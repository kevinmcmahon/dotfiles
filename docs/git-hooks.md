# Git commit-message input

The global `prepare-commit-msg-llm` hook uses `commit_prompt.py` beside it to
prepare staged context before calling `llm`. This policy applies to every repo;
there are no project-specific paths or exceptions.

The collector emits at most 64 KiB of staged context. The prompt template or
custom system prompt adds its own instructions. Each file block is at most
8 KiB, including its heading and any truncation notice. An inventory uses at
most 8 KiB and includes quoted paths, statuses, and rename destinations. Branch
and change-count metadata help the model identify the commit's scope.

The collector considers at most 64 file diffs, with source files first, then
configs, then other files. Small configs retain their diff even when the whole
file is large. Large data diffs use addition/deletion counts and a summary-only
notice. Binary contents are omitted. Other large text diffs get bounded excerpts.
The footer reports omitted inventory entries, omitted diffs, and truncated
excerpts so the model does not treat partial context as a complete review.

Git metadata is read as NUL-separated records. Paths remain literal arguments;
tabs, newlines, glob characters, and leading dashes do not become shell code or
pathspec patterns. Content comes from the index rather than unstaged files.
External diff and text-conversion drivers are disabled for this input collection.
Patch streams stop after a prefix instead of being loaded in full into Bash.

This bounds commit-message input, not the commit itself. Full staged files still
enter the commit and remain available for human review. A generated message may
miss details omitted from its context and still needs review. Choosing a model
with a smaller context window may require lowering the collector's limits.

The existing skip/explicit-message behavior, `llm` template selection, credentials,
and secret-scanning dispatcher stay intact. Collection or model failures leave
the commit-message file unchanged and report failure; no manual message or
silent fallback is generated.

The helper requires Python 3. It uses only the standard library, needs no package
installation, and adds no shell startup or PATH changes. Its installed location
follows the existing `~/.git-core` directory symlink on macOS and Linux. Keep
the hook and its helper together when installing them.

Run the tests without paid API calls:

```sh
uv run --no-project --offline --python 3.12 python -m unittest discover -s tests -p test_git_commit_hook.py
shellcheck git/git-core.symlink/hooks/prepare-commit-msg-llm
```

Tests create temporary repos and use a fake `llm`, covering large data and source
diffs, long single lines, many files, invalid UTF-8, binary files, renames,
deletions, unusual paths, staged-only content, custom system prompts, and failure
handling. To inspect context for any staged commit without calling a model:

```sh
uv run --no-project --offline git/git-core.symlink/hooks/commit_prompt.py > /tmp/commit-context.txt
wc -c /tmp/commit-context.txt
```
