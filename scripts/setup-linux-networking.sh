#!/usr/bin/env bash
# setup-networking.sh - Configure Tailscale, mosh, UFW firewall, and fail2ban
#
# Usage:
#   ./scripts/setup-networking.sh [OPTIONS]
#
# Options:
#   --tailscale-only    Restrict SSH/mosh to Tailscale interface only (default)
#   --public            Allow SSH/mosh from any interface
#   --skip-firewall     Skip UFW configuration
#   --skip-tailscale    Skip Tailscale installation
#   --skip-mosh         Skip mosh installation
#   --skip-fail2ban     Skip fail2ban installation
#   --dry-run           Show what would be done
#   -h, --help          Show this help message

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

MOSH_PORT_START=60000
MOSH_PORT_END=61000

# ─────────────────────────────────────────────────────────────────────────────
# State variables (set by parse_args)
# ─────────────────────────────────────────────────────────────────────────────

MODE="tailscale-only"  # or "public"
SKIP_FIREWALL=false
SKIP_TAILSCALE=false
SKIP_MOSH=false
SKIP_FAIL2BAN=false
DRY_RUN=false

# ─────────────────────────────────────────────────────────────────────────────
# Logging utilities
# ─────────────────────────────────────────────────────────────────────────────

log() {
    printf '\033[1;32m[+]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}

info() {
    printf '\033[1;34m[*]\033[0m %s\n' "$*"
}

dry_run_msg() {
    printf '\033[1;36m[DRY-RUN]\033[0m %s\n' "$*"
}

# ─────────────────────────────────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────────────────────────────────

need_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "Required command not found: $1"
    fi
}

cmd_exists() {
    command -v "$1" &>/dev/null
}

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "$*"
    else
        "$@"
    fi
}

run_sudo() {
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "sudo $*"
    else
        sudo "$@"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    cat << 'EOF'
setup-networking.sh - Configure Tailscale, mosh, UFW firewall, and fail2ban

Usage:
  ./scripts/setup-networking.sh [OPTIONS]

Options:
  --tailscale-only    Restrict SSH/mosh to Tailscale interface only (default)
  --public            Allow SSH/mosh from any interface
  --skip-firewall     Skip UFW configuration
  --skip-tailscale    Skip Tailscale installation
  --skip-mosh         Skip mosh installation
  --skip-fail2ban     Skip fail2ban installation
  --dry-run           Show what would be done
  -h, --help          Show this help message

Examples:
  # Recommended: Tailscale-only (most secure)
  ./scripts/setup-networking.sh

  # Allow public access
  ./scripts/setup-networking.sh --public

  # Preview changes
  ./scripts/setup-networking.sh --dry-run

  # Just Tailscale, no firewall changes
  ./scripts/setup-networking.sh --skip-firewall --skip-mosh
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tailscale-only)
                MODE="tailscale-only"
                shift
                ;;
            --public)
                MODE="public"
                shift
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --skip-tailscale)
                SKIP_TAILSCALE=true
                shift
                ;;
            --skip-mosh)
                SKIP_MOSH=true
                shift
                ;;
            --skip-fail2ban)
                SKIP_FAIL2BAN=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Preflight checks
# ─────────────────────────────────────────────────────────────────────────────

preflight_checks() {
    # Never run as root directly
    if [[ $EUID -eq 0 ]]; then
        die "Do not run this script as root. It uses sudo internally where needed."
    fi

    # Ensure we're on a Debian-based system
    if ! cmd_exists apt-get; then
        die "This script requires apt-get (Debian/Ubuntu)"
    fi

    # Check for curl (needed for Tailscale installer)
    need_cmd curl

    log "Preflight checks passed"
}

# ─────────────────────────────────────────────────────────────────────────────
# SSH lockout detection
# ─────────────────────────────────────────────────────────────────────────────

