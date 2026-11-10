#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES_DIR="$BATS_TEST_TMPDIR/dotfiles"
  export CONFIG_DIR="$HOME/.config"
  export LOCAL_BIN="$HOME/.local/bin"
  export PLATFORM="Linux"
  export PATH="/usr/bin:/bin"
  mkdir -p "$HOME" "$DOTFILES_DIR"
}

# Runs a command with the bootstrap library sourced.
run_bootstrap() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/common.sh" && '"$1"
}

# Runs a command with the audit library sourced and reports its counters.
run_audit() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/audit.sh" && '"$1"' && echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"'
}

make_codex_sources() {
  mkdir -p "$DOTFILES_DIR/codex/hooks" "$DOTFILES_DIR/codex/rules"
  echo "agents" >"$DOTFILES_DIR/codex/AGENTS.md"
  echo "model = \"repo\"" >"$DOTFILES_DIR/codex/config.toml.template"
  echo '{"hooks": "repo"}' >"$DOTFILES_DIR/codex/hooks.json.template"
  echo "rules" >"$DOTFILES_DIR/codex/rules/default.rules.template"
  printf '#!/bin/sh\n' >"$DOTFILES_DIR/codex/hooks/ntfy-notify.sh"
  chmod +x "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh"
}

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

backups_of() {
  find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*"
}

# ------------------------------------------------------------------------------
# The list itself
# ------------------------------------------------------------------------------

@test "sourcing the expected-state library prints nothing and defines no variables" {
  # PIPESTATUS and BASH_* change with every command; anything else is the library's.
  run bash -c 'before="$(compgen -v | grep -vE "^(BASH_|PIPESTATUS$)")"
    source "$REPO_ROOT/scripts/lib/expected-state.sh"
    after="$(compgen -v | grep -vE "^(BASH_|PIPESTATUS$)" | grep -vx before)"
    [[ "$before" == "$after" ]] && echo same'

  [ "$status" -eq 0 ]
  [ "$output" = "same" ]
}

@test "rows read DOTFILES_DIR, CONFIG_DIR and HOME at call time" {
  # shellcheck disable=SC2016  # the child shell expands REPO_ROOT
  run env DOTFILES_DIR=/repo CONFIG_DIR=/cfg HOME=/home/u bash -c \
    'source "$REPO_ROOT/scripts/lib/expected-state.sh" && expected_state_rows tmux'

  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'real-dir\t-\t/cfg/tmux\nlink\t/repo/tmux/tmux.conf\t/cfg/tmux/tmux.conf')" ]
}

@test "codex rows carry the config mode and every row has four or fewer fields" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  run expected_state_rows codex

  [ "$status" -eq 0 ]
  [[ "$output" == *"$(printf 'copy-once\t%s\t%s\t600' "$DOTFILES_DIR/codex/config.toml.template" "$HOME/.codex/config.toml")"* ]]
  while IFS=$'\t' read -r kind src dst _mode extra; do
    [ -n "$kind" ] && [ -n "$src" ] && [ -n "$dst" ] && [ -z "$extra" ]
  done <<<"$output"
}

@test "the opencode group is its AI dirs plus its config" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  [ "$(expected_state_rows opencode)" = "$(expected_state_rows opencode_ai_dirs; expected_state_rows opencode_config)" ]
  [[ "$(expected_state_rows opencode_config)" == *"$CONFIG_DIR/opencode/opencode.json"* ]]
}

@test "an unknown group is an error" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  run expected_state_rows nonsense

  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown expected-state group: nonsense"* ]]
}

@test "common AI skill names are listed once" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  run expected_common_ai_skills

  [ "$output" = "book-refactoring-pass
book-legacy-change
book-reliability-review
book-domain-modeling
book-data-systems
create-adr
writing-tropes
docker-uv" ]
}

@test "every expected destination appears in docs/bootstrap.md" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"
  local docs="$REPO_ROOT/docs/bootstrap.md"
  local group kind src dst shown pattern missing=""

  for group in $(expected_state_groups); do
    while IFS=$'\t' read -r kind src dst _; do
      shown="~${dst#"$HOME"}"
      pattern="$(printf '%s' "$shown" | sed 's/[.[\*^$/]/\\&/g')([^A-Za-z0-9_.-]|$)"
      grep -Eq "$pattern" "$docs" || missing="$missing $shown"
    done < <(expected_state_rows "$group")
  done

  echo "missing from docs/bootstrap.md:$missing"
  [ -z "$missing" ]
}

