# Bootstrap Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace two duplicate bootstrap scripts with a single `bootstrap.sh` that sources shared code from `lib/common.sh` and platform-specific code from `lib/platform-{mac,linux}.sh`. Add a Linux audit script.

**Architecture:** One entry point (`bootstrap.sh`) detects platform, sources `lib/common.sh` + the right `lib/platform-*.sh`, calls phases in order. Cross-platform tools live in common.sh. Platform differences use inline `$PLATFORM` checks (Option A). See `docs/plans/2026-02-14-bootstrap-consolidation-design.md` for full design.

**Tech Stack:** Bash, shellcheck for verification, existing `audit-mac.sh` as regression test.

---

## Important Context

**Source files to read before each task** (the implementing agent should read these for exact function bodies):
- `scripts/bootstrap-mac.sh` — current macOS bootstrap
- `scripts/bootstrap-linux-dev.sh` — current Linux bootstrap
- `scripts/audit-mac.sh` — audit script structure to mirror

**Key ordering constraint:** Symlinks (Phase 2) must happen AFTER `install_platform_foundation` (Phase 1 — provides package manager + git) but BEFORE `install_platform_packages` (Phase 3 — macOS `brew_bundle` reads `~/.BootstrapBrewfile` which is created by the symlink phase).

**Globals set by bootstrap.sh** that all sourced files can use: `DOTFILES_DIR`, `LOCAL_BIN`, `CONFIG_DIR`, `INSTALL_NODE`, `PLATFORM` (`Darwin` or `Linux`), `ARCH` (`arm64`, `x86_64`, `aarch64`).

**Behavioral contract:** This is a pure structural refactor. No tools added, removed, or changed. The same commands run in the same order with the same logic.

---

### Task 1: Create `scripts/lib/common.sh`

**Files:**
- Create: `scripts/lib/common.sh`

**Step 1: Read source files**

Read `scripts/bootstrap-mac.sh` and `scripts/bootstrap-linux-dev.sh` to use as source for function bodies.

**Step 2: Create `scripts/lib/common.sh`**

This file contains all shared utilities and cross-platform installers. It is sourced by `bootstrap.sh` — it does NOT have a shebang or `set -euo pipefail` (those belong in the entry point).

