#!/bin/bash
# Runs automatically after fresh NextCloud installation via Docker hook.
# Installs OnlyOffice connector and points it to the OnlyOffice Document Server container.

set -e

OCC="php /var/www/html/occ"

# DocumentServerUrl: browser-facing — him-edu.local resolves via:
#   - Avahi mDNS for wired clients (resolves to wired IP)
#   - Captive DNS for WiFi clients (all DNS → 10.42.0.1)
# DocumentServerInternalUrl: NextCloud PHP → OnlyOffice using host eth0 IP
#   (him-edu.local doesn't resolve inside Docker containers)
# StorageUrl: OnlyOffice callbacks to NextCloud using host eth0 IP
HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7}' | head -1)
HOST_IP="${HOST_IP:-10.42.0.1}"

ONLYOFFICE_BROWSER_URL="http://him-edu.local:9980/"
ONLYOFFICE_INTERNAL_URL="http://${HOST_IP}:9980/"
NEXTCLOUD_STORAGE_URL="http://${HOST_IP}:8081/"

echo "[office-init] Installing OnlyOffice connector app..."
$OCC app:install onlyoffice || $OCC app:enable onlyoffice

echo "[office-init] Configuring OnlyOffice Document Server connection..."
echo "[office-init]   Browser URL:  ${ONLYOFFICE_BROWSER_URL}"
echo "[office-init]   Internal URL: ${ONLYOFFICE_INTERNAL_URL}"
echo "[office-init]   Storage URL:  ${NEXTCLOUD_STORAGE_URL}"

$OCC config:app:set onlyoffice DocumentServerUrl         --value="$ONLYOFFICE_BROWSER_URL"
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value="$ONLYOFFICE_INTERNAL_URL"
$OCC config:app:set onlyoffice StorageUrl                --value="$NEXTCLOUD_STORAGE_URL"
$OCC config:app:set onlyoffice verify_peer_off           --value="true"

echo "[office-init] Enabling document creation formats..."
$OCC config:app:set onlyoffice defFormats \
  --value='{"docx":true,"xlsx":true,"pptx":true,"odt":true,"ods":true,"odp":true}'

$OCC config:app:set onlyoffice editFormats \
  --value='{"csv":true,"doc":true,"docm":true,"docx":true,"dotx":true,"epub":true,"html":true,"odp":true,"ods":true,"odt":true,"potm":true,"potx":true,"ppsm":true,"ppsx":true,"ppt":true,"pptm":true,"pptx":true,"rtf":true,"xls":true,"xlsm":true,"xlsx":true,"xltm":true,"xltx":true}'

echo "[office-init] Done. OnlyOffice Document Server connected."
