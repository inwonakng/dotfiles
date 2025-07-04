# Function to get current conda environment name
function parse_conda_env {
	if [[ -n $CONDA_DEFAULT_ENV ]]; then
		echo "($CONDA_DEFAULT_ENV)"
	fi
}

function parse_cwd {
	local dir=$PWD
	local max_length=40
	local home_dir=$HOME

	# Replace home directory with ~
	if [[ $dir == $home_dir* ]]; then
		dir="~${dir#$home_dir}"
	fi

	if [ ${#dir} -le $max_length ]; then
		echo "$dir"
	else
		# Split the path into an array of directories
		IFS='/' read -r -a parts <<<"$dir"
		local length=${#parts[@]}

		# Keep the first part, last three parts, and truncate the middle
		local first_part=${parts[0]}
		local truncated_parts=("${parts[@]: -3}")

		# Join the truncated parts with slashes
		local joined_parts=$(
			IFS='/'
			echo "${truncated_parts[*]}"
		)

		echo "…/$joined_parts"
	fi
}

function newline_if_needed {
	# Save the cursor position
	echo -ne '\e7'
	# Move the cursor to the beginning of the current line
	echo -ne '\e[1G'
	# Check if the cursor is at the beginning of the line (column 1)
	echo -ne '\e[6n'
	read -sdR cursor_position
	cursor_position=${cursor_position#*[}
	cursor_position=${cursor_position%;*}
	if [ "$cursor_position" -gt 1 ]; then
		# Restore the cursor position and print a newline if not at the top
		echo -ne '\e8\n'
	else
		# Restore the cursor position
		echo -ne '\e8'
	fi
}

# detect session type
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
	# SSH session
	export SESSION_TYPE=remote/ssh
else
	case $(ps -o comm= -p "$PPID") in
	sshd | */sshd) export SESSION_TYPE=remote/ssh ;;
	esac
	# Local session
	export SESSION_TYPE=local
fi

# color reference: https://misc.flogisoft.com/bash/tip_colors_and_formatting

WHITE="\[\e[0m\]"
GREEN="\[\e[32m\]"
BROWN="\[\e[33m\]"
BLUE="\[\e[34m\]"
PURPLE="\[\e[35m\]"
CYAN="\[\e[36m\]"
PINKORANGE="\[\e[38;5;212m\]"
DARKPINKORANGE="\[\e[38;5;167m\]"

HOST_COLOR=$CYAN
if [ "$SESSION_TYPE" == "remote/ssh" ]; then
  HOST_COLOR=$DARKPINKORANGE
fi

# Custom PS1
PS1="$GREEN"' \D{%Y-%m-%d} '
PS1+="$BLUE"'  $(parse_cwd) '
PS1+="$BROWN"'$(parse_conda_env)\n'
PS1+="$WHITE"'\u'
PS1+="$PINKORANGE"'@'"$HOST_COLOR"'\h'
PS1+="$CYAN"' → '"$WHITE"

# only add this hook if zoxide is installed.
if command -v "zoxide" >/dev/null 2>&1; then
    PS1+="\$(__zoxide_hook)"
fi
