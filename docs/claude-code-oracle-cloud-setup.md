# Claude Code On-The-Go: Oracle Cloud Pay-as-you-Go + Ntfy Edition

Run Claude Code from your phone with push notifications when Claude needs input.

```
Phone (Termius) → mosh → Tailscale → Oracle ARM VM → Claude Code
                                           ↓
                              PreToolUse hook → ntfy.sh → push notification
```

## Prerequisites

- Oracle Cloud account (Pay-as-you-Go — see Part 1 for setup)
- Tailscale account (free tier works fine)
- Termius on your phone
- ntfy app on your phone

---

## Part 1: Oracle Cloud Account & Billing Setup

The Always Free tier ARM instances are notoriously hard to provision on a plain free-tier account due to capacity limits. A **Pay-as-you-Go (PAYG)** account gets priority access to the same Always Free resources — you won't be charged as long as you stay within the free limits.

### Always Free Limits (what costs $0 on PAYG)

| Resource | Free Allowance |
|----------|---------------|
| ARM VM.Standard.A1.Flex | **4 OCPUs + 24 GB RAM** total (across up to 4 instances) |
| AMD VM.Standard.E2.1.Micro | 2 instances (1/8 OCPU + 1 GB each) |
| Boot volumes | Up to **200 GB** total block storage (up to 4 volumes) |
| Outbound data transfer | **10 TB/month** |
| VCN, subnets, gateways | Included |
| Flexible load balancer | 1 instance |
| Object storage | 20 GB |
| Autonomous Database | 2 instances (1 OCPU + 20 GB each) |

> These limits apply **indefinitely** in your home region — they don't expire after 30 days.

### 1.1 Create an Oracle Cloud Account

