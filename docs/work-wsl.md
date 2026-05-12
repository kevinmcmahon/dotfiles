# Work WSL Mirror

This document describes the WSL-specific dotfiles flow for a work-owned Windows
machine running WSL 2 with Ubuntu 24.04.x.

The short version: **do not clone this personal dotfiles repository on the work
machine**. Generate a work-safe mirror from this repo on a personal machine,
inspect it, publish that generated mirror to a work-approved location, then
clone only the generated mirror inside WSL.

## Goals

- Keep personal and work environments clearly separated.
- Avoid moving personal Git identities, SSH assumptions, AI tooling, prompts,
  hooks, notification services, or home-network configuration onto a work
  machine.
- Keep maintenance lightweight by making the personal dotfiles repo the source
  of truth and the work repo a generated artifact.
- Make the work WSL setup rerunnable and auditable.
- Prefer enterprise-safe defaults: Ubuntu packages first, third-party tooling
  only when explicitly requested.

## Boundary Model

The work WSL repository is generated from an allowlist. It is not a fork to edit
by hand and it is not a branch to clone on the work machine.

```text
personal dotfiles repo
        |
        | scripts/export-work-wsl.sh --dest ../dotfiles-work-wsl
        v
generated work-safe repo
        |
        | git push to work-approved remote
        v
WSL Ubuntu 24.04.x work machine
```

The export process copies only tracked files listed in
`work-wsl/export-manifest.txt`, applies work-safe replacements from
`work-wsl/overrides/`, then runs a hard boundary scan. Ignored files and
untracked local state are never eligible for export.

## What Gets Exported

The generated mirror contains a conservative terminal-first setup:

- Work-safe Git config and `git-secrets` hook wiring.
- Minimal Zsh startup, aliases, and environment layering.
- tmux config without personal theme/plugin dependencies.
- Starship config.
- Neovim config with AI-related extras removed.
- WSL-specific bootstrap and audit scripts.

The generated mirror does not include the normal personal Linux bootstrap. It
has its own WSL bootstrap because the work environment has stricter policy and
data-boundary requirements.

## What Is Intentionally Excluded

The generated mirror excludes by default:

- AI assistant CLIs, prompts, skills, hooks, and global config.
- Public push-notification service config or environment variables.
- Personal Git identities, GitHub accounts, credential helpers, and token files.
- Personal SSH identity helpers built around `~/.ssh/identities`.
- Home-network, NAS, printer, Tailscale, Oracle Cloud, and remote-server docs.
- Clipboard/display helpers such as `xclip`.
- Third-party installers run through shell pipes.
- npm global installs, cargo tool installs, GitHub release binaries, and
  AppImages.

The exporter also scans the generated mirror for blocked identity, token,
notification, and AI-tool markers. `git-secrets` regex patterns are the only
allowed exception because they are defensive scanning rules, not real secrets.

## Generate The Mirror

Run this from the personal dotfiles repo:

```bash
scripts/export-work-wsl.sh --dest ../dotfiles-work-wsl
```

The destination is treated as generated output:

- Existing destination content is removed before regeneration.
- A destination `.git/` directory is preserved, so the mirror can be its own
  repo.
- Only tracked allowlisted source files are copied.
- Work-safe override files are applied after copying.
- The export fails if blocked markers appear in generated output.

Recommended publishing workflow:

```bash
scripts/export-work-wsl.sh --dest ../dotfiles-work-wsl
git -C ../dotfiles-work-wsl status --short
git -C ../dotfiles-work-wsl diff
```

Review the generated diff before committing or pushing the work mirror.

## Install In WSL

Inside WSL, clone the generated mirror from a work-approved remote:

```bash
git clone <work-approved-dotfiles-mirror-url> ~/dotfiles
cd ~/dotfiles
scripts/bootstrap-wsl-work.sh
```

The default bootstrap is intentionally apt-only. It installs conservative core
packages from Ubuntu repositories and creates generated symlinks.

Core packages include:

- `ca-certificates`, `curl`, `wget`, `unzip`, `xz-utils`, `tar`
- `git`, `git-lfs`, `git-secrets`
- `jq`, `make`, `gcc`, `g++`, `pkg-config`, `libclang-dev`
- `zsh`, `tmux`, `ripgrep`, `fd-find`, `bat`
- `gpg`, `gawk`, `locales`, `tree`

The default bootstrap is safe to rerun. It should converge on the expected
state without duplicating shell setup or overwriting local work identity files.

## Optional Tools

Optional tools must be requested one by one:

```bash
scripts/bootstrap-wsl-work.sh --with-node
scripts/bootstrap-wsl-work.sh --with-rust
scripts/bootstrap-wsl-work.sh --with-neovim
scripts/bootstrap-wsl-work.sh --with-fzf
scripts/bootstrap-wsl-work.sh --with-starship
scripts/bootstrap-wsl-work.sh --with-lazygit
scripts/bootstrap-wsl-work.sh --with-yazi
```

There is no `--with-all`. That is deliberate. Some optional tools use upstream
installers or release downloads, so they should be enabled only after confirming
they are acceptable for the work environment.

Each optional tool writes a marker to `~/.work-wsl/enabled-tools`. The audit uses
that marker to distinguish intentionally enabled tools from accidental drift.

## Git Identity

The generated Git config has no personal fallback identity. Bootstrap creates
`~/.gituserconfig.work` if it is missing, but leaves it commented out:

```ini
#[user]
#	name = Your Name
#	email = you@example.com
```

Fill it in with work-approved values before committing in work repos. The local
Git routing template maps `~/work/**` to that identity by default.

## Audit

Run the WSL-specific audit after bootstrap and after any manual changes:

```bash
scripts/audit-wsl-work.sh
```

The audit is read-only. It checks:

- WSL 2 and Ubuntu 24.04.x.
- Required apt packages and command wrappers.
- Generated symlinks for Git, Zsh, tmux, and Starship.
- Work Git identity setup.
- Absence of blocked personal, notification, token, and AI-tool markers.
- Absence of blocked global config directories.
- Optional tools are present only when explicitly enabled.

The audit exits nonzero on failures.

## Updating The Work Mirror

When personal dotfiles change and you want to refresh WSL:

1. Update this personal repo normally.
2. Run `scripts/export-work-wsl.sh --dest ../dotfiles-work-wsl`.
3. Review the generated mirror diff.
4. Commit and push the generated mirror to the work-approved remote.
5. Pull the mirror inside WSL.
6. Run `scripts/bootstrap-wsl-work.sh` and `scripts/audit-wsl-work.sh`.

Do not hand-maintain long-lived changes inside the generated mirror. If a work
change should become durable, copy it back into this repo's `work-wsl/` manifest
or overrides after review.

## Troubleshooting

If export fails, read the matching line it prints. Common causes:

- A newly allowlisted file contains a blocked marker.
- An override file references a personal path or excluded tool.
- A generated symlink points outside the mirror.
- A local untracked file was added under `work-wsl/overrides/`.

If WSL audit fails, fix the reported category rather than bypassing it. The audit
is part of the boundary; a clean bootstrap without a clean audit is not a
complete setup.
