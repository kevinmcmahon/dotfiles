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

# log, warn, die and set_npm_install_policy come from the bootstrap library.
# shellcheck source=SCRIPTDIR/../scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

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

# Set LTS as default and activate it.
# These are fast no-ops if already set, but we always run them to ensure
# the default and active version stay correct after an LTS bump.
fnm default lts-latest
fnm use lts-latest

log "Node.js active: $(node --version)"

# Keep npm global installs stable across fnm-managed Node version changes.
log "Setting npm global prefix to $HOME/.local..."
mkdir -p "$HOME/.local/bin"
npm config set prefix "$HOME/.local"
log "npm global prefix: $(npm config get prefix)"

# Apply the npm install policy with the function bootstrap uses, so both set
# the same keys the audits check.
set_npm_install_policy

# Enable corepack (ships with Node.js, provides yarn and pnpm)
log "Enabling corepack..."
corepack enable

log "Corepack enabled: $(corepack --version)"
log "yarn: $(yarn --version 2>/dev/null || echo 'available via corepack')"
log "pnpm: $(pnpm --version 2>/dev/null || echo 'available via corepack')"

log "Node.js LTS setup complete."
