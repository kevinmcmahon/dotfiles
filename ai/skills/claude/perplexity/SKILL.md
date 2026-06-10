---
name: perplexity
description: Use when you need to search the web for current information, verify facts, or look up recent documentation using the pplx-search tool
---

# Perplexity Web Search

## When to Use

Use `pplx-search` when you need information that:
- Is more recent than your training data (current docs, releases, changelogs)
- Requires verifying a fact you're uncertain about
- Involves library APIs, framework versions, or compatibility you can't confirm
- Needs real-world context (benchmarks, community consensus, best practices in flux)

**Don't use it for:** things you already know confidently, general programming concepts, or questions answerable from the codebase itself.

## Quick Reference

Resolve the CLI before running searches:

```bash
PPLX="${PPLX_SEARCH_BIN:-$HOME/.local/bin/pplx-search}"
if [ ! -x "$PPLX" ]; then PPLX="$HOME/.claude/skills/perplexity/pplx-search"; fi
if [ ! -x "$PPLX" ]; then PPLX="$HOME/dotfiles/ai/skills/claude/perplexity/pplx-search"; fi
```

Prefer `"$PPLX"` over bare `pplx-search` because agent shells can start with a minimal PATH.

```bash
# Standard search (sonar-pro) — good default for most lookups
"$PPLX" "your query here"

# Fast search (sonar) — quick facts, simple lookups
"$PPLX" -m sonar "is Python 3.13 stable yet"

# Deep research — thorough multi-step investigation
"$PPLX" --deep "comprehensive comparison of Bun vs Deno vs Node in 2025"

# Reasoning — analytical or complex technical questions
"$PPLX" --reason "tradeoffs of ECS vs OOP for game engine architecture"

# Pipe context in
echo "explain this error: $ERROR_MSG" | "$PPLX" --stdin

# Raw JSON output (if you need to parse programmatically)
"$PPLX" --json "query"

# Local setup check, no API request
"$PPLX" --health
```

## Writing Good Queries

Short, specific queries get the best results. Include version numbers, language names, and framework names when relevant.

| Bad | Good |
|---|---|
| "how to do auth" | "NextJS 15 app router authentication with Auth.js" |
| "rust error" | "rust borrow checker error returning reference to local variable" |
| "is this deprecated" | "is React.createClass deprecated in React 19" |

## Output Format

The tool returns markdown with:
1. **Answer** — the main response text
2. **Sources** — numbered URLs at the bottom
3. **Token usage** — input/output token count (for cost awareness)

## Models

| Flag | Model | Use When |
|---|---|---|
| _(default)_ | `sonar-pro` | General searches, docs, how-tos |
| `-m sonar` | `sonar` | Quick facts, simple yes/no, fast lookups |
| `--deep` | `sonar-deep-research` | Thorough comparisons, research-grade answers |
| `--reason` | `sonar-reasoning-pro` | Complex analysis, architecture decisions, "why" questions |

Default is `sonar-pro` which balances speed and quality well.

## Setup

1. Get an API key from https://www.perplexity.ai/settings/api
2. Export it: `export PERPLEXITY_API_KEY="pplx-..."`
3. Add `tools/perplexity/` to your PATH or call it directly as `./tools/perplexity/pplx-search`

No pip install. No dependencies. Just Python 3.9+.

## Cost Awareness

Perplexity API is pay-per-use. Approximate costs:
- **Sonar**: $1 / 1M tokens (cheapest)
- **Sonar Pro**: $3 / 1M input, $15 / 1M output
- **Deep Research**: higher — use sparingly for genuinely complex research

The token count in the output footer helps you track spend. Prefer `sonar` for quick checks and `sonar-pro` as your default. Reserve `--deep` for when you really need it.
