# Workflow Protocol

How agents run a unit of work for Kevin, from issue to merged commit. This file
defines the cross-project workflow. A repo's `AGENTS.md` (and its
`docs/agents/*.md`) supplies its commands, verification matrix, safety
constraints, acceptance criteria, and tracker context. Those repo-specific
requirements remain binding. Read the repo's `AGENTS.md` before planning or
changing code.

Skills (TDD, worktrees, review, branch finishing) supply technique. This file
controls implementer ownership, delegation, review scope, mutation checks, and
final verification. It overrides conflicting procedures in skills, templates,
and older issue briefs, including fresh implementers and two reviews per task.
Only Kevin's explicit instructions for the current task can change that
workflow. Repository safety rules, acceptance criteria, and required checks
remain binding. No PRs, merge commits, or push without being asked.

## The shape of a unit of work

Issue -> isolated worktree -> baseline gates -> plan and risk checks ->
red/green TDD -> integrate current main -> whole-issue spec review ->
whole-issue quality review -> final verification -> fast-forward merge ->
tracker closeout. One primary implementer retains ownership across coupled
tasks. One issue per session. One logical commit per issue when feasible.

## Sizing the work

Pick the tier before starting and say which one applies.

- Trivial: anything on the "Do It" list in global CLAUDE.md (typos,
  formatting, lint or type fixes, a missing import) with no behavior change.
  Edit in place, run the relevant gates, and report. No worktree, subagent,
  review, or tracker steps. Commit only when Kevin asks.
- Standard: any behavior change or tracked issue. The full shape above applies.
- Risky: anything under the Ask First rules in global CLAUDE.md or the repo's
  AGENTS.md. Standard, plus Kevin approves the plan before any code changes.

Work without an issue follows the tier that fits, minus the tracker steps. Name
the branch for the change and leave the issue id out of the commit message.

## Issue tracker

- "work on ABC-123" means: fetch that exact issue before planning or changing
  code. The issue (and its agent brief, if present) supplies the scope and
  acceptance criteria. Apply this protocol's workflow when an older brief
  prescribes per-task implementers, per-task review pairs, or mutation checks
  for every new test.
- If the issue lacks verifiable acceptance criteria, derive them, state them in
  the plan, and proceed. Ask Kevin only when two readings of the issue would
  produce different behavior.
- Read the repo's `docs/agents/issue-tracker.md` before reading, updating, or
  creating issues. It holds the fixed context: workspace, team, issue prefix,
  default project.
- Move the issue to In Progress and assign it to Kevin when starting.
- Use existing labels as context; add obvious missing ones when clearly
  warranted.
- Do not create issues during normal work. Create them only when Kevin
  explicitly asks. Report follow-ups in chat or the final comment instead of
  filing them automatically.
- Post one final comment per issue: implementation summary, changed areas,
  verification commands with actual results, and any follow-ups.
- Move to Done only after required verification passes. If blocked or
  verification fails, leave the issue In Progress and comment with the blocker
  or the failing command details.

## Isolation and history

- Run `git status` before touching anything. Uncommitted or untracked changes
  that predate the session are Kevin's work: never stash, reset, check out,
  clean, or commit them. If a file the task must change already carries
  uncommitted edits, tell Kevin and ask whether they belong in the commit.
- Stage files by path. Never use `git add -A` or `git commit -a`.
- Create an isolated branch or git worktree before changing code, unless the
  workspace is already isolated for that issue. Use the tracker's
  `gitBranchName` when available.
