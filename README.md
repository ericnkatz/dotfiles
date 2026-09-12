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
overwritten). Pass `--theme=<name>` to also generate a color theme before
linking (see [Theming](#theming)); omit it to keep whatever's already
generated (defaults to `pastel-green`).

```sh
./install.sh --theme=everforest
```

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

## Runtimes

Node (and other language runtimes, if added later) are managed by
[mise](https://mise.jdx.dev) rather than Homebrew, so versions can be pinned
per-project. `config/mise/config.toml` pins the global default
(`node = "lts"`); `install.sh` runs `mise install` to fetch whatever's pinned
there after linking configs.

## Agent skills

`install.sh` runs `npx skills add addyosmani/agent-skills -g -a '*'` to
globally install [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
for every detected agent (Claude Code, Cursor, Codex, etc.) via the
[skills CLI](https://github.com/vercel-labs/skills). Files land in
`~/.agents/skills/`, symlinked into each agent's own skills directory.

## Theming

`starship.toml`, the Claude Code statusline, and Ghostty's colors all derive
from one palette file in `theme/palettes/<name>.toml`, so switching themes is
one command instead of editing three files by hand:

```sh
python3 theme/generate-theme.py everforest   # or any name in theme/palettes/
```

This rewrites the `# BEGIN/END GENERATED THEME` block in each of
`config/starship.toml`, `config/claude/statusline.sh`, and
`config/ghostty/config` — everything else in those files is left untouched.
Restart Ghostty and start a new Claude Code session to see the change (both
read their config at startup, not live).

Most palettes in `theme/palettes/` are vendored from
***REMOVED***
the community theme collection (same `colors.toml` shape) — run `ls theme/palettes` for the full list
(catppuccin, everforest, gruvbox, nord, tokyo-night, etc.). `pastel-green.toml`
is the original hand-tuned default and is reproduced exactly rather than
derived; every other palette's six powerline colors are approximated by a
gradient between its `light_foreground` and `muted` colors, since a community theme collection
palettes don't define powerline-shaped stops directly.

`theme/current` tracks the last-generated theme name (informational only —
not read by anything).

## Updating

- After changing a config on this machine, copy it back into this repo,
  commit, and push.
- After installing new brew packages: `brew bundle dump --file=Brewfile --force`
  to refresh the list, then commit.
- On another machine, `git pull && ./install.sh` to pick up changes.
