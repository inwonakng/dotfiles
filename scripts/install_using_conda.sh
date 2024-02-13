# /usr/bin/bash

program=""
version=""

print_usage() {
  printf "Usage: \n"
  printf "\t --progam: Specify which program to install\n"
  printf "\t --version: Specify which version to use (must be available in conda repo)\n"
}

# refer to https://stackoverflow.com/questions/22025793/using-getopts-to-pick-up-whole-word-flags
while [ $# -gt 0 ]; do
  case $1 in
    --program) program="$2"; shift ;;
    --version) version="$2"; shift ;;
    *) print_usage; exit 1 ;;
  esac
  shift
done

echo "Installing $program==$version";

source ~/miniconda3/bin/activate;
echo "Conda activated";

conda activate base;

function install_and_link(){
  conda install -c conda-forge ${program}=${version} -y;
  ln -sf ~/miniconda3/bin/${program} ~/.local/bin/${program};
}

if conda list | grep -q "${program}.*${version}"; then
  echo "${program} ${version} is already installed on conda. Won't do anything";
else
  echo "${program} ${version} is not installed. Will install to base";
  install_and_link;
fi
