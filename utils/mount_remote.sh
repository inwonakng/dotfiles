# /usr/bin/bash

mkdir -p ~/mounts/idea/tabrfm
sshfs idea-node-05:/home/kangi/tab-reprog-fm ~/mounts/idea/tabrfm -o follow_symlinks,kill_on_unmount,reconnect

mkdir -p ~/mounts/silkworm/tabrfm
sshfs silkworm:/home/kangi/tab-reprog-fm ~/mounts/silkworm/tabrfm -o follow_symlinks,kill_on_unmount,reconnect

mkdir -p ~/mounts/cci/tabrfm
sshfs cci:/gpfs/u/home/DDTD/DDTDkngn/scratch/tab-reprog-fm ~/mounts/cci/tabrfm -o follow_symlinks,kill_on_unmount,reconnect