# .bash_profile
# This file should have anything that is **common** between the local and
# remote machine setups.

export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8
unset LC_ALL

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

export PATH='/opt/homebrew/bin':$PATH
