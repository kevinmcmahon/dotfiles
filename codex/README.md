# Codex Configuration

OpenAI Codex is managed as a first-class AI peer using Codex-native surfaces: global instructions, config templates, MCP servers, and exec rules.

## Structure

```text
codex/
├── AGENTS.md                  # Global instructions -> ~/.codex/AGENTS.md
├── config.toml.template       # Safe defaults copied to ~/.codex/config.toml when missing
├── hooks.json.template        # Safe hook defaults copied to ~/.codex/hooks.json when missing
├── hooks/
│   └── ntfy-notify.sh         # Symlink to ai/scripts/codex/ntfy-notify.sh
├── rules/
│   └── default.rules.template # Safe exec rules copied to ~/.codex/rules/default.rules when missing
└── README.md
```

## Managed State

Bootstrap links `codex/AGENTS.md` to `~/.codex/AGENTS.md` and `codex/hooks/ntfy-notify.sh` to `~/.codex/hooks/ntfy-notify.sh`. It copies `config.toml.template`, `hooks.json.template`, and `rules/default.rules.template` only when the live files are missing.

`codex/hooks/` is the Codex-facing hook install surface. Hook implementations that are shared by the AI tooling layout live under `ai/scripts/codex/`; `codex/hooks/ntfy-notify.sh` points there, matching the Claude Code `claude/hooks/` to `ai/scripts/claude/` pattern.

Codex hooks are managed separately from Claude Code hooks. Do not install `claude-mem` or other Claude-only lifecycle hooks into Codex; Codex should only load Codex-owned hooks or plugin hooks that are intentionally enabled for Codex.

Codex-owned skill state under `~/.codex/skills` remains local. Dotfiles do not inject skills into that directory or treat it as a symlink target.

Codex user skills live in `~/.agents/skills`. Dotfiles-owned Codex skills are symlinked there from `ai/skills/{common,codex}` by `scripts/ai-sync.sh`. Third-party skills for Codex, Claude Code, and OpenCode are declared in `ai/skills-manifest.toml` and installed by `scripts/install-ai-skills.sh` via `npx skills`. OpenCode skills use the same local-directory pattern at `~/.opencode/skills`.

Home-grown skills are inventoried in `ai/homegrown-skills.md`. Packageable candidates should move to a separate skills repository before they become `npx skills` installs.

`~/.agents/.skill-lock.json` is local package-manager state and should not be committed.

## Local-Only State

Do not commit Codex auth, sessions, logs, cache data, project trust entries, marketplace timestamps, generated plugin state, or app state. Those belong under `~/.codex` on the local machine.

If you need to change global Codex defaults, edit `config.toml.template` for portable defaults and then apply the same change manually to any existing live `~/.codex/config.toml`.
