#!/usr/bin/env bash
# Run with bash. Copies real files into each vault so they also sync to mobile.
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ $# -eq 0 ]]; then
  base="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
  if [[ ! -d "$base" ]]; then
    base="/mnt/c/Users/inwon/iCloudDrive/iCloud~md~obsidian"
  fi
  set -- "$base/personal" "$base/work"
fi
python3 - "$repo" "$@" <<'PY'
import json
import shutil
import sys
from pathlib import Path

templates = Path(sys.argv[1]) / "obsidian/templates"
sources = [templates / "project-notes.md", templates / "project-daily.md"]
# Validate every destination before making changes.
vaults = []
for argument in sys.argv[2:]:
    vault = Path(argument)
    settings_path = vault / ".obsidian/plugins/templater-obsidian/data.json"
    settings = json.loads(settings_path.read_text())
    if settings.get("templates_folder") != "templates":
        raise SystemExit(f"Expected templates folder 'templates': {vault}")
    for source in sources:
        destination = vault / "templates" / source.name
        if destination.is_symlink():
            raise SystemExit(f"Refusing to replace symlink: {destination}")
    vaults.append((vault, settings_path, settings))

for vault, settings_path, settings in vaults:
    (vault / "templates").mkdir(parents=True, exist_ok=True)
    # These templates are managed here; re-running setup deploys source updates.
    for source in sources:
        shutil.copyfile(source, vault / "templates" / source.name)
    (vault / "projects").mkdir(exist_ok=True)
    startup = settings.setdefault("startup_templates", [])
    if "templates/project-notes.md" not in startup:
        startup.append("templates/project-notes.md")
    # These commands create fully rendered notes. Do not re-template their content
    # on creation or when a new project note arrives through sync.
    ignored = settings.setdefault("ignore_folders_on_creation", [])
    if not any(entry.get("folder", "").rstrip("/") == "projects" for entry in ignored):
        ignored.append({"folder": "projects"})
    settings_path.write_text(json.dumps(settings, indent=2) + "\n")
    print(f"Installed project daily templates and command in {vault}")
PY
printf '%s\n' 'Enable Templater > Enable startup templates on each device, then reload Templater.'
