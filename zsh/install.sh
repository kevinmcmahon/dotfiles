#!/usr/bin/env bash

# Define base directories
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ZSH_CONFIG_DIR="$HOME/.zsh"

# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Remove stock zsh files
rm -f "$HOME/.zprofile" "$HOME/.zshrc"

# Create directory structure
mkdir -p "$ZSH_CONFIG_DIR/env/"{core,platform,optional}

# Define arrays of files to symlink
declare -A SYMLINKS=(
    ["$DOTFILES_DIR/zsh/zshrc.symlink"]="$HOME/.zshrc"
    ["$DOTFILES_DIR/zsh/zprofile.symlink"]="$HOME/.zprofile"
    ["$DOTFILES_DIR/zsh/env/core/functions.zsh"]="$ZSH_CONFIG_DIR/env/core/functions.zsh"
    ["$DOTFILES_DIR/zsh/env/core/history.zsh"]="$ZSH_CONFIG_DIR/env/core/history.zsh"
    ["$DOTFILES_DIR/zsh/env/core/language.zsh"]="$ZSH_CONFIG_DIR/env/core/language.zsh"
    ["$DOTFILES_DIR/zsh/env/core/path.zsh"]="$ZSH_CONFIG_DIR/env/core/path.zsh"
    ["$DOTFILES_DIR/zsh/env/platform/macos.zsh"]="$ZSH_CONFIG_DIR/env/platform/macos.zsh"
    ["$DOTFILES_DIR/zsh/env/platform/linux.zsh"]="$ZSH_CONFIG_DIR/env/platform/linux.zsh"
)

# Create symlinks
for src in "${!SYMLINKS[@]}"; do
    dst="${SYMLINKS[$src]}"
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$dst")"
    
    # Backup existing file if it's not a symlink
    if [[ -f "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "$dst.backup"
        echo "Backed up $dst to $dst.backup"
    fi
    
    # Create symlink
    ln -sf "$src" "$dst"
    echo "Created symlink: $dst -> $src"
done

# Install custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install git-open plugin
if [ ! -d "$ZSH_CUSTOM/plugins/git-open" ]; then
    echo "Installing git-open plugin..."
    git clone https://github.com/paulirish/git-open.git "$ZSH_CUSTOM/plugins/git-open"
fi

# Link custom aliases
ln -sf "$DOTFILES_DIR/zsh/alias.zsh" "$ZSH_CUSTOM/alias.zsh"

# Reload zsh configuration
echo "Reloading zsh configuration..."
exec zsh

echo "Installation complete! 🎉"
