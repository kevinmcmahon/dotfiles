# shellcheck shell=bash
# scripts/lib/common.sh — Shared utilities and cross-platform installers
#
# This file is SOURCED by bootstrap.sh — do not add a shebang or set -euo pipefail.
# It expects these globals from the sourcing script:
#   DOTFILES_DIR, LOCAL_BIN, CONFIG_DIR, INSTALL_NODE, PLATFORM, ARCH

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

ensure_local_bin_in_path() {
  log "Ensuring ~/.local/bin is in PATH"
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    warn "$HOME/.local/bin not currently on PATH for this shell session."
    warn "Adding it for bootstrap; make sure your zsh config exports it permanently."
    export PATH="$LOCAL_BIN:$PATH"
  fi
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

  # Symlink osx/*.symlink files (Brewfile, BootstrapBrewfile, etc.) — macOS only
  if [[ "$PLATFORM" == "Darwin" ]]; then
    for f in "$DOTFILES_DIR"/osx/*.symlink; do
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
  fi

  # Symlink git-core directory for hooks and secrets
  local git_core_src="$DOTFILES_DIR/git/git-core.symlink"
  local git_core_dst="$HOME/.git-core"
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

  local topics="nvim yazi starship git ghostty"

  for d in $topics; do
    local src="$DOTFILES_DIR/$d"
    local dst="$CONFIG_DIR/$d"
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

}

symlink_claude_config() {
  log "Symlinking Claude Code configs into ~/.claude"

  local claude_src="$DOTFILES_DIR/claude"
  local claude_dst="$HOME/.claude"

  mkdir -p "$claude_dst"

  # Symlink individual items — NOT the whole directory, because ~/.claude
  # also contains machine-local state (settings.local.json, credentials,
  # cache, history, etc.). Machine-local configs (mcp.json,
  # claude_desktop_config.json) are copied as templates, not symlinked.
  local items="CLAUDE.md settings.json commands docs hooks skills scripts"

  for item in $items; do
    local src="$claude_src/$item"
    local dst="$claude_dst/$item"
    if [ -e "$src" ] || [ -d "$src" ]; then
      if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        continue
      fi
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing $dst -> $backup"
        mv "$dst" "$backup"
      fi
      ln -snf "$src" "$dst"
      log "Linked $dst -> $src"
    fi
  done

  # Machine-local configs: copy repo defaults as starting templates.
  # If dst is a symlink (leftover from older bootstrap), replace it with
  # a real copy so local edits stay local. If dst is already a regular
  # file, leave it alone — never overwrite local customizations.
  for tmpl in mcp.json claude_desktop_config.json; do
    local src="$claude_src/$tmpl"
    local dst="$claude_dst/$tmpl"
    if [[ -L "$dst" ]]; then
      # Migrate: dereference the symlink into a regular file
      local content
      content="$(cat "$dst" 2>/dev/null)" || content=""
      rm "$dst"
      if [[ -n "$content" ]]; then
        printf '%s\n' "$content" > "$dst"
        log "Converted $tmpl symlink to local file (preserved content)"
      elif [[ -f "$src" ]]; then
        cp "$src" "$dst"
        log "Replaced dangling $tmpl symlink with default template"
      fi
    elif [[ ! -e "$dst" ]] && [[ -f "$src" ]]; then
      cp "$src" "$dst"
      log "Copied default $tmpl to $dst (edit for this machine)"
    fi
  done
}

verify_claude_setup() {
  log "Verifying Claude Code setup"
  local claude_dst="$HOME/.claude"
  local errors=0

  # Check symlinks resolve
  for item in CLAUDE.md settings.json commands docs hooks skills scripts; do
    local path="$claude_dst/$item"
    if [[ -L "$path" && ! -e "$path" ]]; then
      warn "Broken symlink: $path -> $(readlink "$path")"
      errors=$((errors + 1))
    fi
  done

  # Check hooks are executable (including through symlink chains)
  for hook in "$claude_dst"/hooks/*.sh; do
    [[ -e "$hook" || -L "$hook" ]] || continue
    if [[ -L "$hook" && ! -e "$hook" ]]; then
      warn "Broken hook symlink: $hook -> $(readlink "$hook")"
      errors=$((errors + 1))
    elif [[ ! -x "$hook" ]]; then
      warn "Hook not executable: $hook"
      errors=$((errors + 1))
    fi
  done

  # Check tools required by hooks/statusline
  for cmd in jq curl; do
    need_cmd "$cmd" || { warn "$cmd not found (needed by Claude hooks)"; errors=$((errors + 1)); }
  done

  # Check mcp.json exists (as a regular file, not a symlink)
  if [[ ! -f "$claude_dst/mcp.json" ]]; then
    warn "mcp.json missing -- copy from $DOTFILES_DIR/claude/mcp.json or claude/mcp.json.example"
    errors=$((errors + 1))
  fi

  if (( errors > 0 )); then
    warn "Claude setup: $errors issue(s) above"
  else
    log "Claude Code setup OK"
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

symlink_opencode_ai_dirs() {
  log "Symlinking OpenCode AI directories into ~/.opencode"

  local opencode_dst="$HOME/.opencode"

  for resource in commands docs skills; do
    local src="$DOTFILES_DIR/opencode/$resource"
    local dst="$opencode_dst/$resource"

    if [[ ! -d "$src" ]]; then
      continue
    fi

    mkdir -p "$opencode_dst"

    if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
      continue
    fi

    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
      local backup="${dst}.bak-$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $dst -> $backup"
      mv "$dst" "$backup"
    fi

    ln -snf "$src" "$dst"
    log "Linked $dst -> $src"
  done
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
  if ! (
    export SKIP_SSH_AGENT=1 SKIP_EXEC_ZSH=1
    bash "$DOTFILES_DIR/zsh/install.sh"
  ); then
    warn "zsh/install.sh reported errors (may still be partially successful)"
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
  local tmux_conf_src="$DOTFILES_DIR/tmux/tmux.conf"
  local tmux_conf_dst="$tmux_config_dir/tmux.conf"
  local tpm_dir="$tmux_config_dir/plugins/tpm"

  mkdir -p "$tmux_config_dir/plugins"

  # Symlink tmux.conf
  if [ -f "$tmux_conf_src" ]; then
    if [ -L "$tmux_conf_dst" ] && [ "$(readlink "$tmux_conf_dst")" = "$tmux_conf_src" ]; then
      : # already correct
    else
      if [ -e "$tmux_conf_dst" ] || [ -L "$tmux_conf_dst" ]; then
        local backup="${tmux_conf_dst}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Backing up existing $tmux_conf_dst -> $backup"
        mv "$tmux_conf_dst" "$backup"
      fi
      ln -sf "$tmux_conf_src" "$tmux_conf_dst"
      log "Linked $tmux_conf_dst -> $tmux_conf_src"
    fi
  fi

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

  npm install -g --prefix "$prefix" @google/gemini-cli

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

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Removing existing templates path (not a symlink): $dst"
    rm -rf "$dst"
  fi

  ln -snf "$src" "$dst"
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
  local src="$DOTFILES_DIR/opencode/opencode.json.symlink"
  local dst="$CONFIG_DIR/opencode/opencode.json"

  if [[ -f "$src" ]]; then
    mkdir -p "$CONFIG_DIR/opencode"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      local backup
      backup="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backing up existing $dst -> $backup"
      mv "$dst" "$backup"
    fi
    ln -sf "$src" "$dst"
    log "Linked $dst -> $src"
  fi
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
