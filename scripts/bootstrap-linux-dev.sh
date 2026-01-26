#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Linux Dev Bootstrap (Ubuntu/Debian)
# - Installs baseline packages (Python/Node via asdf, not apt)
# - Installs Python build dependencies for asdf
# - Ensures ~/.local/bin on PATH
# - Symlinks dotfiles (XDG configs + *.symlink)
# - Installs Neovim AppImage into ~/.local/bin/nvim
# - Installs lazygit (arm64/x64) into ~/.local/bin
# - Installs starship prompt
# - Installs yazi (via cargo)
# - Installs uv (Python package manager)
# - Installs llm (Simon Willison's CLI tool)
# - Uses rustup for Rust (not asdf)
#
# Safe to re-run. It should be idempotent.
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"

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
  # We won't mutate your zshrc aggressively—just ensure a drop-in exists
  # and let your dotfiles source it.
  log "Ensuring ~/.local/bin is in PATH"
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    warn "$HOME/.local/bin not currently on PATH for this shell session."
    warn "Make sure your zsh config exports it. Example:"
    warn '  export PATH="$HOME/.local/bin:$PATH"'
  fi
}

apt_install_base() {
  log "Installing base packages via apt"
  sudo apt-get update -y
  sudo apt-get install -y \
    ca-certificates curl wget unzip xz-utils tar \
    git git-secrets jq make gcc g++ pkg-config \
    zsh tmux \
    ripgrep fd-find fzf bat \
    xclip \
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
}

install_python_build_deps() {
  # Dependencies required by asdf-python (pyenv) to build Python from source
  log "Installing Python build dependencies for asdf"
  sudo apt-get install -y \
    build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev \
    libncursesw5-dev xz-utils tk-dev libxml2-dev \
    libxmlsec1-dev libffi-dev liblzma-dev
}

symlink_dotfiles_symlink_pattern() {
  log "Symlinking *.symlink dotfiles into \$HOME"

  [ -d "$DOTFILES_DIR" ] || die "DOTFILES_DIR not found: $DOTFILES_DIR"

  shopt -s nullglob
  # Symlink root-level *.symlink files
  for f in "$DOTFILES_DIR"/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    if [ -L "$target" ] || [ -e "$target" ]; then
      # If it's already the right symlink, leave it.
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        continue
      fi
      # Back up only if it's not already correct.
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

symlink_xdg_dirs() {
  log "Symlinking XDG config directories (nvim, yazi, tmux, etc.)"

  mkdir -p "$CONFIG_DIR"

  # Add more here as needed (kitty omitted - no GUI on Linux server)
  for d in nvim yazi tmux zsh starship git; do
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

  # tmux expects ~/.tmux.conf by default; follow your *.symlink convention.
  if [ -f "$DOTFILES_DIR/tmux/tmux.conf.symlink" ]; then
    ln -sf "$DOTFILES_DIR/tmux/tmux.conf.symlink" "$HOME/.tmux.conf"
    log "Linked ~/.tmux.conf -> $DOTFILES_DIR/tmux/tmux.conf.symlink"
  fi
}

install_neovim_appimage() {
  log "Installing Neovim AppImage into ~/.local/bin"

  # Choose a pinned version for repeatability; you can bump consciously.
  # If you prefer "stable latest", set NVIM_VERSION="stable" and change URL logic accordingly.
  NVIM_VERSION="${NVIM_VERSION:-v0.11.5}"

  # Map arch to appimage naming
  arch="$(uname -m)"
  case "$arch" in
  aarch64 | arm64) nvim_asset="nvim-linux-arm64.appimage" ;;
  x86_64 | amd64) nvim_asset="nvim-linux-x86_64.appimage" ;;
  *) die "Unsupported architecture for nvim appimage: $arch" ;;
  esac

  nvim_path="$LOCAL_BIN/$nvim_asset"
  nvim_link="$LOCAL_BIN/nvim"

  # Download from GitHub releases
  url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_asset}"
  log "Downloading Neovim ${NVIM_VERSION} (${nvim_asset})"
  curl -fL "$url" -o "$nvim_path"
  chmod +x "$nvim_path"
  ln -sf "$nvim_path" "$nvim_link"

  log "Neovim installed: $("$nvim_link" --version | head -n 1)"
}

