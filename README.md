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
- **Editors** — Neovim, Helix (config only), VS Code (config only)
- **Terminals** — cmux app on macOS with Ghostty config under `~/.config/ghostty`
- **Runtimes** — Rust, Go, Python (uv), Deno, Ruby (chruby + ruby-install), optionally Node.js (fnm)
- **CLI tools** — yazi, lazygit, ripgrep, bat, fd, jq, jless, ast-grep, tree-sitter, viu, croc, ttyd, eza, zoxide, and more via Homebrew/apt/cargo
- **AI tools** — Claude Code, Codex, Gemini CLI, OpenCode, llm (with plugins)
- **Python tooling** — ruff, Neovim Python venv (pynvim)

## How It Works

- **Topic directories** (`git/`, `zsh/`, `nvim/`, etc.) hold per-tool config
- **`*.symlink` files** are linked into `$HOME` as dotfiles (e.g. `git/gitconfig.symlink` → `~/.gitconfig`)
- **Repo-owned static XDG config** is linked into `~/.config/` (e.g. `ghostty/` → `~/.config/ghostty/`)
- **Mutable local state stays local** — `tmux` is managed as a real `~/.config/tmux/` directory with a symlinked `tmux.conf`, so TPM plugins do not live inside the repo
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
│   ├── audit-linux.sh         # verify Linux install state
│   ├── claude-migrate-backup.sh   # bundle Claude memory + per-host config
│   └── claude-migrate-restore.sh  # restore bundle on a new host
├── ai/                        # shared AI resources (prompts, templates)
├── bash/                      # bash config
├── claude/                    # Claude Code config (CLAUDE.md, hooks, settings)
├── codex/                     # OpenAI Codex CLI config
├── cursor/                    # Cursor editor config
├── gemini/                    # Google Gemini CLI config
├── ghostty/                   # Ghostty terminal config
├── git/                       # git config + hooks
├── goose/                     # Goose AI config
├── helix/                     # Helix editor config (XDG)
├── iterm2/                    # iTerm2 config (macOS)
├── kitty/                     # Kitty terminal config (historical/reference)
├── linux/                     # Linux-specific files (PPD, scripts)
├── lldb/                      # LLDB debugger config
├── llm/                       # llm tool config + templates
├── node/                      # Node.js installer (fnm)
├── nvim/                      # Neovim config (XDG)
├── opencode/                  # OpenCode config
├── homebrew/                  # Brewfiles (Bootstrap + full) + snapshots
├── osx/                       # macOS defaults + spotlight config
├── rvm/                       # Ruby version manager config
├── starship/                  # Starship prompt config (XDG)
├── tmux/                      # tmux config
├── tools/                     # misc tool configs (*.symlink)
├── vale/                      # Vale prose linter config
├── vscode/                    # VS Code config
├── yazi/                      # Yazi file manager config (XDG)
├── zsh/                       # shell config
└── docs/                      # detailed documentation
```

## Customization

### Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTFILES_DIR` | `$HOME/dotfiles` | Root of the dotfiles repo |
| `LOCAL_BIN` | `$HOME/.local/bin` | User-local binaries (added to PATH) |
| `CONFIG_DIR` | `$HOME/.config` | XDG config base directory |
| `INSTALL_NODE` | `0` | Set to `1` to install Node.js LTS via fnm |
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS `defaults write` commands |
| `NTFY_TOPIC` | *(unset)* | Set to enable ntfy push notifications for Claude Code hooks |
| `NTFY_SERVER` | `https://ntfy.sh` | ntfy server URL (for self-hosted instances) |
| `NTFY_PRIORITY` | `high` | ntfy notification priority level |

### Adding a New Tool

1. Create a topic directory (e.g. `mytool/`)
2. Decide whether it is pure repo-owned config or needs mutable local state
3. Add config files — use `*.symlink` for `$HOME` dotfiles, a whole topic directory for pure XDG config, or file-level symlinks inside a real local dir for mutable-state tools
4. If it needs installation logic, add it to the appropriate phase in `scripts/bootstrap.sh`

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
- [Claude Code on Oracle Cloud](docs/claude-code-oracle-cloud-setup.md) — remote Claude Code setup
- [Oracle Cloud CLI](docs/oracle-cloud-cli.md) — OCI CLI installation
- [Oracle Cloud Terraform](docs/oracle-cloud-terraform.md) — Terraform for OCI provisioning
- [Mutagen + Electron](docs/mutagen-electron-setup.md) — remote Electron development
