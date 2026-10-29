#!/usr/bin/env bash
# Run with bash after installing Pi and linking the configuration to ~/.pi.
set -euo pipefail

if ! command -v pi >/dev/null 2>&1; then
  printf 'Pi is required. Install Pi and link the configuration to ~/.pi first.\n' >&2
  exit 1
fi

pi update --extensions

printf 'Pi packages installed. Restart Pi or run /reload.\n'
