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
  mkdir -p "$HOME/.claude" "$DOTFILES_DIR/claude"

  REPO_SETTINGS="$DOTFILES_DIR/claude/settings.json"
  LIVE_SETTINGS="$HOME/.claude/settings.json"
  echo '{"repo": true}' >"$REPO_SETTINGS"
}

# Runs the bootstrap step that places Claude Code config in ~/.claude.
run_bootstrap_claude_config() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/common.sh" && symlink_claude_config'
}

# Runs the Claude expected-state check and the settings drift check, keeping
# only the settings.json lines.
run_settings_audit() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/audit.sh" && { check_expected_state claude; check_claude_settings_copy; } | grep "settings.json"'
}

# Counts the audit lines in $output that carry the given marker.
count_marked() {
  printf '%s\n' "$output" | grep -c "$1" || true
}

@test "bootstrap copies the repo settings when none exist" {
  run_bootstrap_claude_config

  [ "$status" -eq 0 ]
  [ -f "$LIVE_SETTINGS" ]
  [ ! -L "$LIVE_SETTINGS" ]
  [ "$(cat "$LIVE_SETTINGS")" = '{"repo": true}' ]
}

@test "bootstrap leaves existing local settings untouched" {
  echo '{"local": true}' >"$LIVE_SETTINGS"

  run_bootstrap_claude_config

  [ "$status" -eq 0 ]
  [ ! -L "$LIVE_SETTINGS" ]
  [ "$(cat "$LIVE_SETTINGS")" = '{"local": true}' ]
  [ -z "$(find "$HOME/.claude" -maxdepth 1 -name 'settings.json.bak.*')" ]
}

@test "bootstrap converts a settings symlink into a local copy" {
  ln -s "$REPO_SETTINGS" "$LIVE_SETTINGS"

  run_bootstrap_claude_config

  [ "$status" -eq 0 ]
  [ -f "$LIVE_SETTINGS" ]
  [ ! -L "$LIVE_SETTINGS" ]
  [ "$(cat "$LIVE_SETTINGS")" = '{"repo": true}' ]
  [ "$(cat "$REPO_SETTINGS")" = '{"repo": true}' ]
}

@test "audit passes local settings that match the repo copy" {
  cp "$REPO_SETTINGS" "$LIVE_SETTINGS"

  run_settings_audit

  [ "$(count_marked '✗')" -eq 0 ]
  [ "$(count_marked '⚠')" -eq 0 ]
  [[ "$output" == *"~/.claude/settings.json exists"* ]]
  [[ "$output" == *"~/.claude/settings.json matches the repo copy"* ]]
}

@test "audit warns when local settings differ from the repo copy" {
  echo '{"local": true}' >"$LIVE_SETTINGS"

  run_settings_audit

  [ "$(count_marked '✗')" -eq 0 ]
  [ "$(count_marked '⚠')" -eq 1 ]
  [[ "$output" == *"~/.claude/settings.json exists"* ]]
  [[ "$output" == *"differs from $REPO_SETTINGS"* ]]
}

@test "audit fails when settings are still a symlink" {
  ln -s "$REPO_SETTINGS" "$LIVE_SETTINGS"

  run_settings_audit

  [ "$(count_marked '✗')" -eq 1 ]
  [ "$(count_marked '⚠')" -eq 0 ]
  [[ "$output" == *"~/.claude/settings.json is a symlink (expected local copy)"* ]]
}

@test "audit fails when settings are missing" {
  run_settings_audit

  [ "$(count_marked '✗')" -eq 1 ]
  [ "$(count_marked '⚠')" -eq 0 ]
  [[ "$output" == *"~/.claude/settings.json missing"* ]]
}

@test "platform audits no longer expect a settings symlink" {
  cp "$REPO_SETTINGS" "$LIVE_SETTINGS"

  run bash -c 'source "$REPO_ROOT/scripts/lib/audit.sh" && audit_section_claude_config 2>&1 | grep "settings.json"'

  [[ "$output" != *"NOT a symlink"* ]]
}
