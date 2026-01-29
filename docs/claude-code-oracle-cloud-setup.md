# Claude Code On-The-Go: Oracle Cloud Always Free + Ntfy Edition

Run Claude Code from your phone with push notifications when Claude needs input.

```
Phone (Termius) → mosh → Tailscale → Oracle ARM VM → Claude Code
                                           ↓
                              PreToolUse hook → ntfy.sh → push notification
```

## Prerequisites

- Oracle Cloud account (Pay-as-you-Go with budget alerts ✓)
- Tailscale account (free tier works fine)
- Termius on your phone
- ntfy app on your phone

---

## Part 1: Create the Oracle Cloud Instance

### 1.1 Navigate to Compute

1. Go to Oracle Cloud Console → Compute → Instances → Create Instance

### 1.2 Configure the Instance

**Name:** `claude-dev` (or whatever you prefer)

**Placement:** Leave default (your home region)

**Image and Shape:**
- Click "Edit" in the Image and shape section
- Click "Change image" → Select **Ubuntu 24.04** (Canonical Ubuntu)
- Click "Change shape":
  - Instance type: **Virtual machine**
  - Shape series: **Ampere** (ARM-based processor)
  - Shape name: **VM.Standard.A1.Flex**
  - OCPUs: **4**
  - Memory: **24 GB**

