#!/usr/bin/env bash
# Merge a claude-mem SQLite DB into the live one at ~/.claude-mem/claude-mem.db.
# Companion to claude-migrate-backup.sh / claude-migrate-restore.sh — use this
# instead of restore when the destination already has memories worth keeping.
#
# Usage:
#   claude-mem-merge.sh [--dry-run] <bundle.tar.gz | path/to/claude-mem.db>
#
# Inputs:
#   - A full migration bundle (.tar.gz) — extracted to a temp dir, the inner
#     claude-mem/claude-mem.db is used.
#   - A standalone .db file — used directly.
#
# What it does:
#   1. Snapshots ~/.claude-mem/ to ~/claude-mem.pre-merge-<TS>/ (full dir copy).
#   2. Stops the claude-mem worker (reads PID from worker.pid).
#   3. Checkpoints WAL on both source and live DBs.
#   4. Merges src -> live on a scratch copy (never touches live mid-merge).
#        - Dedupes sdk_sessions by content_session_id (UNIQUE NOT NULL).
#        - Imports child rows (observations, session_summaries, user_prompts)
#          scoped to newly imported sessions.
#        - Omits the integer PK column so SQLite autoincrements fresh locally.
#        - FTS5 triggers keep search indexes in sync automatically.
#   5. Atomic swap: mv live -> live.pre-merge-<TS>, mv scratch -> live.
#      Stale WAL/SHM files removed.
#   6. Backs up vector-db/ into the snapshot dir and recreates it empty.
#      (Embeddings keyed to old integer observation IDs are stale; claude-mem
#      will rebuild Chroma on next worker start.)
#   7. Does NOT restart the worker. You launch Claude Code yourself.
#
# --dry-run:
#   Runs steps 1-4 against a scratch copy, prints the report, and rolls back.
#   Leaves live DB and worker untouched. Still creates and removes the snapshot
#   dir as a rehearsal.
#
# Rollback: the script prints a one-line command at the end. The snapshot dir
# has everything needed to restore.
#
# Before running (real mode): quit all Claude Code sessions to avoid the worker
# being respawned while we work.

set -euo pipefail

# ----- config & args ---------------------------------------------------------

DRY_RUN=0
ARG=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "unknown flag: $a" >&2
      exit 2
      ;;
    *)
      if [[ -n "$ARG" ]]; then
        echo "unexpected extra argument: $a" >&2
        exit 2
      fi
      ARG="$a"
      ;;
  esac
done

if [[ -z "$ARG" ]]; then
  echo "usage: $0 [--dry-run] <bundle.tar.gz | claude-mem.db>" >&2
  exit 2
fi

CLAUDE_MEM_DIR="${CLAUDE_MEM_DIR:-$HOME/.claude-mem}"
CLAUDE_MEM_BACKUP_DIR="${CLAUDE_MEM_BACKUP_DIR:-$HOME}"
LIVE_DB="$CLAUDE_MEM_DIR/claude-mem.db"
TS="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="$CLAUDE_MEM_BACKUP_DIR/claude-mem.pre-merge-$TS"

STAGE="$(mktemp -d -t claude-mem-merge.XXXXXX)"
SCRATCH="$STAGE/scratch.db"
trap 'rm -rf "$STAGE"' EXIT

# ----- helpers ---------------------------------------------------------------

log()  { printf '>> %s\n' "$*"; }
err()  { printf '!! %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"
}

# cols_except_id DB TABLE — print comma-joined column list with `id` removed.
cols_except_id() {
  local db="$1" tbl="$2"
  sqlite3 "$db" "SELECT GROUP_CONCAT(name, ',') FROM pragma_table_info('$tbl') WHERE name != 'id';"
}

# sqlite_count DB QUERY
sqlite_count() {
  sqlite3 "$1" "$2"
}

# ----- resolve input ---------------------------------------------------------

SRC_DB=""
if [[ "$ARG" == *.tar.gz || "$ARG" == *.tgz ]]; then
  [[ -f "$ARG" ]] || die "bundle not found: $ARG"
  log "extracting bundle to $STAGE/bundle"
  mkdir -p "$STAGE/bundle"
  tar -xzf "$ARG" -C "$STAGE/bundle"
  SRC_DB="$STAGE/bundle/claude-mem/claude-mem.db"
  [[ -f "$SRC_DB" ]] || die "bundle has no claude-mem/claude-mem.db inside"
  if [[ -f "$STAGE/bundle/MANIFEST.txt" ]]; then
    log "bundle manifest:"
    sed 's/^/   /' "$STAGE/bundle/MANIFEST.txt"
  fi
