# shellcheck shell=bash
# shellcheck disable=SC2329
# scripts/lib/common.sh — Shared utilities and cross-platform installers
#
# This file is SOURCED by bootstrap.sh — do not add a shebang or set -euo pipefail.
# It expects these globals from the sourcing script:
#   DOTFILES_DIR, LOCAL_BIN, CONFIG_DIR, INSTALL_NODE, PLATFORM, ARCH
#
# node/install.sh also sources it, for log, warn, die and
# set_npm_install_policy, and sets none of those globals. Sourcing must
# therefore only define functions: read the globals inside the functions that
# need them, never at the top level.

# Directory holding this library; sibling libraries are sourced from here so
# the code that runs matches the checkout this file came from.
COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/expected-state.sh
source "$COMMON_LIB_DIR/expected-state.sh"

# ==============================================================================
# Utilities
# ==============================================================================

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

write_bootstrap_profile_marker() {
  local profile="${1:-${PROFILE:-workstation}}"
  local profile_dir="$CONFIG_DIR/dotfiles"
  local profile_file="$profile_dir/profile"
  local temporary

  case "$profile" in
    workstation|server) ;;
    *) die "Unknown Bootstrap profile marker: $profile" ;;
  esac

  mkdir -p "$profile_dir"
  temporary="$(mktemp "$profile_dir/.profile.XXXXXX")"
  printf '%s\n' "$profile" >"$temporary"
  chmod 644 "$temporary"
  mv "$temporary" "$profile_file"
  log "Recorded Bootstrap profile: $profile"
}

# Links dst -> src. A dst that is already that symlink is left alone; anything
# else at dst (file, directory, or other symlink) is moved to
# dst.bak.<timestamp> first. Creates dst's parent directory if needed.
link_with_backup() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup
    backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Backing up existing $dst -> $backup"
    mv "$dst" "$backup"
  fi

  ln -snf "$src" "$dst"
  log "Linked $dst -> $src"
}

# Applies the rows of one expected-state group (see expected-state.sh). An
# optional kind limits it to the rows of that kind.
apply_expected_state() {
  local group="$1"
  local only_kind="${2:-}"
  local rows kind src dst mode

  rows="$(expected_state_rows "$group")" || die "Unknown expected-state group: $group"

  while IFS=$'\t' read -r kind src dst mode; do
    [[ -n "$kind" ]] || continue
    [[ -z "$only_kind" || "$kind" == "$only_kind" ]] || continue
    case "$kind" in
      link) apply_expected_link "$src" "$dst" ;;
      real-dir) apply_expected_real_dir "$dst" ;;
      copy-once) apply_expected_copy_once "$src" "$dst" "$mode" ;;
      *) die "Unknown expected-state kind for $dst: $kind" ;;
    esac
  done <<<"$rows"
}

apply_expected_link() {
  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    warn "Not linking $dst: source missing: $src"
    return 0
  fi

  link_with_backup "$src" "$dst"
}

# A symlink where a real local directory belongs is moved to
# dst.bak.<timestamp>, then the real directory is created.
apply_expected_real_dir() {
  local dst="$1"

  if [[ -L "$dst" ]]; then
    local backup
    backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Backing up symlink $dst -> $backup (expected a real local directory)"
    mv "$dst" "$backup"
    mkdir -p "$dst"
    log "Created real local directory: $dst"
  else
    mkdir -p "$dst"
  fi
}

# Machine-local configs: copy repo defaults as starting templates.
# If dst is a symlink (leftover from older bootstrap), replace it with
# a real copy so local edits stay local. If dst is already a regular
# file, leave it alone — never overwrite local customizations.
# mode, when given, is applied to any file this function creates.
apply_expected_copy_once() {
  local src="$1"
  local dst="$2"
  local mode="${3:-}"

  if [[ -L "$dst" ]]; then
    # Migrate: dereference the symlink into a regular file
    local content
    content="$(cat "$dst" 2>/dev/null)" || content=""
    rm "$dst"
    if [[ -n "$content" ]]; then
      printf '%s\n' "$content" > "$dst"
      log "Converted $dst symlink to local file (preserved content)"
    elif [[ -f "$src" ]]; then
      cp "$src" "$dst"
      log "Replaced dangling $dst symlink with default template"
    else
      warn "$dst: removed an empty or dangling symlink and found no repo template to copy ($src missing); it is machine-local, so create it by hand if this machine needs it"
      return 0
    fi
  elif [[ -e "$dst" ]]; then
    return 0
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log "Copied default $src to $dst (edit for this machine)"
  else
    warn "$dst: no repo template to copy ($src missing); it is machine-local, so create it by hand if this machine needs it"
    return 0
  fi

  if [[ -n "$mode" ]]; then
    chmod "$mode" "$dst"
  fi
}

