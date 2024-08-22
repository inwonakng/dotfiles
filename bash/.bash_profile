# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -f ~/.bash_utils/prompt ]; then
	. ~/.bash_utils/prompt
fi
. "$HOME/.cargo/env"
