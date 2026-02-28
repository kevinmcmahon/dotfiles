# ABOUTME: Builds PATH with correct priority ordering using zsh array syntax.
# ABOUTME: Safe to re-source — typeset -U deduplicates, $path preserves dynamic entries.

# Detect platform once
_is_macos=false
[[ "$(uname -s)" == "Darwin" ]] && _is_macos=true

# Auto-deduplicate PATH entries (keeps first occurrence)
typeset -U path

# Save existing dynamic entries (fnm, oh-my-zsh, etc.) before rebuilding
local -a _existing=("${path[@]}")

# Highest priority first
path=(
  "$HOME/.local/bin"
  "$HOME/.fzf/bin"
  "$HOME/.cargo/bin"
)

# Homebrew (macOS Apple Silicon only) — add explicitly to preserve ordering
if $_is_macos; then
  [[ -d "/opt/homebrew/bin"  ]] && path+=("/opt/homebrew/bin")
  [[ -d "/opt/homebrew/sbin" ]] && path+=("/opt/homebrew/sbin")
fi

# macOS-specific tool paths
if $_is_macos; then
  [[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] && path+=("$HOME/Library/Application Support/JetBrains/Toolbox/scripts")
  [[ -d "/Library/TeX/texbin" ]] && path+=("/Library/TeX/texbin")
fi

# Cross-platform custom tools
[[ -d "$HOME/tools" ]] && path+=("$HOME/tools")

# Bun
[[ -d "$HOME/.bun/bin" ]] && path+=("$HOME/.bun/bin")

# Deno
[[ -d "$HOME/.deno/bin" ]] && path+=("$HOME/.deno/bin")

# Go (official install)
if [[ -d "/usr/local/go/bin" ]]; then
  path+=("/usr/local/go/bin")
  export GOPATH="$HOME/go"
  export GOBIN="$GOPATH/bin"
  [[ -d "$GOBIN" ]] && path+=("$GOBIN")
fi

# Restore previously-existing entries (fnm, oh-my-zsh plugins, etc.)
# then append system paths at lowest priority.
# typeset -U ensures no duplicates — our entries above win because they're first.
path+=(
  "${_existing[@]}"
  /usr/local/bin
  /usr/bin
  /bin
  /usr/sbin
  /sbin
)

export PATH
unset _is_macos
