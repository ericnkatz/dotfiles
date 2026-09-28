export PATH="$HOME/.local/bin:$PATH"
for gcloud_sdk_bin in /opt/homebrew/share/google-cloud-sdk/bin /usr/local/share/google-cloud-sdk/bin; do
  [[ -d "$gcloud_sdk_bin" ]] && export PATH="$gcloud_sdk_bin:$PATH"
done
if [[ -o interactive && ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init zsh)"
fi
eval "$(mise activate zsh)"
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
