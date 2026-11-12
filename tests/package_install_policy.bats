#!/usr/bin/env bats

# The package install policy: a release-age cooldown for uv, bun and npm, and
# an npm install that fails on a dependency install script nobody has
# approved. uv and bun read repo-owned config files linked into place; npm
# keeps local state in ~/.npmrc, so bootstrap sets its keys.

# Each bats test runs in its own subshell, so a variable a test exports for
# its npm stub is meant to stay local to that test.
# shellcheck disable=SC2030,SC2031

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
  export HOME="$BATS_TEST_TMPDIR/home"
  export DOTFILES_DIR="$BATS_TEST_TMPDIR/dotfiles"
  export CONFIG_DIR="$HOME/.config"
  export LOCAL_BIN="$HOME/.local/bin"
  export PLATFORM="Linux"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  export STUB_BIN
  export NPM_LOG="$BATS_TEST_TMPDIR/npm.log"
  export PATH="$STUB_BIN:/usr/bin:/bin"
  mkdir -p "$HOME" "$DOTFILES_DIR" "$STUB_BIN"
}

run_bootstrap() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/common.sh" && '"$1"
}

run_audit() {
  run bash -c 'source "$REPO_ROOT/scripts/lib/audit.sh" && '"$1"' && echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"'
}

make_stub() {
  printf '#!/bin/bash\n%s\n' "$2" >"$STUB_BIN/$1"
  chmod +x "$STUB_BIN/$1"
}

# An npm that records every call and answers `config get` from the
# NPM_MIN_RELEASE_AGE and NPM_STRICT_ALLOW_SCRIPTS variables. With
# NPM_STRICT_ALLOW_SCRIPTS=undefined it behaves like an npm that predates the
# key: `config get` prints "undefined" and `config set` fails.
make_npm_stub() {
  # shellcheck disable=SC2016  # the stub expands these when it runs
  make_stub npm 'echo "$*" >>"$NPM_LOG"
if [[ "$1 $2" == "config get" ]]; then
  case "$3" in
    min-release-age) echo "${NPM_MIN_RELEASE_AGE-7}" ;;
    strict-allow-scripts) echo "${NPM_STRICT_ALLOW_SCRIPTS-true}" ;;
    prefix) echo "$HOME/.local" ;;
  esac
fi
if [[ "$1" == "--version" ]]; then
  echo "0.0.0"
fi
if [[ "$1 $2 $3" == "config set strict-allow-scripts" && "${NPM_STRICT_ALLOW_SCRIPTS-}" == "undefined" ]]; then
  echo "npm error strict-allow-scripts is not a valid npm option" >&2
  exit 1
fi'
}

# npm plus the fnm, node and corepack calls the node setup makes, with an LTS
# release already installed.
make_node_toolchain_stubs() {
  make_npm_stub
  # shellcheck disable=SC2016  # the stub expands $1 when it runs
  make_stub fnm 'if [[ "$1" == "list" ]]; then echo "* v0.0.0 default, lts-latest"; fi'
  make_stub node 'echo "v0.0.0"'
  # shellcheck disable=SC2016  # the stub expands $1 when it runs
  make_stub corepack 'if [[ "$1" == "--version" ]]; then echo "0.0.0"; fi'
}

make_policy_sources() {
  mkdir -p "$DOTFILES_DIR/uv" "$DOTFILES_DIR/bun"
  echo 'exclude-newer = "7 days"' >"$DOTFILES_DIR/uv/uv.toml"
  printf '[install]\nminimumReleaseAge = 604800\n' >"$DOTFILES_DIR/bun/bunfig.toml"
}

link_policy_files() {
  make_policy_sources
  mkdir -p "$CONFIG_DIR/uv"
  ln -s "$DOTFILES_DIR/uv/uv.toml" "$CONFIG_DIR/uv/uv.toml"
  ln -s "$DOTFILES_DIR/bun/bunfig.toml" "$HOME/.bunfig.toml"
}

# ------------------------------------------------------------------------------
# The expected state
# ------------------------------------------------------------------------------

