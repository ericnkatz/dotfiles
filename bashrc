export PATH="$HOME/.local/bin:$PATH"
if [[ $- == *i* && ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init bash)"
fi
eval "$(mise activate bash)"
