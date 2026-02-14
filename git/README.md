# Git Configuration

Cross-platform Git configuration with OS-specific settings, security hooks, and LLM-assisted commits.

---

## Structure

```
git/
├── gitconfig.symlink          # Main config → ~/.gitconfig
├── gitconfig-secrets.symlink  # git-secrets patterns → ~/.gitconfig-secrets
├── gitconfig-macos.symlink    # macOS overrides → ~/.gitconfig-macos
├── gitconfig-linux.symlink    # Linux overrides → ~/.gitconfig-linux
├── gitignore_global.symlink   # Global ignores → ~/.gitignore_global
├── gitattributes.symlink      # Diff/merge rules → ~/.gitattributes
├── gituserconfig.symlink      # Default user identity → ~/.gituserconfig
├── gituserconfig.*.symlink    # Project-specific identities
├── git-core.symlink/          # Global hooks & secrets → ~/.git-core/
│   ├── hooks/
│   │   ├── pre-commit         # git-secrets scan
│   │   ├── commit-msg         # git-secrets scan
│   │   ├── prepare-commit-msg # git-secrets + LLM assist
│   │   └── post-checkout      # LFS auto-configure (if repo uses it)
│   └── secrets/
│       ├── patterns           # Blocked patterns (AWS, GitHub tokens)
│       └── allowed            # Exceptions
└── git-templates.symlink/     # Template for new repos
```

---

## Cross-Platform Setup

The config auto-detects OS using `includeIf` based on home directory path:

```ini
[includeIf "gitdir:/Users/"]
    path = ~/.gitconfig-macos

[includeIf "gitdir:/home/"]
    path = ~/.gitconfig-linux
```

### macOS Settings (`gitconfig-macos.symlink`)

| Setting | Value |
|---------|-------|
| Diff tool | Kaleidoscope |
| Merge tool | Kaleidoscope |
| Credential helper | osxkeychain |
| Plist diffs | plutil textconv |
| fsmonitor | enabled |

### Linux Settings (`gitconfig-linux.symlink`)

| Setting | Value |
|---------|-------|
| Pager | delta (side-by-side, syntax highlighted) |
| Diff tool | nvimdiff |
| Merge tool | nvimdiff |
| Credential helper | cache (24hr timeout) |
| fsmonitor | enabled |

---

## Installation

### Prerequisite: git-secrets

This setup expects **git-secrets** to be installed because the global hooks in `~/.git-core/hooks/`
invoke `git secrets`.

Ubuntu/Debian:

```bash
sudo apt-get update -y
sudo apt-get install -y git-secrets
```

### macOS

Symlinks are typically created by your dotfiles bootstrap. Manually:

```bash
ln -sf ~/dotfiles/git/gitconfig.symlink ~/.gitconfig
ln -sf ~/dotfiles/git/gitconfig-secrets.symlink ~/.gitconfig-secrets
ln -sf ~/dotfiles/git/gitconfig-macos.symlink ~/.gitconfig-macos
ln -sf ~/dotfiles/git/gitignore_global.symlink ~/.gitignore_global
ln -sf ~/dotfiles/git/git-core.symlink ~/.git-core
```

### Linux

The `bootstrap.sh` script handles all symlinks. Manually:

```bash
ln -sf ~/dotfiles/git/gitconfig.symlink ~/.gitconfig
ln -sf ~/dotfiles/git/gitconfig-secrets.symlink ~/.gitconfig-secrets
ln -sf ~/dotfiles/git/gitconfig-linux.symlink ~/.gitconfig-linux
ln -sf ~/dotfiles/git/gitignore_global.symlink ~/.gitignore_global
ln -sf ~/dotfiles/git/git-core.symlink ~/.git-core
```

Install delta for enhanced diffs:

```bash
cargo install git-delta
```

### Verify Setup

```bash
# Check config loads without errors
git config --list >/dev/null && echo "Config OK"

# Check OS-specific settings loaded
git config --get core.pager      # Linux: delta
git config --get diff.tool       # macOS: Kaleidoscope, Linux: nvimdiff
git config --get credential.helper

# Check aliases work
git config --get alias.st
```

---

## User Identity

### Why identity routing is tricky across machines

Git's `includeIf gitdir:` matching is done against the repo's **absolute path** and **does not expand** `~` or `$HOME`.
That makes it hard to keep a single version-controlled `~/.gitconfig` that works across machines with different usernames
(e.g. `/Users/kevin` vs `/home/ubuntu` vs `/home/clawdbot`).

This dotfiles setup solves that by splitting identity routing into two layers:

- **Version-controlled**: the identity files *templates* and the include that loads `~/.gitconfig-local`
- **Machine-local (unversioned)**: `~/.gitconfig-local`, which contains absolute paths for *this* machine

### Machine-local routing: `~/.gitconfig-local`

The main config includes a local file:

```ini
[include]
  path = ~/.gitconfig-local
```

On each machine, create `~/.gitconfig-local` from the template and substitute your absolute home path:

```bash
cp ~/dotfiles/git/gitconfig-local.template ~/.gitconfig-local
$EDITOR ~/.gitconfig-local
```

The template uses a placeholder:

