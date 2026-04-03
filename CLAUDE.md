# CLAUDE.md

Personal dotfiles repo: modular, symlink-friendly, terminal-first config for macOS and remote Linux.

## Core Philosophy

- Preserve modularity. Do not collapse config into monolithic files.
- Prefer small, targeted, reversible diffs over broad cleanup.
- Respect symlink-based installation patterns.
- Protect shell startup speed and predictability.
- Do not reorganize top-level directories unless the task explicitly requires it.

## Environment Assumptions

- Primary: macOS, Zsh, Neovim, Ghostty terminal, cmux
- Linux usage is remote, headless, SSH-only
- NEVER assume Linux GUI, clipboard daemons, display servers, or desktop keyrings
- Prefer user-scoped installs over system-wide

## Directory Roles

### Active (prefer working here)

- `zsh/` — shell startup, env layering, functions, completions
- `nvim/` — Neovim config (standalone domain, separate from shell)
- `ghostty/` — active terminal config
- `tmux/` — tmux config and helpers
- `starship/` — prompt config
- `git/` — git config, hooks, templates, secret patterns
- `scripts/` — reusable bootstrap/setup/utility scripts
- `scripts/lib/` — shared shell library (`common.sh`, `platform-linux.sh`, `platform-mac.sh`)
- `osx/` — macOS-specific setup and defaults
- `docs/` — setup and operational documentation

### Legacy/reference (do not change casually)

- `bash/`, `kitty/`, `iterm2/`, `helix/`, `vscode/`, `archive/`
- Treat as migration history. Do not delete or "clean up."

### Stateful/generated (hands off)

- `claude/`, `codex/`, `gemini/`, `goose/`, `.git/`, `kitty/themes/`
- AI tool dirs: `ai/`, `opencode/`, `cursor/`, `llm/`
- Never clean, normalize, or refactor session files, sqlite DBs, logs, caches, or generated JSON

### AI tooling

- Keep tool-specific config separated per directory
- Reuse shared assets under `ai/` rather than duplicating
- Respect existing symlink relationships between `ai/` and tool-specific dirs

## Symlink Conventions

- Files ending in `*.symlink` are part of the install contract
- Never rename, relocate, or replace `*.symlink` files without calling it out
- Never convert symlink-managed files into copied files
- `claude/` is symlinked to `~/.claude/` — `claude/CLAUDE.md` is the user-level global config, not this file

## Zsh Architecture

`zsh/` uses a deliberate layered env system. Preserve it.

### Layer placement

- `zsh/env/core/` — foundational shell behavior (PATH, history, runtime)
- `zsh/env/platform/` — platform-specific behavior (`macos.zsh`, `linux.zsh`)
- `zsh/env/tools/` — runtime/tool init (node, python-uv, rust, go, bun)
- `zsh/env/optional/` — local/private overlays
- `zsh/functions/` — reusable shell commands
- `zsh/completions/` — zsh completions

### Rules

- Do not collapse layers into a monolithic `.zshrc`
- Do not stuff logic into top-level entry files when a layer exists
- Prefer functions over aliases for anything non-trivial
- If an alias grows logic, promote it to a function in `zsh/functions/`
- Do not inline completion logic into shell init files

## Shell Startup Performance

- Avoid expensive subprocesses in startup paths
- No duplicate initialization across zshenv/zprofile/zshrc/env layers
- Preserve load ordering unless fixing a clear bug
- Favor conditional or lazy loading
- Every shell change must be safe for interactive, SSH, and non-interactive use
- Be careful with: PATH construction, prompt init, runtime manager init, completion loading, shell hook registration

## PATH and Toolchain

- `~/.local/bin` is the canonical user-level bin directory
- Minimize Homebrew for language runtimes when a language-native manager exists

### Preferred runtime managers (do not introduce competitors)

- Python: `uv`
- Node.js: `fnm`
- Rust: `rustup`
- Ruby: `chruby`

## Scripts

- Reusable scripts go under `scripts/`
- Shared helpers go in `scripts/lib/` — reuse `common.sh`, `platform-linux.sh`, `platform-mac.sh`
- Do not duplicate platform detection logic across scripts
- Scripts should be idempotent and fail clearly
- Bootstrap/setup flows should be rerunnable and non-interactive

## Neovim

- Standalone domain — do not mix with shell config
- LazyVim-style structure: settings in `lua/config/`, plugins in `lua/plugins/`
- Be careful with clipboard, providers, LSP, tree-sitter, and runtimepath — behavior differs across macOS and remote Linux
- Prefer deterministic provider/tool paths over implicit global assumptions

## Ghostty

- Preserve modular split: `appearance.conf`, `behavior.conf`, `keybinds.conf`, `local.conf`, `themes/`
- Theme changes must respect existing theme structure under `ghostty/themes/`
- Do not hardcode appearance values in unrelated files

## Prompt (Starship)

- Config lives under `starship/`
- Keep prompt-related helpers near `starship/`
- Avoid prompt changes that add visible latency

## Git

- `git/` contains policy and safety logic, not just preferences
- Do not casually change hooks, secret patterns, or templates
- Be aware of platform-specific git config (`gitconfig-linux.symlink`, `gitconfig-macos.symlink`)

## Platform Separation

- macOS logic: `osx/` or platform-specific shell/script files
- Linux logic: `linux/` or platform-specific shell/script files
- Do not scatter platform checks everywhere when a platform-specific home exists
- Keep shared logic shared, platform logic isolated

## Change Expectations

Every change should be: small, explicit, reversible, symlink-safe, startup-safe, platform-aware, and easy to understand six months later.

When making changes, mention: what changed, why, any symlink/startup/PATH/performance/platform impact.

## Things to Avoid

- Introducing Linux desktop assumptions into remote/headless workflows
- Adding Homebrew-based language runtime dependencies when a native manager exists
- Replacing preferred runtime managers without discussion
- Rewriting large config files when a targeted edit suffices
- Moving shell logic out of the `zsh/env/` layering without strong reason
- Scattering theme values across unrelated config files
- Normalizing or cleaning stateful AI/tool directories unless explicitly asked
