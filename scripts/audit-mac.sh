#!/usr/bin/env bash
# shellcheck disable=SC2088
set -uo pipefail

# ------------------------------------------------------------------------------
# macOS Dev Environment Audit
# Checks for drift or misaligned configuration against what bootstrap.sh
# sets up on macOS. Safe to run anytime — read-only, changes nothing.
# ------------------------------------------------------------------------------

# Source shared audit library
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPTS_DIR/lib/audit.sh" ]]; then
  printf "audit library not found: %s\n" "$SCRIPTS_DIR/lib/audit.sh" >&2
  exit 1
fi
# shellcheck source=SCRIPTDIR/lib/audit.sh
source "$SCRIPTS_DIR/lib/audit.sh"

is_fnm_path() {
  case "$1" in
    "$HOME/.local/share/fnm/"* | "$HOME/.local/state/fnm_multishells/"*) return 0 ;;
    *) return 1 ;;
  esac
}

check_interactive_zsh_node_resolution() {
  local shell_probe shell_node shell_npm shell_prefix

  if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not available; skipping interactive Node resolution check"
    return 0
  fi

  shell_probe="$(zsh -ic 'command -v node; command -v npm; npm config get prefix' 2>/dev/null)"
  shell_node="$(printf '%s\n' "$shell_probe" | sed -n '1p')"
  shell_npm="$(printf '%s\n' "$shell_probe" | sed -n '2p')"
  shell_prefix="$(printf '%s\n' "$shell_probe" | sed -n '3p')"

  if [[ -z "$shell_node" ]]; then
    warn "interactive zsh node not installed (run: fnm install --lts)"
  elif is_fnm_path "$shell_node"; then
    pass "interactive zsh node resolves through fnm: $shell_node"
  else
    fail "interactive zsh node resolves outside fnm: $shell_node"
  fi

  if [[ -z "$shell_npm" ]]; then
    warn "interactive zsh npm not available"
  elif is_fnm_path "$shell_npm"; then
    pass "interactive zsh npm resolves through fnm: $shell_npm"
  else
    fail "interactive zsh npm resolves outside fnm: $shell_npm"
  fi

  if [[ -n "$shell_prefix" ]]; then
    if [[ "$shell_prefix" == "$HOME/.local" ]]; then
      pass "interactive zsh npm global prefix: $shell_prefix"
    else
      fail "interactive zsh npm global prefix: $shell_prefix (expected $HOME/.local)"
    fi
  fi
}

get_default_shell_macos() {
  local shell_path

  shell_path="$(dscacheutil -q user -a name "$USER" 2>/dev/null | awk -F': ' '$1 == "shell" { print $2; exit }')"
  if [[ -n "$shell_path" ]]; then
    printf '%s\n' "$shell_path"
    return 0
  fi

  shell_path="$(id -P "$USER" 2>/dev/null | awk -F: '{ print $10 }')"
  if [[ -n "$shell_path" ]]; then
    printf '%s\n' "$shell_path"
    return 0
  fi

  return 1
}

# ==============================================================================
# Checks
# ==============================================================================

section "Platform"
if [[ "$(uname -s)" == "Darwin" ]]; then
  pass "macOS detected: $(sw_vers -productVersion)"
else
  fail "Not macOS — this audit is for macOS only"
  exit 1
fi

arch="$(uname -m)"
if [[ "$arch" == "arm64" ]]; then
  pass "Apple Silicon (arm64)"
elif [[ "$arch" == "x86_64" ]]; then
  pass "Intel (x86_64)"
else
  warn "Unknown architecture: $arch"
fi

# --- Xcode CLT ---
section "Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
  pass "Xcode CLT installed: $(xcode-select -p)"
else
  fail "Xcode CLT not installed"
fi

# --- Homebrew ---
section "Homebrew"
if command -v brew >/dev/null 2>&1; then
  pass "Homebrew installed: $(brew --prefix)"
else
  fail "Homebrew not found"
fi

# --- BootstrapBrewfile packages ---
section "Brew Packages (BootstrapBrewfile)"
brew_formulae=(
  bat coreutils curl direnv eza fd fzf git git-lfs jq ripgrep
  shellcheck tmux tree wget zoxide lazygit neovim starship
  go fnm chruby ruby-install yazi
)

for pkg in "${brew_formulae[@]}"; do
  if brew list "$pkg" &>/dev/null 2>&1; then
    pass "$pkg"
  else
    fail "$pkg not installed"
  fi
done


# --- Brew Cask apps ---
section "Brew Cask Apps"
cask_apps=(tailscale)
for app in "${cask_apps[@]}"; do
  # Capitalise first letter for /Applications check
  app_name="$(tr '[:lower:]' '[:upper:]' <<< "${app:0:1}")${app:1}"
  if brew list --cask "$app" &>/dev/null 2>&1; then
    pass "$app"
  elif [[ -d "/Applications/${app_name}.app" ]]; then
    pass "$app (found in /Applications)"
  else
    fail "$app not installed"
  fi
