#!/bin/bash
# Runs automatically after fresh NextCloud installation via Docker hook.
# Installs OnlyOffice connector and points it to the OnlyOffice Document Server container.

set -e

OCC="php /var/www/html/occ"

# AP IP is fixed — clients always reach OnlyOffice via this address
ONLYOFFICE_BROWSER_URL="http://10.42.0.1:9980/"
# Internal Docker network URL for NextCloud → OnlyOffice server communication
ONLYOFFICE_INTERNAL_URL="http://onlyoffice/"
NEXTCLOUD_INTERNAL_URL="http://nextcloud/"

echo "[office-init] Installing OnlyOffice connector app..."
$OCC app:install onlyoffice || $OCC app:enable onlyoffice

echo "[office-init] Configuring OnlyOffice Document Server connection..."
$OCC config:app:set onlyoffice DocumentServerUrl          --value="$ONLYOFFICE_BROWSER_URL"
$OCC config:app:set onlyoffice DocumentServerInternalUrl  --value="$ONLYOFFICE_INTERNAL_URL"
$OCC config:app:set onlyoffice StorageUrl                 --value="$NEXTCLOUD_INTERNAL_URL"
$OCC config:app:set onlyoffice verify_peer_off            --value="true"

echo "[office-init] Done. OnlyOffice Document Server connected."
