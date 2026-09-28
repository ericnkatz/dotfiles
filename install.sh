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

# Guard against Ctrl-C leaving the cursor hidden mid-spin.
trap 'tput cnorm 2>/dev/null' EXIT

THEME=""
THEME_WAS_PASSED=false
EMULATE=false
PICK_THEME=false
GRADSTOP=false
for arg in "$@"; do
  case "$arg" in
    --theme=*) THEME="${arg#--theme=}"; THEME_WAS_PASSED=true ;;
    --theme)
      echo "Usage: --theme=<name> (e.g. --theme=everforest). See theme/palettes/ for options." >&2
      exit 1
      ;;
    --themes) PICK_THEME=true ;;
    # Approximate powerline colors with a light_foreground->muted gradient
    # instead of the palette's own named colors (which --themes' swatch
    # previews and generate-theme.py uses by default).
    --gradstop) GRADSTOP=true ;;
    # Preview the spinner/status UX of a from-scratch macOS install with
    # simulated wait times, making no real changes to this machine.
    --emulate) EMULATE=true ;;
  esac
done

# Renders a palette's key colors as background-color blocks (not the real
# powerline glyphs) so --themes works without the Nerd Font installed.
theme_swatch() {
  local file="$1" key hex r g b out=""
  for key in red orange yellow green cyan blue magenta; do
    hex="$(grep -E "^${key}[[:space:]]*=" "$file" | head -1 \
      | sed -E 's/^[^=]+=[[:space:]]*"?(#[0-9a-fA-F]{6})"?.*/\1/')"
    [ -z "$hex" ] && continue
    hex="${hex#\#}"
    r=$((16#${hex:0:2})); g=$((16#${hex:2:2})); b=$((16#${hex:4:2}))
    out+="$(printf '\033[48;2;%d;%d;%dm  \033[0m' "$r" "$g" "$b")"
  done
  printf '%s' "$out"
}

# Lists every theme/palettes/*.toml with a swatch, prompts for a pick over
# /dev/tty (so this also works when install.sh is run via `curl | bash`),
# and sets THEME/THEME_WAS_PASSED so the rest of the script proceeds exactly
# as if --theme=<name> had been passed.
pick_theme_interactively() {
  if [ ! -r /dev/tty ]; then
    echo "$TAG ${RED}error${RESET}  --themes needs an interactive terminal (no /dev/tty available)" >&2
    exit 1
  fi

  local names=() f
  for f in "$DOTFILES_DIR"/theme/palettes/*.toml; do
    names+=("$(basename "$f" .toml)")
  done

  echo "$TAG Available themes:"
  local i=1 name
  for name in "${names[@]}"; do
    printf "  %2d) %-20s %s\n" "$i" "$name" "$(theme_swatch "$DOTFILES_DIR/theme/palettes/$name.toml")"
    i=$((i + 1))
  done

  local choice
  printf "%s Select a theme [1-%d]: " "$TAG" "${#names[@]}"
  read -r choice < /dev/tty
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#names[@]}" ]; then
    echo "$TAG ${RED}error${RESET}  invalid selection '$choice'" >&2
    exit 1
  fi

  THEME="${names[$((choice - 1))]}"
  THEME_WAS_PASSED=true
  echo "$TAG selected ${BOLD}$THEME${RESET}"
}

if [ "$PICK_THEME" = true ]; then
  pick_theme_interactively
fi

INSTALLED=()   # things that needed installing this run
SKIPPED=()     # things that needed manual action (no installer available)

installed() { INSTALLED+=("$1"); echo "$TAG ${YELLOW}installed${RESET} $1"; }
skipped()   { SKIPPED+=("$1: $2"); echo "$TAG ${RED}skipped${RESET}  $1 - $2"; }

# Waits on a backgrounded PID, animating a spinner and rotating through the
# given status messages every ~3s so long, silent installs (brew bundle,
# mise install) don't look hung. Skipped entirely when not attached to a
# terminal, since \r-driven redraws are meaningless in a log file.
spin() {
  local pid=$1; shift
  local messages=("$@")
  if [ ! -t 1 ]; then
    wait "$pid"
    return
  fi
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local i=0 msg_i=0 msg_ticks=0
  tput civis 2>/dev/null
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s ${CYAN}%s${RESET} %s" "$TAG" "${frames[$((i % ${#frames[@]}))]}" "${messages[$msg_i]}"
    sleep 0.1
    i=$((i + 1))
    msg_ticks=$((msg_ticks + 1))
    if [ "$msg_ticks" -ge 30 ] && [ "$((msg_i + 1))" -lt "${#messages[@]}" ]; then
      msg_i=$((msg_i + 1))
      msg_ticks=0
    fi
  done
  printf "\r\033[K"
  tput cnorm 2>/dev/null
  wait "$pid"
}

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dest"
}

# Walks through the same spinner/status output a real fresh macOS install
# would produce, but with synthetic sleeps standing in for every network
# call or installer (brew, mise, npx). Reads package names out of the real
# Brewfile so the summary is accurate, but never shells out to brew, mise,
# curl, or touches anything under $HOME - a pure UX preview.
emulate_install() {
  echo "$TAG ${BOLD}setting up${RESET} $(basename "$DOTFILES_DIR") ${DIM}(emulated fresh install, no changes made)${RESET}"

  sleep 10 &
  spin $! "installing Homebrew" "still installing Homebrew (this can take a minute)..."
  installed "Homebrew"

  sleep 6 &
  spin $! "installing mise"
  installed "mise"

  local formulae casks pkg
  formulae="$(grep -oE '^\s*brew "[^"]+"' "$DOTFILES_DIR/Brewfile" | sed -E 's/.*"([^"]+)".*/\1/' | sed 's#.*/##')"
  casks="$(grep -oE '^\s*cask "[^"]+"' "$DOTFILES_DIR/Brewfile" | sed -E 's/.*"([^"]+)".*/\1/')"

  sleep 20 &
  spin $! "installing packages from Brewfile" \
    "still installing packages (some casks are large downloads)..." \
    "almost there, finishing up package installs..."
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    installed "$pkg"
  done <<< "$formulae
$casks"

  sleep 8 &
  spin $! "installing tool versions via mise"

  sleep 5 &
  spin $! "installing agent skills"
  installed "agent skills (addyosmani/agent-skills)"

  echo "$TAG ${CYAN}theme${RESET}   applying theme ${BOLD}pastel-green${RESET} and linking configs ${DIM}(emulated)${RESET}"

  echo ""
  echo "$TAG ${GREEN}✓${RESET} installed: ${BOLD}${INSTALLED[*]}${RESET}"
  echo "$TAG ${GREEN}done${RESET} ${DIM}(emulated - re-run without --emulate for a real install)${RESET}"
}

if [ "$EMULATE" = true ]; then
  emulate_install
  exit 0
fi

echo "$TAG ${BOLD}setting up${RESET} $(basename "$DOTFILES_DIR")"

OS="$(uname)"
IS_OMARCHY=false
if [ "$OS" = "Linux" ] && command -v omarchy &>/dev/null; then
  IS_OMARCHY=true
fi

# --- prerequisites -----------------------------------------------------

# Omarchy is Arch-based and already provides a package-management facade. Do
# not install a second system package manager there. Homebrew remains the
# package manager for macOS and the fallback for other supported Linux hosts.
if [ "$IS_OMARCHY" = false ]; then
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &
    spin $! "installing Homebrew" "still installing Homebrew (this can take a minute)..."
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    installed "Homebrew"
  fi
fi

if ! command -v mise &>/dev/null; then
  (curl -fsSL https://mise.run | sh >/dev/null) &
  spin $! "installing mise"
  export PATH="$HOME/.local/bin:$PATH"
  installed "mise"
fi

# --- system packages ---------------------------------------------------

if [ "$IS_OMARCHY" = true ]; then
  for spec in "github-cli:gh" "starship:starship"; do
    pkg="${spec%%:*}"
    cmd="${spec#*:}"
    if ! command -v "$cmd" &>/dev/null; then
      omarchy pkg add "$pkg"
      installed "$pkg"
    fi
  done
else
  # brew bundle list returns tap-qualified names (e.g. atlassian/acli/acli)
  # while brew list returns bare names (acli) - compare basenames so already-
  # installed tapped formulae aren't reported as new.
  new_pkgs="$(comm -23 \
    <(brew bundle list --file="$DOTFILES_DIR/Brewfile" 2>/dev/null | sed 's#.*/##' | sort) \
    <(brew list --formula -1 2>/dev/null | sort))"
  if [ "$OS" = "Darwin" ]; then
    new_pkgs="$new_pkgs
$(comm -23 \
    <(brew bundle list --file="$DOTFILES_DIR/Brewfile" --casks 2>/dev/null | sed 's#.*/##' | sort) \
    <(brew list --cask -1 2>/dev/null | sort))"
  fi
  # || true: some casks (e.g. tailscale-app) install via a .pkg that needs
  # sudo in a real terminal; in a non-interactive context they'll fail but
  # the rest of install.sh should still run.
  (brew bundle install --file="$DOTFILES_DIR/Brewfile" --quiet >/dev/null || true) &
  spin $! "installing packages from Brewfile" \
    "still installing packages (some casks are large downloads)..." \
    "almost there, finishing up package installs..."
  # brew bundle check --verbose lists anything still missing after install
  # (e.g. a cask whose .pkg installer needs manual sudo/approval), so a
  # failed cask is reported as skipped rather than falsely claimed installed.
  still_missing="$(brew bundle check --file="$DOTFILES_DIR/Brewfile" --verbose 2>&1 \
    | sed -En 's/^→ (Formula|Cask) ([^ ]*) needs.*/\2/p' | sed 's#.*/##')"
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if grep -qxF "$pkg" <<< "$still_missing"; then
      skipped "$pkg" "brew bundle install failed; run 'brew bundle install' manually"
    else
      installed "$pkg"
    fi
  done <<< "$new_pkgs"
fi

# Homebrew Cask (ghostty, fonts) only works on macOS. On Linux, install the
# same things via the system package manager / direct download instead.
if [ "$OS" = "Linux" ]; then
  if ! command -v ghostty &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg add ghostty
      installed "ghostty"
    elif command -v pacman &>/dev/null; then
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
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add visual-studio-code-bin
      installed "visual-studio-code"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm visual-studio-code-bin >/dev/null
      installed "visual-studio-code"
    else
      skipped "visual-studio-code" "no AUR helper found; see https://code.visualstudio.com/download"
    fi
  fi

  if ! command -v cursor &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add cursor-bin
      installed "cursor"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm cursor-bin >/dev/null
      installed "cursor"
    else
      skipped "cursor" "no AUR helper found; see https://cursor.com/download"
    fi
  fi

  # 1Password has no official pacman repo - the desktop app and CLI are only
  # published to the AUR (1password.com/downloads/linux confirms AUR for Arch).
  if ! command -v 1password &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add 1password
      installed "1password"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm 1password >/dev/null
      installed "1password"
    else
      skipped "1password" "no AUR helper found; see https://1password.com/downloads/linux"
    fi
  fi

  if ! command -v op &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add 1password-cli
      installed "1password-cli"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm 1password-cli >/dev/null
      installed "1password-cli"
    else
      skipped "1password-cli" "no AUR helper found; see https://1password.com/downloads/linux"
    fi
  fi

  # Figma has no official Linux app; figma-linux is a community client
  # available only via the AUR.
  if ! command -v figma-linux &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add figma-linux
      installed "figma-linux"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm figma-linux >/dev/null
      installed "figma-linux"
    else
      skipped "figma-linux" "no AUR helper found; see https://github.com/Figma-Linux/figma-linux"
    fi
  fi

  # Not in the official Arch repos - only available via the AUR.
  if ! command -v gcloud &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg aur add google-cloud-cli
      installed "google-cloud-cli"
    elif [ -n "$aur_helper" ]; then
      "$aur_helper" -S --needed --noconfirm google-cloud-cli >/dev/null
      installed "google-cloud-cli"
    else
      skipped "google-cloud-cli" "no AUR helper found; see https://cloud.google.com/sdk/docs/install"
    fi
  fi

  if ! command -v tailscale &>/dev/null; then
    if [ "$IS_OMARCHY" = true ]; then
      omarchy pkg add tailscale
      installed "tailscale"
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --needed --noconfirm tailscale >/dev/null
      installed "tailscale"
    else
      skipped "tailscale" "no pacman found; see https://tailscale.com/download/linux"
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

AETHER_MANAGED=false
if [ "$IS_OMARCHY" = true ] && command -v aether &>/dev/null \
  && { [ "$THEME_WAS_PASSED" = true ] || [ -f "$HOME/.config/aether/theme/colors.toml" ]; }; then
  AETHER_MANAGED=true
fi

if [ "$AETHER_MANAGED" = true ] && [ "$THEME_WAS_PASSED" = false ]; then
  # With no explicit choice, preserve the palette currently active in Aether.
  THEME="aether"
  palette_path="$HOME/.config/aether/theme/colors.toml"
elif [ -z "$THEME" ] && [ -f "$DOTFILES_DIR/theme/current" ]; then
  THEME="$(cat "$DOTFILES_DIR/theme/current")"
fi
THEME="${THEME:-pastel-green}"

if [ -z "${palette_path:-}" ] && [ ! -f "$DOTFILES_DIR/theme/palettes/$THEME.toml" ]; then
  echo "Unknown theme '$THEME'. Available:" >&2
  ls "$DOTFILES_DIR/theme/palettes" | sed 's/\.toml$//' | sed 's/^/  /' >&2
  exit 1
fi

GRADSTOP_FLAG=()
[ "$GRADSTOP" = true ] && GRADSTOP_FLAG=(--gradstop)

if [ "$AETHER_MANAGED" = true ]; then
  if [ "$THEME_WAS_PASSED" = true ]; then
    # Aether applies this once to Omarchy and every application it supports.
    aether --import-colors-toml "$DOTFILES_DIR/theme/palettes/$THEME.toml"
    palette_path="$HOME/.config/aether/theme/colors.toml"
  fi
  theme_out="$(python3 "$DOTFILES_DIR/theme/generate-theme.py" "$THEME" \
    --palette "$palette_path" --starship-palette "$DOTFILES_DIR/theme/palettes/tokyo-night.toml" \
    --aether-managed "${GRADSTOP_FLAG[@]+"${GRADSTOP_FLAG[@]}"}")"
else
  theme_out="$(python3 "$DOTFILES_DIR/theme/generate-theme.py" "$THEME" "${GRADSTOP_FLAG[@]+"${GRADSTOP_FLAG[@]}"}")"
fi
echo "$theme_out" | sed "s/^/$TAG ${CYAN}theme${RESET}   /"

if [ "$AETHER_MANAGED" = false ]; then
  link "$DOTFILES_DIR/config/vscode/dotfiles-theme" "$HOME/.vscode/extensions/dotfiles-theme"
  link "$DOTFILES_DIR/config/vscode/dotfiles-theme" "$HOME/.cursor/extensions/dotfiles-theme"
  link "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
fi
link "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zprofile" "$HOME/.zprofile"
link "$DOTFILES_DIR/bashrc" "$HOME/.bashrc"
link "$DOTFILES_DIR/hushlogin" "$HOME/.hushlogin"
link "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"

if command -v codex &>/dev/null || [ -d "$HOME/.codex" ]; then
  link "$DOTFILES_DIR/config/codex/themes/dotfiles.tmTheme" "$HOME/.codex/themes/dotfiles.tmTheme"
fi

if command -v claude &>/dev/null || [ -d "$HOME/.claude" ]; then
  link "$DOTFILES_DIR/config/claude/statusline.sh" "$HOME/.claude/statusline.sh"
fi

if command -v mise &>/dev/null; then
  # Keep a newer Node that is already installed. Otherwise use the current
  # LTS. This machine-specific choice lives outside the tracked config so one
  # machine's Node version does not rewrite the dotfiles repository.
  node_config_dir="$HOME/.config/mise/conf.d"
  node_config="$node_config_dir/node.toml"
  current_node=""
  if command -v node &>/dev/null; then
    current_node="$(node -p 'process.versions.node' 2>/dev/null || true)"
  fi
  node_lts="$(mise latest node@lts)"
  node_choice="$node_lts"
  if [ -n "$current_node" ] && [ "$(printf '%s\n%s\n' "$node_lts" "$current_node" | sort -V | tail -n1)" = "$current_node" ]; then
    node_path="$(readlink -f "$(command -v node)")"
    if [[ "$node_path" == "$HOME/.local/share/mise/installs/node/"* ]]; then
      node_choice="$current_node"
    else
      node_choice="system"
    fi
  fi
  mkdir -p "$node_config_dir"
  printf '[tools]\nnode = "%s"\n' "$node_choice" > "$node_config"
  mise install &
  spin $! "installing tool versions via mise"
fi

agent_skills_dir="$HOME/.agents/skills"
if [ ! -d "$agent_skills_dir" ] || [ -z "$(ls -A "$agent_skills_dir" 2>/dev/null)" ]; then
  if command -v mise &>/dev/null; then
    (mise exec -- npx --yes skills add addyosmani/agent-skills -g -a '*' -y >/dev/null 2>&1 || true) &
    spin $! "installing agent skills"
    installed "agent skills (addyosmani/agent-skills)"
  fi
fi

if command -v claude &>/dev/null || [ -d "$HOME/.claude" ]; then
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
fi

if command -v codex &>/dev/null || [ -d "$HOME/.codex" ]; then
  python3 "$DOTFILES_DIR/config/codex/configure-statusline.py" "$HOME/.codex/config.toml"
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