# ------------------------------------------------------------------------------
# Apply side
# ------------------------------------------------------------------------------

@test "link rows warn about a missing source and keep going" {
  make_codex_sources
  rm "$DOTFILES_DIR/codex/AGENTS.md"

  run_bootstrap symlink_codex_config

  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN:"*"$DOTFILES_DIR/codex/AGENTS.md"* ]]
  [ ! -e "$HOME/.codex/AGENTS.md" ]
  [ "$(readlink "$HOME/.codex/hooks/ntfy-notify.sh")" = "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh" ]
}

@test "real-dir rows back up a symlink and create a real directory" {
  mkdir -p "$HOME/.claude" "$BATS_TEST_TMPDIR/old-skills"
  ln -s "$BATS_TEST_TMPDIR/old-skills" "$HOME/.claude/skills"

  run_bootstrap ensure_claude_skills_dir

  [ "$status" -eq 0 ]
  [ -d "$HOME/.claude/skills" ] && [ ! -L "$HOME/.claude/skills" ]
  backup="$(backups_of "$HOME/.claude/skills")"
  [[ "$backup" =~ ^"$HOME/.claude/skills.bak."[0-9]{8}-[0-9]{6}$ ]]
  [ "$(readlink "$backup")" = "$BATS_TEST_TMPDIR/old-skills" ]
  [[ "$output" == *"WARN:"*"$HOME/.claude/skills -> $backup"* ]]
}

@test "real-dir rows create a missing directory and keep an existing one" {
  mkdir -p "$HOME/.opencode/skills/mine"

  run_bootstrap 'ensure_opencode_skills_dir && ensure_claude_skills_dir'

  [ "$status" -eq 0 ]
  [ -d "$HOME/.opencode/skills/mine" ]
  [ -d "$HOME/.claude/skills" ] && [ ! -L "$HOME/.claude/skills" ]
  [[ "$output" != *"WARN"* ]]
}

@test "copy-once rows copy a missing file and apply the mode" {
  make_codex_sources

  run_bootstrap symlink_codex_config

  [ "$status" -eq 0 ]
  [ -f "$HOME/.codex/config.toml" ] && [ ! -L "$HOME/.codex/config.toml" ]
  [ "$(cat "$HOME/.codex/config.toml")" = 'model = "repo"' ]
  [ "$(mode_of "$HOME/.codex/config.toml")" = "600" ]
  [ "$(cat "$HOME/.codex/rules/default.rules")" = "rules" ]
  [ "$(cat "$HOME/.codex/hooks.json")" = '{"hooks": "repo"}' ]
}

@test "copy-once rows convert a Codex symlink into a local file with its content and mode" {
  make_codex_sources
  mkdir -p "$HOME/.codex"
  echo 'model = "linked"' >"$BATS_TEST_TMPDIR/linked.toml"
  chmod 644 "$BATS_TEST_TMPDIR/linked.toml"
  ln -s "$BATS_TEST_TMPDIR/linked.toml" "$HOME/.codex/config.toml"
  ln -s "$DOTFILES_DIR/codex/hooks.json.template" "$HOME/.codex/hooks.json"

  run_bootstrap symlink_codex_config

  [ "$status" -eq 0 ]
  [ -f "$HOME/.codex/config.toml" ] && [ ! -L "$HOME/.codex/config.toml" ]
  [ "$(cat "$HOME/.codex/config.toml")" = 'model = "linked"' ]
  [ "$(mode_of "$HOME/.codex/config.toml")" = "600" ]
  [ "$(cat "$BATS_TEST_TMPDIR/linked.toml")" = 'model = "linked"' ]
  [ -f "$HOME/.codex/hooks.json" ] && [ ! -L "$HOME/.codex/hooks.json" ]
  [ "$(cat "$DOTFILES_DIR/codex/hooks.json.template")" = '{"hooks": "repo"}' ]
  [[ "$output" == *"Converted $HOME/.codex/config.toml symlink to local file (preserved content)"* ]]
}

