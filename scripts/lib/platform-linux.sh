# shellcheck shell=bash
# scripts/lib/platform-linux.sh — Linux-specific bootstrap functions
#
# This file is SOURCED by bootstrap.sh AFTER common.sh — do not add a shebang
# or set -euo pipefail.
#
# It expects these globals from the sourcing script:
#   DOTFILES_DIR, LOCAL_BIN, CONFIG_DIR, INSTALL_NODE, PLATFORM, ARCH
#
# It uses these functions from common.sh:
#   log, warn, die, need_cmd, install_rustup

# ==============================================================================
# Platform Contract — Public Functions
# ==============================================================================

preflight_checks() {
  log "Running preflight checks"

  if [[ "$(uname -s)" != "Linux" ]]; then
    die "This script is for Linux only. Use bootstrap.sh on a macOS host."
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    die "Do not run this bootstrap with sudo. Run as your user; the script uses sudo internally."
  fi

  case "$ARCH" in
    aarch64|arm64) log "Detected ARM64 (aarch64)" ;;
    x86_64|amd64)  log "Detected x86_64 (amd64)" ;;
    *)             die "Unsupported architecture: $ARCH" ;;
  esac
}

install_platform_foundation() {
  apt_install_base
  install_extras_optional
}

install_platform_packages() {
  install_go_official
  install_fnm
  install_neovim_appimage
  install_lazygit
  install_starship
  install_fzf
  install_ruby_build_deps
  install_ruby_install
  install_chruby
  install_ruby_optional
  install_pbcopy_wrappers_optional
}

install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"

  install_rustup

  # --- yazi (file manager) ---
  if need_cmd yazi && need_cmd ya; then
    log "yazi already installed: $(yazi --version | head -n 1)"
  else
    log "Installing yazi..."
    cargo install --force yazi-build
    yazi-build
    log "yazi installed: $(yazi --version | head -n 1)"
  fi

  # --- viu (terminal image viewer) ---
  if need_cmd viu; then
    log "viu already installed: $(viu --version | head -n 1)"
  else
    log "Installing viu..."
    cargo install viu
    log "viu installed: $(viu --version | head -n 1)"
  fi

  # --- tectonic (LaTeX compiler) ---
  if need_cmd tectonic; then
    log "tectonic already installed: $(tectonic --version | head -n 1)"
  else
    log "Installing tectonic build dependencies..."
    sudo apt-get install -y libfontconfig1-dev libgraphite2-dev libharfbuzz-dev libicu-dev
    log "Installing tectonic..."
    cargo install -F external-harfbuzz tectonic
    log "tectonic installed: $(tectonic --version | head -n 1)"
  fi
}

set_default_shell_zsh() {
  log "Checking default shell"

  # Check if zsh is already the default shell
  if [[ "$SHELL" == */zsh ]]; then
    log "Default shell is already zsh"
    return 0
  fi

  # Find zsh path
  local zsh_path
  zsh_path="$(command -v zsh)" || {
    warn "zsh not found in PATH, cannot change default shell"
    return 1
  }

  # Check if zsh is in /etc/shells
  if ! grep -qx "$zsh_path" /etc/shells; then
    warn "Adding $zsh_path to /etc/shells"
    echo "$zsh_path" | sudo tee -a /etc/shells
  fi

  log "Changing default shell to zsh (will prompt for password)"
  if chsh -s "$zsh_path"; then
    log "Default shell changed to zsh. Log out and back in for it to take effect."
  else
    warn "Failed to change default shell. You can do it manually with: chsh -s $zsh_path"
  fi
}

apply_platform_config() {
  # No platform-level config needed on Linux
  return 0
}

post_checks_platform() {
  # Platform-specific checks not already covered by common.sh's post_checks.
  # common.sh already checks: git, tmux, nvim, rg, fd, fzf, bat, rustc,
  # cargo, uv, deno, fnm, node.
  need_cmd go       || warn "go missing"
  need_cmd lazygit  || warn "lazygit missing"
  need_cmd starship || warn "starship missing"
  need_cmd yazi     || warn "yazi missing"
  need_cmd eza      || warn "eza missing"
  need_cmd zoxide   || warn "zoxide missing"
}

