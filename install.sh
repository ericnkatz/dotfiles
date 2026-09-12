#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color/style, mirroring mise's own CLI output: a dim "tag" prefix on every
# line, color reserved for status (green = ok, yellow = installing, red =
# needs manual action), everything else plain. Respects NO_COLOR and skips
# color entirely when not attached to a terminal.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  DIM=$'\033[2m'; BOLD=$'\033[1m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  DIM=""; BOLD=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; RESET=""
fi
TAG="${DIM}dotfiles${RESET}"

THEME=""
for arg in "$@"; do
  case "$arg" in
    --theme=*) THEME="${arg#--theme=}" ;;
    --theme)
      echo "Usage: --theme=<name> (e.g. --theme=everforest). See theme/palettes/ for options." >&2
      exit 1
      ;;
  esac
done
if [ -z "$THEME" ] && [ -f "$DOTFILES_DIR/theme/current" ]; then
  THEME="$(cat "$DOTFILES_DIR/theme/current")"
fi
THEME="${THEME:-pastel-green}"

INSTALLED=()   # things that needed installing this run
SKIPPED=()     # things that needed manual action (no installer available)

installed() { INSTALLED+=("$1"); echo "$TAG ${YELLOW}installed${RESET} $1"; }
skipped()   { SKIPPED+=("$1: $2"); echo "$TAG ${RED}skipped${RESET}  $1 - $2"; }

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dest"
}

echo "$TAG ${BOLD}setting up${RESET} $(basename "$DOTFILES_DIR")"

# --- prerequisites -----------------------------------------------------

if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null
  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  installed "Homebrew"
fi

if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh >/dev/null
  export PATH="$HOME/.local/bin:$PATH"
  installed "mise"
fi

# --- Homebrew packages (Brewfile) --------------------------------------

# brew bundle list returns tap-qualified names (e.g. atlassian/acli/acli)
# while brew list returns bare names (acli) - compare basenames so already-
# installed tapped formulae aren't reported as new.
new_pkgs="$(comm -23 \
  <(brew bundle list --file="$DOTFILES_DIR/Brewfile" 2>/dev/null | sed 's#.*/##' | sort) \
  <(brew list --formula -1 2>/dev/null | sort))"
if [ "$(uname)" = "Darwin" ]; then
  new_pkgs="$new_pkgs
$(comm -23 \
    <(brew bundle list --file="$DOTFILES_DIR/Brewfile" --casks 2>/dev/null | sed 's#.*/##' | sort) \
    <(brew list --cask -1 2>/dev/null | sort))"
fi
brew bundle install --file="$DOTFILES_DIR/Brewfile" --quiet >/dev/null
while IFS= read -r pkg; do
  [ -n "$pkg" ] && installed "$pkg"
done <<< "$new_pkgs"

# Homebrew Cask (ghostty, fonts) only works on macOS. On Linux, install the
# same things via the system package manager / direct download instead.
if [ "$(uname)" = "Linux" ]; then
  if ! command -v ghostty &>/dev/null; then
    if command -v pacman &>/dev/null; then
      sudo pacman -S --needed --noconfirm ghostty >/dev/null
      installed "ghostty"
    else
      skipped "ghostty" "no pacman found; see https://ghostty.org/docs/install/binary"
    fi
  fi

  # VS Code and Cursor aren't in Arch's official repos, only the AUR. Use
  # whichever AUR helper is present; otherwise print manual install links.
  aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  fi

  if ! command -v code &>/dev/null; then
    if [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm visual-studio-code-bin >/dev/null
      installed "visual-studio-code"
    else
      skipped "visual-studio-code" "no AUR helper found; see https://code.visualstudio.com/download"
    fi
  fi

  if ! command -v cursor &>/dev/null; then
    if [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm cursor-bin >/dev/null
      installed "cursor"
    else
      skipped "cursor" "no AUR helper found; see https://cursor.com/download"
    fi
  fi

  if ! fc-list | grep -qi "0xProto Nerd Font"; then
    font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    tmp_zip="$(mktemp)"
    curl -fsSL -o "$tmp_zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip"
    unzip -oq "$tmp_zip" -d "$font_dir"
    rm -f "$tmp_zip"
    fc-cache -f "$font_dir" &>/dev/null || true
    installed "0xProto Nerd Font"
  fi
fi

# --- theme + configs -----------------------------------------------------

if [ ! -f "$DOTFILES_DIR/theme/palettes/$THEME.toml" ]; then
  echo "Unknown theme '$THEME'. Available:" >&2
  ls "$DOTFILES_DIR/theme/palettes" | sed 's/\.toml$//' | sed 's/^/  /' >&2
  exit 1
fi
theme_out="$(python3 "$DOTFILES_DIR/theme/generate-theme.py" "$THEME")"
echo "$theme_out" | sed "s/^/$TAG ${CYAN}theme${RESET}   /"

link "$DOTFILES_DIR/config/vscode/dotfiles-theme" "$HOME/.vscode/extensions/dotfiles-theme"
link "$DOTFILES_DIR/config/vscode/dotfiles-theme" "$HOME/.cursor/extensions/dotfiles-theme"
link "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
link "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zprofile" "$HOME/.zprofile"
link "$DOTFILES_DIR/bashrc" "$HOME/.bashrc"
link "$DOTFILES_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
link "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"

if command -v mise &>/dev/null; then
  mise install
fi

agent_skills_dir="$HOME/.agents/skills"
if [ ! -d "$agent_skills_dir" ] || [ -z "$(ls -A "$agent_skills_dir" 2>/dev/null)" ]; then
  if command -v mise &>/dev/null; then
    mise exec -- npx --yes skills add addyosmani/agent-skills -g -a '*' -y >/dev/null 2>&1 || true
    installed "agent skills (addyosmani/agent-skills)"
  fi
fi

claude_settings="$HOME/.claude/settings.json"
if [ -f "$claude_settings" ] && command -v jq &>/dev/null; then
  tmp=$(mktemp)
  jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 60}' \
    "$claude_settings" > "$tmp" && mv "$tmp" "$claude_settings"
else
  mkdir -p "$HOME/.claude"
  cat > "$claude_settings" <<'JSON'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 60
  }
}
JSON
fi

# --- summary -----------------------------------------------------------

echo ""
if [ "${#INSTALLED[@]}" -eq 0 ]; then
  echo "$TAG ${GREEN}✓${RESET} everything already installed - re-applied theme ${BOLD}$THEME${RESET} and configs"
else
  echo "$TAG ${GREEN}✓${RESET} installed: ${BOLD}${INSTALLED[*]}${RESET}"
fi
if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo "$TAG ${RED}!${RESET} needs manual install:"
  printf "$TAG     ${RED}-${RESET} %s\n" "${SKIPPED[@]}"
fi
echo "$TAG ${GREEN}done${RESET}"
