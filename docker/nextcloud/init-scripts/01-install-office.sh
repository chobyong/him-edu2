#!/bin/bash
# Runs automatically after fresh NextCloud installation via Docker hook.
# Installs OnlyOffice connector and points it to the OnlyOffice Document Server container.

set -e

OCC="php /var/www/html/occ"

ONLYOFFICE_BROWSER_URL="http://10.42.0.1:9980/"
ONLYOFFICE_INTERNAL_URL="http://onlyoffice/"
NEXTCLOUD_INTERNAL_URL="http://nextcloud/"

echo "[office-init] Installing OnlyOffice connector app..."
$OCC app:install onlyoffice || $OCC app:enable onlyoffice

echo "[office-init] Configuring OnlyOffice Document Server connection..."
$OCC config:app:set onlyoffice DocumentServerUrl         --value="$ONLYOFFICE_BROWSER_URL"
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value="$ONLYOFFICE_INTERNAL_URL"
$OCC config:app:set onlyoffice StorageUrl                --value="$NEXTCLOUD_INTERNAL_URL"
$OCC config:app:set onlyoffice verify_peer_off           --value="true"

echo "[office-init] Enabling document creation formats..."
$OCC config:app:set onlyoffice defFormats \
  --value='{"docx":true,"xlsx":true,"pptx":true,"odt":true,"ods":true,"odp":true}'

$OCC config:app:set onlyoffice editFormats \
  --value='{"csv":true,"doc":true,"docm":true,"docx":true,"dotx":true,"epub":true,"html":true,"odp":true,"ods":true,"odt":true,"potm":true,"potx":true,"ppsm":true,"ppsx":true,"ppt":true,"pptm":true,"pptx":true,"rtf":true,"xls":true,"xlsm":true,"xlsx":true,"xltm":true,"xltx":true}'

echo "[office-init] Done. OnlyOffice Document Server connected."
