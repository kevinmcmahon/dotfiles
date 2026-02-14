#!/usr/bin/env bash
# shellcheck disable=SC2088
set -uo pipefail

# ------------------------------------------------------------------------------
# Linux Dev Environment Audit
# Checks for drift or misaligned configuration against what bootstrap.sh
# sets up on Linux. Safe to run anytime — read-only, changes nothing.
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"

# --- Counters ---
PASS=0
FAIL=0
WARN=0

# --- Output ---
pass() { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS + 1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL + 1)); }
warn() { printf "  \033[33m⚠\033[0m %s\n" "$*"; WARN=$((WARN + 1)); }
section() { printf "\n\033[1;34m━━━ %s ━━━\033[0m\n" "$*"; }

check_cmd() {
  local cmd="$1"
  local label="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$label: $(command -v "$cmd")"
  else
    fail "$label: not found"
  fi
}

check_symlink() {
  local target="$1"
  local expected="$2"
  local label="${3:-$target}"

  if [[ -L "$target" ]]; then
    local actual actual_resolved expected_resolved
    actual="$(readlink "$target")"
    # Resolve both to absolute paths for comparison (handles relative symlinks)
    actual_resolved="$(cd "$(dirname "$target")" && cd "$(dirname "$actual")" && pwd)/$(basename "$actual")"
    expected_resolved="$expected"
    if [[ "$actual" == "$expected" || "$actual_resolved" == "$expected_resolved" ]]; then
      pass "$label -> $actual"
    else
      fail "$label -> $actual (expected $expected)"
    fi
  elif [[ -e "$target" ]]; then
    fail "$label exists but is NOT a symlink (expected -> $expected)"
  else
    fail "$label missing (expected -> $expected)"
  fi
}

