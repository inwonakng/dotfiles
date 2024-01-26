# /usr/bin/bash
source ~/miniconda3/bin/activate;
echo "Conda activated";

conda activate base;

TMUX_VERSION="3.3a"

function install_and_link(){
  conda install -c conda-forge tmux=${TMUX_VERSION} -y;
  ln -sf ~/miniconda3/bin/tmux ~/.local/bin/tmux;
}

if conda env list | grep -q "tmux.*${TMUX_VERSION}"; then
  echo "Tmux ${TMUX_VERSION} is already installed on conda. Won't do anything";
else 
  echo "Tmux ${TMUX_VERSION} is not installed. Will install to base";
  install_and_link;
fi
