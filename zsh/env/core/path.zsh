# Build PATH from scratch with priorities clearly visible
# Detect platform once
_is_macos=false
[[ "$(uname -s)" == "Darwin" ]] && _is_macos=true

# Build PATH from scratch with priorities clearly visible
PATH=""

# Highest priority first
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin"
[[ -d "$HOME/.fzf/bin" ]] && PATH="$PATH:$HOME/.fzf/bin"

# Rust (rustup) — authoritative for Rust toolchains
[[ -d "$HOME/.cargo/bin" ]] && PATH="$PATH:$HOME/.cargo/bin"

# fnm (Fast Node Manager) — Node.js version management
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

# Homebrew (macOS Apple Silicon only) — add explicitly to preserve ordering
if $_is_macos; then
  [[ -d "/opt/homebrew/bin"  ]] && PATH="$PATH:/opt/homebrew/bin"
  [[ -d "/opt/homebrew/sbin" ]] && PATH="$PATH:/opt/homebrew/sbin"
fi

# macOS-specific tool paths
if $_is_macos; then
  [[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] && PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
  [[ -d "/Library/TeX/texbin" ]] && PATH="$PATH:/Library/TeX/texbin"
fi

# Cross-platform custom tools
[[ -d "$HOME/tools" ]] && PATH="$PATH:$HOME/tools"

# Bun
[[ -d "$HOME/.bun/bin" ]] && PATH="$PATH:$HOME/.bun/bin"

# OpenCode
[[ -d "$HOME/.opencode/bin" ]] && PATH="$PATH:$HOME/.opencode/bin"

# Go (official install)
if [[ -d "/usr/local/go/bin" ]]; then
  PATH="$PATH:/usr/local/go/bin"
  export GOPATH="$HOME/go"
  export GOBIN="$GOPATH/bin"
  [[ -d "$GOBIN" ]] && PATH="$PATH:$GOBIN"
fi

# System paths
PATH="$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

export PATH
unset _is_macos
