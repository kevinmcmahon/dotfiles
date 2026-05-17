---
name: perplexity
description: Use when the user wants current information, recent documentation, fact verification, changelogs, release status, or source-backed web research via Perplexity.
---

# Perplexity

Use this skill only for information that is time-sensitive, uncertain, or requires external source verification.

Do not use it for:
- questions answerable from the local codebase
- stable general knowledge
- tasks that do not need web research

## Tool

Resolve the CLI in this order:

1. `$PPLX_SEARCH_BIN` if set
2. `pplx-search` from `PATH`
3. `~/.agents/skills/perplexity/pplx-search`
4. `/home/mrrobot/dotfiles/ai/skills/codex/perplexity/pplx-search`

Before the first real query in a session, prefer a quick health check if setup is uncertain:

```bash
pplx-search --health
```

Use one of the resolved commands above. Example:

```bash
/home/mrrobot/dotfiles/ai/skills/codex/perplexity/pplx-search "query"
```

Models:
- `-m sonar`: quick factual checks
- default (`sonar-pro`): normal research
- `--reason`: analytical questions and comparisons
- `--deep`: broad, multi-source research only when necessary

## Query Writing

Write short, specific queries with product names, versions, and dates.

Prefer queries that ask for:
- official docs, repos, changelogs, release notes, or maintainer comments
- concrete dates for changes, deprecations, and support status
- explicit separation of confirmed facts from inference

Examples:

```bash
/home/mrrobot/dotfiles/ai/skills/codex/perplexity/pplx-search "OpenClaw memory-core vs claude-mem April 2026 official docs issues changelog"
/home/mrrobot/dotfiles/ai/skills/codex/perplexity/pplx-search --reason "Does current OpenClaw memory search require memory-core runtime contract"
/home/mrrobot/dotfiles/ai/skills/codex/perplexity/pplx-search -m sonar "latest Bun release date"
```

Useful templates:

```bash
# Release / changelog lookup
pplx-search "latest <product> release changelog <month year> official"

# Is X still supported?
pplx-search --reason "Is <feature/plugin/product> still supported as of <month year>? Prefer official docs, changelogs, issues, maintainer comments"

# Comparison with current state
pplx-search --deep "<product A> vs <product B> <year> official docs benchmarks maintainer guidance"

# Maintainer-intent / architecture drift
pplx-search --reason "<project> <feature> architecture changes issue discussion changelog maintainer comments"
```

## Output Handling

When using results:
- prefer primary sources
- prefer official docs, repos, changelogs, release notes, and maintainer comments over blogs
- separate confirmed facts from inference
- preserve concrete dates when the answer depends on recency
- include source links in the final answer
- keep synthesis concise unless the user asks for depth

If the first search is weak:
- reformulate once with tighter nouns, versions, and dates
- switch to `--reason` for analytical questions
- switch to `--deep` only when breadth is genuinely needed

If setup fails:
- run `pplx-search --health`
- check `PERPLEXITY_API_KEY`
- check whether network access is available