link_server_file() {
  local src="$1"
  local dst="$2"

  [[ -e "$src" || -L "$src" ]] || die "Server profile source is missing: $src"
  link_with_backup "$src" "$dst"
}

symlink_server_dotfiles() {
  log "Symlinking the reviewed server profile"

  link_server_file "$DOTFILES_DIR/git/gitconfig.symlink" "$HOME/.gitconfig"
  link_server_file "$DOTFILES_DIR/git/gitignore_global.symlink" "$HOME/.gitignore_global"
  link_server_file "$DOTFILES_DIR/zsh/zprofile.symlink" "$HOME/.zprofile"
  link_server_file "$DOTFILES_DIR/zsh/zshenv.symlink" "$HOME/.zshenv"
  link_server_file "$DOTFILES_DIR/zsh/zshrc.symlink" "$HOME/.zshrc"
  link_server_file "$DOTFILES_DIR/zsh/env" "$HOME/.zsh/env"
  link_server_file "$DOTFILES_DIR/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
}

ensure_server_git_identity() {
  log "Ensuring the server Git identity files exist"

  if [[ ! -f "$HOME/.gituserconfig" ]]; then
    cat >"$HOME/.gituserconfig" <<'EOF'
# Local Git identity. This file is not part of the dotfiles repository.
[user]
  # name = Your Name
  # email = you@example.com
EOF
    chmod 600 "$HOME/.gituserconfig"
    warn "Created $HOME/.gituserconfig; set the name and email before committing"
  fi

  if [[ ! -f "$HOME/.gitconfig-local" ]]; then
    : >"$HOME/.gitconfig-local"
    chmod 600 "$HOME/.gitconfig-local"
  fi
}

# The perplexity skill installs into the shared ~/.agents/skills store from the
# [[external]] pplx-search manifest entry. Its CLI is useful outside an agent
# session too, so link it onto PATH. Must run after install_ai_skills; the skill
# is absent when INSTALL_AI_SKILLS is unset, which is not an error.
ensure_pplx_search_bin() {
  log "Ensuring pplx-search is available on PATH"

  local src="${AGENT_SKILLS:-$HOME/.agents/skills}/perplexity/pplx-search"
  local dst="$LOCAL_BIN/pplx-search"

  if [[ ! -x "$src" ]]; then
    warn "pplx-search not installed: $src (run scripts/install-ai-skills.sh)"
    return 0
  fi

  mkdir -p "$LOCAL_BIN"

  if [[ -L "$dst" ]]; then
    [[ "$(readlink "$dst")" == "$src" ]] && return 0
  elif [[ -e "$dst" ]]; then
    warn "$dst exists and is not a symlink; leaving it unchanged"
    return 0
  fi

  ln -snf "$src" "$dst"
  log "Linked $dst -> $src"
}

# ==============================================================================
# Symlink Functions
# ==============================================================================

