#!/usr/bin/env bash
# =============================================================================
# HimEdu Server Setup Script
# Replicates the full stack: Kolibri + NextCloud + HostAP + Walled Garden
# Run as root: sudo bash setup.sh
# =============================================================================
set -euo pipefail

# =============================================================================
# CONFIGURATION — edit these per server if needed
# =============================================================================
AP_SSID="him-edu"
AP_PASSWORD="1234567890"
AP_CHANNEL=6
AP_COUNTRY=US
AP_IP="10.42.0.1"
AP_SUBNET="10.42.0.0/24"
WLAN_IF="wlan0"

NC_HTTP_PORT=8081
NC_HTTPS_PORT=8443
NC_DB_PASSWORD="dbpassword"
NC_ADMIN_USER="him"
NC_ADMIN_PASS="ABCD_1234"

KOLIBRI_PORT=8080
KOLIBRI_USER="${SUDO_USER:-him}"
KOLIBRI_VENV="/opt/kolibri-venv"
KOLIBRI_HOME="/opt/kolibri-data"
KOLIBRI_FACILITY="HimEdu"
KOLIBRI_ADMIN_USER="him"
KOLIBRI_ADMIN_PASS="ABCD_1234"

PROJECT_DIR="/opt/him-edu2"
DOCKER_DIR="$PROJECT_DIR/docker/nextcloud"
GITHUB_REPO="https://github.com/chobyong/him-edu2.git"

# =============================================================================
# HELPERS
# =============================================================================
info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run with sudo: sudo bash $0"
    exit 1
  fi
}


# =============================================================================
# WIFI INTERFACE DETECTION
# =============================================================================
detect_wifi_interface() {
  info "Detecting WiFi interface..."
  local iface

  # Try iw first (most reliable for wireless interfaces)
  iface=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')

  # Fallback: scan sysfs for wireless interfaces
  if [[ -z "$iface" ]]; then
    iface=$(find /sys/class/net -maxdepth 2 -name wireless -type d 2>/dev/null | head -1 | awk -F/ '{print $(NF-1)}')
  fi

  if [[ -n "$iface" ]]; then
    WLAN_IF="$iface"
    success "WiFi interface detected: $WLAN_IF"
  else
    echo "[WARN] No WiFi interface found — using default: $WLAN_IF"
    echo "       AP setup may fail. Plug in a WiFi adapter and re-run if needed."
  fi
}

# =============================================================================
# 0. CLONE PROJECT FROM GITHUB
# =============================================================================
clone_project() {
  if [[ -f "$DOCKER_DIR/docker-compose.yml" ]]; then
    success "Project already at $PROJECT_DIR, skipping clone."
    return
  fi
  info "Cloning project from GitHub..."
  apt-get install -y -qq git
  git clone "$GITHUB_REPO" "$PROJECT_DIR"
  success "Project cloned to $PROJECT_DIR."
}

# =============================================================================
# 1. SYSTEM PACKAGES
# =============================================================================
install_packages() {
  info "Installing system packages..."
  # Install Docker via official script (handles repo setup for all Debian/RPi variants)
  if ! command -v docker &>/dev/null; then
    apt-get install -y -qq curl
    curl -fsSL https://get.docker.com | sh
  fi

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    hostapd \
    iptables-persistent \
    netfilter-persistent \
    python3-venv \
    python3-full \
    iw
  systemctl unmask hostapd || true

  # Enable Docker service
  systemctl enable --now docker

  # Allow KOLIBRI_USER to run docker without sudo
  usermod -aG docker "$KOLIBRI_USER"
  success "Packages installed. '$KOLIBRI_USER' added to docker group (re-login required for effect)."
}

