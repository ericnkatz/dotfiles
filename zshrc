export PATH="$HOME/.local/bin:$PATH"
if [[ -o interactive && ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init zsh)"
fi
eval "$(mise activate zsh)"
