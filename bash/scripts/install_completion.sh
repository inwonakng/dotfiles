# install git completions
VERSION=$(git --version | awk '{print $3}' | sed 's/^/v/')
URL="https://raw.githubusercontent.com/git/git/$VERSION/contrib/completion/git-completion.bash"
curl $URL -o "$HOME/.git-completion.bash"
