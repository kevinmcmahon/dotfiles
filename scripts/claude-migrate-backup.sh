#!/usr/bin/env bash
# Bundle Claude Code memory + per-machine config into a single tarball.
# Run on the SOURCE host. Restore on the destination with claude-migrate-restore.sh.
#
# Output:
#   $CLAUDE_MIGRATE_DIR/claude-migration-<host>-<ts>.tar.gz
#   defaults to $HOME (override e.g. CLAUDE_MIGRATE_DIR=~/projects/claude-migration
#   to drop into a synced folder).
#
# Before running: quit all Claude Code sessions so the SQLite WAL is quiescent.
# Cross-platform: works on macOS and Linux. The auto-memory dir is derived from
# $HOME ("/Users/kevin" -> "-Users-kevin", "/root" -> "-root", etc.).

set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
HOST_TAG="$(hostname -s 2>/dev/null || hostname)"
OUT_DIR="${CLAUDE_MIGRATE_DIR:-$HOME}"
mkdir -p "$OUT_DIR"
OUT="${OUT_DIR}/claude-migration-${HOST_TAG}-${TS}.tar.gz"

STAGE="$(mktemp -d -t claude-migrate.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

# Auto-memory dir: ~/.claude/projects/<HOME-with-slashes-as-dashes>/memory
HOME_TAG="${HOME//\//-}"   # /Users/kevin -> -Users-kevin
MEM_SRC="$HOME/.claude/projects/${HOME_TAG}/memory"

echo ">> staging at $STAGE"
echo ">> source host=$HOST_TAG, auto-memory dir=$MEM_SRC"

# --- claude-mem -----------------------------------------------------------
# sqlite3 .backup is hot-safe for the main DB. Vector DB (chroma) is plain
# files — quit CC sessions first to avoid a torn read.
if [[ -d "$HOME/.claude-mem" ]]; then
  mkdir -p "$STAGE/claude-mem"

  if [[ -f "$HOME/.claude-mem/claude-mem.db" ]]; then
    if command -v sqlite3 >/dev/null 2>&1; then
      echo ">> snapshotting claude-mem.db via sqlite3 .backup"
      sqlite3 "$HOME/.claude-mem/claude-mem.db" \
        ".backup '$STAGE/claude-mem/claude-mem.db'"
    else
      echo ">> sqlite3 missing — falling back to plain copy (quit CC first!)"
      cp "$HOME/.claude-mem/claude-mem.db" "$STAGE/claude-mem/claude-mem.db"
    fi
  fi

  if [[ -d "$HOME/.claude-mem/vector-db" ]]; then
    echo ">> copying vector-db/"
    cp -R "$HOME/.claude-mem/vector-db" "$STAGE/claude-mem/vector-db"
  fi

  if [[ -f "$HOME/.claude-mem/settings.json" ]]; then
    cp "$HOME/.claude-mem/settings.json" "$STAGE/claude-mem/settings.json"
  fi
else
  echo ">> ~/.claude-mem missing, skipping"
fi

# --- auto-memory MD files -------------------------------------------------
if [[ -d "$MEM_SRC" ]]; then
  echo ">> copying auto-memory MD files"
  mkdir -p "$STAGE/auto-memory"
  cp -R "$MEM_SRC/." "$STAGE/auto-memory/"
else
  echo ">> auto-memory dir missing, skipping"
fi

# --- top-level configs ----------------------------------------------------
mkdir -p "$STAGE/configs"
for f in "$HOME/.claude.json" "$HOME/.claude/settings.local.json"; do
  if [[ -f "$f" ]]; then
    echo ">> copying $f"
    cp "$f" "$STAGE/configs/$(basename "$f")"
  else
    echo ">> $f missing, skipping"
  fi
done

# --- manifest -------------------------------------------------------------
# Record the SOURCE home tag so the restore script knows the original
# auto-memory subdir name (in case source and dest $HOME differ).
cat > "$STAGE/MANIFEST.txt" <<EOF
Claude migration bundle
Created: $(date)
Source host: $(hostname)
Source user: $(whoami)
Source HOME: $HOME
Source HOME_TAG: $HOME_TAG

Contents:
  claude-mem/claude-mem.db        -> ~/.claude-mem/claude-mem.db
  claude-mem/vector-db/           -> ~/.claude-mem/vector-db/
  claude-mem/settings.json        -> ~/.claude-mem/settings.json
  auto-memory/*.md                -> ~/.claude/projects/<HOME_TAG>/memory/
  configs/.claude.json            -> ~/.claude.json
  configs/settings.local.json     -> ~/.claude/settings.local.json
EOF

echo ">> creating tarball"
tar -czf "$OUT" -C "$STAGE" .

SIZE="$(du -h "$OUT" | cut -f1)"
echo
echo "done: $OUT ($SIZE)"
echo "next: copy/sync this file to the destination, then run"
echo "      claude-migrate-restore.sh [bundle.tar.gz]"
