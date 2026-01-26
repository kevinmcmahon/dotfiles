# Git Configuration

Cross-platform Git configuration with OS-specific settings, security hooks, and LLM-assisted commits.

---

## Structure

```
git/
├── gitconfig.symlink          # Main config → ~/.gitconfig
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
│   │   ├── post-checkout      # LFS (if enabled)
│   │   ├── post-commit        # LFS (if enabled)
│   │   ├── post-merge         # LFS (if enabled)
│   │   └── pre-push           # LFS (if enabled)
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
ln -sf ~/dotfiles/git/gitconfig-macos.symlink ~/.gitconfig-macos
ln -sf ~/dotfiles/git/gitignore_global.symlink ~/.gitignore_global
ln -sf ~/dotfiles/git/git-core.symlink ~/.git-core
```

### Linux

The `bootstrap-linux-dev.sh` script handles all symlinks. Manually:

```bash
ln -sf ~/dotfiles/git/gitconfig.symlink ~/.gitconfig
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

Conditional includes set user identity per project directory:

```ini
[includeIf "gitdir:/Users/kevin/projects/kmc/"]
    path = ~/.gituserconfig.kmc

[includeIf "gitdir:/Users/kevin/dev/work/"]
    path = ~/.gituserconfig.work
```

Create identity files from template:

```bash
cp gituserconfig.template ~/.gituserconfig.work
# Edit with your work email/username
```

---

## Hooks

All hooks are in `~/.git-core/hooks/` (set via `core.hooksPath`).

### Security Hooks

`pre-commit`, `commit-msg`, and `prepare-commit-msg` invoke `git-secrets` to block:

- AWS access keys (`AKIA...`)
- AWS secret keys
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`)

### LFS Hooks

`post-checkout`, `post-commit`, `post-merge`, `pre-push` handle Git LFS. They:

- Only run if the repo has `filter=lfs` in `.gitattributes`
- Skip silently if `git-lfs` isn't installed
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
