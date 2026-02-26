if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
  fnm use --install-if-missing default >/dev/null 2>&1
fi
