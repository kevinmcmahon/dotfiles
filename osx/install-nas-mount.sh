#!/usr/bin/env bash
# Install the NAS auto-mount script and its LaunchAgent.
#
# Idempotent: re-running only reloads the agent when the plist actually changed.
# Safe to run on a fresh machine before ~/.config/nas-mount.env exists — the
# script will no-op until the config file is created.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LA_DIR="$HOME/Library/LaunchAgents"
LABEL="com.kevin.mountnas"
PLIST_SRC="$DOTFILES_DIR/osx/${LABEL}.plist"
PLIST_DEST="$LA_DIR/${LABEL}.plist"
SCRIPT_SRC="$DOTFILES_DIR/osx/mount-nas.sh"
SCRIPT_DEST="$LOCAL_BIN/mount-nas.sh"
CONFIG="$CONFIG_DIR/nas-mount.env"

mkdir -p "$LOCAL_BIN" "$LA_DIR" "$HOME/Library/Logs"

install -m 0755 "$SCRIPT_SRC" "$SCRIPT_DEST"

# launchd does not expand $HOME in plists, so we substitute at install time.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
sed "s|\${HOME}|$HOME|g" "$PLIST_SRC" > "$tmp"

plist_changed=0
if ! cmp -s "$tmp" "$PLIST_DEST"; then
    mv "$tmp" "$PLIST_DEST"
    trap - EXIT
    plist_changed=1
fi

# Only load the agent once prerequisites are in place: the env file exists and
# Keychain has an entry for the share. Without the Keychain entry, osascript
# would pop a GUI password prompt on every run.
missing=()
if [ ! -r "$CONFIG" ]; then
    missing+=("env file at $CONFIG")
fi

keychain_ok=0
if [ -r "$CONFIG" ]; then
    # shellcheck disable=SC1090
    ( . "$CONFIG"
      /usr/bin/security find-internet-password \
          -s "${NAS_HOST:-}" -a "${NAS_USER:-}" >/dev/null 2>&1 ) && keychain_ok=1
    if [ "$keychain_ok" -ne 1 ]; then
        missing+=("Keychain entry (mount the share once in Finder with \"Remember this password in my keychain\")")
    fi
fi

if [ "${#missing[@]}" -eq 0 ]; then
    agent_loaded=0
    launchctl print "gui/$UID/${LABEL}" >/dev/null 2>&1 && agent_loaded=1

    if [ "$plist_changed" -eq 1 ] || [ "$agent_loaded" -eq 0 ]; then
        launchctl bootout "gui/$UID/${LABEL}" 2>/dev/null || true
        launchctl bootstrap "gui/$UID" "$PLIST_DEST"
        echo "Loaded LaunchAgent: $LABEL"
    else
        echo "LaunchAgent $LABEL already loaded and up to date"
    fi
else
    echo "Installed NAS mount files but NOT loading the LaunchAgent yet. Missing:" >&2
    for item in "${missing[@]}"; do
        echo "  - $item" >&2
    done
    cat >&2 <<EOF

To finish setup:
  1. Open Finder, Cmd+K, mount smb://<user>@<host>/<share>, check
     "Remember this password in my keychain"
  2. cp $DOTFILES_DIR/osx/nas-mount.env.example $CONFIG
     chmod 600 $CONFIG
     \$EDITOR $CONFIG
  3. Re-run: bash $DOTFILES_DIR/osx/install-nas-mount.sh
EOF
fi
