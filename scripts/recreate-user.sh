#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# User Recreation Script
# ------------------------------------------------------------------------------
# Backs up .ssh directory, deletes user, creates new user, restores .ssh
#
# USAGE:
#   Must be run from a DIFFERENT privileged account (not the target user)
#
# EXAMPLE - Recreate 'moltbot' user from 'ubuntu' account:
#
#   # Step 1: As moltbot, copy script to safe location
#   sudo cp ~/dotfiles/scripts/recreate-user.sh /tmp/
#
#   # Step 2: Logout and SSH in as ubuntu
#   ssh ubuntu@your-server
#
#   # Step 3: Run script to recreate moltbot
#   sudo /tmp/recreate-user.sh moltbot
#
#   # Step 4: SSH back in as new moltbot user
#   ssh moltbot@your-server
#
#   # Step 5: Clone dotfiles and bootstrap
#   git clone <repo> ~/dotfiles
#   cd ~/dotfiles/scripts && ./bootstrap.sh
#
# WHAT IT DOES:
#   - Backs up target user's .ssh to /root/user-backup-<timestamp>
#   - Kills all processes owned by target user
#   - Deletes user and home directory completely
#   - Creates fresh user with zsh as default shell
#   - Restores .ssh directory with correct permissions
#   - Optionally adds user to sudo group
#
# REQUIREMENTS:
#   - Must be run as root or with sudo
#   - Cannot be run as the target user (use different admin account)
#   - Target user must exist
# ------------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)"
   echo "Example: sudo $0 <username>"
   exit 1
fi

# ------------------------------------------------------------------------------
# Argument parsing and validation
# ------------------------------------------------------------------------------

USERNAME="${1:-}"
if [[ -z "$USERNAME" ]]; then
  echo "ERROR: Username required"
  echo ""
  echo "Usage: sudo $0 <username>"
  echo "Example: sudo $0 moltbot"
  exit 1
fi

# Safety check - don't allow root
if [[ "$USERNAME" == "root" ]]; then
  echo "ERROR: Cannot recreate root user"
  exit 1
fi

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
  echo "ERROR: User '$USERNAME' does not exist"
  exit 1
fi

# Check if current user is trying to delete themselves
CURRENT_USER="${SUDO_USER:-$USER}"
if [[ "$CURRENT_USER" == "$USERNAME" ]]; then
  echo "ERROR: Cannot delete yourself!"
  echo "You are currently: $CURRENT_USER"
  echo "You are trying to delete: $USERNAME"
  echo ""
  echo "Please login as a different admin user (e.g., ubuntu) and try again."
  exit 1
fi

# ------------------------------------------------------------------------------
# Setup and confirmation
# ------------------------------------------------------------------------------

USER_HOME=$(eval echo "~$USERNAME")
SSH_DIR="$USER_HOME/.ssh"
BACKUP_DIR="/root/user-backup-$USERNAME-$(date +%Y%m%d-%H%M%S)"

echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│               USER RECREATION SCRIPT                       │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""
echo "  Target user:     $USERNAME"
echo "  Home directory:  $USER_HOME"
echo "  Backup location: $BACKUP_DIR"
echo "  Running as:      $CURRENT_USER"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
echo "⚠️  WARNING: This will PERMANENTLY:"
echo ""
echo "  1. Backup .ssh directory (if exists)"
echo "  2. Kill all processes owned by '$USERNAME'"
echo "  3. DELETE user '$USERNAME' and ALL files in $USER_HOME"
echo "  4. Create fresh user '$USERNAME' with zsh shell"
echo "  5. Restore .ssh directory from backup"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
read -p "Type 'yes' to continue, anything else to abort: " confirm

if [[ "$confirm" != "yes" ]]; then
  echo ""
  echo "❌ Aborted by user"
  exit 0
fi

echo ""
echo "────────────────────────────────────────────────────────────"

# ------------------------------------------------------------------------------
# Execution
# ------------------------------------------------------------------------------

echo ""
echo "[1/7] Creating backup directory..."
mkdir -p "$BACKUP_DIR"
echo "      ✓ Created: $BACKUP_DIR"

echo ""
echo "[2/7] Backing up .ssh directory..."
if [[ -d "$SSH_DIR" ]]; then
  cp -a "$SSH_DIR" "$BACKUP_DIR/ssh-backup"
  echo "      ✓ Backed up to: $BACKUP_DIR/ssh-backup"
  echo "      ✓ Found $(find "$SSH_DIR" -type f | wc -l) files"
