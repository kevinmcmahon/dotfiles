#!/usr/bin/env bash
# printing.sh — Set up CUPS printing with HP M255dw
# Safe to re-run (idempotent)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Printer Setup ==="

# --- 1. Install CUPS and hplip ---
echo "[1/3] Installing CUPS and hplip..."
sudo apt-get install -y cups hplip

# --- 2. Copy PPD ---
echo "[2/3] Installing HP PPD..."
sudo cp "$SCRIPT_DIR/HP_M255dw.ppd" /etc/cups/ppd/HP_M255dw.ppd
sudo chmod 644 /etc/cups/ppd/HP_M255dw.ppd

# --- 3. Add/update printer ---
echo "[3/3] Configuring HP_M255dw..."
if lpstat -p HP_M255dw &>/dev/null; then
    echo "  Printer already exists — updating..."
    sudo lpadmin -p HP_M255dw \
        -v ipp://192.168.7.59/ipp/print \
        -P "$SCRIPT_DIR/HP_M255dw.ppd" \
        -E
else
    echo "  Adding printer..."
    sudo lpadmin -p HP_M255dw \
        -v ipp://192.168.7.59/ipp/print \
        -P "$SCRIPT_DIR/HP_M255dw.ppd" \
        -E
fi

echo ""
echo "=== Done ==="
echo "Verify with: lpstat -p HP_M255dw"
echo "Test print:  echo 'Test' | lp -d HP_M255dw"
