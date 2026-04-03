# AGENTS.md

This repository contains Kevin's personal dotfiles, environment bootstrap/setup, terminal/editor configuration, shell environment, and AI tooling configuration.

The goal is a modular, symlink-friendly, terminal-first setup that is safe to evolve incrementally. Preserve structure, avoid surprise breakage, and favor small, explicit changes over broad cleanup or reorganization.

## Core principles

- Preserve modularity.
- Prefer small, targeted diffs.
- Keep platform boundaries clean.
- Respect symlink-based installation patterns.
- Protect shell startup speed and predictability.
- Favor explicit, maintainable solutions over cleverness.
- Do not reorganize the repo unless the task explicitly requires it.

## Environment assumptions

- Primary local environment is macOS.
- Primary shell is Zsh.
- Primary editor is Neovim.
- Terminal setup is Ghostty/Cmux-oriented.
- Linux usage is primarily remote, headless, and accessed over SSH/tmux.
- Do not assume Linux desktop GUI tools, clipboard daemons, display servers, or desktop keyrings on remote systems.

## Active core areas

These are the main areas agents should prefer to work in when relevant:

- `zsh/`
- `nvim/`
- `ghostty/`
- `starship/`
- `tmux/`
- `git/`
- `scripts/`
- `osx/`
- `docs/`

## Secondary or legacy/reference areas

These may still matter, but should not be changed casually:

- `bash/`
- `kitty/`
- `iterm2/`
- `helix/`
- `vscode/`
- `archive/`

Treat these as reference, compatibility, or historical areas unless the task explicitly targets them.

## Stateful or generated tooling areas

These contain agent/tool state, caches, sessions, generated data, or local working artifacts. Do not clean up, normalize, or refactor them unless the task explicitly targets them.

- `claude/`
- `codex/`
- `gemini/`
- `goose/`
- `.git/`
- `kitty/themes/`

Also avoid incidental edits to files like:

- `output.txt`
- `zsh/output.txt`
- sqlite databases
- log files
- cached evaluation/session files
- session transcripts
- generated JSON/JSONL state

## Repo domain boundaries

Treat these top-level directories as separate domains with clear responsibilities:

- `zsh/` — shell startup, environment layering, functions, completions
- `nvim/` — Neovim config
- `ghostty/` — active terminal config
- `tmux/` — tmux config and helpers
- `starship/` — prompt config and helper scripts
- `git/` — git config, hooks, templates, secret patterns
- `scripts/` — reusable bootstrap/setup/audit/utility scripts
- `scripts/lib/` — shared shell library code for scripts
- `osx/` — macOS-specific setup and defaults
- `docs/` — setup and operational documentation
- `ai/`, `claude/`, `codex/`, `opencode/`, `cursor/`, `gemini/`, `goose/`, `llm/` — AI tooling, prompts, skills, templates, state, and integration assets

Do not blur these boundaries without a good reason.

## Symlink conventions

Symlink-oriented installation is part of the design.

- Files ending in `*.symlink` are part of the install contract.
- Do not casually rename, relocate, flatten, or replace `*.symlink` files.
- Do not convert symlink-managed files into copied files.
- Any change affecting symlink targets or bootstrap expectations should be called out explicitly.

## Zsh architecture rules

`zsh/` is a deliberate layered system. Preserve it.

### Existing layout

- `zsh/zshrc.symlink`
- `zsh/zprofile.symlink`
- `zsh/zshenv.symlink`
- `zsh/env/core/`
- `zsh/env/platform/`
- `zsh/env/tools/`
- `zsh/env/optional/`
- `zsh/functions/`
- `zsh/completions/`

### Rules

- Shared foundational shell behavior belongs in `zsh/env/core/`.
- Platform-specific behavior belongs in `zsh/env/platform/`.
- Tool/runtime initialization belongs in `zsh/env/tools/`.
- Optional, local, or private overlays belong in `zsh/env/optional/`.
- Reusable shell commands belong in `zsh/functions/`.
- Zsh completions belong in `zsh/completions/`.
- Do not collapse this structure into a monolithic `.zshrc`.
- Do not stuff new logic into top-level entry files when there is already a more appropriate layer.

## Shell startup and performance

Shell startup is a first-class concern.

- Avoid expensive subprocesses in startup paths unless necessary.
- Avoid duplicate initialization across `zshenv`, `zprofile`, `zshrc`, and layered env files.
- Preserve ordering unless there is a clear bug.
- Favor conditional or lazy loading where appropriate.
- Any shell change should be safe for interactive shell use, SSH use, and non-interactive use unless explicitly intended otherwise.

Be especially careful with:

- PATH construction
- prompt initialization
- runtime manager initialization
- completion loading
- shell hook registration

## PATH and toolchain philosophy

This repo has a clear tooling bias. Follow it.

- `~/.local/bin` is the canonical user-level bin directory.
- Prefer user-scoped installs over system-wide installs.
- Avoid unnecessary global installs.
- Minimize Homebrew for language runtimes when a better language-native option exists.

Preferred managers:

- Python: `uv`
- Node.js: `fnm`
- Rust: `rustup`
- Ruby: `chruby`

Do not introduce competing runtime managers casually.

## Functions, aliases, and completions

### Functions