> ⚠️ **Capacity Issues:** If you get "Out of capacity" errors, try:
> - Different availability domain (if your region has multiple)
> - Try during off-peak hours (early morning UTC)
> - Reduce to 2 OCPUs / 12GB initially, resize later
> - Use the [OCI Instance Notifier](https://github.com/hitrov/oci-arm-host-capacity) script

**Networking:**
- Select your VCN or create a new one
- Select a public subnet (we'll lock it down with security lists)
- **Assign a public IPv4 address:** Yes (needed for initial setup and Tailscale coordination)

**SSH Keys:**
- Generate or upload your SSH key pair
- **Save the private key** - you'll need it for initial setup

### 1.3 Create the Instance

Click "Create" and wait for it to be running (usually 1-2 minutes).

---

## Part 2: Initial Security Setup

### 2.1 Connect via SSH (temporary, for initial setup)

```bash
ssh -i /path/to/your-key.pem ubuntu@<PUBLIC_IP>
```

### 2.2 Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

### 2.3 Install Essential Packages

```bash
sudo apt install -y \
  mosh \
  tmux \
  git \
  curl \
  wget \
  jq \
  build-essential \
  fail2ban \
  ufw
```

### 2.4 Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Follow the authentication link to connect to your Tailnet.

After authentication, get your Tailscale IP:
```bash
tailscale ip -4
```

Note this IP (e.g., `100.x.y.z`) - this is how you'll connect from now on.

### 2.5 Configure Firewall (UFW)

```bash
# Reset to defaults
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow Tailscale interface
sudo ufw allow in on tailscale0

# Allow mosh on Tailscale only (UDP 60000-61000)
sudo ufw allow in on tailscale0 to any port 60000:61000 proto udp

# Enable firewall
sudo ufw enable
```

### 2.6 Lock Down Oracle Cloud Security List

In Oracle Cloud Console:
1. Go to Networking → Virtual Cloud Networks → Your VCN
2. Click on your subnet's Security List
3. Edit Ingress Rules:
   - **Remove** the SSH (port 22) rule if present
   - **Keep only** the rule for ICMP (or remove all ingress if you want maximum lockdown)

> The instance will now only be accessible via Tailscale. No public SSH.

### 2.7 Configure fail2ban

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 2.8 Test Tailscale Connection

**From your local machine (with Tailscale installed):**
```bash
ssh ubuntu@<TAILSCALE_IP>
```

If this works, your public SSH is no longer needed.

---

## Part 3: Install Claude Code

### 3.1 Install Node.js (required for Claude Code)

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3.2 Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

### 3.3 Authenticate Claude Code

```bash
claude
```

Follow the prompts to authenticate with your Anthropic account.

---

## Part 4: Session Persistence with tmux

### 4.1 Configure tmux

Create `~/.tmux.conf`:

```bash
cat > ~/.tmux.conf << 'EOF'
# Use Ctrl-a as prefix (easier on phone)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support (useful for Termius)
set -g mouse on

# Increase history
set -g history-limit 50000

# Better colors
set -g default-terminal "screen-256color"

# Status bar
set -g status-bg colour235
set -g status-fg white
set -g status-left '[#S] '
set -g status-right '%H:%M'

# Easy window navigation
bind -n M-Left previous-window
bind -n M-Right next-window

# Quick reload
bind r source-file ~/.tmux.conf \; display "Reloaded!"
EOF
```

### 4.2 Auto-attach to tmux on Login

Add to your `~/.bashrc` (or `~/.zshrc` if you switch shells):

```bash
cat >> ~/.bashrc << 'EOF'

# Auto-attach to tmux
if [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" || -n "$MOSH" ]]; then
    tmux attach -t main 2>/dev/null || tmux new -s main
fi
EOF
```

---

## Part 5: Set Up Git SSH Keys

Since mosh doesn't forward SSH agent, you'll need keys on the VM for git operations.

### 5.1 Generate SSH Key on VM

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### 5.2 Add to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy this and add it to GitHub: Settings → SSH and GPG keys → New SSH key

### 5.3 Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

### 5.4 Test Connection

```bash
ssh -T git@github.com
```

---

## Part 6: Set Up Ntfy Push Notifications

### 6.1 Install ntfy App on Phone

- iOS: [App Store](https://apps.apple.com/app/ntfy/id1625396347)
- Android: [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy) or F-Droid

### 6.2 Subscribe to Your Topic

In the ntfy app:
1. Tap "+" to add a subscription
2. Use the public server: `ntfy.sh`
3. Create a unique topic name (e.g., `claude-yourname-abc123`)

> ⚠️ **Security Note:** Anyone who knows your topic name can send you notifications. Use something random/unguessable. For production use, consider self-hosting ntfy.

### 6.3 Create the Notification Hook Script

```bash
mkdir -p ~/.claude/hooks

cat > ~/.claude/hooks/ntfy-notify.sh << 'EOF'
#!/bin/bash

# Configuration
NTFY_TOPIC="claude-yourname-abc123"  # ← CHANGE THIS to your topic
NTFY_SERVER="https://ntfy.sh"

# Get the hook type from argument
HOOK_TYPE="${1:-unknown}"

# Read event data from stdin
EVENT_DATA=$(cat)

# Extract project name from environment or use default
PROJECT_NAME="${CLAUDE_PROJECT_NAME:-Claude}"

# Build notification based on hook type
case "$HOOK_TYPE" in
    question)
        # Extract the question from AskUserQuestion tool
        QUESTION=$(echo "$EVENT_DATA" | jq -r '.tool_input.questions[0].question // .tool_input.question // "needs your input"' 2>/dev/null)
        TITLE="🤖 $PROJECT_NAME"
        MESSAGE="$QUESTION"
        PRIORITY="high"
        TAGS="question"
        ;;
    tool)
        TOOL_NAME=$(echo "$EVENT_DATA" | jq -r '.tool_name // "unknown"' 2>/dev/null)
        TITLE="🔧 $PROJECT_NAME"
        MESSAGE="Using tool: $TOOL_NAME"
        PRIORITY="default"
        TAGS="tools"
        ;;
    *)
        TITLE="📢 $PROJECT_NAME"
        MESSAGE="Claude needs attention"
        PRIORITY="default"
        TAGS="notification"
        ;;
esac

# Send to ntfy
curl -s \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: $TAGS" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" > /dev/null 2>&1 &

# Exit successfully (don't block Claude)
exit 0
EOF

chmod +x ~/.claude/hooks/ntfy-notify.sh
```

### 6.4 Configure Claude Code Hook

Create or edit `~/.claude/settings.json`:

```bash
mkdir -p ~/.claude

cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ntfy-notify.sh question"
          }
        ]
      }
    ]
  }
}
EOF
```

### 6.5 Test the Notification

```bash
echo '{"tool_input":{"questions":[{"question":"Test notification - is this working?"}]}}' | ~/.claude/hooks/ntfy-notify.sh question
```

You should receive a push notification on your phone!

---

## Part 7: Configure Termius

### 7.1 Install Tailscale on Your Phone

Install the Tailscale app and sign in to the same Tailnet as your VM.

### 7.2 Add Host in Termius

1. Open Termius
2. Add new Host:
   - **Label:** Claude Dev
   - **Hostname:** Your Tailscale IP (e.g., `100.x.y.z`)
   - **Port:** 22
   - **Username:** ubuntu
   - **Key:** Import or paste your SSH private key

### 7.3 Configure Mosh

1. In the host settings, enable **Mosh**
2. Mosh ports: `60000-61000`

### 7.4 Connect!

Tap the host to connect. You should land directly in tmux.

---

## Part 8: Daily Usage

### Starting Work

1. Open Tailscale on your phone (ensures VPN is active)
2. Open Termius → Connect to "Claude Dev"
3. You're in tmux, ready to go

### Running Claude Code

```bash
# Navigate to your project
cd ~/projects/myproject

# Start Claude
claude

# Or start with a specific task
claude "Add dark mode support to the settings page"
```

### Managing Multiple Projects

Create new tmux windows:
- `Ctrl-a c` → New window
- `Ctrl-a n` → Next window
- `Ctrl-a p` → Previous window
- `Ctrl-a 1-9` → Jump to window by number

### Handling Notifications

When Claude asks a question:
1. Your phone buzzes with ntfy notification
2. The notification shows Claude's question
3. Open Termius, type your response, continue

### Disconnecting

Just close Termius. Your session persists in tmux. Reconnect anytime and pick up where you left off.

---

## Optional Enhancements

### Add Project Name to Notifications

Create a wrapper script `~/bin/claude-project`:

```bash
mkdir -p ~/bin

cat > ~/bin/claude-project << 'EOF'
#!/bin/bash
# Sets project name for notifications based on current directory
export CLAUDE_PROJECT_NAME=$(basename "$PWD")
exec claude "$@"
EOF

chmod +x ~/bin/claude-project
```

Add to PATH in `~/.bashrc`:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
```

Now use `claude-project` instead of `claude` to get project-specific notifications.

### Enhanced Notification for Task Completion

Add a "Stop" hook to notify when Claude finishes:

```bash
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/ntfy-notify.sh question"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"reason\":\"completed\"}' | ~/.claude/hooks/ntfy-notify.sh complete"
          }
        ]
      }
    ]
  }
}
EOF
```

Add to your notify script (before the `esac`):

```bash
    complete)
        TITLE="✅ $PROJECT_NAME"
        MESSAGE="Task completed!"
        PRIORITY="high"
        TAGS="white_check_mark"
        ;;
