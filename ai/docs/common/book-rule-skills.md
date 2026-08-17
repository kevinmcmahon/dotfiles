# Book Rule Skills

These skills turn selected `agent-rules-books` mini rule sets into on-demand lenses for Codex and Claude Code sessions.

## Available Skills

- `$book-refactoring-pass`: behavior-preserving structure changes and cleanup.
- `$book-legacy-change`: risky changes in weakly tested or hard-to-test code.
- `$book-reliability-review`: production readiness, failure modes, retries, timeouts, overload, and observability.
- `$book-domain-modeling`: bounded contexts, domain language, aggregates, entities, and value objects.
- `$book-data-systems`: ownership, durability, consistency, events, streams, replay, and derived data.
- `$book-a-philosophy-of-software-design`: complexity reduction, abstraction control, and module-level simplicity.
- `$book-clean-architecture`: dependency direction, business-policy-first design, and boundary protection.
- `$book-clean-code`: naming, function shape, readability, and practical maintainability.
- `$book-code-complete`: construction rigor, defensive coding, and implementation safety.
- `$book-domain-driven-design`: strategic DDD, bounded contexts, and integration semantics.
- `$book-implementing-domain-driven-design`: tactical DDD patterns, aggregate boundaries, and translation design.
- `$book-patterns-of-enterprise-application-architecture`: mature enterprise pattern selection and anti-pattern avoidance.
- `$book-refactoring-guru`: practical refactoring catalog patterns and transformation planning.
- `$book-the-pragmatic-programmer`: uncertainty reduction, feedback loops, and pragmatic tradeoffs.

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
| `/book-a-philosophy-of-software-design` | `$book-a-philosophy-of-software-design` | Complexity trimming and design-simplicity guidance |
| `/book-clean-architecture` | `$book-clean-architecture` | Boundary design and dependency-rule checks |
| `/book-clean-code` | `$book-clean-code` | Readability-first implementation and cleanup guidance |
| `/book-code-complete` | `$book-code-complete` | Implementation discipline and defensive programming checks |
| `/book-domain-driven-design` | `$book-domain-driven-design` | Strategic DDD modeling and bounded-context decisions |
| `/book-implementing-domain-driven-design` | `$book-implementing-domain-driven-design` | Tactical DDD implementation guidance |
| `/book-patterns-of-enterprise-application-architecture` | `$book-patterns-of-enterprise-application-architecture` | Pattern-level design choices for enterprise systems |
| `/book-refactoring-guru` | `$book-refactoring-guru` | Catalog-based refactoring sequences and safety planning |
| `/book-the-pragmatic-programmer` | `$book-the-pragmatic-programmer` | Pragmatic habits, uncertainty, and practical tradeoff checks |

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

```text
/book-a-philosophy-of-software-design Simplify this area before adding another layer.
```

```text
/book-clean-architecture Refactor this flow around stable business boundaries.
```

```text
/book-clean-code Clean this code path so it is easier to read and maintain.
```

```text
/book-domain-driven-design Redesign this context boundary for cleaner domain language.
```

```text
/book-patterns-of-enterprise-application-architecture Pick a better pattern for this integration and data flow.
```

### Codex Prompt Snippets

Codex uses skills as the reusable workflow surface in this dotfiles layout. Use explicit prompt text instead:

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

```text
Use $book-a-philosophy-of-software-design. Help me reduce complexity before the next change.
```

```text
Use $book-clean-architecture. Review this module for dependency direction and boundary issues.
```

```text
Use $book-domain-driven-design. Redesign the bounded context model before implementation.
```

```text
Use $book-refactoring-guru. Plan this transformation as a sequence of safe refactorings.
```

Default behavior for each snippet: select the named skill lens, briefly state the risk/check plan, then proceed with the requested work unless blocked by missing essential context. The book lens stays subordinate to user instructions, repository instructions, and project architecture.

### Compatibility-aware composition

`docs/COMPATIBILITY.md` drives which book mini rules can be active together.
Use [`book-skill-compatibility-check.md`](book-skill-compatibility-check.md) for an operational version of the same rules.

- Use a single primary lens by default.
- When adding a second lens, confirm it is complementary in the matrix.
- For overlaps, prefer one primary lens and one narrowly scoped secondary lens; avoid both as equal peers.

Hard conflicts (do not load as peers):

- `$book-domain-driven-design` + `$book-patterns-of-enterprise-application-architecture`
- `$book-implementing-domain-driven-design` + `$book-patterns-of-enterprise-application-architecture`

Known overlaps (avoid as equal peers; make one lens primary):

- `$book-a-philosophy-of-software-design` + `$book-clean-code`
- `$book-clean-architecture` + `$book-implementing-domain-driven-design`
- `$book-clean-architecture` + `$book-patterns-of-enterprise-application-architecture`
- `$book-clean-code` + `$book-code-complete`
- `$book-clean-code` + `$book-the-pragmatic-programmer`
- `$book-code-complete` + `$book-the-pragmatic-programmer`
- `$book-domain-driven-design` + `$book-implementing-domain-driven-design`
- `$book-refactoring-pass` + `$book-refactoring-guru`
- `$book-domain-modeling` + `$book-implementing-domain-driven-design`
- `$book-domain-modeling` + `$book-patterns-of-enterprise-application-architecture`

Good combinations:

- `$book-legacy-change` plus `$book-refactoring-pass`
- `$book-reliability-review` plus `$book-data-systems`
- `$book-domain-modeling` plus `$book-data-systems`
- `$book-domain-driven-design` plus `$book-implementing-domain-driven-design` (scope one as primary, one as narrow tactical lens)

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
