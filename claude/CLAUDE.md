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
- Add missing imports, or declare a dependency the repo already locks
- Refactor within a single file for readability

### 🟡 Propose First (tell me what you plan to do, then proceed)
- Changes affecting multiple files or modules
- New features or significant functionality additions
- API or interface changes
- Database schema changes
- Third-party integrations
- New direct dependencies, after they pass the vetting checks in the workflow protocol

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
- NEVER make cleanup, refactoring, or feature changes unrelated to the current task. Report them as follow-ups instead. Unrelated bugs follow the rule in the workflow protocol.
- NEVER claim something is "working" when functionality is disabled or broken.

### Debugging & Fixing

- When fixing a bug, NEVER throw away the old implementation and rewrite from scratch without my explicit permission. Try to fix what's there first.
- NEVER create duplicate files/templates to work around issues — fix the original.
- Treat every failure as a learning opportunity. Read the error, understand it, and then fix it.
- NEVER ignore test output or logs — they often contain critical information.

## Engineering principles

Distilled from the `book-*` skills. Repo rules and the workflow protocol win where they differ.

- Judge a design by how much a reader must hold in mind to change it safely. Split or merge code by that measure rather than line count, so one deep module with a small interface beats a chain of pass-through functions, wrappers, and layers (Ousterhout over Clean Code's tiny functions; `book-a-philosophy-of-software-design`).
- Pull complexity down into the module that owns it. Accept a harder implementation when it spares callers setup steps, ordering rules, mode flags, or knowledge of storage and formats.
- Give each fact one owner: a rule, mapping, status meaning, schema, or default. When one change needs edits in many places, move that knowledge to its owner before adding more.
- Let code that merely looks alike wait for a third copy, and keep code that changes for different reasons apart even when it matches. Add an abstraction, pattern, or layer only for a need you can name today.
- Make invalid states hard to represent. Use enums for closed sets, small value types for primitives that carry rules, and separate functions instead of boolean mode flags; a function answers a question or changes state, never both.
- Keep each decision in the module that owns the concept. CLI handlers, scripts, SQL, serializers, and vendor adapters translate and route, and core logic never imports them (`book-clean-architecture`).
- Use the project's domain vocabulary with one term per concept, and rename code when understanding improves. Translate foreign payloads, rows, and vendor types at the boundary so they never become the model (`book-domain-modeling`).
- Match model weight to the problem. Simple flows stay plain functions; richer types and boundaries go where invariants, lifecycle, or integration risk demand them (`book-patterns-of-enterprise-application-architecture`).
- Make the change easy, then make the easy change. Refactor only what blocks the current task, as a behavior-preserving step before the behavior change; scope discipline beats the boy-scout rule (`book-refactoring-pass`).
- When current behavior looks wrong but something may depend on it, pin it with a characterization test and report it instead of fixing it in passing (`book-legacy-change`).
- Give every derived copy (cache, index, projection, export) a named source of truth and a rebuild path. Treat stored formats and schemas as contracts with old readers, old writers, and old data (`book-data-systems`).
- Assume crashes, duplicate runs, and unknown success. Make writes and jobs safe to rerun, retry only idempotent operations with a bounded count and backoff, and put an explicit limit on every outbound call, wait, and queue (`book-reliability-review`).
- Validate input at trust boundaries and assert programmer assumptions. Report expected failures plainly and let bugs fail loudly with their context.
- Write comments for what code cannot say: interface contracts, invariants, units, and reasons. If a comment would explain how the code works, improve the names or structure first.
- Measure before optimizing, and hide the optimization behind the interface. When a design is uncertain, get a thin end-to-end slice running before filling in the pieces (`book-the-pragmatic-programmer`).

Each book is a `book-*` skill; load the matching one at the workflow protocol's checkpoints, or whenever a decision above is contested, for the full rules.

## Testing

- Tests MUST cover the functionality being implemented.
- Test output must be clean to pass. If logs are supposed to contain errors, capture and assert on them.

## Writing Conventions

- Before writing any prose humans will read, use the writing-tropes skill.

## Tools & Conventions  

- Use Perplexity for web search. We have a perplexity skill.
- For uv (Python packaging), use the astral:uv skill.
- For Python Dockerfiles, use the docker-uv skill.
- @~/.claude/docs/workflow-protocol.md

## Other Important Considerations

- When searching or modifying code, you should use ast-grep (sg). it is way better than grep, ripgrep, ag, sed, or regex-only tools. ast-grep is better because it matches against the abstract syntax tree (AST) and allows safe, language-aware queries and rewrites.
- Always prefer sg for code analysis, queries, or refactoring tasks.
- If you discover an unrelated bug, fix it in its own commit when the fix is a few lines, obviously correct, and covered by the gates. Otherwise report it as a follow-up with enough detail to act on. Don't say the equivalent of "everything is done, EXCEPT there is a bug" and leave it there.

## Learning-Focused Error Response

When encountering tool failures (biome, ruff, pytest, etc.):

- Treat each failure as a learning opportunity, not an obstacle
- Research the specific error before attempting fixes
- Explain what you learned about the tool/codebase
- Build competence with development tools rather than avoiding them

Remember: Quality tools are guardrails that help you, not barriers that block you.

## Problem-Solving Approach

- FIX problems, don't work around them
- THIS IS IMPORTANT I highly prefer the subagent development skill for multi-task plans and long runs, and fresh-context subagents for every review. The main session implements single-task changes when it already holds the context (see the workflow protocol).
- MAINTAIN code quality and avoid technical debt
- USE proper debugging to find root causes
- AVOID shortcuts that break user experience
- When choosing port numbers for new services, make them thematically related and memorable (leet-speak, pop culture, or project-relevant numbers). Keep infrastructure defaults boring (NATS, databases, etc.). The goal is to cleanly avoid all regularly used ports (8080, 8081, etc)
- when referring to models from foundational model companies (openai, anthropic) and you think a model is fake, please google it and figure out if it is fake or not.
- Your knowledge cut off is getting in the way of you making good decisions
