#!/usr/bin/env bash
set -euo pipefail

state_dir="$HOME/.cache/rift-floating-border"
mkdir -p "$state_dir"

# Keep the same lock file: concurrent events must query and update in order.
# lockf locks the inherited descriptor, so the lock lasts until this script exits.
exec 9>"$state_dir/lock"
lockf -s 9

if [[ "${1:-}" == "--start" ]]; then
  # A process existing is not enough: borders registers its Mach service only
  # after creating the initial borders. Wait for that service before adding hooks.
  python3 -B - <<'PY'
import ctypes
import subprocess
import time

system = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
port_type = ctypes.c_uint32
system.task_get_special_port.argtypes = [port_type, ctypes.c_int, ctypes.POINTER(port_type)]
system.bootstrap_look_up.argtypes = [port_type, ctypes.c_char_p, ctypes.POINTER(port_type)]
system.mach_port_deallocate.argtypes = [port_type, port_type]
task = port_type.in_dll(system, "mach_task_self_").value
bootstrap = port_type()
if system.task_get_special_port(task, 4, ctypes.byref(bootstrap)) != 0:
    raise SystemExit("Cannot access the Mach bootstrap port")

def borders_ready() -> bool:
    port = port_type()
    if system.bootstrap_look_up(bootstrap, b"git.felix.borders", ctypes.byref(port)) != 0:
        return False
    system.mach_port_deallocate(task, port)
    return True

options = ["borders", "style=round", "width=5.0", "hidpi=on",
           "active_color=0x00000000", "inactive_color=0x00000000"]
if borders_ready():
    # Static settings are applied once at startup, never on ordinary events.
    subprocess.run(options, check=True)
else:
    daemon = subprocess.Popen(options, stdin=subprocess.DEVNULL,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              close_fds=True)
    deadline = time.monotonic() + 5.0
    while not borders_ready():
        if daemon.poll() is not None:
            raise SystemExit("JankyBorders exited before registering its Mach service")
        if time.monotonic() >= deadline:
            daemon.terminate()
            daemon.wait()
            raise SystemExit("JankyBorders did not register its Mach service within 5 seconds")
        time.sleep(0.05)
PY
  printf '%s\n' '0x00000000' > "$state_dir/active-color"

  script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
  for event in focused_window_changed workspace_changed windows_changed layout_changed; do
    rift-cli subscribe cli --event "$event" --command bash --args "$script_path"
  done
fi

# Always query current focus rather than using a potentially stale event payload.
windows="$(rift-cli query windows)"
focused_is_floating="$(jq -r 'any(.[]; .is_focused == true and .is_floating == true)' <<< "$windows")"

active_color="0x00000000"
if [[ "$focused_is_floating" == "true" ]]; then
  active_color="0xffffb454"
fi

previous_color=""
if [[ -f "$state_dir/active-color" ]]; then
  IFS= read -r previous_color < "$state_dir/active-color"
fi
if [[ "$active_color" == "$previous_color" ]]; then
  exit 0
fi

# Do not auto-start a daemon from an event. Restart Rift if borders was stopped.
pgrep -x borders >/dev/null
# Passing hidpi here would recreate every border; only the active color changes.
borders active_color="$active_color" 9>&-
printf '%s\n' "$active_color" > "$state_dir/active-color"
