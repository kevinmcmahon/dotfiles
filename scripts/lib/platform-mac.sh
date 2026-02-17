# shellcheck shell=bash
# scripts/lib/platform-mac.sh — macOS-specific bootstrap functions
#
# This file is SOURCED by bootstrap.sh AFTER common.sh — do not add a shebang
# or set -euo pipefail.
#
# It expects these globals from the sourcing script:
#   DOTFILES_DIR, LOCAL_BIN, CONFIG_DIR, INSTALL_NODE, PLATFORM, ARCH
#
# It uses these functions from common.sh:
#   log, warn, die, need_cmd, install_rustup

SKIP_DEFAULTS="${SKIP_DEFAULTS:-0}"

# ==============================================================================
# Platform Contract — Public Functions
# ==============================================================================

preflight_checks() {
  log "Running preflight checks"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script is for macOS only. Use bootstrap.sh on a Linux host."
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    die "Do not run this bootstrap with sudo. Run as your user; the script uses sudo internally."
  fi

  case "$ARCH" in
    arm64)  log "Detected Apple Silicon (arm64)" ;;
    x86_64) log "Detected Intel (x86_64)" ;;
    *)      die "Unsupported architecture: $ARCH" ;;
  esac
}

install_platform_foundation() {
  install_xcode_clt
  install_homebrew
  install_git_via_brew
}

install_platform_packages() {
  brew_bundle
  install_cask_apps
}

install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"

  install_rustup

  # --- viu (terminal image viewer) ---
  if need_cmd viu; then
    log "viu already installed: $(viu --version | head -n 1)"
  else
    log "Installing viu..."
    cargo install viu
    log "viu installed: $(viu --version | head -n 1)"
  fi

  # --- tectonic (LaTeX compiler) — use brew on macOS (cargo build has C dep issues) ---
  if need_cmd tectonic; then
    log "tectonic already installed: $(tectonic --version | head -n 1)"
  else
    log "Installing tectonic via brew..."
    brew install tectonic || warn "Failed to install tectonic"
  fi
}

set_default_shell_zsh() {
  # No-op on macOS: zsh/install.sh (called by install_zsh_environment in
  # common.sh) already handles changing the default shell via dscl on macOS.
  return 0
}

apply_platform_config() {
  if [[ "$SKIP_DEFAULTS" == "1" ]]; then
    log "Skipping macOS platform config (SKIP_DEFAULTS=1)"
    return 0
  fi

  apply_macos_defaults
  apply_spotlight_configs
}

post_checks_platform() {
  # Platform-specific checks not already covered by common.sh's post_checks.
  # common.sh already checks: git, tmux, nvim, rg, fd, fzf, bat, rustc,
  # cargo, uv, deno, fnm, node.
  need_cmd brew     || die "brew missing"
  need_cmd eza      || warn "eza missing"
  need_cmd zoxide   || warn "zoxide missing"
  need_cmd lazygit  || warn "lazygit missing"
  need_cmd starship || warn "starship missing"
  need_cmd yazi     || warn "yazi missing"
}

print_next_steps() {
  log "Bootstrap complete."
  log ""
  log "Next steps:"
  log "  1. Open a new shell (or exec zsh) so PATH updates apply"
  log "  2. Open Tailscale from Applications and sign in"
  log "  3. Configure your Git identity (REQUIRED for commits):"
  log "     Edit ~/.gituserconfig and uncomment/set your name and email"
  log "     (Optional) Edit ~/.gituserconfig.kmc and ~/.gituserconfig.nsv"
  log "     for project-specific identities"
  log "  4. Install Python versions with uv:"
  log "     uv python install 3.12"
  log "     uv python install 3.11"
  if [[ "$INSTALL_NODE" != "1" ]]; then
    log "  5. Install Node.js with fnm and enable corepack:"
    log "     fnm install --lts"
    log "     fnm use lts-latest"
    log "     fnm default lts-latest"
    log "     corepack enable"
    log "     (or re-run with INSTALL_NODE=1 to automate this)"
  fi
  log "  6. Install Ruby with ruby-install:"
  log "     ruby-install ruby 3.3.6"
  log "  7. Set up LLM API keys:"
  log "     llm keys set anthropic"
  log "     llm keys set openai"
  log "     llm keys set gemini"
  log "  8. (Optional) Install remaining Brewfile apps:"
  log "     brew bundle --file=~/.Brewfile"
  log "  9. (Optional) Set up ntfy push notifications for Claude Code:"
  log "     Add to ~/.zsh/env/optional/private.zsh:"
  log "       export NTFY_TOPIC=\"your-unique-topic\""
  log ""
  log "NOTE: If you saw any warnings above, review them before proceeding."
}

# ==============================================================================
# Private Helpers — Foundation
# ==============================================================================

install_xcode_clt() {
  log "Checking Xcode Command Line Tools"

  if xcode-select -p &>/dev/null; then
    log "Xcode CLT already installed: $(xcode-select -p)"
    return 0
  fi

  log "Installing Xcode Command Line Tools (this may open a system dialog)..."
  xcode-select --install 2>/dev/null || true

  # Poll until the installation finishes (the dialog is async)
  log "Waiting for Xcode CLT installation to complete..."
  local waited=0
  until xcode-select -p &>/dev/null; do
    sleep 5
    waited=$((waited + 5))
    if [[ $waited -ge 600 ]]; then
      die "Timed out waiting for Xcode CLT (10 min). Install manually: xcode-select --install"
    fi
  done

  log "Xcode CLT installed: $(xcode-select -p)"
}