# =============================================================================
# 2. KOLIBRI
# =============================================================================
install_kolibri() {
  info "Installing Kolibri..."
  if [[ ! -x "$KOLIBRI_VENV/bin/kolibri" ]]; then
    python3 -m venv "$KOLIBRI_VENV"
    "$KOLIBRI_VENV/bin/pip" install --quiet kolibri
    success "Kolibri installed in $KOLIBRI_VENV"
  else
    success "Kolibri already installed, skipping."
  fi

  mkdir -p "$KOLIBRI_HOME"
  chown "${KOLIBRI_USER}:${KOLIBRI_USER}" "$KOLIBRI_HOME"

  cat > /etc/systemd/system/kolibri.service <<EOF
[Unit]
Description=Kolibri Learning Platform
After=network.target

[Service]
Type=simple
User=${KOLIBRI_USER}
Environment=KOLIBRI_HOME=${KOLIBRI_HOME}
ExecStart=${KOLIBRI_VENV}/bin/kolibri start --foreground
ExecStop=${KOLIBRI_VENV}/bin/kolibri stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable kolibri
  systemctl start kolibri
  success "Kolibri service enabled and started (port $KOLIBRI_PORT)."
}

# =============================================================================
# 3. HOSTAPD
# =============================================================================
configure_hostapd() {
  info "Configuring hostapd..."
  cat > /etc/hostapd/hostapd.conf <<EOF
# HimEdu Access Point
interface=${WLAN_IF}
driver=nl80211
ssid=${AP_SSID}
hw_mode=g
channel=${AP_CHANNEL}
ieee80211n=1
wmm_enabled=1
country_code=${AP_COUNTRY}

# WPA2
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${AP_PASSWORD}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
  success "hostapd.conf written (SSID: $AP_SSID)."
}

# =============================================================================
# 4. NETWORKMANAGER AP + DHCP
# =============================================================================
configure_nm_ap() {
  info "Configuring NetworkManager AP connection..."

  nmcli con delete "HimEdu-AP" 2>/dev/null || true

  nmcli con add \
    type wifi \
    ifname "$WLAN_IF" \
    con-name "HimEdu-AP" \
    ssid "$AP_SSID" \
    mode ap \
    ipv4.method shared \
    ipv4.addresses "${AP_IP}/24" \
    wifi-sec.key-mgmt wpa-psk \
    wifi-sec.psk "$AP_PASSWORD"

  mkdir -p /etc/NetworkManager/dnsmasq-shared.d
  cat > /etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf <<EOF
# Captive portal: redirect all DNS to gateway
address=/#/${AP_IP}
EOF

  if nmcli con up "HimEdu-AP" 2>&1; then
    success "AP up — ${WLAN_IF} at ${AP_IP}/24, SSID: ${AP_SSID}."
  else
    echo "[WARN] AP connection created but could not activate now (driver/supplicant issue)."
    echo "       Config is saved — it will retry on reboot, or run: sudo nmcli con up HimEdu-AP"
  fi
}

# =============================================================================
# 5. WALLED GARDEN (iptables)
# =============================================================================
configure_walled_garden() {
  info "Configuring walled garden iptables..."

  echo 1 > /proc/sys/net/ipv4/ip_forward
  touch /etc/sysctl.conf
  grep -q 'net.ipv4.ip_forward' /etc/sysctl.conf \
    && sed -i 's/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf \
    || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

  # NM dispatcher: re-apply rules on AP bring-up
  cat > /etc/NetworkManager/dispatcher.d/99-walled-garden <<'DISPATCH'
#!/bin/bash
INTERFACE="$1"
EVENT="$2"
AP_IP="10.42.0.1"
AP_SUBNET="10.42.0.0/24"

if [ "$INTERFACE" = "wlan0" ] && [ "$EVENT" = "up" ]; then
  echo 1 > /proc/sys/net/ipv4/ip_forward
  iptables -t nat -F
  iptables -F FORWARD 2>/dev/null || true

  UPSTREAM=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | grep -v wlan0 | head -1)
  if [ -n "$UPSTREAM" ]; then
    iptables -t nat -A POSTROUTING -s "$AP_SUBNET" -o "$UPSTREAM" -j MASQUERADE
    iptables -A FORWARD -i wlan0 -o "$UPSTREAM" -j ACCEPT
    iptables -A FORWARD -i "$UPSTREAM" -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
  fi

  iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j DNAT --to-destination "${AP_IP}:80"
