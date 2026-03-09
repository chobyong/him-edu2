#!/bin/bash
# Install NextCloud apps on an already-running NextCloud instance.
# Usage: sudo bash nextcloud-apps.sh
set -euo pipefail

NC_CONTAINER="nextcloud"
OCC="docker exec --workdir /var/www/html -u www-data ${NC_CONTAINER} php occ"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# Apps to install
APPS=(
  notes
  richdocuments
  calendar
  contacts
  whiteboard
  mail
  forms
)

# Check NextCloud container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${NC_CONTAINER}$"; then
  err "Container '${NC_CONTAINER}' is not running."
  echo "Start it with: docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d"
  exit 1
fi

# Check occ is accessible
if ! $OCC status &>/dev/null; then
  err "Cannot reach occ — NextCloud may still be initializing. Try again in a minute."
  exit 1
fi

# Check internet access from inside the container
HTTP_CODE=$(docker exec --workdir / "${NC_CONTAINER}" curl -s --max-time 10 -o /dev/null -w '%{http_code}' https://apps.nextcloud.com 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" != "200" ]]; then
  err "No internet access from inside the NextCloud container (got: ${HTTP_CODE})."
  echo ""
  echo "Fix: restart Docker to restore its iptables forwarding rules, then re-run this script:"
  echo "  sudo systemctl restart docker"
  echo "  docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d"
  echo "  sudo bash $0"
  exit 1
fi

echo ""
echo "Installing NextCloud apps..."
echo "-------------------------------------------"

for app in "${APPS[@]}"; do
  # Check if already enabled
  if $OCC app:list 2>/dev/null | grep -q "^  - ${app}:"; then
    echo "  [skip]    ${app} — already enabled"
    continue
  fi
  # Check if installed but disabled
  if $OCC app:list --disabled 2>/dev/null | grep -q "^  - ${app}:"; then
    echo "  [enable]  ${app}..."
    $OCC app:enable "$app" 2>&1 | grep -v "^$" || true
    ok "${app} enabled."
    continue
  fi
  # Install fresh
  echo "  [install] ${app}..."
  if $OCC app:install "$app" 2>&1 | grep -v "^$"; then
    ok "${app} installed."
  else
    warn "${app} install failed — may not be available for this NextCloud version."
  fi
done

echo ""
ok "Done. Installed apps:"
$OCC app:list 2>/dev/null | grep -E "$(IFS='|'; echo "${APPS[*]}")" || true
echo ""
