# Workflow Protocol: Book Lenses

Part of the workflow protocol (`workflow-protocol.md`, beside this file). Read it at planning, before changing weakly tested code, and in the quality review.


The `book-*` skills hold distilled rules from software design books. Global
CLAUDE.md carries a short core of them in every session; load the full skill
at the checkpoints below, where its depth changes a decision. Repository rules,
the issue's settled decisions, and Kevin's instructions win over any book.

- Load at most three lenses at one checkpoint, chosen by the decision at hand,
  not by habit. Name each lens and the decision pressure it serves in the plan
  or the review, so a reader can see which rules shaped the work.
- Planning, for any change to a module's interface, a new module, or a
  decomposition: `book-a-philosophy-of-software-design`. Add
  `book-clean-architecture` when the change moves a dependency across a
  boundary (domain code, adapters, the composition root).
- Planning, when the change touches stored data, a cache or derived index, a
  file format, concurrency, retries, or anything two writers can reach:
  `book-data-systems`.
- Planning, when the work turns on domain language, aggregates, or the edges
  between contexts: `book-domain-modeling`. Reach for
  `book-domain-driven-design` or `book-implementing-domain-driven-design` only
  when the strategic or tactical question needs more depth than that.
- Planning, when choosing an enterprise pattern (repository, unit of work,
  service layer, data mapper): `book-patterns-of-enterprise-application-architecture`.
- Before changing code that has weak or no tests, unclear behavior, or hard
  setup: `book-legacy-change`, so characterization tests and seams come before
  the edit.
- Behavior-preserving refactors: `book-refactoring-pass` for the plan and the
  safety steps; add `book-refactoring-guru` when choosing which refactoring
  answers a given smell.
- Construction of non-trivial routines (error handling, defensive checks,
  control flow): `book-code-complete`.
- Services, workers, scheduled jobs, network clients, timeouts, retries, and
  anything that runs unattended: `book-reliability-review`, at planning and
  again in the quality review.
- The quality review always loads `book-clean-code`, plus every lens the plan
  named, so the reviewer judges the code against the same rules that shaped
  it.
- Unclear trade-offs with no better-fitting lens: `book-the-pragmatic-programmer`.
- A lens that does not apply after loading it gets dropped, with one line
  saying why. Do not stretch a book's rules over a decision they were not
  written for.