symlink_dotfiles_symlink_pattern() {
  log "Symlinking *.symlink dotfiles into \$HOME"

  [ -d "$DOTFILES_DIR" ] || die "DOTFILES_DIR not found: $DOTFILES_DIR"

  shopt -s nullglob
  # Symlink root-level *.symlink files
  for f in "$DOTFILES_DIR"/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    link_with_backup "$f" "$target"
  done

  # Symlink git/*.symlink files (gitconfig, gitignore_global, etc.)
  for f in "$DOTFILES_DIR"/git/*.symlink; do
    base="$(basename "$f" .symlink)"
    target="$HOME/.${base}"
    link_with_backup "$f" "$target"
  done

  # Symlink homebrew/*.symlink files (Brewfile, BootstrapBrewfile, etc.) — macOS only
  if [[ "$PLATFORM" == "Darwin" ]]; then
    for f in "$DOTFILES_DIR"/homebrew/*.symlink; do
      base="$(basename "$f" .symlink)"
      target="$HOME/.${base}"
      link_with_backup "$f" "$target"
    done
  fi

  # Symlink git-core directory for hooks and secrets
  local git_core_src="$DOTFILES_DIR/git/git-core.symlink"
  local git_core_dst="$HOME/.git-core"
  if [ -d "$git_core_src" ]; then
    link_with_backup "$git_core_src" "$git_core_dst"
  fi
  shopt -u nullglob
}

ensure_git_identity_templates() {
  log "Ensuring local git identity templates exist (no personal data)"

  local home_abs="$HOME"

  if [[ ! -f "$HOME/.gituserconfig" ]]; then
    cat >"$HOME/.gituserconfig" <<'EOF'
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
  log "Symlinking XDG config directories (nvim, yazi, starship, etc.)"

  mkdir -p "$CONFIG_DIR"

  apply_expected_state xdg
}

symlink_claude_config() {
  log "Symlinking Claude Code configs into ~/.claude"

  apply_expected_state claude
}

ensure_claude_skills_dir() {
  # Skills are local mutable install state. Dotfiles-owned skills are injected
  # into this real directory by ai-sync.sh; third-party skills may also live
  # here when installed by the skills CLI.
  apply_expected_state claude real-dir
}

ensure_opencode_skills_dir() {
  apply_expected_state opencode_ai_dirs real-dir
}

symlink_codex_config() {
  log "Configuring Codex"

  local codex_dst="$HOME/.codex"

  mkdir -p "$codex_dst"
  mkdir -p "$codex_dst/skills"

  apply_expected_state codex
}

# Runs the audit library's Claude Code and Codex sections as a bootstrap
# report. audit.sh defines its own warn/pass/fail, so it is sourced in a
# subshell to keep this library's helpers intact. Failures are reported but
# never fatal: bootstrap carries on and the platform audit gives the full
# picture.
audit_ai_tool_config() {
  log "Auditing Claude Code and Codex config"

  if (
    set +e
    # Not followed: audit.sh re-assigns DOTFILES_DIR, CONFIG_DIR and LOCAL_BIN
    # with defaults, which only matters inside this subshell. shellcheck checks
    # audit.sh on its own.
    # shellcheck source=/dev/null
    source "$COMMON_LIB_DIR/audit.sh"
    audit_section_claude_config
    audit_section_codex_config
    printf '\n  %d passed, %d failed, %d warnings\n' "$PASS" "$FAIL" "$WARN"
    [[ $FAIL -eq 0 ]]
  ); then
    log "Claude Code and Codex config OK"
  else
    warn "Claude Code and Codex config audit reported failures above; fix them and rerun scripts/audit-mac.sh or scripts/audit-linux.sh"
  fi
}

sync_ai_resources() {
  log "Syncing AI resources from canonical ai/ directory"

  local sync_script="$DOTFILES_DIR/scripts/ai-sync.sh"
  if [[ ! -x "$sync_script" ]]; then
    warn "ai-sync.sh not found or not executable, skipping"
    return 0
  fi

  "$sync_script"
}

install_ai_skills() {
  if [[ "${INSTALL_AI_SKILLS:-0}" != "1" ]]; then
    log "Skipping third-party AI skills install (set INSTALL_AI_SKILLS=1 to enable)"
    return 0
  fi

  log "Installing third-party AI skills from manifest"

  local install_script="$DOTFILES_DIR/scripts/install-ai-skills.sh"
  if [[ ! -x "$install_script" ]]; then
    warn "install-ai-skills.sh not found or not executable, skipping"
    return 0
  fi

  "$install_script"
}

symlink_opencode_ai_dirs() {
  log "Symlinking OpenCode AI directories into ~/.opencode"

  apply_expected_state opencode_ai_dirs
}

# ==============================================================================
# Shell
# ==============================================================================

install_zsh_environment() {
  log "Installing zsh environment (oh-my-zsh, plugins, symlinks)"

  if [[ ! -f "$DOTFILES_DIR/zsh/install.sh" ]]; then
    warn "zsh/install.sh not found, skipping zsh setup"
    return 0
  fi

  # SKIP_EXEC_ZSH: prevent zsh/install.sh from exec'ing into a new shell (blocks bootstrap)
  # SKIP_SSH_AGENT: prevent passphrase prompts during bootstrap
  local install_status
  if (
    export SKIP_SSH_AGENT=1 SKIP_EXEC_ZSH=1
    if [[ "$PROFILE" == server ]]; then
      export SKIP_DEFAULT_SHELL=1 SKIP_WORKSTATION_ALIASES=1
    fi
    bash "$DOTFILES_DIR/zsh/install.sh"
  ); then
    install_status=0
  else
    install_status=$?
    warn "zsh/install.sh reported errors (may still be partially successful)"
    [[ "$PROFILE" != server ]] || return "$install_status"
  fi

  log "zsh environment installed"
}

# ==============================================================================
# Shared Rustup Helper
# ==============================================================================

install_rustup() {
  log "Installing Rust toolchain"

  # Ensure ~/.cargo/bin is on PATH for the rest of this session
  export PATH="$HOME/.cargo/bin:$PATH"

  if ! need_cmd rustup; then
    log "Installing rustup (Rust toolchain manager)"
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs |
      sh -s -- -y --default-toolchain stable
  else
    log "rustup already installed"
  fi

  # shellcheck disable=SC1091
  source "$HOME/.cargo/env" || true

  if ! need_cmd rustup; then
    die "rustup not available after install"
  fi

  # Ensure stable toolchain is installed, default, and up-to-date.
  # Prevents build failures from stale apt-installed rustc or outdated toolchains.
  log "Ensuring stable Rust toolchain is current"
  rustup toolchain install stable
  rustup default stable
  rustup update stable

  if ! need_cmd cargo; then
    die "cargo not available after rustup install"
  fi

  log "rustup: $(rustup --version 2>/dev/null || echo 'unknown')"
  log "rustc:  $(rustc --version 2>/dev/null || echo 'unknown')"
}

# ==============================================================================
# Cross-platform Installers
# ==============================================================================

install_tmux_plugins() {
  log "Setting up tmux (XDG layout)"

  local tmux_config_dir="$CONFIG_DIR/tmux"
  local tpm_dir="$tmux_config_dir/plugins/tpm"

  # Symlink tmux.conf
  apply_expected_state tmux

  mkdir -p "$tmux_config_dir/plugins"

  # Clone TPM if missing
  if [ ! -d "$tpm_dir/.git" ]; then
    log "Cloning TPM into $tpm_dir"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  # Install plugins (non-interactive, safe if tmux isn't running)
  if [ -x "$tpm_dir/bin/install_plugins" ]; then
    log "Installing tmux plugins via TPM"
    "$tpm_dir/bin/install_plugins" || warn "TPM install_plugins returned non-zero (may be fine if tmux isn't running)"
  fi

  # Clean up legacy ~/.tmux.conf if it's a stale symlink to old dotfiles path
  if [ -L "$HOME/.tmux.conf" ]; then
    local old_target
    old_target="$(readlink "$HOME/.tmux.conf")"
    if [[ "$old_target" == *"dotfiles/tmux"* ]]; then
      rm "$HOME/.tmux.conf"
      log "Removed stale legacy symlink ~/.tmux.conf -> $old_target"
    fi
  fi
}

install_uv() {
  log "Installing uv (Python package manager)"

  # Link the user config before anything runs uv, so the release-age cooldown
  # applies to this bootstrap's own installs too.
  apply_expected_state uv

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

install_bun() {
  log "Installing Bun"

  # Link the user config (release-age cooldown) before anything runs bun.
  apply_expected_state bun

  if need_cmd bun || [[ -x "$HOME/.bun/bin/bun" ]]; then
    export PATH="$HOME/.bun/bin:$PATH"
    log "bun already installed: $(bun --version)"
    return 0
  fi

  curl -fsSL https://bun.sh/install | bash -s -- --no-modify-profile

  export PATH="$HOME/.bun/bin:$PATH"

  log "bun installed: $(bun --version 2>/dev/null || echo 'WARN: bun not found in PATH')"
}

ensure_local_bin_in_path() {
  log "Ensuring LOCAL_BIN is on PATH for this bootstrap run"
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    warn "$LOCAL_BIN not currently on PATH for this shell session."
    warn "Adding it for this bootstrap run."
    export PATH="$LOCAL_BIN:$PATH"
  fi
}

install_gemini_cli() {
  log "Installing Gemini CLI"

  local prefix="${GEMINI_CLI_PREFIX:-$HOME/.local}"
  local bin_dir="$prefix/bin"
  local expected="$bin_dir/gemini"

  if ! need_cmd node || ! need_cmd npm; then
    warn "node/npm not found; skipping Gemini CLI install (install Node via fnm first)."
    return 0
  fi

  mkdir -p "$bin_dir"

  if need_cmd gemini; then
    local found
    found="$(command -v gemini 2>/dev/null || true)"
    if [[ "$found" == "$expected" ]]; then
      log "gemini already installed at expected path: $found"
    else
      warn "gemini already found on PATH: $found"
      warn "Expected install location would be: $expected"
    fi
    log "gemini version: $(gemini --version 2>/dev/null | head -n 1 || echo 'unknown')"
    return 0
  fi

  log "Installing Gemini CLI to: $expected"
  log "Using per-install npm prefix (no global npm config changes)."

  # Gemini CLI's optional native modules build with install scripts. The npm
  # install policy (see expected_npm_config) fails an install on any script
  # that is not approved, so these two are approved by name. A new scripted
  # dependency stops this install with its name until it is added here.
  npm install -g --prefix "$prefix" \
    --allow-scripts=@github/keytar,node-pty \
    @google/gemini-cli

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$bin_dir"; then
    export PATH="$bin_dir:$PATH"
  fi

  if [[ -x "$expected" ]]; then
    log "Installed: $expected"
  else
    warn "Install completed but expected binary not found at: $expected"
  fi

  if need_cmd gemini; then
    log "gemini version: $(gemini --version 2>/dev/null | head -n 1 || echo 'unknown')"
  else
    warn "gemini not found in PATH after install. Ensure $bin_dir is on PATH."
    return 1
  fi
}

install_codex() {
  log "Installing Codex CLI"

  # Install location (overrideable)
  local prefix="${CODEX_PREFIX:-$HOME/.local}"
  local bin_dir="$prefix/bin"
  local expected="$bin_dir/codex"

  # Require node/npm (recommended: fnm-managed)
  if ! need_cmd node || ! need_cmd npm; then
    warn "node/npm not found; skipping Codex CLI install (install Node via fnm first)."
    return 0
  fi

  mkdir -p "$bin_dir"

  # Idempotency:
  # - If codex exists anywhere on PATH, don't reinstall.
  # - If it's not at expected path, show what we found.
  if need_cmd codex; then
    local found
    found="$(command -v codex 2>/dev/null || true)"
    if [[ "$found" == "$expected" ]]; then
      log "codex already installed at expected path: $found"
    else
      warn "codex already found on PATH: $found"
      warn "Expected install location would be: $expected"
    fi
    log "codex version: $(codex --version 2>/dev/null | head -n 1 || echo 'unknown')"
    return 0
  fi

  log "Installing Codex CLI to: $expected"
  log "Using per-install npm prefix (no global npm config changes)."

  npm install -g --prefix "$prefix" @openai/codex

  # Ensure this shell sees it immediately (bootstrap only; does not persist)
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$bin_dir"; then
    export PATH="$bin_dir:$PATH"
  fi

  if [[ -x "$expected" ]]; then
    log "Installed: $expected"
  else
    warn "Install completed but expected binary not found at: $expected"
  fi

  if need_cmd codex; then
    log "codex version: $(codex --version 2>/dev/null | head -n 1 || echo 'unknown')"
  else
    warn "codex not found in PATH after install. Ensure $bin_dir is on PATH."
    return 1
  fi
}

# Sets the npm user config keys listed by expected_npm_config (see
# expected-state.sh): a release-age cooldown, and a failed install rather than
# an unapproved dependency install script.
#
# `npm config set` rejects a key the running npm does not know, and
# `npm config get` prints "undefined" for one. Such a key is skipped with a
# warning so an older Node does not stop the caller; the audit fails on it.
set_npm_install_policy() {
  local key value

  log "Setting npm install policy..."
  while IFS=$'\t' read -r key value; do
    [[ -n "$key" ]] || continue
    if [[ "$(npm config get "$key" 2>/dev/null)" == "undefined" ]]; then
      warn "npm $(npm --version) does not support $key; upgrade Node (fnm install --lts) and rerun"
      continue
    fi
    npm config set "$key" "$value"
    printf '  npm %s: %s\n' "$key" "$(npm config get "$key")"
  done < <(expected_npm_config)
}

setup_node() {
  if [[ "$INSTALL_NODE" != "1" ]]; then
    log "Skipping Node.js setup (INSTALL_NODE=0)"
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

  log "Setting npm global prefix to $HOME/.local..."
  mkdir -p "$HOME/.local/bin"
  npm config set prefix "$HOME/.local"
  log "npm global prefix: $(npm config get prefix)"

  set_npm_install_policy

  log "Enabling corepack..."
  corepack enable

  log "Corepack enabled: $(corepack --version)"
}

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

# ==============================================================================
# Cross-platform Installers with Inline Platform Checks
# ==============================================================================

install_llm() {
  log "Installing Simon Willison's llm tool"

  if ! need_cmd llm; then
    if need_cmd uv; then
      uv tool install llm --python 3.12
    elif need_cmd pipx; then
      pipx install llm
    else
      warn "Neither uv nor pipx found; installing llm via uv after uv install"
      install_uv
      uv tool install llm --python 3.12
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
  if [[ "$PLATFORM" == "Darwin" && "$ARCH" == "arm64" ]]; then
    llm install -U llm-mlx
  elif [[ "$PLATFORM" == "Linux" ]]; then
    llm install -U llm-mlx
  else
    log "Skipping llm-mlx (not supported on macOS x86_64)"
  fi
}

symlink_llm_templates() {
  log "Symlinking llm templates"

  local src="$DOTFILES_DIR/llm/templates.symlink"

  local llm_data_dir
  if [[ "$PLATFORM" == "Darwin" ]]; then
    llm_data_dir="$HOME/Library/Application Support/io.datasette.llm"
    if [[ ! -d "$llm_data_dir" ]]; then
      llm_data_dir="$HOME/.config/io.datasette.llm"
    fi
  else
    llm_data_dir="$HOME/.config/io.datasette.llm"
  fi
  local dst="$llm_data_dir/templates"

  if [[ ! -d "$src" ]]; then
    warn "No llm templates found at $src (skipping)"
    return 0
  fi

  mkdir -p "$llm_data_dir"

  link_with_backup "$src" "$dst"
}

install_opencode() {
  log "Installing OpenCode"
  if need_cmd opencode || [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    export PATH="$HOME/.opencode/bin:$PATH"
    log "opencode already installed: $(opencode --version | head -n 1)"
  else
    # The installer modifies ~/.zshrc to add PATH — snapshot and restore to block it
    local zshrc_real
    zshrc_real="$(readlink -f "$HOME/.zshrc" 2>/dev/null || echo "$HOME/.zshrc")"
    local zshrc_snapshot=""
    if [[ -f "$zshrc_real" ]]; then
      zshrc_snapshot="$(cat "$zshrc_real")"
    fi

    curl -fsSL https://opencode.ai/install | bash

    # Restore .zshrc — we manage PATH ourselves
    if [[ -n "$zshrc_snapshot" && -f "$zshrc_real" ]]; then
      printf '%s\n' "$zshrc_snapshot" > "$zshrc_real"
    fi

    export PATH="$HOME/.opencode/bin:$PATH"

    log "opencode installed: $(opencode --version 2>/dev/null || echo 'WARN: opencode not found in PATH')"
  fi

  # Symlink config
  apply_expected_state opencode_config
}

# ==============================================================================
# Post-checks
# ==============================================================================

post_checks() {
  log "Quick sanity checks"
  need_cmd git || die "git missing"
  need_cmd tmux || warn "tmux missing"
  need_cmd nvim || warn "nvim missing"
  need_cmd rg || warn "ripgrep missing"
  need_cmd fd || warn "fd missing"
  need_cmd fzf || warn "fzf missing"
  need_cmd bat || warn "bat missing"
  need_cmd rustc || warn "rust missing"
  need_cmd cargo || warn "cargo missing"
  need_cmd uv || warn "uv missing"
  need_cmd deno || warn "deno missing"
  need_cmd bun || warn "bun missing"
  need_cmd fnm || warn "fnm missing"

  # Platform-specific post-checks (defined by platform modules)
  post_checks_platform

  need_cmd gemini || warn "gemini CLI missing"
  need_cmd node || log "Node.js not yet installed (run: fnm install --lts)"
}

post_checks_server() {
  log "Checking the server command set"
  local command_name
  for command_name in git jq zsh tmux nvim rg fd bat fzf less tree htop rsync ssh; do
    need_cmd "$command_name" || warn "$command_name missing"
  done
}

print_server_next_steps() {
  log "Server Bootstrap profile complete."
  log "Set your Git identity in ~/.gituserconfig before committing."
  if [[ -n "${LOG_FILE:-}" ]]; then
    log "Full bootstrap log saved to: $LOG_FILE"
  fi
}
