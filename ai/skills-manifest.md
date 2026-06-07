# AI Skills Manifest

`ai/skills-manifest.toml` is this repo's declaration of intent for AI skills
that are not simply symlinked from `ai/skills/`.

It is a bespoke dotfiles contract. The file is not part of Codex, Claude Code,
OpenCode, or the `skills` CLI. It exists so this repo can describe what should
be installed, what should only be watched, and which repo-owned skills still
need packaging work.

## Problem It Solves

AI skills are small, easy to copy, and easy to forget. That creates three
maintenance problems:

- A copied skill snapshot can silently become stale while upstream keeps moving.
- Some useful repositories are discovery indexes, not installable skills.
- Agent-local skill directories contain package-manager state that should not be
  committed to dotfiles.

The manifest keeps those concerns separate. It records intent and review state
in git, while local package-manager state stays local.

## How It Works

The manifest has three entry types:

- `[[external]]`: third-party skills that should be installed with
  `scripts/install-ai-skills.sh`.
- `[[watch]]`: upstream repositories or URLs worth tracking, but not installed
  directly.
- `[[local]]`: repo-owned skill sources that are symlinked by `scripts/ai-sync.sh`
  or tracked as future packaging candidates.

Two scripts consume the manifest:

- `scripts/install-ai-skills.sh` reads `[[external]]` entries and translates them
  into `npx skills@latest add ...` commands.
- `scripts/audit-ai-skills.sh` reads `[[external]]` and `[[watch]]` entries,
  checks GitHub-backed sources for drift, and reports whether each reviewed ref
  is current.

Neither script owns the lock file. The `skills` CLI owns resolution,
installation, and local lock state under `~/.agents/.skill-lock.json`.

## Decision Rule

Use this rule before adding or moving a skill entry:

- If you authored it or maintain it in this repo, keep it in `ai/skills/...` and
  list it as `[[local]]`.
- If `npx skills` should install it from elsewhere, use `[[external]]`.
- If it is useful to track but not install, use `[[watch]]`.
- If it is generated or package-manager state, do not put it in git.

## Expected Outcomes

The manifest should make these things obvious:

- which third-party skills are intended to be installed
- which sources are only references or discovery indexes
- when an upstream source was last reviewed
- whether a source is likely to become stale because it mirrors policy, APIs, or
  tool behavior
- why a repo-owned skill has not been packaged yet

The manifest should not:

- vendor third-party skill text into this repo
- automatically update active skills
- replace Apple, Swift, OpenAI, Anthropic, or tool documentation as the source of
  truth
- commit generated package-manager state

## Entry Types

### `[[external]]`

Use `[[external]]` for third-party skills that should be installed into one or
more agent skill directories.

Required fields:

- `name`: stable human-readable entry name.
- `source`: source accepted by `npx skills add`, such as `owner/repo` or a skill
  URL.
- `agents`: target agents passed to `npx skills add -a`, such as `codex`,
  `claude-code`, or `opencode`.
- `skills`: skill names passed to `npx skills add -s`.

Recommended review fields:

- `reviewed_ref`: upstream commit SHA last reviewed. For non-GitHub URL sources,
  omit this unless there is a stable revision identifier.
- `reviewed_at`: date of review in `YYYY-MM-DD` format.
- `risk`: short maintenance category.
- `notes`: why this entry exists and what future maintainers should check.

Example:

```toml
[[external]]
name = "app-store-review"
source = "safaiyeh/app-store-review-skill"
agents = ["codex", "claude-code", "opencode"]
skills = ["app-store-review"]
reviewed_ref = "3497c26895bcef743e06de2bd83675a68dea3555"
reviewed_at = "2026-06-07"
risk = "policy-stale"
notes = "Verify against current Apple App Store Review Guidelines before relying on findings."
```

### `[[watch]]`

Use `[[watch]]` for sources that should be checked periodically but should not be
installed directly. This is the right place for curated indexes, comparison
repos, and candidate skills that need more review.

Required fields:

- `name`: stable human-readable entry name.
- `source`: GitHub repo or source URL.

Recommended review fields:

- `reviewed_ref`: upstream commit SHA last reviewed, when available.
- `reviewed_at`: date of review in `YYYY-MM-DD` format.
- `risk`: why this source needs review.
- `notes`: what the source is for and whether it should remain watch-only.

Example:

```toml
[[watch]]
name = "swift-agent-skills-index"
source = "twostraws/Swift-Agent-Skills"
reviewed_ref = "79dacde53418e718d3ae2c6c44d7eb65c0b9b33e"
reviewed_at = "2026-06-07"
risk = "discovery-only"
notes = "Curated index of Swift and Apple platform skills. Use for discovery; do not install directly."
```

### `[[local]]`

Use `[[local]]` for dotfiles-owned skills that are managed by this repo rather
than by `npx skills`.

Required fields:

- `name`: skill or skill-group name.
- `source`: repo path or glob for the source files.
- `status`: current maintenance state.

Optional fields:

- `notes`: packaging, provenance, or maintenance context.

Current `status` values:

- `move-to-skills-repo`: portable enough to package later, but not ready yet.
- `local-private`: intentionally kept local unless provenance or redistribution
  concerns are resolved.

Example:

```toml
[[local]]
name = "swift-best-practices"
source = "ai/skills/common/swift-best-practices"
status = "move-to-skills-repo"
```

## Risk Categories

`risk` is intentionally a short label, not a taxonomy that needs a schema.
Common values:

- `policy-stale`: legal, store-review, compliance, or policy guidance that must
  be checked against current official docs.
- `api-stale`: framework, SDK, or model guidance that can drift as APIs change.
- `tool-stale`: workflow guidance tied to a CLI, plugin, or external tool.
- `workflow`: process guidance that is mostly evergreen but still worth
  reviewing.
- `discovery-only`: index or catalog; useful for finding skills but not
  installed directly.
- `low`: low expected drift.

Prefer a clear existing value. Add a new value only when it communicates a
meaningful maintenance difference.

## Commands

Validate installable entries:

```bash
scripts/install-ai-skills.sh --check
```

Preview install commands:

```bash
scripts/install-ai-skills.sh --dry-run
```

Audit upstream drift:

```bash
scripts/audit-ai-skills.sh
```

Print audit results as JSON:

```bash
scripts/audit-ai-skills.sh --json
```

## Maintenance Rules

- Add `[[external]]` only when the skill should actually be installed.
- Add `[[watch]]` when a source is useful but not trusted, reviewed, or
  installable enough for active use.
- Keep App Store, legal, model, and SDK guidance source-linked and reviewed
  because those facts change.
- Do not copy third-party skill folders into `ai/skills/common` just to avoid an
  install command.
- Do not commit `~/.agents/.skill-lock.json`; it is local package-manager state.
- When updating `reviewed_ref`, inspect the upstream diff first and update
  `reviewed_at` and `notes` if the maintenance posture changed.
