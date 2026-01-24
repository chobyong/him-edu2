#!/usr/bin/env bash
set -e

STACK_DIR="${PWD}"

echo "=== Nextcloud Docker stack setup in: ${STACK_DIR} ==="

# 1. Create directories
echo "[1/4] Creating directories..."
mkdir -p "${STACK_DIR}/html" \
         "${STACK_DIR}/custom_apps" \
         "${STACK_DIR}/config" \
         "${STACK_DIR}/data" \
         "${STACK_DIR}/nextclouddb" \
         "${STACK_DIR}/redis" \
         "${STACK_DIR}/npm-data" \
         "${STACK_DIR}/letsencrypt"

# 2. Set permissions for Nextcloud directories
echo "[2/4] Setting permissions for Nextcloud directories..."
sudo chown -R www-data:www-data "${STACK_DIR}/html" \
                                "${STACK_DIR}/custom_apps" \
                                "${STACK_DIR}/config" \
                                "${STACK_DIR}/data"
sudo chmod -R 750 "${STACK_DIR}/html" \
                  "${STACK_DIR}/custom_apps" \
                  "${STACK_DIR}/config" \
                  "${STACK_DIR}/data"

# 3. Set permissions for DB / Redis / NPM (use your local user here if you prefer)
echo "[3/4] Setting permissions for DB / Redis / NPM data..."
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)

sudo chown -R "${LOCAL_UID}:${LOCAL_GID}" "${STACK_DIR}/nextclouddb" \
                                         "${STACK_DIR}/redis" \
                                         "${STACK_DIR}/npm-data" \
                                         "${STACK_DIR}/letsencrypt"

# 4. Bring up the stack
echo "[4/4] Starting Docker Compose stack..."
docker compose down || true
docker compose up -d

echo "=== Done. Open http://<host-ip>:8081 to finish Nextcloud setup. ==="
