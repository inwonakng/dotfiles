# /usr/bin/bash
source ~/miniconda3/bin/activate;
echo "Conda activated";

conda activate base;

GIT_VERSION="2.40.1"

function install_and_link(){
  conda install -c conda-forge git=${GIT_VERSION} -y;
  ln -sf ~/miniconda3/bin/git ~/.local/bin/git;
}

if conda env list | grep -q "git.*${GIT_VERSION}"; then
  echo "Git ${GIT_VERSION} is already installed on conda. Won't do anything";
else
  echo "Git ${GIT_VERSION} is not installed. Will install to base";
  install_and_link;
fi
