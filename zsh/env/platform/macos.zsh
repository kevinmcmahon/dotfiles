# MacOS specific environment variables
export HOMEBREW_NO_AUTO_UPDATE=1

# Source deno environment if it exists
if [ -f "/Users/kevin/.deno/env" ]; then
  source "/Users/kevin/.deno/env"
fi
