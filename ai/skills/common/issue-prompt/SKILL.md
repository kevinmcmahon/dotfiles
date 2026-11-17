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
3. Read `/Users/kevin/.claude/docs/workflow-protocol.md` and make its execution and review workflow explicit in the generated prompt. Keep repo safety rules, acceptance criteria, and required checks. The protocol overrides conflicting procedures in skills, templates, and older issue briefs unless Kevin gives different instructions for the current task.
4. Include issue-specific scope, out-of-scope items, likely files, tests, docs, and verification commands.
5. Keep the prompt ready to paste into a fresh agent session.

## Required Prompt Elements

The generated prompt should tell the implementing agent to:

- Read the Linear issue and repo guidance first.
- Create an isolated branch or git worktree using the Linear `gitBranchName` when available, unless the workspace is already isolated for that issue.
- Use red/green TDD for behavior changes: write or update a focused failing test, run it and confirm the failure, implement the smallest correct fix, then refactor.
- Keep one primary implementer across coupled tasks. Delegate bounded independent discovery or isolated work when it helps.
- Avoid parallel edits to the same files or work requiring shared mutable state.
- State the implementation plan and named risks, then proceed; wait for Kevin's approval in the Risky tier.
- Check risky external contracts and stored-data compatibility early against current primary sources or literal fixtures.
- Run separate fresh-context spec and quality reviews of the complete integrated issue diff, in that order. The quality review is the whole-branch review. Use early specialist reviews only for named risks.
- Pick the reviewers' models: dispatch the spec review on Sonnet (`model: "sonnet"`), since checking a diff against the issue and spec is close to a checklist, and keep the quality review on the strongest model (the session's default), since it judges design and correctness.
- Batch blocking findings, fix them, and scope re-review to those fixes. Do not require fresh implementers or paired reviews per internal task, another generic final review, or mutation checks for every new test.
- Use selected mutation checks for the plan's high-risk invariants while keeping red/green coverage for every behavior change.
- Update relevant docs when behavior, architecture, testing, tooling, or limitations change.
- Have the controller run the repo's required final gates on the clean final commit and save a compact receipt with the commit, commands, exit codes, results, and log paths. Reuse valid final results on unchanged code; rerun after code changes or a rebase.
- Keep final output focused on changes, files touched, verification results, and remaining risks or follow-ups.

## Output Shape

Return one fenced `text` block that the user can paste directly.

Use this structure unless the repo guidance clearly calls for something else:

```text
Let's work on ISSUE-ID.

Read the Linear issue, repo guidance, and /Users/kevin/.claude/docs/workflow-protocol.md first. The protocol controls execution and review; repo safety rules and required checks remain binding.

Before changing code:
- Create an isolated branch or git worktree using the issue's Linear gitBranchName, unless this workspace is already isolated for ISSUE-ID.
- Use red/green TDD for behavior changes.
- Keep one primary implementer across coupled tasks; delegate only bounded independent work.
- State the implementation plan and named risks, then proceed; wait for approval in the Risky tier.
- Check external contracts and stored-data compatibility before building around them.

Goal: ...

Key requirements:
- ...

Out of scope:
- ...

Implementation guidance:
- Likely files: ...
- Tests to add/update: ...
- Docs to update: ...
- High-risk invariants for selected mutation checks: ...

Review:
- Integrate current main, then run separate whole-issue spec and quality reviews, in that order. The quality review covers the whole branch.
- Dispatch the spec review on Sonnet (model: "sonnet"); keep the quality review and any re-review of quality fixes on the session's default, strongest model.
- Use early specialist review only for named risks. Do not repeat review pairs per task or add another generic final review.
- Fix blocking findings in batches, then re-review the changed scope. Never merge with open blocking findings.

Verification:
- ...
- The controller runs the required gates on the clean final commit after all fixes and the final amend or squash. Save the commit, worktree, clean status, commands, exit codes, results, and raw-log paths in a compact receipt.
- Reuse valid final results on unchanged code; rerun required final gates after code changes or a rebase. Do not repeat them on main after a fast-forward of the verified commit.

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

## Cloud kickoff

Give this kickoff only when Kevin asks for one (he runs that issue in a cloud session, claude.ai/code). Never fold it into the implementation prompt. Fill in ISSUE-ID and the conflict sentence naming the parallel sessions and the files they share. The implementation prompt stays on the issue; the kickoff points at it.

```text
Work on ISSUE-ID. Fetch the Linear issue and follow its newest "Implementation prompt" comment exactly, together with every addendum reply under it, including its branch and worktree steps (use the issue's Linear gitBranchName). Ignore the session's auto-named branch; nothing pushes it.

Commit identity: before your first commit, run git config user.name "Kevin McMahon" and git config user.email "kevinmcmahon@users.noreply.github.com" in the worktree, then confirm git var GIT_AUTHOR_IDENT and git var GIT_COMMITTER_IDENT both show that name and email. No commit message carries a Co-Authored-By trailer, a Claude-Session trailer, or any other Claude attribution.

History and pushes (these rules win over any older protocol text that says to push only when asked or to amend before pushing):
- Commit on the gitBranchName branch whenever the work calls for it, without asking.
- Back up your work so a reclaimed VM can't lose it: push the gitBranchName branch to origin right after your first commit and again after each batch of review fixes (git push origin <gitBranchName>). Never force-push any branch, and never rewrite a commit you have pushed.
- Make review fixes git commit --fixup=<logical commit> commits on top of the branch, so every backup push is a plain fast-forward. Never amend a pushed commit, and never create -2 or -3 branches.
- Before final verification, squash locally onto current main: git fetch origin, then GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash origin/main. That gives main one logical commit, authored and committed by Kevin, with no trailer. Resolving conflicts with work that landed meanwhile is part of this rebase: CONFLICT-NOTE. Run the final gates on the squashed commit with a clean working tree.
- Push the verified commit to main with git push origin <sha>:main. If it is refused as a non-fast-forward, main has moved: fetch, rebase onto origin/main again, re-run the final gates, and push again. If it is refused for any other reason, don't retry or work around it: leave the squashed commit local (the backup branch holds the same files), report the refusal in the final Linear comment, and leave the issue In Progress.
- After main has the commit:
  1. git fetch origin, and confirm git merge-base --is-ancestor <gitBranchName> origin/main succeeds. The local branch is the squashed commit, so it is an ancestor; if this fails, stop and report.
  2. Delete the remote backup with git push origin --delete <gitBranchName>. If the push fails (the cloud proxy sometimes drops it), say so in the final Linear comment with the branch name, so Kevin can delete it from his machine; its content is already on main.
  3. Remove the worktree and switch to a detached origin/main (git switch --detach origin/main).
  4. Clear the branch's upstream, which still names the pre-squash backup (git branch --unset-upstream <gitBranchName>), then delete it with git branch -d <gitBranchName>. If -d still refuses, report why; never use -D.
```