Functions to include (copy from either bootstrap script — they're identical unless noted):

**Utilities** (from either script, identical):
- `log`, `warn`, `die`, `need_cmd`
- `ensure_dirs`
- `ensure_local_bin_in_path`

**Symlink functions:**
- `symlink_dotfiles_symlink_pattern` — merge from both scripts. The mac version has an extra loop for `osx/*.symlink` files. Add an inline `$PLATFORM == "Darwin"` check around that loop. Copy the rest verbatim from either script.
- `ensure_git_identity_templates` — identical in both scripts (after the fete→nsv fix already applied). Copy from either.
- `symlink_xdg_dirs` — use a string variable for topics instead of a hardcoded list. Base topics: `nvim yazi tmux starship git`. Append `kitty` when `$PLATFORM == "Darwin"`. Copy the loop body from either script.

**Shell:**
- `install_zsh_environment` — identical in both. Copy from either.

**Shared rustup helper** (new extraction):
- `install_rustup` — extract the rustup/cargo setup portion from either script's `install_rust_and_cargo_tools`. Just the curl install + `source cargo/env` + cargo check. Each platform's `install_rust_and_cargo_tools` will call this, then do platform-specific tool installs.

**Cross-platform installers** (identical in both scripts — copy from either):
- `install_uv`
- `install_deno`
- `setup_node`
- `install_nvim_python_venv_uv`
- `install_ruff_uv`
- `install_claude_code`

**Cross-platform installers with inline platform checks:**

- `install_llm` — copy from mac version, then modify the llm-mlx section:
  - Mac + arm64: install llm-mlx
  - Linux: install llm-mlx (unconditionally, matching current linux behavior)
  - Mac + x86_64: skip llm-mlx (matching current mac behavior)

- `symlink_llm_templates` — determine `llm_data_dir` based on `$PLATFORM`:
  - Darwin: check `~/Library/Application Support/io.datasette.llm` first, fall back to `~/.config`
  - Linux: always `~/.config/io.datasette.llm`

- `install_opencode` — copy from either script. Wrap the `sed -i` lines in a platform check:
  - Darwin: `sed -i ''`
  - Linux: `sed -i`

**Post-checks:**
- `post_checks` — unified common checks (git, tmux, nvim, rg, fd, fzf, bat, rustc, cargo, uv, deno, fnm, node), then calls `post_checks_platform` (defined by each platform module).

**Step 3: Shellcheck**

Run: `shellcheck scripts/lib/common.sh`
Expected: 0 errors (warnings about SC1091 for sourced files are acceptable, suppress with `# shellcheck disable=SC1091`)

**Step 4: Commit**

```bash
git add scripts/lib/common.sh
git commit -m "refactor: extract shared bootstrap functions into lib/common.sh"
```

---

### Task 2: Create `scripts/lib/platform-mac.sh`

**Files:**
- Create: `scripts/lib/platform-mac.sh`

**Step 1: Read source**

Read `scripts/bootstrap-mac.sh` for exact function bodies.

**Step 2: Create `scripts/lib/platform-mac.sh`**

This file is sourced after `common.sh`. No shebang or `set -euo pipefail`.

Set `SKIP_DEFAULTS="${SKIP_DEFAULTS:-0}"` at the top (mac-only env var).

Functions to include (copy from `bootstrap-mac.sh`):

**Foundation:**
- `preflight_checks` — lines 60-76
- `install_xcode_clt` — lines 78-101
- `install_homebrew` — lines 103-122
- `install_git_via_brew` — lines 124-134
- `install_platform_foundation` — new wrapper that calls the three above

**Platform packages (after symlinks):**
- `brew_bundle` — lines 282-296
- `install_cask_apps` — lines 298-316
- `install_platform_packages` — new wrapper that calls both

**Rust + cargo tools:**
- `install_rust_and_cargo_tools` — calls `install_rustup` (from common.sh), then installs viu via cargo and tectonic via brew. Copy the viu/tectonic logic from lines 365-381.

**Shell:**
- `set_default_shell_zsh` — mac uses `dscl` to read current shell. Copy the zsh/install.sh mac shell detection pattern, or adapt from the existing mac script. Note: the current `bootstrap-mac.sh` does NOT have a standalone `set_default_shell_zsh` — zsh/install.sh handles it. Create a thin wrapper that's a no-op if shell is already zsh (check via dscl), otherwise calls chsh. Or: just make it a no-op since zsh/install.sh already handles shell change on both platforms.

  **Decision:** Make `set_default_shell_zsh` a no-op on mac — `zsh/install.sh` (called by `install_zsh_environment` in common.sh) already handles the shell change. The linux platform has its own `change_shell_to_zsh` because the current linux bootstrap calls it separately (after zsh/install.sh AND additionally as a standalone step). Review: looking at `zsh/install.sh` lines 104-120, it handles both mac and linux shell change. So `set_default_shell_zsh` can be a no-op on BOTH platforms since `install_zsh_environment` already runs `zsh/install.sh` which does the shell change. BUT the current linux bootstrap calls `change_shell_to_zsh` SEPARATELY too (belt and suspenders). To match current behavior exactly: make linux's `set_default_shell_zsh` the current `change_shell_to_zsh`, and mac's a no-op.

**Platform config:**
- `apply_macos_defaults` — lines 610-695
- `apply_spotlight_configs` — lines 697-711
- `apply_platform_config` — wrapper that checks `SKIP_DEFAULTS`, calls both

**Post-install:**
- `post_checks_platform` — additional checks: brew (die), eza, zoxide, lazygit, starship, yazi (all warn)
- `print_next_steps` — lines 788-817 (the "Next steps" log block)

**Step 3: Shellcheck**

Run: `shellcheck scripts/lib/platform-mac.sh`
Expected: 0 errors

**Step 4: Commit**

```bash
git add scripts/lib/platform-mac.sh
git commit -m "refactor: extract macOS bootstrap functions into lib/platform-mac.sh"
```

---

### Task 3: Create `scripts/lib/platform-linux.sh`

**Files:**
- Create: `scripts/lib/platform-linux.sh`

**Step 1: Read source**

Read `scripts/bootstrap-linux-dev.sh` for exact function bodies.

**Step 2: Create `scripts/lib/platform-linux.sh`**

This file is sourced after `common.sh`. No shebang or `set -euo pipefail`.

Functions to include (copy from `bootstrap-linux-dev.sh`):

**Foundation:**
- `preflight_checks` — not-root check + arch detection (no OS check since bootstrap.sh handles platform routing)
- `apt_install_base` — lines 57-80
- `install_extras_optional` — lines 82-93
- `install_platform_foundation` — wrapper calling `apt_install_base`, `install_extras_optional`

**Platform packages (after symlinks):**
- `install_go_official` — lines 153-212
- `install_fnm` — lines 95-116
- `install_neovim_appimage` — lines 352-378
- `install_lazygit` — lines 380-413
- `install_starship` — lines 465-475
- `install_fzf` — lines 477-494
- `install_ruby_build_deps` — lines 703-711
- `install_ruby_install` — lines 713-739
- `install_chruby` — lines 741-767
- `install_ruby_optional` — lines 769-781 (conditional on `RUBY_VERSION` env var)
- `install_pbcopy_wrappers` — lines 680-701
- `install_platform_packages` — wrapper calling all of the above

**Rust + cargo tools:**
- `install_rust_and_cargo_tools` — calls `install_rustup` (from common.sh), then installs yazi (cargo + yazi-build), viu (cargo), tectonic (cargo). Copy logic from lines 436-463.

**Shell:**
- `set_default_shell_zsh` — copy `change_shell_to_zsh` from lines 783-811

**Platform config:**
- `apply_platform_config` — no-op (`return 0`)

**Post-install:**
- `post_checks_platform` — checks for go, lazygit, starship, yazi, eza, zoxide (all warn)
- `print_next_steps` — lines 903-929 (the "Next steps" log block, with nsv not fete)

**Step 3: Shellcheck**

Run: `shellcheck scripts/lib/platform-linux.sh`
Expected: 0 errors

**Step 4: Commit**

```bash
git add scripts/lib/platform-linux.sh
git commit -m "refactor: extract Linux bootstrap functions into lib/platform-linux.sh"
```

---

### Task 4: Create `scripts/bootstrap.sh`

**Files:**
- Create: `scripts/bootstrap.sh`

**Step 1: Create `scripts/bootstrap.sh`**

This is the new single entry point. It sets globals, sources libraries, and defines `main()` with the phase ordering.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Dev Environment Bootstrap
# Auto-detects macOS or Linux, sources shared + platform-specific libraries,
# and runs a phased install. Safe to re-run (idempotent).
#
# Usage:
#   scripts/bootstrap.sh
#   INSTALL_NODE=1 scripts/bootstrap.sh    # also install Node.js LTS
#   SKIP_DEFAULTS=1 scripts/bootstrap.sh   # skip macOS system defaults
# ------------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
INSTALL_NODE="${INSTALL_NODE:-0}"

SCRIPTS_DIR="$DOTFILES_DIR/scripts"
PLATFORM="$(uname -s)"
ARCH="$(uname -m)"

# Source shared library
# shellcheck source=lib/common.sh
source "$SCRIPTS_DIR/lib/common.sh"

# Source platform-specific library
case "$PLATFORM" in
  Darwin)
    # shellcheck source=lib/platform-mac.sh
    source "$SCRIPTS_DIR/lib/platform-mac.sh"
    ;;
  Linux)
    # shellcheck source=lib/platform-linux.sh
    source "$SCRIPTS_DIR/lib/platform-linux.sh"
    ;;
  *)
    die "Unsupported platform: $PLATFORM"
    ;;