@test "uv keeps a real config directory with the repo uv.toml linked into it" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  [ "$(expected_state_rows uv)" = "$(printf 'real-dir\t-\t%s\nlink\t%s\t%s' \
    "$CONFIG_DIR/uv" "$DOTFILES_DIR/uv/uv.toml" "$CONFIG_DIR/uv/uv.toml")" ]
}

@test "bun reads the repo bunfig.toml from the home directory" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  [ "$(expected_state_rows bun)" = "$(printf 'link\t%s\t%s' \
    "$DOTFILES_DIR/bun/bunfig.toml" "$HOME/.bunfig.toml")" ]
}

@test "uv and bun are expected-state groups" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  run expected_state_groups

  [[ $'\n'"$output"$'\n' == *$'\n'uv$'\n'* ]]
  [[ $'\n'"$output"$'\n' == *$'\n'bun$'\n'* ]]
}

@test "npm is expected to wait seven days and refuse unapproved install scripts" {
  source "$REPO_ROOT/scripts/lib/expected-state.sh"

  [ "$(expected_npm_config)" = "$(printf 'min-release-age\t7\nstrict-allow-scripts\ttrue')" ]
}

@test "the repo uv config excludes releases newer than seven days" {
  run grep -Ex 'exclude-newer = "7 days"' "$REPO_ROOT/uv/uv.toml"

  [ "$status" -eq 0 ]
}

