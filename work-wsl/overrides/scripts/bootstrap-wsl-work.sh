#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
STATE_DIR="$HOME/.work-wsl"
ENABLED_TOOLS="$STATE_DIR/enabled-tools"

WITH_NODE=0
WITH_RUST=0
WITH_NEOVIM=0
WITH_FZF=0
WITH_STARSHIP=0
WITH_LAZYGIT=0
WITH_YAZI=0
SKIP_APT=0

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap-wsl-work.sh [options]

Default setup uses Ubuntu packages only.

Options:
  --with-node      Install fnm, Node LTS, and corepack
  --with-rust      Install rustup stable
  --with-neovim    Install Ubuntu neovim and link editor config
  --with-fzf       Install Ubuntu fzf
  --with-starship  Install starship from its upstream installer
  --with-lazygit   Install lazygit from its upstream release archive
  --with-yazi      Install yazi with cargo; requires --with-rust or existing cargo
  --skip-apt       Skip the core apt-get update/install step
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-node) WITH_NODE=1 ;;
    --with-rust) WITH_RUST=1 ;;
    --with-neovim) WITH_NEOVIM=1 ;;
    --with-fzf) WITH_FZF=1 ;;
    --with-starship) WITH_STARSHIP=1 ;;
    --with-lazygit) WITH_LAZYGIT=1 ;;
    --with-yazi) WITH_YAZI=1 ;;
    --skip-apt) SKIP_APT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