check_file_exists() {
  local path="$1"
  local label="${2:-$path}"
  if [[ -f "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing"
  fi
}

check_dir_exists() {
  local path="$1"
  local label="${2:-$path}"
  if [[ -d "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing"
  fi
}

# ==============================================================================
# Checks
# ==============================================================================

section "Platform"
if [[ "$(uname -s)" == "Linux" ]]; then
  pass "Linux detected"
else
  fail "Not Linux — this audit is for Linux only"
  exit 1
fi

arch="$(uname -m)"
case "$arch" in
  aarch64|arm64) pass "ARM64 (aarch64)" ;;
  x86_64|amd64)  pass "x86_64 (amd64)" ;;
  *)             warn "Unknown architecture: $arch" ;;
esac

# --- Base apt packages ---
section "Base apt Packages"
apt_cmds=(git git-lfs tmux rg jq make gcc zsh curl wget xclip)
for cmd in "${apt_cmds[@]}"; do
  check_cmd "$cmd" "$cmd"
done

# --- fd/bat wrappers ---
section "fd/bat Wrappers"
check_symlink "$LOCAL_BIN/fd" "$(command -v fdfind 2>/dev/null || echo "fdfind")" "~/.local/bin/fd"
check_symlink "$LOCAL_BIN/bat" "$(command -v batcat 2>/dev/null || echo "batcat")" "~/.local/bin/bat"

# --- Optional packages ---
section "Optional Packages"
optional_cmds=(eza zoxide tree)
for cmd in "${optional_cmds[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd: $(command -v "$cmd")"
  else
    warn "$cmd: not found (optional)"
  fi
done

# --- Root *.symlink files ---
section "Dotfile Symlinks (root-level)"
shopt -s nullglob
for f in "$DOTFILES_DIR"/*.symlink; do
  base="$(basename "$f" .symlink)"
  check_symlink "$HOME/.$base" "$f" "~/.$base"
done

# --- git/*.symlink files ---
section "Dotfile Symlinks (git/)"
for f in "$DOTFILES_DIR"/git/*.symlink; do
  base="$(basename "$f" .symlink)"
  check_symlink "$HOME/.$base" "$f" "~/.$base"
done
shopt -u nullglob

# --- git-core directory ---
section "Git Core"
check_symlink "$HOME/.git-core" "$DOTFILES_DIR/git/git-core.symlink" "~/.git-core"

# --- XDG config directories ---
section "XDG Config Directories (~/.config)"
for d in nvim yazi tmux starship git; do
  check_symlink "$CONFIG_DIR/$d" "$DOTFILES_DIR/$d" "~/.config/$d"
done

# tmux.conf at $HOME
if [[ -f "$DOTFILES_DIR/tmux/tmux.conf.symlink" ]]; then
  check_symlink "$HOME/.tmux.conf" "$DOTFILES_DIR/tmux/tmux.conf.symlink" "~/.tmux.conf"
fi

# --- Zsh symlinks ---
section "Zsh Environment"
check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/zsh/zshrc.symlink" "~/.zshrc"
check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/zsh/zprofile.symlink" "~/.zprofile"
check_symlink "$HOME/.zshenv" "$DOTFILES_DIR/zsh/zshenv.symlink" "~/.zshenv"
check_symlink "$HOME/.zsh/env" "$DOTFILES_DIR/zsh/env" "~/.zsh/env"

# --- Oh-my-zsh ---
section "Oh-My-Zsh"
check_dir_exists "$HOME/.oh-my-zsh" "~/.oh-my-zsh"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
omz_plugins=(git-open zsh-defer zsh-autosuggestions zsh-syntax-highlighting you-should-use fzf-tab)
for plugin in "${omz_plugins[@]}"; do
  check_dir_exists "$ZSH_CUSTOM/plugins/$plugin" "plugin: $plugin"
done

# alias.zsh linked into custom dir
check_symlink "$ZSH_CUSTOM/alias.zsh" "$DOTFILES_DIR/zsh/alias.zsh" "alias.zsh"

# --- Git identity ---
section "Git Identity"
check_file_exists "$HOME/.gituserconfig" "~/.gituserconfig"
check_file_exists "$HOME/.gitconfig-local" "~/.gitconfig-local"

# Check if gituserconfig has name/email set (not commented out)
if [[ -f "$HOME/.gituserconfig" ]]; then
  if grep -q '^[[:space:]]*name[[:space:]]*=' "$HOME/.gituserconfig"; then
    pass "~/.gituserconfig has name set"
  else
    warn "~/.gituserconfig: name is not set (still commented out?)"
  fi
  if grep -q '^[[:space:]]*email[[:space:]]*=' "$HOME/.gituserconfig"; then
    pass "~/.gituserconfig has email set"
  else
    warn "~/.gituserconfig: email is not set (still commented out?)"
  fi
fi

# Optional project-specific identities
for f in "$HOME/.gituserconfig.kmc" "$HOME/.gituserconfig.nsv"; do
  if [[ -f "$f" ]]; then
    pass "$(basename "$f") exists"
  else
    warn "$(basename "$f") not found (optional)"
  fi
done

# --- Language runtimes ---
section "Language Runtimes"
check_cmd rustup "rustup"
check_cmd rustc "rustc"
check_cmd cargo "cargo"
check_cmd uv "uv"
check_cmd deno "deno"
check_cmd fnm "fnm"

# --- Go ---
section "Go"
if [[ -x /usr/local/go/bin/go ]]; then
  pass "go: /usr/local/go/bin/go ($(/usr/local/go/bin/go version | awk '{print $3}'))"
elif command -v go >/dev/null 2>&1; then
  pass "go: $(command -v go)"
else
  fail "go not found (expected at /usr/local/go/bin/go)"
fi

# --- Ruby ---
section "Ruby"
if [[ -f /usr/local/share/chruby/chruby.sh ]]; then
  pass "chruby: /usr/local/share/chruby/chruby.sh"
else
  fail "chruby: /usr/local/share/chruby/chruby.sh not found"
fi
check_cmd ruby-install "ruby-install"

# --- Binary installs ---
section "Binary Installs"
check_file_exists "$LOCAL_BIN/nvim" "~/.local/bin/nvim (Neovim AppImage)"
check_file_exists "$LOCAL_BIN/lazygit" "~/.local/bin/lazygit"

# --- Starship & fzf ---
section "Starship & fzf"
check_cmd starship "starship"
check_cmd fzf "fzf"
check_dir_exists "$HOME/.fzf" "~/.fzf (git clone)"

# --- Node (optional) ---
section "Node (optional)"
if command -v node >/dev/null 2>&1; then
  pass "node: $(node --version)"

  # Check corepack
  if command -v corepack >/dev/null 2>&1; then
    pass "corepack: $(corepack --version)"
  else
    warn "corepack not enabled (run: corepack enable)"
  fi

  # Check yarn (via corepack)
  if command -v yarn >/dev/null 2>&1; then
    pass "yarn: $(yarn --version)"
  else
    warn "yarn not available (run: corepack enable)"
  fi

  # Check pnpm (via corepack)
  if command -v pnpm >/dev/null 2>&1; then
    pass "pnpm: $(pnpm --version)"
  else
    warn "pnpm not available (run: corepack enable)"
  fi
else
  warn "node not installed (run: fnm install --lts, or INSTALL_NODE=1)"
fi

# --- Cargo tools ---
section "Cargo Tools"
check_cmd viu "viu"
check_cmd tectonic "tectonic"
check_cmd yazi "yazi"

# --- Python tooling ---
section "Python Tooling"
check_cmd ruff "ruff"

NVIM_VENV_PY="$HOME/.local/share/nvim/venv/bin/python"
if [[ -x "$NVIM_VENV_PY" ]]; then
  if "$NVIM_VENV_PY" -c "import pynvim" 2>/dev/null; then
    pass "Neovim Python venv: pynvim OK"
  else
    fail "Neovim Python venv exists but pynvim import fails"
  fi
else
  fail "Neovim Python venv missing ($NVIM_VENV_PY)"
fi

# --- LLM ---
section "LLM Tool"
if command -v llm >/dev/null 2>&1; then
  pass "llm installed"
  installed_plugins="$(llm plugins 2>/dev/null)"
  expected_plugins=(llm-anthropic llm-gemini llm-openai-plugin llm-mistral llm-mlx)
  for plugin in "${expected_plugins[@]}"; do
    if echo "$installed_plugins" | grep -q "$plugin"; then
      pass "llm plugin: $plugin"
    else
      fail "llm plugin missing: $plugin"
    fi
  done
else
  fail "llm not installed"
fi

# --- LLM templates ---
section "LLM Templates"
llm_data_dir="$HOME/.config/io.datasette.llm"
check_symlink "$llm_data_dir/templates" "$DOTFILES_DIR/llm/templates.symlink" "llm templates"

# --- AI CLIs ---
section "AI CLIs"
check_cmd claude "Claude Code"

if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  pass "opencode installed"
else
  fail "opencode not installed"
fi

# OpenCode config
if [[ -f "$DOTFILES_DIR/opencode/opencode.json.symlink" ]]; then
  check_symlink "$CONFIG_DIR/opencode/opencode.json" "$DOTFILES_DIR/opencode/opencode.json.symlink" "opencode config"
fi

# --- Directories ---
section "Standard Directories"
check_dir_exists "$LOCAL_BIN" "~/.local/bin"
check_dir_exists "$CONFIG_DIR" "~/.config"

# --- Default shell ---
section "Shell"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" == *"zsh"* ]]; then
  pass "Default shell is zsh: $current_shell"
else
  warn "Default shell is not zsh: $current_shell"
fi

# --- pbcopy/pbpaste wrappers ---
section "pbcopy/pbpaste Wrappers"
if [[ -x "$LOCAL_BIN/pbcopy" ]]; then
  pass "~/.local/bin/pbcopy exists and is executable"
else
  fail "~/.local/bin/pbcopy missing or not executable"
fi

if [[ -x "$LOCAL_BIN/pbpaste" ]]; then
  pass "~/.local/bin/pbpaste exists and is executable"
else
  fail "~/.local/bin/pbpaste missing or not executable"
fi

# ==============================================================================
# Summary
# ==============================================================================

section "Summary"
total=$((PASS + FAIL + WARN))
printf "\n"
printf "  \033[32m%d passed\033[0m  " "$PASS"
printf "\033[31m%d failed\033[0m  " "$FAIL"
printf "\033[33m%d warnings\033[0m  " "$WARN"
printf "(%d total checks)\n\n" "$total"

if [[ $FAIL -gt 0 ]]; then
  printf "  Run \033[1mscripts/bootstrap.sh\033[0m to fix failures.\n\n"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  printf "  Some optional items need attention. Review warnings above.\n\n"
  exit 0
else
  printf "  \033[32mEverything looks good!\033[0m\n\n"
  exit 0
fi