install_lazygit() {
  log "Installing lazygit into ~/.local/bin"

  # Detect arch
  arch="$(uname -m)"
  case "$arch" in
  aarch64 | arm64) lazygit_arch="arm64" ;;
  x86_64 | amd64) lazygit_arch="x86_64" ;;
  *) die "Unsupported architecture for lazygit: $arch" ;;
  esac

  # Fetch latest version tag via GitHub API
  if ! need_cmd jq; then
    die "jq is required for lazygit install. Install via apt first."
  fi

  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    jq -r '.tag_name' | sed 's/^v//')"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  tarball="lazygit_${version}_Linux_${lazygit_arch}.tar.gz"
  url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"

  log "Downloading lazygit v${version} (${lazygit_arch})"
  curl -fL "$url" -o "$tmpdir/$tarball"
  tar -xzf "$tmpdir/$tarball" -C "$tmpdir" lazygit

  mv "$tmpdir/lazygit" "$LOCAL_BIN/lazygit"
  chmod +x "$LOCAL_BIN/lazygit"

  log "lazygit installed: $("$LOCAL_BIN/lazygit" --version | head -n 1)"
}

install_rustup() {
  log "Installing rustup (Rust toolchain manager)"
  if need_cmd rustup; then
    log "rustup already installed"
    return 0
  fi

  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
    sh -s -- -y

  # shellcheck disable=SC1090
  source "$HOME/.cargo/env" || true

  log "rustup installed: $(rustup --version || true)"
}

install_yazi_via_cargo() {
  log "Installing yazi via cargo (requires rustup)"
  if need_cmd yazi && need_cmd ya; then
    log "yazi already installed: $(yazi --version | head -n 1)"
    return 0
  fi

  if ! need_cmd cargo; then
    warn "cargo not found; installing rustup first"
    install_rustup
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env" || true
  fi

  cargo install --locked yazi-fm yazi-cli

  log "yazi installed: $(yazi --version | head -n 1)"
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

install_uv() {
  log "Installing uv (Python package manager)"
  if need_cmd uv; then
    log "uv already installed: $(uv --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://astral.sh/uv/install.sh | sh

  log "uv installed: $(uv --version 2>/dev/null || echo 'restart shell to verify')"
}

install_llm() {
  log "Installing Simon Willison's llm tool"
  if need_cmd llm; then
    log "llm already installed: $(llm --version | head -n 1)"
    return 0
  fi

  # uv is the preferred install method; fall back to pipx if uv unavailable
  if need_cmd uv; then
    uv tool install llm
  elif need_cmd pipx; then
    pipx install llm
  else
    warn "Neither uv nor pipx found; installing llm via uv after uv install"
    install_uv
    # Source uv env if needed
    export PATH="$HOME/.local/bin:$PATH"
    uv tool install llm
  fi

  log "llm installed: $(llm --version 2>/dev/null || echo 'restart shell to verify')"
}

install_pbcopy_wrappers_optional() {
  # This gives you pbcopy/pbpaste on Linux when $DISPLAY is available.
  # (You already got it working, but this makes it reproducible.)
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

post_checks() {
  log "Quick sanity checks"
  need_cmd git || die "git missing"
  need_cmd tmux || die "tmux missing"
  need_cmd rg || warn "ripgrep missing"
  need_cmd fd || warn "fd missing"
  need_cmd fzf || warn "fzf missing"
  need_cmd nvim || warn "nvim missing (expected if AppImage step skipped/failed)"
}

main() {
  ensure_dirs
  ensure_local_bin_in_path

  apt_install_base
  install_extras_optional
  install_python_build_deps

  symlink_dotfiles_symlink_pattern
  symlink_xdg_dirs

  install_neovim_appimage
  install_lazygit
  install_starship

  # Rust via rustup (not asdf)
  install_rustup

  # yazi via cargo (comment out if you prefer other install method)
  install_yazi_via_cargo

  # Python tooling (use asdf for Python itself)
  install_uv
  install_llm

  # Optional niceties
  install_pbcopy_wrappers_optional

  post_checks

  log "Bootstrap complete."
  log "Next: open a new shell (or source your zsh config) so PATH updates apply."
  log "Then use asdf to install python and nodejs runtimes."
}

main "$@"
