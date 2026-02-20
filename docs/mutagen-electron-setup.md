# Mutagen + SSH/tmux Setup for Remote Electron Dev

A complete setup for developing an Electron app on a Linux VPS while running/testing it natively on macOS.

---

## Architecture

```
┌─────────────────────────┐          ┌──────────────────────────┐
│       Linux VPS          │          │         macOS             │
│                          │  mutagen │                          │
│  ~/project/src/**   ◄────┼──────────┼────►  ~/project/src/**   │
│  ~/project/package.json  │  (sync)  │  ~/project/package.json  │
│                          │          │                          │
│  tmux: edit, git, lint   │          │  node_modules/ (local)   │
│  neovim / your editor    │          │  electron . (runs here)  │
└─────────────────────────┘          └──────────────────────────┘
           ▲                                    ▲
           │ ssh / mosh                         │ you sit here
           └────────────────────────────────────┘
```

**Key idea**: Source code syncs bidirectionally. `node_modules` stays local on each machine. You edit on the VPS, Electron runs on the Mac.

---

## 1. Prerequisites

### On your Mac

```bash
# Install Mutagen
brew install mutagen-io/mutagen/mutagen

# Install Mosh (optional, better than SSH over flaky connections)
brew install mosh

# Make sure Node/npm are installed
node -v && npm -v
```

### On your Linux VPS

```bash
# Mosh server (optional)
sudo apt update && sudo apt install -y mosh

# Node.js (if not installed)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# tmux
sudo apt install -y tmux
```

### SSH key auth (skip if already set up)

```bash
# On Mac — generate key if you don't have one
ssh-keygen -t ed25519 -C "your@email.com"

# Copy to VPS
ssh-copy-id user@your-vps-ip

# Verify passwordless login
ssh user@your-vps-ip
```

---

## 2. Project Setup (One-Time)

### On the VPS

```bash
# Clone or create your project
cd ~
git clone git@github.com:you/your-electron-app.git project
cd project
npm install   # VPS-side node_modules (for linting, tests, etc.)
```

### On the Mac

```bash
# Create the local project directory
mkdir -p ~/project
```

---

## 3. Mutagen Sync Configuration

Create a `mutagen.yml` at the **root of your Mac's project directory** (or manage it globally — both approaches shown below).

### Option A: Project-level config (recommended)

Create `~/project/mutagen.yml` on your Mac:

```yaml
sync:
  electron-dev:
    alpha: "."
    beta: "user@your-vps-ip:~/project"
    mode: "two-way-resolved"

    ignore:
      vcs: true               # ignore .git
      paths:
        - "node_modules/"
        - "dist/"
        - "out/"
        - ".webpack/"
        - ".erb/"
        - "release/"
        - "*.dmg"
        - "*.app"
        - ".DS_Store"
        - "thumbs.db"

    permissions:
      defaultFileMode: 0644
      defaultDirectoryMode: 0755
```

Then start the sync:

```bash
cd ~/project
mutagen project start
```

### Option B: CLI-based (no config file)

```bash
mutagen sync create \
  --name electron-dev \
  --mode two-way-resolved \
  --ignore-vcs \
  --ignore "node_modules/" \
  --ignore "dist/" \
  --ignore "out/" \
  --ignore ".webpack/" \
  --ignore ".DS_Store" \
  --default-file-mode 0644 \
  --default-directory-mode 0755 \
  ~/project \
  user@your-vps-ip:~/project
```

### Verify sync is working

```bash
# Check status
mutagen sync list

# Watch sync activity in real-time
mutagen sync monitor electron-dev
```

---

## 4. tmux Config on VPS

Add to `~/.tmux.conf` on your VPS:

```bash
# Better prefix
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Mouse support (for scrolling, pane selection)
set -g mouse on

# Start windows/panes at 1 not 0
set -g base-index 1
setw -g pane-base-index 1

# Easy splits
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Status bar
set -g status-style 'bg=#333333 fg=#ffffff'
set -g status-left '#[fg=#00ff00][#S] '
set -g status-right '#[fg=#888888]%H:%M '

# Increase history
set -g history-limit 50000

# Faster escape (important for vim/neovim)
set -sg escape-time 10

# 256 colors
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
```

---

## 5. Daily Workflow

### Start your day

```bash
# 1. Start Mutagen sync (Mac terminal)
cd ~/project
mutagen project start       # if using mutagen.yml
# or: mutagen sync resume electron-dev

# 2. SSH/mosh into VPS
mosh user@your-vps-ip       # or: ssh user@your-vps-ip

# 3. Attach or create tmux session
tmux new -s dev              # first time
tmux attach -t dev           # reconnecting
```

### tmux layout suggestion

```
┌──────────────────────────┬──────────────────┐
│                          │                  │
│   Editor (nvim/vim)      │   git / shell    │
│                          │                  │
│                          │                  │
├──────────────────────────┼──────────────────┤
│                          │                  │
│   lint / typecheck       │   logs / tests   │
│   (npm run lint:watch)   │   (npm test)     │
│                          │                  │
└──────────────────────────┴──────────────────┘
```

Set it up:
```bash
# Inside tmux:
# Pane 1: editor
nvim .

# Ctrl-a | (vertical split) → Pane 2: git/shell
# Ctrl-a - (horizontal split on left) → Pane 3: lint watcher
# Select right pane, Ctrl-a - → Pane 4: tests
```

### Run Electron on your Mac

In a **separate Mac terminal** (not the SSH session):

```bash
cd ~/project

# Install deps locally (first time or after package.json changes)
npm install

# Run Electron in dev mode
npm start
# or: npx electron .
# or: npm run dev (depending on your setup)
```

