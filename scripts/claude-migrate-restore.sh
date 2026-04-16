#!/usr/bin/env bash
# Restore a Claude migration bundle on the destination host.
#
# Usage: claude-migrate-restore.sh [bundle.tar.gz]
#   With no arg, picks the newest bundle in $CLAUDE_MIGRATE_DIR
#   (default $HOME).
#
# Quit all Claude Code sessions before running so files aren't held open.
# Existing destination files are stashed as *.pre-migrate-<timestamp> — never
# clobbered. The auto-memory subdir is derived from the destination $HOME so a
# bundle created under /Users/kevin still restores correctly under /root, etc.

set -euo pipefail

if [[ $# -ge 1 ]]; then
  BUNDLE="$1"
else
  SRC_DIR="${CLAUDE_MIGRATE_DIR:-$HOME}"
  BUNDLE="$(ls -t "$SRC_DIR"/claude-migration-*.tar.gz 2>/dev/null | head -n1 || true)"
  if [[ -z "$BUNDLE" ]]; then
    echo "no bundle found in $SRC_DIR" >&2
    echo "usage: $0 [bundle.tar.gz]" >&2
    exit 1
  fi
  echo ">> using newest bundle: $BUNDLE"
fi

if [[ ! -f "$BUNDLE" ]]; then
  echo "bundle not found: $BUNDLE" >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
STAGE="$(mktemp -d -t claude-restore.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

echo ">> extracting to $STAGE"
tar -xzf "$BUNDLE" -C "$STAGE"

if [[ -f "$STAGE/MANIFEST.txt" ]]; then
  echo "---- bundle manifest ----"
  cat "$STAGE/MANIFEST.txt"
  echo "-------------------------"
fi

# Destination auto-memory subdir derived from THIS host's $HOME.
HOME_TAG="${HOME//\//-}"
MEM_DEST="$HOME/.claude/projects/${HOME_TAG}/memory"

# stash_existing <path> — rename out of the way if it exists
stash_existing() {
  local p="$1"
  if [[ -e "$p" ]]; then
    local backup="${p}.pre-migrate-${TS}"
    echo ">> existing $p -> $backup"
    mv "$p" "$backup"
  fi
}

# place_dir <src> <dest>
place_dir() {
  local src="$1" dest="$2"
  if [[ -d "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    stash_existing "$dest"
    echo ">> restoring dir $dest"
    cp -R "$src" "$dest"
  fi
}

# place_file <src> <dest>
place_file() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    stash_existing "$dest"
    echo ">> restoring file $dest"
    cp "$src" "$dest"
  fi
}

# --- claude-mem -----------------------------------------------------------
mkdir -p "$HOME/.claude-mem"
place_file "$STAGE/claude-mem/claude-mem.db"   "$HOME/.claude-mem/claude-mem.db"
place_file "$STAGE/claude-mem/settings.json"   "$HOME/.claude-mem/settings.json"
place_dir  "$STAGE/claude-mem/vector-db"       "$HOME/.claude-mem/vector-db"

# Stale WAL/SHM from the source DB would confuse SQLite — wipe them.
rm -f "$HOME/.claude-mem/claude-mem.db-wal" "$HOME/.claude-mem/claude-mem.db-shm"

# --- auto-memory ----------------------------------------------------------
if [[ -d "$STAGE/auto-memory" ]]; then
  mkdir -p "$MEM_DEST"
  for f in "$STAGE/auto-memory/"*.md; do
    [[ -e "$f" ]] || continue
    place_file "$f" "$MEM_DEST/$(basename "$f")"
  done
fi

# --- top-level configs ----------------------------------------------------
place_file "$STAGE/configs/.claude.json"        "$HOME/.claude.json"
place_file "$STAGE/configs/settings.local.json" "$HOME/.claude/settings.local.json"

echo
echo "done. start a new Claude Code session and verify:"
echo "  - memory recall works"
echo "  - MCP servers and plugins still load (~/.claude.json)"
echo "  - permission rules look right (~/.claude/settings.local.json)"
echo "previous files (if any) preserved with .pre-migrate-${TS} suffix."
