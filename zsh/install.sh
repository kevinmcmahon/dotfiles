#!/usr/bin/env bash
set -eo pipefail

# -----------------------------
# Configuration
# -----------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CONFIG_DIR="$HOME/.zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# -----------------------------
# Utilities
# -----------------------------
clone_if_missing() {
  local repo=$1
  local dest=$2
  if [ ! -d "$dest" ]; then
    echo "📦 Installing $(basename "$dest") plugin..."
    git clone "$repo" "$dest"
  else
    echo "✅ $(basename "$dest") already installed. Skipping."
  fi
}

# -----------------------------
# Check dependencies
# -----------------------------
for cmd in git curl zsh; do
  if ! command -v $cmd &>/dev/null; then
    echo "❌ Error: $cmd is required but not installed."
    exit 1
  fi
done

# -----------------------------
# Install Homebrew (macOS only)
# -----------------------------
if [[ "$OSTYPE" == "darwin"* && ! -x /opt/homebrew/bin/brew ]]; then
  echo "🍺 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# -----------------------------
# Install oh-my-zsh
# -----------------------------
if [[ ! -s "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
  echo "🌀 Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# -----------------------------
# Remove stock configs
# -----------------------------
rm -f "$HOME/.zprofile" "$HOME/.zshrc"

# -----------------------------
# Directory structure
# -----------------------------
mkdir -p "$ZSH_CONFIG_DIR/env/"{core,platform,optional}

# -----------------------------
# Symlinks
# -----------------------------
declare -A SYMLINKS=(
  ["$DOTFILES_DIR/zsh/zshrc.symlink"]="$HOME/.zshrc"
  ["$DOTFILES_DIR/zsh/zprofile.symlink"]="$HOME/.zprofile"
  ["$DOTFILES_DIR/zsh/zshenv.symlink"]="$HOME/.zshenv"
  ["$DOTFILES_DIR/zsh/env/core/functions.zsh"]="$ZSH_CONFIG_DIR/env/core/functions.zsh"
  ["$DOTFILES_DIR/zsh/env/core/history.zsh"]="$ZSH_CONFIG_DIR/env/core/history.zsh"
  ["$DOTFILES_DIR/zsh/env/core/language.zsh"]="$ZSH_CONFIG_DIR/env/core/language.zsh"
  ["$DOTFILES_DIR/zsh/env/core/path.zsh"]="$ZSH_CONFIG_DIR/env/core/path.zsh"
  ["$DOTFILES_DIR/zsh/env/platform/macos.zsh"]="$ZSH_CONFIG_DIR/env/platform/macos.zsh"
  ["$DOTFILES_DIR/zsh/env/platform/linux.zsh"]="$ZSH_CONFIG_DIR/env/platform/linux.zsh"
)

for src in "${!SYMLINKS[@]}"; do
  dst="${SYMLINKS[$src]}"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "$dst.backup"
    echo "🗂️  Backed up $dst to $dst.backup"
  fi
  ln -sf "$src" "$dst"
  echo "🔗 Created symlink: $dst → $src"
done

# -----------------------------
# Install plugins
# -----------------------------
clone_if_missing https://github.com/paulirish/git-open.git "$ZSH_CUSTOM/plugins/git-open"
clone_if_missing https://github.com/romkatv/zsh-defer.git "$ZSH_CUSTOM/plugins/zsh-defer"

# -----------------------------
# Link alias file
# -----------------------------
ln -sf "$DOTFILES_DIR/zsh/alias.zsh" "$ZSH_CUSTOM/alias.zsh"

# -----------------------------
# Done! Optionally reload shell
# -----------------------------
if [[ -t 1 ]]; then
  echo "✅ Zsh environment installed. Launching shell..."
  exec zsh
else
  echo "✅ Zsh environment installed. Start a new shell to begin using it."
fi
