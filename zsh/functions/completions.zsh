# ~/dotfiles/zsh/functions/completions.zsh
# Adds tab-completion for SSH-related utilities

# --- ssh-use: Complete with keys in ~/.ssh/identities (non-pub) ---
# ~/.zsh/functions/completions.zsh or inline near ssh-use

# --- ssh-test: Complete with host aliases from ~/.ssh/config.d ---
_ssh_test_complete() {
  local -a aliases
  aliases=(${(f)"$(grep -h '^Host ' ~/.ssh/config.d/* 2>/dev/null | awk '{print $2}' | sort -u)"})
  compadd -- $aliases
}
compdef _ssh_test_complete ssh-test

# --- ssh-git-id: Only has a single optional flag
_ssh_git_id_complete() {
  _arguments '--fix[Apply the suggested fix to the Git remote URL]'
}
compdef _ssh_git_id_complete ssh-git-id

_ssh_use_complete() {
  local keys
  keys=(${(f)"$(find ~/.ssh/identities -type f ! -name '*.pub' -exec basename {} \; 2>/dev/null)"})
  compadd -- "${keys[@]}"
}
compdef _ssh_use_complete ssh-use


