# Work WSL Dotfiles

This repository is a generated WSL-safe mirror. The source of truth lives
elsewhere; local changes here should be treated as disposable unless they are
manually reviewed and moved back upstream.

It is intentionally conservative. Default setup uses Ubuntu packages only.
Third-party tools require explicit one-by-one flags, and there is no catch-all
installer option.

## Boundary

This mirror is for a work-owned WSL 2 Ubuntu 24.04.x environment. It is designed
to keep personal and work configuration separate.

The mirror intentionally omits:

- Personal Git identities and account routing.
- Personal SSH identity helpers.
- Personal assistant, model, prompt, hook, skill, and token configuration.
  Minimal Claude CLI aliases are allowed, but personal Claude state is not
  exported.
- Public push-notification service configuration.
- Home-network, printer, cloud-server, and remote-access setup.
- Clipboard/display helpers unless you add them yourself locally.

If a file is not in this generated repo, assume that was deliberate.

## Bootstrap

Default setup is intentionally conservative and uses Ubuntu packages only:

```bash
scripts/bootstrap-wsl-work.sh
```

The default bootstrap installs core terminal/dev packages from Ubuntu
repositories and creates generated symlinks for Git, Zsh, Zsh functions, tmux,
and Starship. It is safe to rerun.

If apt packages are already installed, refresh symlinks and optional tools with:

```bash
scripts/bootstrap-wsl-work.sh --skip-apt
```

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

There is no catch-all option. That is intentional. Optional tools may use
upstream installers or release downloads, so confirm they are acceptable before
enabling them.

Each optional tool records an enable marker in `~/.work-wsl/enabled-tools`.
Node is installed through `fnm`; bootstrap also links `node`, `npm`, `npx`, and
`corepack` into `~/.local/bin` from fnm's default alias. Yazi is installed
through the current `yazi-build` Cargo package.

## SSH Keys

SSH agent reuse is handled by `keychain`. Add one private key path per line to
`~/.work-wsl/ssh-keys`, or set `WORK_WSL_SSH_KEYS` to a colon-separated list of
private key paths. Missing files are ignored.

## Audit

Run the audit any time:

```bash
scripts/audit-wsl-work.sh
```

The audit checks WSL/Ubuntu version, required packages, generated symlinks,
Git identity boundaries, blocked token/tool markers, and whether optional tools
were explicitly enabled.

Treat a failing audit as a setup failure. The goal is not just a usable shell;
the goal is a usable shell with clear work/personal boundaries.

## Git Identity

Bootstrap creates `~/.gituserconfig.work` if it is missing. Fill it in with
work-approved values before committing:

```ini
#[user]
#	name = Your Name
#	email = you@example.com
```

The generated Git config does not provide a personal fallback identity.

## Updates

Pull updates from the generated mirror remote, then rerun:

```bash
scripts/bootstrap-wsl-work.sh
scripts/audit-wsl-work.sh
```

Do not hand-maintain this repository. If a local improvement should become
durable, move it back to the source repo's WSL mirror inputs after review.

## Troubleshooting

If bootstrap warns that `/run/user/$(id -u)` is missing, user runtime services
may not work correctly. Fix that once with
`sudo loginctl enable-linger $USER`, then run `wsl.exe --shutdown` from Windows
before retrying.
