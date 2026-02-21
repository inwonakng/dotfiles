#!/usr/bin/env python3
import json, sys, subprocess


def get_app_path(name):
    r = subprocess.run(
        ['osascript', '-e', f'POSIX path of (path to application "{name}")'],
        capture_output=True, text=True, timeout=3
    )
    path = r.stdout.strip()
    return path.rstrip('/') if '.app' in path else None


windows = json.load(sys.stdin)
app_names = {w.get('app-name', '') for w in windows if w.get('app-name')}
app_paths = {name: get_app_path(name) for name in app_names}

items = []
for w in windows:
    app   = w.get('app-name', '')
    title = w.get('window-title') or app
    wid   = str(w.get('window-id', ''))
    item  = {'title': title, 'subtitle': app, 'arg': wid, 'uid': wid}
    path  = app_paths.get(app)
    if path:
        item['icon'] = {'type': 'fileicon', 'path': path}
    items.append(item)

print(json.dumps({'items': items}))
