#!/usr/bin/env bash
# =============================================================================
# NextCloud Trusted Domains Fix
# Adds all current interface IPs to NextCloud trusted_domains.
# Run if you see "Access through untrusted domain" error.
# Usage: sudo bash nextcloud-trust-domains.sh
# =============================================================================
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

NC_HTTP_PORT=8081
NC_HTTPS_PORT=8443
AP_IP="10.42.0.1"

OCC="docker exec --workdir /var/www/html -u www-data nextcloud php occ"

# Verify NextCloud container is running
docker exec nextcloud php occ status &>/dev/null || {
  echo "[ERROR] NextCloud container is not running. Start it with:"
  echo "  sudo docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d"
  exit 1
}

echo "Clearing existing trusted_domains..."
# Get current count and delete all
for i in $(seq 0 20); do
  $OCC config:system:delete trusted_domains $i 2>/dev/null || true
done

idx=0
echo "Adding trusted domains..."

for domain in \
  "localhost" \
  "127.0.0.1" \
  "${AP_IP}" \
  "${AP_IP}:${NC_HTTP_PORT}" \
  "${AP_IP}:${NC_HTTPS_PORT}" \
  "nextcloud.him-edu.local"; do
  $OCC config:system:set trusted_domains $((++idx)) --value="$domain"
  echo "  [$idx] $domain"
done

# All current interface IPs
while IFS= read -r iface_ip; do
  [[ -z "$iface_ip" ]] && continue
  $OCC config:system:set trusted_domains $((++idx)) --value="$iface_ip"
  echo "  [$idx] $iface_ip"
  $OCC config:system:set trusted_domains $((++idx)) --value="${iface_ip}:${NC_HTTP_PORT}"
  echo "  [$idx] ${iface_ip}:${NC_HTTP_PORT}"
done < <(ip -4 addr show | awk '/inet / {print $2}' | cut -d/ -f1 | grep -v '^127\.' || true)

echo ""
echo "Done. $idx trusted domains configured."
echo "Verify: http://${AP_IP}:${NC_HTTP_PORT}"
