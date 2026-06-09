---
name: issue-prompt
description: Use when Kevin asks for a ready-to-paste implementation prompt for a Linear issue, or asks how to prompt an agent to implement an issue. Builds a prompt from the issue and repo workflow, emphasizing isolated worktrees/branches, red-green TDD, safe subagent parallelism, docs, verification, and final reporting.
---

# Issue Prompt

Create a ready-to-paste implementation prompt for a Linear issue.

Do not implement the issue unless Kevin explicitly asks for implementation.

## Workflow

1. Read the Linear issue. Use the issue text as the source of truth.
2. Read repo-local agent guidance when available, especially `AGENTS.md` and issue tracker docs such as `docs/agents/issue-tracker.md`.
3. Identify the repo's default implementation workflow and make it explicit in the generated prompt.
4. Include issue-specific scope, out-of-scope items, likely files, tests, docs, and verification commands.
5. Keep the prompt ready to paste into a fresh agent session.

## Required Prompt Elements

The generated prompt should tell the implementing agent to:

- Read the Linear issue and repo guidance first.
- Create an isolated branch or git worktree using the Linear `gitBranchName` when available, unless the workspace is already isolated for that issue.
- Use red/green TDD for behavior changes: write or update a focused failing test, run it and confirm the failure, implement the smallest correct fix, then refactor.
- Parallelize independent discovery and review with agents/subagents where available and safe.
- Avoid parallel edits to the same files or work requiring shared mutable state.
- State the implementation plan, then proceed.
- Update relevant docs when behavior, architecture, testing, tooling, or limitations change.
- Run the repo's required verification matrix and report actual command results.
- Keep final output focused on changes, files touched, verification results, and remaining risks or follow-ups.

## Output Shape

Return one fenced `text` block that the user can paste directly.

Use this structure unless the repo guidance clearly calls for something else:

```text
Let's work on ISSUE-ID.

Read the Linear issue and repo guidance first. Follow this repo's issue workflow exactly.

Before changing code:
- Create an isolated branch or git worktree using the issue's Linear gitBranchName, unless this workspace is already isolated for ISSUE-ID.
- Use red/green TDD for behavior changes.
- Parallelize independent discovery/review with agents/subagents where safe.
- State the implementation plan, then proceed.

Goal: ...

Key requirements:
- ...

Out of scope:
- ...

Implementation guidance:
- Likely files: ...
- Tests to add/update: ...
- Docs to update: ...

Verification:
- ...

Final response should include:
- Summary of changes
- Files touched
- Tests/build commands run with results
- Docs updated
- Remaining risks or follow-ups
```

## Style

- Be concrete and concise.
- Prefer repo-specific commands over generic guidance.
- Do not invent issue requirements that are not in Linear or repo docs.
- If the issue is ambiguous, include the ambiguity as a question or assumption in the prompt.
