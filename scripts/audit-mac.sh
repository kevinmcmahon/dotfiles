#!/usr/bin/env bash
# shellcheck disable=SC2088
set -uo pipefail

# ------------------------------------------------------------------------------
# macOS Dev Environment Audit
# Checks for drift or misaligned configuration against what bootstrap.sh
# sets up on macOS. Safe to run anytime — read-only, changes nothing.
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

check_generated_common_ai_docs() {
  local tool="$1"
  local docs_dir="$2"
  local doc_path doc_name

  for doc_path in "$DOTFILES_DIR"/ai/docs/common/*; do
    [[ -f "$doc_path" ]] || continue
    doc_name="$(basename "$doc_path")"
    check_symlink "$docs_dir/$doc_name" "$doc_path" "$tool doc: $doc_name"
  done
}

is_fnm_path() {
  case "$1" in
    "$HOME/.local/share/fnm/"* | "$HOME/.local/state/fnm_multishells/"*) return 0 ;;
    *) return 1 ;;
  esac
}

check_npm_global_prefix() {
  local expected_prefix="$HOME/.local"
  local actual_prefix

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not available; skipping npm global prefix check"
    return 0
  fi

  actual_prefix="$(npm config get prefix 2>/dev/null)"
  if [[ "$actual_prefix" == "$expected_prefix" ]]; then
    pass "npm global prefix: $actual_prefix"
  else
    fail "npm global prefix: $actual_prefix (expected $expected_prefix)"
  fi
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

check_claude_mem_not_watching_codex() {
  local watch_config="$HOME/.claude-mem/transcript-watch.json"

  if [[ ! -f "$watch_config" ]]; then
    pass "claude-mem transcript watch does not exist"
    return
  fi

  if grep -q '~/.codex/' "$watch_config"; then
    fail "claude-mem transcript watch references ~/.codex"
  else
    pass "claude-mem transcript watch does not reference ~/.codex"
  fi
}

check_codex_has_no_claude_mem() {
  local codex_config="$HOME/.codex/config.toml"

  if [[ ! -f "$codex_config" ]]; then
    fail "Codex config missing: $codex_config"
    return
  fi

  if grep -Eq 'claude-mem|mcp-search|CLAUDE_CODE_' "$codex_config"; then
    fail "Codex config still references claude-mem, mcp-search, or CLAUDE_CODE_*"
  else
    pass "Codex config has no claude-mem, mcp-search, or CLAUDE_CODE_* references"
  fi
}

check_codex_sentry_mcp() {
  local codex_config="$HOME/.codex/config.toml"

  if [[ ! -f "$codex_config" ]]; then
    fail "Codex config missing: $codex_config"
    return
  fi

  if ! grep -q '^\[mcp_servers\.sentry\]' "$codex_config"; then
    fail "Codex config missing [mcp_servers.sentry] -- copy block from codex/config.toml.template"
    return
  fi

  # Sentry must stay disabled globally; projects enable it per-invocation with
  # `codex -c mcp_servers.sentry.enabled=true`.
  if awk '/^\[mcp_servers\.sentry\]/{found=1; next} /^\[/{found=0} found && /^enabled *= *false/{ok=1} END{exit !ok}' "$codex_config"; then
    pass "Codex sentry MCP server is registered and disabled globally"
  else
    fail "Codex sentry MCP server is not disabled globally (expected enabled = false)"
  fi
}

check_codex_hooks_json() {
  local hooks_json="$HOME/.codex/hooks.json"

  if [[ ! -f "$hooks_json" ]]; then
    fail "Codex hooks config missing: $hooks_json"
    return
  fi

  if grep -q '[$]HOME/.codex/hooks/ntfy-notify.sh' "$hooks_json"; then
    pass "Codex hooks use portable ntfy hook path"
  else
    fail "Codex hooks do not reference portable ntfy hook path"
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

# --- git-core directory ---
section "Git Core"
check_symlink "$HOME/.git-core" "$DOTFILES_DIR/git/git-core.symlink" "~/.git-core"

# --- XDG config directories ---
section "XDG Config Directories (~/.config)"
for d in nvim yazi starship git ghostty; do
  check_symlink "$CONFIG_DIR/$d" "$DOTFILES_DIR/$d" "~/.config/$d"
done
check_file_exists "$CONFIG_DIR/ghostty/appearance.conf" "~/.config/ghostty/appearance.conf"

# --- tmux XDG layout ---
section "tmux XDG Layout"
check_dir_exists "$CONFIG_DIR/tmux" "~/.config/tmux"
check_symlink "$CONFIG_DIR/tmux/tmux.conf" "$DOTFILES_DIR/tmux/tmux.conf" "~/.config/tmux/tmux.conf"
check_dir_exists "$CONFIG_DIR/tmux/plugins" "~/.config/tmux/plugins"
check_dir_exists "$CONFIG_DIR/tmux/plugins/tpm" "~/.config/tmux/plugins/tpm"

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
  expected_plugins=(llm-anthropic llm-gemini llm-openai-plugin llm-mistral)
  if [[ "$arch" == "arm64" ]]; then
    expected_plugins+=(llm-mlx)
  fi
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

# LLM templates — macOS uses ~/Library/Application Support, Linux uses ~/.config
section "LLM Templates"
llm_data_dir="$HOME/Library/Application Support/io.datasette.llm"
if [[ ! -d "$llm_data_dir" ]]; then
  llm_data_dir="$HOME/.config/io.datasette.llm"
fi
check_symlink "$llm_data_dir/templates" "$DOTFILES_DIR/llm/templates.symlink" "llm templates"

# --- Claude Code config ---
section "Claude Code Config"
for item in CLAUDE.md commands docs hooks settings.json scripts; do
  check_symlink "$HOME/.claude/$item" "$DOTFILES_DIR/claude/$item" "~/.claude/$item"
done
check_generated_common_ai_docs "Claude" "$HOME/.claude/docs"
if [[ -L "$HOME/.claude/skills" ]]; then
  fail "~/.claude/skills is a symlink (expected real local directory)"
else
  check_dir_exists "$HOME/.claude/skills" "~/.claude/skills"
fi

# Generated common skills
common_ai_skills=(
  book-refactoring-pass
  book-legacy-change
  book-reliability-review
  book-domain-modeling
  book-data-systems
  create-adr
)
for skill in "${common_ai_skills[@]}"; do
  check_symlink "$HOME/.claude/skills/$skill" "$DOTFILES_DIR/ai/skills/common/$skill" "~/.claude/skills/$skill"
done

# --- Codex config ---
section "Codex Config"
check_symlink "$HOME/.codex/AGENTS.md" "$DOTFILES_DIR/codex/AGENTS.md" "~/.codex/AGENTS.md"
check_claude_mem_not_watching_codex
check_codex_has_no_claude_mem
check_file_exists "$HOME/.codex/config.toml" "~/.codex/config.toml"
check_codex_sentry_mcp
check_codex_hooks_json
check_file_exists "$HOME/.codex/rules/default.rules" "~/.codex/rules/default.rules"
check_symlink "$HOME/.codex/hooks/ntfy-notify.sh" "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh" "~/.codex/hooks/ntfy-notify.sh"
for skill in "${common_ai_skills[@]}"; do
  check_symlink "$HOME/.codex/skills/$skill" "$DOTFILES_DIR/ai/skills/common/$skill" "~/.codex/skills/$skill"
done
check_symlink "$HOME/.codex/skills/perplexity" "$DOTFILES_DIR/ai/skills/codex/perplexity" "~/.codex/skills/perplexity"
check_symlink "$LOCAL_BIN/pplx-search" "$DOTFILES_DIR/ai/skills/codex/perplexity/pplx-search" "~/.local/bin/pplx-search"

# --- AI CLIs ---
section "AI CLIs"
check_cmd claude "Claude Code"
check_cmd codex "Codex CLI"

if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  pass "opencode installed"
else
  fail "opencode not installed"
fi

# OpenCode config
if [[ -f "$DOTFILES_DIR/opencode/opencode.json.symlink" ]]; then
  check_symlink "$CONFIG_DIR/opencode/opencode.json" "$DOTFILES_DIR/opencode/opencode.json.symlink" "opencode config"
fi
check_symlink "$HOME/.opencode/commands" "$DOTFILES_DIR/opencode/commands" "~/.opencode/commands"
check_symlink "$HOME/.opencode/docs" "$DOTFILES_DIR/opencode/docs" "~/.opencode/docs"
check_generated_common_ai_docs "OpenCode" "$HOME/.opencode/docs"
if [[ -L "$HOME/.opencode/skills" ]]; then
  fail "~/.opencode/skills is a symlink (expected real local directory)"
else
  check_dir_exists "$HOME/.opencode/skills" "~/.opencode/skills"
fi

# --- Directories ---
section "Standard Directories"
check_dir_exists "$LOCAL_BIN" "~/.local/bin"
check_dir_exists "$CONFIG_DIR" "~/.config"

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
