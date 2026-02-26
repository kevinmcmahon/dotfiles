# Claude Code Configuration

Global Claude Code settings, hooks, commands, skills, and context docs.

---

## Structure

```
claude/
├── CLAUDE.md                  # Global instructions → ~/.claude/CLAUDE.md
├── settings.json              # Global settings → ~/.claude/settings.json
├── mcp.json.example           # MCP server config template
├── hooks/
│   ├── ntfy-notify.sh         # Push notifications via ntfy.sh (symlink → ai/)
│   ├── block-git.sh           # Block Claude from running git commit/push (symlink → ai/)
│   └── fix-worktree-hooks.sh  # Restore global git hooks in worktrees
├── commands/                  # Slash commands (symlinks → ai/commands/)
│   ├── brainstorm.md
│   ├── careful-review.md
│   ├── code-review.md
│   ├── do-issues.md
│   ├── do-todo.md
│   ├── find-missing-tests.md
│   ├── gh-issue.md
│   ├── make-github-issues.md
│   ├── plan.md / plan-gh.md / plan-tdd.md
│   ├── security-review.md
│   ├── session-summary.md
│   └── setup.md
├── skills/
│   └── perplexity/            # Perplexity web search skill (symlink → ai/)
└── docs/                      # Context docs loaded via @-references in CLAUDE.md
    ├── python.md              # Python conventions (symlink → ai/)
    ├── using-uv.md            # uv package manager guide (symlink → ai/)
    ├── docker-uv.md           # Multistage Docker + uv (symlink → ai/)
    └── perplexity.md          # Perplexity search docs (symlink → ai/)
```

Most files are symlinks into `~/dotfiles/ai/` — the shared source for AI tool configs across editors (Claude Code, Cursor, etc.). Files owned exclusively by Claude Code live here directly.

---

## Settings (`settings.json`)

| Key | Value | Purpose |
|-----|-------|---------|
| `model` | `opus` | Default model |
| `alwaysThinkingEnabled` | `true` | Extended thinking on by default |
| `skipDangerousModePermissionPrompt` | `true` | Skip dangerous mode confirmation |
| `enableAllProjectMcpServers` | `true` | Auto-enable project MCP servers |

### Permissions

Pre-approved tool patterns (no confirmation needed):

- `Bash(ls:*)` — directory listing
- `Bash(ripgrep:*)` — code search
- `Bash(grep:*)` — content search

---

## Hooks

### Notifications (`ntfy-notify.sh`)

Push notifications via [ntfy.sh](https://ntfy.sh) for long-running sessions. Requires `NTFY_TOPIC` env var; exits silently if unset.

| Event | Hook Type | Trigger |
|-------|-----------|---------|
| Permission prompt | Notification | `permission_prompt` |
| Idle prompt | Notification | `idle_prompt` |
| Question asked | PreToolUse | `AskUserQuestion` |
| Task complete | Stop | (all) |

### Git Command Blocking (`block-git.sh`)

Prevents Claude from running `git commit` or `git push` directly — only humans should make commits. Triggers on every `Bash` tool call and exits with code 2 (blocking) if the command matches.

```json
{
  "PreToolUse": [{
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "command": "~/.claude/hooks/block-git.sh"
    }]
  }]
}
```

### Worktree Fix (`fix-worktree-hooks.sh`)

**Problem**: Claude Code's `EnterWorktree` sets a local `core.hooksPath` that shadows the global `~/.git-core/hooks/` setting from `git/`. This breaks LLM-assisted commit messages and git-secrets scanning.

**Fix**: PostToolUse hook on `EnterWorktree` that runs `git config --local --unset core.hooksPath`.

```json
{
  "PostToolUse": [{
    "matcher": "EnterWorktree",
    "hooks": [{
      "type": "command",
      "command": "~/.claude/hooks/fix-worktree-hooks.sh"
    }]
  }]
}
```

### Interaction with `git/` hooks

The global git config sets `core.hooksPath = ~/.git-core/hooks` (managed by `git/git-core.symlink/`). Claude Code hooks here ensure that path is never overridden in worktrees. See `git/README.md` for details on the git hooks themselves.

---

## Commands

Slash commands available as `/command-name` in Claude Code sessions. All symlinked from `ai/commands/`:

| Command | Purpose |
|---------|---------|
| `/brainstorm` | Interactive Q&A to develop a spec |
| `/plan` | Step-by-step implementation blueprint |
| `/plan-tdd` | TDD-flavored planning |
| `/plan-gh` | Planning with GitHub issue integration |
| `/do-todo` | Work through `todo.md` checklist |
| `/do-issues` | Pick and complete a GitHub issue |
| `/gh-issue` | Open and work a specific GitHub issue |
| `/code-review` | Review code for quality issues |
| `/careful-review` | Deep review of recently written code |
| `/security-review` | Security-focused code review |
| `/find-missing-tests` | Identify untested code paths |
| `/make-github-issues` | Generate GitHub issues from code review |
| `/session-summary` | Summarize the current session to a file |
| `/setup` | Initialize CLAUDE.md for a project |

---

## Context Docs

Referenced in `CLAUDE.md` via `@~/.claude/docs/filename.md`. These are injected into every Claude Code session as background context:

- **python.md** — Python 3.11+ conventions, ruff, mypy, type hints
- **using-uv.md** — uv package manager field manual
- **docker-uv.md** — Multistage Dockerfile patterns with uv

---

## Plugins

Enabled in `settings.json`:

| Plugin | Status |
|--------|--------|
| `frontend-design` | Enabled |
| `feature-dev` | Enabled |
| `playwright` | Enabled |
| `claude-mem` | Enabled |
| `context7` | Disabled |

---

## Troubleshooting

### Git hooks not running in worktrees

```bash
# Check what hooksPath is set
git config core.hooksPath
# Should be ~/.git-core/hooks, NOT .git/hooks

# If wrong, unset the local override
git config --local --unset core.hooksPath
```

### Notifications not arriving

```bash
# Check NTFY_TOPIC is set
echo $NTFY_TOPIC

# Test manually
curl -d "test" "https://ntfy.sh/$NTFY_TOPIC"
```
