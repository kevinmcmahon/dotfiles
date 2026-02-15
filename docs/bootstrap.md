# Bootstrap System

One-command setup for macOS and Linux dev environments. Safe to re-run at any time.

```bash
scripts/bootstrap.sh                     # auto-detects macOS or Linux
INSTALL_NODE=1 scripts/bootstrap.sh      # also install Node.js LTS
SKIP_DEFAULTS=1 scripts/bootstrap.sh     # skip macOS system defaults
```

## Goals

- **One command** — a fresh machine goes from zero to usable dev environment
- **Idempotent** — every function checks state before acting; re-running skips what's already done
- **No root entry point** — scripts run as your user; `sudo` is used internally only where needed (apt, chsh)
- **Platform-aware** — single entry point auto-detects macOS or Linux; platform-specific logic lives in dedicated modules

## Philosophy

This repo follows the [holman/dotfiles](https://github.com/holman/dotfiles) convention of **topic-based organization**: each tool or concern gets its own directory (e.g., `git/`, `zsh/`, `nvim/`, `tmux/`). Configuration lives next to the tool it configures.

Key design decisions:

- **`*.symlink` files** are symlinked into `$HOME` as dotfiles (e.g., `git/gitconfig.symlink` -> `~/.gitconfig`)
- **XDG config directories** are symlinked into `~/.config/` (e.g., `nvim/` -> `~/.config/nvim/`)
- **Dotfile management is separate from provisioning** — the bootstrap scripts handle tool installation, while the topic directories hold configuration. They meet at the symlink phase.
- **Templates for secrets** — files containing personal data (git identity) use `.template` files that are copied (not symlinked) and `.gitignore`'d, so they never leak into the repo

## Architecture

### File Layout

```
scripts/
  bootstrap.sh              # Single entry point — auto-detects platform
  lib/
    common.sh               # Shared utilities + cross-platform installers
    platform-mac.sh         # macOS-specific: brew, xcode, cask, defaults
    platform-linux.sh       # Linux-specific: apt, appimage, manual binaries
  audit-mac.sh              # macOS environment audit
  audit-linux.sh            # Linux environment audit
```

`bootstrap.sh` detects the platform via `uname -s`, sources `lib/common.sh` for shared logic, then sources the appropriate `lib/platform-*.sh`. The install order is defined exactly once in `bootstrap.sh`'s `main()` function. Platform modules implement a contract of 8 functions that differ by OS; common.sh handles everything that works the same everywhere.

### Bootstrap Phases (`scripts/bootstrap.sh`)

| Phase | What it does | Defined in |
|-------|-------------|-----------|
| 1. Foundation | Preflight checks, create dirs, package manager + git | `platform-*.sh` |
| 2. Dotfile Symlinks | `*.symlink` -> `~/.<name>`, git identity templates, XDG config dirs | `common.sh` |
| 3. Platform Packages | Remaining platform tools (brew bundle, cask apps / go, nvim, lazygit, etc.) | `platform-*.sh` |
| 4. Shell Environment | oh-my-zsh, plugins, shell symlinks, set default shell | `common.sh` + `platform-*.sh` |
| 5. Language Runtimes | Rust/rustup, uv, Deno, optionally Node.js (fnm + corepack) | `common.sh` + `platform-*.sh` |
| 6. Dev Tooling | Neovim Python venv, ruff, llm + plugins, llm templates | `common.sh` |
| 7. AI/Dev CLIs | Claude Code, Claude config symlinks, OpenCode | `common.sh` |
| 8. Platform Config | macOS system defaults + Spotlight exclusions (no-op on Linux) | `platform-*.sh` |
| 9. Post-install | Sanity checks for expected commands | `common.sh` + `platform-*.sh` |

Symlinks must happen AFTER Phase 1 (which provides git and the package manager) but BEFORE Phase 3 (because on macOS, `brew bundle` reads `~/.BootstrapBrewfile` which is created by the symlink phase).

### Platform Contract

Each `lib/platform-*.sh` must define these 8 functions:

| Function | Purpose |
|----------|---------|
| `preflight_checks` | Verify OS, architecture, not root |
| `install_platform_foundation` | Minimal setup: package manager + git (before symlinks) |
| `install_platform_packages` | Remaining platform tools (after symlinks are in place) |
| `install_rust_and_cargo_tools` | Shared rustup (from common) + platform-specific cargo/brew tools |
| `set_default_shell_zsh` | chsh with platform-appropriate shell detection |
| `apply_platform_config` | macOS defaults + spotlight; no-op on Linux |
| `post_checks_platform` | Extra platform-specific sanity checks |
| `print_next_steps` | Platform-appropriate post-install instructions |

### Platform Differences

| Concern | macOS (`platform-mac.sh`) | Linux (`platform-linux.sh`) |
|---------|--------------------------|----------------------------|
| System packages | Homebrew (`brew bundle`) | apt-get |
| Neovim | Homebrew | AppImage -> `~/.local/bin/nvim` |
| lazygit | Homebrew | GitHub release tarball |
| starship | Homebrew | `starship.rs` installer |
| fzf | Homebrew | Git clone + install script |
| yazi | Homebrew | `cargo install` |
| tectonic | Homebrew | `cargo install` |
| Go | Homebrew | Official tarball to `/usr/local/go` |
| Ruby | `brew install chruby ruby-install` | Manual install from source |
| GUI apps | Homebrew Cask (kitty, tailscale) | N/A (server environment) |
| macOS defaults | `defaults write` | N/A |
| XDG dirs | nvim, yazi, tmux, starship, git, kitty | Same minus kitty |
| fd/bat | Homebrew (`fd`, `bat`) | apt (`fdfind`, `batcat`) + symlinks |
| fnm | Homebrew | curl installer -> `~/.local/bin` |
| pbcopy/pbpaste | Native | xclip wrapper scripts |

## Symlink Conventions

| Source pattern | Destination | Example |
|---------------|------------|---------|
| `<root>/*.symlink` | `~/.<name>` | `tools/aider.conf.yml.symlink` -> `~/.aider.conf.yml` |
| `git/*.symlink` | `~/.<name>` | `git/gitconfig.symlink` -> `~/.gitconfig` |
| `osx/*.symlink` | `~/.<name>` | `osx/Brewfile.symlink` -> `~/.Brewfile` |
| `git/git-core.symlink/` | `~/.git-core/` | Hooks and secrets directory |
| `tmux/tmux.conf.symlink` | `~/.tmux.conf` | tmux expects this path by default |
| `zsh/zshrc.symlink` | `~/.zshrc` | Handled by `zsh/install.sh` |
| `zsh/zshenv.symlink` | `~/.zshenv` | Handled by `zsh/install.sh` |
| `zsh/zprofile.symlink` | `~/.zprofile` | Handled by `zsh/install.sh` |
| XDG topic dirs | `~/.config/<topic>/` | `nvim/` -> `~/.config/nvim/` |
| `zsh/env/` | `~/.zsh/env/` | Layered zsh environment |
| `llm/templates.symlink/` | `<llm-data>/templates/` | llm template directory |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code global instructions |
| `claude/commands/` | `~/.claude/commands/` | Claude Code slash commands |
| `claude/docs/` | `~/.claude/docs/` | Claude Code reference docs |
| `claude/hooks/` | `~/.claude/hooks/` | Claude Code hook scripts |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code settings (hooks, plugins) |

Existing files are backed up with a `.bak.<timestamp>` suffix before being replaced.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `$HOME/dotfiles` | Root of the dotfiles repo |
| `LOCAL_BIN` | `$HOME/.local/bin` | User-local binaries (added to PATH) |
| `CONFIG_DIR` | `$HOME/.config` | XDG config base directory |
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS system defaults (mac only) |
| `INSTALL_NODE` | `0` | Set to `1` to install Node.js LTS via fnm + corepack |
| `NTFY_TOPIC` | *(unset)* | ntfy topic for Claude Code push notifications (required for ntfy) |
| `NTFY_SERVER` | `https://ntfy.sh` | ntfy server URL (optional, for self-hosted) |
| `NTFY_PRIORITY` | `high` | ntfy notification priority (min/low/default/high/urgent) |

## Topic Directory Structure

A topic directory can contain any combination of:

```
<topic>/
  *.symlink          # Symlinked to ~/.<name> by bootstrap
  install.sh         # Standalone installer (can run independently)
  README.md          # Documentation for the topic
  <config files>     # XDG config (symlinked to ~/.config/<topic>/)
```

Current topics: `bash`, `claude`, `codex`, `cursor`, `gemini`, `git`, `goose`, `helix`, `iterm2`, `kitty`, `lldb`, `llm`, `node`, `nvim`, `opencode`, `osx`, `starship`, `tmux`, `tools`, `vale`, `vscode`, `yazi`, `zsh`

## Standalone Installers

Some topics have `install.sh` scripts that work independently of the main bootstrap:

### `node/install.sh`
Installs Node.js LTS via fnm + corepack. Prerequisites: fnm on PATH. Handles fnm env setup, LTS install, setting default, and enabling corepack (provides yarn and pnpm).

### `zsh/install.sh`
Full zsh environment setup:
1. Installs oh-my-zsh (if missing)
2. Removes stock shell configs
3. Symlinks `~/.zshrc`, `~/.zshenv`, `~/.zprofile` to dotfiles versions
4. Creates `~/.zsh/env` -> `zsh/env/` (layered environment)
5. Clones oh-my-zsh plugins (git-open, zsh-defer, zsh-autosuggestions, zsh-syntax-highlighting, you-should-use, fzf-tab)
6. Links `alias.zsh` into oh-my-zsh custom dir
7. Sets zsh as default shell

The bootstrap scripts call `zsh/install.sh` with `SKIP_EXEC_ZSH=1` and `SKIP_SSH_AGENT=1` to prevent it from launching a new shell or prompting for SSH passphrases during bootstrap.

### Zsh Environment Layers (`zsh/env/`)

```
env/
  core/        # Always loaded
    path.zsh       # PATH construction
    functions.zsh  # Shell functions
    history.zsh    # History settings
    language.zsh   # Language/locale
    ruby.zsh       # chruby setup
    runtime.zsh    # Runtime tool init (starship, zoxide, direnv, fnm, etc.)
  platform/    # Loaded based on OS
    macos.zsh      # macOS-specific (Homebrew paths, clipboard, etc.)
    linux.zsh      # Linux-specific
  optional/    # Loaded if present
    private.zsh    # Machine-specific secrets (gitignored)
```

## Git Identity System

Git identity uses a layered include system to support multiple identities (personal, work) without storing personal data in the repo:

1. `git/gitconfig.symlink` -> `~/.gitconfig` — main config, includes platform-specific and local configs
2. `git/gitconfig-local.template` -> `~/.gitconfig-local` — **copied** (not symlinked), contains `includeIf` rules that route repos to identity files based on directory path. Uses absolute paths because Git doesn't expand `~` in `includeIf`.
3. Identity files (all **copied** from templates, never committed):
   - `~/.gituserconfig` — default fallback identity
   - `~/.gituserconfig.kmc` — personal projects identity
   - `~/.gituserconfig.nsv` — work projects identity

## Adding a New Tool

1. **Create a topic directory**: `mkdir <tool>/`
2. **Add config files** — these get symlinked to `~/.config/<tool>/` if you add the topic to the XDG list in the bootstrap scripts
3. **Add `*.symlink` files** — for files that need to live at `~/.<name>`
4. **Optionally add `install.sh`** — if the tool needs a standalone installer
5. **Update the bootstrap** — add the install function to `lib/common.sh` (if cross-platform) or the appropriate `lib/platform-*.sh` (if platform-specific), and call it from `main()` in `bootstrap.sh`. If it needs XDG symlinking, add the topic name to the `symlink_xdg_dirs` loop in `common.sh`.
6. **Update the audit scripts** — add checks for the new tool's commands, symlinks, and config to both `audit-mac.sh` and `audit-linux.sh`

## Auditing

### `scripts/audit-mac.sh`

Read-only script that checks for configuration drift. Run anytime to see what's missing or misconfigured:

```bash
scripts/audit-mac.sh
```

It checks:
- Platform and architecture
- Xcode CLT and Homebrew installation
- All expected brew formulae and casks
- Nerd fonts
- Every `*.symlink` file has a correct symlink in place
- XDG config directory symlinks
- Zsh environment (oh-my-zsh, plugins, shell symlinks)
- Git identity files (existence + whether name/email are set)
- Language runtimes (rust, go, uv, deno, fnm, chruby, node)
- Cargo/brew tools (viu, tectonic)
- Python tooling (ruff, neovim python venv)
- LLM tool + plugins + template symlinks
- AI CLIs (claude, opencode) and Claude Code config symlinks
- Standard directories (`~/.local/bin`, `~/.config`)
- Default shell
- macOS defaults (spot-checks key settings)
- Spotlight exclusions
- ~/Library visibility

Output: pass/fail/warn counts with a summary. Exit code 1 if any failures.

### `scripts/audit-linux.sh`

Linux counterpart of the macOS audit. Same pass/fail/warn framework, same helper functions. Checks:
- Platform and architecture
- Base apt packages (git, tmux, rg, jq, zsh, etc.)
- fd/bat wrapper symlinks in `~/.local/bin`
- Optional packages (eza, zoxide, tree — warns if missing)
- Every `*.symlink` file has a correct symlink in place
- XDG config directory symlinks (no kitty)
- Zsh environment (oh-my-zsh, plugins, shell symlinks)
- Git identity files (existence + whether name/email are set)
- Language runtimes (rust, go, uv, deno, fnm, chruby, ruby-install)
- Binary installs in `~/.local/bin` (nvim AppImage, lazygit)
- Starship and fzf (from non-brew sources)
- Cargo tools (viu, tectonic, yazi)
- Python tooling (ruff, neovim python venv)
- LLM tool + plugins + template symlinks (at `~/.config` path)
- AI CLIs (claude, opencode) and Claude Code config symlinks
- Standard directories (`~/.local/bin`, `~/.config`)
- Default shell (via `getent passwd`)
- pbcopy/pbpaste wrapper scripts

Output: pass/fail/warn counts with a summary. Exit code 1 if any failures.

## Design History

The original bootstrap used two separate scripts (`bootstrap-mac.sh` and `bootstrap-linux-dev.sh`) that shared ~450 lines of duplicated logic. This created drift risk: adding a tool to one script and forgetting the other.

The consolidation (Feb 2026) replaced them with the current `bootstrap.sh` + `lib/` architecture. The install list is now defined exactly once in `bootstrap.sh`'s `main()` function. Platform differences live in dedicated modules with a clear contract. Trivial platform differences (1-3 lines) use inline `$PLATFORM` checks in `common.sh` rather than splitting into separate files.
