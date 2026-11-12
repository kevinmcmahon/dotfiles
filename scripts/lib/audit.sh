# shellcheck shell=bash
# shellcheck disable=SC2088
# scripts/lib/audit.sh — Shared checks for the platform audit scripts
#
# This file is SOURCED by audit-linux.sh and audit-mac.sh — do not add a
# shebang or set shell options. Sourcing it only defines functions and
# initializes the defaults and counters below; nothing runs until the sourcing
# script calls a check or an audit_section_* function.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
# Shared skills store the `skills` CLI writes to. Codex, OpenCode, Gemini CLI, and
# Antigravity read it directly; Claude Code reads symlinks into ~/.claude/skills.
AGENT_SKILLS="${AGENT_SKILLS:-$HOME/.agents/skills}"

# The expected links, copies and real directories bootstrap applies.
# shellcheck source=SCRIPTDIR/expected-state.sh
source "$(dirname "${BASH_SOURCE[0]}")/expected-state.sh"

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

# A path that must be a real local directory, never a symlink.
check_real_dir() {
  local path="$1"
  local label="${2:-$path}"
  if [[ -L "$path" ]]; then
    fail "$label is a symlink (expected real local directory)"
  else
    check_dir_exists "$path" "$label"
  fi
}

# A copy-once file is a regular local file that bootstrap copied from the repo
# once and never overwrites. Some templates are gitignored machine-local files
# (claude/mcp.json, for example); without one, bootstrap has nothing to copy,
# so a missing file is a warning rather than a failure.
check_copy_once() {
  local src="$1"
  local path="$2"
  local label="${3:-$path}"
  if [[ -L "$path" ]]; then
    fail "$label is a symlink (expected local copy)"
  elif [[ -f "$path" ]]; then
    pass "$label exists"
  elif [[ -e "$path" ]]; then
    fail "$label exists but is not a regular file (expected local copy)"
  elif [[ -f "$src" ]]; then
    fail "$label missing"
  else
    warn "$label missing; no repo template to copy ($src), so it is machine-local: create it by hand if this machine needs it"
  fi
}