elif [[ "$ARG" == *.db ]]; then
  [[ -f "$ARG" ]] || die "db not found: $ARG"
  SRC_DB="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
else
  die "unrecognised input (expected .tar.gz / .tgz / .db): $ARG"
fi

log "source DB: $SRC_DB"
log "live DB:   $LIVE_DB"
log "mode:      $( ((DRY_RUN)) && echo DRY-RUN || echo REAL)"

# ----- pre-flight ------------------------------------------------------------

need_cmd sqlite3
need_cmd jq
need_cmd tar

[[ -f "$LIVE_DB" ]] || die "live DB missing: $LIVE_DB (use claude-migrate-restore.sh for first-time setup)"

# SQLite validity
sqlite3 "$SRC_DB"  "SELECT 1;" >/dev/null 2>&1 || die "source is not a valid SQLite DB: $SRC_DB"
sqlite3 "$LIVE_DB" "SELECT 1;" >/dev/null 2>&1 || die "live is not a valid SQLite DB: $LIVE_DB"

# Schema parity
SRC_SCHEMA="$(sqlite3 "$SRC_DB"  "SELECT COALESCE(MAX(version),0) FROM schema_versions;")"
LIVE_SCHEMA="$(sqlite3 "$LIVE_DB" "SELECT COALESCE(MAX(version),0) FROM schema_versions;")"
if [[ "$SRC_SCHEMA" != "$LIVE_SCHEMA" ]]; then
  err "schema mismatch: source=$SRC_SCHEMA, live=$LIVE_SCHEMA"
  err "run claude-mem against the older DB to upgrade it before merging, or reverse the merge direction"
  exit 1
fi
log "schema version: $LIVE_SCHEMA (matches on both sides)"

# Non-empty live sanity
LIVE_OBS="$(sqlite_count "$LIVE_DB" "SELECT COUNT(*) FROM observations;")"
if [[ "$LIVE_OBS" == "0" ]]; then
  err "live DB has 0 observations — use claude-migrate-restore.sh instead, merging into an empty DB is pointless"
  exit 1
fi

# ----- snapshot --------------------------------------------------------------

log "snapshotting $CLAUDE_MEM_DIR -> $SNAPSHOT_DIR"
cp -R "$CLAUDE_MEM_DIR" "$SNAPSHOT_DIR"

cleanup_snapshot_on_dry_run() {
  if ((DRY_RUN)) && [[ -d "$SNAPSHOT_DIR" ]]; then
    log "dry-run: removing rehearsal snapshot $SNAPSHOT_DIR"
    rm -rf "$SNAPSHOT_DIR"
  fi
}

# ----- stop worker -----------------------------------------------------------

WORKER_PID=""
if [[ -f "$CLAUDE_MEM_DIR/worker.pid" ]]; then
  WORKER_PID="$(jq -r '.pid // empty' "$CLAUDE_MEM_DIR/worker.pid" 2>/dev/null || true)"
fi

if [[ -n "$WORKER_PID" ]] && kill -0 "$WORKER_PID" 2>/dev/null; then
  log "stopping claude-mem worker (pid $WORKER_PID)"
  kill "$WORKER_PID" || true
  # Wait up to 10s for graceful exit.
  for _ in $(seq 1 20); do
    kill -0 "$WORKER_PID" 2>/dev/null || break
    sleep 0.5
  done
  if kill -0 "$WORKER_PID" 2>/dev/null; then
    cleanup_snapshot_on_dry_run
    die "worker (pid $WORKER_PID) did not exit in 10s — not force-killing. Stop it manually and retry."
  fi
  log "worker stopped"
else
  log "no live worker (pid $WORKER_PID${WORKER_PID:+ }not running)"
fi

# ----- WAL checkpoint --------------------------------------------------------

log "checkpointing WAL on both DBs"
sqlite3 "$LIVE_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null
sqlite3 "$SRC_DB"  "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
# Source may be on a read-only media or lack WAL; tolerate.

