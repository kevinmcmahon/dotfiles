#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# macOS Dev Bootstrap
# - Installs Xcode Command Line Tools
# - Installs Homebrew and core packages via BootstrapBrewfile
# - Symlinks dotfiles (XDG configs + *.symlink)
# - Installs Rust toolchain and cargo tools (viu, tectonic)
# - Installs uv (Python version & package manager)
# - Installs Deno runtime
# - Installs llm (Simon Willison's CLI tool)
# - Installs Claude Code (Anthropic CLI)
# - Installs OpenCode CLI
# - Optionally applies macOS system defaults
#
# Safe to re-run. It should be idempotent.
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
SKIP_DEFAULTS="${SKIP_DEFAULTS:-0}"
INSTALL_NODE="${INSTALL_NODE:-0}"
ARCH="$(uname -m)"

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$*"; }
die() {
  printf "\033[1;31mERR:\033[0m %s\n" "$*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_dirs() {
  log "Ensuring standard directories exist"
  mkdir -p "$LOCAL_BIN" "$CONFIG_DIR"
}

ensure_local_bin_in_path() {
  log "Ensuring ~/.local/bin is in PATH"
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    warn "$HOME/.local/bin not currently on PATH for this shell session."
    warn "Adding it for bootstrap; make sure your zsh config exports it permanently."
    export PATH="$LOCAL_BIN:$PATH"
  fi
}

# ------------------------------------------------------------------------------
# Phase 1 — Foundation
# ------------------------------------------------------------------------------

