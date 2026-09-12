tap "atlassian/acli"
tap "hashicorp/tap"
# GitHub command-line tool
brew "gh"
# Software to interact with Atlassian Cloud from the terminal
brew "atlassian/acli/acli", trusted: true
# Vault
brew "hashicorp/tap/vault", trusted: true
# Cross-shell prompt used by .zshrc/.bashrc
brew "starship"
# Polyglot runtime version manager (manages node, etc. - see zshrc/bashrc).
# Installed via mise.run in install.sh instead of brew - the Homebrew formula
# is slower/larger since it builds from source rather than using mise's own
# precompiled binary.

# Casks are macOS-only (Homebrew Cask doesn't support Linux). On Linux these
# are installed by install.sh via the system package manager instead.
if OS.mac?
  # Terminal emulator that uses platform-native UI and GPU acceleration
  cask "ghostty"
  # Font used by Ghostty config
  cask "font-0xproto-nerd-font"
  # Editors
  cask "visual-studio-code"
  cask "cursor"
end
