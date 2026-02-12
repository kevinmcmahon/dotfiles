# Node.js via fnm
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
  fnm use --install-if-missing default >/dev/null 2>&1
fi

# Python via uv (always available)
if command -v uv >/dev/null 2>&1; then
  python()  { uv run python "$@"; }
  python3() { uv run python "$@"; }
  pip()     { uv run pip "$@"; }
  pip3()    { uv run pip "$@"; }
fi

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
