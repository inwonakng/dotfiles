"""Remember workspace focus through one ordered Rift event stream."""

from __future__ import annotations

from dataclasses import dataclass
import fcntl
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time
from typing import TypedDict, cast

from rift_window_cache import WindowId, WindowRef, read_cache, save_window


class Window(WindowRef):
    is_focused: bool


class Workspace(TypedDict):
    id: str
    is_active: bool
    windows: list[Window]


class ProtocolWorkspaceId(TypedDict):
    idx: int
    version: int


class Event(TypedDict, total=False):
    type: str
    space_id: int
    workspace_id: ProtocolWorkspaceId
    window_id: WindowId


@dataclass
class Pending:
    workspace_id: str
    target: WindowRef | None
    deadline: float
    requested: bool = False
    automatic_window: WindowId | None = None


def cli(*args: str) -> str:
    return subprocess.run(
        ["rift-cli", *args], check=True, capture_output=True, text=True, timeout=3
    ).stdout


def query_workspaces(space: int) -> list[Workspace]:
    return cast(list[Workspace], json.loads(cli("query", "workspaces", "--space-id", str(space))))


def find_window(workspace: Workspace, ref: WindowRef | None) -> Window | None:
    if ref is None:
        return None
    return next(
        (window for window in workspace["windows"]
         if window["id"] == ref["id"]
         and (ref.get("window_server_id") is None
              or window["window_server_id"] == ref["window_server_id"])),
        None,
    )


def focused_window(workspace: Workspace) -> Window | None:
    return next((window for window in workspace["windows"] if window["is_focused"]), None)


def focus(window: WindowRef) -> None:
    args = ["execute", "window", "focus", "--window-id", json.dumps(window["id"])]
    if window.get("window_server_id") is not None:
        args.extend(["--window-server-id", str(window["window_server_id"])])
    cli(*args)


# Normally the first focus event drives restoration. Some entries (notably
# returning from an empty workspace) keep macOS focus and emit no focus event.
ENTRY_FOCUS_WAIT = 0.2
RESTORE_FOCUS_WAIT = 1.0
SERVER_CHECK_INTERVAL = 2.0


class FocusHistory:
    def __init__(self) -> None:
        self.active: dict[int, str] = {}
        self.last_focus: dict[int, WindowRef] = {}
        self.pending: dict[int, Pending] = {}

    def remember(self, space: int, workspace_id: str, window: WindowRef | None) -> None:
        save_window(workspace_id, "last_focused", window)
        if window is None:
            self.last_focus.pop(space, None)
        else:
            self.last_focus[space] = window

    def restore(self, pending: Pending, target: Window, automatic: Window | None) -> None:
        pending.requested = True
        pending.automatic_window = automatic["id"] if automatic is not None else None
        pending.deadline = time.monotonic() + RESTORE_FOCUS_WAIT
        focus(target)

    def seed(self) -> None:
        layout = json.loads(cli("query", "layout"))
        if layout is None:
            return
        space = int(layout["space_id"])
        for workspace in query_workspaces(space):
            if workspace["is_active"]:
                self.active[space] = workspace["id"]
                self.remember(space, workspace["id"], focused_window(workspace))

    def handle(self, event: Event) -> None:
        kind = event.get("type")
        if kind not in {"workspace_changed", "focused_window_changed"}:
            return
        space = event["space_id"]
        identity = event["workspace_id"]
        workspace_id = f"VirtualWorkspaceId({identity['idx']}v{identity['version']})"
        workspaces = query_workspaces(space)
        workspace = next((ws for ws in workspaces if ws["id"] == workspace_id), None)
        if workspace is None:
            return

        if kind == "workspace_changed":
            previous_workspace = self.active.get(space)
            self.active[space] = workspace_id
            cached = read_cache().get(workspace_id, {}).get("last_focused")
            target = find_window(workspace, cached)
            # A window following us into the destination is an intentional move,
            # not a request to restore the destination's older focus.
            if previous_workspace != workspace_id:
                moved = find_window(workspace, self.last_focus.get(space))
                if moved is not None:
                    target = moved
            self.pending[space] = Pending(
                workspace_id, target, time.monotonic() + ENTRY_FOCUS_WAIT
            )
            return

        self.active.setdefault(space, workspace_id)
        if self.active[space] != workspace_id:
            return
        # History follows event order, not the newer query snapshot. In
        # particular, focus immediately before move-and-follow may already
        # belong to the destination by the time this event is read.
        observed = next(
            (window for ws in workspaces for window in ws["windows"]
             if window["id"] == event["window_id"]),
            None,
        )
        ref: WindowRef = {
            "id": event["window_id"],
            "window_server_id": observed["window_server_id"] if observed is not None else None,
        }
        pending = self.pending.get(space)
        belongs = any(window["id"] == ref["id"] for window in workspace["windows"])
        if not belongs and (
            workspace["is_active"]
            or (pending is not None and pending.automatic_window is None)
        ):
            # During rapid switches Rift can label an outgoing window with the
            # incoming workspace ID. It must not establish entry focus or look
            # like a newer click. Historical focus on an inactive workspace can
            # still belong to a window that has since moved elsewhere.
            return
        if pending is None:
            self.remember(space, workspace_id, ref)
            return
        target = find_window(workspace, pending.target)
        if target is None or target["id"] == ref["id"]:
            self.pending.pop(space)
            self.remember(space, workspace_id, ref)
            return
        if pending.automatic_window is None:
            pending.automatic_window = ref["id"]
        elif ref["id"] != pending.automatic_window:
            # A different focus after entry is newer user/app intent, even
            # when this workspace has since become inactive.
            self.pending.pop(space)
            self.remember(space, workspace_id, ref)
            return
        window = focused_window(workspace)
        if (not pending.requested and workspace["is_active"]
                and window is not None and window["id"] == ref["id"]):
            # Only restoration (not history recording) needs live validation.
            # Wait for Rift's entry focus before sending our focus request.
            self.restore(pending, target, window)

    def expire(self) -> None:
        for space, pending in list(self.pending.items()):
            if time.monotonic() < pending.deadline:
                continue
            workspace = next(
                (ws for ws in query_workspaces(space)
                 if ws["id"] == pending.workspace_id and ws["is_active"]),
                None,
            )
            if workspace is None:
                self.pending.pop(space)
                continue
            window = focused_window(workspace)
            target = find_window(workspace, pending.target)
            if not pending.requested and target is not None and (
                window is None or window["id"] != target["id"]
            ):
                # No entry-focus event arrived. Reconcile the live workspace
                # once, then wait for the usual acknowledgement.
                self.restore(pending, target, window)
            else:
                self.pending.pop(space)
                # Failed/missing acknowledgements must not freeze history.
                self.remember(space, workspace["id"], window)

    def timeout(self) -> float | None:
        if not self.pending:
            return None
        return max(0.0, min(p.deadline for p in self.pending.values()) - time.monotonic())