preflight() {
  [[ "$(uname -s)" == "Linux" ]] || die "This bootstrap is for Linux under WSL."
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || die "WSL kernel not detected."

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || die "Ubuntu is required; found ${ID:-unknown}."
    [[ "${VERSION_ID:-}" == 24.04* ]] || die "Ubuntu 24.04.x is required; found ${VERSION_ID:-unknown}."
  else
    die "/etc/os-release not found."
  fi

  [[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Run as your user, not with sudo."

  if [[ ! -d "/run/user/$(id -u)" ]]; then
    warn "XDG_RUNTIME_DIR (/run/user/$(id -u)) is missing - tools like fnm, gpg-agent, and systemctl --user may fail."
    warn "Fix once with: sudo loginctl enable-linger $USER && wsl.exe --shutdown"
  fi
}

record_tool() {
  local tool="$1"
  mkdir -p "$STATE_DIR"
  touch "$ENABLED_TOOLS"
  if ! grep -qxF "$tool" "$ENABLED_TOOLS"; then
    printf '%s\n' "$tool" >> "$ENABLED_TOOLS"
    sort -u "$ENABLED_TOOLS" -o "$ENABLED_TOOLS"
  fi
}

install_core_packages() {
  log "Installing core Ubuntu packages"
  sudo apt-get update -y
  sudo apt-get install -y \
    ca-certificates curl wget unzip xz-utils tar \
    git git-lfs git-secrets \
    jq make gcc g++ pkg-config libclang-dev \
    zsh tmux ripgrep fd-find bat \
    gpg gawk locales tree \
    keychain eza

  mkdir -p "$LOCAL_BIN"
  if need_cmd fdfind && ! need_cmd fd; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
  fi
  if need_cmd batcat && ! need_cmd bat; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
  fi
}

backup_path() {
  local path="$1"
  local backup
  backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
  warn "Backing up existing $path -> $backup"
  mv "$path" "$backup"
}

link_path() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    backup_path "$dst"
  fi
  ln -snf "$src" "$dst"
}

copy_template_if_missing() {
  local src="$1"
  local dst="$2"
  [[ -f "$dst" ]] && return 0
  mkdir -p "$(dirname "$dst")"
  sed "s|__HOME__|$HOME|g" "$src" > "$dst"
  chmod 600 "$dst"
}

ensure_work_identity_template() {
  local dst="$HOME/.gituserconfig.work"
  [[ -f "$dst" ]] && return 0
  cat > "$dst" <<'EOF'
# Work Git identity. Fill this in with work-approved values.
#
#[user]
#	name = Your Name
#	email = you@example.com
EOF
  chmod 600 "$dst"
  warn "Created $dst; edit it before committing in work repositories."
}

install_dotfiles() {
  log "Installing generated dotfile symlinks"
  mkdir -p "$CONFIG_DIR" "$HOME/.zsh" "$STATE_DIR"

  link_path "$DOTFILES_DIR/git/gitconfig.symlink" "$HOME/.gitconfig"
  link_path "$DOTFILES_DIR/git/gitignore_global.symlink" "$HOME/.gitignore_global"
  link_path "$DOTFILES_DIR/git/gitconfig-secrets.symlink" "$HOME/.gitconfig-secrets"
  link_path "$DOTFILES_DIR/git/git-core.symlink" "$HOME/.git-core"
  copy_template_if_missing "$DOTFILES_DIR/git/gitconfig-local.template" "$HOME/.gitconfig-local"
  ensure_work_identity_template

  link_path "$DOTFILES_DIR/zsh/zshrc.symlink" "$HOME/.zshrc"
  link_path "$DOTFILES_DIR/zsh/zprofile.symlink" "$HOME/.zprofile"
  link_path "$DOTFILES_DIR/zsh/zshenv.symlink" "$HOME/.zshenv"
  link_path "$DOTFILES_DIR/zsh/env" "$HOME/.zsh/env"
  link_path "$DOTFILES_DIR/zsh/alias.zsh" "$HOME/.zsh/alias.zsh"
  link_path "$DOTFILES_DIR/zsh/functions" "$HOME/.zsh/functions"

  mkdir -p "$CONFIG_DIR/tmux"
  link_path "$DOTFILES_DIR/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
  link_path "$DOTFILES_DIR/starship" "$CONFIG_DIR/starship"
}

install_node_optional() {
  [[ "$WITH_NODE" == "1" ]] || return 0
  log "Installing optional Node toolchain"
  if ! need_cmd fnm; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$LOCAL_BIN" --skip-shell
    export PATH="$LOCAL_BIN:$PATH"
  fi
  fnm install --lts
  fnm default lts-latest
  fnm exec --using=default -- corepack enable
  local fnm_default_bin="$HOME/.local/share/fnm/aliases/default/bin"
  for tool in node npm npx corepack; do
    [[ -e "$fnm_default_bin/$tool" ]] && ln -sf "$fnm_default_bin/$tool" "$LOCAL_BIN/$tool"
  done
  record_tool node
}

install_rust_optional() {
  [[ "$WITH_RUST" == "1" ]] || return 0
  log "Installing optional Rust toolchain"
  if ! need_cmd rustup; then
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
      sh -s -- -y --default-toolchain stable
  fi
  # shellcheck disable=SC1091
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
  rustup toolchain install stable
  rustup default stable
  record_tool rust
}

install_neovim_optional() {
  [[ "$WITH_NEOVIM" == "1" ]] || return 0
  log "Installing optional Neovim"
  sudo apt-get install -y neovim
  link_path "$DOTFILES_DIR/nvim" "$CONFIG_DIR/nvim"
  record_tool neovim
}

install_fzf_optional() {
  [[ "$WITH_FZF" == "1" ]] || return 0
  log "Installing optional fzf"
  sudo apt-get install -y fzf
  record_tool fzf
}

install_starship_optional() {
  [[ "$WITH_STARSHIP" == "1" ]] || return 0
  log "Installing optional starship"
  if ! need_cmd starship; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$LOCAL_BIN"
    export PATH="$LOCAL_BIN:$PATH"
  fi
  record_tool starship
}

install_lazygit_optional() {
  [[ "$WITH_LAZYGIT" == "1" ]] || return 0
  log "Installing optional lazygit"
  if need_cmd lazygit; then
    record_tool lazygit
    return 0
  fi
  local arch lazygit_arch version tmpdir tarball url
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) lazygit_arch="arm64" ;;
    x86_64|amd64) lazygit_arch="x86_64" ;;
    *) die "Unsupported architecture for lazygit: $arch" ;;
  esac
  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
    jq -r '.tag_name' | sed 's/^v//')"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' RETURN
  tarball="lazygit_${version}_Linux_${lazygit_arch}.tar.gz"
  url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"
  curl -fL "$url" -o "$tmpdir/$tarball"
  tar -xzf "$tmpdir/$tarball" -C "$tmpdir" lazygit
  mv "$tmpdir/lazygit" "$LOCAL_BIN/lazygit"
  chmod +x "$LOCAL_BIN/lazygit"
  record_tool lazygit
}

install_yazi_optional() {
  [[ "$WITH_YAZI" == "1" ]] || return 0
  log "Installing optional yazi"
  need_cmd cargo || die "cargo is required for yazi. Re-run with --with-rust --with-yazi."
  cargo install --locked --force yazi-build
  record_tool yazi
}

preflight
[[ "$SKIP_APT" == "1" ]] || install_core_packages
install_dotfiles
install_node_optional
install_rust_optional
install_neovim_optional
install_fzf_optional
install_starship_optional
install_lazygit_optional
install_yazi_optional

log "Bootstrap complete. Run scripts/audit-wsl-work.sh to verify."
