# /usr/bin/bash

mkdir -p ~/mounts/tabrfm-idea
sshfs idea-node-05:/home/kangi/tab-reprog-fm ~/mounts/tabrfm-idea -o follow_symlinks,kill_on_unmount,reconnect
