# Work WSL SSH agent setup.
#
# Add one private key path per line to ~/.work-wsl/ssh-keys, or set
# WORK_WSL_SSH_KEYS to a colon-separated list of private key paths.
if (( $+commands[keychain] )); then
  typeset -a _work_wsl_ssh_keys _work_wsl_ssh_keys_present
  _work_wsl_ssh_keys=()

  if [[ -n "${WORK_WSL_SSH_KEYS:-}" ]]; then
    _work_wsl_ssh_keys+=("${(@s/:/)WORK_WSL_SSH_KEYS}")
  fi

  if [[ -f "$HOME/.work-wsl/ssh-keys" ]]; then
    typeset _work_wsl_key
    while IFS= read -r _work_wsl_key; do
      _work_wsl_key="${_work_wsl_key%%#*}"
      _work_wsl_key="${_work_wsl_key#"${_work_wsl_key%%[![:space:]]*}"}"
      _work_wsl_key="${_work_wsl_key%"${_work_wsl_key##*[![:space:]]}"}"
      [[ -n "$_work_wsl_key" ]] && _work_wsl_ssh_keys+=("$_work_wsl_key")
    done < "$HOME/.work-wsl/ssh-keys"
  fi

  typeset _work_wsl_key
  for _work_wsl_key in $_work_wsl_ssh_keys; do
    [[ "$_work_wsl_key" == "~/"* ]] && _work_wsl_key="$HOME/${_work_wsl_key#~/}"
    [[ -f "$_work_wsl_key" ]] && _work_wsl_ssh_keys_present+=("$_work_wsl_key")
  done

  if (( ${#_work_wsl_ssh_keys_present} )); then
    eval "$(keychain --eval --quiet --agents ssh $_work_wsl_ssh_keys_present)"
  fi

  unset _work_wsl_ssh_keys _work_wsl_ssh_keys_present _work_wsl_key
fi
