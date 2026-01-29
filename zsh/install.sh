#!/usr/bin/env bash
set -eo pipefail

# -----------------------------
# Configuration
# -----------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# -----------------------------
# Utilities
# -----------------------------
clone_if_missing() {
  local repo=$1
  local dest=$2
  if [ ! -d "$dest" ]; then
    echo "Installing $(basename "$dest") plugin..."
    git clone --depth 1 "$repo" "$dest"
  else
    echo "$(basename "$dest") already installed. Skipping."
  fi
}

# -----------------------------
# Check dependencies
# -----------------------------
for cmd in git curl zsh; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# -----------------------------
# Install Homebrew (macOS only)
# -----------------------------
if [[ "$OSTYPE" == "darwin"* ]] && ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# -----------------------------
# Install oh-my-zsh
# -----------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# -----------------------------
# Remove stock configs
# -----------------------------
rm -f "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zshenv"

# Normalize ~/.zsh to be a directory (not a symlink)
if [[ -L "$HOME/.zsh" ]]; then
  rm -f "$HOME/.zsh"
elif [[ -d "$HOME/.zsh" ]]; then
  # keep directory; we'll refresh ~/.zsh/env inside it
  true
else
  rm -f "$HOME/.zsh" 2>/dev/null || true
fi
mkdir -p "$HOME/.zsh"

# -----------------------------
# Symlinks
# -----------------------------
echo "Creating symlinks..."
ln -sf "$DOTFILES_DIR/zshrc.symlink" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/zprofile.symlink" "$HOME/.zprofile"
ln -sf "$DOTFILES_DIR/zshenv.symlink" "$HOME/.zshenv"

# macOS-style layout everywhere:
# ~/.zsh/env -> $DOTFILES_DIR/env
ln -snf "$DOTFILES_DIR/env" "$HOME/.zsh/env"

echo "Created symlinks:"
echo "  ~/.zshrc    -> $DOTFILES_DIR/zshrc.symlink"
echo "  ~/.zprofile -> $DOTFILES_DIR/zprofile.symlink"
echo "  ~/.zshenv   -> $DOTFILES_DIR/zshenv.symlink"
echo "  ~/.zsh/env  -> $DOTFILES_DIR/env"

# -----------------------------
# Install plugins
# -----------------------------
echo "Installing oh-my-zsh plugins..."
clone_if_missing https://github.com/paulirish/git-open.git "$ZSH_CUSTOM/plugins/git-open"
clone_if_missing https://github.com/romkatv/zsh-defer.git "$ZSH_CUSTOM/plugins/zsh-defer"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/MichaelAquilina/zsh-you-should-use.git "$ZSH_CUSTOM/plugins/you-should-use"
clone_if_missing https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"

# -----------------------------
# Link alias file
# -----------------------------
ln -sf "$DOTFILES_DIR/alias.zsh" "$ZSH_CUSTOM/alias.zsh"
echo "Linked alias.zsh to $ZSH_CUSTOM/alias.zsh"

# -----------------------------
# Set zsh as default shell
# -----------------------------
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
zsh_path="$(which zsh)"

if [[ "$current_shell" != "$zsh_path" ]]; then
  echo "Setting zsh as default login shell..."
  if chsh -s "$zsh_path"; then
    echo "Default shell changed to zsh"
  else
    echo "Warning: Could not change default shell. Run manually: chsh -s $zsh_path"
  fi
else
  echo "zsh is already the default shell"
fi

# -----------------------------
# Done
# -----------------------------
echo ""
echo "Zsh environment installed!"
echo ""
echo "Required tools (install separately):"
echo "  - starship (prompt)"
echo "  - zoxide (cd replacement)"
echo "  - fzf (fuzzy finder)"
echo "  - fd (find replacement)"
echo "  - bat (cat replacement)"
echo "  - eza (ls replacement)"
echo "  - nvim (editor)"
echo "  - direnv (directory environments)"
echo ""
if [[ -t 1 ]]; then
  echo "Launching new shell..."
  exec zsh
else
  echo "Start a new shell to begin using it."
fi
