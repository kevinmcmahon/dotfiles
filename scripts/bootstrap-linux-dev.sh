#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Linux Dev Bootstrap (Ubuntu/Debian)
# - Installs baseline packages (not Python/Node - those via uv/fnm)
# - Ensures ~/.local/bin on PATH
# - Symlinks dotfiles (XDG configs + *.symlink)
# - Installs Neovim AppImage into ~/.local/bin/nvim
# - Installs lazygit (arm64/x64) into ~/.local/bin
# - Installs starship prompt
# - Installs cargo tools: yazi, viu, tectonic
# - Installs uv (Python version & package manager)
# - Installs fnm (Fast Node Manager)
# - Installs ruby-install + chruby (Ruby version manager)
# - Installs llm (Simon Willison's CLI tool)
# - Installs Deno runtime
# - Installs Claude Code (Anthropic CLI)
# - Installs OpenCode CLI
# - Uses rustup for Rust
# - Uses Go official tarball
#
# Safe to re-run. It should be idempotent.
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
INSTALL_NODE="${INSTALL_NODE:-0}"

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
    # Add to PATH for the current bootstrap session
    export PATH="$LOCAL_BIN:$PATH"
  fi
}

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

  # Note: dirmngr, gpg, gawk are useful for GPG key management and general scripting

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

install_go_official() {
  log "Installing Go (official tarball)"

  # If you ever want to pin, set GO_VERSION (e.g. go1.22.5)
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
  if need_cmd go && [[ "$(go version 2>/dev/null)" == *"$version"* ]]; then
    log "Go $version already installed"
    return 0
  fi

  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) go_arch="arm64" ;;
    x86_64|amd64)  go_arch="amd64" ;;
    *) die "Unsupported architecture for Go: $arch" ;;
  esac

  # Fetch metadata for the target version (filename + checksum)
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

  url="https://go.dev/dl/${filename}"

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

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

install_python_build_deps() {
  # DEPRECATED: Not needed with uv (uses pre-built Python binaries)
  # Keeping function for backwards compatibility but skipping install
  log "Skipping Python build dependencies (uv uses pre-built binaries)"
  return 0
}

