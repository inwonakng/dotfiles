# assume we are in ~/dotfiles
for f in $HOME/dotfiles/scripts/startup/mac/*.sh; do
    # skip init.sh
    [[ "$f" == *init.sh ]] && continue
    bash "$f"
done
