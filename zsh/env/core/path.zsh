# Build PATH from scratch with priorities clearly visible
PATH=""

# Highest priority first
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin"
[[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]] && PATH="$PATH:${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
[[ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]] && PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
[[ -d "$HOME/tools" ]] && PATH="$PATH:$HOME/tools"
[[ -d "/Library/TeX/texbin" ]] && PATH="${PATH}:/Library/TeX/texbin"

# System paths
PATH="$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Homebrew (high priority)
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH
