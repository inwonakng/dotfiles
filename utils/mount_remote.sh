# /usr/bin/bash

# mkdir -p ~/mount/idea/tabrfm
# sshfs idea-node-05:/home/kangi/tab-reprog-fm ~/mount/idea/tabrfm -o follow_symlinks,kill_on_unmount

mkdir -p ~/mount/silkworm/tabrfm
sshfs silkworm:/home/kangi/tab-reprog-fm ~/mount/silkworm/tabrfm -o follow_symlinks,kill_on_unmount

# mkdir -p ~/mount/cci/tabrfm
# sshfs cci:/gpfs/u/home/DDTD/DDTDkngn/scratch/tab-reprog-fm ~/mount/cci/tabrfm -o follow_symlinks,kill_on_unmount
