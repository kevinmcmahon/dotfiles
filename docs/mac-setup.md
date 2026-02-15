# macOS Dev Bootstrap Guide

Set up a fresh macOS machine for development using the automated bootstrap script.

## Overview

The `bootstrap.sh` script auto-detects macOS and configures a complete development environment:

- **Xcode Command Line Tools** (no Apple ID needed)
- **Homebrew** and core CLI packages
- **Dotfile symlinks** (zsh, git, nvim, tmux, kitty, etc.)
- **Shell environment** (oh-my-zsh, plugins, starship prompt)
- **GUI apps**: kitty (terminal) and Tailscale (VPN)
- **Go** via Homebrew
- **Rust** toolchain and cargo tools (viu)
- **Python** tooling via uv (package manager, ruff, pynvim)
- **Deno** runtime
- **AI CLIs** (Claude Code, OpenCode, llm)
- **macOS system defaults** (Finder, keyboard, trackpad, screenshots)

## Prerequisites

- macOS (Apple Silicon or Intel)
- Internet connection
- No Apple ID required

## Quick Start

On a fresh Mac, running `git` for the first time triggers the Xcode CLT install dialog. Wait for that to finish before cloning.

```bash
# 1. Clone dotfiles (may trigger Xcode CLT dialog on fresh Mac)
git clone https://github.com/kevinmcmahon/dotfiles.git ~/dotfiles

# 2. Run bootstrap
cd ~/dotfiles/scripts
./bootstrap.sh

# 3. Open a new shell
exec zsh
```

## What Gets Installed

### Via Homebrew (BootstrapBrewfile)

| Category | Packages |
|----------|----------|
| CLI essentials | bat, coreutils, curl, eza, fd, fzf, jq, ripgrep, tmux, tree, wget, zoxide |
| Dev tools | direnv, git, git-lfs, lazygit, neovim, shellcheck, starship, tectonic |
| Languages & managers | go, fnm (Node), chruby + ruby-install (Ruby) |
| File manager | yazi |
| Fonts | Fira Code Nerd Font, JetBrains Mono Nerd Font, Monaspace |

### Via Homebrew Cask

| App | Purpose |
|-----|---------|
| kitty | GPU-accelerated terminal emulator |
| Tailscale | Zero-config VPN for secure remote access |

### Via Cargo

| Tool | Purpose |
|------|---------|
| viu | Terminal image viewer |

### Via Installers

| Tool | Purpose |
|------|---------|
| rustup | Rust toolchain manager |
| uv | Python version & package manager |
| Deno | JavaScript/TypeScript runtime |
| Claude Code | Anthropic CLI |
| OpenCode | OpenCode CLI |
| llm | Simon Willison's LLM CLI (with anthropic, gemini, openai, mlx, mistral plugins) |
| ruff | Python linter/formatter (via uv) |

### Dotfile Symlinks

| Source | Target |
|--------|--------|
| `*.symlink` (root, git/, osx/) | `~/.<name>` |
| `git/git-core.symlink/` | `~/.git-core` |
| `nvim/`, `yazi/`, `tmux/`, `starship/`, `git/`, `kitty/` | `~/.config/<name>` |
| `zsh/*.symlink` | `~/.zshrc`, `~/.zshenv`, `~/.zprofile` |
| `llm/templates.symlink` | `~/.config/io.datasette.llm/templates` |
| `claude/CLAUDE.md`, `commands/`, `docs/`, `hooks/`, `settings.json` | `~/.claude/<name>` |

## Post-Install Configuration

### Tailscale

Open Tailscale from Applications and sign in to connect to your tailnet.

### Git Identity (required)

The bootstrap creates template files that you must edit:

```bash
# Set your default identity
$EDITOR ~/.gituserconfig
# Uncomment and set name + email

# (Optional) Set project-specific identities
$EDITOR ~/.gituserconfig.kmc
$EDITOR ~/.gituserconfig.nsv
```

### Node.js via fnm

```bash
fnm install --lts
fnm use lts-latest
fnm default lts-latest
corepack enable
```

### Python via uv

```bash
uv python install 3.12
uv python install 3.11
```

### Ruby via ruby-install

```bash
ruby-install ruby 3.3.6
```

After installing, select it with chruby:
```bash
chruby ruby-3.3.6
```

### LLM API Keys

```bash
llm keys set anthropic
llm keys set openai
llm keys set gemini
```

### Ntfy Push Notifications (optional)

To receive push notifications on your phone when Claude Code needs input:

1. Install the ntfy app ([iOS](https://apps.apple.com/app/ntfy/id1625396347) / [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy))
2. Subscribe to a unique, hard-to-guess topic
3. Add to `~/.zsh/env/optional/private.zsh`:
   ```bash
   export NTFY_TOPIC="your-unique-topic"
   ```

## Optional: Additional Apps

The bootstrap installs a minimal set of packages. For a full development setup, the main Brewfile has additional apps:

```bash
brew bundle --file=~/.Brewfile
```

If you later add an Apple ID, Mac App Store apps can be installed via `mas`:

```bash
brew install mas
mas install 441258766   # Magnet
mas install 1179623856  # Pastebot
```

See `osx/mas-list.txt` for the full list.

## Environment Variable Flags

| Variable | Default | Effect |
|----------|---------|--------|
| `SKIP_DEFAULTS` | `0` | Set to `1` to skip macOS system defaults and Spotlight config |
| `DOTFILES_DIR` | `$HOME/dotfiles` | Override dotfiles location |

Example:
```bash
SKIP_DEFAULTS=1 ./bootstrap.sh
```

## Troubleshooting

### Xcode CLT dialog doesn't appear

If `xcode-select --install` says tools are already installed but they're not working:

```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

### Homebrew on Apple Silicon

Homebrew installs to `/opt/homebrew` on Apple Silicon (vs `/usr/local` on Intel). The bootstrap handles this automatically. If `brew` isn't found after install, run:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Git identity not working

Verify your config chain:

```bash
git config --show-origin user.name
git config --show-origin user.email
```

If blank, edit `~/.gituserconfig`:
```bash
$EDITOR ~/.gituserconfig
```

### Neovim checkhealth issues

Run `:checkhealth` in Neovim and address any warnings. Common fixes:

```bash
# Python provider
~/.local/share/nvim/venv/bin/python -c "import pynvim"

# Node provider
npm install -g neovim
```

## Platform Differences

Both platforms use the same `scripts/bootstrap.sh` entry point. The differences are in how each tool gets installed:

| Feature | macOS | Linux |
|---------|-------|-------|
| Package manager | Homebrew | apt |
| Neovim | `brew install neovim` | AppImage |
| lazygit, starship, fzf | `brew install` | Binary downloads |
| yazi | `brew install yazi` | `cargo install` |
| tectonic | `brew install tectonic` | `cargo install` |
| Default shell | zsh (already default) | `chsh -s` required |
| pbcopy/pbpaste | Native | xclip wrappers |
| Go | `brew install go` | Official tarball |
| fnm | `brew install fnm` | Curl installer |
| chruby/ruby-install | `brew install` | Source install |
| System config | `defaults write` | N/A |

## Related Documentation

- [Bootstrap System](bootstrap.md) — Full bootstrap architecture documentation
- [Linux Networking Setup](linux-networking-setup.md) — Tailscale, firewall, mosh
- [macOS Defaults Source](../osx/set-defaults.sh) — Standalone defaults script
