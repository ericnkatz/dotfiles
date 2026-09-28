export PATH="$HOME/.local/bin:$PATH"
for gcloud_sdk_bin in /opt/homebrew/share/google-cloud-sdk/bin /usr/local/share/google-cloud-sdk/bin; do
  [[ -d "$gcloud_sdk_bin" ]] && export PATH="$gcloud_sdk_bin:$PATH"
done
if [[ $- == *i* && ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init bash)"
fi
eval "$(mise activate bash)"
