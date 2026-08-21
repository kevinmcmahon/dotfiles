#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Dev Environment Bootstrap
# Auto-detects macOS or Linux, sources shared + platform-specific libraries,
# and runs a phased install. Safe to re-run (idempotent).
#
# Usage:
#   scripts/bootstrap.sh
#   scripts/bootstrap.sh --profile workstation
#   scripts/bootstrap.sh --profile server
#   INSTALL_NODE=0 scripts/bootstrap.sh    # skip Node.js LTS install
#   SKIP_DEFAULTS=1 scripts/bootstrap.sh   # skip macOS system defaults
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
INSTALL_NODE="${INSTALL_NODE:-1}"
PROFILE="workstation"

parse_bootstrap_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        [[ $# -ge 2 ]] || { printf 'ERR: --profile requires a value\n' >&2; return 2; }
        PROFILE="$2"
        shift 2
        ;;
      *)
        printf 'ERR: Unknown option: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done

  case "$PROFILE" in
    workstation|server) ;;
    *)
      printf 'ERR: Unknown profile: %s\n' "$PROFILE" >&2
      return 2
      ;;
  esac
}

setup_logging() {
  LOG_DIR="${LOG_DIR:-/tmp/dotfiles-bootstrap}"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  printf "\n\033[1;34m==>\033[0m Bootstrap log: %s\n" "$LOG_FILE"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  parse_bootstrap_args "$@"
fi

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

run_workstation_profile() {
  # Phase 1 — Foundation (platform-specific: package manager + git)
  preflight_checks
  ensure_dirs
  write_bootstrap_profile_marker
  ensure_local_bin_in_path
  install_platform_foundation

  # Phase 2 — Dotfile Symlinks (must precede brew bundle on macOS)
  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs

  # Phase 3 — Platform Packages (brew bundle needs BootstrapBrewfile symlink)
  install_platform_packages

  # Phase 3.5 — tmux (XDG config + TPM plugin bootstrap; after brew so tmux is available)
  install_tmux_plugins

  # Phase 4 — Shell Environment
  install_zsh_environment
  set_default_shell_zsh

  # Phase 5 — Language Runtimes
  install_rust_and_cargo_tools
  install_uv
  install_deno
  install_bun
  setup_node

  # Phase 6 — Dev Tooling
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Phase 7 — AI/Dev CLIs
  install_claude_code
  install_codex
  install_gemini_cli
  install_opencode
  ensure_claude_skills_dir
  ensure_opencode_skills_dir
  sync_ai_resources
  ensure_pplx_search_bin
  symlink_claude_config
  symlink_opencode_ai_dirs
  install_ai_skills
  symlink_codex_config
  verify_claude_setup
  verify_codex_setup

  # Phase 8 — Platform Configuration
  apply_platform_config

  # Phase 9 — Post-install
  post_checks
  print_next_steps
}

run_server_profile() {
  [[ "$PLATFORM" == "Linux" ]] || die "The server profile supports Linux only."

  preflight_checks
  ensure_dirs
  ensure_local_bin_in_path
  install_server_packages
  write_bootstrap_profile_marker
  symlink_server_dotfiles
  ensure_server_git_identity
  install_tmux_plugins
  install_zsh_environment
  set_default_shell_zsh
  post_checks_server
  print_server_next_steps
}

main() {
  setup_logging
  log "Bootstrap profile: $PROFILE"

  case "$PROFILE" in
    workstation) run_workstation_profile ;;
    server) run_server_profile ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
