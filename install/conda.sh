# install conda if not found
if ! command which conda &> /dev/null
then
  echo "I don't see conda, will install"
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O conda.sh
  bash conda.sh -b -p ~/miniconda3
  rm -f conda.sh
  ~/local/miniconda3/bin/conda init bash
  . ~/.bashrc
else
  echo "Conda found, I won't do anything"
fi