install_homebrew() {
  log "Checking Homebrew"

  if need_cmd brew; then
    log "Homebrew already installed: $(brew --version | head -n 1)"
    return 0
  fi

  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Make brew available for the rest of this session
  if [[ "$ARCH" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  log "Homebrew installed: $(brew --version | head -n 1)"
}

install_git_via_brew() {
  log "Installing latest git via Homebrew"

  if brew list git &>/dev/null; then
    log "git (brew) already installed: $(git --version)"
    return 0
  fi

  brew install git
  log "git installed: $(git --version)"
}

# ==============================================================================
# Private Helpers — Platform Packages
# ==============================================================================

brew_bundle() {
  log "Installing packages from BootstrapBrewfile"

  local brewfile="$HOME/.BootstrapBrewfile"
  if [[ ! -f "$brewfile" ]]; then
    warn "$HOME/.BootstrapBrewfile not found (symlink may not be in place). Skipping brew bundle."
    return 0
  fi

  export HOMEBREW_NO_AUTO_UPDATE=1
  brew bundle --file="$brewfile"
  unset HOMEBREW_NO_AUTO_UPDATE

  log "Brew bundle complete"
}

install_cask_apps() {
  log "Installing GUI applications via Homebrew Cask"

  local casks=(
    kitty
    tailscale
  )

  export HOMEBREW_NO_AUTO_UPDATE=1
  for app in "${casks[@]}"; do
    if brew list --cask "$app" &>/dev/null; then
      log "$app already installed"
    else
      log "Installing $app..."
      brew install --cask "$app" || warn "Failed to install $app"
    fi
  done
  unset HOMEBREW_NO_AUTO_UPDATE
}

# ==============================================================================
# Private Helpers — macOS Configuration
# ==============================================================================

apply_macos_defaults() {
  if [[ "$SKIP_DEFAULTS" == "1" ]]; then
    log "Skipping macOS defaults (SKIP_DEFAULTS=1)"
    return 0
  fi

  log "Applying macOS system defaults"

  # Close System Settings to prevent it from overriding changes
  osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true

  # --- Keyboard ---
  # Disable press-and-hold for keys in favor of key repeat
  defaults write -g ApplePressAndHoldEnabled -bool false
  # Enable full keyboard access for all controls (e.g. Tab in modal dialogs)
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  # --- Trackpad ---
  # Map bottom right corner to right-click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
  # Enable tap to click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

  # --- Finder ---
  # Show hidden files
  defaults write com.apple.finder AppleShowAllFiles -bool true
  # Show all filename extensions
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  # Show status bar
  defaults write com.apple.finder ShowStatusBar -bool true
  # Show path bar
  defaults write com.apple.finder ShowPathbar -bool true
  # Use list view by default
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  # Display full POSIX path as window title
  defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  # Disable warning when changing file extension
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  # Disable warning before emptying Trash
  defaults write com.apple.finder WarnOnEmptyTrash -bool false
  # Show ~/Library
  chflags nohidden ~/Library
  # Remove proxy icon hover delay
  defaults write com.apple.Finder NSToolbarTitleViewRolloverDelay -float 0
  # Set Desktop as default location for new Finder windows
  defaults write com.apple.finder NewWindowTarget -string "PfDe"
  defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

  # --- Dock ---
  # Enable highlight hover effect for grid view stacks
  defaults write com.apple.dock mouse-over-hilite-stack -bool true

  # --- AirDrop ---
  # Use AirDrop over every interface
  defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

  # --- Disk images ---
  # Disable verification
  defaults write com.apple.frameworks.diskimages skip-verify -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-locked -bool true
  defaults write com.apple.frameworks.diskimages skip-verify-remote -bool true
  # Auto-open new Finder window when volume is mounted
  defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
  defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true

  # --- Screenshots ---
  defaults write com.apple.screencapture type -string "png"

  # --- Misc ---
  # Disable quarantine dialog ("downloaded from the internet")
  defaults write com.apple.LaunchServices LSQuarantine -bool false
  # Avoid .DS_Store on network volumes
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  # Faster window resize animation
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

  # --- Photos ---
  # Prevent Photos from opening when devices are plugged in
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

  # --- Terminal.app ---
  defaults write com.apple.terminal StringEncodings -array 4

  log "macOS defaults applied. Some changes require logout or restart."
}

apply_spotlight_configs() {
  if [[ "$SKIP_DEFAULTS" == "1" ]]; then
    log "Skipping Spotlight config (SKIP_DEFAULTS=1)"
    return 0
  fi

  log "Applying Spotlight configurations"

  # Prevent Spotlight from indexing Caches and Developer directories
  mkdir -p ~/Library/Caches ~/Library/Developer
  touch ~/Library/Caches/.metadata_never_index
  touch ~/Library/Developer/.metadata_never_index

  log "Spotlight index exclusions set"
}