- Put reusable shell behavior in `zsh/functions/`.
- Prefer functions over aliases for anything non-trivial.
- Keep functions understandable and inspectable.
- Do not hide meaningful logic in opaque one-liners.

### Aliases

- Keep aliases simple.
- If an alias grows logic, turn it into a function.

### Completions

- Keep zsh completions in `zsh/completions/`.
- Do not inline large completion logic into shell init files.

## Scripts and shared script library

`scripts/` is for reusable operational logic, not random scratch work.

- Prefer reusable scripts under `scripts/`.
- Shared helpers belong in `scripts/lib/`.
- Reuse existing helpers in:
  - `scripts/lib/common.sh`
  - `scripts/lib/platform-linux.sh`
  - `scripts/lib/platform-mac.sh`
- Avoid duplicating platform detection or shared helper logic across scripts.
- Scripts should be idempotent where practical.
- Scripts should fail clearly rather than silently.

## Bootstrap and setup

Bootstrap/setup behavior should stay repeatable and understandable.

Relevant areas include:

- `scripts/bootstrap.sh`
- `zsh/install.sh`
- `node/install.sh`
- `osx/`
- `docs/bootstrap.md`
- other setup docs under `docs/`

Rules:

- Prefer one-shot, rerunnable setup flows.
- Avoid unnecessary interactive steps.
- Avoid requiring manual edits in multiple places when the repo can encode the behavior once.
- Update docs when setup behavior changes.

## Neovim rules

`nvim/` is a standalone domain. Keep it separate from shell config.

### Existing layout

- `nvim/init.lua`
- `nvim/lua/config/`
- `nvim/lua/plugins/`
- `nvim/stylua.toml`
- `nvim/lazy-lock.json`

### Rules

- Preserve the LazyVim-style structure.
- Core editor settings belong in `lua/config/`.
- Plugin specs/customizations belong in `lua/plugins/`.
- Do not move editor logic into shell init files.
- Be careful with clipboard, provider, LSP, tree-sitter, and runtime-path changes because behavior differs across macOS and remote Linux.
- Prefer deterministic provider/tool paths over implicit global assumptions.

## Terminal config rules

### Ghostty

`ghostty/` is the active terminal config area.

Preserve its modular split:

- `appearance.conf`
- `behavior.conf`
- `keybinds.conf`
- `local.conf`
- `themes/`
- `config`

Rules:

- Prefer modular edits over stuffing everything into one file.
- Theme changes should respect the existing theme structure.
- Avoid hardcoding appearance/theme values in unrelated files.

### Legacy terminal configs

- `kitty/` and `iterm2/` are reference/legacy areas.
- Do not remove or “clean up” them casually.
- Treat them as migration history or compatibility reference unless the task explicitly targets them.

## Theme and appearance changes

- Prefer changes that preserve modular theme structure.
- Ghostty themes live under `ghostty/themes/`.
- Theme switching should be explicit and inspectable.
- Do not scatter theme values across unrelated config files.

## Prompt config rules

- Prompt config belongs under `starship/`.
- Be careful about startup cost and hook side effects.
- Keep prompt-related helper logic near `starship/` when that makes structure clearer.
- Avoid prompt changes that add visible latency.

## Git config rules

`git/` contains policy and safety logic, not just personal preferences.

Be careful with:

- `git/git-core.symlink/hooks/`
- git templates
- git secrets patterns
- platform-specific git config files
- user config templates

Do not casually change hooks, secret patterns, or templates.

## AI tooling areas

The repo contains shared and tool-specific AI configuration.

Important areas include:

- `ai/`
- `claude/`
- `codex/`
- `opencode/`
- `cursor/`
- `gemini/`
- `goose/`
- `llm/`

Rules:

- Keep tool-specific config/state separated.
- Prefer reusing shared assets under `ai/` rather than duplicating them.
- Respect existing symlink relationships between shared AI assets and tool-specific directories.
- Do not clean up session/state/cached files unless explicitly asked.
- Do not relocate commands, skills, docs, or memory/state directories casually.

## Platform separation

This repo already has explicit platform separation. Keep using it.

- macOS-specific logic belongs in `osx/` or platform-specific shell/script files
- Linux-specific logic belongs in `linux/` or platform-specific shell/script files
- Do not scatter platform checks everywhere when a platform-specific home already exists
- Keep shared logic shared and platform logic isolated

## Change style expectations

In this repo, the best change is usually:

- small
- explicit
- reversible
- symlink-safe
- startup-safe
- platform-aware
- easy to understand six months later

Do not do broad cleanup for its own sake.

## Things to avoid

- Do not collapse modular config into giant files.
- Do not move shell logic out of the `zsh/env/` layering without a strong reason.
- Do not introduce Linux desktop assumptions into remote/server workflows.
- Do not rely on GUI clipboard/display behavior on headless Linux remotes.
- Do not add surprise Homebrew-based language runtime dependencies.
- Do not replace preferred runtime managers casually.
- Do not rewrite large config files when a targeted edit will do.
- Do not delete legacy/reference config just because it looks inactive.
- Do not normalize or clean stateful AI/tool directories unless explicitly asked.
- Do not reorganize top-level directories without a compelling reason.

## When making changes

Always mention:

- what changed
- why it changed
- any symlink impact
- any startup or PATH impact
- any performance impact
- any platform-specific implications
- any manual follow-up steps, only if truly required
