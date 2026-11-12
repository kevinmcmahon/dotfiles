# Bootstrap System

One-command setup for macOS and Linux dev environments. Safe to re-run at any time.

```bash
scripts/bootstrap.sh                     # auto-detects macOS or Linux
scripts/bootstrap.sh --profile workstation # explicit form of the default
scripts/bootstrap.sh --profile server      # fixed headless Linux operator profile
INSTALL_NODE=0 scripts/bootstrap.sh      # skip Node.js LTS
INSTALL_AI_SKILLS=1 scripts/bootstrap.sh # also install third-party AI skills
SKIP_DEFAULTS=1 scripts/bootstrap.sh     # skip macOS system defaults
```

> **Work WSL is different.** Do not use this personal bootstrap directly on a
> work-owned WSL machine. Generate and clone the work-safe mirror described in
> [Work WSL Mirror](work-wsl.md) instead.

## Bootstrap Profiles

With no argument, `scripts/bootstrap.sh` uses the `workstation` profile. The
explicit `--profile workstation` form runs the same phase sequence.

The Linux-only `server` profile installs this fixed package set:

```text
ca-certificates curl git git-lfs jq zsh tmux neovim ripgrep fd-find bat fzf
less tree htop rsync unzip openssh-client dnsutils iproute2 procps lsof
```

It links only the main Git config and ignore file, the Zsh entry files and
layered environment, and `tmux.conf`. It installs no language runtime, AI CLI,
AI configuration, private shell overlay, full Neovim configuration, or macOS
asset. Networking remains a separate step.

Bootstrap writes the selected non-secret profile name to
`~/.config/dotfiles/profile`. Shell startup treats a missing or invalid marker
as `workstation`. The `server` marker skips private overlays and tool runtime
hooks while retaining the shared shell, tmux, and Git experience.

## Goals

- **One command** — a fresh machine goes from zero to usable dev environment
- **Idempotent** — every function checks state before acting; re-running skips what's already done
- **No root entry point** — scripts run as your user; `sudo` is used internally only where needed (apt, chsh)
- **Platform-aware** — single entry point auto-detects macOS or Linux; platform-specific logic lives in dedicated modules

## Philosophy

