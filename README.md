# dotfiles

Personal dev environment for macOS and Linux. One command, zero to usable.

Follows [holman/dotfiles](https://github.com/holman/dotfiles) topic-based organization — each tool gets its own directory with its configuration alongside it.

## Quick Start

```bash
git clone https://github.com/kevinmcmahon/dotfiles.git ~/dotfiles
cd ~/dotfiles
scripts/bootstrap.sh
```

The script auto-detects macOS or Linux and is safe to re-run (idempotent).

## What Gets Installed

- **Shell** — zsh, starship prompt, fzf, tmux
- **Editors** — Neovim, Helix, VS Code config
- **Runtimes** — Rust, Python (uv), Deno, optionally Node.js (fnm)
- **CLI tools** — yazi, lazygit, ripgrep, bat, and more via Homebrew/apt
- **AI tools** — Claude Code, llm, OpenCode

## How It Works

- **Topic directories** (`git/`, `zsh/`, `nvim/`, etc.) hold per-tool config
- **`*.symlink` files** are linked into `$HOME` as dotfiles (e.g. `git/gitconfig.symlink` → `~/.gitconfig`)
- **XDG config dirs** are linked into `~/.config/` (e.g. `kitty/` → `~/.config/kitty/`)
- **Platform auto-detection** — a single `bootstrap.sh` entry point delegates to `lib/platform-mac.sh` or `lib/platform-linux.sh`

## Repository Structure

```
dotfiles/
├── scripts/
│   ├── bootstrap.sh           # main entry point
│   ├── lib/
│   │   ├── common.sh          # shared install functions
│   │   ├── platform-mac.sh    # macOS-specific installs
│   │   └── platform-linux.sh  # Linux-specific installs
│   ├── audit-mac.sh           # verify macOS install state
│   └── audit-linux.sh         # verify Linux install state
├── claude/                    # Claude Code config (CLAUDE.md, hooks, settings)
├── git/                       # git config + hooks
├── zsh/                       # shell config
├── nvim/                      # Neovim config (XDG)
├── kitty/                     # terminal config (XDG)
├── tmux/                      # tmux config
├── osx/                       # Brewfiles + macOS defaults
└── docs/                      # detailed documentation
```

## Customization

### Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `INSTALL_NODE` | `0` | Set to `1` to install Node.js LTS via fnm |
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS `defaults write` commands |
| `NTFY_TOPIC` | *(unset)* | Set to enable ntfy push notifications for Claude Code hooks |

### Adding a New Tool

1. Create a topic directory (e.g. `mytool/`)
2. Add config files — use `*.symlink` for `$HOME` dotfiles, or the directory itself for XDG config
3. If it needs installation logic, add it to the appropriate phase in `scripts/bootstrap.sh`

## Auditing

Verify your install matches the expected state:

```bash
scripts/audit-mac.sh     # macOS
scripts/audit-linux.sh   # Linux
```

## Documentation

- [Bootstrap System](docs/bootstrap.md) — full architecture, install phases, platform contract
- [macOS Setup](docs/mac-setup.md) — macOS-specific notes and manual steps
- [Linux Networking](docs/linux-networking-setup.md) — Tailscale, firewall, mosh setup
