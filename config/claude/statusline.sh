#!/usr/bin/env bash
# Claude Code statusline styled after ~/.config/starship.toml's pastel_green
# powerline theme, with LiteLLM gateway usage/budget as an extra segment.
set -uo pipefail

input=$(cat)

# Same palette as starship.toml [palettes.pastel_green]
# BEGIN GENERATED THEME (do not edit; run theme/generate-theme.py)
RED="180;190;230"  # #b4bee6
PEACH="157;166;205"  # #9da6cd
YELLOW="134;143;180"  # #868fb4
GREEN="111;119;154"  # #6f779a
SAPPHIRE="88;96;129"  # #586081
LAVENDER="65;72;104"  # #414868
CRUST="26;27;38"  # #1a1b26
# END GENERATED THEME

R="\033[0m"
CAP=$''   # opening powerline cap
ARROW=$'' # powerline transition/closing arrow

bg() { printf "\033[48;2;%sm" "$1"; }
fg() { printf "\033[38;2;%sm" "$1"; }

last_bg=""
out=""

# Opening cap: fg = first segment's color, on the terminal's own background.
open_cap() {
  out+="$(fg "$1")${CAP}${R}"
  last_bg="$1"
}

# Transition arrow: fg = previous segment's bg, bg = next segment's bg.
arrow_to() {
  out+="$(fg "$last_bg")$(bg "$1")${ARROW}${R}"
  last_bg="$1"
}

segment() {
  local color="$1" text="$2"
  out+="$(bg "$color")$(fg "$CRUST") ${text} ${R}"
}

# --- gather data ---
model=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')
cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty')
ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

dir_display=""
if [[ -n "$cwd" ]]; then
  display_path="$cwd"
  [[ "$display_path" == "$HOME"* ]] && display_path="~${display_path#$HOME}"
  dir_display=$(printf '%s' "$display_path" | awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) if ($i != "") parts[++n] = $i
    if (n <= 3) {
      out = parts[1]
      for (i = 2; i <= n; i++) out = out "/" parts[i]
      print out
    } else {
      printf "…/%s/%s/%s", parts[n-2], parts[n-1], parts[n]
    }
  }')
fi

branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [[ -n "$branch" ]] && [[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]]; then
    branch="${branch} *"
  fi
fi

usage=""
usage_tier="neutral"
metric_cmd="/usr/local/bin/litellm-metric.sh"
if [[ -x "$metric_cmd" ]]; then
  # litellm-metric.sh's multi-field metrics (period/pct/tier/today) use \x01
  # as an IFS separator, which macOS's bash 3.2 drops during word-splitting,
  # so they return nothing there. period-spend/period-budget are single
  # fields and unaffected; compute the rest ourselves from those.
  period_spend=$("$metric_cmd" period-spend 2>/dev/null)
  period_budget=$("$metric_cmd" period-budget 2>/dev/null)
  if [[ -n "$period_spend" ]]; then
    usage="$period_spend"
    if [[ -n "$period_budget" ]]; then
      usage="${period_spend}/${period_budget}"
      spend_num="${period_spend#\$}"
      budget_num="${period_budget#\$}"
      pct=$(awk -v s="$spend_num" -v b="$budget_num" 'BEGIN { if (b > 0) printf "%.0f%%", (s / b) * 100 }')
      [[ -n "$pct" ]] && usage="${usage} (${pct})"
      usage_tier=$(awk -v s="$spend_num" -v b="$budget_num" 'BEGIN {
        if (b <= 0) { print "neutral"; exit }
        r = s / b
        if (r >= 1) print "crit"
        else if (r >= 0.85) print "red"
        else print "green"
      }')
    fi
  fi
fi

now=$(date +%R)

# --- render ---
open_cap "$RED"
segment "$RED" " ${model}"

if [[ -n "$dir_display" ]]; then
  arrow_to "$PEACH"
  segment "$PEACH" " ${dir_display}"
fi

if [[ -n "$branch" ]]; then
  arrow_to "$YELLOW"
  segment "$YELLOW" " ${branch}"
fi

if [[ -n "${ctx_pct:-}" ]]; then
  arrow_to "$GREEN"
  segment "$GREEN" "ctx ${ctx_pct}%"
fi

if [[ -n "$usage" ]]; then
  arrow_to "$SAPPHIRE"
  case "$usage_tier" in
    crit) usage_color="\033[1;38;2;255;60;60m" ;;
    red)  usage_color="\033[38;2;224;108;117m" ;;
    *)    usage_color="" ;;
  esac
  if [[ -n "$usage_color" ]]; then
    out+="$(bg "$SAPPHIRE")${usage_color} \$ ${usage} ${R}"
    last_bg="$SAPPHIRE"
  else
    segment "$SAPPHIRE" "\$ ${usage}"
  fi
fi

arrow_to "$LAVENDER"
segment "$LAVENDER" " ${now}"

out+="$(fg "$LAVENDER")${ARROW}${R}"

printf "%b" "$out"