@test "copy-once rows replace a dangling symlink with the repo source" {
  make_codex_sources
  mkdir -p "$HOME/.codex/rules"
  ln -s "$BATS_TEST_TMPDIR/nowhere" "$HOME/.codex/rules/default.rules"

  run_bootstrap symlink_codex_config

  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.codex/rules/default.rules" ]
  [ "$(cat "$HOME/.codex/rules/default.rules")" = "rules" ]
}

@test "copy-once rows never touch an existing regular file" {
  make_codex_sources
  mkdir -p "$HOME/.codex"
  echo 'model = "local"' >"$HOME/.codex/config.toml"
  chmod 640 "$HOME/.codex/config.toml"

  run_bootstrap symlink_codex_config

  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.codex/config.toml")" = 'model = "local"' ]
  [ "$(mode_of "$HOME/.codex/config.toml")" = "640" ]
  [ -z "$(backups_of "$HOME/.codex/config.toml")" ]
}

@test "copy-once rows warn when neither the file nor its repo source exists" {
  mkdir -p "$DOTFILES_DIR/claude"
  echo '{}' >"$DOTFILES_DIR/claude/settings.json"

  run_bootstrap symlink_claude_config

  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN:"*"$HOME/.claude/mcp.json"*"no repo template"* ]]
  [[ "$output" == *"WARN:"*"$HOME/.claude/claude_desktop_config.json"*"no repo template"* ]]
  [ ! -e "$HOME/.claude/mcp.json" ]
  [ -f "$HOME/.claude/settings.json" ]
}

@test "copy-once rows stay silent when the repo source is missing but the file exists" {
  mkdir -p "$DOTFILES_DIR/claude" "$HOME/.claude"
  echo '{}' >"$DOTFILES_DIR/claude/settings.json"
  echo '{"local": true}' >"$HOME/.claude/mcp.json"
  echo '{"local": true}' >"$HOME/.claude/claude_desktop_config.json"

  run_bootstrap symlink_claude_config

  [ "$status" -eq 0 ]
  [[ "$output" != *"mcp.json"* ]]
  [[ "$output" != *"claude_desktop_config.json"* ]]
  [ "$(cat "$HOME/.claude/mcp.json")" = '{"local": true}' ]
}

# ------------------------------------------------------------------------------
# Check side
# ------------------------------------------------------------------------------

@test "check passes a group whose links, copies and real dirs are in place" {
  mkdir -p "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
  echo "conf" >"$DOTFILES_DIR/tmux/tmux.conf"
  ln -s "$DOTFILES_DIR/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"

  run_audit 'check_expected_state tmux'

  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.config/tmux exists"* ]]
  [[ "$output" == *"~/.config/tmux/tmux.conf -> $DOTFILES_DIR/tmux/tmux.conf"* ]]
  [[ "$output" == *"PASS=2 FAIL=0 WARN=0"* ]]
}

@test "check fails a real-dir row that is a symlink or missing" {
  run_audit 'check_expected_state tmux'

  [[ "$output" == *"✗"*"~/.config/tmux missing"* ]]

  mkdir -p "$CONFIG_DIR" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$CONFIG_DIR/tmux"

  run_audit 'check_expected_state tmux'

  [[ "$output" == *"✗"*"~/.config/tmux is a symlink (expected real local directory)"* ]]
  [[ "$output" != *"~/.config/tmux exists"* ]]
}

@test "check reports each copy-once state once" {
  make_codex_sources
  mkdir -p "$HOME/.codex/rules"
  echo 'model = "local"' >"$HOME/.codex/config.toml"
  ln -s "$DOTFILES_DIR/codex/hooks.json.template" "$HOME/.codex/hooks.json"

  run_audit 'check_expected_state codex'

  [[ "$output" == *"~/.codex/config.toml exists"* ]]
  [[ "$output" == *"~/.codex/hooks.json is a symlink (expected local copy)"* ]]
  [[ "$output" == *"~/.codex/rules/default.rules missing"* ]]
  [ "$(printf '%s\n' "$output" | grep -c 'default.rules')" -eq 1 ]
}

