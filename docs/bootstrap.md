# Bootstrap System

One-command setup for macOS and Linux dev environments. Safe to re-run at any time.

```bash
# macOS
scripts/bootstrap-mac.sh

# Linux (Ubuntu/Debian)
scripts/bootstrap-linux-dev.sh
```

## Goals

- **One command** — a fresh machine goes from zero to usable dev environment
- **Idempotent** — every function checks state before acting; re-running skips what's already done
- **No root entry point** — scripts run as your user; `sudo` is used internally only where needed (apt, chsh)
- **Platform-aware** — separate scripts for macOS and Linux with shared conventions

## Philosophy

This repo follows the [holman/dotfiles](https://github.com/holman/dotfiles) convention of **topic-based organization**: each tool or concern gets its own directory (e.g., `git/`, `zsh/`, `nvim/`, `tmux/`). Configuration lives next to the tool it configures.

Key design decisions:

- **`*.symlink` files** are symlinked into `$HOME` as dotfiles (e.g., `git/gitconfig.symlink` -> `~/.gitconfig`)
- **XDG config directories** are symlinked into `~/.config/` (e.g., `nvim/` -> `~/.config/nvim/`)
- **Dotfile management is separate from provisioning** — the bootstrap scripts handle tool installation, while the topic directories hold configuration. They meet at the symlink phase.
- **Templates for secrets** — files containing personal data (git identity) use `.template` files that are copied (not symlinked) and `.gitignore`'d, so they never leak into the repo

## Current Architecture

### macOS Bootstrap Phases (`scripts/bootstrap-mac.sh`)

| Phase | What it does |
|-------|-------------|
| 1. Foundation | Preflight checks, create dirs, Xcode CLT, Homebrew, git |
| 2. Dotfile Symlinks | `*.symlink` -> `~/.<name>`, git identity templates, XDG config dirs |
| 3. Brew Bundle | Install packages from `BootstrapBrewfile`, install cask apps (kitty, tailscale) |
| 4. Shell Environment | Run `zsh/install.sh` (oh-my-zsh, plugins, shell symlinks) |
| 5. Language Runtimes | Rust/rustup, uv, Deno, optionally Node.js (fnm + corepack) |
| 6. Python/Dev Tooling | Neovim Python venv, ruff, llm + plugins, llm templates |
| 7. AI/Dev CLIs | Claude Code, OpenCode |
| 8. macOS Configuration | System defaults (Finder, keyboard, trackpad, dock, screenshots), Spotlight exclusions |
| 9. Post-install | Sanity checks for expected commands |

### Linux Bootstrap (`scripts/bootstrap-linux-dev.sh`)

The Linux script covers the same ground but uses different package managers and installation methods:

| Difference | macOS | Linux |
|-----------|-------|-------|
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

Existing files are backed up with a `.bak.<timestamp>` suffix before being replaced.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `$HOME/dotfiles` | Root of the dotfiles repo |
| `LOCAL_BIN` | `$HOME/.local/bin` | User-local binaries (added to PATH) |
| `CONFIG_DIR` | `$HOME/.config` | XDG config base directory |
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS system defaults (mac only) |
| `INSTALL_NODE` | `0` | Set to `1` to install Node.js LTS via fnm + corepack |

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
5. **Update the bootstrap scripts** — add the install function and call it from `main()`. If it needs XDG symlinking, add the topic name to the `symlink_xdg_dirs` loop.
6. **Update the audit script** — add checks for the new tool's commands, symlinks, and config

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
- AI CLIs (claude, opencode)
- Standard directories (`~/.local/bin`, `~/.config`)
- Default shell
- macOS defaults (spot-checks key settings)
- Spotlight exclusions
- ~/Library visibility

Output: pass/fail/warn counts with a summary. Exit code 1 if any failures.

### Linux Audit (future)

No `audit-linux.sh` exists yet. A future version should mirror `audit-mac.sh` but check:
- apt packages instead of brew formulae
- AppImage/binary installs in `~/.local/bin` (nvim, lazygit)
- starship, fzf from non-brew sources
- Go in `/usr/local/go`
- chruby/ruby-install from source
- pbcopy/pbpaste wrapper scripts
- No GUI app or macOS defaults checks

## Future Direction

The mac and linux bootstrap scripts share ~450 lines of duplicated logic (utility functions, symlink operations, git identity templates, tool installers for rust, uv, deno, node, llm, claude, opencode, etc.). The planned consolidation (Approach 2: topic-based installers) would:

1. **Extract `scripts/lib/common.sh`** — shared utility functions (`log`, `warn`, `die`, `need_cmd`), symlink helpers, git identity template logic
2. **Create per-topic installers** — each tool gets an `install.sh` in its topic directory (e.g., `rust/install.sh`, `deno/install.sh`) that handles platform differences internally
3. **Slim bootstrap scripts to orchestrators** — `bootstrap-mac.sh` and `bootstrap-linux-dev.sh` become thin scripts that: do platform-specific setup (brew/apt, Xcode CLT), source `common.sh`, call topic installers in order, run platform-specific post-config (macOS defaults)

This eliminates duplication while keeping each topic self-contained and independently runnable.
