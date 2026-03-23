#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Dev Environment Bootstrap
# Auto-detects macOS or Linux, sources shared + platform-specific libraries,
# and runs a phased install. Safe to re-run (idempotent).
#
# Usage:
#   scripts/bootstrap.sh
#   INSTALL_NODE=1 scripts/bootstrap.sh    # also install Node.js LTS
#   SKIP_DEFAULTS=1 scripts/bootstrap.sh   # skip macOS system defaults
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
INSTALL_NODE="${INSTALL_NODE:-0}"

# --- Log capture: tee all output to a timestamped file ---
LOG_DIR="${LOG_DIR:-/tmp/dotfiles-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
printf "\n\033[1;34m==>\033[0m Bootstrap log: %s\n" "$LOG_FILE"

SCRIPTS_DIR="$DOTFILES_DIR/scripts"
PLATFORM="$(uname -s)"
# shellcheck disable=SC2034  # ARCH is used by sourced platform modules
ARCH="$(uname -m)"

# Source shared library
# shellcheck source=lib/common.sh
source "$SCRIPTS_DIR/lib/common.sh"

# Source platform-specific library
case "$PLATFORM" in
Darwin)
  # shellcheck source=lib/platform-mac.sh
  source "$SCRIPTS_DIR/lib/platform-mac.sh"
  ;;
Linux)
  # shellcheck source=lib/platform-linux.sh
  source "$SCRIPTS_DIR/lib/platform-linux.sh"
  ;;
*)
  die "Unsupported platform: $PLATFORM"
  ;;
esac

main() {
  # Phase 1 — Foundation (platform-specific: package manager + git)
  preflight_checks
  ensure_dirs
  ensure_local_bin_in_path
  install_platform_foundation

  # Phase 2 — Dotfile Symlinks (must precede brew bundle on macOS)
  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs

  # Phase 2.5 — tmux (XDG config + TPM plugin bootstrap)
  install_tmux_plugins

  # Phase 3 — Platform Packages (brew bundle needs BootstrapBrewfile symlink)
  install_platform_packages

  # Phase 4 — Shell Environment
  install_zsh_environment
  set_default_shell_zsh

  # Phase 5 — Language Runtimes
  install_rust_and_cargo_tools
  install_uv
  install_deno
  setup_node

  # Phase 6 — Dev Tooling
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Phase 7 — AI/Dev CLIs
  install_claude_code
  sync_ai_resources
  symlink_claude_config
  verify_claude_setup
  install_codex
  install_gemini_cli
  install_opencode
  symlink_opencode_ai_dirs

  # Phase 8 — Platform Configuration
  apply_platform_config

  # Phase 9 — Post-install
  post_checks
  print_next_steps
}

main "$@"
