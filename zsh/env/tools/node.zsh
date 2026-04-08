if command -v fnm >/dev/null 2>&1; then
  # `fnm env` exposes the current default version and installs the cd hook.
  # Avoid `fnm use --install-if-missing` during shell startup: it adds latency
  # and can mutate runtime state just by opening a shell.
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
