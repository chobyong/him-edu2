#!/usr/bin/env bash
# Fix OnlyOffice "cannot be reached" by setting DocumentServerUrl.
# Defaults to him-edu.local (works on both wired and WiFi via mDNS/captive DNS).
# Usage: sudo bash nextcloud-fix-onlyoffice.sh [hostname-or-ip]

set -euo pipefail
[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

OCC="docker exec --workdir /var/www/html -u www-data nextcloud php occ"

HOST_IP="${1:-him-edu.local}"

echo "Setting OnlyOffice DocumentServerUrl → http://${HOST_IP}:9980/"
$OCC config:app:set onlyoffice DocumentServerUrl         --value="http://${HOST_IP}:9980/"
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
$OCC config:app:set onlyoffice StorageUrl                --value="http://nextcloud/"

echo ""
echo "Done. Test: curl http://${HOST_IP}:9980/healthcheck"
echo "Access NextCloud at: http://${HOST_IP}:8081"
