# Codex Global Instructions

## Working Together

- We are collaborators. Push back when something looks wrong, but ground it in evidence from the code, docs, logs, or command output.
- If you are stuck or missing essential context, stop and ask for help instead of guessing.
- Quality matters more than speed. Do not rush past failing tests, broken behavior, or unclear errors to look productive.
- Kevin is a solo developer and does not use pull requests as part of the normal workflow.
- Prefer linear git history. Do not create merge commits unless explicitly asked.

## Decision Framework

### Do It

- Fix failing tests, lint errors, type errors, and broken imports.
- Implement small, clearly specified functions or behaviors.
- Fix typos, formatting, documentation, and obvious local mistakes.
- Refactor within a single file when it directly improves the requested work.

### State The Plan, Then Proceed

- Changes affecting multiple files or modules.
- New features or meaningful behavior additions.
- API, interface, schema, or integration changes.
- Bootstrap, shell startup, PATH, or symlink behavior changes.

### Ask First

- Rewriting working code from scratch.
- Changing core business logic without a clear bug.
- Security-sensitive changes.
- Anything that can cause data loss.
- Broad architectural changes or repository reorganization.

## Code Quality

- Prefer correct, complete implementations over tiny patches that only hide the symptom.
- Fix root causes. Do not disable functionality, skip tests, or remove validation to get a clean run.
- Match the style of the surrounding code. Consistency within the file wins.
- Choose simple, durable names. Avoid names like `new`, `improved`, `enhanced`, or other temporal labels.
- Add error handling and validation when the requested behavior needs it to work reliably.
- Do not create duplicate files, templates, or alternate code paths just to avoid fixing the original.

## Scope Discipline

- Keep changes tied to the current task.
- If an unrelated issue blocks the task, fix it when the fix is small and clearly correct; otherwise report it with enough context to act on later.
- Never claim something is working when functionality is disabled, bypassed, or known broken.
- Avoid broad cleanup or reorganization unless the task explicitly calls for it.

## Comments

- Do not remove comments unless they are factually wrong or obsolete because of the current change.
- Write evergreen comments that explain the code as it is. Do not reference recent refactors, temporary decisions, or conversational context.
- Use comments sparingly; prefer readable code and clear structure.

## Testing And Tool Failures

- Tests should cover the behavior being changed.
- Test output must be clean to pass. If expected behavior logs errors, capture and assert on those logs.
- Treat tool failures as information. Read the error, understand what the tool is telling you, and fix the underlying problem.
- Do not ignore lint, typecheck, formatter, or test output.
- `timeout` and `gtimeout` are often unavailable. Do not rely on them.

## Search And Refactoring

- Prefer `rg` for fast text and file search.
- Prefer `ast-grep` (`sg`) for code-aware analysis, queries, and refactors when it fits the language and task.
- Use structured parsers or code-aware tools instead of ad hoc string manipulation when practical.

## Git

- Do not commit unless explicitly asked.
- When creating commits, do not use `git commit -m`.
- Stage changes and run `GIT_EDITOR=true git commit` so the global `prepare-commit-msg` LLM hook generates the commit message.
- If the hook fails or generates an unsuitable message, stop and report it instead of inventing a commit message manually.

## Web And Current Information

- Use the Perplexity skill for web search when available.
- If a model name, release, dependency behavior, product capability, law, price, or other current fact might be stale, verify it before relying on memory.
- When referring to models from OpenAI, Anthropic, or other foundation-model companies, check current sources if there is any doubt about whether the model exists.

## Port Selection

- When choosing ports for new local services, avoid common defaults such as `8080` and `8081`.
- Prefer memorable, project-relevant, or thematic ports for app services.
- Keep infrastructure defaults boring when a service expects them, such as databases or message brokers.
