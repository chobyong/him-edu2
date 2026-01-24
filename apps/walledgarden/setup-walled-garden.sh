#!/usr/bin/env bash
set -e

WG_SUBNET="10.42.0.0/24"
WG_ADDR="10.42.0.1"
WG_DHCP_START="10.42.0.10"
WG_DHCP_END="10.42.0.254"
WG_DHCP_LEASE="12h"
WG_DOMAIN="him-edu.local"
DNSMASQ_CONF="/etc/dnsmasq.d/walled-garden.conf"

echo "=== Walled garden setup for ${WG_DOMAIN} on ${WG_ADDR}/24 ==="

# 0. Ensure dnsmasq is installed (Debian/Ubuntu)
echo "[0/5] Checking dnsmasq installation..."
if ! command -v dnsmasq >/dev/null 2>&1; then
  echo "dnsmasq not found, installing via apt..."
  sudo DEBIAN_FRONTEND=noninteractive \
    apt-get -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
    install -y dnsmasq
fi

# 1. Detect wireless interface (no renaming)
echo "[1/5] Detecting wireless interface..."
WLAN_IF=$(sudo iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n1)

if [ -z "$WLAN_IF" ]; then
  echo "ERROR: No wireless interface found via 'sudo iw dev'."
  exit 1
fi

echo "Using wireless interface: ${WLAN_IF}"

# 2. Ensure static IP on that interface (idempotent)
echo "[2/5] Ensuring ${WG_ADDR}/24 is on ${WLAN_IF}..."

if ip -4 -o addr show dev "${WLAN_IF}" | grep -q " ${WG_ADDR}/24"; then
  echo "IP ${WG_ADDR}/24 already present on ${WLAN_IF}, skipping add."
else
  echo "Adding ${WG_ADDR}/24 to ${WLAN_IF}..."
  # Optionally flush old addresses if you want a clean state:
  # sudo ip addr flush dev "${WLAN_IF}" || true
  sudo ip addr add "${WG_ADDR}/24" dev "${WLAN_IF}"
fi

echo "Bringing ${WLAN_IF} up..."
sudo ip link set "${WLAN_IF}" up
echo "State after bring-up:"
ip -br addr show dev "${WLAN_IF}"

# 3. dnsmasq: DHCP + captive DNS on that interface
echo "[3/5] Configuring dnsmasq (${DNSMASQ_CONF})..."

sudo mkdir -p /etc/dnsmasq.d

sudo tee "${DNSMASQ_CONF}" >/dev/null <<EOF
# Walled garden on ${WLAN_IF} - ${WG_SUBNET}
interface=${WLAN_IF}
bind-interfaces

# DHCP range
dhcp-range=${WG_DHCP_START},${WG_DHCP_END},${WG_DHCP_LEASE}

# Gateway and DNS
dhcp-option=3,${WG_ADDR}
dhcp-option=6,${WG_ADDR}

# Captive DNS: all names -> ${WG_ADDR}
address=/#/${WG_ADDR}

no-resolv
EOF

echo "Restarting dnsmasq..."
sudo systemctl restart dnsmasq

# 4. iptables: redirect Wi‑Fi HTTP to NPM/landing on 10.42.0.1:80
echo "[4/5] Configuring iptables..."

echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null

UPSTREAM_IF=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
echo "Detected upstream interface (optional NAT): ${UPSTREAM_IF:-none}"

# Flush existing NAT and FORWARD rules (careful if you rely on other rules)
sudo iptables -t nat -F
sudo iptables -F FORWARD || true

# NAT from walled-garden subnet out via upstream (if present)
if [ -n "$UPSTREAM_IF" ]; then
  sudo iptables -t nat -A POSTROUTING -s "${WG_SUBNET}" -o "${UPSTREAM_IF}" -j MASQUERADE
  sudo iptables -A FORWARD -i "${WLAN_IF}" -o "${UPSTREAM_IF}" -j ACCEPT
  sudo iptables -A FORWARD -i "${UPSTREAM_IF}" -o "${WLAN_IF}" -m state --state RELATED,ESTABLISHED -j ACCEPT
fi

# Redirect HTTP from Wi‑Fi to local landing page
sudo iptables -t nat -A PREROUTING -i "${WLAN_IF}" -p tcp --dport 80 -j DNAT --to-destination "${WG_ADDR}:80"

# Persist rules if tools are available
if command -v netfilter-persistent >/dev/null 2>&1; then
  sudo netfilter-persistent save
elif command -v iptables-save >/dev/null 2>&1; then
  sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
fi

# 5. /etc/hosts mapping for him-edu.local
echo "[5/5] Updating /etc/hosts for ${WG_DOMAIN}..."

ALL_IPS=$(ip -4 -o addr show | awk '!/ lo / {print $4}' | cut -d/ -f1 | tr '\n' ' ')

sudo sed -i '/him-edu\.local$/d' /etc/hosts

if [ -n "$ALL_IPS" ]; then
  echo "${ALL_IPS} ${WG_DOMAIN}" | sudo tee -a /etc/hosts >/dev/null
  echo "him-edu.local now maps to: ${ALL_IPS}"
else
  echo "WARNING: No non-loopback IPs found; /etc/hosts not updated for ${WG_DOMAIN}."
fi

echo "=== Walled garden setup complete ==="
echo "Wi‑Fi IF: ${WLAN_IF}, IP: ${WG_ADDR}/24"
echo "Wi‑Fi clients get DHCP 10.42.0.0/24 and DNS -> ${WG_ADDR}."
echo "All HTTP from Wi‑Fi is redirected to http://${WG_ADDR}:80 (NPM landing)."

