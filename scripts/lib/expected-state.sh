# shellcheck shell=bash
# scripts/lib/expected-state.sh — Expected links, copies and real directories
#
# This file is SOURCED by common.sh (bootstrap applies the rows) and audit.sh
# (the audits check the same rows). Sourcing it only defines functions.
#
# Each group function prints one tab-separated row per fact:
#
#   kind<TAB>src<TAB>dst[<TAB>mode]
#
#   link       dst is a symlink to src
#   real-dir   dst is a real local directory, never a symlink; src is "-"
#   copy-once  dst is a regular local file copied from src when missing and
#              never overwritten afterwards; mode, when present, is the chmod
#              mode for a file bootstrap creates
#
# A field that does not apply is printed as "-" rather than left empty, because
# `IFS=$'\t' read` merges adjacent tabs. Real directories come first in each
# group so links and copies land inside them. Rows read DOTFILES_DIR,
# CONFIG_DIR and HOME when called, not when this file is sourced.

expected_state_groups() {
  printf '%s\n' xdg tmux uv bun claude codex opencode
}

# Prints the rows of one group; fails on an unknown group name.
expected_state_rows() {
  case "$1" in
    xdg) expected_state_xdg ;;
    tmux) expected_state_tmux ;;
    uv) expected_state_uv ;;
    bun) expected_state_bun ;;
    claude) expected_state_claude ;;
    codex) expected_state_codex ;;
    opencode) expected_state_opencode ;;
    opencode_config) expected_state_opencode_config ;;
    opencode_ai_dirs) expected_state_opencode_ai_dirs ;;
    *)
      printf 'unknown expected-state group: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

expected_state_row() {
  if [[ -n "${4:-}" ]]; then
    printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
  else
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  fi
}

# Repo-owned static XDG config: whole-directory symlinks.
expected_state_xdg() {
  local topic
  for topic in nvim yazi starship git ghostty; do
    expected_state_row link "$DOTFILES_DIR/$topic" "$CONFIG_DIR/$topic"
  done
}

# tmux keeps a real XDG directory so TPM plugins stay local; only tmux.conf is
# linked into it.
expected_state_tmux() {
  expected_state_row real-dir - "$CONFIG_DIR/tmux"
  expected_state_row link "$DOTFILES_DIR/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
}

# uv writes its own files (uv-receipt.json) into its config directory, so the
# directory stays real and only uv.toml is linked into it.
expected_state_uv() {
  expected_state_row real-dir - "$CONFIG_DIR/uv"
  expected_state_row link "$DOTFILES_DIR/uv/uv.toml" "$CONFIG_DIR/uv/uv.toml"
}

# Bun reads its user config from the home directory.
expected_state_bun() {
  expected_state_row link "$DOTFILES_DIR/bun/bunfig.toml" "$HOME/.bunfig.toml"
}

# npm user config keys bootstrap sets and the audits check, one
# key<TAB>value row each. npm writes credentials and local settings to
# ~/.npmrc, so the file stays local and only these keys are managed.
#
#   min-release-age       install only versions published at least this many
#                         days ago
#   strict-allow-scripts  fail the install when a dependency has an install
#                         script that has not been approved, instead of
#                         running it
expected_npm_config() {
  printf '%s\t%s\n' \
    min-release-age 7 \
    strict-allow-scripts true
}

expected_state_claude() {
  local item

  # Skills are local mutable install state; see ensure_claude_skills_dir.
  expected_state_row real-dir - "$HOME/.claude/skills"

  # Symlink individual items — NOT the whole directory, because ~/.claude
  # also contains machine-local state (settings.local.json, credentials,
  # cache, history, etc.). Machine-local configs (mcp.json,
  # claude_desktop_config.json) are copied as templates, not symlinked.
  # settings.json is copied too: Claude Code saves it by replacing the file,
  # which would turn a symlink into a regular file on the first save.
  for item in CLAUDE.md commands docs hooks scripts; do
    expected_state_row link "$DOTFILES_DIR/claude/$item" "$HOME/.claude/$item"
  done

  for item in mcp.json claude_desktop_config.json settings.json; do
    expected_state_row copy-once "$DOTFILES_DIR/claude/$item" "$HOME/.claude/$item"
  done
}

expected_state_codex() {
  expected_state_row link "$DOTFILES_DIR/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
  expected_state_row copy-once "$DOTFILES_DIR/codex/config.toml.template" "$HOME/.codex/config.toml" 600
  expected_state_row copy-once "$DOTFILES_DIR/codex/hooks.json.template" "$HOME/.codex/hooks.json"
  expected_state_row copy-once "$DOTFILES_DIR/codex/rules/default.rules.template" "$HOME/.codex/rules/default.rules"
  expected_state_row link "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh" "$HOME/.codex/hooks/ntfy-notify.sh"
}

# The OpenCode rows split by bootstrap step: install_opencode links the config,
# symlink_opencode_ai_dirs places the ~/.opencode directories.
expected_state_opencode() {
  expected_state_opencode_ai_dirs
  expected_state_opencode_config
}

expected_state_opencode_config() {
  expected_state_row link "$DOTFILES_DIR/opencode/opencode.json.symlink" "$CONFIG_DIR/opencode/opencode.json"
}

expected_state_opencode_ai_dirs() {
  local resource

  expected_state_row real-dir - "$HOME/.opencode/skills"
  for resource in commands docs; do
    expected_state_row link "$DOTFILES_DIR/opencode/$resource" "$HOME/.opencode/$resource"
  done
}

# Generated common AI skills that every AI tool's skills directory should hold
# as symlinks into ai/skills/common/. Names only; each audit section checks
# them under its own tool's skills directory.
expected_common_ai_skills() {
  printf '%s\n' \
    book-refactoring-pass \
    book-legacy-change \
    book-reliability-review \
    book-domain-modeling \
    book-data-systems \
    create-adr \
    writing-tropes \
    docker-uv
}
