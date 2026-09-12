# dotfiles

Personal config for Ghostty, shell, and package installation. Works on macOS
and Linux (tested against Arch-based distros).

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

### Cross-platform notes

- `Brewfile` casks (Ghostty app, Nerd Font) only work on macOS, since Homebrew
  Cask doesn't support Linux. On Linux, `install.sh` installs Ghostty via
  `pacman` (if present) and downloads the Nerd Font directly from its GitHub
  release instead.
- `zprofile` detects whether Homebrew lives at `/opt/homebrew` (macOS) or
  `/home/linuxbrew/.linuxbrew` (Linux) and sets up the shell env accordingly.
- The Ghostty config file itself needs no changes across platforms — Ghostty
  silently ignores config keys that don't apply to the current platform
  (e.g. `macos-non-native-fullscreen` is a no-op on Linux).

## Updating

- After changing a config on this machine, copy it back into this repo,
  commit, and push.
- After installing new brew packages: `brew bundle dump --file=Brewfile --force`
  to refresh the list, then commit.
- On another machine, `git pull && ./install.sh` to pick up changes.