@test "check warns instead of failing when a copy-once file has no repo source" {
  mkdir -p "$HOME/.claude" "$DOTFILES_DIR/claude"

  run_audit 'check_expected_state claude | grep -E "mcp.json|claude_desktop_config.json"; check_expected_state claude >/dev/null'

  [[ "$output" == *"~/.claude/mcp.json missing"*"no repo template"* ]]
  [[ "$output" == *"~/.claude/claude_desktop_config.json missing"*"no repo template"* ]]
  [[ "$output" != *"✗"*"mcp.json"* ]]
}

@test "check fails a missing copy-once file whose repo source exists" {
  mkdir -p "$DOTFILES_DIR/claude"
  echo '{}' >"$DOTFILES_DIR/claude/mcp.json"

  run_audit 'check_expected_state claude | grep "mcp.json"'

  [[ "$output" == *"✗"*"~/.claude/mcp.json missing"* ]]
  [[ "$output" != *"no repo template"* ]]
}

@test "Claude hook scripts must be executable and resolve" {
  mkdir -p "$DOTFILES_DIR/claude/hooks" "$HOME/.claude"
  printf '#!/bin/sh\n' >"$DOTFILES_DIR/claude/hooks/good.sh"
  chmod +x "$DOTFILES_DIR/claude/hooks/good.sh"
  printf '#!/bin/sh\n' >"$DOTFILES_DIR/claude/hooks/flat.sh"
  ln -s "$BATS_TEST_TMPDIR/nowhere.sh" "$DOTFILES_DIR/claude/hooks/broken.sh"
  ln -s "$DOTFILES_DIR/claude/hooks" "$HOME/.claude/hooks"

  run_audit check_claude_hooks_executable

  [[ "$output" == *"✓"*"~/.claude/hooks/good.sh is executable"* ]]
  [[ "$output" == *"✗"*"~/.claude/hooks/flat.sh is not executable"* ]]
  [[ "$output" == *"✗"*"~/.claude/hooks/broken.sh is a broken symlink"* ]]
  [[ "$output" == *"PASS=1 FAIL=2 WARN=0"* ]]
}

@test "the Codex config section checks that the ntfy hook is executable" {
  make_codex_sources
  chmod -x "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh"
  mkdir -p "$HOME/.codex/hooks"
  ln -s "$DOTFILES_DIR/codex/hooks/ntfy-notify.sh" "$HOME/.codex/hooks/ntfy-notify.sh"

  run_audit audit_section_codex_config

  [[ "$output" == *"✓"*"~/.codex/hooks/ntfy-notify.sh -> $DOTFILES_DIR/codex/hooks/ntfy-notify.sh"* ]]
  [[ "$output" == *"✗"*"~/.codex/hooks/ntfy-notify.sh is not executable"* ]]
}

@test "the Claude config section checks hooks and the machine-local copies" {
  mkdir -p "$DOTFILES_DIR/claude/hooks" "$HOME/.claude"
  printf '#!/bin/sh\n' >"$DOTFILES_DIR/claude/hooks/flat.sh"
  ln -s "$DOTFILES_DIR/claude/hooks" "$HOME/.claude/hooks"

  run_audit audit_section_claude_config

  [[ "$output" == *"~/.claude/hooks/flat.sh is not executable"* ]]
  [[ "$output" == *"~/.claude/mcp.json"* ]]
  [[ "$output" == *"~/.claude/claude_desktop_config.json"* ]]
}

# ------------------------------------------------------------------------------
# Bootstrap verification step
# ------------------------------------------------------------------------------

@test "the bootstrap AI config audit reports failures without failing bootstrap" {
  run bash -c 'set -euo pipefail
    source "$REPO_ROOT/scripts/lib/common.sh"
    audit_ai_tool_config
    echo "still running"
    warn "common warn intact"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code Config"* ]]
  [[ "$output" == *"Codex Config"* ]]
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"WARN:"*"Claude Code and Codex config audit reported failures"* ]]
  [[ "$output" == *"still running"* ]]
  [[ "$output" == *"WARN:"*"common warn intact"* ]]
}
