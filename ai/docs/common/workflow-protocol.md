# Workflow Protocol

How agents run a unit of work for Kevin, from issue to merged commit. This file
is the cross-project default. A repo's `AGENTS.md` (and its `docs/agents/*.md`)
is the source of truth for repo specifics — commands, verification matrix,
constraints, tracker context — and overrides this file where they conflict.
Read the repo's `AGENTS.md` before planning or changing code.

Skills (TDD, worktrees, review, branch finishing) supply technique. Where a
skill's procedure conflicts with this file, this file wins: no PRs, no merge
commits, no push without being asked.

## The shape of a unit of work

Issue -> isolated worktree -> baseline gates -> red/green TDD -> two-stage
review -> verify -> fast-forward merge -> tracker closeout. One issue per
session. One logical commit per issue when feasible.

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
  code. The issue (and its agent brief, if present) is the contract.
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

- Create an isolated branch or git worktree before changing code, unless the
  workspace is already isolated for that issue. Use the tracker's
  `gitBranchName` when available.
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
  before the baseline.
- Run the gates in the fresh worktree before changing anything and record the
  result. A failure here is pre-existing: report it to Kevin before building on
  top of it.
- Linear history only: fast-forward merges, no merge commits, no PRs. While the
  branch is unpushed, amend or squash review fixes into the logical commit they
  belong to.
- Verify the gates on the branch tip, after the final amend or squash and with
  a clean working tree, then fast-forward main to it. A fast-forward makes main
  the exact commit you verified, so don't re-run the gates on main. If main has
  moved, rebase the branch and re-verify before the fast-forward.
- After the merge is confirmed on main, remove the worktree and delete the
  branch with `git branch -d`. A refusal means the branch is not merged; find
  out why instead of forcing the delete.
- Commit messages: gitmoji conventional commits including the issue id, e.g.
  `refactor: ♻️ extract collector config module from cli (CWPT-142)`.
- Push only when Kevin asks.

## Execution

- State the implementation plan, then proceed unless the work is in the Risky
  tier.
- The main session implements when it already holds the context and the change
  is a single task. Delegate to a fresh implementer subagent when the plan has
  several independent tasks or the run is long enough to exhaust the main
  session's context. The implementer receives the full task text and curated
  context (not a pointer to go find it), implements with TDD, self-reviews,
  commits, and reports status with actual command results. An implementer that
  lacks context reports what is missing instead of guessing.
- Two-stage review after implementation, each by a fresh-context reviewer, in
  order:
  1. Spec compliance — did it build exactly what was asked, nothing more,
     nothing less. The reviewer verifies against the code and the diff, never
     against the implementer's report. Behavior-preservation claims get
     re-derived (run the old expression, diff the outputs).
  2. Code quality — only after spec review passes.
- Reviewers mark each finding blocking (wrong behavior, spec miss, broken
  gate, violated repo constraint) or non-blocking (style, naming, optional
  cleanup). Blocking findings go back to whoever implemented; re-review after
  fixes. Non-blocking findings are fixed when cheap and otherwise listed in the
  final report.
- The implementer may rebut a finding with evidence from the code or a command
  result. The reviewer then withdraws it or answers the evidence.
- After three review rounds with blocking findings still open, stop and bring
  the disagreement to Kevin. Do not merge with open blocking findings.
- Parallelize independent discovery, review, test analysis, and documentation
  reads. Never parallelize edits that touch the same files or share mutable
  state.
- An unrelated bug found along the way: if the fix is a few lines, obviously
  correct, and covered by the gates, fix it in its own commit on the branch.
  Otherwise leave the code alone and report it as a follow-up.

## TDD

- Red/green for behavior changes: write or update a focused failing test, watch
  it fail for the right reason, implement the smallest correct fix, then
  refactor with tests green.
- For deletions, invert the discipline: prove the suite green before and after,
  and show that only the dead path's coverage disappeared.
- For behavior-preserving refactors, prove preservation: capture baseline
  output before touching code (to a scratch file outside the repo) and diff
  after. Byte equality when the contract claims it.
- Test through the interface, not internals. Prefer real implementations with
  injectable seams over broad mocking.
- Test output must be pristine to pass. Expected errors are captured and
  asserted, not left in logs.

## Verification and reporting

- Run the smallest relevant check first, then the repo's required gates (its
  AGENTS.md verification matrix) before handoff. Use the repo's single gate
  command when it has one.
- When the gates do not exercise the change, run it through its real
  entrypoint (the CLI command, the endpoint, the script) and report what
  happened.
- Never claim success without running the checks and reporting actual command
  results. Subagent reports are claims, not evidence: re-run the gates in the
  main session before merging.
- If a check fails, read the output and find the cause. Fix it when the cause
  is inside the issue's scope. Stop and report the output plainly when the
  failure is pre-existing, lies outside the issue's scope, or survives three
  fix attempts. No success language while anything is broken or disabled.
- Keep credentials and local data out of everything: never read, print, or
  commit real tokens; tests use fake values; local config and collected outputs
  are data, not source.

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
worktree setup command; a repository map; architecture constraints; a doc
update map; and a pointer to `docs/agents/issue-tracker.md` carrying the
tracker's fixed context. The repo's CLAUDE.md should just point at AGENTS.md.