1. Go to [oracle.com/cloud/free](https://www.oracle.com/cloud/free/) and click **Start for free**
2. Fill in your details and choose a **home region** (this is where your Always Free resources live — pick one close to you)
3. Add a credit card for verification (you won't be charged during the 30-day trial)

### 1.2 Upgrade to Pay-as-you-Go

Upgrading unlocks better capacity availability for ARM instances. You keep all Always Free resources and are only charged for usage **beyond** the free limits.

1. Log in to the [OCI Console](https://cloud.oracle.com/)
2. Look for the **Upgrade** banner at the top of the console home page and click it
   - If you don't see the banner, click the **hamburger menu** (top-left) → **Billing & Cost Management** → **Upgrade and Manage Payment**
3. Select **Pay As You Go** (no commitment, no minimums)
4. Enter a valid credit/debit card and confirm
5. Your account status updates to paid (usually immediate)

> Once upgraded, you **cannot** revert to free-tier-only. But all Always Free resources remain free forever — the card is only charged if you create resources beyond the free limits.

### 1.3 Set Up Budget Alerts

OCI does not support hard spending caps that automatically stop charges. Budgets provide **email notifications** so you can catch unexpected costs early and delete the offending resources.

1. Open the **hamburger menu** → **Billing & Cost Management** → **Cost Management** → **Budgets**
2. Click **Create Budget**:
   - **Target type:** Compartment (select your root compartment to cover everything)
   - **Name:** `free-tier-guard` (or whatever you prefer)
   - **Monthly budget amount:** `$1.00` (any spend means you've exceeded free limits)
   - **Start day:** 1
3. Click **Create**
4. On the budget details page, go to the **Budget Alert Rules** tab → **Create Budget Alert Rule**:

| Field | Value |
|-------|-------|
| Threshold metric | **Actual Spend** |
| Threshold type | **Absolute amount** |
| Threshold | `$0.01` |
| Email recipients | your email address |

5. Click **Create** to save the alert rule
6. **(Recommended)** Add a second alert rule with **Forecast Spend** at `$1.00` to catch runaway usage before it hits

You'll receive an email the moment any charge appears on your account. The correct response is to log in and delete whatever resource is causing the charge.

> **Tip:** Add multiple alert rules at different thresholds (e.g., $0.01 actual, $1 forecast, $5 actual) for layered protection.

### 1.4 Verify Your Free Tier Status

After upgrading, confirm you have Always Free capacity:

1. **Hamburger menu** → **Governance & Administration** → **Tenancy Details**
2. Check that your home region matches what you chose at sign-up
3. **Hamburger menu** → **Compute** → **Instances** → **Create Instance** → **Change shape**
4. Select **Ampere** → **VM.Standard.A1.Flex** — it should show "Always Free eligible"

---

## Part 2: Create the Oracle Cloud Instance

> **Prefer Terraform?** See [oracle-cloud-terraform.md](oracle-cloud-terraform.md) (or grab the repo directly: [oci-alwaysfree-tf-stack](https://github.com/kevinmcmahon/oci-alwaysfree-tf-stack)) for IaC equivalents of Parts 2-3, then skip to Part 3.5 (Tailscale).

### 2.1 Navigate to Compute

1. Go to Oracle Cloud Console → Compute → Instances → Create Instance

### 2.2 Configure the Instance

**Name:** `claude-dev` (or whatever you prefer)

**Placement:** Leave default (your home region — Always Free resources only work here)

**Image and Shape:**
- Click "Edit" in the Image and shape section
- Click "Change image" → Select **Ubuntu 24.04** (Canonical Ubuntu)
- Click "Change shape":
  - Instance type: **Virtual machine**
  - Shape series: **Ampere** (ARM-based processor)
  - Shape name: **VM.Standard.A1.Flex**
  - OCPUs: **4** (uses your full Always Free allowance)
  - Memory: **24 GB** (uses your full Always Free allowance)

> ⚠️ **Capacity Issues:** If you get "Out of capacity" errors, try:
> - Different availability domain (if your region has multiple)
> - Try during off-peak hours (early morning UTC)
> - Reduce to 2 OCPUs / 12GB initially, resize later
> - Use the [OCI Instance Notifier](https://github.com/hitrov/oci-arm-host-capacity) script
> - PAYG accounts have significantly better success rates than free-tier-only accounts

**Boot Volume:**
- Leave default (typically 46.6 GB) — this stays within the 200 GB free block storage limit
- Do **not** create additional block volumes unless you're tracking your total against the 200 GB cap

**Networking:**
- Select your VCN or create a new one
- Select a public subnet (we'll lock it down with security lists)
- **Assign a public IPv4 address:** Yes (needed for initial setup and Tailscale coordination)

**SSH Keys:**
- Generate or upload your SSH key pair
- **Save the private key** - you'll need it for initial setup

### 2.3 Create the Instance

Click "Create" and wait for it to be running (usually 1-2 minutes).

---

## Part 3: Initial Security Setup

### 3.1 Connect via SSH (temporary, for initial setup)

```bash
ssh -i /path/to/your-key.pem ubuntu@<PUBLIC_IP>
```

### 3.2 Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

### 3.3 Install Essential Packages

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

### 3.4 Install Tailscale

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

### 3.5 Configure Firewall (UFW)

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

### 3.6 Lock Down Oracle Cloud Security List

In Oracle Cloud Console:
1. Go to Networking → Virtual Cloud Networks → Your VCN
2. Click on your subnet's Security List
3. Edit Ingress Rules:
   - **Remove** the SSH (port 22) rule if present
   - **Keep only** the rule for ICMP (or remove all ingress if you want maximum lockdown)

> The instance will now only be accessible via Tailscale. No public SSH.

### 3.7 Configure fail2ban

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3.8 Test Tailscale Connection

**From your local machine (with Tailscale installed):**
```bash
ssh ubuntu@<TAILSCALE_IP>
```

If this works, your public SSH is no longer needed.

---

## Part 4: Install Claude Code

### 4.1 Install Node.js (required for Claude Code)

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

### 4.2 Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

### 4.3 Authenticate Claude Code

```bash
claude
```

Follow the prompts to authenticate with your Anthropic account.

---

## Part 5: Session Persistence with tmux

### 5.1 Configure tmux

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

### 5.2 Auto-attach to tmux on Login

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

## Part 6: Set Up Git SSH Keys

Since mosh doesn't forward SSH agent, you'll need keys on the VM for git operations.

### 6.1 Generate SSH Key on VM

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### 6.2 Add to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy this and add it to GitHub: Settings → SSH and GPG keys → New SSH key

### 6.3 Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

### 6.4 Test Connection

```bash
ssh -T git@github.com
```

---

## Part 7: Set Up Ntfy Push Notifications

The dotfiles repo includes a pre-configured ntfy hook script and Claude Code settings. If you ran the bootstrap, both `~/.claude/hooks/ntfy-notify.sh` and `~/.claude/settings.json` are already symlinked from the repo. All you need to do is set the env var and install the phone app.

### 7.1 Install ntfy App on Phone

- iOS: [App Store](https://apps.apple.com/app/ntfy/id1625396347)
- Android: [Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy) or F-Droid

### 7.2 Subscribe to Your Topic

In the ntfy app:
1. Tap "+" to add a subscription
2. Use the public server: `ntfy.sh`
3. Create a unique topic name (e.g., `claude-yourname-abc123`)

> ⚠️ **Security Note:** Anyone who knows your topic name can send you notifications. Use something random/unguessable. For production use, consider self-hosting ntfy.

### 7.3 Set the Environment Variable

Add to `~/.zsh/env/optional/private.zsh` (this file is gitignored, so your topic stays private):

```bash
export NTFY_TOPIC="claude-yourname-abc123"  # ← your unique topic

# Optional overrides:
# export NTFY_SERVER="https://ntfy.yourdomain.com"  # default: https://ntfy.sh
# export NTFY_PRIORITY="urgent"                     # default: high
```

Then reload your shell:
```bash
source ~/.zshrc
```

### 7.4 Verify the Symlinks

If you ran the bootstrap, these should already be in place:

```bash
ls -la ~/.claude/hooks/ntfy-notify.sh  # → dotfiles/claude/hooks/ntfy-notify.sh
ls -la ~/.claude/settings.json         # → dotfiles/claude/settings.json
```

If not, run `symlink_claude_config` from the bootstrap or manually symlink:
```bash
ln -snf ~/dotfiles/claude/hooks ~/.claude/hooks
ln -snf ~/dotfiles/claude/settings.json ~/.claude/settings.json
```

### 7.5 Test the Notification

```bash
NTFY_TOPIC=your-topic CLAUDE_HOOK_EVENT_DATA='{"tool_input":{"question":"Test notification"}}' ~/.claude/hooks/ntfy-notify.sh question
```

You should receive a push notification on your phone!

To verify the script exits silently when unconfigured (e.g., on a machine without ntfy):
```bash
unset NTFY_TOPIC && ~/.claude/hooks/ntfy-notify.sh question && echo "Exited cleanly"
```

---

## Part 8: Configure Termius

### 8.1 Install Tailscale on Your Phone

Install the Tailscale app and sign in to the same Tailnet as your VM.

### 8.2 Add Host in Termius

1. Open Termius
2. Add new Host:
   - **Label:** Claude Dev
   - **Hostname:** Your Tailscale IP (e.g., `100.x.y.z`)
   - **Port:** 22
   - **Username:** ubuntu
   - **Key:** Import or paste your SSH private key

### 8.3 Configure Mosh

1. In the host settings, enable **Mosh**
2. Mosh ports: `60000-61000`

### 8.4 Connect!

Tap the host to connect. You should land directly in tmux.

---

## Part 9: Daily Usage

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

### Task Completion Notifications

The repo-managed `settings.json` already includes both a "PreToolUse" hook (for questions) and a "Stop" hook (for task completion). No manual configuration needed — just set `NTFY_TOPIC` and both notification types work automatically.

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
- Check the topic name matches in the app and your `NTFY_TOPIC` env var: `echo $NTFY_TOPIC`
- Verify the script is executable and symlinked: `ls -la ~/.claude/hooks/ntfy-notify.sh`
- Check the symlink is correct: `readlink ~/.claude/settings.json`

### Unexpected charges on PAYG account
- Check **Billing & Cost Management** → **Cost Analysis** to see what's incurring charges
- Common culprits: extra block volumes, instances outside home region, exceeding 4 OCPU / 24 GB total
- Delete the offending resource immediately — PAYG charges stop when the resource is terminated
- Verify your budget alert is configured (Part 1.3) so you catch charges early

### "Out of capacity" when creating instance
- PAYG accounts have better success than free-tier-only — upgrade first (Part 1.2)
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
- ✅ Pay-as-you-Go account with budget alerts (safety net against surprise charges)
- ✅ Always-on ARM VM (4 OCPU, 24GB RAM) - within Always Free limits ($0)
- ✅ Tailscale-only access (no public SSH exposure)
- ✅ Mosh for resilient mobile connections
- ✅ tmux for persistent sessions
- ✅ Push notifications via ntfy when Claude needs input
- ✅ Git configured with SSH keys on the VM

The workflow: Start a task, pocket your phone, get notified when Claude has questions, respond, repeat. Development fits into the gaps of your day.
