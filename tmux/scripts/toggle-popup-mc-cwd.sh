#!/usr/bin/env bash

# This entry point has the same persistent-session behavior as the MC toggle.
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit
exec bash "$script_dir/toggle-popup-mc.sh" "$@"
