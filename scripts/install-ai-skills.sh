#!/usr/bin/env bash
# ABOUTME: Install declared third-party AI skills with the skills CLI.
# ABOUTME: Records successful GitHub-backed installs in ai/skills-manifest.toml.
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

uv_python() {
  uv run --no-project --python 3.12 python "$@"
}

usage() {
  cat <<'EOF'
Usage: install-ai-skills.sh [OPTIONS]

Install third-party AI skills declared in ai/skills-manifest.toml and record
the installed GitHub refs back into the manifest.

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

entry_names=()
entry_sources=()
commands=()
while IFS=$'\t' read -r name source command; do
  entry_names+=("$name")
  entry_sources+=("$source")
  commands+=("$command")
done < <(
  uv_python - "$MANIFEST" <<'PY'
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
    print(f"{name}\t{source}\t{shlex.join(args)}")
PY
)

update_manifest_review_refs() {
  local reviewed_at="${AI_SKILLS_REVIEWED_AT:-$(date +%F)}"

  log "Updating manifest review refs"
  uv_python - "$MANIFEST" "$reviewed_at" "$@" <<'PY'
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

manifest = Path(sys.argv[1])
reviewed_at = sys.argv[2]
args = sys.argv[3:]

if len(args) % 2 != 0:
    raise SystemExit("expected successful entries as name/source pairs")

successful_entries = list(zip(args[0::2], args[1::2]))


def github_repo(source):
    owner_repo = re.fullmatch(r"([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)", source)
    if owner_repo:
        return f"{owner_repo.group(1)}/{owner_repo.group(2)}"

    parsed = urlparse(source)
    if parsed.netloc not in {"github.com", "www.github.com"}:
        return None

    parts = [part for part in parsed.path.strip("/").split("/") if part]
    if len(parts) < 2:
        return None

    repo = parts[1].removesuffix(".git")
    return f"{parts[0]}/{repo}"


def parse_github_payload(stdout, tool_name):
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON from {tool_name}: {exc}") from exc

    sha = payload.get("sha")
    if isinstance(sha, str) and sha:
        return sha

    message = payload.get("message")
    if isinstance(message, str) and message:
        raise SystemExit(message)
    raise SystemExit(f"{tool_name} response did not include sha")


def latest_ref_for(source):
    repo = github_repo(source)
    if repo is None:
        return None

    errors = []
    gh_bin = shutil.which("gh")
    if gh_bin:
        result = subprocess.run(
            [gh_bin, "api", f"repos/{repo}/commits/HEAD"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode == 0:
            return parse_github_payload(result.stdout, "gh api")
        errors.append(result.stderr.strip() or "gh api failed")

    curl_bin = shutil.which("curl")
    if curl_bin:
        result = subprocess.run(
            [curl_bin, "-fsSL", f"https://api.github.com/repos/{repo}/commits/HEAD"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode == 0:
            return parse_github_payload(result.stdout, "GitHub API")
        errors.append(result.stderr.strip() or "curl failed")

    detail = "; ".join(error for error in errors if error)
    if detail:
        raise SystemExit(f"{repo}: unable to resolve latest ref: {detail}")
    raise SystemExit(f"{repo}: unable to resolve latest ref: gh or curl required")


def short_ref(value):
    return value[:12] if value else "-"


def extract_string_field(block, field):
    match = re.search(rf'(?m)^{field}\s*=\s*"([^"]*)"\s*$', block)
    return match.group(1) if match else None


def line_for(field, value):
    return f'{field} = "{value}"\n'


def insertion_index(lines):
    for index, line in enumerate(lines):
        if re.match(r"^(risk|notes)\s*=", line):
            return index

    index = len(lines)
    while index > 0 and lines[index - 1].strip() == "":
        index -= 1
    return index


def upsert_review_fields(block, latest_ref):
    old_ref = extract_string_field(block, "reviewed_ref")
    lines = block.splitlines(keepends=True)
    ref_index = None
    at_index = None

    for index, line in enumerate(lines):
        if re.match(r"^reviewed_ref\s*=", line):
            ref_index = index
        elif re.match(r"^reviewed_at\s*=", line):
            at_index = index

    if ref_index is None:
        insert_at = at_index if at_index is not None else insertion_index(lines)
        lines.insert(insert_at, line_for("reviewed_ref", latest_ref))
        ref_index = insert_at
        if at_index is not None:
            at_index += 1

    if at_index is None:
        lines.insert(ref_index + 1, line_for("reviewed_at", reviewed_at))
        at_index = ref_index + 1

    lines[ref_index] = line_for("reviewed_ref", latest_ref)
    lines[at_index] = line_for("reviewed_at", reviewed_at)
    return "".join(lines), old_ref


refs_by_name = {}
skipped = []
for name, source in successful_entries:
    latest_ref = latest_ref_for(source)
    if latest_ref is None:
        skipped.append(name)
        continue
    refs_by_name[name] = latest_ref

text = manifest.read_text()
header_re = re.compile(r"(?m)^\[\[([A-Za-z0-9_-]+)\]\]\s*$")
matches = list(header_re.finditer(text))
parts = []
position = 0
updated = []

for index, match in enumerate(matches):
    parts.append(text[position : match.start()])
    block_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
    block = text[match.start() : block_end]

    if match.group(1) == "external":
        name = extract_string_field(block, "name")
        latest_ref = refs_by_name.get(name)
        if latest_ref is not None:
            block, old_ref = upsert_review_fields(block, latest_ref)
            updated.append((name, old_ref, latest_ref))

    parts.append(block)
    position = block_end

parts.append(text[position:])

if updated:
    manifest.write_text("".join(parts))

for name, old_ref, latest_ref in updated:
    print(f"    {name}: {short_ref(old_ref)} -> {short_ref(latest_ref)}")
for name in skipped:
    print(f"    {name}: skipped; source is not a GitHub repo")
PY
}

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
successful_entries=()
for index in "${!commands[@]}"; do
  name="${entry_names[$index]}"
  source="${entry_sources[$index]}"
  command="${commands[$index]}"

  log "Running: $command"
  if eval "$command"; then
    successful_entries+=("$name" "$source")
  else
    warn "Failed: $command"
    failures=$((failures + 1))
  fi
done

if (( ${#successful_entries[@]} > 0 )); then
  update_manifest_review_refs "${successful_entries[@]}"
fi

if (( failures > 0 )); then
  die "AI skills install completed with $failures failure(s)"
fi

log "AI skills install complete"