print_next_steps() {
  log "Bootstrap complete."
  log ""
  log "Next steps:"
  log "  1. Open a new shell (or exec zsh) so PATH updates apply"
  log "  2. Configure your Git identity (REQUIRED for commits):"
  log "     Edit ~/.gituserconfig and uncomment/set your name and email"
  log "     (Optional) Edit ~/.gituserconfig.kmc and ~/.gituserconfig.nsv"
  log "     for project-specific identities"
  log "  3. Install Python versions with uv:"
  log "     uv python install 3.12"
  log "     uv python install 3.11"
  if [[ "$INSTALL_NODE" != "1" ]]; then
    log "  4. Install Node.js with fnm and enable corepack (for yarn/pnpm):"
    log "     fnm install --lts"
    log "     fnm use lts-latest"
    log "     fnm default lts-latest"
    log "     corepack enable"
    log "     (or re-run with INSTALL_NODE=1 to automate this)"
  fi
  log "  5. Install Ruby with ruby-install:"
  log "     ruby-install ruby 3.3.6"
  log "     (or set RUBY_VERSION=3.3.6 before bootstrap)"
  log "  6. (Optional) Set up ntfy push notifications for Claude Code:"
  log "     Add to ~/.zsh/env/optional/private.zsh:"
  log "       export NTFY_TOPIC=\"your-unique-topic\""
  log ""
  log "NOTE: If you saw any warnings above, review them before proceeding."
  log "Optional: Install keychain manually if you need SSH key management:"
  log "  sudo apt-get install -y keychain"
}

# ==============================================================================
# Private Helpers — Foundation
# ==============================================================================

apt_install_base() {
  log "Installing base packages via apt"
  sudo apt-get update -y
  sudo apt-get install -y \
    ca-certificates curl wget unzip xz-utils tar \
    git git-lfs git-secrets jq make gcc g++ pkg-config \
    zsh tmux \
    ripgrep fd-find bat \
    xclip \
    dirmngr gpg gawk \
    locales

  # Ubuntu calls it fdfind; provide fd symlink in ~/.local/bin
  if need_cmd fdfind && ! need_cmd fd; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
  fi

  # Ubuntu calls it batcat; provide bat symlink in ~/.local/bin
  if need_cmd batcat && ! need_cmd bat; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
  fi
}

install_extras_optional() {
  # Keep optional extras separate so you can comment out easily.
  log "Installing optional quality-of-life tools (apt)"
  sudo apt-get install -y \
    eza zoxide \
    tree \
    neofetch || true

  # keychain is optional because it may prompt for SSH passphrase during bootstrap
  # Uncomment if you want it installed automatically:
  # sudo apt-get install -y keychain
}

# ==============================================================================
# Private Helpers — Platform Packages
# ==============================================================================

install_go_official() {
  log "Installing Go (official tarball)"

  # If you ever want to pin, set GO_VERSION (e.g. go1.22.5)
  local version
  if [[ -n "${GO_VERSION:-}" ]]; then
    version="$GO_VERSION"
  else
    # Pull latest stable from go.dev JSON
    version="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '.[] | select(.stable==true) | .version' | head -n 1)"
  fi

  if [[ -z "$version" || "$version" == "null" ]]; then
    die "Could not determine latest stable Go version"
  fi

  # Skip if already installed at desired version
  # Check both PATH and the known install location
  local go_bin
  go_bin="$(command -v go 2>/dev/null || echo /usr/local/go/bin/go)"
  if [[ -x "$go_bin" ]] && [[ "$($go_bin version 2>/dev/null)" == *"$version"* ]]; then
    log "Go $version already installed"
    return 0
  fi

  local arch go_arch
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) go_arch="arm64" ;;
    x86_64|amd64)  go_arch="amd64" ;;
    *) die "Unsupported architecture for Go: $arch" ;;
  esac

  # Fetch metadata for the target version (filename + checksum)
  local go_meta filename checksum
  go_meta="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r --arg v "$version" --arg a "$go_arch" \
    '.[] | select(.version==$v) | .files[] | select(.os=="linux" and .arch==$a and .kind=="archive")')"

  filename="$(echo "$go_meta" | jq -r '.filename')"
  checksum="$(echo "$go_meta" | jq -r '.sha256')"

  if [[ -z "$filename" || "$filename" == "null" ]]; then
    die "Could not find linux-$go_arch archive for $version"
  fi
  if [[ -z "$checksum" || "$checksum" == "null" ]]; then
    die "Could not find checksum for $filename"
  fi

  local url tmpdir
  url="https://go.dev/dl/${filename}"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN

  log "Downloading $url"
  curl -fL "$url" -o "$tmpdir/$filename"

  # Verify checksum before extracting
  log "Verifying checksum"
  echo "$checksum  $tmpdir/$filename" | sha256sum -c - || die "Checksum verification failed for $filename"

  # Install to /usr/local/go (system-wide)
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$tmpdir/$filename"

  log "Go installed: $(/usr/local/go/bin/go version)"
}

