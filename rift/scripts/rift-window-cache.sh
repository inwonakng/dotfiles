#!/usr/bin/env bash

rift_cache_file="$HOME/.cache/rift-windows.json"
rift_cache_writer="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/rift_window_cache.py"
rift_windows="[]"
rift_workspace_id="default"

rift_load_context() {
  local workspaces

  rift_windows="$(rift-cli query windows 2>/dev/null || printf '[]')"
  workspaces="$(rift-cli query workspaces 2>/dev/null || printf '[]')"
  rift_workspace_id="$(jq -r '[.[] | select(.is_active == true) | .id][0] // "default"' <<< "$workspaces")"
}

rift_focus_window() {
  local window="$1"
  local window_id
  local window_server_id
  local focus_args

  window_id="$(jq -cr '.id' <<< "$window")"
  window_server_id="$(jq -r '.window_server_id // empty' <<< "$window")"

  focus_args=(--window-id "$window_id")
  if [[ -n "$window_server_id" && "$window_server_id" != "null" ]]; then
    focus_args+=(--window-server-id "$window_server_id")
  fi

  rift-cli execute window focus "${focus_args[@]}"
}

rift_save_cached_window() {
  local key="$1"
  local window="$2"

  [[ -z "$window" ]] && return 0

  # Merge under the same lock as the persistent focus listener.
  python3 -B "$rift_cache_writer" "$rift_workspace_id" "$key" "$window"
}

rift_cached_window() {
  local key="$1"

  [[ -f "$rift_cache_file" ]] || return 0
  jq -c --arg workspace_id "$rift_workspace_id" --arg key "$key" \
    '.[$workspace_id][$key] // empty' "$rift_cache_file" 2>/dev/null || true
}

rift_cached_current_window_where() {
  local key="$1"
  local predicate="$2"
  local cached

  cached="$(rift_cached_window "$key")"
  [[ -n "$cached" ]] || return 0

  jq -c --argjson cached "$cached" \
    "first(.[] | select(.id == \$cached.id and ($predicate))) // empty" <<< "$rift_windows"
}
