#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
  export DOTFILES_DIR="$REPO_ROOT"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$TEST_BIN"
  export PATH="$TEST_BIN:/usr/bin:/bin"

  cat >"$TEST_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Unsupported\n'
EOF
  chmod +x "$TEST_BIN/uname"
}

set_linux_uname() {
  cat >"$TEST_BIN/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'aarch64\n' ;;
  *) printf 'Linux\n' ;;
esac
EOF
  chmod +x "$TEST_BIN/uname"
}

profile_trace() {
  local profile="${1:-}"
  set_linux_uname

  PROFILE_TO_TRACE="$profile" bash -c '
    source "$REPO_ROOT/scripts/bootstrap.sh"
    setup_logging() { :; }
    log() { :; }
    for name in \
      preflight_checks ensure_dirs ensure_local_bin_in_path install_platform_foundation \
      symlink_dotfiles_symlink_pattern ensure_git_identity_templates symlink_xdg_dirs \
      install_platform_packages install_tmux_plugins install_zsh_environment \
      set_default_shell_zsh install_rust_and_cargo_tools install_uv install_deno \
      install_bun setup_node install_nvim_python_venv_uv install_ruff_uv install_llm \
      symlink_llm_templates install_claude_code install_codex install_gemini_cli \
      install_opencode ensure_claude_skills_dir ensure_opencode_skills_dir \
      sync_ai_resources ensure_pplx_search_bin symlink_claude_config \
      symlink_opencode_ai_dirs install_ai_skills symlink_codex_config \
      verify_claude_setup verify_codex_setup apply_platform_config post_checks \
      print_next_steps install_server_packages write_bootstrap_profile_marker \
      symlink_server_dotfiles ensure_server_git_identity post_checks_server \
      print_server_next_steps; do
      eval "$name() { echo $name; }"
    done
    if [[ -n "$PROFILE_TO_TRACE" ]]; then
      parse_bootstrap_args --profile "$PROFILE_TO_TRACE"
    fi
    main
  '
}

@test "bootstrap rejects an unknown profile before platform setup" {
  run "$REPO_ROOT/scripts/bootstrap.sh" --profile unknown

  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown profile: unknown"* ]]
  [[ "$output" != *"Unsupported platform"* ]]
}

@test "default profile has the same phase sequence as explicit workstation" {
  run profile_trace
  [ "$status" -eq 0 ]
  default_trace="$output"

  run profile_trace workstation
  [ "$status" -eq 0 ]
  [ "$output" = "$default_trace" ]
}

@test "workstation profile records its local marker" {
  run profile_trace workstation

  [ "$status" -eq 0 ]
  [[ "$output" == *$'ensure_dirs\nwrite_bootstrap_profile_marker\nensure_local_bin_in_path'* ]]
}

@test "server profile runs only its fixed phases" {
  run profile_trace server

  [ "$status" -eq 0 ]
  [ "$output" = "preflight_checks
ensure_dirs
ensure_local_bin_in_path
install_server_packages
write_bootstrap_profile_marker
symlink_server_dotfiles
ensure_server_git_identity
install_tmux_plugins
install_zsh_environment
set_default_shell_zsh
post_checks_server
print_server_next_steps" ]
}

@test "server package set is fixed and excludes development runtimes and AI tools" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  sudo() { printf '%s\n' "$*"; }

  run install_server_packages

  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get install -y ca-certificates curl git git-lfs jq zsh tmux neovim ripgrep fd-find bat fzf less tree htop rsync unzip openssh-client dnsutils iproute2 procps lsof"* ]]
  [[ "$output" != *" rust"* ]]
  [[ "$output" != *" node"* ]]
  [[ "$output" != *" bun"* ]]
  [[ "$output" != *" deno"* ]]
  [[ "$output" != *" uv"* ]]
  [[ "$output" != *"claude"* ]]
  [[ "$output" != *"codex"* ]]
}

@test "server symlinks only the reviewed shell tmux and Git set" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  export CONFIG_DIR="$HOME/.config"
  mkdir -p "$HOME"

  symlink_server_dotfiles

  expected=(
    "$HOME/.gitconfig"
    "$HOME/.gitignore_global"
    "$HOME/.zprofile"
    "$HOME/.zshenv"
    "$HOME/.zshrc"
    "$HOME/.zsh/env"
    "$HOME/.config/tmux/tmux.conf"
  )
  for path in "${expected[@]}"; do
    [ -L "$path" ]
  done
  [ ! -e "$HOME/.config/nvim" ]
  [ ! -e "$HOME/.claude" ]
  [ ! -e "$HOME/.codex" ]
  [ ! -e "$HOME/.gitconfig-linux" ]
  [ ! -e "$HOME/.gitconfig-secrets" ]
  [ ! -e "$HOME/.git-core" ]
}

@test "server marker suppresses private overlays and tool runtime hooks" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  export CONFIG_DIR="$HOME/.config"
  mkdir -p "$HOME/.zsh/env/optional" "$HOME/.zsh/env/tools" "$HOME/.zsh/env/core" "$HOME/.zsh/env/platform"
  cp "$REPO_ROOT/zsh/zshenv.symlink" "$HOME/.zshenv"
  cp "$REPO_ROOT/zsh/zshrc.symlink" "$HOME/.zshrc"
  cp "$REPO_ROOT/zsh/env/core/"*.zsh "$HOME/.zsh/env/core/"
  cp "$REPO_ROOT/zsh/env/platform/linux.zsh" "$HOME/.zsh/env/platform/linux.zsh"
  printf 'touch %q\n' "$HOME/private-loaded" >"$HOME/.zsh/env/optional/private.zsh"
  printf 'touch %q\n' "$HOME/tool-loaded" >"$HOME/.zsh/env/tools/probe.zsh"
  printf 'touch %q\n' "$HOME/runtime-loaded" >"$HOME/.zsh/env/core/runtime.zsh"
  printf 'touch %q\n' "$HOME/ruby-loaded" >"$HOME/.zsh/env/core/ruby.zsh"
  printf 'touch %q\n' "$HOME/completion-loaded" >"$HOME/.zsh/env/optional/local_completions.zsh"
  for command_name in uv uvx deno; do
    cat >"$TEST_BIN/$command_name" <<EOF
