This repository is the dotfiles for various systems. It's the central place to manage and maintain configuration of the various apps I use daily.

The relevant directories are symlinked to the appropriate locations for each system. To check how things are automatically linked, you can view the setup scripts in `./scripts/setup/{local,remote}.sh`. local assumes a mac machine, while remote assumes a linux machine.

**Directories:**

- ./bash/ -- bash config
- ./litenvim/ -- neovim config
- ./vim/ -- vim config
- ./tmux/ -- tmux config
- ./pi-nvim/ -- custom neovim config for pi agent
- ./pi/ -- config for pi agent

**Good practices**

- Do not use `chmod` on helper scripts. prefer to use `bash` or `sh` to execute them. 