esac

main() {
  # Phase 1 — Foundation (platform-specific: package manager + git)
  preflight_checks
  ensure_dirs
  ensure_local_bin_in_path
  install_platform_foundation

  # Phase 2 — Dotfile Symlinks (must precede brew bundle on macOS)
  symlink_dotfiles_symlink_pattern
  ensure_git_identity_templates
  symlink_xdg_dirs

  # Phase 3 — Platform Packages (brew bundle needs BootstrapBrewfile symlink)
  install_platform_packages

  # Phase 4 — Shell Environment
  install_zsh_environment
  set_default_shell_zsh

  # Phase 5 — Language Runtimes
  install_rust_and_cargo_tools
  install_uv
  install_deno
  setup_node

  # Phase 6 — Dev Tooling
  install_nvim_python_venv_uv
  install_ruff_uv
  install_llm
  symlink_llm_templates

  # Phase 7 — AI/Dev CLIs
  install_claude_code
  install_opencode

  # Phase 8 — Platform Configuration
  apply_platform_config

  # Phase 9 — Post-install
  post_checks
  print_next_steps
}

main "$@"
```

**Step 2: Make executable**

Run: `chmod +x scripts/bootstrap.sh`

**Step 3: Shellcheck all new scripts**

Run: `shellcheck scripts/bootstrap.sh scripts/lib/common.sh scripts/lib/platform-mac.sh scripts/lib/platform-linux.sh`
Expected: 0 errors (SC1091 source warnings are OK — suppress inline)

**Step 4: Commit**

```bash
git add scripts/bootstrap.sh
git commit -m "refactor: add unified bootstrap.sh entry point"
```

---

### Task 5: Verify bootstrap consolidation

**Step 1: Run macOS audit**

Run: `bash scripts/audit-mac.sh`
Expected: Same pass/fail/warn counts as before the refactor. The audit checks symlinks, commands, and config — if these pass, the bootstrap is functionally equivalent.

Note: This verifies the CURRENT state of the machine hasn't drifted. It doesn't exercise the new bootstrap.sh directly (that would install things). But since the new scripts contain the same function bodies, passing audit confirms nothing was lost.

**Step 2: Dry-read verification**

Manually verify these key differences between old and new:
1. `symlink_dotfiles_symlink_pattern` — confirm `osx/*.symlink` loop has `$PLATFORM == "Darwin"` guard
2. `symlink_xdg_dirs` — confirm kitty only added on Darwin
3. `install_llm` — confirm mlx logic matches: Darwin+arm64 = yes, Linux = yes, Darwin+x86 = no
4. `install_opencode` — confirm sed syntax branches correctly
5. `symlink_llm_templates` — confirm data dir path branches correctly
6. Phase ordering in `bootstrap.sh` — confirm symlinks before `install_platform_packages`

**Step 3: Grep for orphaned references**

Run: `grep -r 'bootstrap-mac\|bootstrap-linux-dev' scripts/`
Expected: No references in the new scripts (old scripts still exist at this point, that's fine)

---

### Task 6: Create `scripts/audit-linux.sh`

**Files:**
- Create: `scripts/audit-linux.sh`

**Step 1: Read `scripts/audit-mac.sh` for structure**

Read `scripts/audit-mac.sh` to copy the framework (counters, output helpers, check functions).

**Step 2: Create `scripts/audit-linux.sh`**

Mirror the structure of `audit-mac.sh` but check Linux-specific tools and paths. Copy the helper functions (`pass`, `fail`, `warn`, `section`, `check_cmd`, `check_symlink`, `check_file_exists`, `check_dir_exists`) verbatim from `audit-mac.sh`.

Sections to include (see design doc `audit-linux.sh` table for full list):

1. **Platform** — verify Linux, detect arch
2. **Base apt packages** — check commands: git, git-lfs, tmux, rg, jq, make, gcc, zsh, curl, wget, xclip
3. **fd/bat wrappers** — check `~/.local/bin/fd` and `~/.local/bin/bat` exist and are symlinks
4. **Optional packages** — check commands: eza, zoxide, tree (warn if missing)
5. **Dotfile symlinks (root)** — iterate `$DOTFILES_DIR/*.symlink`, check each `~/.<name>` symlink
6. **Dotfile symlinks (git/)** — iterate `$DOTFILES_DIR/git/*.symlink`, check each
7. **Git core** — check `~/.git-core` -> `$DOTFILES_DIR/git/git-core.symlink`
8. **XDG config dirs** — check nvim, yazi, tmux, starship, git (NOT kitty)
9. **tmux.conf** — check `~/.tmux.conf` symlink
10. **Zsh environment** — `~/.zshrc`, `~/.zprofile`, `~/.zshenv` symlinks, `~/.zsh/env` symlink, oh-my-zsh dir, plugins
11. **Git identity** — `.gituserconfig` (exists + name/email set), `.gitconfig-local`, optional `.kmc`/`.nsv`
12. **Language runtimes** — rustup, rustc, cargo, uv, deno, fnm
13. **Go** — check `/usr/local/go/bin/go` or `go` on PATH
14. **Ruby** — chruby (`/usr/local/share/chruby/chruby.sh`), ruby-install
15. **Binary installs** — nvim in `~/.local/bin`, lazygit in `~/.local/bin`
16. **Starship, fzf** — commands on PATH
17. **Node (optional)** — node, corepack, yarn, pnpm (warn if missing)
18. **Cargo tools** — viu, tectonic, yazi
19. **Python tooling** — ruff, neovim python venv + pynvim
20. **LLM** — llm + plugins (anthropic, gemini, openai, mistral, mlx), template symlink at `~/.config` path
21. **AI CLIs** — claude, opencode + config symlink
22. **Standard dirs** — `~/.local/bin`, `~/.config`
23. **Default shell** — zsh via `getent passwd`
24. **pbcopy/pbpaste** — wrapper scripts in `~/.local/bin`
25. **Summary** — pass/fail/warn counts

Key differences from `audit-mac.sh`:
- No Homebrew, cask, or font checks
- No macOS defaults spot-checks
- No `~/Library` visibility check
- No Spotlight exclusion checks
- Go checked at `/usr/local/go/bin/go` (not via brew)
- chruby checked via file existence (`/usr/local/share/chruby/chruby.sh`)
- fd/bat checked as symlink wrappers in `~/.local/bin`
- Shell detected via `getent passwd` (not `dscl`)
- pbcopy/pbpaste checked as wrapper scripts
- `check_symlink` must handle Linux `readlink` (no `-f` needed for basic readlink check — the mac audit's `check_symlink` uses `readlink` without `-f` and works on both)

**Step 3: Make executable**

Run: `chmod +x scripts/audit-linux.sh`

**Step 4: Shellcheck**

Run: `shellcheck scripts/audit-linux.sh`
Expected: 0 errors

**Step 5: Commit**

```bash
git add scripts/audit-linux.sh
git commit -m "feat: add Linux dev environment audit script"
```

---

### Task 7: Update `docs/bootstrap.md`

**Files:**
- Modify: `docs/bootstrap.md`

**Step 1: Read current docs**

Read `docs/bootstrap.md` to understand current content.

**Step 2: Update to reflect new architecture**

Key changes:
- Update the usage commands at the top: single `scripts/bootstrap.sh` instead of two scripts
- Update "Current Architecture" section: describe the `bootstrap.sh` + `lib/` structure instead of two separate scripts
- Update phase tables to show the unified 9-phase ordering
- Update "Platform Differences" to reference `lib/platform-mac.sh` and `lib/platform-linux.sh`
- Update "Auditing" section to include `scripts/audit-linux.sh`
- Update "Future Direction" section — the consolidation is now DONE, so this section should note what was accomplished and any remaining opportunities

Do NOT change sections that are still accurate (symlink conventions, env vars, topic structure, git identity, adding new tools).

**Step 3: Commit**

```bash
git add docs/bootstrap.md
git commit -m "docs: update bootstrap.md to reflect consolidated architecture"
```

---

### Task 8: Remove old scripts and final verification

**Files:**
- Delete: `scripts/bootstrap-mac.sh`
- Delete: `scripts/bootstrap-linux-dev.sh`

**Step 1: Final audit check**

Run: `bash scripts/audit-mac.sh`
Expected: Same results as Task 5. The audit doesn't check bootstrap scripts — it checks the installed state.

**Step 2: Remove old scripts**

```bash
git rm scripts/bootstrap-mac.sh scripts/bootstrap-linux-dev.sh
```

**Step 3: Grep for stale references**

Run: `grep -r 'bootstrap-mac\|bootstrap-linux-dev' docs/ scripts/`
Expected: No references. If any found in docs, update them to reference `bootstrap.sh`.

**Step 4: Final commit**

```bash
git add -A
git commit -m "refactor: remove old bootstrap-mac.sh and bootstrap-linux-dev.sh

Replaced by unified scripts/bootstrap.sh + lib/common.sh +
lib/platform-mac.sh + lib/platform-linux.sh.

See docs/plans/2026-02-14-bootstrap-consolidation-design.md for details."
```

---

## Summary

| Task | Creates/Modifies | Key risk |
|------|-----------------|----------|
| 1 | `scripts/lib/common.sh` | Platform checks in merged functions must match current behavior exactly |
| 2 | `scripts/lib/platform-mac.sh` | Must preserve brew_bundle ordering (after symlinks) |
| 3 | `scripts/lib/platform-linux.sh` | Must include all linux-only tools (go, appimage, ruby, pbcopy) |
| 4 | `scripts/bootstrap.sh` | Phase ordering: symlinks before platform_packages |
| 5 | (verification only) | Confirms no regression on macOS |
| 6 | `scripts/audit-linux.sh` | Must check all linux-specific paths and tools |
| 7 | `docs/bootstrap.md` | Must accurately describe new architecture |
| 8 | Removes old scripts | Must not leave stale references |