install_fnm() {
  log "Installing fnm (Fast Node Manager)"

  if need_cmd fnm; then
    log "fnm already installed: $(fnm --version | head -n 1)"
    return 0
  fi

  # Install fnm via official installer
  # --install-dir puts binary in ~/.local/bin (managed by path.zsh)
  # --skip-shell prevents installer from modifying shell configs (we manage PATH centrally)
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$LOCAL_BIN" --skip-shell

  # Ensure ~/.local/bin is in PATH for current session
  export PATH="$LOCAL_BIN:$PATH"

  if need_cmd fnm; then
    log "fnm installed: $(fnm --version)"
  else
    warn "fnm command not found after installation"
  fi
}

install_neovim_appimage() {
  log "Installing Neovim AppImage into ~/.local/bin"

  # Choose a pinned version for repeatability; you can bump consciously.
  local NVIM_VERSION="${NVIM_VERSION:-v0.11.5}"

  # Map arch to appimage naming
  local arch nvim_asset
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) nvim_asset="nvim-linux-arm64.appimage" ;;
    x86_64|amd64)  nvim_asset="nvim-linux-x86_64.appimage" ;;
    *) die "Unsupported architecture for nvim appimage: $arch" ;;
  esac

  local nvim_path="$LOCAL_BIN/$nvim_asset"
  local nvim_link="$LOCAL_BIN/nvim"

  # Skip if already installed at desired version
  if [[ -x "$nvim_link" ]] && [[ "$("$nvim_link" --version 2>/dev/null | head -n 1)" == *"${NVIM_VERSION#v}"* ]]; then
    log "Neovim ${NVIM_VERSION} already installed"
    return 0
  fi

  # Download from GitHub releases
  local url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_asset}"
  log "Downloading Neovim ${NVIM_VERSION} (${nvim_asset})"
  curl -fL "$url" -o "$nvim_path"
  chmod +x "$nvim_path"
  ln -sf "$nvim_path" "$nvim_link"

  log "Neovim installed: $("$nvim_link" --version | head -n 1)"
}

install_lazygit() {
  log "Installing lazygit into ~/.local/bin"

  # Detect arch
  local arch lazygit_arch
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) lazygit_arch="arm64" ;;
    x86_64|amd64)  lazygit_arch="x86_64" ;;
    *) die "Unsupported architecture for lazygit: $arch" ;;
  esac

  # Fetch latest version tag via GitHub API
  if ! need_cmd jq; then
    die "jq is required for lazygit install. Install via apt first."
  fi

  local version
  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    jq -r '.tag_name' | sed 's/^v//')"

  # Skip if already installed at latest version
  if need_cmd lazygit && [[ "$(lazygit --version 2>/dev/null)" == *"version=${version}"* ]]; then
    log "lazygit v${version} already installed"
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN

  local tarball url
  tarball="lazygit_${version}_Linux_${lazygit_arch}.tar.gz"
  url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"

  log "Downloading lazygit v${version} (${lazygit_arch})"
  curl -fL "$url" -o "$tmpdir/$tarball"
  tar -xzf "$tmpdir/$tarball" -C "$tmpdir" lazygit

  mv "$tmpdir/lazygit" "$LOCAL_BIN/lazygit"
  chmod +x "$LOCAL_BIN/lazygit"

  log "lazygit installed: $("$LOCAL_BIN/lazygit" --version | head -n 1)"
}

