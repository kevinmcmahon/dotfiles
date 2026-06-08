#!/usr/bin/env bash
# ABOUTME: Install declared third-party AI skills with the skills CLI.
# ABOUTME: ai/skills-manifest.toml declares intent; npx skills owns resolution and lock state.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
MANIFEST="${SKILLS_MANIFEST:-$DOTFILES_DIR/ai/skills-manifest.toml}"

DRY_RUN=0
CHECK=0
VERBOSE=0

log() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33mWARN:\033[0m %s\n" "$*"; }
die() {
  printf "\033[1;31mERR:\033[0m %s\n" "$*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install-ai-skills.sh [OPTIONS]

Install third-party AI skills declared in ai/skills-manifest.toml.

Options:
  -n, --dry-run   Print npx skills commands without running them
  -c, --check     Validate the manifest and required tools only
  -v, --verbose   Print extra detail
  -h, --help      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -c|--check) CHECK=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -f "$MANIFEST" ]] || die "Skills manifest not found: $MANIFEST"

if ! command -v uv >/dev/null 2>&1; then
  die "uv not found; required to run Python tooling"
fi

if (( ! CHECK )) && (( ! DRY_RUN )) && ! command -v npx >/dev/null 2>&1; then
  die "npx not found; install Node.js first"
fi

commands=()
while IFS= read -r command; do
  commands+=("$command")
done < <(
  uv run --no-project --python 3.12 python - "$MANIFEST" <<'PY'
import shlex
import sys
from pathlib import Path

import tomllib

manifest = Path(sys.argv[1])
data = tomllib.loads(manifest.read_text())

entries = data.get("external", [])
if not isinstance(entries, list):
    raise SystemExit("[[external]] entries must be a list")

for entry in entries:
    name = entry.get("name")
    source = entry.get("source")
    agents = entry.get("agents", [])
    skills = entry.get("skills", [])

    if not name or not isinstance(name, str):
        raise SystemExit("Each [[external]] entry needs a string name")
    if not source or not isinstance(source, str):
        raise SystemExit(f"{name}: source must be a string")
    if not agents or not all(isinstance(agent, str) and agent for agent in agents):
        raise SystemExit(f"{name}: agents must be a non-empty string array")
    if not skills or not all(isinstance(skill, str) and skill for skill in skills):
        raise SystemExit(f"{name}: skills must be a non-empty string array")

    args = ["npx", "skills@latest", "add", source, "-g", "-y", "-a", *agents, "-s", *skills]
    print(shlex.join(args))
PY
)

if (( CHECK )); then
  log "Skills manifest OK: $MANIFEST"
  if (( VERBOSE )); then
    printf '%s\n' "${commands[@]}"
  fi
  exit 0
fi

if (( DRY_RUN )); then
  log "Dry run - no skills will be installed"
  printf '%s\n' "${commands[@]}"
  exit 0
fi

export DISABLE_TELEMETRY="${DISABLE_TELEMETRY:-1}"

failures=0
for command in "${commands[@]}"; do
  log "Running: $command"
  if ! eval "$command"; then
    warn "Failed: $command"
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  die "AI skills install completed with $failures failure(s)"
fi

log "AI skills install complete"