- A branch the harness assigns (such as a cloud session's auto-named branch)
  does not replace the `gitBranchName`: create the `gitBranchName` branch from
  it and commit there. Push only what the task's instructions authorize.
- Before creating anything, check for an existing `.worktrees/<issue-id>` or an
  issue already In Progress. If either exists, inspect the branch state and
  resume from it instead of starting over.
- Place worktrees under `.worktrees/<issue-id>` in the repo root, not as peer
  directories next to the repo. This location wins over a harness or skill
  default; only repo-specific guidance overrides it. Ensure `.worktrees/` is
  git-ignored before creating repo-local worktrees.
- Worktree tooling may branch from origin's default branch. If local main is
  ahead of origin (unpushed work), fast-forward the new branch to local main
  before starting, or the baseline silently misses prior work.
- A fresh worktree has no ignored files (local env files, virtualenvs,
  installed dependencies). Run the repo's worktree setup command from AGENTS.md
  before the baseline. When AGENTS.md names none, run the package manager's
  locked install (`uv sync --locked`, `npm ci`, or the stack's equivalent),
  copy no ignored credential file such as `.env`, and report the missing
  command as a follow-up.
- Run the gates in the fresh worktree before changing anything and record the
  result. A failure here is pre-existing: report it to Kevin before building on
  top of it.
- Use the approved command forms in the user's global instructions and command
  rules. Check required worktree and tool-cache access during setup. When an
  exception is needed, propose a reusable operation-level prefix rather than
  an approval tied to a filename, branch, or temporary path.
- Linear history only: fast-forward merges, no merge commits, no PRs. While the
  branch is unpushed, amend or squash review fixes into the logical commit they
  belong to.
- Verify the gates on the branch tip, after the final amend or squash and with
  a clean working tree, then fast-forward main to it. A fast-forward makes main
  the exact commit you verified, so don't re-run the gates on main. If main has
  moved, rebase the branch and re-verify before the fast-forward. If
  uncommitted changes in main's working tree block the fast-forward, stop and
  ask.
- After the merge is confirmed on main, remove the worktree and delete the
  branch with `git branch -d`. A refusal means the branch is not merged; find
  out why instead of forcing the delete.
- Commit messages: gitmoji conventional commits including the issue id, e.g.
  `refactor: ♻️ extract collector config module from cli (CWPT-142)`.
- Push only when Kevin asks.
- A commit that exists on a remote is permanent: never amend, rebase, squash,
  or force-push it. Fix a pushed mistake with a new commit. Reverting a pushed
  commit needs Kevin's approval.
- After a push, check the remote CI run when the repo has one. A red run is a
  failed check and follows the failure rule under Verification and reporting,
  with the fix going in as a new commit. If the issue was already Done, move
  it back to In Progress and comment with the failing job.

## Dependencies

- Prefer the standard library and dependencies the repo already has.
- A new direct dependency does not need Kevin's approval. It needs to pass
  every vetting check below, with the evidence recorded. Run the checks; do
  not answer them from memory.
  1. Identity: the exact name and publisher match the project's official
     documentation or source repository. A plausible name is not evidence the
     package exists or is the one intended.
  2. Standing: the package was first published more than 90 days ago, has a
     public source repository, and shows recent maintenance.
  3. Release age: the version was published at least 7 days ago. Take the
     newest version that meets this, not the newest version.
  4. Advisories: no known unpatched advisory applies to that version,
     according to the registry's audit command or the OSV database.
  5. License: compatible with the repo.
  6. Install scripts: install with lifecycle scripts disabled where the
     package manager supports it. A package that cannot work without its
     install script fails this check unless the script has been read and does
     only what the package documents; enable scripts for that package alone.
  7. Transitive packages: read the lockfile diff. Checks 3 and 4 apply to
     every package the dependency brings in.
- A repo's AGENTS.md may tighten or loosen these thresholds.
- When a candidate fails a check, do not wait for Kevin. Choose an
  alternative that passes, or implement the piece without a dependency. If
  neither works, finish everything that does not depend on it, leave the
  issue In Progress, and report the failed check.
- The final report lists each new dependency: name, version, publish date,
  what it is for, and the result of each check. Kevin reads this before
  pushing.
- Add and upgrade through the repo's package manager, never by hand-editing a
  lockfile. Commit the manifest and the lockfile together with the code that
  uses them, and follow the repo's pinning convention.
- Upgrade a dependency only when the issue calls for it. Report other
  outdated or vulnerable dependencies as follow-ups.

## Execution

- State the implementation plan, then proceed unless the work is in the Risky
  tier. Name the primary implementer and the concrete risks that need early
  checks in the plan.
- Keep one primary implementer across tasks that share interfaces, files, or
  mutable state. The main session may implement, or it may retain one worker
  across those tasks. Task count alone does not justify fresh implementers or
  additional review stages.
- Delegate bounded independent research or isolated implementation when it
  helps. Give each worker its task, shared interfaces, constraints, and a short
  report contract. Do not dispatch helpers just because agents are available.
  Never parallelize edits that touch the same files or share mutable state.
- Before building around an external API or changing stored data, check the
  risky contract against current primary sources or literal compatibility
  fixtures. Verify expected request fields, schema limits, error signatures,
  and legacy behavior independently of the proposed implementation. A fixture
  that agrees with the implementation can still encode the wrong contract.
- Use an early specialist review for a named risk such as credential handling,
  a provider request contract, or an on-disk format change. Keep it scoped to
  that risk. It does not start a pair of reviews for every task or replace the
  final issue reviews.
- If a context limit requires an implementer handoff, leave a compact record
  of the commit, working-tree state, interfaces, completed work, open findings,
  and check results. Resume from that record; do not repeat completed tasks.
- After implementation and integration with current main, run two reviews of
  the complete issue diff, in order, with separate fresh-context reviewers who
  did not implement the change:
  1. Spec compliance — verify the code, tests, docs, and integrated behavior
     against the issue and approved decisions. Re-derive preservation claims
     and verify external contracts against their sources.
  2. Code quality — only after spec review passes; review the complete branch
     for correctness, security, reliability, and maintainability.
- These are the two formal issue reviews. The quality review is the
  whole-branch review; do not add another generic final review or require
  implementer/spec/quality cycles for each internal task. Reviewers judge the
  code themselves. They may use recorded check results and run focused probes
  for specific gaps; they do not repeat already-recorded suites on unchanged
  code without a concrete reason.
- Reviewers mark each finding blocking (wrong behavior, spec miss, broken
  gate, violated repo constraint) or non-blocking (style, naming, optional
  cleanup). Batch each review's blocking findings into one fix wave for the
  primary implementer. Re-review the fixes and new breakage within the changed
  code; do not restart the whole review. Non-blocking findings are fixed when
  cheap and otherwise listed in the final report.
- The implementer may rebut a finding with evidence from the code or a command
  result. The reviewer then withdraws it or answers the evidence.
- After three fix/re-review rounds in either review stage with blocking
  findings still open, stop and bring the disagreement to Kevin. Do not merge
  with open blocking findings. If a quality fix changes an acceptance rule or
  interface, have the spec reviewer recheck that affected scope.
- An unrelated bug found along the way: if the fix is a few lines, obviously
  correct, and covered by the gates, fix it in its own commit on the branch.
  Otherwise leave the code alone and report it as a follow-up.

## Book lenses

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

## TDD

- Red/green for behavior changes: write or update a focused failing test, watch
  it fail for the right reason, implement the smallest correct fix, then
  refactor with tests green.
- Install network and paid-call guards before the first red run that could
  reach an external service. Use offline fixtures and temporary data. Live
  calls and collected-data changes still require the repo's authorization.
- For deletions, invert the discipline: prove the suite green before and after,
  and show that only the dead path's coverage disappeared.
- For behavior-preserving refactors, prove preservation: capture baseline
  output before touching code (to a scratch file outside the repo) and diff
  after. Byte equality when the contract claims it.
- Test through the interface, not internals. Prefer real implementations with
  injectable seams over broad mocking.
- Test output must be pristine to pass. Expected errors are captured and
  asserted, not left in logs.
- Use mutation checks for the high-risk invariants named in the plan, such as
  cache preservation, credential redaction, retry limits, validation before
  writes, or keeping completed work after failure. Do not require a mutation
  for every new test. Keep red/green coverage for every behavior change.
- For each selected mutation, record the behavior broken, the focused test
  command and its observed failure, then restore the source before continuing.
  Run covering checks after restoration; do not run the full suite per mutant.

## Verification and reporting

- Run the smallest relevant check first, then the repo's required gates (its
  AGENTS.md verification matrix) before handoff. Use the repo's single gate
  command when it has one.
- When the gates do not exercise the change, run it through its real
  entrypoint (the CLI command, the endpoint, the script) and report what
  happened.
- Never claim success without running the checks and reporting actual command
  results. The controller owns one independent final verification pass on the
  clean branch tip after all fixes, integration, and the final amend or squash.
  It runs every repo-required gate itself; a worker's report does not replace
  that pass. Focused implementation checks and early risk probes remain
  required. Do not repeat a successful final pass on unchanged code or after a
  fast-forward merge of that exact commit.
- Save a compact verification receipt outside tracked source and collected
  data. Record the commit, worktree, clean status, and each command's exit
  code, result summary, and raw-log path. For advisory checks, record the
  baseline and final diagnostic counts. Keep credentials out of the receipt
  and logs.
- After compaction or a handoff, confirm the receipt's commit and clean state
  still match and read the saved results. If a result is missing, rerun that
  check. If the code changed or the branch was rebased, rerun the required
  final gates and replace the receipt. Never turn a missing result into a
  passing claim.
- If a check fails, read the output and find the cause. Fix it when the cause
  is inside the issue's scope. Stop and report the output plainly when the
  failure is pre-existing, lies outside the issue's scope, or survives three
  fix attempts. No success language while anything is broken or disabled.
- Keep credentials and local data out of everything: never read, print, or
  commit real tokens; tests use fake values; local config and collected outputs
  are data, not source.
- Status updates distinguish active implementation, review, verification, and
  blocked tool or approval waits. Name the remaining gates and the cause of a
  delay; do not describe a blocked command as ongoing implementation.

## Documentation is required work

- Update docs in the same commit as the change they describe: usage changes go
  to the README, module boundaries and data flow to the architecture doc,
  decisions to a new ADR, testing or verification expectations to AGENTS.md
  (including its verification matrix when a test file is added).
- Quality bar: high signal (why over what), evergreen (no temporal language),
  accurate (docs match code), scoped (one topic per section).

## Handoff checklist

Before finishing, confirm:

- [ ] Changes are scoped to the issue and architecture-aligned.
- [ ] Whole-issue spec and quality reviews passed, with no open blocking
      findings.
- [ ] Tests and checks were run, with results captured in the report.
- [ ] Relevant docs were updated.
- [ ] Tracker updated: final comment posted, state set, only after verification.
- [ ] No credentials, generated artifacts, local data, or unrelated files were
      modified.

## What a repo's AGENTS.md should provide

When bootstrapping a new repo, its AGENTS.md should supply the specifics this
protocol depends on: purpose; core rules; repo-specific Ask First items; a
verification matrix mapping files/areas to exact commands; a single command
that runs every required gate, enforced by a git hook where practical; a
worktree setup command; the package manager and pinning convention; how to
check remote CI, if the repo has any; a repository map; architecture
constraints; a doc update map; and a pointer to `docs/agents/issue-tracker.md`
carrying the tracker's fixed context. The repo's CLAUDE.md should just point at
AGENTS.md.
