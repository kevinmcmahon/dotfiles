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

  # shellcheck source=../scripts/lib/common.sh
  source "$REPO_ROOT/scripts/lib/common.sh"

  SRC="$DOTFILES_DIR/thing.symlink"
  DST="$HOME/.thing"
  echo "repo thing" >"$SRC"
}

# Prints the backups created next to a destination, one per line.
backups_of() {
  find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*" | LC_ALL=C sort
}

assert_single_timestamped_backup() {
  local dst="$1"
  local found
  found="$(backups_of "$dst")"
  [ -n "$found" ]
  [ "$(printf '%s\n' "$found" | wc -l | tr -d ' ')" -eq 1 ]
  [[ "$found" =~ ^"$dst.bak."[0-9]{8}-[0-9]{6}$ ]]
  BACKUP="$found"
}

@test "missing destination is linked without a backup" {
  run link_with_backup "$SRC" "$DST"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Linked $DST -> $SRC"* ]]
  [[ "$output" != *"Backing up"* ]]
  [ -L "$DST" ]
  [ "$(readlink "$DST")" = "$SRC" ]
  [ -z "$(backups_of "$DST")" ]
}

@test "missing parent directory is created before linking" {
  local dst="$HOME/.zsh/env"

  run link_with_backup "$SRC" "$dst"

  [ "$status" -eq 0 ]
  [ -L "$dst" ]
  [ "$(readlink "$dst")" = "$SRC" ]
}

@test "destination that is already the correct symlink is left alone" {
  ln -s "$SRC" "$DST"

  run link_with_backup "$SRC" "$DST"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(readlink "$DST")" = "$SRC" ]
  [ -z "$(backups_of "$DST")" ]
}

@test "symlink to somewhere else is backed up and replaced" {
  local other="$BATS_TEST_TMPDIR/other"
  echo "other" >"$other"
  ln -s "$other" "$DST"

  run link_with_backup "$SRC" "$DST"

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$DST"
  [[ "$output" == *"Backing up existing $DST -> $BACKUP"* ]]
  [[ "$output" == *"Linked $DST -> $SRC"* ]]
  [ "$(readlink "$DST")" = "$SRC" ]
  [ -L "$BACKUP" ]
  [ "$(readlink "$BACKUP")" = "$other" ]
}

@test "dangling symlink is backed up and replaced" {
  ln -s "$BATS_TEST_TMPDIR/nowhere" "$DST"

  run link_with_backup "$SRC" "$DST"

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$DST"
  [ "$(readlink "$DST")" = "$SRC" ]
  [ "$(readlink "$BACKUP")" = "$BATS_TEST_TMPDIR/nowhere" ]
}

@test "regular file is backed up with its contents intact" {
  echo "local edits" >"$DST"

  run link_with_backup "$SRC" "$DST"

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$DST"
  [[ "$output" == *"Backing up existing $DST -> $BACKUP"* ]]
  [ ! -L "$BACKUP" ]
  [ "$(cat "$BACKUP")" = "local edits" ]
  [ "$(readlink "$DST")" = "$SRC" ]
}

@test "real directory is backed up intact and replaced by the link" {
  local src_dir="$DOTFILES_DIR/topic"
  local dst_dir="$CONFIG_DIR/topic"
  mkdir -p "$src_dir" "$dst_dir"
  echo "local state" >"$dst_dir/state.txt"

  run link_with_backup "$src_dir" "$dst_dir"

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$dst_dir"
  [[ "$output" == *"Backing up existing $dst_dir -> $BACKUP"* ]]
  [ -d "$BACKUP" ] && [ ! -L "$BACKUP" ]
  [ "$(cat "$BACKUP/state.txt")" = "local state" ]
  [ "$(readlink "$dst_dir")" = "$src_dir" ]
  # The link replaces the directory; nothing is nested inside the source.
  [ ! -e "$src_dir/topic" ]
}

@test "llm templates step backs up a real templates directory instead of deleting it" {
  mkdir -p "$DOTFILES_DIR/llm/templates.symlink"
  echo "repo template" >"$DOTFILES_DIR/llm/templates.symlink/repo.yaml"
  local dst="$HOME/.config/io.datasette.llm/templates"
  mkdir -p "$dst"
  echo "my template" >"$dst/mine.yaml"

  run symlink_llm_templates

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$dst"
  [[ "$output" == *"Backing up existing $dst -> $BACKUP"* ]]
  [ "$(cat "$BACKUP/mine.yaml")" = "my template" ]
  [ "$(readlink "$dst")" = "$DOTFILES_DIR/llm/templates.symlink" ]
}

@test "llm templates step on macOS stays inside HOME and backs up" {
  export PLATFORM="Darwin"
  mkdir -p "$DOTFILES_DIR/llm/templates.symlink"
  local data_dir="$HOME/Library/Application Support/io.datasette.llm"
  local dst="$data_dir/templates"
  mkdir -p "$dst"
  echo "my template" >"$dst/mine.yaml"

  run symlink_llm_templates

  [ "$status" -eq 0 ]
  assert_single_timestamped_backup "$dst"
  [ "$(cat "$BACKUP/mine.yaml")" = "my template" ]
  [ "$(readlink "$dst")" = "$DOTFILES_DIR/llm/templates.symlink" ]
}

@test "ensure_local_bin_in_path is defined exactly once in common.sh" {
  run grep -c '^ensure_local_bin_in_path()' "$REPO_ROOT/scripts/lib/common.sh"

  [ "$output" = "1" ]
}

@test "ensure_local_bin_in_path adds LOCAL_BIN for the bootstrap run" {
  run ensure_local_bin_in_path

  [ "$status" -eq 0 ]
  [[ "$output" == *"Ensuring LOCAL_BIN is on PATH for this bootstrap run"* ]]
  [[ "$output" == *"$LOCAL_BIN not currently on PATH for this shell session."* ]]
  [[ "$output" == *"Adding it for this bootstrap run."* ]]
}