Mutagen syncs your VPS edits to the Mac in ~200-500ms. Electron's hot reload picks up the changes automatically if you're using webpack/vite HMR.

---

## 6. Auto-Restart Script (Mac-Side)

If your setup doesn't have HMR, use this watcher to auto-restart Electron when files change:

Create `~/project/scripts/dev-watch.sh`:

```bash
#!/usr/bin/env bash
# Watches for file changes and restarts Electron
# Requires: brew install fswatch

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELECTRON_PID=""

start_electron() {
    cd "$PROJECT_DIR"
    npx electron . &
    ELECTRON_PID=$!
    echo "🚀 Electron started (PID: $ELECTRON_PID)"
}

stop_electron() {
    if [ -n "$ELECTRON_PID" ] && kill -0 "$ELECTRON_PID" 2>/dev/null; then
        kill "$ELECTRON_PID" 2>/dev/null
        wait "$ELECTRON_PID" 2>/dev/null
        echo "⏹  Electron stopped"
    fi
}

cleanup() {
    stop_electron
    exit 0
}

trap cleanup SIGINT SIGTERM

# Initial start
start_electron

# Watch for changes (ignore node_modules, dist, .git)
fswatch -o \
    --exclude "node_modules" \
    --exclude "dist" \
    --exclude ".git" \
    --exclude ".DS_Store" \
    -r "$PROJECT_DIR/src" "$PROJECT_DIR/main" "$PROJECT_DIR/renderer" \
    | while read -r _; do
        echo "🔄 Change detected, restarting..."
        stop_electron
        sleep 0.5
        start_electron
    done
```

```bash
chmod +x ~/project/scripts/dev-watch.sh
brew install fswatch
~/project/scripts/dev-watch.sh
```

---

## 7. Keeping node_modules in Sync

Since `node_modules` is ignored by Mutagen (intentionally — platform-specific binaries differ), you need to sync `package.json` changes manually:

### Quick approach: alias

Add to your Mac's `~/.zshrc` or `~/.bashrc`:

```bash
# After pulling package.json changes from VPS, reinstall on Mac
alias enpm="cd ~/project && npm install"
```

### Better approach: auto-detect

Create `~/project/scripts/watch-deps.sh` on the Mac:

```bash
#!/usr/bin/env bash
# Watches package.json and auto-runs npm install when it changes

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HASH_FILE="/tmp/.package-json-hash"

get_hash() {
    md5 -q "$PROJECT_DIR/package.json" 2>/dev/null || md5sum "$PROJECT_DIR/package.json" | cut -d' ' -f1
}

# Store initial hash
get_hash > "$HASH_FILE"

echo "👀 Watching package.json for changes..."

fswatch -o "$PROJECT_DIR/package.json" | while read -r _; do
    NEW_HASH=$(get_hash)
    OLD_HASH=$(cat "$HASH_FILE")

    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
        echo "$NEW_HASH" > "$HASH_FILE"
        echo "📦 package.json changed — running npm install..."
        cd "$PROJECT_DIR" && npm install
        echo "✅ Dependencies updated"
    fi
done
```

---

## 8. Convenience: One-Command Startup

Create `~/dev-start.sh` on your Mac:

```bash
#!/usr/bin/env bash
set -e

PROJECT=~/project
VPS="user@your-vps-ip"

echo "🔄 Starting Mutagen sync..."
cd "$PROJECT"
mutagen sync resume electron-dev 2>/dev/null || mutagen project start 2>/dev/null || true

echo "📦 Checking dependencies..."
npm install --prefer-offline --no-audit --no-fund 2>/dev/null

echo ""
echo "==================================="
echo "  Sync running. Mac ready."
echo "  Connect to VPS:  mosh $VPS"
echo "  Attach tmux:     tmux attach -t dev"
echo "  Run Electron:    npm start"
echo "==================================="
echo ""

# Optional: auto-open a terminal with mosh
# osascript -e "tell application \"Terminal\" to do script \"mosh $VPS -- tmux attach -t dev || tmux new -s dev\""
```

```bash
chmod +x ~/dev-start.sh
```

---

## 9. Useful Commands Reference

| Task | Command |
|---|---|
| Start sync | `mutagen project start` or `mutagen sync resume electron-dev` |
| Check sync status | `mutagen sync list` |
| Pause sync | `mutagen sync pause electron-dev` |
| Force re-sync | `mutagen sync flush electron-dev` |
| Reset sync (nuclear) | `mutagen sync reset electron-dev` |
| Connect to VPS | `mosh user@your-vps-ip` |
| Create tmux session | `tmux new -s dev` |
| Attach to tmux | `tmux attach -t dev` |
| Detach from tmux | `Ctrl-a d` |
| Kill tmux session | `tmux kill-session -t dev` |

---

## 10. Troubleshooting

**Sync is slow or stuck**
```bash
mutagen sync flush electron-dev    # force immediate sync
mutagen sync list                  # check for conflicts
```

**Conflicts (both sides edited same file)**
With `two-way-resolved`, the alpha (Mac) wins by default. To change this:
```yaml
mode: "two-way-resolved"
# Alpha wins. To make VPS win instead, swap alpha/beta in config.
```

**Electron can't find modules after sync**
```bash
cd ~/project && rm -rf node_modules && npm install
```

**Mosh connection issues**
```bash
# Make sure UDP ports 60000-61000 are open on VPS
sudo ufw allow 60000:61000/udp
```

**Large initial sync takes forever**
```bash
# Do the first sync via rsync, then let Mutagen maintain it
rsync -avz --exclude node_modules --exclude .git \
  user@your-vps-ip:~/project/ ~/project/
```
