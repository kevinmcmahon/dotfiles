# Bootstrap Consolidation Design

**Date:** 2026-02-14
**Status:** Approved

## Problem

The mac and linux bootstrap scripts share ~21 identical functions and ~3 nearly identical
functions. This duplication creates drift risk: adding a tool to one script and forgetting
the other, or platform-specific tweaks diverging silently over time. The "what to install"
list is defined in two places.

## Design Principles

- **Drift prevention over deduplication** — the primary goal is structural: make it impossible
  to define the install list in two places
- **Idiomatic and simple** — bash sourcing, no framework, no magic
- **Option A everywhere** — trivial platform differences (1-3 lines) use inline `$PLATFORM`
  checks rather than splitting into separate files
- **One entry point** — single `bootstrap.sh` auto-detects the platform

## Architecture

### File Layout

```
scripts/
  bootstrap.sh                # Single entry point (replaces both scripts)
  lib/
    common.sh                 # Shared utilities + cross-platform installers
    platform-mac.sh           # macOS-specific: brew, xcode, cask, defaults
    platform-linux.sh         # Linux-specific: apt, appimage, manual binaries
  audit-mac.sh                # Existing mac audit (unchanged)
  audit-linux.sh              # New linux audit
  bootstrap-mac.sh            # Removed (replaced by bootstrap.sh)
  bootstrap-linux-dev.sh      # Removed (replaced by bootstrap.sh)
```

### How It Works

`bootstrap.sh` is the orchestrator:
1. Detects platform via `uname -s` (Darwin or Linux)
2. Sets `PLATFORM` and `ARCH` globals
3. Sources `lib/common.sh` (utilities + cross-platform installers)
4. Sources the appropriate `lib/platform-*.sh`
5. Calls phases in order from `main()`

The install order is defined exactly once in `bootstrap.sh`. Platform modules provide
implementations for functions that differ by OS. Common functions handle everything that
works the same everywhere.

### bootstrap.sh — Phase Ordering

```
main() {
  # Phase 1 — Foundation (platform-specific)
  preflight_checks
  ensure_dirs
  ensure_local_bin_in_path
  install_platform_packages

  # Phase 2 — Dotfile Symlinks (common)
  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs

  # Phase 3 — Shell Environment (common)
  install_zsh_environment
  set_default_shell_zsh

  # Phase 4 — Language Runtimes
  install_rust_and_cargo_tools
  install_uv
  install_deno
  setup_node

  # Phase 5 — Dev Tooling (common)
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Phase 6 — AI/Dev CLIs (common)
  install_claude_code
  install_opencode

  # Phase 7 — Platform Configuration (platform-specific)
  apply_platform_config

  # Phase 8 — Post-install
  post_checks
  print_next_steps
}
```

### Platform Contract

Each `platform-*.sh` must define these functions:

| Function | Purpose |
|----------|---------|
| `preflight_checks` | Verify OS, architecture, not root |
| `install_platform_packages` | System package manager + platform-only tools |
| `install_rust_and_cargo_tools` | Shared rustup (from common) + platform-specific cargo/brew tools |
| `set_default_shell_zsh` | chsh with platform-appropriate shell detection |
| `apply_platform_config` | macOS defaults + spotlight; no-op on Linux |
| `post_checks_platform` | Extra platform-specific sanity checks |
| `print_next_steps` | Platform-appropriate post-install instructions |

### Function Placement

**common.sh** — shared utilities + cross-platform installers:

| Function | Notes |
|----------|-------|
| `log`, `warn`, `die`, `need_cmd` | Identical on both platforms |
| `ensure_dirs`, `ensure_local_bin_in_path` | Identical |
| `symlink_dotfiles_symlink_pattern` | Identical |
| `ensure_git_identity_templates` | Identical |
| `symlink_xdg_dirs` | Inline `$PLATFORM` check: includes kitty on Darwin only |
| `install_zsh_environment` | Identical |
| `install_uv` | curl installer, identical |
| `install_deno` | curl installer, identical |
| `setup_node` | fnm-based, identical |
| `install_nvim_python_venv_uv` | Identical |
| `install_ruff_uv` | Identical |
| `install_llm` | Inline `$PLATFORM`/`$ARCH` check for llm-mlx |
| `symlink_llm_templates` | Inline `$PLATFORM` check for data dir path |
| `install_claude_code` | curl installer, identical |
| `install_opencode` | Inline `$PLATFORM` check for sed `-i` vs `-i ''` syntax |
| `post_checks` | Common checks + calls `post_checks_platform` |

**platform-mac.sh** — macOS-specific:

| Function | What it wraps |
|----------|--------------|
| `preflight_checks` | Darwin check, architecture detection |
| `install_platform_packages` | `install_xcode_clt`, `install_homebrew`, `install_git_via_brew`, `brew_bundle`, `install_cask_apps` |
| `install_rust_and_cargo_tools` | rustup (common helper) + brew for tectonic; viu via cargo |
| `set_default_shell_zsh` | dscl-based shell detection |
| `apply_platform_config` | `apply_macos_defaults`, `apply_spotlight_configs` |
| `post_checks_platform` | brew, eza, zoxide, lazygit, starship, yazi, fnm, cargo, go, chruby checks |
| `print_next_steps` | Tailscale, Python, Node, Ruby, LLM keys, Brewfile |

**platform-linux.sh** — Linux-specific:

