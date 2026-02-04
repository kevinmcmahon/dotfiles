# Linux Networking Setup Guide

Secure your Linux server with Tailscale VPN, mosh, UFW firewall, and fail2ban using the automated setup script.

## Overview

The `setup-linux-networking.sh` script configures:

- **Tailscale**: Zero-config VPN for secure remote access
- **mosh**: Mobile shell that handles intermittent connections
- **UFW (Uncomplicated Firewall)**: Host-based firewall
- **fail2ban**: Intrusion prevention (blocks brute-force attacks)

## Quick Start

### Prerequisites

- Fresh Linux server (Ubuntu/Debian)
- Root/sudo access
- SSH access to the server
- **Important**: You should have another way to access the server (console access) in case of lockout

### Safety First: Two-Step Approach (Recommended)

This approach prevents SSH lockout by installing Tailscale first, verifying it works, then locking down the firewall.

#### Step 1: Install Tailscale and mosh (no firewall changes)

```bash
cd ~/dotfiles/scripts
./setup-linux-networking.sh --skip-firewall
```

**What this does:**
- ✅ Installs Tailscale VPN
- ✅ Prompts you to authenticate with Tailscale
- ✅ Installs mosh for stable SSH connections
- ✅ Installs fail2ban for brute-force protection
- ❌ Does NOT change firewall rules (public SSH still works)

**When prompted**, authenticate with Tailscale:
```bash
sudo tailscale up
# Browser will open for authentication
```

#### Step 2: Get your Tailscale IP

```bash
tailscale status
# or
tailscale ip -4
```

Example output:
```
100.101.102.103
```

#### Step 3: Test Tailscale connection

**IMPORTANT**: Keep your current SSH session open as backup!

Open a **new** terminal and connect via Tailscale:
```bash
ssh your-username@100.101.102.103
```

Test mosh too:
```bash
mosh your-username@100.101.102.103
```

If both work, you're ready for Step 4. If not, troubleshoot before continuing.

#### Step 4: Lock down the firewall

From your **Tailscale SSH session**, run:
```bash
cd ~/dotfiles/scripts
./setup-linux-networking.sh --tailscale-only
```

**What this does:**
- ✅ Configures UFW to allow traffic only on Tailscale interface
- ✅ Blocks SSH/mosh from public internet
- ✅ Your Tailscale connection remains working

The script detects you're on a Tailscale IP and safely applies the restrictive rules.

**After this step:** Public IP SSH access is blocked. You can only connect via Tailscale.

#### Step 5: Verify (optional but recommended)

```bash
# Check firewall rules
sudo ufw status verbose

# Check Tailscale status
tailscale status

# Check fail2ban
sudo fail2ban-client status
```

## Alternative Approaches

### Approach A: Public Mode (less secure)

Allows SSH/mosh from any IP address. Use for testing or if you can't use Tailscale.

```bash
./setup-linux-networking.sh --public
```

**Security note**: Your SSH port is exposed to the internet. Ensure you have:
- Strong passwords or key-based auth only
- fail2ban running (included in script)
- Consider changing SSH port from default 22

You can switch to `--tailscale-only` later after testing Tailscale.

### Approach B: All-at-once (risky, not recommended)

```bash
./setup-linux-networking.sh --tailscale-only
```

**⚠️  WARNING**: If you're connected via public IP, this will:
1. Show you a lockout warning
2. Require you to type "yes" to confirm
3. Immediately restrict SSH to Tailscale only

Only use this if you're already connected via Tailscale or have console access as backup.

## Script Options

```bash
./setup-linux-networking.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--tailscale-only` | Restrict SSH/mosh to Tailscale interface only (default, most secure) |
| `--public` | Allow SSH/mosh from any interface (less secure) |
| `--skip-firewall` | Skip UFW configuration (useful for Step 1) |
| `--skip-tailscale` | Skip Tailscale installation |
| `--skip-mosh` | Skip mosh installation |
| `--skip-fail2ban` | Skip fail2ban installation |
| `--dry-run` | Show what would be done without making changes |
| `-h, --help` | Show help message |

## Common Scenarios

### Scenario 1: New server, maximum security

```bash
# Step 1: Install Tailscale
./setup-linux-networking.sh --skip-firewall

# Step 2: Test Tailscale access
ssh user@<tailscale-ip>

# Step 3: Lock down firewall from Tailscale session
./setup-linux-networking.sh --tailscale-only
```

### Scenario 2: Preview changes first

```bash
# See what would happen without making changes
./setup-linux-networking.sh --dry-run

# See tailscale-only mode changes
./setup-linux-networking.sh --tailscale-only --dry-run
```

### Scenario 3: Just Tailscale, no firewall

```bash
# Install only Tailscale and mosh
./setup-linux-networking.sh --skip-firewall --skip-fail2ban
```

### Scenario 4: Switch from public to Tailscale-only

```bash
# Currently in public mode, want to restrict

# First: Ensure Tailscale is working
tailscale status

# Then: Connect via Tailscale and run
./setup-linux-networking.sh --tailscale-only
```

## Oracle Cloud Specific

If running on Oracle Cloud Infrastructure:

### Security Lists

After verifying Tailscale works, you can remove the SSH ingress rule from your Oracle Cloud Security List for maximum security:

1. Go to OCI Console → Networking → Virtual Cloud Networks
2. Select your VCN → Security Lists
3. Find the rule allowing TCP port 22 from 0.0.0.0/0
4. Delete or disable it

