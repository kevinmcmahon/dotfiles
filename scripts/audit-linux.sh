#!/usr/bin/env bash
# shellcheck disable=SC2088
set -uo pipefail

# ------------------------------------------------------------------------------
# Linux Dev Environment Audit
# Checks for drift or misaligned configuration against what bootstrap.sh
# sets up on Linux. Safe to run anytime — read-only, changes nothing.
# ------------------------------------------------------------------------------

# Source shared audit library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPTS_DIR/lib/audit.sh" ]]; then
  printf "audit library not found: %s\n" "$SCRIPTS_DIR/lib/audit.sh" >&2
  exit 1
fi
# shellcheck source=SCRIPTDIR/lib/audit.sh
source "$SCRIPTS_DIR/lib/audit.sh"

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
optional_cmds=(eza zoxide tree keychain)
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

audit_section_git_core
audit_section_xdg_config
audit_section_tmux_xdg_layout
audit_section_zsh_environment
audit_section_oh_my_zsh
audit_section_git_identity

# --- Language runtimes ---
section "Language Runtimes"
check_cmd rustup "rustup"
check_cmd rustc "rustc"
check_cmd cargo "cargo"
check_cmd uv "uv"
check_cmd deno "deno"
check_cmd bun "bun"
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

  check_npm_global_prefix
else
  warn "node not installed (run: fnm install --lts)"
fi

# --- Cargo tools ---
section "Cargo Tools"
check_cmd tree-sitter "tree-sitter"
check_cmd delta "delta (git-delta)"
check_cmd viu "viu"
check_cmd jless "jless"

check_cmd yazi "yazi"

audit_section_python_tooling

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
      warn "llm plugin missing: $plugin"
    fi
  done
else
  fail "llm not installed"
fi

# --- LLM templates ---
section "LLM Templates"
llm_data_dir="$HOME/.config/io.datasette.llm"
check_symlink "$llm_data_dir/templates" "$DOTFILES_DIR/llm/templates.symlink" "llm templates"

audit_section_claude_config
audit_section_codex_config
audit_section_ai_clis
audit_section_standard_directories

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

audit_section_summary
