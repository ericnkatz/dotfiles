# dotfiles

Personal config for Ghostty, shell, and package installation. Works on macOS
and Linux (tested against Arch-based distros).

## Usage

On a new machine, with the repo already cloned:

```sh
git clone git@github.com:ericnkatz/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Or, without git/SSH keys set up yet — downloads a zip of the repo from
GitHub, extracts it to `~/dotfiles`, and runs `install.sh` (requires the
repo to be public):

```sh
curl -fsSL https://raw.githubusercontent.com/ericnkatz/dotfiles/main/bootstrap.sh | bash
```

Re-running either form updates `~/dotfiles` in place and re-applies configs.

On macOS this installs Homebrew if missing and installs/checks the packages in
`Brewfile`. On Omarchy it uses `omarchy pkg` for Arch/AUR packages and `mise`
for the cross-platform Vault and Atlassian CLIs, without installing Linuxbrew.
It then symlinks the tracked configs into place (existing files are backed up
with a `.bak.<timestamp>` suffix, not overwritten). Pass `--theme=<name>` to
also generate a color theme before linking (see [Theming](#theming)); omit it
to keep the current Aether palette on Omarchy or the repository's current
generated theme on other systems.

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
per-project. During installation, an existing Node newer than the current LTS
is preserved; otherwise the current LTS is selected. The machine-specific
choice is written to `~/.config/mise/conf.d/node.toml`, then `mise install`
fetches any configured tools that are missing.

## Agent skills

`install.sh` runs `npx skills add addyosmani/agent-skills -g -a '*'` to
globally install [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
for every detected agent (Claude Code, Cursor, Codex, etc.) via the
[skills CLI](https://github.com/vercel-labs/skills). Files land in
`~/.agents/skills/`, symlinked into each agent's own skills directory.

## Theming

On macOS and other non-Omarchy systems, Starship, Codex, Ghostty, and the editor
themes derive from one palette file in `theme/palettes/<name>.toml`:

```sh
python3 theme/generate-theme.py everforest   # or any name in theme/palettes/
```

On Omarchy systems with Aether, `./install.sh --theme=<name>` imports that
palette into Aether first. Aether then owns the Omarchy, Ghostty, VS Code, and
other supported application cascade. With no `--theme`, the installer preserves
and reads Aether's current palette. The dotfiles generator only fills the gaps:
Codex receives the Aether palette, while Starship keeps its established Tokyo
Night powerline colors.

Claude's existing status-line appearance is intentionally left untouched.

When installed, Codex gets a matching native status-line layout and selects the
generated theme in its `[tui]` configuration. Codex supplies its own status-line
fields and separators, so it cannot reproduce a powerline layout exactly.

Most palettes in `theme/palettes/` are vendored from a community theme
collection (flat `colors.toml` shape) — run `ls theme/palettes` for the full
list (catppuccin, everforest, gruvbox, nord, tokyo-night, etc.).
`pastel-green.toml` is the original hand-tuned default and is reproduced
exactly rather than derived; every other palette's six powerline colors are
approximated by a gradient between its `light_foreground` and `muted`
colors, since those palettes don't define powerline-shaped stops directly.

`theme/current` tracks the last-generated theme name (informational only —
not read by anything).

## Updating

- After changing a config on this machine, copy it back into this repo,
  commit, and push.
- After installing new brew packages: `brew bundle dump --file=Brewfile --force`
  to refresh the list, then commit.
- On another machine, `git pull && ./install.sh` to pick up changes.