# ----- merge on scratch ------------------------------------------------------

log "copying live DB to scratch: $SCRATCH"
cp "$LIVE_DB" "$SCRATCH"

# Enumerate column lists at runtime so we're resilient to future schema changes.
OBS_COLS="$(cols_except_id "$SCRATCH" observations)"
SUM_COLS="$(cols_except_id "$SCRATCH" session_summaries)"
PMT_COLS="$(cols_except_id "$SCRATCH" user_prompts)"
SES_COLS="$(cols_except_id "$SCRATCH" sdk_sessions)"

[[ -n "$OBS_COLS$SUM_COLS$PMT_COLS$SES_COLS" ]] || die "failed to enumerate table columns"

# Before-counts for the report
BEFORE_SES="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM sdk_sessions;")"
BEFORE_OBS="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM observations;")"
BEFORE_SUM="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM session_summaries;")"
BEFORE_PMT="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM user_prompts;")"

SRC_SES="$(sqlite_count "$SRC_DB" "SELECT COUNT(*) FROM sdk_sessions;")"
SRC_OBS="$(sqlite_count "$SRC_DB" "SELECT COUNT(*) FROM observations;")"
SRC_SUM="$(sqlite_count "$SRC_DB" "SELECT COUNT(*) FROM session_summaries;")"
SRC_PMT="$(sqlite_count "$SRC_DB" "SELECT COUNT(*) FROM user_prompts;")"

log "live (before): sessions=$BEFORE_SES observations=$BEFORE_OBS summaries=$BEFORE_SUM prompts=$BEFORE_PMT"
log "source:         sessions=$SRC_SES    observations=$SRC_OBS    summaries=$SRC_SUM    prompts=$SRC_PMT"

log "merging into scratch..."
# Embedded escape: sqlite3 ATTACH takes a path literal. Bail if the path has a
# single quote (pathological, but don't allow SQL injection via path).
case "$SRC_DB" in *"'"*) die "source path contains a single quote; refuse to ATTACH" ;; esac

sqlite3 "$SCRATCH" <<SQL
PRAGMA foreign_keys = ON;
ATTACH DATABASE '$SRC_DB' AS src;
BEGIN;

-- New sessions = src sessions whose content_session_id is not already in live.
-- content_session_id is TEXT UNIQUE NOT NULL on sdk_sessions -> safe natural key.
CREATE TEMP TABLE new_sessions (
  content_session_id TEXT PRIMARY KEY,
  memory_session_id  TEXT
);
-- Skip any src session whose memory_session_id already exists in live under a
-- *different* content_session_id — memory_session_id is also UNIQUE and would
-- abort the transaction.
INSERT INTO new_sessions (content_session_id, memory_session_id)
SELECT s.content_session_id, s.memory_session_id
FROM src.sdk_sessions s
WHERE s.content_session_id NOT IN (SELECT content_session_id FROM main.sdk_sessions)
  AND (s.memory_session_id IS NULL
       OR s.memory_session_id NOT IN (
            SELECT memory_session_id FROM main.sdk_sessions WHERE memory_session_id IS NOT NULL
          ));

-- 1) Sessions first. Omit the integer PK; SQLite autoincrements locally.
INSERT INTO main.sdk_sessions ($SES_COLS)
SELECT $SES_COLS
FROM src.sdk_sessions
WHERE content_session_id IN (SELECT content_session_id FROM new_sessions);

-- 2) observations — scoped by memory_session_id (NOT NULL on this table).
--    Some new_sessions may have NULL memory_session_id and thus no children; fine.
INSERT INTO main.observations ($OBS_COLS)
SELECT $OBS_COLS
FROM src.observations
WHERE memory_session_id IN (
  SELECT memory_session_id FROM new_sessions WHERE memory_session_id IS NOT NULL
);

-- 3) session_summaries — same scoping.
INSERT INTO main.session_summaries ($SUM_COLS)
SELECT $SUM_COLS
FROM src.session_summaries
WHERE memory_session_id IN (
  SELECT memory_session_id FROM new_sessions WHERE memory_session_id IS NOT NULL
);

