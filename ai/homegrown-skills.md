# Home-Grown AI Skills

These skills are authored in this dotfiles repo today. The follow-up goal is to
move packageable skills into a separate skills repository so they can be
installed with `npx skills add`.

## Packageable Candidates

| Skill | Current source | Notes |
| --- | --- | --- |
| `perplexity` | `ai/skills/claude/perplexity`, `ai/skills/codex/perplexity` | Merge the duplicated Claude/Codex variants into one portable skill before packaging. |
| `runpodctl` | `ai/skills/common/runpodctl` | Packageable external CLI workflow. |
| `swift-best-practices` | `ai/skills/common/swift-best-practices` | Package with nested SwiftUI guidance as a separate skill or reference. |
| `coding-best-practices` | `ai/skills/common/coding-best-practices` | Package after clarifying overlap with Swift-specific guidance. |
| `claude-codex` | `ai/skills/claude/codex` | Package only after removing local persona-specific wording and making assumptions portable. |

## Local-Private For Now

| Skill | Current source | Reason |
| --- | --- | --- |
| `book-data-systems` | `ai/skills/common/book-data-systems` | Keep local until redistribution and provenance cleanup are resolved. |
| `book-domain-modeling` | `ai/skills/common/book-domain-modeling` | Keep local until redistribution and provenance cleanup are resolved. |
| `book-legacy-change` | `ai/skills/common/book-legacy-change` | Keep local until redistribution and provenance cleanup are resolved. |
| `book-refactoring-pass` | `ai/skills/common/book-refactoring-pass` | Keep local until redistribution and provenance cleanup are resolved. |
| `book-reliability-review` | `ai/skills/common/book-reliability-review` | Keep local until redistribution and provenance cleanup are resolved. |
| `issue-prompt` | `ai/skills/common/issue-prompt` | Personal workflow for generating ready-to-paste Linear implementation prompts from repo guidance. |

## Superseded By External Installs

External skills win by name. These local copies should not be injected into
global skill surfaces unless they are renamed or intentionally forked.

| Skill | Local source | External source |
| --- | --- | --- |
| `grill-me` | `ai/skills/common/grill-me` | `mattpocock/skills` |
| `improve-codebase-architecture` | `ai/skills/common/improve-codebase-architecture` | `mattpocock/skills` |
