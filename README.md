# dotfiles

Personal config for macOS setup: Ghostty, shell, and Homebrew packages.

## Usage

On a new machine:

```sh
git clone git@github.com:ericnkatz/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

This installs Homebrew if missing, installs/checks all packages in `Brewfile`
(skips anything already installed), and symlinks the tracked configs into
place (existing files are backed up with a `.bak.<timestamp>` suffix, not
overwritten).

## Updating

- After changing a config on this machine, copy it back into this repo,
  commit, and push.
- After installing new brew packages: `brew bundle dump --file=Brewfile --force`
  to refresh the list, then commit.
- On another machine, `git pull && ./install.sh` to pick up changes.
