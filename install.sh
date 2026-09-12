#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    echo "Backed up existing $dest"
  fi
  ln -sfn "$src" "$dest"
  echo "Linked $dest -> $src"
}

if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

if ! command -v mise &>/dev/null; then
  echo "Installing mise via mise.run (faster/smaller than the Homebrew formula)..."
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "Installing/checking Homebrew packages from Brewfile..."
brew bundle install --file="$DOTFILES_DIR/Brewfile"

# Homebrew Cask (ghostty, fonts) only works on macOS. On Linux, install the
# same things via the system package manager / direct download instead.
if [ "$(uname)" = "Linux" ]; then
  if command -v pacman &>/dev/null; then
    echo "Linux detected with pacman (e.g. Arch) - installing Ghostty via pacman..."
    sudo pacman -S --needed --noconfirm ghostty
  else
    echo "Non-pacman Linux detected - install Ghostty yourself (see https://ghostty.org/docs/install/binary)."
  fi

  # VS Code and Cursor aren't in Arch's official repos, only the AUR. Use
  # whichever AUR helper is present; otherwise print manual install links.
  aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  fi
  if [ -n "$aur_helper" ]; then
    echo "Installing VS Code and Cursor via $aur_helper (AUR)..."
    "$aur_helper" -S --needed --noconfirm visual-studio-code-bin cursor-bin
  else
    echo "No AUR helper (yay/paru) found - install VS Code and Cursor yourself:"
    echo "  https://code.visualstudio.com/download"
    echo "  https://cursor.com/download"
  fi

  if ! fc-list | grep -qi "0xProto Nerd Font"; then
    echo "Downloading 0xProto Nerd Font..."
    font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"
    tmp_zip="$(mktemp)"
    curl -fsSL -o "$tmp_zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip"
    unzip -oq "$tmp_zip" -d "$font_dir"
    rm -f "$tmp_zip"
    fc-cache -f "$font_dir" &>/dev/null || true
  fi
fi

if [ -n "$THEME" ]; then
  if [ ! -f "$DOTFILES_DIR/theme/palettes/$THEME.toml" ]; then
    echo "Unknown theme '$THEME'. Available:" >&2
    ls "$DOTFILES_DIR/theme/palettes" | sed 's/\.toml$//' | sed 's/^/  /' >&2
    exit 1
  fi
  echo "Generating theme: $THEME"
  python3 "$DOTFILES_DIR/theme/generate-theme.py" "$THEME"
fi

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
  echo "Installing tool versions from mise config..."
  mise install
fi

if command -v mise &>/dev/null; then
  echo "Installing agent skills (addyosmani/agent-skills) for Claude/Cursor/Codex..."
  mise exec -- npx --yes skills add addyosmani/agent-skills -g -a '*' -y || true
fi

claude_settings="$HOME/.claude/settings.json"
if [ -f "$claude_settings" ] && command -v jq &>/dev/null; then
  tmp=$(mktemp)
  jq '.statusLine = {"type": "command", "command": "~/.claude/statusline.sh", "refreshInterval": 60}' \
    "$claude_settings" > "$tmp" && mv "$tmp" "$claude_settings"
  echo "Set statusLine in $claude_settings"
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
  echo "Created $claude_settings with statusLine"
fi

echo "Done."