```ini
[includeIf "gitdir:__HOME__/projects/kmc/**"]
  path = ~/.gituserconfig.kmc

[includeIf "gitdir:__HOME__/projects/fete/**"]
  path = ~/.gituserconfig.fete
```

Replace `__HOME__` with your actual home directory, e.g.

- macOS: `/Users/kevin`
- Linux: `/home/ubuntu`

### Identity templates (NOT checked in)

Create local identity files from templates:

```bash
cp ~/dotfiles/git/gituserconfig-kmc.template ~/.gituserconfig.kmc
cp ~/dotfiles/git/gituserconfig-fete.template ~/.gituserconfig.fete
$EDITOR ~/.gituserconfig.kmc ~/.gituserconfig.fete
```

These local files should contain **only** your `user.name` and `user.email` for that identity.

### Bootstrap integration (Linux)

`bootstrap.sh` can generate the local files if they are missing:

- `~/.gitconfig-local` (with `__HOME__` substituted)
- `~/.gituserconfig.kmc` and `~/.gituserconfig.nsv` (copied from templates)

It will **never overwrite** existing local files.

### Verify Identity Routing

After setup, verify the correct identity loads in each directory:

```bash
# Check current identity (run from any repo)
git config user.name
git config user.email

# See which file provides the identity
git config --show-origin user.name
git config --show-origin user.email
```

Test routing by checking identity in different directories:

```bash
# Default identity (outside project directories)
cd ~/some-random-repo
git config user.name  # Should show default from ~/.gituserconfig

# Project-specific identity
cd ~/projects/kmc/some-repo
git config user.name  # Should show KMC identity

cd ~/projects/fete/some-repo
git config user.name  # Should show Fete identity
```

If the wrong identity appears, check:

1. **`includeIf` paths are absolute** — `~` won't work, use `/home/username/...`
2. **Trailing `/**` on directory patterns** — required to match repos inside
3. **File exists** — `ls -la ~/.gituserconfig.kmc`
4. **No typos in path** — `git config --list --show-origin | grep -i include`

Debug the full config resolution:

```bash
# Show all config with source files
git config --list --show-origin

# Filter to see which includes are active
git config --list --show-origin | grep -E "(includeIf|user\.(name|email))"
```

---

## Hooks

All hooks are in `~/.git-core/hooks/` (set via `core.hooksPath`).

### Security Hooks

`pre-commit`, `commit-msg`, and `prepare-commit-msg` invoke `git-secrets` to block:

- AWS access keys (`AKIA...`)
- AWS secret keys
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`)
- OpenAI API keys (`sk-...`, `sk-proj-...`)
- Google API keys (`AIza...`)

### LFS Hook

`post-checkout` auto-configures Git LFS for repos that use it. It:

- Only runs if the repo has `filter=lfs` in `.gitattributes`
- Skips silently if `git-lfs` isn't installed
- Won't interfere with non-LFS repos

### LLM Commit Assistance

`prepare-commit-msg` can invoke `prepare-commit-msg-llm` to generate commit messages using the `llm` CLI. Set `SKIP_LLM_GITHOOK=1` to disable.

---

## Secrets Scanning

Patterns in `~/.git-core/secrets/patterns`:

```
# AWS keys
(A3T[A-Z0-9]|AKIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA|ASIA)[A-Z0-9]{16}

# GitHub tokens
ghp_[A-Za-z0-9]{36,}
gho_[A-Za-z0-9]{36,}
ghu_[A-Za-z0-9]{36,}
ghs_[A-Za-z0-9]{36,}
ghr_[A-Za-z0-9]{36,}
github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}
```

Test scanning:

```bash
git secrets --scan
git secrets --scan-history
```

---

## Aliases

| Alias | Command |
|-------|---------|
| `st` | `status -s` |
| `co` | `checkout` |
| `br` | `branch` |
| `ci` | `commit -v` |
| `df` | `diff` |
| `lg` | Pretty log graph with colors |
| `aa` | `add --all` |
| `amend` | Amend last commit, reuse message |
| `undo` | `reset --hard` (use with caution) |
| `standup` | Yesterday's commits by author |
| `releasenotes` | Markdown changelog from last tag |
| `new` | Init repo with `main` branch |

---

## Troubleshooting

### Config parse error

Check for merge conflict markers or invalid syntax:

```bash
git config --list
```

If broken, bypass with:

```bash
GIT_CONFIG_GLOBAL=/dev/null git status
```

### Hooks not running

```bash
git config --get core.hooksPath  # Should be ~/.git-core/hooks
ls -la ~/.git-core/hooks/
```

### Delta not working (Linux)

```bash
which delta  # Should return a path
git config --get core.pager  # Should be "delta"
```

### fsmonitor issues

Disable in your local config:

```bash
git config --global core.fsmonitor false
```

---

## Shell Integration (Bash Only)

For Zsh, use oh-my-zsh git plugin or starship prompt instead.

### Bash Setup

```bash
[[ -f ~/dotfiles/git/git_completion.sh ]] && source ~/dotfiles/git/git_completion.sh
[[ -f ~/dotfiles/git/git-prompt.sh ]] && source ~/dotfiles/git/git-prompt.sh

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM="auto"
```
