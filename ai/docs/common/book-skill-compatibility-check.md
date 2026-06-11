# Book Skill Compatibility Check

Use this checklist before activating more than one local book lens.

## Source of truth

This check list is the operationalized form of
[`/sync/projects/ai/agent-rules-books/docs/COMPATIBILITY.md`](../../../../sync/projects/ai/agent-rules-books/docs/COMPATIBILITY.md):

- Hard conflict and overlap pairs are copied directly from that matrix.
- Unlisted book lens pairs are complementary by default.
- Keep this file synchronized with the matrix whenever upstream compatibility guidance changes.

## Skill name mapping (local -> source mini)

- `book-a-philosophy-of-software-design` -> `a-philosophy-of-software-design`
- `book-clean-architecture` -> `clean-architecture`
- `book-clean-code` -> `clean-code`
- `book-code-complete` -> `code-complete`
- `book-data-systems` -> `designing-data-intensive-applications`
- `book-domain-driven-design` -> `domain-driven-design`
- `book-domain-modeling` -> `domain-driven-design-distilled`
- `book-refactoring-guru` -> `refactoring-guru`
- `book-refactoring-pass` -> `refactoring`
- `book-implementing-domain-driven-design` -> `implementing-domain-driven-design`
- `book-patterns-of-enterprise-application-architecture` -> `patterns-of-enterprise-application-architecture`
- `book-reliability-review` -> `release-it`
- `book-the-pragmatic-programmer` -> `the-pragmatic-programmer`
- `book-legacy-change` -> `working-effectively-with-legacy-code`

## Hard conflicts (do not load as peers)

- `book-domain-driven-design` + `book-patterns-of-enterprise-application-architecture`
- `book-implementing-domain-driven-design` + `book-patterns-of-enterprise-application-architecture`

## Overlaps (do not use as equal peers)

Choose one primary lens and one narrow/lens-later approach.

- `book-a-philosophy-of-software-design` + `book-clean-code`
- `book-clean-architecture` + `book-implementing-domain-driven-design`
- `book-clean-architecture` + `book-patterns-of-enterprise-application-architecture`
- `book-clean-code` + `book-code-complete`
- `book-clean-code` + `book-the-pragmatic-programmer`
- `book-code-complete` + `book-the-pragmatic-programmer`
- `book-domain-driven-design` + `book-domain-modeling`
- `book-domain-driven-design` + `book-implementing-domain-driven-design`
- `book-domain-modeling` + `book-implementing-domain-driven-design`
- `book-domain-modeling` + `book-patterns-of-enterprise-application-architecture`
- `book-refactoring-pass` + `book-refactoring-guru`

## Recommended peer pairings (from compatibility matrix)

These are generally good complementary combinations in practice:

- `book-legacy-change` + `book-refactoring-pass`
- `book-reliability-review` + `book-data-systems`
- `book-domain-modeling` + `book-data-systems`
- `book-clean-architecture` + `book-code-complete` for service-level refactors (if `book-clean-code` is not also active)

## Quick check

- If a pair appears in **hard conflicts**, keep one out or switch to scoped invocation.
- If a pair appears in **overlaps**, prefer one as the primary lens and explicitly defer the other.
- If not listed above, the combination is complementary by default (`docs/COMPATIBILITY.md` baseline).
