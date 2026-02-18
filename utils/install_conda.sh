# install conda if not found
if ! command which conda &> /dev/null
then
  echo "I don't see conda, will install"
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O $HOME/conda.sh
  bash $HOME/conda.sh -b -u -p $HOME/miniconda3
  rm -f $HOME/conda.sh
  . ~/.bashrc
else
  echo "Conda found, I won't do anything"
fi