| Function | What it wraps |
|----------|--------------|
| `preflight_checks` | Linux check, not root, architecture |
| `install_platform_packages` | `apt_install_base`, `install_extras_optional`, `install_go_official`, `install_fnm`, `install_neovim_appimage`, `install_lazygit`, `install_starship`, `install_fzf`, `install_ruby_build_deps`, `install_ruby_install`, `install_chruby`, `install_pbcopy_wrappers` |
| `install_rust_and_cargo_tools` | rustup (common helper) + cargo for yazi, viu, tectonic |
| `set_default_shell_zsh` | getent-based shell detection, `/etc/shells` management |
| `apply_platform_config` | No-op |
| `post_checks_platform` | nvim/lazygit in `~/.local/bin`, fzf, go, chruby, ruby-install |
| `print_next_steps` | Python, Node, Ruby, keychain note |

### Handling "Nearly Identical" Functions (Option A)

All use inline platform checks. Examples:

```bash
# symlink_xdg_dirs — kitty only on macOS
local topics="nvim yazi tmux starship git"
[[ "$PLATFORM" == "Darwin" ]] && topics="$topics kitty"

# install_opencode — sed syntax
if [[ "$PLATFORM" == "Darwin" ]]; then
  sed -i '' '/^# opencode$/d' "$zshrc_real"
else
  sed -i '/^# opencode$/d' "$zshrc_real"
fi

# install_llm — mlx plugin
if [[ "$PLATFORM" == "Darwin" && "$ARCH" == "arm64" ]]; then
  llm install -U llm-mlx
fi

# symlink_llm_templates — data dir
if [[ "$PLATFORM" == "Darwin" ]]; then
  local llm_data_dir="$HOME/Library/Application Support/io.datasette.llm"
  [[ ! -d "$llm_data_dir" ]] && llm_data_dir="$HOME/.config/io.datasette.llm"
else
  local llm_data_dir="$HOME/.config/io.datasette.llm"
fi
```

### Shared Rustup Helper

`common.sh` provides `install_rustup` (just the rustup + cargo setup). Each platform's
`install_rust_and_cargo_tools` calls it, then installs platform-specific cargo/brew tools:

```bash
# common.sh
install_rustup() {
  if ! need_cmd rustup; then
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y
  fi
  source "$HOME/.cargo/env" || true
  need_cmd cargo || die "cargo not available after rustup install"
}

# platform-mac.sh
install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"
  install_rustup
  # viu via cargo, tectonic via brew
  need_cmd viu || cargo install viu
  need_cmd tectonic || brew install tectonic
}

# platform-linux.sh
install_rust_and_cargo_tools() {
  log "Installing Rust toolchain and cargo tools"
  install_rustup
  # everything via cargo on linux
  need_cmd yazi || { cargo install --force yazi-build && yazi-build; }
  need_cmd viu || cargo install viu
  need_cmd tectonic || cargo install tectonic
}
```

## audit-linux.sh

New script mirroring `audit-mac.sh` structure. Same pass/fail/warn framework, same helper
functions (`check_cmd`, `check_symlink`, `check_file_exists`, `check_dir_exists`).

### Sections

| Section | Checks |
|---------|--------|
| Platform | Linux detected, architecture |
| Base apt packages | git, tmux, ripgrep, fd-find, bat, zsh, jq, curl, wget, make, gcc, xclip |
| fd/bat symlinks | `~/.local/bin/fd` -> fdfind, `~/.local/bin/bat` -> batcat |
| Optional packages | eza, zoxide, tree |
| Dotfile symlinks (root) | All `*.symlink` files |
| Dotfile symlinks (git/) | All `git/*.symlink` files |
| Git core | `~/.git-core` symlink |
| XDG config dirs | nvim, yazi, tmux, starship, git (no kitty) |
| Zsh environment | oh-my-zsh dir, plugins, `~/.zshrc`/`~/.zshenv`/`~/.zprofile` symlinks, `~/.zsh/env` |
| Git identity | `~/.gituserconfig` (existence + name/email set), `~/.gitconfig-local`, optional `.kmc`/`.nsv` |
| Language runtimes | rustup, rustc, cargo, go (`/usr/local/go/bin/go`), uv, deno, fnm, chruby, ruby-install |
| Binary installs | nvim in `~/.local/bin`, lazygit in `~/.local/bin` |
| Starship | starship command |
| fzf | `~/.fzf` dir + fzf command |
| Cargo tools | viu, tectonic, yazi |
| Python tooling | ruff, neovim python venv + pynvim |
| LLM | llm + plugins (anthropic, gemini, openai, mistral, mlx), template symlink at `~/.config` path |
| AI CLIs | claude, opencode + config symlink |
| Standard dirs | `~/.local/bin`, `~/.config` |
| Default shell | zsh via `getent passwd` |
| pbcopy/pbpaste | Wrapper scripts exist in `~/.local/bin` |
| Node (optional) | node, corepack, yarn, pnpm if present |
| Summary | pass/fail/warn counts, exit 1 on failures |

The audit helpers (`check_cmd`, `check_symlink`, etc.) are duplicated between
`audit-mac.sh` and `audit-linux.sh` rather than shared. The audit scripts are
standalone read-only tools — keeping them self-contained is more important than
DRYing out ~50 lines of helper functions.

## Migration

1. Build new scripts alongside old ones (no deletion during development)
2. Verify on macOS: run `audit-mac.sh` before and after to confirm no drift
3. Verify on Linux: run new `audit-linux.sh` to confirm parity
4. Remove old `bootstrap-mac.sh` and `bootstrap-linux-dev.sh`
5. Update `docs/bootstrap.md` to reflect new architecture

## Out of Scope

- Changing what gets installed (no new tools, no removals)
- Changing installation methods (still curl | sh, still brew, still cargo)
- Merging the audit scripts into one (they stay self-contained)
- Any behavioral changes — this is a pure structural refactor
