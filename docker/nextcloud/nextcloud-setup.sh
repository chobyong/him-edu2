#!/usr/bin/env bash
set -e

STACK_DIR="${PWD}"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "=== Nextcloud Docker stack setup in: ${STACK_DIR} ==="

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo bash $0"
  exit 1
fi

# 0. Install Docker and Docker Compose
echo "[0/5] Installing Docker and Docker Compose..."
if ! command -v docker &>/dev/null; then
  apt-get install -y -qq curl
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
usermod -aG docker "$CURRENT_USER"
echo "      Docker installed. '$CURRENT_USER' added to docker group (re-login to use without sudo)."

# 1. Create directories
echo "[1/5] Creating directories..."
mkdir -p "${STACK_DIR}/html" \
         "${STACK_DIR}/custom_apps" \
         "${STACK_DIR}/config" \
         "${STACK_DIR}/data" \
         "${STACK_DIR}/nextclouddb" \
         "${STACK_DIR}/redis" \
         "${STACK_DIR}/npm-data" \
         "${STACK_DIR}/letsencrypt"

# 2. Set permissions for Nextcloud directories
echo "[2/5] Setting permissions for Nextcloud directories..."
sudo chown -R www-data:www-data "${STACK_DIR}/html" \
                                "${STACK_DIR}/custom_apps" \
                                "${STACK_DIR}/config" \
                                "${STACK_DIR}/data"
sudo chmod -R 750 "${STACK_DIR}/html" \
                  "${STACK_DIR}/custom_apps" \
                  "${STACK_DIR}/config" \
                  "${STACK_DIR}/data"

# 3. Set permissions for DB / Redis / NPM (use your local user here if you prefer)
echo "[3/5] Setting permissions for DB / Redis / NPM data..."
LOCAL_UID=$(id -u)
LOCAL_GID=$(id -g)

sudo chown -R "${LOCAL_UID}:${LOCAL_GID}" "${STACK_DIR}/nextclouddb" \
                                         "${STACK_DIR}/redis" \
                                         "${STACK_DIR}/npm-data" \
                                         "${STACK_DIR}/letsencrypt"

# 4. Bring up the stack
echo "[4/5] Starting Docker Compose stack..."
docker compose down || true
docker compose up -d

echo "=== Done. Open http://<host-ip>:8081 to finish Nextcloud setup. ==="
