#!/usr/bin/env bash

rift_cache_file="$HOME/.cache/rift-windows.json"
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
  local tmp
  local current

  [[ -z "$window" ]] && return 0

  mkdir -p "$(dirname "$rift_cache_file")"
  current="$(cat "$rift_cache_file" 2>/dev/null || printf '{}')"
  tmp="$rift_cache_file.$$"

  if jq -c \
    --arg workspace_id "$rift_workspace_id" \
    --arg key "$key" \
    --argjson window "$window" \
    'if type == "object" then . else {} end
     | .[$workspace_id] = (
         ((.[$workspace_id] // {}) | if type == "object" then . else {} end)
         + {($key): {id: $window.id, window_server_id: ($window.window_server_id // null)}}
       )' <<< "$current" > "$tmp"; then
    mv "$tmp" "$rift_cache_file"
  else
    rm -f "$tmp"
  fi
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