ensure_git_identity_templates() {
  log "Ensuring local git identity templates exist (no personal data)"

  # Only create these if missing; never overwrite.
  # gitconfig-local is required for includeIf gitdir: routing because it must
  # contain absolute paths (Git does not expand ~ or $HOME in includeIf).
  local home_abs="$HOME"

  # Create default ~/.gituserconfig (included by ~/.gitconfig for default identity)
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
  # Note: includes gitconfig-secrets.symlink -> ~/.gitconfig-secrets
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
  # Note: zsh is handled separately by zsh/install.sh (uses ~/.zsh/env layout)
  for d in nvim yazi tmux starship git; do
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

install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"

  # Install rustup if needed
  if ! need_cmd rustup; then
    log "Installing rustup (Rust toolchain manager)"
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
      sh -s -- -y
  else
    log "rustup already installed"
  fi

  # shellcheck disable=SC1090
  source "$HOME/.cargo/env" || true

  if ! need_cmd cargo; then
    die "cargo not available after rustup install"
  fi

  log "rustup: $(rustup --version 2>/dev/null || echo 'unknown')"

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
    log "Installing tectonic..."
    cargo install tectonic
    log "tectonic installed: $(tectonic --version | head -n 1)"
  fi
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

install_uv() {
  log "Installing uv (Python package manager)"
  if need_cmd uv; then
    log "uv already installed: $(uv --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://astral.sh/uv/install.sh | sh

  # uv installs to ~/.cargo/bin or ~/.local/bin; update PATH for current session
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

  log "uv installed: $(uv --version 2>/dev/null || echo 'WARN: uv not found in PATH')"
}

install_nvim_python_venv_uv() {
  log "Setting up Neovim Python venv (uv)"

  local NVIM_VENV_DIR="$HOME/.local/share/nvim/venv"
  local NVIM_VENV_PY="$NVIM_VENV_DIR/bin/python"

  # Create venv only if it doesn't already exist
  if [[ ! -x "$NVIM_VENV_PY" ]]; then
    mkdir -p "$(dirname "$NVIM_VENV_DIR")"
    uv venv "$NVIM_VENV_DIR" --seed
  fi

  # Install/upgrade pynvim
  uv pip install --python "$NVIM_VENV_PY" -U pynvim

  # Verify (non-fatal)
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
    # uv is the preferred install method; fall back to pipx if uv unavailable
    if need_cmd uv; then
      uv tool install llm
    elif need_cmd pipx; then
      pipx install llm
    else
      warn "Neither uv nor pipx found; installing llm via uv after uv install"
      install_uv
      uv tool install llm
    fi

    # uv tool install puts binaries in ~/.local/bin; update PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! need_cmd llm; then
    warn "llm command not found after installation - skipping plugin install"
    return 0
  fi

  log "llm installed: $(llm --version)"

  # Install/upgrade llm plugins
  log "Installing llm plugins"
  llm install -U llm-anthropic
  llm install -U llm-gemini
  llm install -U llm-openai-plugin
  llm install -U llm-mlx
  llm install -U llm-mistral
}

install_claude_code() {
  log "Installing Claude Code (Anthropic CLI)"
  if need_cmd claude; then
    log "claude already installed: $(claude --version | head -n 1)"
    return 0
  fi

  curl -fsSL https://claude.ai/install.sh | bash

  # Claude Code installer adds to ~/.local/bin; update PATH for current session
  export PATH="$HOME/.local/bin:$PATH"

  log "claude installed: $(claude --version 2>/dev/null || echo 'WARN: claude not found in PATH')"
}

install_deno() {
  log "Installing Deno"
  if need_cmd deno || [[ -x "$HOME/.deno/bin/deno" ]]; then
    export PATH="$HOME/.deno/bin:$PATH"
    log "deno already installed: $(deno --version | head -n 1)"
    return 0
  fi

  # --no-modify-path: we manage PATH in path.zsh
  curl -fsSL https://deno.land/install.sh | sh -s -- --no-modify-path

  # Deno installs to ~/.deno/bin; update PATH for current session
  export PATH="$HOME/.deno/bin:$PATH"

  log "deno installed: $(deno --version 2>/dev/null | head -n 1 || echo 'WARN: deno not found in PATH')"
}

install_opencode() {
  log "Installing OpenCode"
  if need_cmd opencode || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    export PATH="$HOME/.opencode/bin:$PATH"
    log "opencode already installed: $(opencode --version | head -n 1)"
  else
    curl -fsSL https://opencode.ai/install | bash

    # The installer adds a PATH line to ~/.zshrc; remove it (we manage PATH in path.zsh)
    # Use readlink to resolve symlinks — sed -i replaces symlinks with regular files
    local zshrc_real
    zshrc_real="$(readlink -f "$HOME/.zshrc" 2>/dev/null || echo "$HOME/.zshrc")"
    if [[ -f "$zshrc_real" ]]; then
      sed -i '/^# opencode$/d' "$zshrc_real"
      sed -i '/\.opencode\/bin/d' "$zshrc_real"
    fi

    # OpenCode installer adds to ~/.opencode/bin; update PATH for current session
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

symlink_llm_templates() {
  log "Symlinking llm templates"

  # llm uses ~/.config/io.datasette.llm/templates
  src="$DOTFILES_DIR/llm/templates.symlink"
  dst="$HOME/.config/io.datasette.llm/templates"

  if [[ ! -d "$src" ]]; then
    warn "No llm templates found at $src (skipping)"
    return 0
  fi

  mkdir -p "$HOME/.config/io.datasette.llm"

  # Important: llm does NOT recurse. The templates dir must contain the YAML files directly.
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Removing existing templates path (not a symlink): $dst"
    rm -rf "$dst"
  fi

  ln -snf "$src" "$dst"
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

  RUBY_INSTALL_VERSION="${RUBY_INSTALL_VERSION:-0.9.3}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  local url="https://github.com/postmodern/ruby-install/releases/download/v${RUBY_INSTALL_VERSION}/ruby-install-${RUBY_INSTALL_VERSION}.tar.gz"
  log "Downloading ruby-install v${RUBY_INSTALL_VERSION}"
  curl -fsSL "$url" -o "$tmpdir/ruby-install.tar.gz"
  tar -xzf "$tmpdir/ruby-install.tar.gz" -C "$tmpdir"
  cd "$tmpdir/ruby-install-${RUBY_INSTALL_VERSION}"
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

  CHRUBY_VERSION="${CHRUBY_VERSION:-0.3.9}"

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  local url="https://github.com/postmodern/chruby/releases/download/v${CHRUBY_VERSION}/chruby-${CHRUBY_VERSION}.tar.gz"
  log "Downloading chruby v${CHRUBY_VERSION}"
  curl -fsSL "$url" -o "$tmpdir/chruby.tar.gz"
  tar -xzf "$tmpdir/chruby.tar.gz" -C "$tmpdir"
  cd "$tmpdir/chruby-${CHRUBY_VERSION}"
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

change_shell_to_zsh() {
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

install_zsh_environment() {
  log "Installing zsh environment (oh-my-zsh, plugins, symlinks)"

  if [[ ! -f "$DOTFILES_DIR/zsh/install.sh" ]]; then
    warn "zsh/install.sh not found, skipping zsh setup"
    return 0
  fi

  # The zsh installer handles:
  # - oh-my-zsh installation
  # - ~/.zshrc, ~/.zshenv, ~/.zprofile symlinks
  # - ~/.zsh/env symlink
  # - oh-my-zsh plugins
  # Run in subshell to prevent 'exec zsh' at end from terminating bootstrap
  # Skip ssh-agent to prevent passphrase prompts during bootstrap
  if ! (export SKIP_SSH_AGENT=1 SKIP_EXEC_ZSH=1; bash "$DOTFILES_DIR/zsh/install.sh"); then
    warn "zsh/install.sh reported errors (may still be partially successful)"
  fi

  log "zsh environment installed"
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
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    die "Do not run this bootstrap with sudo. Run as your user; the script uses sudo internally."
  fi

  ensure_dirs
  ensure_local_bin_in_path

  apt_install_base
  install_extras_optional
  install_python_build_deps

  # Language runtimes and version managers (install before dotfiles/shell setup)
  install_go_official
  install_fnm
  setup_node

  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs
  install_zsh_environment
  change_shell_to_zsh

  install_neovim_appimage
  install_lazygit
  install_starship
  install_fzf

  # Rust toolchain and cargo tools
  install_rust_and_cargo_tools

  # Python tooling (uv for packages, venvs, and tools)
  install_uv
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Ruby tooling (chruby + ruby-install)
  install_ruby_build_deps
  install_ruby_install
  install_chruby
  install_ruby_optional

  # Deno
  install_deno

  # Claude Code CLI
  install_claude_code

  # OpenCode CLI
  install_opencode

  # Optional niceties
  install_pbcopy_wrappers_optional

  post_checks

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
  log ""
  log "NOTE: If you saw any warnings above, review them before proceeding."
  log "Optional: Install keychain manually if you need SSH key management:"
  log "  sudo apt-get install -y keychain"
}

main "$@"
