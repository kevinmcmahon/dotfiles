# Starship Prompt Configuration

Cross-shell prompt configuration using [Starship](https://starship.rs/).

## Prerequisites

### Linux

```bash
curl -sS https://starship.rs/install.sh | sh
```

### Windows

```powershell
winget install --id Starship.Starship
```

Or with Scoop:

```powershell
scoop install starship
```

## Setup

### Linux / macOS

1. Create the config directory and symlink:

```bash
mkdir -p ~/.config/starship
ln -sf ~/dotfiles/starship/starship.toml ~/.config/starship/starship.toml
ln -sf ~/dotfiles/starship/battery-status.sh ~/.config/starship/battery-status.sh
```

2. Add to your shell config:

**Zsh** (`~/.zshrc`):
```bash
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"
```

**Bash** (`~/.bashrc`):
```bash
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init bash)"
```

### Windows

1. Create the config directory:

```powershell
mkdir -Force "$HOME\.config\starship"
```

2. Create symlink (run as Administrator) or copy the config:

```powershell
# Symlink (requires Admin)
New-Item -ItemType SymbolicLink -Path "$HOME\.config\starship\starship.toml" -Target "$HOME\dotfiles\starship\starship.toml"

# Or just copy
Copy-Item "$HOME\dotfiles\starship\starship.toml" "$HOME\.config\starship\starship.toml"
```

3. Add to your PowerShell profile (`$PROFILE`):

```powershell
$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\starship.toml"
Invoke-Expression (&starship init powershell)
```

## Notes

- The `battery-status.sh` custom module only works on systems with battery (laptops). It will be silently ignored on desktops/servers.
- On Windows, you may need a [Nerd Font](https://www.nerdfonts.com/) for icons to display correctly.
- The config includes modules for: Git, Python, Java, Node.js, Go, AWS, and Docker.
