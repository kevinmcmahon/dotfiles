#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# User Recreation Script
# Backs up .ssh directory, deletes user, creates new user, restores .ssh
# MUST be run as root or with sudo
# ------------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Get username to recreate
USERNAME="${1:-}"
if [[ -z "$USERNAME" ]]; then
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
  echo "ERROR: User $USERNAME does not exist"
  exit 1
fi

# Get user's home directory before deletion
USER_HOME=$(eval echo "~$USERNAME")
SSH_DIR="$USER_HOME/.ssh"
BACKUP_DIR="/root/user-backup-$(date +%Y%m%d-%H%M%S)"

echo "=============================================================="
echo "User Recreation Script"
echo "=============================================================="
echo "Username:        $USERNAME"
echo "Home directory:  $USER_HOME"
echo "Backup location: $BACKUP_DIR"
echo "=============================================================="
echo ""
echo "WARNING: This will:"
echo "  1. Backup $SSH_DIR to $BACKUP_DIR"
echo "  2. Delete user $USERNAME and all files in $USER_HOME"
echo "  3. Create new user $USERNAME with empty home directory"
echo "  4. Restore .ssh directory with correct permissions"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup .ssh directory if it exists
if [[ -d "$SSH_DIR" ]]; then
  echo "Backing up .ssh directory..."
  cp -a "$SSH_DIR" "$BACKUP_DIR/ssh-backup"
  echo "✓ Backed up to $BACKUP_DIR/ssh-backup"
else
  echo "! No .ssh directory found at $SSH_DIR"
fi

# Kill all processes owned by the user
echo "Killing all processes owned by $USERNAME..."
pkill -u "$USERNAME" || true
sleep 2

# Delete the user and home directory
echo "Deleting user $USERNAME..."
userdel -r "$USERNAME" 2>/dev/null || {
  echo "! userdel failed or user already partially removed"
}

# Wait a moment
sleep 1

# Create new user
echo "Creating new user $USERNAME..."
useradd -m -s /bin/zsh "$USERNAME"

# Get the new home directory
NEW_HOME=$(eval echo "~$USERNAME")

# Set password
echo ""
echo "Setting password for $USERNAME..."
passwd "$USERNAME"

# Restore .ssh if backup exists
if [[ -d "$BACKUP_DIR/ssh-backup" ]]; then
  echo "Restoring .ssh directory..."
  cp -a "$BACKUP_DIR/ssh-backup" "$NEW_HOME/.ssh"

  # Fix ownership and permissions
  chown -R "$USERNAME:$USERNAME" "$NEW_HOME/.ssh"
  chmod 700 "$NEW_HOME/.ssh"
  chmod 600 "$NEW_HOME/.ssh"/* 2>/dev/null || true
  chmod 644 "$NEW_HOME/.ssh"/*.pub 2>/dev/null || true

  echo "✓ Restored .ssh directory"
else
  echo "! No .ssh backup to restore"
fi

# Add to sudo group (optional - remove if not needed)
read -p "Add $USERNAME to sudo group? (y/n): " add_sudo
if [[ "$add_sudo" =~ ^[Yy]$ ]]; then
  usermod -aG sudo "$USERNAME"
  echo "✓ Added to sudo group"
fi

echo ""
echo "=============================================================="
echo "User recreation complete!"
echo "=============================================================="
echo "Username:     $USERNAME"
echo "Home dir:     $NEW_HOME"
echo "Backup saved: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Login as $USERNAME"
echo "  2. Clone dotfiles: git clone <repo> ~/dotfiles"
echo "  3. Run bootstrap: cd ~/dotfiles/scripts && ./bootstrap-linux-dev.sh"
echo ""
echo "Backup will remain at: $BACKUP_DIR"
echo "Delete when no longer needed: rm -rf $BACKUP_DIR"
echo "=============================================================="