install_starship() {
  log "Installing starship prompt"
  if need_cmd starship; then
    log "starship already installed: $(starship --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"

  log "starship installed: $("$LOCAL_BIN/starship" --version | head -n 1)"
}

install_fzf() {
  log "Installing fzf (fuzzy finder)"
  if need_cmd fzf; then
    log "fzf already installed: $(fzf --version | head -n 1)"
    return 0
  fi

  if [[ -d "$HOME/.fzf" ]]; then
    log "Updating existing ~/.fzf"
    git -C "$HOME/.fzf" pull
  else
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  fi

  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc

  log "fzf installed: $("$HOME/.fzf/bin/fzf" --version | head -n 1)"
}

install_ruby_build_deps() {
  log "Installing Ruby build dependencies"
  sudo apt-get update -y
  sudo apt-get install -y \
    build-essential curl git \
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev \
    libffi-dev libgdbm-dev libncurses5-dev \
    libtool bison autoconf
}

install_ruby_install() {
  log "Installing ruby-install"

  if need_cmd ruby-install; then
    log "ruby-install already installed: $(ruby-install --version | head -n 1)"
    return 0
  fi

  local RUBY_INSTALL_VERSION="${RUBY_INSTALL_VERSION:-0.9.3}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN

  local url="https://github.com/postmodern/ruby-install/releases/download/v${RUBY_INSTALL_VERSION}/ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  log "Downloading ruby-install v${RUBY_INSTALL_VERSION}"
  curl -fsSL "$url" -o "$tmpdir/ruby-install.tar.gz"
  tar -xzf "$tmpdir/ruby-install.tar.gz" -C "$tmpdir"
  cd "$tmpdir/ruby-install-${RUBY_INSTALL_VERSION}" || die "Failed to cd into ruby-install source directory"
  sudo make install

  if need_cmd ruby-install; then
    log "ruby-install installed: $(ruby-install --version | head -n 1)"
  else
    warn "ruby-install command not found after installation"
  fi
}

install_chruby() {
  log "Installing chruby"

  if [[ -f /usr/local/share/chruby/chruby.sh ]] || [[ -f /usr/share/chruby/chruby.sh ]]; then
    log "chruby already installed"
    return 0
  fi

  local CHRUBY_VERSION="${CHRUBY_VERSION:-0.3.9}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN

  local url="https://github.com/postmodern/chruby/releases/download/v${CHRUBY_VERSION}/chruby-${CHRUBY_VERSION}.tar.gz"
  log "Downloading chruby v${CHRUBY_VERSION}"
  curl -fsSL "$url" -o "$tmpdir/chruby.tar.gz"
  tar -xzf "$tmpdir/chruby.tar.gz" -C "$tmpdir"
  cd "$tmpdir/chruby-${CHRUBY_VERSION}" || die "Failed to cd into chruby source directory"
  sudo make install

  if [[ -f /usr/local/share/chruby/chruby.sh ]]; then
    log "chruby installed: /usr/local/share/chruby/chruby.sh"
  else
    warn "chruby.sh not found after installation"
  fi
}

install_ruby_optional() {
  if [[ -z "${RUBY_VERSION:-}" ]]; then
    log "RUBY_VERSION not set, skipping Ruby install (install later with ruby-install)"
    return 0
  fi

  log "Installing Ruby $RUBY_VERSION via ruby-install"
  ruby-install ruby "$RUBY_VERSION" || warn "Ruby $RUBY_VERSION install failed (non-fatal)"

  if [[ -d "$HOME/.rubies" ]]; then
    log "Rubies installed: $(ls "$HOME/.rubies")"
  fi
}

install_pbcopy_wrappers_optional() {
  # This gives you pbcopy/pbpaste on Linux when $DISPLAY is available.
  log "Installing pbcopy/pbpaste wrappers (optional)"

  cat >"$LOCAL_BIN/pbcopy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Requires xclip and an available DISPLAY
xclip -selection clipboard
EOF
  chmod +x "$LOCAL_BIN/pbcopy"

  cat >"$LOCAL_BIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
xclip -selection clipboard -o
EOF
  chmod +x "$LOCAL_BIN/pbpaste"

  log "Installed pbcopy/pbpaste wrappers into ~/.local/bin"
}