preflight_checks() {
  log "Running preflight checks"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    die "This script is for macOS only. Use bootstrap-linux-dev.sh for Linux."
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

# ------------------------------------------------------------------------------
# Phase 2 — Dotfile Symlinks
# ------------------------------------------------------------------------------

symlink_dotfiles_symlink_pattern() {
  log "Symlinking *.symlink dotfiles into \$HOME"

  [ -d "$DOTFILES_DIR" ] || die "DOTFILES_DIR not found: $DOTFILES_DIR"

  shopt -s nullglob
  # Symlink root-level *.symlink files
  for f in "$DOTFILES_DIR"/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    if [ -L "$target" ] || [ -e "$target" ]; then
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $target -> $backup"
      mv "$target" "$backup"
    fi
    ln -sf "$f" "$target"
    log "Linked $target -> $f"
  done

  # Symlink git/*.symlink files (gitconfig, gitignore_global, etc.)
  for f in "$DOTFILES_DIR"/git/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    if [ -L "$target" ] || [ -e "$target" ]; then
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $target -> $backup"
      mv "$target" "$backup"
    fi
    ln -sf "$f" "$target"
    log "Linked $target -> $f"
  done

  # Symlink osx/*.symlink files (Brewfile, BootstrapBrewfile, etc.)
  for f in "$DOTFILES_DIR"/osx/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    if [ -L "$target" ] || [ -e "$target" ]; then
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      backup="${target}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $target -> $backup"
      mv "$target" "$backup"
    fi
    ln -sf "$f" "$target"
    log "Linked $target -> $f"
  done

  # Symlink git-core directory for hooks and secrets
  git_core_src="$DOTFILES_DIR/git/git-core.symlink"
  git_core_dst="$HOME/.git-core"
  if [ -d "$git_core_src" ]; then
    if [ -e "$git_core_dst" ] && [ ! -L "$git_core_dst" ]; then
      backup="${git_core_dst}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $git_core_dst -> $backup"
      mv "$git_core_dst" "$backup"
    fi
    ln -snf "$git_core_src" "$git_core_dst"
    log "Linked $git_core_dst -> $git_core_src"
  fi
  shopt -u nullglob
}

ensure_git_identity_templates() {
  log "Ensuring local git identity templates exist (no personal data)"

  local home_abs="$HOME"

  if [[ ! -f "$HOME/.gituserconfig" ]]; then
    cat > "$HOME/.gituserconfig" <<'EOF'
# ~/.gituserconfig
# Default Git identity (NOT checked in).
# This is your fallback identity for repos that don't match
# any includeIf patterns in ~/.gitconfig-local.

[user]
  # name = Your Name
  # email = you@example.com
EOF
    chmod 600 "$HOME/.gituserconfig"
    warn "Created $HOME/.gituserconfig (EDIT THIS: uncomment and set name/email)"
  fi

  if [[ ! -f "$HOME/.gitconfig-local" ]]; then
    if [[ -f "$DOTFILES_DIR/git/gitconfig-local.template" ]]; then
      sed "s|__HOME__|$home_abs|g" "$DOTFILES_DIR/git/gitconfig-local.template" >"$HOME/.gitconfig-local"
      chmod 600 "$HOME/.gitconfig-local"
      log "Created $HOME/.gitconfig-local (edit as needed)"
    else
      warn "Missing template: $DOTFILES_DIR/git/gitconfig-local.template"
    fi
  fi

  if [[ ! -f "$HOME/.gituserconfig.kmc" && -f "$DOTFILES_DIR/git/gituserconfig-kmc.template" ]]; then
    cp "$DOTFILES_DIR/git/gituserconfig-kmc.template" "$HOME/.gituserconfig.kmc"
    chmod 600 "$HOME/.gituserconfig.kmc"
    warn "Created $HOME/.gituserconfig.kmc (EDIT THIS: set name/email)"
  fi

  if [[ ! -f "$HOME/.gituserconfig.nsv" && -f "$DOTFILES_DIR/git/gituserconfig-nsv.template" ]]; then
    cp "$DOTFILES_DIR/git/gituserconfig-nsv.template" "$HOME/.gituserconfig.nsv"
    chmod 600 "$HOME/.gituserconfig.nsv"
    warn "Created $HOME/.gituserconfig.nsv (EDIT THIS: set name/email)"
  fi
}

symlink_xdg_dirs() {
  log "Symlinking XDG config directories (nvim, yazi, tmux, kitty, etc.)"

  mkdir -p "$CONFIG_DIR"

  for d in nvim yazi tmux starship git kitty; do
    src="$DOTFILES_DIR/$d"
    dst="$CONFIG_DIR/$d"
    if [ -d "$src" ]; then
      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing $dst -> $backup"
        mv "$dst" "$backup"
      fi
      ln -snf "$src" "$dst"
      log "Linked $dst -> $src"
    fi
  done

  # tmux expects ~/.tmux.conf by default
  if [ -f "$DOTFILES_DIR/tmux/tmux.conf.symlink" ]; then
    ln -sf "$DOTFILES_DIR/tmux/tmux.conf.symlink" "$HOME/.tmux.conf"
    log "Linked ~/.tmux.conf -> $DOTFILES_DIR/tmux/tmux.conf.symlink"
  fi
}

# ------------------------------------------------------------------------------
# Phase 3 — Brew Bundle
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Phase 4 — Shell Environment
# ------------------------------------------------------------------------------

install_zsh_environment() {
  log "Installing zsh environment (oh-my-zsh, plugins, symlinks)"

  if [[ ! -f "$DOTFILES_DIR/zsh/install.sh" ]]; then
    warn "zsh/install.sh not found, skipping zsh setup"
    return 0
  fi

  # SKIP_EXEC_ZSH: prevent zsh/install.sh from exec'ing into a new shell (blocks bootstrap)
  # SKIP_SSH_AGENT: prevent passphrase prompts during bootstrap
  if ! (export SKIP_SSH_AGENT=1 SKIP_EXEC_ZSH=1; bash "$DOTFILES_DIR/zsh/install.sh"); then
    warn "zsh/install.sh reported errors (may still be partially successful)"
  fi

  log "zsh environment installed"
}

# ------------------------------------------------------------------------------
# Phase 5 — Non-Brew Language Runtimes & Tools
# ------------------------------------------------------------------------------

install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"

  if ! need_cmd rustup; then
    log "Installing rustup (Rust toolchain manager)"
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
      sh -s -- -y
  else
    log "rustup already installed"
  fi

  # shellcheck disable=SC1091
  source "$HOME/.cargo/env" || true

  if ! need_cmd cargo; then
    die "cargo not available after rustup install"
  fi

  log "rustup: $(rustup --version 2>/dev/null || echo 'unknown')"

  # yazi is installed via brew (BootstrapBrewfile), not cargo on macOS

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

install_uv() {
  log "Installing uv (Python package manager)"
  if need_cmd uv; then
    log "uv already installed: $(uv --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://astral.sh/uv/install.sh | sh

  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

  log "uv installed: $(uv --version 2>/dev/null || echo 'WARN: uv not found in PATH')"
}

install_deno() {
  log "Installing Deno"
  if need_cmd deno || [[ -x "$HOME/.deno/bin/deno" ]]; then
    export PATH="$HOME/.deno/bin:$PATH"
    log "deno already installed: $(deno --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://deno.land/install.sh | sh -s -- --no-modify-path

  export PATH="$HOME/.deno/bin:$PATH"

  log "deno installed: $(deno --version 2>/dev/null | head -n 1 || echo 'WARN: deno not found in PATH')"
}

setup_node() {
  if [[ "$INSTALL_NODE" != "1" ]]; then
    log "Skipping Node.js setup (set INSTALL_NODE=1 to enable)"
    return 0
  fi

  log "Setting up Node.js LTS via fnm + corepack"

  if ! need_cmd fnm; then
    warn "fnm not found — skipping Node.js setup"
    return 0
  fi

  eval "$(fnm env)"

  if fnm list 2>/dev/null | grep -q "lts-latest"; then
    log "Node.js LTS already installed"
  else
    log "Installing Node.js LTS..."
    fnm install --lts
  fi

  # These are fast no-ops if already set, but we always run them to ensure
  # the default and active version stay correct after an LTS bump.
  fnm default lts-latest
  fnm use lts-latest

  log "Node.js active: $(node --version)"

  log "Enabling corepack..."
  corepack enable

  log "Corepack enabled: $(corepack --version)"
}

# ------------------------------------------------------------------------------
# Phase 6 — Python/Dev Tooling
# ------------------------------------------------------------------------------

install_nvim_python_venv_uv() {
  log "Setting up Neovim Python venv (uv)"

  local NVIM_VENV_DIR="$HOME/.local/share/nvim/venv"
  local NVIM_VENV_PY="$NVIM_VENV_DIR/bin/python"

  if [[ ! -x "$NVIM_VENV_PY" ]]; then
    mkdir -p "$(dirname "$NVIM_VENV_DIR")"
    uv venv "$NVIM_VENV_DIR" --seed
  fi

  uv pip install --python "$NVIM_VENV_PY" -U pynvim

  if "$NVIM_VENV_PY" -c "import pynvim" 2>/dev/null; then
    log "pynvim OK: $("$NVIM_VENV_PY" -c "import pynvim; print(pynvim.__version__)")"
  else
    warn "pynvim import check failed — Neovim :checkhealth may report issues"
  fi
}

install_ruff_uv() {
  log "Installing ruff via uv"

  if need_cmd ruff; then
    log "ruff already installed: $(ruff --version)"
    return 0
  fi

  uv tool install ruff

  if need_cmd ruff; then
    log "ruff installed: $(ruff --version)"
  else
    warn "ruff not found in PATH after install"
  fi
}

install_llm() {
  log "Installing Simon Willison's llm tool"

  if ! need_cmd llm; then
    if need_cmd uv; then
      uv tool install llm
    elif need_cmd pipx; then
      pipx install llm
    else
      warn "Neither uv nor pipx found; installing llm via uv after uv install"
      install_uv
      uv tool install llm
    fi

    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! need_cmd llm; then
    warn "llm command not found after installation — skipping plugin install"
    return 0
  fi

  log "llm installed: $(llm --version)"

  log "Installing llm plugins"
  llm install -U llm-anthropic
  llm install -U llm-gemini
  llm install -U llm-openai-plugin
  llm install -U llm-mistral
  if [[ "$(uname -m)" == "arm64" ]]; then
    llm install -U llm-mlx
  else
    log "Skipping llm-mlx (requires Apple Silicon)"
  fi
}

symlink_llm_templates() {
  log "Symlinking llm templates"

  src="$DOTFILES_DIR/llm/templates.symlink"

  # macOS uses ~/Library/Application Support, Linux uses ~/.config
  local llm_data_dir="$HOME/Library/Application Support/io.datasette.llm"
  if [[ ! -d "$llm_data_dir" ]]; then
    llm_data_dir="$HOME/.config/io.datasette.llm"
  fi
  dst="$llm_data_dir/templates"

  if [[ ! -d "$src" ]]; then
    warn "No llm templates found at $src (skipping)"
    return 0
  fi

  mkdir -p "$llm_data_dir"

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Removing existing templates path (not a symlink): $dst"
    rm -rf "$dst"
  fi

  ln -snf "$src" "$dst"
}

# ------------------------------------------------------------------------------
# Phase 7 — AI/Dev CLIs
# ------------------------------------------------------------------------------

install_claude_code() {
  log "Installing Claude Code (Anthropic CLI)"
  if need_cmd claude; then
    log "claude already installed: $(claude --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://claude.ai/install.sh | bash

  export PATH="$HOME/.local/bin:$PATH"

  log "claude installed: $(claude --version 2>/dev/null || echo 'WARN: claude not found in PATH')"
}

install_opencode() {
  log "Installing OpenCode"
  if need_cmd opencode || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    export PATH="$HOME/.opencode/bin:$PATH"
    log "opencode already installed: $(opencode --version | head -n 1)"
  else
    curl -fsSL https://opencode.ai/install | bash

    # The installer adds a PATH line to ~/.zshrc; remove it (we manage PATH in path.zsh)
    local zshrc_real
    zshrc_real="$(readlink -f "$HOME/.zshrc" 2>/dev/null || echo "$HOME/.zshrc")"
    if [[ -f "$zshrc_real" ]]; then
      sed -i '' '/^# opencode$/d' "$zshrc_real"
      sed -i '' '/\.opencode\/bin/d' "$zshrc_real"
    fi

    export PATH="$HOME/.opencode/bin:$PATH"

    log "opencode installed: $(opencode --version 2>/dev/null || echo 'WARN: opencode not found in PATH')"
  fi

  # Symlink config
  local src="$DOTFILES_DIR/opencode/opencode.json.symlink"
  local dst="$CONFIG_DIR/opencode/opencode.json"

  if [[ -f "$src" ]]; then
    mkdir -p "$CONFIG_DIR/opencode"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $dst -> $backup"
      mv "$dst" "$backup"
    fi
    ln -sf "$src" "$dst"
    log "Linked $dst -> $src"
  fi
}

# ------------------------------------------------------------------------------
# Phase 8 — macOS Configuration (optional)
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Phase 9 — Post-install
# ------------------------------------------------------------------------------

post_checks() {
  log "Quick sanity checks"
  need_cmd git      || die "git missing"
  need_cmd brew     || die "brew missing"
  need_cmd tmux     || warn "tmux missing"
  need_cmd nvim     || warn "nvim missing"
  need_cmd rg       || warn "ripgrep missing"
  need_cmd fd       || warn "fd missing"
  need_cmd fzf      || warn "fzf missing"
  need_cmd bat      || warn "bat missing"
  need_cmd eza      || warn "eza missing"
  need_cmd zoxide   || warn "zoxide missing"
  need_cmd lazygit  || warn "lazygit missing"
  need_cmd starship || warn "starship missing"
  need_cmd yazi     || warn "yazi missing"
  need_cmd fnm      || warn "fnm missing"
  need_cmd rustc    || warn "rust missing"
  need_cmd cargo    || warn "cargo missing"
  need_cmd uv       || warn "uv missing"
  need_cmd deno     || warn "deno missing"
  need_cmd node     || log "Node.js not yet installed (run: fnm install --lts, or INSTALL_NODE=1)"
}

# ------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------

main() {
  # Phase 1 — Foundation
  preflight_checks
  ensure_dirs
  ensure_local_bin_in_path
  install_xcode_clt
  install_homebrew
  install_git_via_brew

  # Phase 2 — Dotfile Symlinks
  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs

  # Phase 3 — Brew Bundle + GUI Apps
  brew_bundle
  install_cask_apps

  # Phase 4 — Shell Environment
  install_zsh_environment

  # Phase 5 — Non-Brew Language Runtimes & Tools
  install_rust_and_cargo_tools
  install_uv
  install_deno
  setup_node

  # Phase 6 — Python/Dev Tooling
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Phase 7 — AI/Dev CLIs
  install_claude_code
  install_opencode

  # Phase 8 — macOS Configuration (optional)
  apply_macos_defaults
  apply_spotlight_configs

  # Phase 9 — Post-install
  post_checks

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
  log ""
  log "NOTE: If you saw any warnings above, review them before proceeding."
}

main "$@"
