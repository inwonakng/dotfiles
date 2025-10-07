#!/bin/bash
# Takes as input some json string through STDIN. invokes terminal-notifier to notify user
INPUT=$(cat)
FOLDER=$(echo "$INPUT" | jq -r '.cwd | split("/") | last')
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // "N/A"')
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // "N/A"')

MESSAGE="I want to use \"$TOOL\""

terminal-notifier -title "Claude@$FOLDER" -message "$MESSAGE"
