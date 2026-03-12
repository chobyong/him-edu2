#!/usr/bin/env bash
# Fix OnlyOffice "cannot be reached" by setting DocumentServerUrl
# to the IP the browser can actually reach.
# Usage: sudo bash nextcloud-fix-onlyoffice.sh [IP]
#   IP defaults to the server's primary wired interface IP

set -euo pipefail
[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

OCC="docker exec --workdir /var/www/html -u www-data nextcloud php occ"

# Use provided IP or auto-detect wired IP
if [[ -n "${1:-}" ]]; then
  HOST_IP="$1"
else
  HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7}' | head -1 || echo "")
  [[ -z "$HOST_IP" ]] && { echo "Cannot detect IP — pass it as argument: sudo bash $0 10.0.1.109"; exit 1; }
fi

echo "Setting OnlyOffice DocumentServerUrl → http://${HOST_IP}:9980/"
$OCC config:app:set onlyoffice DocumentServerUrl         --value="http://${HOST_IP}:9980/"
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
$OCC config:app:set onlyoffice StorageUrl                --value="http://nextcloud/"

echo ""
echo "Done. Test: http://${HOST_IP}:9980/healthcheck"
echo "Access NextCloud at: http://${HOST_IP}:8081"
