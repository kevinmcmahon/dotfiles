# chruby — Ruby version manager
# Sourced automatically by load_env_dir in zshrc

# Find chruby.sh (Linux: make install → /usr/local/share; macOS: Homebrew)
local _chruby_sh=""
for _candidate in \
  /usr/local/share/chruby/chruby.sh \
  /usr/share/chruby/chruby.sh \
  /opt/homebrew/opt/chruby/share/chruby/chruby.sh \
  /usr/local/opt/chruby/share/chruby/chruby.sh; do
  if [[ -f "$_candidate" ]]; then
    _chruby_sh="$_candidate"
    break
  fi
done

if [[ -n "$_chruby_sh" ]]; then
  source "$_chruby_sh"
  # auto.sh enables .ruby-version detection
  source "${_chruby_sh%chruby.sh}auto.sh"
fi

unset _chruby_sh _candidate
