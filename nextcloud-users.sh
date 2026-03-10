#!/bin/bash
# Create generic user accounts (user1–user5) on a running NextCloud instance.
# Usage: sudo bash nextcloud-users.sh
set -euo pipefail

NC_CONTAINER="nextcloud"
NC_USER_PASS="User@1234"   # Change this to set a different default password
OCC="docker exec --workdir /var/www/html -u www-data ${NC_CONTAINER} php occ"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# Check container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${NC_CONTAINER}$"; then
  err "Container '${NC_CONTAINER}' is not running."
  exit 1
fi

# Check occ is accessible
if ! $OCC status &>/dev/null; then
  err "Cannot reach occ — NextCloud may still be initializing. Try again in a minute."
  exit 1
fi

echo ""
echo "Creating NextCloud users..."
echo "-------------------------------------------"

# Disable password policy to avoid breach-db rejections
$OCC app:disable password_policy 2>/dev/null || true

for i in 1 2 3 4 5; do
  uname="user${i}"
  if $OCC user:list 2>/dev/null | grep -q "${uname}"; then
    echo "  [skip]   ${uname} — already exists"
  else
    docker exec --workdir /var/www/html -u www-data -e OC_PASS="$NC_USER_PASS" \
      "${NC_CONTAINER}" php occ user:add \
      --password-from-env \
      --display-name="User ${i}" \
      "$uname" && ok "${uname} created."
  fi
done

$OCC app:enable password_policy 2>/dev/null || true

echo ""
ok "Done. Users:"
$OCC user:list 2>/dev/null | grep -E "user[1-5]" || true
echo ""
echo "Default password: ${NC_USER_PASS}"
echo "Users can change their password after first login."
echo ""