#!/usr/bin/env bash
touch "$HOME/$command_name-called"
EOF
    chmod +x "$TEST_BIN/$command_name"
  done

  write_bootstrap_profile_marker server
  run env HOME="$HOME" PATH="/usr/bin:/bin" /bin/zsh -c 'source "$HOME/.zshenv"; source "$HOME/.zshrc"'

  [ "$status" -eq 0 ]
  [ ! -e "$HOME/private-loaded" ]
  [ ! -e "$HOME/tool-loaded" ]
  [ ! -e "$HOME/runtime-loaded" ]
  [ ! -e "$HOME/ruby-loaded" ]
  [ ! -e "$HOME/completion-loaded" ]
  [ ! -e "$HOME/uv-called" ]
  [ ! -e "$HOME/uvx-called" ]
  [ ! -e "$HOME/deno-called" ]
}

@test "an absent marker keeps workstation overlay behavior" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.zsh/env/optional" "$HOME/.zsh/env/core"
  cp "$REPO_ROOT/zsh/zshenv.symlink" "$HOME/.zshenv"
  cp "$REPO_ROOT/zsh/env/core/path.zsh" "$HOME/.zsh/env/core/path.zsh"
  printf 'touch %q\n' "$HOME/private-loaded" >"$HOME/.zsh/env/optional/private.zsh"

  run env HOME="$HOME" PATH="/usr/bin:/bin" /bin/zsh -c 'source "$HOME/.zshenv"'

  [ "$status" -eq 0 ]
  [ -e "$HOME/private-loaded" ]
}

@test "server bootstrap fails when required zsh installation fails" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  export PROFILE=server
  bash() { return 23; }

  run install_zsh_environment

  [ "$status" -eq 23 ]
}

@test "server zsh installation defers its inner default-shell change" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  export PROFILE=server
  bash() { printf '%s:%s\n' "${SKIP_DEFAULT_SHELL:-unset}" "${SKIP_WORKSTATION_ALIASES:-unset}" >"$BATS_TEST_TMPDIR/skip-shell"; }

  install_zsh_environment

  [ "$(cat "$BATS_TEST_TMPDIR/skip-shell")" = '1:1' ]
}

@test "server zsh installer does not link workstation aliases" {
  home="$BATS_TEST_TMPDIR/home"
  custom="$home/.oh-my-zsh/custom"
  mkdir -p "$custom/plugins"
  for plugin in git-open zsh-defer zsh-autosuggestions zsh-syntax-highlighting you-should-use fzf-tab; do
    mkdir -p "$custom/plugins/$plugin"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_BIN/brew"
  chmod +x "$TEST_BIN/brew"
  ln -s "$REPO_ROOT/zsh/alias.zsh" "$custom/alias.zsh"

  run env HOME="$home" ZSH_CUSTOM="$custom" SKIP_DEFAULT_SHELL=1 SKIP_WORKSTATION_ALIASES=1 \
    bash "$REPO_ROOT/zsh/install.sh"

  [ "$status" -eq 0 ]
  [ ! -e "$custom/alias.zsh" ]
}

@test "server zsh installer refuses a user-owned alias file" {
  home="$BATS_TEST_TMPDIR/home"
  custom="$home/.oh-my-zsh/custom"
  mkdir -p "$custom/plugins"
  for plugin in git-open zsh-defer zsh-autosuggestions zsh-syntax-highlighting you-should-use fzf-tab; do
    mkdir -p "$custom/plugins/$plugin"
  done
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_BIN/brew"
  chmod +x "$TEST_BIN/brew"
  printf '%s\n' 'alias mine=true' >"$custom/alias.zsh"

  run env HOME="$home" ZSH_CUSTOM="$custom" SKIP_DEFAULT_SHELL=1 SKIP_WORKSTATION_ALIASES=1 \
    bash "$REPO_ROOT/zsh/install.sh"

  [ "$status" -ne 0 ]
  grep -qx 'alias mine=true' "$custom/alias.zsh"
}

@test "server shell does not export the workstation Ollama endpoint" {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/dotfiles"
  printf '%s\n' server >"$HOME/.config/dotfiles/profile"

  run env HOME="$HOME" OLLAMA_HOST=unexpected /bin/zsh -c \
    'source "$REPO_ROOT/zsh/zshenv.symlink"; print -r -- "${OLLAMA_HOST-unset}"'

  [ "$status" -eq 0 ]
  [ "$output" = unset ]
}

@test "server bootstrap fails when the default shell cannot change" {
  set_linux_uname
  source "$REPO_ROOT/scripts/bootstrap.sh"
  export PROFILE=server SHELL=/bin/bash
  zsh() { :; }
  grep() { return 0; }
  id() { printf '%s\n' ubuntu; }
  sudo() { return 24; }

  run set_default_shell_zsh

  [ "$status" -eq 24 ]
}