-- 4) user_prompts — scoped by content_session_id (different FK column).
INSERT INTO main.user_prompts ($PMT_COLS)
SELECT $PMT_COLS
FROM src.user_prompts
WHERE content_session_id IN (SELECT content_session_id FROM new_sessions);

COMMIT;
DETACH DATABASE src;

-- Integrity checks on the merged scratch DB.
SELECT 'integrity', integrity_check FROM pragma_integrity_check() LIMIT 5;

VACUUM;
SQL

AFTER_SES="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM sdk_sessions;")"
AFTER_OBS="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM observations;")"
AFTER_SUM="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM session_summaries;")"
AFTER_PMT="$(sqlite_count "$SCRATCH" "SELECT COUNT(*) FROM user_prompts;")"

ADDED_SES=$((AFTER_SES - BEFORE_SES))
ADDED_OBS=$((AFTER_OBS - BEFORE_OBS))
ADDED_SUM=$((AFTER_SUM - BEFORE_SUM))
ADDED_PMT=$((AFTER_PMT - BEFORE_PMT))
SKIPPED_SES=$((SRC_SES - ADDED_SES))

cat <<REPORT

---- merge report ----
                live(before)   source   live(after)   imported
  sessions      $BEFORE_SES           $SRC_SES       $AFTER_SES           $ADDED_SES
  observations  $BEFORE_OBS           $SRC_OBS       $AFTER_OBS           $ADDED_OBS
  summaries     $BEFORE_SUM           $SRC_SUM       $AFTER_SUM           $ADDED_SUM
  prompts       $BEFORE_PMT           $SRC_PMT       $AFTER_PMT           $ADDED_PMT

  sessions in source already present in live (skipped): $SKIPPED_SES
----------------------

REPORT

# ----- dry-run short-circuit -------------------------------------------------

if ((DRY_RUN)); then
  cleanup_snapshot_on_dry_run
  log "dry-run complete. Live DB untouched. No vector-db changes."
  if [[ -n "$WORKER_PID" ]]; then
    log "note: worker (pid $WORKER_PID) was stopped; restart by launching Claude Code."
  fi
  exit 0
fi

# ----- atomic swap -----------------------------------------------------------

log "swapping live DB in"
mv "$LIVE_DB" "$LIVE_DB.pre-merge-$TS"
mv "$SCRATCH" "$LIVE_DB"
# Stale WAL/SHM from pre-swap inode — remove to avoid corruption-looking errors.
rm -f "$LIVE_DB-wal" "$LIVE_DB-shm"

# ----- vector-db backup and reset --------------------------------------------

if [[ -d "$CLAUDE_MEM_DIR/vector-db" ]]; then
  log "resetting vector-db (snapshot already has the pre-merge copy)"
  # The snapshot dir captured vector-db at step 1; we just need to clear live.
  rm -rf "$CLAUDE_MEM_DIR/vector-db"
fi
mkdir -p "$CLAUDE_MEM_DIR/vector-db"

# ----- next steps ------------------------------------------------------------

cat <<DONE

done.

  snapshot:  $SNAPSHOT_DIR
  also:      $LIVE_DB.pre-merge-$TS  (DB-only rollback point)

next steps:
  1. Launch Claude Code. The claude-mem worker will respawn, detect the empty
     vector-db, and begin re-embedding observations. Semantic search quality is
     degraded until that catches up.
  2. Verify counts:
       sqlite3 $LIVE_DB \\
         "SELECT 'sessions', COUNT(*) FROM sdk_sessions
          UNION ALL SELECT 'observations', COUNT(*) FROM observations
          UNION ALL SELECT 'summaries', COUNT(*) FROM session_summaries
          UNION ALL SELECT 'prompts', COUNT(*) FROM user_prompts;"

rollback (full):
  pkill -f 'worker-service.cjs --daemon' 2>/dev/null || true
  rm -rf $CLAUDE_MEM_DIR
  mv $SNAPSHOT_DIR $CLAUDE_MEM_DIR

rollback (DB only, keep post-merge vector-db state):
  pkill -f 'worker-service.cjs --daemon' 2>/dev/null || true
  rm -f $LIVE_DB $LIVE_DB-wal $LIVE_DB-shm
  mv $LIVE_DB.pre-merge-$TS $LIVE_DB

DONE
