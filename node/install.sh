#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Node.js LTS Setup via fnm + Corepack
# Installs the latest LTS version, sets it as default, and enables corepack
# (which provides yarn and pnpm without separate installs).
#
# Prerequisites: fnm must be installed and on PATH.
# Safe to re-run — skips steps that are already done.
# ------------------------------------------------------------------------------

log() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$*"; }
die() {
  printf "\033[1;31mERR:\033[0m %s\n" "$*"
  exit 1
}

# Require fnm
if ! command -v fnm >/dev/null 2>&1; then
  die "fnm is not installed. Install it first (brew install fnm or via bootstrap)."
fi

# Initialize fnm in this shell session
eval "$(fnm env)"

# Install latest LTS if not already present
if fnm list | grep -q "lts-latest"; then
  log "Node.js LTS already installed: $(fnm list | grep lts-latest | head -n 1)"
else
  log "Installing Node.js LTS..."
  fnm install --lts
fi

# Set LTS as default
log "Setting LTS as default Node.js version"
fnm default lts-latest

# Activate it
fnm use lts-latest

log "Node.js active: $(node --version)"

# Enable corepack (ships with Node.js, provides yarn and pnpm)
log "Enabling corepack..."
corepack enable

log "Corepack enabled: $(corepack --version)"
log "yarn: $(yarn --version 2>/dev/null || echo 'available via corepack')"
log "pnpm: $(pnpm --version 2>/dev/null || echo 'available via corepack')"

log "Node.js LTS setup complete."
