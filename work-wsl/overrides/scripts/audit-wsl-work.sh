#!/usr/bin/env bash
set -uo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config}"
STATE_DIR="$HOME/.work-wsl"
ENABLED_TOOLS="$STATE_DIR/enabled-tools"

PASS=0
FAIL=0
WARN=0

pass() { printf '  \033[32mOK\033[0m %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$*"; WARN=$((WARN + 1)); }
section() { printf '\n== %s ==\n' "$*"; }

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd: $(command -v "$cmd")"
  else
    fail "$cmd missing"
  fi
}

check_pkg() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    pass "package: $pkg"
  else
    fail "package missing: $pkg"
  fi
}

check_link() {
  local path="$1"
  local expected="$2"
  if [[ -L "$path" && "$(readlink "$path")" == "$expected" ]]; then
    pass "$path -> $expected"
  elif [[ -L "$path" ]]; then
    fail "$path points to $(readlink "$path"), expected $expected"
  elif [[ -e "$path" ]]; then
    fail "$path exists but is not a generated symlink"
  else
    fail "$path missing"
  fi
}

enabled_tool() {
  local tool="$1"
  [[ -f "$ENABLED_TOOLS" ]] && grep -qxF "$tool" "$ENABLED_TOOLS"
}

blocked_terms() {
  printf '%s\n' \
    "n""tfy" "N""TFY" "n""tfy.sh" \
    "cla""ude" "co""dex" "ge""mini" "open""code" "l""lm" "co""pilot" \
    "kevin""mcmahon" "/Users/kevin/dot""files" \
    "OPENAI""_API_KEY" "ANTHROPIC""_API_KEY" \
    "gh""p_" "gh""o_" "gh""u_" "gh""s_" "gh""r_" "github""_pat_" \
    "sk""-proj-" "sk""-"
}

scan_boundary_files() {
  local term matches
  if ! command -v rg >/dev/null 2>&1; then
    fail "rg missing; cannot run boundary scan"
    return
  fi

  while IFS= read -r term; do
    [[ -n "$term" ]] || continue
    matches="$(rg -n --hidden --no-ignore -S -F "$term" \
      "$DOTFILES_DIR" "$HOME/.gitconfig" "$HOME/.gitconfig-local" "$HOME/.gituserconfig.work" "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zprofile" \
      -g '!.git/**' 2>/dev/null | grep -v '/git/gitconfig-secrets\.symlink:' || true)"
    if [[ -n "$matches" ]]; then
      printf '%s\n' "$matches"
      fail "blocked marker found: $term"
    fi
  done < <(blocked_terms)
}

check_no_blocked_dirs() {
  local d1 d2 d3 l1
  d1=".$(printf '%s' "cla""ude")"
  d2=".$(printf '%s' "co""dex")"
  d3=".$(printf '%s' "open""code")"
  l1="$(printf '%s' "l""lm")"
  for path in "$HOME/$d1" "$HOME/$d2" "$HOME/$d3" "$CONFIG_DIR/io.datasette.$l1"; do
    if [[ -e "$path" || -L "$path" ]]; then
      fail "blocked config path exists: $path"
    else
      pass "blocked config path absent: $path"
    fi
  done
}

check_generated_symlinks_stay_local() {
  local link target
  while IFS= read -r -d '' link; do
    target="$(readlink "$link")"
    if [[ "$target" == /* ]]; then
      fail "mirror symlink uses absolute target: $link -> $target"
    elif [[ "$target" == *".."* ]]; then
      fail "mirror symlink escapes its directory: $link -> $target"
    else
      pass "mirror symlink stays local: $link -> $target"
    fi
  done < <(find "$DOTFILES_DIR" -type l -print0 2>/dev/null)
}

section "Platform"
if [[ "$(uname -s)" == "Linux" ]]; then pass "Linux detected"; else fail "not Linux"; fi
if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then pass "WSL detected"; else fail "WSL not detected"; fi
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" == "ubuntu" ]]; then
    pass "Ubuntu detected"
  else
    fail "Ubuntu required"
  fi
  if [[ "${VERSION_ID:-}" == 24.04* ]]; then
    pass "Ubuntu 24.04.x detected"
  else
    fail "Ubuntu 24.04.x required"
  fi
else
  fail "/etc/os-release missing"
fi

section "Core Packages"
core_packages=(
  ca-certificates curl wget unzip xz-utils tar
  git git-lfs git-secrets jq make gcc g++ pkg-config libclang-dev
  zsh tmux ripgrep fd-find bat gpg gawk locales tree
)
for pkg in "${core_packages[@]}"; do check_pkg "$pkg"; done

section "Core Commands"
for cmd in git tmux rg jq make gcc zsh curl wget; do check_cmd "$cmd"; done
check_link "$LOCAL_BIN/fd" "$(command -v fdfind 2>/dev/null || printf fdfind)"
check_link "$LOCAL_BIN/bat" "$(command -v batcat 2>/dev/null || printf batcat)"

section "Generated Symlinks"
check_link "$HOME/.gitconfig" "$DOTFILES_DIR/git/gitconfig.symlink"
check_link "$HOME/.gitignore_global" "$DOTFILES_DIR/git/gitignore_global.symlink"
check_link "$HOME/.gitconfig-secrets" "$DOTFILES_DIR/git/gitconfig-secrets.symlink"
check_link "$HOME/.git-core" "$DOTFILES_DIR/git/git-core.symlink"
check_link "$HOME/.zshrc" "$DOTFILES_DIR/zsh/zshrc.symlink"
check_link "$HOME/.zshenv" "$DOTFILES_DIR/zsh/zshenv.symlink"
check_link "$HOME/.zprofile" "$DOTFILES_DIR/zsh/zprofile.symlink"
check_link "$HOME/.zsh/env" "$DOTFILES_DIR/zsh/env"
check_link "$HOME/.zsh/alias.zsh" "$DOTFILES_DIR/zsh/alias.zsh"
check_link "$CONFIG_DIR/tmux/tmux.conf" "$DOTFILES_DIR/tmux/tmux.conf"
check_link "$CONFIG_DIR/starship" "$DOTFILES_DIR/starship"

section "Git Identity"
if git config --global user.email >/dev/null 2>&1; then
  email="$(git config --global user.email)"
  case "$email" in
    *users.noreply.github.com*) fail "global Git email appears personal: $email" ;;
    *) pass "global Git email configured: $email" ;;
  esac
else
  warn "global Git email is unset; commits require work repo routing or local identity"
fi
if [[ -f "$HOME/.gituserconfig.work" ]]; then
  pass "work identity template exists"
else
  fail "work identity template missing"
fi

section "Boundary"
scan_boundary_files
check_no_blocked_dirs
check_generated_symlinks_stay_local

section "Optional Tools"
declare -A optional_commands=(
  [node]=node
  [rust]=rustup
  [neovim]=nvim
  [fzf]=fzf
  [starship]=starship
  [lazygit]=lazygit
  [yazi]=yazi
)
for tool in "${!optional_commands[@]}"; do
  cmd="${optional_commands[$tool]}"
  if command -v "$cmd" >/dev/null 2>&1; then
    if enabled_tool "$tool"; then
      pass "optional tool intentionally enabled: $tool"
    else
      fail "optional tool present without enable marker: $tool"
    fi
  else
    warn "optional tool absent: $tool"
  fi
done

section "Summary"
printf '\n%d passed, %d failed, %d warnings\n' "$PASS" "$FAIL" "$WARN"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
