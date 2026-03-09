#!/usr/bin/env bash
# =============================================================================
# HimEdu Reset Script — reverts server to pre-setup state for fresh testing
# Run as root: sudo bash reset.sh
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo bash $0"
  exit 1
fi

echo "=== HimEdu Reset: removing all installed components ==="

# 1. Stop and remove Docker containers
echo "[1/7] Stopping Docker containers..."
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml down -v 2>/dev/null || true
docker rm -f nextcloud nextcloud-db redis collabora nginx-proxy 2>/dev/null || true

# 2. Remove NextCloud data directories
echo "[2/7] Removing NextCloud data..."
rm -rf /opt/him-edu2/docker/nextcloud/html \
       /opt/him-edu2/docker/nextcloud/config \
       /opt/him-edu2/docker/nextcloud/data \
       /opt/him-edu2/docker/nextcloud/custom_apps \
       /opt/him-edu2/docker/nextcloud/nextclouddb \
       /opt/him-edu2/docker/nextcloud/redis \
       /opt/him-edu2/docker/nextcloud/npm-data \
       /opt/him-edu2/docker/nextcloud/letsencrypt

# 3. Remove cloned project
echo "[3/7] Removing /opt/him-edu2..."
rm -rf /opt/him-edu2

# 4. Remove Kolibri
echo "[4/7] Removing Kolibri..."
systemctl stop kolibri 2>/dev/null || true
systemctl disable kolibri 2>/dev/null || true
rm -f /etc/systemd/system/kolibri.service
systemctl daemon-reload
rm -rf /opt/kolibri-venv /opt/kolibri-data

# 5. Remove WiFi AP / captive portal config
echo "[5/7] Removing AP and captive portal config..."
nmcli con delete "HimEdu-AP" 2>/dev/null || true
rm -f /etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf
rm -f /etc/NetworkManager/dispatcher.d/99-walled-garden
rm -f /etc/hostapd/hostapd.conf

# 6. Clear iptables rules
echo "[6/7] Clearing iptables rules..."
iptables -t nat -F 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
rm -f /etc/iptables/rules.v4

# 7. Remove setup.sh
echo "[7/7] Removing setup.sh..."
rm -f /home/him/setup.sh

echo ""
echo "=== Reset complete. Server is back to initial state. ==="
echo ""
echo "To run a fresh setup:"
echo "  curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/setup.sh"
echo "  sudo bash setup.sh"