check_ssh_lockout_risk() {
    # Only relevant for tailscale-only mode with firewall enabled
    if [[ "$MODE" != "tailscale-only" ]] || [[ "$SKIP_FIREWALL" == "true" ]]; then
        return 0
    fi

    # Get the SSH client IP if we're in an SSH session
    local ssh_client_ip="${SSH_CLIENT%% *}"

    if [[ -z "$ssh_client_ip" ]]; then
        # Not an SSH session, no risk
        return 0
    fi

    # Check if connected via Tailscale IP (100.x.x.x range)
    if [[ "$ssh_client_ip" =~ ^100\. ]]; then
        info "Connected via Tailscale IP ($ssh_client_ip) - safe to proceed"
        return 0
    fi

    # Connected via public IP with tailscale-only mode - warn user
    warn "╔════════════════════════════════════════════════════════════════╗"
    warn "║                    ⚠️  SSH LOCKOUT WARNING ⚠️                   ║"
    warn "╠════════════════════════════════════════════════════════════════╣"
    warn "║ You are connected via public IP: $ssh_client_ip"
    warn "║ With --tailscale-only mode, you may lose SSH access!          ║"
    warn "║                                                                ║"
    warn "║ Options:                                                       ║"
    warn "║   1. Use --public mode instead                                 ║"
    warn "║   2. First connect via Tailscale, then run this script         ║"
    warn "║   3. Use --skip-firewall to skip UFW configuration             ║"
    warn "╚════════════════════════════════════════════════════════════════╝"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run mode: continuing anyway to show planned changes"
        return 0
    fi

    printf '\n'
    read -r -p "Are you sure you want to continue? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        die "Aborted by user"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Tailscale installation
# ─────────────────────────────────────────────────────────────────────────────

install_tailscale() {
    if [[ "$SKIP_TAILSCALE" == "true" ]]; then
        info "Skipping Tailscale installation (--skip-tailscale)"
        return 0
    fi

    log "Installing Tailscale..."

    if cmd_exists tailscale; then
        info "Tailscale is already installed"

        # Check if connected
        if tailscale status &>/dev/null; then
            info "Tailscale is already connected"
            tailscale status
            return 0
        fi
    else
        info "Downloading and installing Tailscale..."
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "curl -fsSL https://tailscale.com/install.sh | sh"
        else
            curl -fsSL https://tailscale.com/install.sh | sh
        fi
    fi

    # Prompt to authenticate
    printf '\n'
    read -r -p "Run 'sudo tailscale up' now to authenticate? (y/n): " response
    if [[ "$response" =~ ^[Yy] ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            dry_run_msg "sudo tailscale up"
        else
            info "Starting Tailscale authentication (browser will open)..."
            sudo tailscale up
            log "Tailscale connected successfully"
            tailscale status
        fi
    else
        warn "Skipping Tailscale authentication - run 'sudo tailscale up' manually"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# mosh installation
# ─────────────────────────────────────────────────────────────────────────────

install_mosh() {
    if [[ "$SKIP_MOSH" == "true" ]]; then
        info "Skipping mosh installation (--skip-mosh)"
        return 0
    fi

    log "Installing mosh..."

    if cmd_exists mosh-server; then
        info "mosh is already installed"
        return 0
    fi

    run_sudo apt-get update
    run_sudo apt-get install -y mosh

    if [[ "$DRY_RUN" != "true" ]]; then
        log "mosh installed successfully"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# fail2ban installation
# ─────────────────────────────────────────────────────────────────────────────

install_fail2ban() {
    if [[ "$SKIP_FAIL2BAN" == "true" ]]; then
        info "Skipping fail2ban installation (--skip-fail2ban)"
        return 0
    fi

    log "Installing fail2ban..."

    if cmd_exists fail2ban-server; then
        info "fail2ban is already installed"

        # Ensure it's enabled and running
        if [[ "$DRY_RUN" != "true" ]]; then
            sudo systemctl enable fail2ban 2>/dev/null || true
            sudo systemctl start fail2ban 2>/dev/null || true
        fi
        return 0
    fi

    run_sudo apt-get update
    run_sudo apt-get install -y fail2ban
    run_sudo systemctl enable fail2ban
    run_sudo systemctl start fail2ban

    if [[ "$DRY_RUN" != "true" ]]; then
        log "fail2ban installed and started"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# UFW firewall configuration
# ─────────────────────────────────────────────────────────────────────────────

configure_ufw() {
    if [[ "$SKIP_FIREWALL" == "true" ]]; then
        info "Skipping UFW configuration (--skip-firewall)"
        return 0
    fi

    log "Configuring UFW firewall (mode: $MODE)..."

    # Install UFW if missing
    if ! cmd_exists ufw; then
        info "Installing UFW..."
        run_sudo apt-get update
        run_sudo apt-get install -y ufw
    fi

    # Set default policies
    info "Setting default policies..."
    run_sudo ufw default deny incoming
    run_sudo ufw default allow outgoing

    # Apply rules based on mode
    if [[ "$MODE" == "public" ]]; then
        configure_ufw_public
    else
        configure_ufw_tailscale_only
    fi

    # Enable UFW (rules are already set, so this is safe)
    info "Enabling UFW..."
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run_msg "ufw --force enable"
    else
        sudo ufw --force enable
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        log "UFW configured and enabled"
    fi
}

configure_ufw_public() {
    info "Configuring public mode rules..."

    # SSH from anywhere
    info "Allowing SSH (port 22) from anywhere..."
    run_sudo ufw allow 22/tcp comment 'SSH'

    # mosh from anywhere
    info "Allowing mosh (ports $MOSH_PORT_START:$MOSH_PORT_END/udp) from anywhere..."
    run_sudo ufw allow "$MOSH_PORT_START:$MOSH_PORT_END/udp" comment 'mosh'

    # Allow all Tailscale traffic (if interface exists)
    if ip link show tailscale0 &>/dev/null || [[ "$DRY_RUN" == "true" ]]; then
        info "Allowing all traffic on Tailscale interface..."
        run_sudo ufw allow in on tailscale0 comment 'Tailscale'
    else
        warn "Tailscale interface (tailscale0) not found - skipping Tailscale UFW rule"
    fi
}

configure_ufw_tailscale_only() {
    info "Configuring tailscale-only mode rules..."

    # Check if Tailscale interface exists
    if ! ip link show tailscale0 &>/dev/null && [[ "$DRY_RUN" != "true" ]]; then
        warn "Tailscale interface (tailscale0) not found!"
        warn "Make sure Tailscale is installed and connected before enabling firewall"
        die "Cannot configure tailscale-only mode without Tailscale interface"
    fi

    # Allow all traffic on Tailscale interface
    info "Allowing all traffic on Tailscale interface..."
    run_sudo ufw allow in on tailscale0 comment 'Tailscale'

    # mosh on Tailscale interface (explicit rule for clarity)
    info "Allowing mosh (ports $MOSH_PORT_START:$MOSH_PORT_END/udp) on Tailscale interface..."
    run_sudo ufw allow in on tailscale0 to any port "$MOSH_PORT_START:$MOSH_PORT_END" proto udp comment 'mosh via Tailscale'
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

show_summary() {
    printf '\n'
    log "════════════════════════════════════════════════════════════════"
    log "                    Setup Complete!"
    log "════════════════════════════════════════════════════════════════"
    printf '\n'

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "This was a dry run - no changes were made"
        printf '\n'
        return 0
    fi

    info "Configuration summary:"
    printf '  Mode:        %s\n' "$MODE"
    printf '  Tailscale:   %s\n' "$( [[ "$SKIP_TAILSCALE" == "true" ]] && echo "skipped" || echo "installed" )"
    printf '  mosh:        %s\n' "$( [[ "$SKIP_MOSH" == "true" ]] && echo "skipped" || echo "installed" )"
    printf '  fail2ban:    %s\n' "$( [[ "$SKIP_FAIL2BAN" == "true" ]] && echo "skipped" || echo "installed" )"
    printf '  UFW:         %s\n' "$( [[ "$SKIP_FIREWALL" == "true" ]] && echo "skipped" || echo "configured" )"
    printf '\n'

    info "Verification commands:"
    [[ "$SKIP_TAILSCALE" != "true" ]] && printf '  tailscale status              # Check Tailscale connection\n'
    [[ "$SKIP_FIREWALL" != "true" ]]  && printf '  sudo ufw status verbose       # Check firewall rules\n'
    [[ "$SKIP_FAIL2BAN" != "true" ]]  && printf '  sudo fail2ban-client status   # Check fail2ban status\n'
    printf '\n'

    if [[ "$MODE" == "tailscale-only" ]]; then
        info "Testing (use Tailscale IP):"
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null || echo "<tailscale-ip>")
        printf '  ssh %s@%s\n' "$USER" "$ts_ip"
        [[ "$SKIP_MOSH" != "true" ]] && printf '  mosh %s@%s\n' "$USER" "$ts_ip"
        printf '\n'

        info "Oracle Cloud note:"
        printf '  For maximum security, remove SSH ingress rule from Oracle Cloud\n'
        printf '  Security List after verifying Tailscale access works.\n'
    fi

    printf '\n'
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    log "Starting networking setup (mode: $MODE)"
    [[ "$DRY_RUN" == "true" ]] && warn "Dry-run mode enabled - no changes will be made"
    printf '\n'

    preflight_checks
    check_ssh_lockout_risk

    # Install components in order
    install_tailscale
    install_mosh
    install_fail2ban
    configure_ufw

    show_summary
}

main "$@"
