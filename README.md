# Dotfiles

## Setting up:

Use platform specific .sh file in the root directory

**Bash**

After cloning this repository, either symlink the full script like this:

```bash
ln -s $PATH_TO_DOTFILES/bash/bashrc/default.sh $HOME/.bashrc
```

OR just include this line in your existing `.bashrc`:

```bash
source $PATH_TO_DOTFILES/bash/bashrc/extras.sh
```

**Most other things**

Most apps here use the `~/.config` directory as their config home. Symlink the directory something like this:

```bash
ln -sn $PATH_TO_DOTFILES/$APP_NAME $HOME/.config/
```

This will create a directory called `~/.config/$APP_NAME` as a symlink.

Vim is an exception. link to `~/.vim`

## Notes

- If git is too old, lazyvim will not install correctly.
- You can use conda to install a new git. (synlink the binary to `~/.local/bin/$ARCH` and it will be picked up next time bashrc is sourced)
  - `$ARCH` can be `x86` or `ppc`. This setting is really only required because I sometimes have to use machines with IBM PowerPC architecture, where the login node is connected to both x86 and ppc compute nodes. In that case we need to be able to tell apart the binaries for diff. systems.

## Main Apps & Tools

- [Kitty](https://sw.kovidgoyal.net/kitty/)/[Ghostty](https://ghostty.org)
- [Obsidian](https://obsidian.md/help/) for note taking.
  - [obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) plugin used for desktop neovim integration. Using [templater](https://github.com/silentvoid13/Templater) for templating daily notes (so that it also works on mobile)
- [conda](https://www.anaconda.com/docs/getting-started/miniconda/main) package manager. used for global binaries only
  - [pixi](https://pixi.prefix.dev/latest/) project-based package manager. used for actual projects
- [karabiner](https://karabiner-elements.pqrs.org) keyborad remapper
- [homerow](https://github.com/nchudleigh/homerow#user-guide) vim-like navigation for clicking things
- [scrolla](https://scrolla.app) just for scrolling. It's smoother.
- [Rift](https://github.com/acsandmann/rift/wiki) space manager. used to maintain virtual spaces
- [Rectangle](https://rectangleapp.com) window manager. used to snap windows to the sides of the screen
- [Hammerspoon](https://www.hammerspoon.org) scriptable automation tool. can do arbitrary things
- [Zotero](https://www.zotero.org) paper manager
  - [AIdea](https://github.com/Visterainer/aidea-zotero) AI assistant integration for Zotero
- [btop](https://github.com/aristocratos/btop) system monitor (top/htop alternative).

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

### Stuff that can be installed with conda

- vim
- tmux
- git
- ripgrep
- fd-find
- zoxide

Install these in the `(base)` environment, and then create a symlink to the
appropriate `~/.local/bin/$ARCH$` folder

### Prerequisites

**Neovim**

- node (use `./scripts/setup/node.sh` to install using nvm)
- cargo/rustup (install using conda if no sudo)
- fd (symlink fdfind to `~/.local/bin/fd`)
- ripgrep
- tree-sitter-cli (may need to use npm or cargo. apt is very out of date)
- python3-dev (on top of python3)

### Pi agent harness

[pi](https://pi.dev/) is an agentic harness similar to codex or claude code. I use it as the main driver and maintain a neovim-based interface for it.

**Pi session console**

[`pi-console`](https://github.com/inwonakng/pi-console) is developed from a local
checkout at `~/Documents/projects/pi-console`. Its development installer links
the `pi-console` command into `~/.local/bin`, registers its Pi package, and lets
tmux load the integration through that installed command rather than a checkout
path. It has three startup modes:

- `pi-console` (or `pc`) — conversation UI.
- `pi-console --overview` — live session overview.
- `pi-console --session PATH` — resume a saved conversation.

By default, pi-console and litenvim install
[`nvim-extras`](https://github.com/inwonakng/nvim-extras) through `vim.pack` and
pin it in their own lockfiles. To test uncommitted changes in both, symlink an
editable checkout at `~/.local/share/nvim-dev/nvim-extras`; each config prepends
that directory to `runtimepath` when it exists.

`tmux/tmux.conf.shared` owns Kitty graphics passthrough and the
`@graphics-nest-count` hooks used by nvim-extras in both Neovim configs.
They work without pi-console installed: ordinary clients use one passthrough
wrapper, while clients attached inside a tmux popup use two. Pi-console's
optional `tmux/graphics.conf` is for standalone installations; do not source it
alongside these shared settings.

Before sending the first message in a new conversation, use `:PiCd [DIRECTORY]`
or `<leader>pc` to change its working directory. This restarts the empty Pi
runtime so project-specific resources load from the selected directory. After a
message has been sent, the command leaves the session unchanged and shows a
warning.

In tmux, `<prefix>g` toggles the `agents` popup, `<prefix>G` starts a new
conversation in the current pane's directory, and `<prefix>o` opens or returns
to its persistent Overview window. The Overview window is created lazily.

The overview refreshes every second and preserves selection by instance ID.
Use Enter to focus a conversation, `dd` to kill it and close its tmux window
(with confirmation if it is active), `/` to filter, `c` to clear the filter,
and `r` to refresh. `<leader>h` opens history, where `ctrl-g` switches between
regular and archived sessions. `<leader>pN` starts a conversation in the
selected session's project directory; `<leader>pn` prompts for a directory.
The regular notification, access-mode, and integration-mode mappings control
the selected session. `<leader>?` shows the complete mappings for either the
overview or conversation UI. Killing a conversation leaves its saved session
file in history. A tmux window with other panes cannot be closed from the overview.
History keeps the existing transcript previews and archive/restore/trash actions.
Resuming from the overview focuses an already-open conversation or creates a
new window; it never replaces another conversation. Archive/trash skip sessions
open in other registered instances, including those opened during confirmation.

Backend-specific discovery, metadata storage, launching, and focus live in the
pi-console checkout under `nvim/lua/pi-integration/backends/`. The overview and
history picker use the backend-neutral `runtime.lua` API. Cross-instance controls use the Neovim RPC
address in each runtime snapshot rather than backend-specific keystrokes. Only
the tmux adapter is implemented; another adapter can implement the same
operations without changing the dashboard UI.

