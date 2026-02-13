# MacOS specific environment variables
export HOMEBREW_NO_AUTO_UPDATE=1

# Source deno environment if it exists
if [ -f "$HOME/.deno/env" ]; then
  source "$HOME/.deno/env"
fi
