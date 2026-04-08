# Linux-specific environment variables
#
# Most Linux usage here is remote and headless over SSH/tmux, so avoid forcing
# DISPLAY globally. Add GUI-specific overrides in ~/.zsh/env/optional/local.zsh
# on machines that actually need them.

# keychain: SSH/GPG agent manager - reuses agents across shell sessions
# Only run if keychain is installed and we have SSH identities
if command -v keychain &>/dev/null && [[ -d "$HOME/.ssh/identities" ]]; then
  local ssh_keys=()
  for key in "$HOME/.ssh/identities"/*; do
    [[ -f "$key" && "$key" != *.pub ]] && ssh_keys+=("$key")
  done

  if (( ${#ssh_keys[@]} )); then
    eval "$(keychain --eval --quiet --agents ssh "${ssh_keys[@]}")"
  fi
fi
