# Workflow Protocol

How agents run a unit of work for Kevin, from issue to merged commit. This file
is the cross-project default. A repo's `AGENTS.md` (and its `docs/agents/*.md`)
is the source of truth for repo specifics — commands, verification matrix,
constraints, tracker context — and overrides this file where they conflict.
Read the repo's `AGENTS.md` before planning or changing code.

## The shape of a unit of work

Issue -> isolated worktree -> red/green TDD -> two-stage review -> verify ->
fast-forward merge -> tracker closeout. One issue at a time. One logical commit
per issue when feasible.

## Issue tracker

- "work on ABC-123" means: fetch that exact issue before planning or changing
  code. The issue (and its agent brief, if present) is the contract.
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
- Place worktrees under `.worktrees/<issue-id>` in the repo root by default,
  not as peer directories next to the repo. Check for an existing `.worktrees/`
  convention or repo-specific guidance before choosing a different location.
- Worktree tooling may branch from origin's default branch. If local main is
  ahead of origin (unpushed work), fast-forward the new branch to local main
  before starting, or the baseline silently misses prior work.
- Linear history only: fast-forward merges, no merge commits, no PRs. While the
  branch is unpushed, amend or squash review fixes into the logical commit they
  belong to.
- Verify the gates on the branch, merge to main, then re-run the gates on main.
- After the merge is confirmed on main, remove the worktree and delete the
  branch.
- Commit messages: gitmoji conventional commits including the issue id, e.g.
  `refactor: ♻️ extract collector config module from cli (CWPT-142)`.
- Push only when Kevin asks.

## Execution

- Prefer subagent-driven development. A fresh implementer subagent receives the
  full task text and curated context (not a pointer to go find it), asks
  questions before starting, implements with TDD, self-reviews, commits, and
  reports status with actual command results.
- Two-stage review after implementation, in order:
  1. Spec compliance — did it build exactly what was asked, nothing more,
     nothing less. The reviewer verifies against the code and the diff, never
     against the implementer's report. Behavior-preservation claims get
     re-derived (run the old expression, diff the outputs).
  2. Code quality — only after spec review passes.
- Reviewer findings go back to the same implementer; re-review after fixes.
  Repeat until approved. Do not proceed with open findings.
- Parallelize independent discovery, review, test analysis, and documentation
  reads. Never parallelize edits that touch the same files or share mutable
  state.
- State the implementation plan, then proceed unless the change falls under the
  Ask First rules in global CLAUDE.md or the repo's AGENTS.md.

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
  AGENTS.md verification matrix) before handoff.
- Never claim success without running the checks and reporting actual command
  results. Subagent reports are claims, not evidence: re-run the gates in the
  main session before merging.
- If a check fails, report the output plainly and stop. No success language
  while anything is broken or disabled.
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

- [ ] Changes are minimal and architecture-aligned.
- [ ] Tests and checks were run, with results captured in the report.
- [ ] Relevant docs were updated.
- [ ] Tracker updated: final comment posted, state set, only after verification.
- [ ] No credentials, generated artifacts, local data, or unrelated files were
      modified.

## What a repo's AGENTS.md should provide

When bootstrapping a new repo, its AGENTS.md should supply the specifics this
protocol depends on: purpose; core rules; repo-specific Ask First items; a
verification matrix mapping files/areas to exact commands; a repository map;
architecture constraints; a doc update map; and a pointer to
`docs/agents/issue-tracker.md` carrying the tracker's fixed context. The repo's
CLAUDE.md should just point at AGENTS.md.
