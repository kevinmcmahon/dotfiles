#!/bin/bash
# ABOUTME: Unsets local core.hooksPath after Claude Code creates a worktree.
# ABOUTME: Prevents worktree creation from shadowing global git hooks (e.g. LLM commit hooks).

git config --local --unset core.hooksPath 2>/dev/null || true
