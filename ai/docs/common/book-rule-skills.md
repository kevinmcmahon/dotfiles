# Book Rule Skills

These skills turn selected `agent-rules-books` mini rule sets into on-demand lenses for Codex and Claude Code sessions.

## Available Skills

- `$book-refactoring-pass`: behavior-preserving structure changes and cleanup.
- `$book-legacy-change`: risky changes in weakly tested or hard-to-test code.
- `$book-reliability-review`: production readiness, failure modes, retries, timeouts, overload, and observability.
- `$book-domain-modeling`: bounded contexts, domain language, aggregates, entities, and value objects.
- `$book-data-systems`: ownership, durability, consistency, events, streams, replay, and derived data.

## Usage

Use one primary book lens per task. Add a second only when it works at a different level.

### Claude Code And OpenCode Slash Commands

Common book-rule commands are available in Claude Code and OpenCode after running `scripts/ai-sync.sh`:

| Command | Skill | Intent |
|---------|-------|--------|
| `/book-refactor` | `$book-refactoring-pass` | Behavior-preserving cleanup or preparatory refactoring |
| `/book-legacy-change` | `$book-legacy-change` | Risky changes in weakly tested or hard-to-test code |
| `/book-reliability-review` | `$book-reliability-review` | Production failure-mode review or reliability hardening |
| `/book-domain-modeling` | `$book-domain-modeling` | Model/domain-language pass before implementation |
| `/book-data-systems` | `$book-data-systems` | Data ownership, consistency, eventing, replay, or derived-data work |

Examples:

```text
/book-refactor Improve this module's structure without changing behavior.
```

```text
/book-legacy-change Add this feature with characterization tests first.
```

```text
/book-reliability-review Review this worker for timeout, retry, backpressure, and observability risks.
```

```text
/book-domain-modeling Help me model this billing workflow before we change the code.
```

```text
/book-data-systems Design the event and replay behavior for this projection.
```

### Codex Prompt Snippets

Codex does not currently have a slash-command sync target in this dotfiles layout. Use explicit prompt text instead:

```text
Use $book-refactoring-pass. Improve this module's structure without changing behavior.
```

```text
Use $book-legacy-change. Add this feature with characterization tests first.
```

```text
Use $book-reliability-review. Review this worker for timeout, retry, backpressure, and observability risks.
```

```text
Use $book-domain-modeling. Help me model this billing workflow before we change the code.
```

```text
Use $book-data-systems. Design the event and replay behavior for this projection.
```

Default behavior for each snippet: select the named skill lens, briefly state the risk/check plan, then proceed with the requested work unless blocked by missing essential context. The book lens stays subordinate to user instructions, repository instructions, and project architecture.

Good combinations:

- `$book-legacy-change` plus `$book-refactoring-pass`
- `$book-reliability-review` plus `$book-data-systems`
- `$book-domain-modeling` plus `$book-data-systems`

Avoid loading overlapping or conflicting lenses as equal peers:

- DDD and Patterns of Enterprise Application Architecture
- Refactoring and Refactoring.Guru
- Clean Code and Code Complete
- several full book files globally

## Local Layout

The tracked skill copies live in:

```text
~/dotfiles/ai/skills/common/<skill>/SKILL.md
```

Codex exposure uses symlinks in:

```text
~/.codex/skills/<skill>
```

Claude Code exposure uses local symlinks in:

```text
~/dotfiles/claude/skills/<skill>
```

`~/dotfiles/claude/skills` is ignored because it is a local symlink surface. The tracked content is the common skill directory.

## Refresh From Upstream

The upstream source is:

```text
~/sync/projects/ai/agent-rules-books
```

Each `SKILL.md` has a provenance block with the source file and source commit. To refresh a skill:

1. Pull or update `agent-rules-books`.
2. Compare the relevant upstream `*.mini.md` file with the skill's `Upstream Mini Rules` section.
3. Recopy the upstream mini rules under the skill wrapper.
4. Update the source commit in the provenance block.
5. Re-run a symlink check for Codex and Claude Code.

Do not edit the copied mini rules casually. Put local workflow guidance in the wrapper above the provenance block so future upstream refreshes stay simple.
