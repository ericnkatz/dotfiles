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
fi

echo "Installing/checking Homebrew packages from Brewfile..."
brew bundle install --file="$DOTFILES_DIR/Brewfile"

link "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zprofile" "$HOME/.zprofile"
link "$DOTFILES_DIR/bashrc" "$HOME/.bashrc"

echo "Done."
