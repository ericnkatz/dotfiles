#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

link "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zprofile" "$HOME/.zprofile"
link "$DOTFILES_DIR/bashrc" "$HOME/.bashrc"
link "$DOTFILES_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"

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
