# macOS Setup

Scripts and config fragments specific to macOS. Most are invoked automatically
by `scripts/bootstrap.sh`; a few require one-time manual setup.

## Scripts

| File | Purpose | Invoked by |
|---|---|---|
| `set-defaults.sh` | Apply `defaults write` tweaks (Finder, Dock, keyboard, trackpad, etc.) | `apply_macos_defaults` in `scripts/lib/platform-mac.sh` |
| `set-spotlight-configs.sh` | Mark `~/Library/Caches` and `~/Library/Developer` as never-indexed | `apply_spotlight_configs` |
| `install-nerd-fonts.sh` | Install Nerd Fonts via Homebrew | Manual |
| `install-nas-mount.sh` | Install `mount-nas.sh` + load its LaunchAgent | `install_nas_mount_agent` |
| `mount-nas.sh` | Idempotent SMB re-mount helper (called by the LaunchAgent every 60s) | LaunchAgent `com.kevin.mountnas` |

Skip macOS defaults by running `SKIP_DEFAULTS=1 scripts/bootstrap.sh`.
Skip just the NAS mount agent with `SKIP_NAS_MOUNT=1`.

## NAS auto-mount setup (one-time)

Keeps a QNAP SMB share automatically mounted, surviving sleep/wake and reboots.

1. **Prime the Keychain.** Open Finder → `Cmd+K` → enter
   `smb://<user>@<host>/<share>`. When prompted, check **"Remember this password
   in my keychain"**.
2. **Verify credentials stuck:**
   ```bash
   security find-internet-password -s <NAS_HOST> -a <NAS_USER>
   ```
3. **Create the local config:**
   ```bash
   cp osx/nas-mount.env.example ~/.config/nas-mount.env
   chmod 600 ~/.config/nas-mount.env
   $EDITOR ~/.config/nas-mount.env
   ```
4. **Load the agent** (bootstrap does this automatically, or run directly):
   ```bash
   bash osx/install-nas-mount.sh
   ```
5. **First-run permission prompt.** macOS Sequoia/Tahoe may prompt the first
   time the agent mounts a network volume — approve it. If mounts silently
   fail with no prompt, check System Settings → Privacy & Security → Full Disk
   Access and allow `sh` or `osascript`.

### Verify

```bash
launchctl print "gui/$UID/com.kevin.mountnas" | head -20
diskutil unmount /Volumes/<share>     # force a remount cycle
sleep 65 && mount | grep <share>      # should be back
tail -n 20 ~/Library/Logs/mount-nas.log
```

### Stop / reload

```bash
launchctl bootout  "gui/$UID/com.kevin.mountnas"
launchctl bootstrap "gui/$UID" ~/Library/LaunchAgents/com.kevin.mountnas.plist
```
