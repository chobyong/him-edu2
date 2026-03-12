#!/usr/bin/env bash
# Fix OnlyOffice "cannot be reached" by setting correct URLs.
# - DocumentServerUrl: browser-facing (him-edu.local via mDNS)
# - DocumentServerInternalUrl: NextCloud PHP → OnlyOffice (needs real host IP)
# - StorageUrl: OnlyOffice → NextCloud callback (needs real host IP)
# Usage: sudo bash nextcloud-fix-onlyoffice.sh [browser-hostname-or-ip]

set -euo pipefail
[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

OCC="docker exec --workdir /var/www/html -u www-data nextcloud php occ"

BROWSER_HOST="${1:-him-edu.local}"
# Auto-detect host IP via default route (works regardless of interface name)
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7}' | head -1)
if [[ -z "$HOST_IP" ]]; then
  HOST_IP=$(ip -4 addr show | awk '/inet / && !/127\./ && !/10\.42\./{print $2}' | cut -d/ -f1 | head -1)
fi
HOST_IP="${HOST_IP:-10.42.0.1}"

echo "Browser URL  → http://${BROWSER_HOST}:9980/"
echo "Internal URL → http://${HOST_IP}:9980/  (host IP, used by NextCloud container)"
echo "Storage URL  → http://${HOST_IP}:8081/  (host IP, used by OnlyOffice container)"
echo ""

$OCC config:app:set onlyoffice DocumentServerUrl         --value="http://${BROWSER_HOST}:9980/"
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value="http://${HOST_IP}:9980/"
$OCC config:app:set onlyoffice StorageUrl                --value="http://${HOST_IP}:8081/"

echo ""
echo "Done. Test connectivity:"
echo "  curl http://${BROWSER_HOST}:9980/healthcheck"
echo "  docker exec nextcloud curl http://${HOST_IP}:9980/healthcheck"