# Checks the rows of one expected-state group (see expected-state.sh). Labels
# show the destination with $HOME written as ~.
check_expected_state() {
  local group="$1"
  local rows kind src dst label

  if ! rows="$(expected_state_rows "$group" 2>&1)"; then
    fail "$rows"
    return
  fi

  while IFS=$'\t' read -r kind src dst _; do
    [[ -n "$kind" ]] || continue
    label="$dst"
    if [[ "$dst" == "$HOME"/* ]]; then
      label="~${dst#"$HOME"}"
    fi
    case "$kind" in
      link) check_symlink "$dst" "$src" "$label" ;;
      real-dir) check_real_dir "$dst" "$label" ;;
      copy-once) check_copy_once "$src" "$dst" "$label" ;;
      *) fail "$label: unknown expected-state kind: $kind" ;;
    esac
  done <<<"$rows"
}

# Passes an executable path, fails one that is not executable or is a broken
# symlink. An absent path is skipped: the link check for it reports that.
check_executable() {
  local path="$1"
  local label="${2:-$path}"
  if [[ -L "$path" && ! -e "$path" ]]; then
    fail "$label is a broken symlink -> $(readlink "$path")"
  elif [[ ! -e "$path" ]]; then
    return 0
  elif [[ -x "$path" ]]; then
    pass "$label is executable"
  else
    fail "$label is not executable"
  fi
}

# Check hooks are executable (including through symlink chains)
check_claude_hooks_executable() {
  local hook
  for hook in "$HOME"/.claude/hooks/*.sh; do
    [[ -e "$hook" || -L "$hook" ]] || continue
    check_executable "$hook" "~/.claude/hooks/$(basename "$hook")"
  done
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

# Checks the npm user config keys listed by expected_npm_config. Without npm
# there is nothing to check: the platform audit reports a missing node. npm
# prints "undefined" for a key it does not know, which no `npm config set`
# can fix.
check_npm_install_policy() {
  local key expected actual

  command -v npm >/dev/null 2>&1 || return 0

  while IFS=$'\t' read -r key expected; do
    [[ -n "$key" ]] || continue
    actual="$(npm config get "$key" 2>/dev/null)"
    if [[ "$actual" == "$expected" ]]; then
      pass "npm $key: $actual"
    elif [[ "$actual" == "undefined" ]]; then
      fail "npm $key: not supported by npm $(npm --version 2>/dev/null) (upgrade Node: fnm install --lts, then rerun node/install.sh)"
    else
      fail "npm $key: $actual (expected $expected; run: npm config set $key $expected)"
    fi
  done < <(expected_npm_config)
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

# Claude Code plugins are installed from remote marketplaces, not symlinked out
# of this repo. claude/settings.json is the declaration; Claude Code records what
# it actually installed under ~/.claude/plugins/. This compares the two.
# ~/.claude/settings.json is a local copy of the repo file, not a symlink:
# Claude Code saves it by replacing the file. Drift from the repo copy is a
# warning so changes worth keeping get synced back by hand.
check_claude_settings_copy() {
  local live="$HOME/.claude/settings.json"
  local repo="$DOTFILES_DIR/claude/settings.json"

  # The claude expected-state check reports a symlinked or missing local copy;
  # this check covers drift only.
  if [[ -L "$live" || ! -f "$live" ]]; then
    return 0
  fi

  if [[ ! -f "$repo" ]]; then
    fail "Claude settings missing: $repo"
  elif cmp -s "$live" "$repo"; then
    pass "~/.claude/settings.json matches the repo copy"
  else
    warn "~/.claude/settings.json differs from $repo (copy changes worth keeping back to the repo)"
  fi
}

check_claude_plugins() {
  local settings="$DOTFILES_DIR/claude/settings.json"
  local installed="$HOME/.claude/plugins/installed_plugins.json"
  local known="$HOME/.claude/plugins/known_marketplaces.json"
  local name repo actual plugin installed_list
  local declared_markets=0 missing_markets=0
  local enabled_count=0 missing_plugins=0

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found; skipping Claude Code plugin checks"
    return
  fi

  if [[ ! -f "$settings" ]]; then
    fail "Claude settings missing: $settings"
    return
  fi

  # Every marketplace declared in dotfiles must be registered under the same repo.
  if [[ ! -f "$known" ]]; then
    fail "Claude marketplaces not registered: $known missing"
  else
    while IFS=$'\t' read -r name repo; do
      [[ -n "$name" ]] || continue
      declared_markets=$((declared_markets + 1))
      actual="$(jq -r --arg n "$name" '.[$n].source.repo // ""' "$known")"
      if [[ -z "$actual" ]]; then
        fail "Claude marketplace not registered: $name ($repo)"
        missing_markets=$((missing_markets + 1))
      elif [[ "$actual" != "$repo" ]]; then
        fail "Claude marketplace repo mismatch: $name -> $actual (expected $repo)"
        missing_markets=$((missing_markets + 1))
      fi
    done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[] | "\(.key)\t\(.value.source.repo // "")"' "$settings")

    if [[ $missing_markets -eq 0 && $declared_markets -gt 0 ]]; then
      pass "Claude marketplaces registered ($declared_markets declared)"
    fi
  fi

  # Enabled marketplace plugins need install records. Built-ins are supplied by
  # Claude Code and expose their availability only inside a session's /plugin UI.
  installed_list=""
  if [[ -f "$installed" ]]; then
    installed_list="$(jq -r '.plugins // {} | keys[]' "$installed")"
  fi

  while read -r plugin; do
    [[ -n "$plugin" ]] || continue
    if [[ "$plugin" == *@builtin ]]; then
      printf '  Claude built-in: %s (check availability in a session with /plugin)\n' "$plugin"
      continue
    fi
    if [[ ! -f "$installed" ]]; then
      fail "Claude plugins not installed: $installed missing"
      return
    fi
    enabled_count=$((enabled_count + 1))
    if ! grep -qxF "$plugin" <<<"$installed_list"; then
      fail "Claude plugin enabled but not installed: $plugin"
      missing_plugins=$((missing_plugins + 1))
    fi
  done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings")

  if [[ $missing_plugins -eq 0 && $enabled_count -gt 0 ]]; then
    pass "Claude plugins installed ($enabled_count enabled marketplace plugins)"
  fi
}

# The perplexity skill and its pplx-search CLI ship from
# github.com/kevinmcmahon/pplx-search, not from this repo. Claude Code gets it from
# the perplexity@pplx-search plugin (covered by check_claude_plugins); Codex,
# OpenCode, and the other agents read the shared ~/.agents/skills store the skills
# CLI writes to. Only presence and usability are checked, never how the entry was
# provisioned, so a manifest install and a local dev checkout both pass.
check_perplexity_skill() {
  local skill="$AGENT_SKILLS/perplexity"
  local bin="$LOCAL_BIN/pplx-search"

  if [[ ! -d "$skill" ]]; then
    fail "perplexity skill missing: $skill (scripts/install-ai-skills.sh installs it from kevinmcmahon/pplx-search)"
  elif [[ ! -f "$skill/SKILL.md" ]]; then
    fail "perplexity skill incomplete: $skill/SKILL.md not found"
  elif [[ ! -x "$skill/pplx-search" ]]; then
    fail "perplexity CLI missing or not executable: $skill/pplx-search"
  else
    pass "perplexity skill available to Codex/OpenCode: $skill"
  fi

  if [[ -x "$bin" ]]; then
    pass "pplx-search on PATH: $bin"
  else
    fail "pplx-search missing or not executable: $bin (link it from $skill/pplx-search)"
  fi
}

# ==============================================================================
# Shared Sections
# ==============================================================================

# --- git-core directory ---
audit_section_git_core() {
  section "Git Core"
  check_symlink "$HOME/.git-core" "$DOTFILES_DIR/git/git-core.symlink" "~/.git-core"
}

# --- XDG config directories ---
audit_section_xdg_config() {
  section "XDG Config Directories (~/.config)"
  check_expected_state xdg
  check_file_exists "$CONFIG_DIR/ghostty/appearance.conf" "~/.config/ghostty/appearance.conf"
}

# --- Package install policy ---
# The release-age cooldown for uv, bun and npm, and npm's refusal to run
# unapproved dependency install scripts.
audit_section_package_install_policy() {
  section "Package Install Policy"
  check_expected_state uv
  check_expected_state bun
  check_npm_install_policy
}

# --- tmux XDG layout ---
audit_section_tmux_xdg_layout() {
  section "tmux XDG Layout"
  check_expected_state tmux
  check_dir_exists "$CONFIG_DIR/tmux/plugins" "~/.config/tmux/plugins"
  check_dir_exists "$CONFIG_DIR/tmux/plugins/tpm" "~/.config/tmux/plugins/tpm"
}

# --- Zsh symlinks ---
audit_section_zsh_environment() {
  section "Zsh Environment"
  check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/zsh/zshrc.symlink" "~/.zshrc"
  check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/zsh/zprofile.symlink" "~/.zprofile"
  check_symlink "$HOME/.zshenv" "$DOTFILES_DIR/zsh/zshenv.symlink" "~/.zshenv"
  check_symlink "$HOME/.zsh/env" "$DOTFILES_DIR/zsh/env" "~/.zsh/env"
}

# --- Oh-my-zsh ---
audit_section_oh_my_zsh() {
  section "Oh-My-Zsh"
  check_dir_exists "$HOME/.oh-my-zsh" "~/.oh-my-zsh"

  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  omz_plugins=(git-open zsh-defer zsh-autosuggestions zsh-syntax-highlighting you-should-use fzf-tab)
  for plugin in "${omz_plugins[@]}"; do
    check_dir_exists "$ZSH_CUSTOM/plugins/$plugin" "plugin: $plugin"
  done

  # alias.zsh linked into custom dir
  check_symlink "$ZSH_CUSTOM/alias.zsh" "$DOTFILES_DIR/zsh/alias.zsh" "alias.zsh"
}

# --- Git identity ---
audit_section_git_identity() {
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
}

# --- Python tooling ---
audit_section_python_tooling() {
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
}

# --- Claude Code config ---
audit_section_claude_config() {
  section "Claude Code Config"
  check_expected_state claude
  check_claude_settings_copy
  check_claude_hooks_executable
  check_generated_common_ai_docs "Claude" "$HOME/.claude/docs"

  # Generated common skills
  local skill
  for skill in $(expected_common_ai_skills); do
    check_symlink "$HOME/.claude/skills/$skill" "$DOTFILES_DIR/ai/skills/common/$skill" "~/.claude/skills/$skill"
  done

  check_claude_plugins
}

# --- Codex config ---
audit_section_codex_config() {
  section "Codex Config"
  check_expected_state codex
  check_executable "$HOME/.codex/hooks/ntfy-notify.sh" "~/.codex/hooks/ntfy-notify.sh"
  check_claude_mem_not_watching_codex
  check_codex_has_no_claude_mem
  check_codex_sentry_mcp
  check_codex_hooks_json
  local skill
  for skill in $(expected_common_ai_skills); do
    check_symlink "$HOME/.codex/skills/$skill" "$DOTFILES_DIR/ai/skills/common/$skill" "~/.codex/skills/$skill"
  done
}

# --- AI CLIs ---
audit_section_ai_clis() {
  section "AI CLIs"
  check_cmd claude "Claude Code"
  check_cmd codex "Codex CLI"

  if command -v opencode >/dev/null 2>&1 || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    pass "opencode installed"
  else
    fail "opencode not installed"
  fi

  # OpenCode config
  check_expected_state opencode
  check_generated_common_ai_docs "OpenCode" "$HOME/.opencode/docs"

  check_perplexity_skill
}

# --- Directories ---
audit_section_standard_directories() {
  section "Standard Directories"
  check_dir_exists "$LOCAL_BIN" "~/.local/bin"
  check_dir_exists "$CONFIG_DIR" "~/.config"
}

# ==============================================================================
# Summary
# ==============================================================================

audit_section_summary() {
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
}
