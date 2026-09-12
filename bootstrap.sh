#!/usr/bin/env bash
# Fetches this repo as a zip from GitHub (no git/SSH key required) and runs
# install.sh from it. Safe to re-run: updates in place.
#
#   curl -fsSL https://raw.githubusercontent.com/ericnkatz/dotfiles/main/bootstrap.sh | bash
#
# Any args are forwarded to install.sh, e.g.:
#   curl -fsSL .../bootstrap.sh | bash -s -- --theme=tokyo-night
set -euo pipefail

REPO="ericnkatz/dotfiles"
BRANCH="main"
DEST="${DOTFILES_DIR:-$HOME/dotfiles}"

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.zip" -o "$tmp/dotfiles.zip"
  unzip -q "$tmp/dotfiles.zip" -d "$tmp"

  rm -rf "$DEST"
  mv "$tmp/${REPO#*/}-$BRANCH" "$DEST"
fi

exec "$DEST/install.sh" "$@"
