# /usr/bin/bash

source ~/miniconda3/bin/activate;
echo "Conda activated";

function create_and_install(){
  conda create -n pynvim python=3.10 -y;
  conda activate pynvim;
  pip install neovim;
}

if conda env list | grep -q pynvim; then
  echo "Pynvim exists, won't do anything";
else 
  echo "Pynvim does not exist, will create!";
  create_and_install;
fi
