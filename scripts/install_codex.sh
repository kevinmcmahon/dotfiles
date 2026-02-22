#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Codex CLI installer (clean, no global npm config mutation)
#
# Installs @openai/codex using a per-command npm prefix so:
#   - no sudo required
#   - no "npm config set prefix" side effects
#   - binary lands in: ${CODEX_PREFIX:-$HOME/.local}/bin/codex
#
# Requirements:
#   - node + npm in PATH (recommend: fnm on macOS/Linux)
#
# Usage:
#   ./install_codex.sh                # installs latest from npm
#   CODEX_PREFIX="$HOME/.local" ./install_codex.sh
#
# After install:
#   codex login
# ------------------------------------------------------------

log()  { printf "\033[1;34m[codex]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[codex]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[codex]\033[0m %s\n" "$*"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_bin_dir_on_path_for_run() {
  local bin_dir="$1"
  case ":$PATH:" in
    *":$bin_dir:"*) return 0 ;;
    *) export PATH="$bin_dir:$PATH" ;;
  esac
}

codex_expected_path() {
  local prefix="$1"
  printf "%s/bin/codex" "$prefix"
}

install_codex() {
  local prefix="${CODEX_PREFIX:-$HOME/.local}"
  local bin_dir="$prefix/bin"
  local expected
  expected="$(codex_expected_path "$prefix")"

  if ! have_cmd node || ! have_cmd npm; then
    die "node/npm not found in PATH. Install Node first (recommended: fnm)."
  fi

  mkdir -p "$bin_dir"

  # If codex is already installed, prefer idempotency:
  # - If it's the expected path, treat as done.
  # - If it's elsewhere, still treat as done, but print where.
  if have_cmd codex; then
    local found
    found="$(command -v codex || true)"
    if [[ "$found" == "$expected" ]]; then
      log "codex already installed at expected path: $found"
    else
      warn "codex already found on PATH: $found"
      warn "Expected install location would be: $expected"
    fi
    codex --version 2>/dev/null | head -n 1 || true
    return 0
  fi

  log "Installing Codex CLI to: $expected"
  log "Using per-install npm prefix (no global npm config changes)."

  npm install -g --prefix "$prefix" @openai/codex

  # Make codex available immediately for this run.
  ensure_bin_dir_on_path_for_run "$bin_dir"

  if [[ -x "$expected" ]]; then
    log "Installed: $expected"
  else
    warn "Install completed but expected binary not found at: $expected"
    warn "Checking npm bin dir output:"
    (npm bin -g --prefix "$prefix" 2>/dev/null || true) | sed 's/^/[codex] /' || true
  fi

  if have_cmd codex; then
    log "codex version: $(codex --version 2>/dev/null | head -n 1 || echo 'unknown')"
  else
    die "codex not found on PATH after install. Ensure $bin_dir is on PATH."
  fi
}

main() {
  install_codex
  log "Next: run 'codex login' to authenticate."
}

main "$@"
