# /usr/bin/bash

# mkdir -p ~/mount/idea/tabrfm
# sshfs idea-node-05:/home/kangi/tab-reprog-fm ~/mount/idea/tabrfm -o follow_symlinks,kill_on_unmount

mkdir -p ~/mount/brains/tabrfm
sshfs brains:/home/kangi/tab-reprog-fm ~/mount/brains/tabrfm -o follow_symlinks,kill_on_unmount

# mkdir -p ~/mount/cci/tabdd
# sshfs cci:/gpfs/u/home/DDTD/DDTDkngn/scratch/tabdd ~/mount/cci/tabdd -o follow_symlinks,kill_on_unmount

# mkdir -p ~/mount/cci/tabrfm
# sshfs cci:/gpfs/u/home/DDTD/DDTDkngn/scratch/tab-reprog-fm ~/mount/cci/tabrfm -o follow_symlinks,kill_on_unmount
