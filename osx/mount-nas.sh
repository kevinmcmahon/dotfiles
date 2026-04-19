#!/bin/bash
# Mount an SMB share if it is not already alive.
#
# Config lives in ~/.config/nas-mount.env (gitignored, machine-local):
#   NAS_HOST           — required (e.g. 192.168.7.173)
#   NAS_USER           — required (SMB username, credentials come from Keychain)
#   NAS_SHARE          — required (share name, e.g. "data")
#   NAS_MOUNT_POINT    — optional, defaults to /Volumes/$NAS_SHARE
#   NAS_SENTINEL       — optional, defaults to $NAS_MOUNT_POINT/documents
#
# The sentinel check guards against stale mounts: macOS sometimes leaves an
# empty /Volumes/<share> directory behind when an SMB mount goes dead, so we
# probe a known subdirectory instead of just the mount point.

set -u

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nas-mount.env"
[ -r "$CONFIG" ] || exit 0
# shellcheck disable=SC1090
. "$CONFIG"

: "${NAS_HOST:?NAS_HOST not set in $CONFIG}"
: "${NAS_USER:?NAS_USER not set in $CONFIG}"
: "${NAS_SHARE:?NAS_SHARE not set in $CONFIG}"
: "${NAS_MOUNT_POINT:=/Volumes/${NAS_SHARE}}"
: "${NAS_SENTINEL:=${NAS_MOUNT_POINT}/documents}"

SMB_URL="smb://${NAS_USER}@${NAS_HOST}/${NAS_SHARE}"

# Fast path: mount is already alive, nothing to do.
if [ -d "$NAS_SENTINEL" ]; then
    exit 0
fi

# Require a Keychain entry before attempting the mount. Without one, osascript
# would pop a GUI password prompt every StartInterval cycle.
if ! /usr/bin/security find-internet-password -s "$NAS_HOST" -a "$NAS_USER" >/dev/null 2>&1; then
    exit 0
fi

# Probe SMB (TCP/445) with a short connect timeout. Skip silently when the
# host is unreachable (off-LAN without Tailscale, NAS rebooting, laptop
# offline) to avoid macOS's "couldn't connect" popup that osascript would
# otherwise trigger. -G bounds the connect phase; 2s is generous even for
# Tailscale relay paths.
if ! /usr/bin/nc -z -G 2 "$NAS_HOST" 445 >/dev/null 2>&1; then
    exit 0
fi

/usr/bin/osascript -e "mount volume \"$SMB_URL\"" >/dev/null 2>&1
