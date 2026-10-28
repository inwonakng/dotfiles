"""Shared, atomic window-history writes for Rift's shell helpers and listener."""

from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import TypedDict, cast


class WindowId(TypedDict):
    pid: int
    idx: int


class WindowRef(TypedDict):
    id: WindowId
    window_server_id: int | None


CACHE_FILE = Path.home() / ".cache/rift-windows.json"


def read_cache() -> dict[str, dict[str, WindowRef]]:
    try:
        data = json.loads(CACHE_FILE.read_text())
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        raise ValueError(f"Expected an object in {CACHE_FILE}")
    return cast(dict[str, dict[str, WindowRef]], data)


def save_window(workspace_id: str, key: str, window: WindowRef | None) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    # All writers lock the same sidecar, not the file replaced by os.replace.
    with CACHE_FILE.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        cache = read_cache()
        workspace = cache.setdefault(workspace_id, {})
        if window is None:
            workspace.pop(key, None)
        else:
            workspace[key] = {
                "id": window["id"],
                "window_server_id": window.get("window_server_id"),
            }
        temporary: str | None = None
        try:
            with tempfile.NamedTemporaryFile(mode="w", dir=CACHE_FILE.parent, delete=False) as out:
                temporary = out.name
                json.dump(cache, out, separators=(",", ":"))
                out.write("\n")
            os.replace(temporary, CACHE_FILE)
        finally:
            if temporary is not None:
                Path(temporary).unlink(missing_ok=True)


if __name__ == "__main__":
    workspace_id, key, payload = sys.argv[1:]
    save_window(workspace_id, key, cast(WindowRef, json.loads(payload)))
