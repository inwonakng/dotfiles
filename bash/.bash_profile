# .bash_profile
# This file should have anything that is **common** between the local and
# remote machine setups.

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

if [ -f ~/.bash_utils/prompt.sh ]; then
    source ~/.bash_utils/prompt.sh
fi