def server_processes() -> str:
    return subprocess.run(
        ["pgrep", "-x", "rift"], check=True, capture_output=True, text=True, timeout=3
    ).stdout


def follow(stream: subprocess.Popen[bytes], servers: str) -> None:
    assert stream.stdout is not None
    history = FocusHistory()
    history.seed()
    buffered = b""
    next_server_check = time.monotonic() + SERVER_CHECK_INTERVAL
    with selectors.DefaultSelector() as selector:
        selector.register(stream.stdout, selectors.EVENT_READ)
        while True:
            timeout = max(0.0, next_server_check - time.monotonic())
            pending_timeout = history.timeout()
            if pending_timeout is not None:
                timeout = min(timeout, pending_timeout)
            for _key, _mask in selector.select(timeout):
                data = os.read(stream.stdout.fileno(), 65536)
                if not data:
                    raise RuntimeError("Rift event stream ended")
                buffered += data
                while b"\n" in buffered:
                    line, buffered = buffered.split(b"\n", 1)
                    history.handle(cast(Event, json.loads(line)))
            history.expire()
            if time.monotonic() >= next_server_check:
                # Rift 0.7's Mach subscription waits indefinitely when its
                # server dies. EOF alone cannot detect a service restart.
                if server_processes() != servers:
                    raise RuntimeError("Rift process changed; reconnecting event stream")
                next_server_check = time.monotonic() + SERVER_CHECK_INTERVAL


def stop(_signum: int, _frame: object) -> None:
    raise SystemExit(0)


def main() -> None:
    lock_path = Path.home() / ".cache/rift-focus-listener.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        while True:
            try:
                servers = server_processes()
                with subprocess.Popen(
                    ["rift-cli", "subscribe", "mach", "*"], stdout=subprocess.PIPE
                ) as stream:
                    try:
                        follow(stream, servers)
                    finally:
                        if stream.poll() is None:
                            stream.terminate()
                            try:
                                stream.wait(timeout=3)
                            except subprocess.TimeoutExpired:
                                stream.kill()
                                stream.wait()
            except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
                print(f"Rift focus listener: {error}", file=sys.stderr, flush=True)
            # Reconnect after Rift restarts. The singleton lock prevents a second
            # run_on_start invocation from creating a competing history writer.
            time.sleep(1)


if __name__ == "__main__":
    main()