else
  echo "      ℹ No .ssh directory found at $SSH_DIR"
  echo "      ℹ Will create fresh .ssh after user creation"
fi

echo ""
echo "[3/7] Killing processes owned by $USERNAME..."
PROC_COUNT=$(pgrep -u "$USERNAME" | wc -l || echo "0")
if [[ "$PROC_COUNT" -gt 0 ]]; then
  echo "      ℹ Found $PROC_COUNT processes to kill"
  pkill -u "$USERNAME" || true
  sleep 2
  echo "      ✓ Processes terminated"
else
  echo "      ℹ No processes running"
fi

echo ""
echo "[4/7] Deleting user and home directory..."
if userdel -r "$USERNAME" 2>/dev/null; then
  echo "      ✓ User deleted: $USERNAME"
  echo "      ✓ Home directory removed: $USER_HOME"
else
  echo "      ⚠ userdel reported errors (may be partial - continuing)"
fi
sleep 1

echo ""
echo "[5/7] Creating fresh user..."
useradd -m -s /bin/zsh "$USERNAME"
NEW_HOME=$(eval echo "~$USERNAME")
echo "      ✓ User created: $USERNAME"
echo "      ✓ Home directory: $NEW_HOME"
echo "      ✓ Default shell: /bin/zsh"

echo ""
echo "[6/7] Setting password..."
echo "────────────────────────────────────────────────────────────"
passwd "$USERNAME"
echo "────────────────────────────────────────────────────────────"
echo "      ✓ Password set"

echo ""
echo "[7/7] Restoring .ssh directory..."
if [[ -d "$BACKUP_DIR/ssh-backup" ]]; then
  cp -a "$BACKUP_DIR/ssh-backup" "$NEW_HOME/.ssh"

  # Fix ownership first
  chown -R "$USERNAME:$USERNAME" "$NEW_HOME/.ssh"

  # Fix permissions properly:
  # - All directories: 700 (rwx------)
  # - Private keys: 600 (rw-------)
  # - Public keys: 644 (rw-r--r--)
  # - config/known_hosts: 600 (rw-------)
  find "$NEW_HOME/.ssh" -type d -exec chmod 700 {} \;
  find "$NEW_HOME/.ssh" -type f -exec chmod 600 {} \;
  find "$NEW_HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} \;

  echo "      ✓ Restored .ssh directory"
  echo "      ✓ Fixed ownership ($USERNAME:$USERNAME)"
  echo "      ✓ Fixed permissions:"
  echo "        - Directories: 700 (rwx------)"
  echo "        - Private keys: 600 (rw-------)"
  echo "        - Public keys: 644 (rw-r--r--)"
else
  echo "      ℹ No .ssh backup to restore"
fi

echo ""
echo "────────────────────────────────────────────────────────────"
read -p "Add $USERNAME to sudo group? (y/n): " add_sudo
if [[ "$add_sudo" =~ ^[Yy]$ ]]; then
  usermod -aG sudo "$USERNAME"
  echo "      ✓ Added to sudo group"
else
  echo "      ℹ Skipped sudo group"
fi

echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│            ✓ USER RECREATION COMPLETE                     │"
echo "└────────────────────────────────────────────────────────────┘"
echo ""
echo "  Username:        $USERNAME"
echo "  Home directory:  $NEW_HOME"
echo "  Default shell:   /bin/zsh"
echo "  Backup location: $BACKUP_DIR"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
echo "📋 NEXT STEPS:"
echo ""
echo "  1. SSH into the recreated user:"
echo "     ssh $USERNAME@your-server"
echo ""
echo "  2. Clone your dotfiles repository:"
echo "     git clone <your-repo-url> ~/dotfiles"
echo ""
echo "  3. Run the bootstrap script:"
echo "     cd ~/dotfiles/scripts"
echo "     ./bootstrap.sh"
echo ""
echo "     (Bootstrap will be faster - system packages already installed)"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
echo "💾 BACKUP:"
echo ""
echo "  Location: $BACKUP_DIR"
echo ""
echo "  The backup contains your old .ssh directory and will persist"
echo "  until manually deleted. Remove when no longer needed:"
echo ""
echo "    sudo rm -rf $BACKUP_DIR"
echo ""
echo "────────────────────────────────────────────────────────────"
echo ""
