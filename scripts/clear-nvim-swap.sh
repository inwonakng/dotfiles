#!/usr/bin/env bash

set -euo pipefail

app_name="${NVIM_APPNAME:-nvim}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
swap_dir="$data_home/$app_name/swp"

if [[ ! -d "$swap_dir" ]]; then
    exit 0
fi

find "$swap_dir" -maxdepth 1 -type f -delete
