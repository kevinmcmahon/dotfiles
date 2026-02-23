#!/usr/bin/env bash
# ABOUTME: Generate symlink farms from canonical ai/ directory into each tool's config directory.
# ABOUTME: Supports common + tool-specific overrides, stale cleanup, dry-run, and verbose modes.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
AI_DIR="$DOTFILES_DIR/ai"
TOOLS=(claude opencode)
RESOURCES=(commands docs skills)

# Counters
CREATED=0
UNCHANGED=0
STALE=0
OVERRIDES=0
CONFLICTS=0

# Flags
DRY_RUN=0
VERBOSE=0

# ==============================================================================
# Utilities
# ==============================================================================

log()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31mERR:\033[0m %s\n" "$*"; exit 1; }

verbose() {
  if (( VERBOSE )); then
    printf "    %s\n" "$*"
  fi
}

usage() {
  cat <<'EOF'
Usage: ai-sync.sh [OPTIONS]

Generate symlink farms from ai/ into each tool's config directory.
Common files are linked first; tool-specific files override on collision.

Options:
  -n, --dry-run   Show what would be done without making changes
  -v, --verbose   Print detailed actions
  -h, --help      Show this help message
EOF
  exit 0
}

# ==============================================================================
# Parse arguments
# ==============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help)    usage ;;
    *)            die "Unknown option: $1" ;;
  esac
done

# ==============================================================================
# Validation
# ==============================================================================

[[ -d "$AI_DIR" ]] || die "Canonical ai/ directory not found: $AI_DIR"

# ==============================================================================
# Core sync logic
# ==============================================================================

sync_resource() {
  local tool="$1"
  local resource="$2"
  local target_dir="$DOTFILES_DIR/$tool/$resource"
  local common_dir="$AI_DIR/$resource/common"
  local specific_dir="$AI_DIR/$resource/$tool"

  # Track which names we've linked (for stale detection)
  declare -A linked_names

  if (( ! DRY_RUN )); then
    mkdir -p "$target_dir"
  fi

  # Pass 1: common files (depth from tool/resource/ to repo root is always 2)
  if [[ -d "$common_dir" ]]; then
    for src in "$common_dir"/*; do
      [[ -e "$src" ]] || continue
      local name
      name="$(basename "$src")"
      local link="$target_dir/$name"
      local rel_target="../../ai/$resource/common/$name"

      linked_names["$name"]="common"

      if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "$rel_target" ]]; then
        verbose "unchanged: $link"
        (( UNCHANGED++ )) || true
        continue
      fi

      if [[ -e "$link" ]] && [[ ! -L "$link" ]]; then
        warn "CONFLICT: $link exists and is not a symlink — skipping"
        (( CONFLICTS++ )) || true
        continue
      fi

      verbose "link: $link -> $rel_target"
      if (( ! DRY_RUN )); then
        ln -snf "$rel_target" "$link"
      fi
      (( CREATED++ )) || true
    done
  fi

  # Pass 2: tool-specific files (override common on collision)
  if [[ -d "$specific_dir" ]]; then
    for src in "$specific_dir"/*; do
      [[ -e "$src" ]] || continue
      local name
      name="$(basename "$src")"
      local link="$target_dir/$name"
      local rel_target="../../ai/$resource/$tool/$name"

      if [[ -n "${linked_names[$name]:-}" ]]; then
        verbose "override: $name ($tool-specific wins over common)"
        (( OVERRIDES++ )) || true
      fi
      linked_names["$name"]="$tool"

      if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "$rel_target" ]]; then
        verbose "unchanged: $link"
        (( UNCHANGED++ )) || true
        continue
      fi

      if [[ -e "$link" ]] && [[ ! -L "$link" ]]; then
        warn "CONFLICT: $link exists and is not a symlink — skipping"
        (( CONFLICTS++ )) || true
        continue
      fi

      verbose "link: $link -> $rel_target"
      if (( ! DRY_RUN )); then
        ln -snf "$rel_target" "$link"
      fi
      (( CREATED++ )) || true
    done
  fi

  # Pass 3: remove stale symlinks (point into ai/ but name no longer in source)
  if [[ -d "$target_dir" ]]; then
    for link in "$target_dir"/*; do
      [[ -L "$link" ]] || continue
      local name
      name="$(basename "$link")"
      local target_path
      target_path="$(readlink "$link")"

      # Only clean up symlinks that point into ai/
      if [[ "$target_path" == ../../ai/* ]]; then
        if [[ -z "${linked_names[$name]:-}" ]]; then
          verbose "stale: removing $link (target no longer in source)"
          if (( ! DRY_RUN )); then
            rm "$link"
          fi
          (( STALE++ )) || true
        fi
      fi
    done
  fi
}

# ==============================================================================
# Main
# ==============================================================================

if (( DRY_RUN )); then
  log "Dry run — no changes will be made"
fi

for tool in "${TOOLS[@]}"; do
  for resource in "${RESOURCES[@]}"; do
    sync_resource "$tool" "$resource"
  done
done

# Summary
log "ai-sync complete: ${CREATED} created, ${UNCHANGED} unchanged, ${STALE} stale removed, ${OVERRIDES} overrides, ${CONFLICTS} conflicts"

if (( CONFLICTS > 0 )); then
  warn "Resolve conflicts manually (non-symlink files in generated directories)"
fi
