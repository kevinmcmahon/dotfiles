# 🛠 Git Configuration

This directory contains a curated set of Git configurations, hooks, secrets, and helper scripts optimized for professional development workflows, LLM-assisted commits, and security hygiene.

---

## 🧩 Structure

### Global Git Configs

- **`gitconfig.symlink`** – the primary `.gitconfig`, symlinked to `~/.gitconfig`
- **Includes conditional user profiles**:
  - `~/.gituserconfig.work` – work email + GitHub username
  - `~/.gituserconfig.kmc`, `~/.gituserconfig.nsv` – alternate project-specific identities

### Hook Configuration

- All hooks are stored in:

  ```
  ~/.git-core/hooks/
  ```

- This path is configured globally in Git:

  ```ini
  [core]
    hooksPath = ~/.git-core/hooks
  ```

---

## 🔐 Git Hooks

### LFS-Aware Hooks (safe by default)

The following Git hooks are now **LFS-aware**, meaning they:

- Only run if `filter.lfs.required = true` is set in the current repo
- Quietly skip if `git-lfs` is missing or not needed

| Hook               | Purpose                          |
|--------------------|----------------------------------|
| `post-checkout`    | Triggers `git lfs post-checkout` |
| `post-merge`       | Triggers `git lfs post-merge`    |
| `post-commit`      | Triggers `git lfs post-commit`   |
| `pre-push`         | Triggers `git lfs pre-push`      |

Each of these is now idempotent and won't interfere with Homebrew or other non-LFS repos.

---

### Security Hooks

- **`pre-commit`**, **`commit-msg`**, **`prepare-commit-msg`** all invoke [`git-secrets`](https://github.com/awslabs/git-secrets) to prevent committing:
  - AWS credentials
  - Access keys
  - Project-specific patterns (`secrets/patterns`, `secrets/allowed`)

---

## 🤖 LLM Commit Assistance

- `prepare-commit-msg-llm` is invoked via `prepare-commit-msg` unless `SKIP_LLM_GITHOOK` is set
- It:
  - Captures the staged diff
  - Pipes it into the `llm` CLI
  - Appends the generated commit message (with a separator) to the original message for review

---

## 🧼 Ignore & Diff Customizations

### Global `.gitignore`

Configured in `core.excludesfile = ~/.gitignore_global`  
Includes patterns for:

- macOS artifacts
- JetBrains and language-specific IDE files
- Temp files (`~`, `.envrc`, `.mcp.json`)

### `.gitattributes`

Handles:

- UTF-16 diffing
- Plist binary diffs
- Binary file handling
- Cross-platform line endings

---

## 🔧 Merge & Diff Tools

- All diff and merge tools default to [Kaleidoscope](https://www.kaleidoscope.app/):

  ```ini
  [merge]
    tool = Kaleidoscope
  [diff]
    tool = Kaleidoscope
  ```

- Includes textconv rules for:
  - `.strings` → UTF-8 via `iconv`
  - `.plist` → XML via `plutil`

---

## 🧪 Helpful Aliases

Defined in `[alias]` in `gitconfig.symlink`:

| Alias        | Command                                                            |
|--------------|---------------------------------------------------------------------|
| `st`         | `status -s`                                                         |
| `lg`         | Rich commit graph w/ color & history                                |
| `standup`    | Changes from "yesterday" by Kevin                                   |
| `releasenotes` | Markdown-formatted changelog from last tag                       |
| `previoustag` | Retrieves previous tag for diff/release tracking                   |
| `new`        | Init new repo with `main` as default branch                         |

---

## 📎 Notes

- Global Git setup is workspace-aware via `includeIf "gitdir:"` blocks
- The system is optimized for project switching, safe key handling, and LLM usage
- `git-lfs` integration is *opt-in*, hook-aware, and non-intrusive in non-LFS repos