```

### Git Worktrees for Parallel Development

```bash
# Clone main repo
git clone git@github.com:you/myproject.git ~/projects/myproject
cd ~/projects/myproject

# Create worktrees for features
git worktree add ../myproject-feature-a feature-a
git worktree add ../myproject-feature-b feature-b
```

Now run separate Claude agents in separate tmux windows, each in their own worktree.

---

## Troubleshooting

### Can't connect via Tailscale
- Ensure Tailscale is running on both devices: `sudo tailscale status`
- Check if the VM is showing as online in Tailscale admin console

### Mosh connection drops
- Verify mosh is installed: `which mosh`
- Check UFW allows mosh ports: `sudo ufw status`
- Try regular SSH first to isolate the issue

### Notifications not arriving
- Test ntfy directly: `curl -d "test" ntfy.sh/your-topic`
- Check the topic name matches in app and script
- Verify the script is executable: `ls -la ~/.claude/hooks/`

### "Out of capacity" when creating instance
- Try different availability domain
- Reduce resources temporarily (2 OCPU / 12GB)
- Try during off-peak hours
- Use capacity notification scripts

### tmux not auto-attaching
- Verify .bashrc changes: `tail ~/.bashrc`
- Source it manually: `source ~/.bashrc`
- Check for shell errors: `bash -x`

---

## Quick Reference

| Action | Command |
|--------|---------|
| New tmux window | `Ctrl-a c` |
| Next window | `Ctrl-a n` |
| Previous window | `Ctrl-a p` |
| List windows | `Ctrl-a w` |
| Detach (leave running) | `Ctrl-a d` |
| Kill window | `Ctrl-a &` |
| Scroll mode | `Ctrl-a [` (q to exit) |

| Service | Command |
|---------|---------|
| Tailscale status | `tailscale status` |
| Restart Tailscale | `sudo systemctl restart tailscaled` |
| Check firewall | `sudo ufw status` |
| View fail2ban | `sudo fail2ban-client status` |

---

## Summary

You now have:
- ✅ Always-on ARM VM (4 OCPU, 24GB RAM) - completely free
- ✅ Tailscale-only access (no public SSH exposure)
- ✅ Mosh for resilient mobile connections
- ✅ tmux for persistent sessions
- ✅ Push notifications via ntfy when Claude needs input
- ✅ Git configured with SSH keys on the VM

The workflow: Start a task, pocket your phone, get notified when Claude has questions, respond, repeat. Development fits into the gaps of your day.