fi
DISPATCH
  chmod +x /etc/NetworkManager/dispatcher.d/99-walled-garden

  # Apply rules now
  local UPSTREAM
  UPSTREAM=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | grep -v wlan0 | head -1 || true)
  iptables -t nat -F
  iptables -F FORWARD 2>/dev/null || true
  if [[ -n "$UPSTREAM" ]]; then
    iptables -t nat -A POSTROUTING -s "$AP_SUBNET" -o "$UPSTREAM" -j MASQUERADE
    iptables -A FORWARD -i "$WLAN_IF" -o "$UPSTREAM" -j ACCEPT
    iptables -A FORWARD -i "$UPSTREAM" -o "$WLAN_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
  fi
  iptables -t nat -A PREROUTING -i "$WLAN_IF" -p tcp --dport 80 -j DNAT --to-destination "${AP_IP}:80"

  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  systemctl enable --now netfilter-persistent 2>/dev/null || true
  success "Walled garden rules applied and persisted."
}

# =============================================================================
# 6. NEXTCLOUD DOCKER STACK
# =============================================================================
start_nextcloud() {
  info "Starting NextCloud docker stack..."

  if [[ ! -f "$DOCKER_DIR/docker-compose.yml" ]]; then
    echo "ERROR: $DOCKER_DIR/docker-compose.yml not found."
    exit 1
  fi

  mkdir -p \
    "$DOCKER_DIR/html" \
    "$DOCKER_DIR/custom_apps" \
    "$DOCKER_DIR/config" \
    "$DOCKER_DIR/data" \
    "$DOCKER_DIR/nextclouddb" \
    "$DOCKER_DIR/npm-data" \
    "$DOCKER_DIR/letsencrypt" \
    "$DOCKER_DIR/redis"

  # Set ownership for Docker container users
  # NextCloud (www-data = uid 33): html, custom_apps, config, data
  chown -R 33:33 \
    "$DOCKER_DIR/html" \
    "$DOCKER_DIR/custom_apps" \
    "$DOCKER_DIR/config" \
    "$DOCKER_DIR/data"
  # MariaDB (mysql = uid 999): nextclouddb
  chown -R 999:999 "$DOCKER_DIR/nextclouddb"
  # Redis (uid 999): redis data
  chown -R 999:999 "$DOCKER_DIR/redis"

  docker compose -f "$DOCKER_DIR/docker-compose.yml" pull --quiet
  docker compose -f "$DOCKER_DIR/docker-compose.yml" up -d

  # Wait for NextCloud container to finish copying its files (occ must exist)
  info "Waiting for NextCloud container to be ready..."
  for i in $(seq 1 60); do
    if docker exec --workdir / nextcloud test -f /var/www/html/occ 2>/dev/null; then
      break
    fi
    echo -n "."
    sleep 3
  done
  echo ""

  # Wait for MariaDB — ping passes early, so wait until the nextcloud DB is actually queryable
  info "Waiting for MariaDB to be fully ready..."
  for i in $(seq 1 60); do
    if docker exec --workdir / nextcloud-db sh -c "mariadb -u nextcloud -p'${NC_DB_PASSWORD}' nextcloud -e 'SELECT 1' 2>/dev/null | grep -q 1"; then
      break
    fi
    echo -n "."
    sleep 3
  done
  echo ""

  # Fix config.php ownership — container may create it as root on first start
  docker exec --workdir / nextcloud chown www-data:www-data /var/www/html/config/config.php 2>/dev/null || true

  # First-time install check
  INSTALLED=$(docker exec --workdir / -u www-data nextcloud php occ status 2>/dev/null | grep "installed: true" || true)
  if [[ -z "$INSTALLED" ]]; then
    info "Running NextCloud first-time install..."
    if [[ -f "$DOCKER_DIR/config/config.php" ]]; then
      sed -i "s/'installed' => true,/'installed' => false,/" "$DOCKER_DIR/config/config.php" || true
    fi

    docker exec --workdir / -u www-data nextcloud php occ maintenance:install \
      --database mysql \
      --database-host nextclouddb \
      --database-name nextcloud \
      --database-user nextcloud \
      --database-pass "$NC_DB_PASSWORD" \
      --admin-user admin \
      --admin-pass "TempSetup_9x!"

    # Trusted domains
    local HOST_IP
    HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7}' | head -1 || echo "127.0.0.1")
    docker exec --workdir / -u www-data nextcloud php occ config:system:set trusted_domains 1 --value="${HOST_IP}:${NC_HTTP_PORT}"
    docker exec --workdir / -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="${AP_IP}:${NC_HTTP_PORT}"
    docker exec --workdir / -u www-data nextcloud php occ config:system:set trusted_domains 3 --value="nextcloud.him-edu.local"

    # Create configured admin user (disable password_policy app to bypass breach-db check)
    docker exec --workdir / -u www-data nextcloud php occ app:disable password_policy 2>/dev/null || true
    docker exec --workdir / nextcloud rm -rf "/var/www/html/data/${NC_ADMIN_USER}" 2>/dev/null || true
    docker exec --workdir / -u www-data -e OC_PASS="$NC_ADMIN_PASS" nextcloud php occ user:add \
      --password-from-env \
      --display-name="$NC_ADMIN_USER" \
      --group="admin" \
      "$NC_ADMIN_USER"
    docker exec --workdir / -u www-data nextcloud php occ user:delete admin 2>/dev/null || true
    docker exec --workdir / -u www-data nextcloud php occ app:enable password_policy 2>/dev/null || true

    success "NextCloud installed. Login: $NC_ADMIN_USER / $NC_ADMIN_PASS"
  else
    success "NextCloud already installed, skipping first-time setup."
  fi
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
  local HOST_IP
  HOST_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {print $7}' | head -1 || echo "unknown")
  echo ""
  echo "============================================================"
  echo "  HimEdu Setup Complete"
  echo "============================================================"
  echo "  WiFi AP"
  echo "    SSID     : $AP_SSID"
  echo "    Password : $AP_PASSWORD"
  echo "    Gateway  : $AP_IP"
  echo ""
  echo "  Services (wired: $HOST_IP)"
  echo "    Kolibri   : http://$HOST_IP:$KOLIBRI_PORT"
  echo "    NextCloud : http://$HOST_IP:$NC_HTTP_PORT"
  echo "    NPM Admin : http://$HOST_IP:81"
  echo ""
  echo "  Services (WiFi: $AP_IP)"
  echo "    Kolibri   : http://$AP_IP:$KOLIBRI_PORT"
  echo "    NextCloud : http://$AP_IP:$NC_HTTP_PORT"
  echo "    Landing   : http://$AP_IP (captive portal)"
  echo ""
  echo "  Logins"
  echo "    Kolibri   : $KOLIBRI_ADMIN_USER / $KOLIBRI_ADMIN_PASS"
  echo "    NextCloud : $NC_ADMIN_USER / $NC_ADMIN_PASS"
  echo "    NPM Admin : admin@example.com / changeme (first login)"
  echo "============================================================"
}

# =============================================================================
# MAIN
# =============================================================================
require_root

# Disable sleep/suspend — this is a server, never sleep
info "Disabling sleep and suspend..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
# Also prevent blank/sleep via logind
sed -i 's/^#*HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf 2>/dev/null || true
sed -i 's/^#*HandleSuspendKey=.*/HandleSuspendKey=ignore/' /etc/systemd/logind.conf 2>/dev/null || true
sed -i 's/^#*IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf 2>/dev/null || true
systemctl restart systemd-logind 2>/dev/null || true
success "Sleep and suspend disabled."

clone_project
install_packages
detect_wifi_interface
install_kolibri
configure_hostapd
configure_nm_ap
configure_walled_garden
start_nextcloud
print_summary
