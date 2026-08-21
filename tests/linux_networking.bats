#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN"
  export PATH="$TEST_BIN:/usr/bin:/bin"

  cat >"$TEST_BIN/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/apt-get"
}

@test "deferred Tailscale login installs components without prompting or enabling UFW" {
  run "$REPO_ROOT/scripts/setup-linux-networking.sh" \
    --defer-tailscale-login --skip-fail2ban --dry-run

  [ "$status" -eq 0 ]
  [[ "$output" == *"Tailscale login deferred"* ]]
  [[ "$output" == *"apt-get install -y mosh"* ]]
  [[ "$output" != *"Run 'sudo tailscale up' now"* ]]
  [[ "$output" != *"ufw --force enable"* ]]
}
