# Dotfiles

## Setting up:

Use platform specific .sh file in the root directory

## Notes

If git is too old, lazyvim will not install correctly. 
You can use conda to install a new git.

## Apps

### OSX
- Hammerspoon 
- Wezterm
- yabai
- borders (for border highlight)
- zim (for zsh)
- conda

### Linux (mostly ubuntu)
- zsh
- conda

## Notes
- In order to match the versions of software used across different machines, I am creating symlinks of binaries installed from conda (tmux, git) on machines that I don't have root access on.

```bash
ln -sn $PATH_TO_APP $HOME/.local/bin
```

and in my shell config file, I have added the following line:

```bash
export PATH=$HOME/.local/bin:$PATH
```

so that the binaries under `.local/bin` are found before anything.