done

# --- Terminal applications ---
section "Terminal Applications"
check_dir_exists "/Applications/cmux.app" "/Applications/cmux.app"
check_file_exists "/Applications/cmux.app/Contents/Resources/bin/cmux" "cmux bundled CLI"
check_symlink "$LOCAL_BIN/cmux" "/Applications/cmux.app/Contents/Resources/bin/cmux" "~/.local/bin/cmux"

# --- Brew Cask fonts ---
section "Fonts"
fonts=(font-fira-code-nerd-font font-jetbrains-mono-nerd-font font-monaspace)
for font in "${fonts[@]}"; do
  if brew list --cask "$font" &>/dev/null 2>&1; then
    pass "$font"
  else
    fail "$font not installed"
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

# --- osx/*.symlink files ---
section "Dotfile Symlinks (osx/)"
for f in "$DOTFILES_DIR"/osx/*.symlink; do
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

# --- CLI tools (non-brew) ---
section "Language Runtimes & CLI Tools"
check_cmd rustup "rustup"
check_cmd rustc "rustc"
check_cmd cargo "cargo"
check_cmd go "go"
check_cmd uv "uv"
check_cmd deno "deno"
check_cmd bun "bun"
check_cmd fnm "fnm"
check_cmd chruby-exec "chruby"

# Optional: node (installed via fnm during bootstrap unless INSTALL_NODE=0)
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
  check_interactive_zsh_node_resolution
else
  warn "node not installed (run: fnm install --lts)"
fi

# --- Cargo tools ---
section "Cargo / Brew-installed Tools"
check_cmd tree-sitter "tree-sitter"
check_cmd viu "viu"
check_cmd jless "jless"


audit_section_python_tooling

# --- LLM ---
section "LLM Tool"
if command -v llm >/dev/null 2>&1; then
  pass "llm installed"
  installed_plugins="$(llm plugins 2>/dev/null)"
  expected_plugins=(llm-anthropic llm-gemini llm-openai-plugin llm-mistral)
  if [[ "$arch" == "arm64" ]]; then
    expected_plugins+=(llm-mlx)
  fi
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

# LLM templates — macOS uses ~/Library/Application Support, Linux uses ~/.config
section "LLM Templates"
llm_data_dir="$HOME/Library/Application Support/io.datasette.llm"
if [[ ! -d "$llm_data_dir" ]]; then
  llm_data_dir="$HOME/.config/io.datasette.llm"
fi
check_symlink "$llm_data_dir/templates" "$DOTFILES_DIR/llm/templates.symlink" "llm templates"

audit_section_claude_config
audit_section_codex_config
audit_section_ai_clis
audit_section_standard_directories

# --- Default shell ---
section "Shell"
if current_shell="$(get_default_shell_macos)"; then
  if [[ "$current_shell" == *"zsh"* ]]; then
    pass "Default shell is zsh: $current_shell"
  else
    warn "Default shell is not zsh: $current_shell"
  fi
else
  warn "Unable to determine default shell"
fi

# --- macOS Defaults (spot-check key settings) ---
section "macOS Defaults (spot check)"

check_default() {
  local domain="$1"
  local key="$2"
  local expected="$3"
  local label="${4:-$domain $key}"

  local actual
  actual="$(defaults read "$domain" "$key" 2>/dev/null)" || {
    warn "$label: not set"
    return
  }

  if [[ "$actual" == "$expected" ]]; then
    pass "$label = $expected"
  else
    fail "$label = $actual (expected $expected)"
  fi
}

check_default "com.apple.finder" "AppleShowAllFiles" "1" "Finder: show hidden files"
check_default "NSGlobalDomain" "AppleShowAllExtensions" "1" "Finder: show extensions"
check_default "com.apple.finder" "ShowStatusBar" "1" "Finder: status bar"
check_default "com.apple.finder" "ShowPathbar" "1" "Finder: path bar"
check_default "com.apple.finder" "FXPreferredViewStyle" "Nlsv" "Finder: list view"
check_default "NSGlobalDomain" "ApplePressAndHoldEnabled" "0" "Keyboard: key repeat"
check_default "com.apple.screencapture" "type" "png" "Screenshots: PNG format"
check_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "1" "No .DS_Store on network"

# --- Spotlight exclusions ---
section "Spotlight Exclusions"
for d in "$HOME/Library/Caches" "$HOME/Library/Developer"; do
  idx="$d/.metadata_never_index"
  if [[ -f "$idx" ]]; then
    pass "$idx"
  else
    warn "$idx missing"
  fi
done

# --- ~/Library visibility ---
section "Library Visibility"
# stat with -f %Xf gets the BSD file flags; 0x8000 = UF_HIDDEN
lib_flags="$(stat -f '%Xf' ~/Library 2>/dev/null || echo "0")"
if (( (16#$lib_flags & 0x8000) == 0 )); then
  pass "~/Library is visible"
else
  fail "~/Library is hidden (run: chflags nohidden ~/Library)"
fi

audit_section_summary