This repo follows the [holman/dotfiles](https://github.com/holman/dotfiles) convention of **topic-based organization**: each tool or concern gets its own directory (e.g., `git/`, `zsh/`, `nvim/`, `tmux/`). Configuration lives next to the tool it configures.

Key design decisions:

- **`*.symlink` files** are symlinked into `$HOME` as dotfiles (e.g., `git/gitconfig.symlink` -> `~/.gitconfig`)
- **Repo-owned static XDG config** is symlinked into `~/.config/` (e.g., `nvim/` -> `~/.config/nvim/`)
- **Mutable local state stays local** — if a tool needs plugins, caches, or generated state beside its config, bootstrap creates a real local directory and symlinks only the repo-owned files into it
- **Dotfile management is separate from provisioning** — the bootstrap scripts handle tool installation, while the topic directories hold configuration. They meet at the symlink phase.
- **Templates for secrets** — files containing personal data (git identity) use `.template` files that are copied (not symlinked) and `.gitignore`'d, so they never leak into the repo

Current examples:

- `ghostty/` is pure repo-owned config, so the whole topic is symlinked to `~/.config/ghostty`
- `tmux` needs a writable local plugin directory for TPM, so bootstrap manages a real `~/.config/tmux/` directory and symlinks `tmux/tmux.conf` into it

## Architecture

### File Layout

```
scripts/
  bootstrap.sh              # Single entry point — auto-detects platform
  lib/
    common.sh               # Shared utilities + cross-platform installers
    expected-state.sh       # Expected links, copies and real dirs (bootstrap applies, audit checks)
    platform-mac.sh         # macOS-specific: brew, xcode, cask, defaults
    platform-linux.sh       # Linux-specific: apt, appimage, manual binaries
    audit.sh                # Audit helpers and sections shared by both audits
  audit-mac.sh              # macOS environment audit
  audit-linux.sh            # Linux environment audit
work-wsl/
  export-manifest.txt       # tracked-file allowlist for the work WSL mirror
  overrides/                # work-safe generated replacements
```

`bootstrap.sh` detects the platform via `uname -s`, sources `lib/common.sh` for shared logic, then sources the appropriate `lib/platform-*.sh`. The install order is defined exactly once in `bootstrap.sh`'s `main()` function. Platform modules implement a contract of 8 functions that differ by OS; common.sh handles everything that works the same everywhere.

### Bootstrap Phases (`scripts/bootstrap.sh`)

| Phase | What it does | Defined in |
|-------|-------------|-----------|
| 1. Foundation | Preflight checks, create dirs, package manager + git | `platform-*.sh` |
| 2. Dotfile Symlinks | `*.symlink` -> `~/.<name>`, git identity templates, XDG config dirs | `common.sh` |
| 3. Platform Packages | Remaining platform tools (brew bundle, cask apps / go, nvim, lazygit, etc.) | `platform-*.sh` |
| 4. Shell Environment | oh-my-zsh, plugins, shell symlinks, set default shell | `common.sh` + `platform-*.sh` |
| 5. Language Runtimes | Rust/rustup, uv, Deno, Bun, optionally Node.js (fnm + corepack) | `common.sh` + `platform-*.sh` |
| 6. Dev Tooling | Neovim Python venv, ruff, llm + plugins, llm templates | `common.sh` |
| 7. AI/Dev CLIs | Claude Code, Codex, OpenCode, AI config symlinks, then a warn-only audit of the Claude Code and Codex config | `common.sh` |
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
| yazi | Homebrew | `cargo install --locked` |
| jless | Homebrew | `cargo install --locked` |
| delta | N/A | `cargo install --locked git-delta` |
| Go | Homebrew | Official tarball to `/usr/local/go` |
| Ruby | `brew install chruby ruby-install` | Manual install from source |
| Terminal app | Official cmux DMG -> `/Applications/cmux.app` + `~/.local/bin/cmux` symlink | N/A |
| GUI apps | Homebrew Cask (tailscale) | N/A (server environment) |
| macOS defaults | `defaults write` | N/A |
| XDG dirs | nvim, yazi, starship, git, ghostty; tmux uses a managed `~/.config/tmux/` dir with symlinked `tmux.conf` | Same |
| fd/bat | Homebrew (`fd`, `bat`) | apt (`fdfind`, `batcat`) + symlinks |
| fnm | Homebrew | curl installer -> `~/.local/bin` |
| pbcopy/pbpaste | Native | xclip wrapper scripts |

## Symlink Conventions

| Source pattern | Destination | Example |
|---------------|------------|---------|
| `<root>/*.symlink` | `~/.<name>` | `tools/aider.conf.yml.symlink` -> `~/.aider.conf.yml` |
| `git/*.symlink` | `~/.<name>` | `git/gitconfig.symlink` -> `~/.gitconfig` |
| `homebrew/*.symlink` | `~/.<name>` | `homebrew/Brewfile.symlink` -> `~/.Brewfile` |
| `git/git-core.symlink/` | `~/.git-core/` | Hooks and secrets directory |
| `/Applications/cmux.app/Contents/Resources/bin/cmux` | `~/.local/bin/cmux` | cmux CLI symlink for shell use |
| `zsh/zshrc.symlink` | `~/.zshrc` | Handled by `zsh/install.sh` |
| `zsh/zshenv.symlink` | `~/.zshenv` | Handled by `zsh/install.sh` |
| `zsh/zprofile.symlink` | `~/.zprofile` | Handled by `zsh/install.sh` |
| `nvim/`, `yazi/`, `starship/`, `git/`, `ghostty/` | `~/.config/nvim/`, `~/.config/yazi/`, `~/.config/starship/`, `~/.config/git/`, `~/.config/ghostty/` | Whole-directory XDG symlinks |
| `tmux/tmux.conf` | `~/.config/tmux/tmux.conf` | tmux uses a real XDG dir so plugins can live beside the symlinked config |
| `uv/uv.toml` | `~/.config/uv/uv.toml` | uv user config (release-age cooldown). uv writes its own files into `~/.config/uv/`, so the directory stays real and only `uv.toml` is linked |
| `bun/bunfig.toml` | `~/.bunfig.toml` | Bun user config (release-age cooldown) |
| `zsh/env/` | `~/.zsh/env/` | Layered zsh environment |
| `llm/templates.symlink/` | `<llm-data>/templates/` | llm template directory |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code global instructions |
| `claude/commands/` | `~/.claude/commands/` | Claude Code slash commands |
| `claude/docs/` | `~/.claude/docs/` | Claude Code reference docs |
| `ai/docs/{common,claude}` | `claude/docs/` | Generated Claude Code docs symlink farm |
| `claude/hooks/` | `~/.claude/hooks/` | Claude Code hook scripts; the audit checks each `*.sh` is executable |
| `claude/scripts/` | `~/.claude/scripts/` | Claude Code helper scripts (statusline) |
| `ai/skills/{common,claude}` | `~/.claude/skills/` | Dotfiles-owned Claude Code skills injected by `scripts/ai-sync.sh` into a real local skills directory |
| `claude/mcp.json` | `~/.claude/mcp.json` | Claude Code MCP config copied only when missing. The repo file is gitignored and machine-local, so a fresh clone has none to copy; bootstrap and the audit warn until the file exists |
| `claude/claude_desktop_config.json` | `~/.claude/claude_desktop_config.json` | Claude Desktop config, copied only when missing. Gitignored and machine-local like `mcp.json` |
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code settings (hooks, plugins) copied only when missing. Claude Code saves this file by replacing it, so a symlink would not survive; the audit warns when the local copy differs from the repo copy |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` | Codex global instructions |
| `codex/config.toml.template` | `~/.codex/config.toml` | Codex safe defaults copied only when missing, mode 600 |
| `codex/hooks.json.template` | `~/.codex/hooks.json` | Codex hook defaults copied only when missing |
| `codex/hooks/ntfy-notify.sh` | `~/.codex/hooks/ntfy-notify.sh` | Optional Codex ntfy notification hook |
| `codex/rules/default.rules.template` | `~/.codex/rules/default.rules` | Codex exec rules copied only when missing |
| `ai/skills/{common,codex}` | `~/.codex/skills/` | Dotfiles-owned Codex user skills generated by `scripts/ai-sync.sh` |
| `opencode/commands/`, `opencode/docs/` | `~/.opencode/commands/`, `~/.opencode/docs/` | Generated OpenCode command/doc symlink farms |
| `opencode/opencode.json.symlink` | `~/.config/opencode/opencode.json` | OpenCode config |
| `ai/docs/{common,opencode}` | `opencode/docs/` | Generated OpenCode docs symlink farm |
| `ai/skills/common` | `~/.opencode/skills/` | Dotfiles-owned OpenCode skills injected by `scripts/ai-sync.sh` into a real local skills directory |

### Expected links, copies and real directories

`scripts/lib/expected-state.sh` lists the fixed XDG, tmux, uv, Bun, Claude Code,
Codex and OpenCode entries from the table above, one row per destination, each with
one of three kinds:

| Kind | Bootstrap | Audit |
|------|-----------|-------|
| `link` | Links the destination to the repo source, backing up anything else there; warns and moves on when the source is missing | Passes the expected symlink; fails anything else |
| `real-dir` | Creates the directory; a symlink in its place is moved to `.bak.<timestamp>` first | Fails a symlink or a missing directory |
| `copy-once` | Copies the repo source when the destination is missing, applying the row's mode if it has one; turns a leftover symlink into a local file with the same content; never touches an existing regular file; warns when neither the file nor its source exists | Fails a symlink, or a missing file whose source exists; warns when both are missing; passes a regular file |

`common.sh` applies these rows and `audit.sh` checks the same rows, so adding a
destination to the list covers both. The list also names the generated common
AI skills that each tool's audit section checks, and the npm config keys of the
[package install policy](#package-install-policy). The `*.symlink` loops, Git
identity templates, platform-only links, llm templates and the server profile
keep their own code. `tests/expected_state.bats` fails when a destination in the
list is missing from this document.

At the end of phase 7, bootstrap runs the audit's Claude Code and Codex
sections in a subshell. Failures there print as warnings and never stop
bootstrap.

Existing files are backed up with a `.bak.<timestamp>` suffix before being replaced. Generated AI resource sync is more conservative: `scripts/ai-sync.sh` converts identical generated file copies back into symlinks, skips divergent non-symlink conflicts, and only removes stale symlinks that point back into `ai/`.
`~/.claude/skills` is a real local directory. Dotfiles-owned skills are injected
there as symlinks by `scripts/ai-sync.sh`, while third-party skills are declared
in `ai/skills-manifest.toml` and installed by `scripts/install-ai-skills.sh` via
`npx skills` for Claude Code, Codex, and OpenCode. Bootstrap runs that
third-party install only when `INSTALL_AI_SKILLS=1` is set.
`~/.agents/.skill-lock.json` remains local package-manager state.
`~/.opencode/skills` follows the same local-directory model as Claude skills;
OpenCode commands and docs remain generated repo-side symlink farms.

Home-grown skills are inventoried in `ai/homegrown-skills.md`; packageable
candidates should move to a separate skills repository before becoming
`npx skills` installs.

### Package install policy

A compromised package release is usually reported and removed within days, and
its usual payload is an install script. Bootstrap therefore makes uv, Bun and npm
wait before they will install a new release, and makes npm refuse install
scripts nobody has approved. pnpm, yarn and Deno are not covered; they do not
read these settings. cargo is handled separately, below the table.

| Tool | Setting | Where | Effect |
|------|---------|-------|--------|
| uv | `exclude-newer = "7 days"` | `uv/uv.toml`, linked to `~/.config/uv/uv.toml` | Resolves only to files uploaded at least 7 days ago |
| Bun | `minimumReleaseAge = 604800` | `bun/bunfig.toml`, linked to `~/.bunfig.toml` | Installs only versions published at least 7 days ago |
| npm | `min-release-age=7` | `~/.npmrc`, set by `setup_node` | Installs only versions published at least 7 days ago |
| npm | `strict-allow-scripts=true` | `~/.npmrc`, set by `setup_node` | Fails the install when a dependency has an install script that is not approved, naming the package |

Bootstrap runs every `cargo install` with `--locked`, so a tool is built
against the dependency versions in its published `Cargo.lock` and not against
whatever is newest on the day of the install. yazi gets less from the flag:
`yazi-build` is an installer whose build script clones Yazi's `shipped` ref
from GitHub and builds that checkout with its own `--locked`, so the flag pins
only the installer's dependencies and the Yazi source is whatever that ref
points to at install time.

npm writes credentials and local settings to `~/.npmrc`, so that file stays
local and bootstrap sets the two keys with `npm config set`. The keys and
values are listed once, in `expected_npm_config` in
`scripts/lib/expected-state.sh`; `setup_node`, `node/install.sh` and the audits
all read that list. Both keys exist in npm 11.19. An npm that does not know a
key rejects `npm config set` for it, so bootstrap skips that key with a
warning and the audit fails until Node is upgraded (`fnm install --lts`, then
rerun `node/install.sh`). Bun gets no script setting: it runs a dependency's
install script only when the package is on its built-in list
(`bun pm default-trusted`) or the project lists it under
`trustedDependencies`.

Bun reads `~/.bunfig.toml` only while `XDG_CONFIG_HOME` is unset, which is how
this repo leaves it. With the variable set, Bun looks for
`$XDG_CONFIG_HOME/.bunfig.toml` instead and the cooldown stops applying.

Without `strict-allow-scripts`, npm runs an unapproved install script and only
prints a warning afterwards. With it, the install stops before anything is
written:

```
npm error code ESTRICTALLOWSCRIPTS
npm error --strict-allow-scripts: 1 package(s) have install scripts not covered by allowScripts:
npm error   esbuild@0.28.2 (postinstall: node install.js)
```

npm's hint to run `npm install-scripts approve` fails at this point with
`ENOMATCH`, because approval only matches packages that are already installed.
Install without scripts first, then approve and run the script:

```bash
npm install --ignore-scripts          # or: npm ci --ignore-scripts
npm install-scripts ls                # the packages waiting for review
npm install-scripts approve <pkg>     # after reading what the script does
npm rebuild <pkg>                     # runs the approved script
```

Approval records the package and version under `allowScripts` in the project's
`package.json`, so it is a one-time step per project and per version once that
file is committed. `npm install -g` and `npx` have no `package.json`; pass
`--allow-scripts=<pkg>` to them instead. Bootstrap does this for Gemini CLI,
whose optional native modules (`@github/keytar`, `node-pty`) have install
scripts.

What else this changes in daily use:

- A project's own scripts and hooks (`prepare`, `pre*`, `post*`) still run.
  The policy covers the install scripts of dependencies only.
- A release newer than 7 days is invisible to all three tools. To take one
  deliberately, override for that command: `npm install --min-release-age=0`,
  `uv ... --exclude-newer <date>`, or a project-level `bunfig.toml`.
- `uv lock` records the cooldown in the project's `uv.lock` under `[options]`,
  so a lockfile written on this machine carries it to anyone else who uses
  that lockfile.

The audits check the two links and the npm keys in their "Package Install
Policy" section.

### Claude Code plugins

Plugins are not symlinked out of this repo. `claude/settings.json` declares them
in `enabledPlugins` and `extraKnownMarketplaces`; Claude Code fetches them from
their marketplaces and records the result in
`~/.claude/plugins/installed_plugins.json` and
`~/.claude/plugins/known_marketplaces.json`. Both audit scripts compare the
declaration against those records, so a plugin enabled in settings but never
installed — or a marketplace pointing at a different repo than declared — shows
up as drift. Plugins declared `false` are off on purpose and are not checked.

Plugins ending in `@builtin` ship with Claude Code and have no marketplace
install record. The audits report them separately without claiming they are
available in the current session. Check `/plugin` → **Installed** inside Claude
Code for that. See the [plugin commands reference](https://code.claude.com/docs/en/plugins/cli-reference#plugin-details).

Adding a plugin therefore means editing `claude/settings.json`, not adding a
symlink. Bootstrap never overwrites an existing `~/.claude/settings.json`, so
on a machine that already has one, make the same change there too. `perplexity@pplx-search` (from `kevinmcmahon/pplx-search`) is the
current example: the skill and its `pplx-search` CLI ship from that repo rather
than living under `ai/skills/`.

### The shared `~/.agents/skills` store

The `skills` CLI installs into one shared store at `~/.agents/skills/`. Codex,
OpenCode, Gemini CLI, and Antigravity read that directory directly; only Claude
Code needs a shim, so the CLI also drops `~/.claude/skills/<name>` symlinks
pointing back into the store.

This matters when auditing: a skill missing from `~/.codex/skills/` is not
missing from Codex. Check `~/.agents/skills/` instead, or run
`npx skills list -g`, which prints each skill's store path and the agents it is
registered for. `~/.agents/.skill-lock.json` is that CLI's own state and stays
local — never committed.

A skill hand-symlinked into the store works but has no lock entry, so it reports
`Source: local`, carries no upstream ref, and `npx skills update` cannot touch
it. Install through the manifest instead of symlinking by hand.

### Perplexity skill

The perplexity skill and its `pplx-search` CLI ship from
`kevinmcmahon/pplx-search`. Each agent family gets it a different way:

- **Claude Code** — the `perplexity@pplx-search` plugin declared in
  `claude/settings.json`.
- **Codex and OpenCode** — the `[[external]]` `pplx-search` manifest entry,
  installed by `scripts/install-ai-skills.sh` into `~/.agents/skills/perplexity`.
- **`PATH`** — `ensure_pplx_search_bin` links
  `~/.agents/skills/perplexity/pplx-search` to `~/.local/bin/pplx-search` so the
  CLI works outside an agent session.

The manifest entry deliberately omits `claude-code` from its `agents` list;
adding it would install a second copy alongside the plugin.

Both audit scripts verify that `~/.agents/skills/perplexity` resolves and holds a
`SKILL.md` plus an executable `pplx-search`, and that `~/.local/bin/pplx-search`
is executable.

Changes to the skill itself are made in its own repo, not here. Push them, then
pull them into the store the supported way:

```bash
npx skills update perplexity
```

That re-resolves the GitHub source and refreshes `~/.agents/skills/perplexity`
along with its lock entry. Run `scripts/install-ai-skills.sh` afterwards to
record the new ref in `reviewed_ref` and `reviewed_at`.

Codex user skills are installed or symlinked under `~/.codex/skills`.

Codex hook implementations live under `ai/scripts/codex/`. Codex-facing hook
paths stay under `codex/hooks/` and are symlinked into `~/.codex/hooks/`.
Claude Code lifecycle hooks and `claude-mem` stay out of Codex unless they are
explicitly reintroduced as Codex-compatible plugins.

### Sentry MCP (per-project, not global)

The Sentry MCP server (`https://mcp.sentry.dev/mcp`, remote HTTP with OAuth) is
scoped to Sentry-using projects so its tools do not load in every session:

- **Codex**: `codex/config.toml.template` registers `[mcp_servers.sentry]` with
  `enabled = false`. Authenticate once per machine with `codex mcp login sentry`,
  then enable it inside a Sentry project with
  `codex -c mcp_servers.sentry.enabled=true`. Machines whose `~/.codex/config.toml`
  predates the template entry need the block copied in by hand (the template is
  only copied when the config is missing); the audit scripts check for it.
- **Claude Code**: no global entry. Check a project-scope `.mcp.json` into each
  Sentry-using repo:

  ```json
  {
    "mcpServers": {
      "sentry": { "type": "http", "url": "https://mcp.sentry.dev/mcp" }
    }
  }
  ```

  `enableAllProjectMcpServers` is set in `claude/settings.json`, so the server
  loads automatically there. Authenticate once via `/mcp` in a session. OAuth
  tokens for both tools are machine-local state and stay out of the repo.

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOTFILES_DIR` | `$HOME/dotfiles` | Root of the dotfiles repo |
| `LOCAL_BIN` | `$HOME/.local/bin` | User-local binaries (added to PATH) |
| `CONFIG_DIR` | `$HOME/.config` | XDG config base directory |
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS system defaults (mac only) |
| `INSTALL_NODE` | `1` | Set to `0` to skip Node.js LTS via fnm + corepack |
| `INSTALL_AI_SKILLS` | `0` | Set to `1` to install third-party AI skills declared in `ai/skills-manifest.toml` |
| `NTFY_TOPIC` | *(unset)* | ntfy topic for Claude Code and Codex push notifications (required for ntfy) |
| `NTFY_SERVER` | `https://ntfy.sh` | ntfy server URL (optional, for self-hosted) |
| `NTFY_PRIORITY` | `high` | ntfy notification priority (min/low/default/high/urgent) |

## Topic Directory Structure

A topic directory can contain any combination of:

```
<topic>/
  *.symlink          # Symlinked to ~/.<name> by bootstrap
  install.sh         # Standalone installer (can run independently)
  README.md          # Documentation for the topic
  <config files>     # Repo-owned XDG config (whole-dir symlink when the tool supports it)
```

If a tool writes mutable state inside its config directory, keep the local directory real and symlink only the repo-owned files into it. `tmux` is the current example of this exception.

Current topics: `ai`, `bash`, `bun`, `claude`, `codex`, `gemini`, `ghostty`, `git`, `helix`, `iterm2`, `kitty`, `linux`, `lldb`, `llm`, `node`, `nvim`, `opencode`, `osx`, `rvm`, `starship`, `tmux`, `tools`, `uv`, `vale`, `vscode`, `yazi`, `zsh`

## Standalone Installers

Some topics have `install.sh` scripts that work independently of the main bootstrap:

### `node/install.sh`
Installs Node.js LTS via fnm + corepack. Prerequisites: fnm on PATH. Handles fnm env setup, LTS install, setting the default, setting npm's global prefix to `~/.local`, setting the npm keys of the [package install policy](#package-install-policy), and enabling corepack (provides yarn and pnpm).

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
    local.zsh      # Machine-specific non-secret local overrides (gitignored)
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
2. **Add config files** — if the tool's XDG directory is pure repo-owned config, add the topic to the shared XDG list so it symlinks to `~/.config/<tool>/`
3. **Handle mutable state explicitly** — if the tool keeps plugins, caches, or generated state inside its config directory, create a real local XDG directory and symlink only the repo-owned files into it
4. **Add `*.symlink` files** — for files that need to live at `~/.<name>`
5. **Optionally add `install.sh`** — if the tool needs a standalone installer
6. **Update the bootstrap** — add the install function to `lib/common.sh` (if cross-platform) or the appropriate `lib/platform-*.sh` (if platform-specific), and call it from `main()` in `bootstrap.sh`. If it uses whole-dir XDG symlinking, add the topic name to `expected_state_xdg` in `lib/expected-state.sh`; bootstrap and both audits pick it up from there.
7. **Update the audit scripts** — add checks for the new tool's commands and config. Links, copied templates and real directories listed in `lib/expected-state.sh` are already checked; any other local-state layout needs its own check. A check that applies to both platforms goes in `lib/audit.sh`, inside an `audit_section_*` function that both `audit-mac.sh` and `audit-linux.sh` call. A platform-only check goes in that platform's audit script.

## Auditing

### `scripts/audit-mac.sh`

Read-only script that checks for configuration drift. Run anytime to see what's missing or misconfigured:

```bash
scripts/audit-mac.sh
```

The pass/fail/warn helpers, the sections that are identical on both platforms, and the summary live in `scripts/lib/audit.sh`. Each audit script sources that library from its own directory and keeps only its platform-specific checks.

It checks:
- Platform and architecture
- Xcode CLT and Homebrew installation
- All expected brew formulae and casks
- cmux app install and CLI symlink
- Nerd fonts
- Every `*.symlink` file has a correct symlink in place
- XDG config directory symlinks
- tmux XDG layout (`~/.config/tmux/`, symlinked `tmux.conf`, TPM plugin dir)
- Zsh environment (oh-my-zsh, plugins, shell symlinks)
- Git identity files (existence + whether name/email are set)
- Language runtimes (rust, go, uv, deno, bun, fnm, chruby, node)
- Package install policy (uv and Bun config symlinks, npm `min-release-age` and `strict-allow-scripts`)
- Cargo/brew tools (viu)
- Python tooling (ruff, neovim python venv)
- LLM tool + plugins + template symlinks
- AI CLIs (claude, codex, opencode), Claude/Codex/OpenCode config symlinks, copied config files, real skills directories, executable Claude and Codex hooks, and generated common AI docs
- Claude Code plugins and marketplaces declared in `claude/settings.json` are actually installed
- Perplexity skill is provisioned for Codex and OpenCode, with `pplx-search` on `PATH`
- Standard directories (`~/.local/bin`, `~/.config`)
- Default shell
- macOS defaults (spot-checks key settings)
- Spotlight exclusions
- ~/Library visibility

Output: pass/fail/warn counts with a summary. Exit code 1 if any failures.

### `scripts/audit-wsl-work.sh`

This script lives in the generated work WSL mirror, not in the personal
bootstrap path. It is exported from `work-wsl/overrides/scripts/` and checks the
enterprise-safe WSL contract:

- WSL 2 and Ubuntu 24.04.x
- Required apt-only core packages
- Generated Git, Zsh, tmux, and Starship symlinks
- Work-only Git identity boundaries
- Absence of excluded personal, notification, token, and AI-tool markers
- Optional tools are present only when explicitly enabled

Run it inside WSL after bootstrap:

```bash
scripts/audit-wsl-work.sh
```

See [Work WSL Mirror](work-wsl.md) for the full workflow.

### `scripts/audit-linux.sh`

Linux counterpart of the macOS audit. It sources the same `scripts/lib/audit.sh`, so it shares the pass/fail/warn framework, helper functions, cross-platform sections, and summary. Checks:
- Platform and architecture
- Base apt packages (git, tmux, rg, jq, zsh, etc.)
- fd/bat wrapper symlinks in `~/.local/bin`
- Optional packages (eza, zoxide, tree — warns if missing)
- Every `*.symlink` file has a correct symlink in place
- XDG config directory symlinks
- tmux XDG layout (`~/.config/tmux/`, symlinked `tmux.conf`, TPM plugin dir)
- Zsh environment (oh-my-zsh, plugins, shell symlinks)
- Git identity files (existence + whether name/email are set)
- Language runtimes (rust, go, uv, deno, bun, fnm, chruby, ruby-install)
- Package install policy (uv and Bun config symlinks, npm `min-release-age` and `strict-allow-scripts`)
- Binary installs in `~/.local/bin` (nvim AppImage, lazygit)
- Starship and fzf (from non-brew sources)
- Cargo tools (tree-sitter, delta/git-delta, viu, jless, yazi)
- Python tooling (ruff, neovim python venv)
- LLM tool + plugins + template symlinks (at `~/.config` path)
- AI CLIs (claude, codex, opencode), Claude/Codex/OpenCode config symlinks, copied config files, real skills directories, executable Claude and Codex hooks, and generated common AI docs
- Claude Code plugins and marketplaces declared in `claude/settings.json` are actually installed
- Perplexity skill is provisioned for Codex and OpenCode, with `pplx-search` on `PATH`
- Standard directories (`~/.local/bin`, `~/.config`)
- Default shell (via `getent passwd`)
- pbcopy/pbpaste wrapper scripts

Output: pass/fail/warn counts with a summary. Exit code 1 if any failures.

## Linux Peripherals

### Printer (HP Color LaserJet M255dw)

The printer setup is handled automatically by `install_printer_optional` in `platform-linux.sh` during the foundation phase. It:

1. Installs `cups` and `hplip`
2. Copies `linux/HP_M255dw.ppd` to `/etc/cups/ppd/`
3. Adds the printer via `lpadmin` pointing at `ipp://192.168.7.59/ipp/print`

The PPD file is committed at `linux/HP_M255dw.ppd`. **Do not use the `everywhere` driverless driver** — it fails over Tailscale routing. The HP PPD via hplip is required.

To set up manually:

```bash
bash linux/printing.sh
```

To verify:

```bash
lpstat -p HP_M255dw
echo "Test" | lp -d HP_M255dw
```

## Design History

The original bootstrap used two separate scripts (`bootstrap-mac.sh` and `bootstrap-linux-dev.sh`) that shared ~450 lines of duplicated logic. This created drift risk: adding a tool to one script and forgetting the other.

The consolidation (Feb 2026) replaced them with the current `bootstrap.sh` + `lib/` architecture. The install list is now defined exactly once in `bootstrap.sh`'s `main()` function. Platform differences live in dedicated modules with a clear contract. Trivial platform differences (1-3 lines) use inline `$PLATFORM` checks in `common.sh` rather than splitting into separate files.
