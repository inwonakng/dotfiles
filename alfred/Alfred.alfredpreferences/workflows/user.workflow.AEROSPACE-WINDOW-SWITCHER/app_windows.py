#!/usr/bin/env python3
import json, sys, subprocess

app_name = sys.argv[1] if len(sys.argv) > 1 else ''
if not app_name:
    print('{"items":[]}')
    sys.exit(0)


def get_app_path(name):
    r = subprocess.run(
        ['osascript', '-e', f'POSIX path of (path to application "{name}")'],
        capture_output=True, text=True, timeout=3
    )
    path = r.stdout.strip()
    return path.rstrip('/') if '.app' in path else None


windows   = json.load(sys.stdin)
app_path  = get_app_path(app_name)

items = []
for w in windows:
    if w.get('app-name') != app_name:
        continue
    title = w.get('window-title') or app_name
    wid   = str(w.get('window-id', ''))
    item  = {'title': title, 'subtitle': app_name, 'arg': wid, 'uid': wid}
    if app_path:
        item['icon'] = {'type': 'fileicon', 'path': app_path}
    items.append(item)

print(json.dumps({'items': items}))
