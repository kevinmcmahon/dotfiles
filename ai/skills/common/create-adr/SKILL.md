---
name: create-adr
description: Drafts and updates Architecture Decision Records using Michael Nygard's lightweight ADR structure and adr.github.io guidance. Use when a user asks to create, write, review, split, supersede, or document an ADR, architecture decision, decision log entry, or design decision record.
---

# Create ADR

## Quick Start

Create or update concise ADRs that capture one significant decision, why it was
made, and what follows from it. Prefer the repository's existing ADR conventions
when present.

Use the Nygard structure:

```md
# N. Short decision title

Date: YYYY-MM-DD

## Status

Proposed | Accepted | Superseded by [NNNN](...)

## Context

What forces, constraints, risks, and local facts motivate the decision?

## Decision

We will ...

## Consequences

What changes after this decision, including positive, negative, and neutral effects?
```

## Workflow

1. Inspect existing ADRs or decision docs before drafting. Match numbering,
   filenames, status words, heading style, link style, and index conventions.
2. Decide whether there is one significant decision or several. Split separate
   decisions into separate ADRs.
3. Write the context in value-neutral language: facts, forces, constraints,
   trade-offs, and project-local history.
4. Write the decision in active voice, usually starting with `We will ...`.
5. Write consequences as the resulting future context. Include costs, constraints,
   follow-on work, and risks, not only benefits.
6. Preserve the decision log. If a decision changes, add a new ADR and mark the
   older one superseded instead of rewriting history.
7. Update any ADR index, architecture overview, or nearby docs that should point
   to the new decision.

## Quality Bar

- One ADR records one architecturally significant decision.
- Keep it short enough for a future maintainer to actually read.
- Prefer concrete local forces over generic best-practice language.
- Avoid hiding alternatives in mushy prose. Name the trade-off being accepted.
- Do not use ADRs for transient task notes, implementation minutiae, or decisions
  with no architectural consequence.
- Do not make Status do rationale work; use Context and Consequences for that.

## References

For source-material details, read [references/nygard-adr.md](references/nygard-adr.md).
