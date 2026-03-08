# CLAUDE.md

## Working Together

- We're collaborators. Push back when you think I'm wrong, but cite evidence.
- If you're stuck or in over your head, stop and ask for help rather than guessing.
- I value quality over speed. Never rush past problems to look productive.

## Decision-Making Framework

### 🟢 Do It (no need to ask)
- Fix failing tests, lint errors, type errors
- Implement single functions with clear specs
- Fix typos, formatting, documentation
- Add missing imports or dependencies
- Refactor within a single file for readability

### 🟡 Propose First (tell me what you plan to do, then proceed)
- Changes affecting multiple files or modules
- New features or significant functionality additions
- API or interface changes
- Database schema changes
- Third-party integrations

### 🔴 Always Ask Permission
- Rewriting existing working code from scratch
- Changing core business logic
- Security-related modifications
- Anything that could cause data loss
- Architectural changes

## Code Quality Rules

### Style & Naming
- Prefer simple, readable, maintainable code over clever or concise code.
- Match the style of surrounding code, even if it differs from standard guides. Consistency within a file wins.
- Never name things "improved", "new", "enhanced", etc. Names should be evergreen.

### Comments
- NEVER remove code comments unless you can prove they are factually incorrect.
- Write evergreen comments. Don't reference "recent refactors" or temporal context — describe the code as it is.

### Scope Discipline
- NEVER make code changes unrelated to the current task. If you spot something that needs fixing, document it as an issue/TODO instead.
- NEVER disable functionality instead of fixing the root cause.
- NEVER claim something is "working" when functionality is disabled or broken.

### Debugging & Fixing
- When fixing a bug, NEVER throw away the old implementation and rewrite from scratch without my explicit permission. Try to fix what's there first.
- NEVER create duplicate files/templates to work around issues — fix the original.
- Treat every failure as a learning opportunity. Read the error, understand it, then fix it.
- NEVER ignore test output or logs — they often contain critical information.

## Git Discipline

### Forbidden
- `--no-verify`, `--no-hooks`, `--no-pre-commit-hook` — NEVER use these flags.

### When Pre-Commit Hooks Fail
1. Read and explain the full error output
2. Identify which tool failed and why
3. Explain the fix and why it addresses the root cause
4. Apply the fix and re-run hooks
5. Only commit after all hooks pass
6. If you can't fix the hooks, ask me for help

### Before Any Git Command, Ask Yourself
- "Am I bypassing a safety mechanism?"
- "Am I choosing convenience over quality?"
If yes — stop and talk to me first.

## Testing

- Tests MUST cover the functionality being implemented.
- Test output must be clean to pass. If logs are supposed to contain errors, capture and assert on them.

### TDD Process
1. Write a failing test that defines the desired behavior
2. Run the test — confirm it fails as expected
3. Write the minimum code to make the test pass
4. Run the test — confirm it passes
5. Refactor while keeping tests green
6. Repeat

## Tools & Conventions  
- @~/.claude/docs/python.md
- @~/.claude/docs/using-uv.md
- @~/.claude/docs/docker-uv.md

