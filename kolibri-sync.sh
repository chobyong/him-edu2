#!/usr/bin/env bash
# =============================================================================
# Kolibri Sync Script
# Copies all Kolibri content from a master server to this server via rsync.
# Run ONCE after setup.sh — no internet required on the target server.
#
# Usage:
#   sudo bash kolibri-sync.sh <master-server-ip>
#
# Example:
#   sudo bash kolibri-sync.sh 10.0.1.102
# =============================================================================
set -euo pipefail

KOLIBRI_USER="${SUDO_USER:-him}"
KOLIBRI_HOME="/opt/kolibri-data"
KOLIBRI_VENV="/opt/kolibri-venv"
MASTER_IP="${1:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo bash $0 <master-ip>"
  exit 1
fi

if [[ -z "$MASTER_IP" ]]; then
  echo "Usage: sudo bash $0 <master-server-ip>"
  echo "Example: sudo bash $0 10.0.1.102"
  exit 1
fi

info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }

echo "============================================================"
echo "  Kolibri Content Sync"
echo "  Master : $MASTER_IP"
echo "  Target : $(hostname) (this server)"
echo "  Source : $MASTER_IP:$KOLIBRI_HOME/"
echo "  Dest   : $KOLIBRI_HOME/"
echo "============================================================"
echo ""
echo "NOTE: This copies all Kolibri databases and content files."
echo "      Safe to re-run — rsync only transfers changed files."
echo "      Requires SSH access to $MASTER_IP as user: $KOLIBRI_USER"
echo ""

# 1. Stop Kolibri on this server during sync
info "Stopping Kolibri service..."
systemctl stop kolibri 2>/dev/null || true

# 2. Ensure target directory exists with correct ownership
mkdir -p "$KOLIBRI_HOME"
chown "${KOLIBRI_USER}:${KOLIBRI_USER}" "$KOLIBRI_HOME"

# 3. Rsync content from master
info "Syncing Kolibri data from $MASTER_IP..."
echo "    (this may take a long time for large content libraries)"
echo ""

sudo -u "$KOLIBRI_USER" rsync \
  --archive \
  --verbose \
  --progress \
  --human-readable \
  --partial \
  --delete \
  "${KOLIBRI_USER}@${MASTER_IP}:${KOLIBRI_HOME}/" \
  "${KOLIBRI_HOME}/"

# 4. Fix ownership after rsync
chown -R "${KOLIBRI_USER}:${KOLIBRI_USER}" "$KOLIBRI_HOME"

# 5. Re-import channel metadata so Kolibri DB recognises the content
info "Re-registering channels in local Kolibri database..."
sudo -u "$KOLIBRI_USER" KOLIBRI_HOME="$KOLIBRI_HOME" \
  "$KOLIBRI_VENV/bin/kolibri" manage scanforfiles 2>&1 \
  | grep -v "^\[.*INFO\|override\|DEBUG" || true

# 6. Restart Kolibri
info "Starting Kolibri service..."
systemctl start kolibri

success "Sync complete. Kolibri is running with content from $MASTER_IP."
echo ""
echo "============================================================"
echo "  Access Kolibri at http://$(hostname -I | awk '{print $1}'):8080"
echo "============================================================"
