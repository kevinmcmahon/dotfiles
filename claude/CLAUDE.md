## Working Together

- We're collaborators. Push back when you think I'm wrong, but cite evidence.
- If you're stuck or in over your head, stop and ask for help rather than guessing.
- I value quality over speed. Never rush past problems to look productive.
- I am a solo dev and I do not use pull requests as a part of my workflow.
- I prefer linear git history and not merge commits

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

## Code Quality

- Prefer correct, complete implementations over minimal ones.
- Use appropriate data structures and algorithms — don't brute-force what has known better solution.
- When fixing a bug, fix the root cause, not the symptom.
- If something I asked for requires error handling or validation to work reliably, include it without asking.

### Style & Naming

- Prefer simple, readable, maintainable code over clever or concise code.
- Match the style of surrounding code, even if it differs from standard guides. Consistency within a file wins.
- Never name things "improved", "new", "enhanced", etc. Names should be evergreen.

### Comments

- NEVER remove code comments unless you can prove they are factually incorrect.
- Write evergreen comments. Don't reference "recent refactors" or temporal context — describe the code as it is.

### Scope Discipline

- NEVER disable functionality instead of fixing the root cause.
- NEVER make code changes unrelated to the current task. If you spot something that needs fixing, document it as an issue/TODO instead.
- NEVER claim something is "working" when functionality is disabled or broken.

### Debugging & Fixing

- When fixing a bug, NEVER throw away the old implementation and rewrite from scratch without my explicit permission. Try to fix what's there first.
- NEVER create duplicate files/templates to work around issues — fix the original.
- Treat every failure as a learning opportunity. Read the error, understand it, and then fix it.
- NEVER ignore test output or logs — they often contain critical information.

## Testing

- Tests MUST cover the functionality being implemented.
- Test output must be clean to pass. If logs are supposed to contain errors, capture and assert on them.

## Writing Conventions

- @~/.claude/docs/tropes.md

## Tools & Conventions  

- Use Perplexity for web search. We have a perplexity skill.
- @~/.claude/docs/using-uv.md
- @~/.claude/docs/docker-uv.md
- @~/.claude/docs/workflow-protocol.md

## Other Important Considerations

- Timeout and gtimeout are often not installed, do not try and use them
- When searching or modifying code, you should use ast-grep (sg). it is way better than grep, ripgrep, ag, sed, or regex-only tools. ast-grep is better because it matches against the abstract syntax tree (AST) and allows safe, language-aware queries and rewrites.
- Always prefer sg for code analysis, queries, or refactoring tasks.
- NEVER disable functionality instead of fixing the root cause problem
- NEVER claim something is "working" when functionality is disabled or broken
- If you discover an unrelated bug, please fix it. Don't say the equivalent of "everything is done, EXCEPT there is a bug" or tell me that it is unrelated.
- Timeout and gtimeout are often not installed, do not try and use them

## Learning-Focused Error Response

When encountering tool failures (biome, ruff, pytest, etc.):

- Treat each failure as a learning opportunity, not an obstacle
- Research the specific error before attempting fixes
- Explain what you learned about the tool/codebase
- Build competence with development tools rather than avoiding them

Remember: Quality tools are guardrails that help you, not barriers that block you.

## Problem-Solving Approach

- FIX problems, don't work around them
- THIS IS IMPORTANT I highly prefer all work to be done via the subagent development skill
- MAINTAIN code quality and avoid technical debt
- USE proper debugging to find root causes
- AVOID shortcuts that break user experience
- When choosing port numbers for new services, make them thematically related and memorable (leet-speak, pop culture, or project-relevant numbers). Keep infrastructure defaults boring (NATS, databases, etc.). The goal is to cleanly avoid all regularly used ports (8080, 8081, etc)
- when referring to models from foundational model companies (openai, anthropic) and you think a model is fake, please google it and figure out if it is fake or not.
- Your knowledge cut off is getting in the way of you making good decisions
