# /usr/bin/bash
source ~/miniconda3/bin/activate;
echo "Conda activated";

ZSH_VERSION="5.9"

function install_and_link(){
  conda install -c conda-forge zsh=${ZSH_VERSION} -y;
  ln -sf ~/miniconda3/bin/zsh ~/.local/bin/zsh;
}

if conda env list | grep -q "zsh.*${ZSH_VERSION}"; then
  echo "zsh ${ZSH_VERSION} is already installed on conda. Won't do anything";
else
  echo "zsh ${ZSH_VERSION} is not installed. Will install to base";
  install_and_link;
fi
