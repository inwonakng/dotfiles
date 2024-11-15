mkdir -p "$HOME/.bash_utils/completions"

# install git completions
VERSION=$(git --version | awk '{print $3}' | sed 's/^/v/')
URL="https://raw.githubusercontent.com/git/git/$VERSION/contrib/completion/git-completion.bash"
curl $URL -o "$HOME/.bash_utils/completions/git.bash"

# install slurm completions
URL="https://raw.githubusercontent.com/damienfrancois/slurm-helper/refs/heads/master/slurm_completion.sh"
curl $URL -o "$HOME/.bash_utils/completions/slurm.bash"
