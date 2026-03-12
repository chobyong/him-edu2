#!/bin/bash
# Runs automatically after fresh NextCloud installation via Docker hook.
# Installs Community Document Server (built-in OnlyOffice) for offline document editing.

set -e

OCC="php /var/www/html/occ"

echo "[office-init] Installing Community Document Server..."
$OCC app:install documentserver_community || $OCC app:enable documentserver_community

echo "[office-init] Installing OnlyOffice connector..."
$OCC app:install onlyoffice || $OCC app:enable onlyoffice

echo "[office-init] Configuring OnlyOffice to use Community Document Server..."
$OCC config:app:set onlyoffice DocumentServerUrl --value=""
$OCC config:app:set onlyoffice DocumentServerInternalUrl --value=""
$OCC config:app:set onlyoffice StorageUrl --value=""

echo "[office-init] Done. OnlyOffice is ready."
