# pplx-search — Perplexity CLI for Claude Code

A zero-dependency Perplexity search CLI designed to replace MCP servers in Claude Code workflows. Instead of loading tool schemas into context on every turn, Claude Code reads a SKILL.md only when it actually needs to search.

## Why not MCP?

MCP servers inject tool schemas into Claude Code's system prompt on **every turn**, whether you search or not. That's hundreds of tokens of overhead per message. This approach:

- **CLAUDE.md**: one line (~15 tokens), always in context
- **SKILL.md**: ~400 tokens, loaded only when Claude decides to search
- **CLI output**: only when a search actually runs

On turns where no search happens, you pay essentially nothing.

## Setup

### 1. Get a Perplexity API key

Go to https://www.perplexity.ai/settings/api and create one.

### 2. Copy the skill into your project

```bash
mkdir -p skills/perplexity
cp pplx-search skills/perplexity/
cp SKILL.md skills/perplexity/
chmod +x skills/perplexity/pplx-search
```

Or keep it global:

```bash
mkdir -p ~/.claude/skills/perplexity
cp pplx-search SKILL.md ~/.claude/skills/perplexity/
chmod +x ~/.claude/skills/perplexity/pplx-search
```

### 3. Set your API key

Add to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
export PERPLEXITY_API_KEY="pplx-your-key-here"
```

### 4. Add the one-liner to CLAUDE.md

For a project-local setup:

```markdown
## Skills
- For web search, read `skills/perplexity/SKILL.md` before using `skills/perplexity/pplx-search`.
```

For a global setup:

```markdown
## Skills
- For web search, read `~/.claude/skills/perplexity/SKILL.md` before using `~/.claude/skills/perplexity/pplx-search`.
```

That's it. Claude Code will read the SKILL.md when it decides it needs web search, learn how to use the tool, and call it via bash.

## Usage (manual)

```bash
# Default search (sonar-pro)
./pplx-search "latest changes in React 19"

# Quick lookup (sonar — faster, cheaper)
./pplx-search -m sonar "python 3.13 release date"

# Deep research
./pplx-search --deep "state of WebGPU support across browsers 2025"

# Reasoning mode
./pplx-search --reason "why does Rust need both lifetimes and the borrow checker"

# Pipe in context
cat error.log | ./pplx-search --stdin

# Raw JSON
./pplx-search --json "query"
```

## File structure

```
skills/perplexity/
├── SKILL.md       # Claude Code reads this to learn when/how to search
├── pplx-search    # The actual CLI (zero dependencies, Python 3.12+)
└── README.md      # You're reading it
```

## License

MIT — do whatever you want with it.
