#!/usr/bin/env bash
# ABOUTME: Audit third-party AI skill sources declared in ai/skills-manifest.toml.
# ABOUTME: Reports upstream drift without installing, updating, or editing skills.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
MANIFEST="${SKILLS_MANIFEST:-$DOTFILES_DIR/ai/skills-manifest.toml}"

JSON=0

die() {
  printf "\033[1;31mERR:\033[0m %s\n" "$*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: audit-ai-skills.sh [OPTIONS]

Audit external and watched AI skill sources declared in ai/skills-manifest.toml.
This command is read-only: it never installs, updates, or edits skills.

Options:
  --json      Print machine-readable JSON
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -f "$MANIFEST" ]] || die "Skills manifest not found: $MANIFEST"

if ! command -v python3 >/dev/null 2>&1; then
  die "python3 not found; required to read TOML manifest"
fi

CURL_BIN="$(command -v curl || true)"
if [[ -z "$CURL_BIN" ]]; then
  die "curl not found; required to check GitHub sources"
fi

python3 - "$MANIFEST" "$JSON" "$CURL_BIN" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

try:
    import tomllib
except ModuleNotFoundError:
    raise SystemExit("python tomllib is required; use Python 3.11+")

manifest = Path(sys.argv[1])
json_mode = sys.argv[2] == "1"
curl_bin = sys.argv[3]
data = tomllib.loads(manifest.read_text())


def require_entries(kind):
    entries = data.get(kind, [])
    if not isinstance(entries, list):
        raise SystemExit(f"[[{kind}]] entries must be a list")
    return entries


def github_repo(source):
    if not isinstance(source, str) or not source:
        return None

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


def latest_ref_for(source):
    repo = github_repo(source)
    if repo is None:
        return None, "unsupported"

    url = f"https://api.github.com/repos/{repo}/commits/HEAD"
    result = subprocess.run(
        [curl_bin, "-fsSL", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        return None, f"error: {result.stderr.strip() or 'curl failed'}"

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        return None, f"error: invalid JSON from GitHub API: {exc}"

    sha = payload.get("sha")
    if not isinstance(sha, str) or not sha:
        message = payload.get("message")
        if isinstance(message, str) and message:
            return None, f"error: {message}"
        return None, "error: GitHub API response did not include sha"

    return sha, None


def status_for(entry, latest_ref, error):
    reviewed_ref = entry.get("reviewed_ref")
    if error == "unsupported":
        return "unsupported"
    if error:
        return "error"
    if not isinstance(reviewed_ref, str) or not reviewed_ref:
        return "unreviewed"
    if reviewed_ref == latest_ref:
        return "current"
    return "stale"


def validate_entry(kind, entry):
    name = entry.get("name")
    source = entry.get("source")
    if not isinstance(name, str) or not name:
        raise SystemExit(f"[[{kind}]] entry needs a string name")
    if not isinstance(source, str) or not source:
        raise SystemExit(f"{name}: source must be a string")


results = []
for kind in ("external", "watch"):
    for entry in require_entries(kind):
        if not isinstance(entry, dict):
            raise SystemExit(f"[[{kind}]] entries must be tables")
        validate_entry(kind, entry)
        latest_ref, error = latest_ref_for(entry["source"])
        results.append(
            {
                "type": kind,
                "name": entry["name"],
                "source": entry["source"],
                "status": status_for(entry, latest_ref, error),
                "reviewed_ref": entry.get("reviewed_ref"),
                "latest_ref": latest_ref,
                "reviewed_at": entry.get("reviewed_at"),
                "risk": entry.get("risk"),
                "notes": entry.get("notes"),
                "error": None if error == "unsupported" else error,
            }
        )

if json_mode:
    print(json.dumps({"manifest": str(manifest), "entries": results}, indent=2, sort_keys=True))
else:
    print(f"AI skills audit: {manifest}")
    for entry in results:
        latest = entry["latest_ref"] or "-"
        reviewed = entry["reviewed_ref"] or "-"
        print(
            f"{entry['status']:11} {entry['type']:8} {entry['name']} "
            f"(reviewed={reviewed}, latest={latest})"
        )
        if entry["error"]:
            print(f"  {entry['error']}")

raise SystemExit(1 if any(entry["status"] == "error" for entry in results) else 0)
PY
