#!/usr/bin/env bash
# ABOUTME: Audit third-party AI skill sources declared in ai/skills-manifest.toml.
# ABOUTME: Reports upstream drift without installing, updating, or editing skills.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
MANIFEST="${SKILLS_MANIFEST:-$DOTFILES_DIR/ai/skills-manifest.toml}"

JSON=0
VERBOSE=0

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
  -v, --verbose
              Print full refs, source, risk, and notes in human output
  -h, --help  Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -f "$MANIFEST" ]] || die "Skills manifest not found: $MANIFEST"

if ! command -v uv >/dev/null 2>&1; then
  die "uv not found; required to run Python tooling"
fi

CURL_BIN="$(command -v curl || true)"
if [[ -z "$CURL_BIN" ]]; then
  die "curl not found; required to check GitHub sources"
fi
GH_BIN="$(command -v gh || true)"

uv run --python 3.12 python - "$MANIFEST" "$JSON" "$VERBOSE" "$CURL_BIN" "$GH_BIN" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

import tomllib

manifest = Path(sys.argv[1])
json_mode = sys.argv[2] == "1"
verbose_mode = sys.argv[3] == "1"
curl_bin = sys.argv[4]
gh_bin = sys.argv[5]
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

    if gh_bin:
        result = subprocess.run(
            [gh_bin, "api", f"repos/{repo}/commits/HEAD"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode == 0:
            try:
                payload = json.loads(result.stdout)
            except json.JSONDecodeError as exc:
                return None, f"error: invalid JSON from gh api: {exc}"

            sha = payload.get("sha")
            if isinstance(sha, str) and sha:
                return sha, None

            message = payload.get("message")
            if isinstance(message, str) and message:
                return None, f"error: {message}"
            return None, "error: gh api response did not include sha"

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


def short_ref(value):
    if not isinstance(value, str) or not value:
        return "-"
    return value[:12]


def status_count(count, status):
    return f"{count} {status}"


def print_verbose(entry):
    print(f"    source: {entry['source']}")
    if entry.get("reviewed_ref"):
        print(f"    reviewed_ref: {entry['reviewed_ref']}")
    if entry.get("latest_ref"):
        print(f"    latest_ref:   {entry['latest_ref']}")
    if entry.get("reviewed_at"):
        print(f"    reviewed_at: {entry['reviewed_at']}")
    if entry.get("risk"):
        print(f"    risk: {entry['risk']}")
    if entry.get("notes"):
        print(f"    notes: {entry['notes']}")


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

    status_order = ["current", "stale", "unreviewed", "unsupported", "error"]
    counts = {status: sum(1 for entry in results if entry["status"] == status) for status in status_order}
    summary = ", ".join(status_count(counts[status], status) for status in status_order if counts[status])
    print(f"Summary: {summary or '0 entries'}")

    attention = [entry for entry in results if entry["status"] != "current"]
    current = [entry for entry in results if entry["status"] == "current"]

    if attention:
        print("\nNeeds attention")
        for entry in attention:
            reviewed = short_ref(entry["reviewed_ref"])
            latest = short_ref(entry["latest_ref"])
            print(f"  {entry['status']:11} {entry['type']:8} {entry['name']}")
            if entry["status"] == "stale":
                print(f"    reviewed {reviewed} -> latest {latest}")
            elif entry["status"] == "unreviewed":
                print(f"    latest {latest}; add reviewed_ref after review")
            elif entry["status"] == "unsupported":
                print("    source is not a GitHub repo; use --json for stored metadata")
            elif entry["status"] == "error":
                print(f"    {entry['error']}")
            if verbose_mode:
                print_verbose(entry)

    if current:
        print("\nCurrent")
        for entry in current:
            print(f"  {entry['type']:8} {entry['name']} @ {short_ref(entry['latest_ref'])}")
            if verbose_mode:
                print_verbose(entry)

    if verbose_mode:
        print("\nUse --json for machine-readable output.")
    else:
        print("\nUse --verbose for full refs and notes; use --json for machine-readable output.")

raise SystemExit(1 if any(entry["status"] == "error" for entry in results) else 0)
PY
