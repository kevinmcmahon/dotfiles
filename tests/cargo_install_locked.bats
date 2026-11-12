#!/usr/bin/env bats

# Bootstrap builds its cargo tools with --locked, so each one compiles against
# the dependency versions in the lockfile its author published instead of
# whatever is newest on the day of the install.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES_DIR="$BATS_TEST_TMPDIR/dotfiles"
  export CONFIG_DIR="$HOME/.config"
  export LOCAL_BIN="$HOME/.local/bin"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  export CARGO_LOG="$BATS_TEST_TMPDIR/cargo.log"
  export PATH="$STUB_BIN:/usr/bin:/bin"
  mkdir -p "$HOME" "$DOTFILES_DIR" "$STUB_BIN"

  # A cargo that records its arguments and installs nothing, so every tool
  # stays missing and every install branch runs.
  # shellcheck disable=SC2016  # the stub expands these when it runs
  printf '#!/bin/bash\necho "$*" >>"$CARGO_LOG"\n' >"$STUB_BIN/cargo"
  printf '#!/bin/bash\nexit 0\n' >"$STUB_BIN/rustup"
  chmod +x "$STUB_BIN/cargo" "$STUB_BIN/rustup"
}

# Runs the platform's install_rust_and_cargo_tools against the stubs. The
# version lookups after each install fail because nothing was installed; only
# the recorded cargo calls matter here.
run_cargo_tools() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/common.sh" &&
    source "$REPO_ROOT/scripts/lib/platform-'"$1"'.sh" &&
    install_rust_and_cargo_tools'
}

installs_without_locked() {
  grep '^install ' "$CARGO_LOG" | grep -v -- '--locked' || true
}

# A named tool already in /usr/bin or /bin would skip its install branch and
# change the number of cargo calls. Pass the tools the platform's function
# looks for.
skip_if_host_has() {
  local tool
  for tool in "$@"; do
    if command -v "$tool" >/dev/null 2>&1; then
      skip "this host has $tool in /usr/bin or /bin"
    fi
  done
}

@test "every macOS cargo install is locked" {
  skip_if_host_has tree-sitter viu
  run_cargo_tools mac

  [ "$(grep -c '^install ' "$CARGO_LOG")" -eq 2 ]
  [ -z "$(installs_without_locked)" ]
}

@test "every Linux cargo install is locked" {
  skip_if_host_has tree-sitter yazi ya jless delta viu
  run_cargo_tools linux

  [ "$(grep -c '^install ' "$CARGO_LOG")" -eq 6 ]
  [ -z "$(installs_without_locked)" ]
}

@test "no script outside tests and legacy config runs an unlocked cargo install" {
  # Untracked files that git does not ignore are searched too, so a new script
  # is checked before it is staged. A comment (a # at the start of the line or
  # after whitespace) is dropped first, so a --locked that appears only in a
  # comment does not count, while a # inside $# or ${var#prefix} leaves the
  # line intact.
  run bash -c 'cd "$REPO_ROOT" &&
    git grep -h --untracked "cargo install" -- . ":!*.md" ":!tests/" \
      ":!bash/" ":!kitty/" ":!iterm2/" ":!helix/" ":!vscode/" ":!archive/" |
    sed -E "s/(^|[[:space:]])#.*//" | grep "cargo install" | grep -v -- "--locked"'

  echo "unlocked: $output"
  [ -z "$output" ]
}
