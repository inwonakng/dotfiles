# inspired by: https://gist.github.com/jsongerber/7dfd9f2d22ae060b98e15c5590c4828d

# keep the presets in ~/.remote-workspaces.txt
# each line shoud look something like {HOST}/{RELPATH_FROM_HOME}
# {HOST} should be defined in ~/.ssh/config
target=$(cat ~/.remote-workspaces.txt | fzf --cycle --layout=reverse)

if [ -z "$target" ]; then
	exit 0
fi

nvim oil-ssh://"$target"