**Why**: Even though UFW blocks public SSH, defense in depth is better. Removing the cloud-level rule adds another layer.

**Important**: Only do this AFTER verifying Tailscale SSH access works!

### Instance Metadata

Oracle Cloud instances may have firewall rules at multiple levels:
1. Security Lists (VCN level)
2. Network Security Groups (optional)
3. iptables/UFW (OS level) ← This script configures this

The script configures OS-level firewall only.

## Troubleshooting

### Can't connect via Tailscale

**Check Tailscale status:**
```bash
tailscale status
```

If not connected:
```bash
sudo tailscale up
```

**Check firewall isn't blocking Tailscale:**
```bash
sudo ufw status
# Should show: allow in on tailscale0
```

### Locked out after enabling firewall

**If you have console access:**
1. Login via console
2. Disable UFW: `sudo ufw disable`
3. Fix Tailscale connection
4. Re-enable: `sudo ufw enable`

**If no console access:**
- You'll need to rebuild the instance or contact support
- This is why the two-step approach is recommended!

### mosh not working

**Check mosh ports are open:**
```bash
sudo ufw status | grep mosh
# Should show: 60000:61000/udp
```

**Check mosh is installed:**
```bash
which mosh-server
```

**Try with explicit port range:**
```bash
mosh --server="mosh-server new -p 60001" user@host
```

### fail2ban not starting

**Check status:**
```bash
sudo systemctl status fail2ban
```

**Check logs:**
```bash
sudo journalctl -u fail2ban -n 50
```

**Restart:**
```bash
sudo systemctl restart fail2ban
```

## Verification Commands

After setup, verify everything is working:

```bash
# Tailscale status and IP
tailscale status
tailscale ip -4

# Firewall rules
sudo ufw status verbose

# fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# mosh server is available
which mosh-server

# Test from another machine:
ssh user@<tailscale-ip>
mosh user@<tailscale-ip>
```

## Security Best Practices

### 1. Use Tailscale-only mode when possible

Most secure option. Public SSH port is completely blocked.

### 2. If using public mode

- Use SSH keys only (disable password auth)
- Change default SSH port
- Monitor fail2ban logs
- Consider rate limiting

### 3. Regular updates

```bash
# Update Tailscale
sudo tailscale update

# Update system packages
sudo apt update && sudo apt upgrade -y
```

### 4. Monitor logs

```bash
# SSH attempts
sudo journalctl -u ssh -f

# fail2ban blocks
sudo fail2ban-client status sshd

# UFW blocks
sudo tail -f /var/log/ufw.log
```

## Firewall Rules Reference

### Tailscale-only mode

```
Default: deny (incoming), allow (outgoing)
Allow:   All traffic on tailscale0 interface
Allow:   mosh (60000:61000/udp) on tailscale0
```

Public SSH is **blocked**.

### Public mode

```
Default: deny (incoming), allow (outgoing)
Allow:   SSH (22/tcp) from anywhere
Allow:   mosh (60000:61000/udp) from anywhere
Allow:   All traffic on tailscale0 interface
```

Public SSH is **allowed**.

## Uninstalling / Reverting

### Disable firewall

```bash
sudo ufw disable
```

### Remove Tailscale

```bash
sudo tailscale down
sudo apt remove tailscale -y
```

### Remove mosh

```bash
sudo apt remove mosh -y
```

### Remove fail2ban

```bash
sudo systemctl stop fail2ban
sudo apt remove fail2ban -y
```

## Related Documentation

- [Bootstrap Script](../scripts/bootstrap-linux-dev.sh) - Initial server setup
- [User Recreation](../scripts/recreate-user.sh) - Recreate user accounts safely
- [Tailscale Documentation](https://tailscale.com/kb/) - Official Tailscale docs
- [UFW Documentation](https://help.ubuntu.com/community/UFW) - Ubuntu firewall guide

## FAQ

### Q: Can I use this with other VPNs?

The script is specifically designed for Tailscale. For other VPNs, you'd need to modify the UFW rules to use your VPN's interface name instead of `tailscale0`.

### Q: What if I need to open other ports?

```bash
# Open a specific port
sudo ufw allow 8080/tcp comment 'My App'

# Open port only on Tailscale
sudo ufw allow in on tailscale0 to any port 8080 proto tcp comment 'My App via Tailscale'
```

### Q: Can I run this multiple times?

Yes! The script is idempotent. It will:
- Skip installation if already installed
- Update rules if needed
- Not duplicate existing rules

### Q: How do I switch modes?

Just run the script again with a different mode:

```bash
# Switch from public to tailscale-only
./setup-linux-networking.sh --tailscale-only

# Switch from tailscale-only to public
./setup-linux-networking.sh --public
```

### Q: What about IPv6?

The script uses `tailscale ip -4` for IPv4. Tailscale also supports IPv6. Check with:

```bash
tailscale ip -6
```

UFW rules apply to both IPv4 and IPv6 by default.

### Q: Does this work on non-Ubuntu distros?

The script requires `apt-get` (Debian/Ubuntu). For other distros:
- Fedora/RHEL: Use `dnf` instead of `apt-get`
- Arch: Use `pacman`
- You'll need to adapt the package installation commands

## Support

If you encounter issues:

1. Check logs: `journalctl -xe`
2. Verify Tailscale: `tailscale status`
3. Check firewall: `sudo ufw status verbose`
4. Test connectivity: `nc -v -z <ip> 22`

For Tailscale issues: [Tailscale Support](https://tailscale.com/contact/support/)