@test "the repo bun config sets a seven day minimum release age under [install]" {
  # minimumReleaseAge = 604800 (seconds) inside the [install] table.
  run awk '/^\[install\]$/ { in_install = 1; next }
    /^\[/ { in_install = 0 }
    in_install && /^minimumReleaseAge = 604800$/ { found = 1 }
    END { exit found ? 0 : 1 }' "$REPO_ROOT/bun/bunfig.toml"

  [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------------------
# Bootstrap
# ------------------------------------------------------------------------------

@test "install_uv links the uv config when uv is already installed" {
  make_policy_sources
  make_stub uv 'echo "uv 0.0.0"'

  run_bootstrap install_uv

  [ "$status" -eq 0 ]
  [ -d "$CONFIG_DIR/uv" ] && [ ! -L "$CONFIG_DIR/uv" ]
  [ "$(readlink "$CONFIG_DIR/uv/uv.toml")" = "$DOTFILES_DIR/uv/uv.toml" ]
}

@test "install_uv keeps local uv state beside the linked config" {
  make_policy_sources
  make_stub uv 'echo "uv 0.0.0"'
  mkdir -p "$CONFIG_DIR/uv"
  echo '{"local": true}' >"$CONFIG_DIR/uv/uv-receipt.json"

  run_bootstrap install_uv

  [ "$status" -eq 0 ]
  [ "$(cat "$CONFIG_DIR/uv/uv-receipt.json")" = '{"local": true}' ]
  [ -L "$CONFIG_DIR/uv/uv.toml" ]
}

@test "install_bun links the bun config when bun is already installed" {
  make_policy_sources
  make_stub bun 'echo "0.0.0"'

  run_bootstrap install_bun

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.bunfig.toml")" = "$DOTFILES_DIR/bun/bunfig.toml" ]
}

@test "setup_node sets the npm install policy" {
  make_node_toolchain_stubs

  run_bootstrap 'INSTALL_NODE=1 setup_node'

  [ "$status" -eq 0 ]
  grep -Fxq "config set min-release-age 7" "$NPM_LOG"
  grep -Fxq "config set strict-allow-scripts true" "$NPM_LOG"
}

@test "setup_node warns and carries on when npm does not know a policy key" {
  make_node_toolchain_stubs
  export NPM_STRICT_ALLOW_SCRIPTS=undefined

  run_bootstrap 'set -euo pipefail; INSTALL_NODE=1 setup_node; echo "still running"'

  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN:"*"npm 0.0.0 does not support strict-allow-scripts"*"fnm install --lts"* ]]
  [[ "$output" == *"still running"* ]]
  grep -Fxq "config set min-release-age 7" "$NPM_LOG"
  run grep -Fq "config set strict-allow-scripts" "$NPM_LOG"
  [ "$status" -ne 0 ]
}

@test "the standalone node installer sets the same npm install policy" {
  make_node_toolchain_stubs

  run bash "$REPO_ROOT/node/install.sh"

  [ "$status" -eq 0 ]
  grep -Fxq "config set min-release-age 7" "$NPM_LOG"
  grep -Fxq "config set strict-allow-scripts true" "$NPM_LOG"
}

@test "the Gemini CLI install approves its native module install scripts by name" {
  # shellcheck disable=SC2016  # the stub expands these when it runs
  make_stub npm 'echo "$*" >>"$NPM_LOG"
if [[ "$1" == "install" ]]; then
  printf "#!/bin/bash\necho 0.0.0\n" >"$GEMINI_CLI_PREFIX/bin/gemini"
  chmod +x "$GEMINI_CLI_PREFIX/bin/gemini"
fi'
  make_stub node 'echo "v0.0.0"'
  export GEMINI_CLI_PREFIX="$HOME/.local"

  run_bootstrap install_gemini_cli

  [ "$status" -eq 0 ]
  grep -Fxq "install -g --prefix $GEMINI_CLI_PREFIX --allow-scripts=@github/keytar,node-pty @google/gemini-cli" "$NPM_LOG"
}

# ------------------------------------------------------------------------------
# Audit
# ------------------------------------------------------------------------------

@test "the audit passes when the links and npm settings are in place" {
  link_policy_files
  make_npm_stub

  run_audit audit_section_package_install_policy

  [ "$status" -eq 0 ]
  [[ "$output" == *"Package Install Policy"* ]]
  [[ "$output" == *"✓"*"~/.config/uv/uv.toml -> $DOTFILES_DIR/uv/uv.toml"* ]]
  [[ "$output" == *"✓"*"~/.bunfig.toml -> $DOTFILES_DIR/bun/bunfig.toml"* ]]
  [[ "$output" == *"✓"*"npm min-release-age: 7"* ]]
  [[ "$output" == *"✓"*"npm strict-allow-scripts: true"* ]]
  [[ "$output" == *"PASS=5 FAIL=0 WARN=0"* ]]
}

@test "the audit fails when the config links are missing" {
  make_policy_sources
  make_npm_stub

  run_audit audit_section_package_install_policy

  [[ "$output" == *"✗"*"~/.config/uv/uv.toml"* ]]
  [[ "$output" == *"✗"*"~/.bunfig.toml"* ]]
}

@test "the audit fails npm settings that differ and names the fix" {
  link_policy_files
  make_npm_stub
  export NPM_MIN_RELEASE_AGE=null NPM_STRICT_ALLOW_SCRIPTS=false

  run_audit audit_section_package_install_policy

  [[ "$output" == *"✗"*"npm min-release-age: null (expected 7; run: npm config set min-release-age 7)"* ]]
  [[ "$output" == *"✗"*"npm strict-allow-scripts: false (expected true; run: npm config set strict-allow-scripts true)"* ]]
  [[ "$output" == *"PASS=3 FAIL=2 WARN=0"* ]]
}

@test "the audit tells an npm that does not know a policy key to upgrade" {
  link_policy_files
  make_npm_stub
  export NPM_STRICT_ALLOW_SCRIPTS=undefined

  run_audit audit_section_package_install_policy

  [[ "$output" == *"✗"*"npm strict-allow-scripts: not supported by npm 0.0.0 (upgrade Node: fnm install --lts, then rerun node/install.sh)"* ]]
  [[ "$output" != *"run: npm config set strict-allow-scripts"* ]]
  [[ "$output" == *"PASS=4 FAIL=1 WARN=0"* ]]
}

@test "the audit skips the npm settings when npm is not installed" {
  if command -v npm >/dev/null 2>&1; then
    skip "this host has npm in /usr/bin or /bin"
  fi
  link_policy_files

  run_audit audit_section_package_install_policy

  [ "$status" -eq 0 ]
  [[ "$output" != *"npm"* ]]
  [[ "$output" == *"PASS=3 FAIL=0 WARN=0"* ]]
}

@test "both platform audits run the package install policy section" {
  grep -qx 'audit_section_package_install_policy' "$REPO_ROOT/scripts/audit-mac.sh"
  grep -qx 'audit_section_package_install_policy' "$REPO_ROOT/scripts/audit-linux.sh"
}
