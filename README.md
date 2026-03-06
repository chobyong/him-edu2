# HimEdu Server Setup

Automated setup script for the HimEdu educational hotspot server.
Deploys Kolibri, NextCloud, a WiFi access point, and a captive portal
on a Raspberry Pi 5 running Debian.

---

## Requirements

- Raspberry Pi 5 (arm64) with Debian trixie
- Wired internet connection (`end0`) during setup
- WiFi interface (`wlan0`) that supports AP mode
- The `/opt/him-edu2/` project directory present on the server

---

## Quick Start

**1. Copy the project to the new server:**
```bash
rsync -av /opt/him-edu2/ user@NEW_SERVER_IP:/opt/him-edu2/
scp /home/him/setup.sh /home/him/README.md user@NEW_SERVER_IP:/home/him/
```

**2. SSH into the new server and run:**
```bash
sudo bash /home/him/setup.sh
```

Setup takes 5–15 minutes depending on internet speed (pulls Docker images and installs Python packages).

---

## Configuration

Edit the variables at the top of `setup.sh` before running:

```bash
# WiFi Access Point
AP_SSID="him-edu"         # Network name clients will see
AP_PASSWORD="1234567890"  # WiFi password (min 8 characters)
AP_CHANNEL=6              # 2.4GHz channel (1-11)
AP_COUNTRY=US             # Regulatory country code
AP_IP="10.42.0.1"         # Gateway IP assigned to this server on WiFi

# NextCloud
NC_ADMIN_USER="him"       # Admin username
NC_ADMIN_PASS="ABCD_1234" # Admin password

# Kolibri
KOLIBRI_USER="him"              # Linux user that runs the Kolibri process
KOLIBRI_ADMIN_USER="him"        # Kolibri web login username
KOLIBRI_ADMIN_PASS="ABCD_1234"  # Kolibri web login password
KOLIBRI_FACILITY="HimEdu"       # School/facility name in Kolibri
```

---

## What Each Step Does

### Step 1 — Install System Packages
Installs all required system packages via `apt`:
- `hostapd` — WiFi access point daemon (config only, NM manages the AP)
- `iptables-persistent` / `netfilter-persistent` — saves firewall rules across reboots
- `python3-venv` / `python3-full` — needed to create the Kolibri virtual environment
- `docker.io` + `docker-compose-plugin` — container runtime for NextCloud stack
- `iw` — wireless interface diagnostics

Enables the Docker service and adds the configured user to the `docker` group so they can run `docker` commands without `sudo` after re-login.

### Step 2 — Install Kolibri
- Creates a Python virtual environment at `/opt/kolibri-venv`
- Installs Kolibri via pip inside the venv
- Creates the data directory at `/opt/kolibri-data`
- Writes a systemd service file (`/etc/systemd/system/kolibri.service`) so Kolibri starts on boot
- Runs the admin user setup (Step 2b) before starting the service

### Step 2b — Set Up Kolibri Admin User
Runs before Kolibri starts to ensure the DB is configured correctly:
- Creates a **Facility** named `HimEdu` (required by Kolibri before any users can exist)
- Creates the admin user with the configured username and password
- Grants **device-level superuser** permissions (can manage content, users, and settings)
- If the user already exists (re-run), updates the password instead

### Step 3 — Configure hostapd
Writes `/etc/hostapd/hostapd.conf` with:
- Interface: `wlan0`, 2.4GHz, channel 6, WPA2-PSK
- SSID and password from configuration variables

Note: hostapd config is written for reference and fallback. The actual AP is managed by NetworkManager in Step 4.

### Step 4 — NetworkManager AP + DHCP
Creates a NetworkManager WiFi connection (`HimEdu-AP`) on `wlan0` with:
- **mode: ap** — puts the interface into access point mode
- **ipv4.method: shared** — NetworkManager runs an internal dnsmasq to assign IP addresses (`10.42.0.x`) to connecting clients automatically
- Static IP `10.42.0.1/24` assigned to the server on the WiFi interface
- WPA2 security using the configured SSID and password

Also writes `/etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf` which makes NM's dnsmasq resolve **all domain names** to `10.42.0.1` — this is what triggers the captive portal prompt on client devices.

### Step 5 — Walled Garden (iptables)
Sets up firewall rules to intercept and redirect WiFi client traffic:
- Enables **IP forwarding** so the Pi can route traffic between WiFi clients and the wired network
- **MASQUERADE** — lets WiFi clients share the Pi's wired internet connection (NAT)
- **PREROUTING DNAT** — redirects all HTTP (port 80) requests from WiFi clients to the Pi's local Nginx Proxy Manager, showing the landing page instead of the internet
- Writes an **NM dispatcher script** (`/etc/NetworkManager/dispatcher.d/99-walled-garden`) that re-applies these rules automatically whenever the WiFi AP comes up after a reboot
- Saves all rules with `netfilter-persistent` for persistence

### Step 6 — NextCloud Docker Stack
- Creates all required data subdirectories under `/opt/him-edu2/docker/nextcloud/`
- Pulls latest Docker images for all services
- Starts the full stack: **NextCloud**, **MariaDB**, **Redis**, **Collabora**, **Nginx Proxy Manager**
- Waits for MariaDB to be ready before proceeding
- Runs `occ maintenance:install` if NextCloud is not yet installed
- Sets **trusted domains** (wired IP, WiFi IP, local hostname)
- Relaxes password policy to allow the configured password
- Creates the admin user and removes the default `admin` account

---

## Services After Setup

### WiFi Access Point
| Setting | Value |
|---|---|
| SSID | `him-edu` |
| Password | `1234567890` |
| Server IP | `10.42.0.1` |
| Client DHCP range | `10.42.0.2 – 10.42.0.254` |

All HTTP traffic from WiFi clients is redirected to the landing page. DNS resolves all domains to `10.42.0.1`.

### Access URLs

**From wired network:**
| Service | URL |
|---|---|
| Kolibri | `http://<wired-ip>:8080` |
| NextCloud | `http://<wired-ip>:8081` |
| NPM Admin | `http://<wired-ip>:81` |

**From WiFi (`him-edu`):**
| Service | URL |
|---|---|
| Landing page | `http://10.42.0.1` |
| Kolibri | `http://10.42.0.1:8080` |
| NextCloud | `http://10.42.0.1:8081` |

### Default Logins
| Service | Username | Password |
|---|---|---|
| Kolibri | `him` | `ABCD_1234` |
| NextCloud | `him` | `ABCD_1234` |
| NPM (first login) | `admin@example.com` | `changeme` |

---

## Directory Structure

```
/home/him/
├── setup.sh              ← setup script
└── README.md             ← this file

/opt/him-edu2/
├── apps/
│   └── landing/www/      ← landing page (index.html, styles.css)
└── docker/nextcloud/
    ├── docker-compose.yml
    ├── config/           ← NextCloud config (auto-generated)
    ├── data/             ← NextCloud user files
    ├── html/             ← NextCloud app files
    ├── nextclouddb/      ← MariaDB data files
    ├── redis/            ← Redis data
    ├── npm-data/         ← Nginx Proxy Manager config
    └── letsencrypt/      ← SSL certificates

/opt/kolibri-venv/        ← Kolibri Python virtualenv
/opt/kolibri-data/        ← Kolibri database and content
```

---

## Re-running the Script

The script is **idempotent** — safe to run again on an existing server:
- Kolibri skipped if already installed in the venv
- Kolibri admin password updated if user already exists
- NM AP connection deleted and re-created (picks up any config changes)
- NextCloud install skipped if already installed

---

## Troubleshooting

---

### WiFi / Access Point

**AP not showing up / SSID not visible:**
```bash
# Check connection status
nmcli device status
nmcli con show HimEdu-AP

# Bring it up manually
sudo nmcli con up HimEdu-AP

# Verify wlan0 has the right IP
ip addr show wlan0
```

**SSID visible but clients can't connect:**
```bash
# Check hostapd config is correct
cat /etc/hostapd/hostapd.conf

# Check NM AP security settings
nmcli -f 802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk con show HimEdu-AP

# Update password if needed (no re-run of full script required)
sudo nmcli con modify HimEdu-AP wifi-sec.psk "newpassword"
sudo nmcli con up HimEdu-AP
```

**Clients connect to WiFi but get no IP address:**
```bash
# NM's internal dnsmasq should handle DHCP — check it's running
ps aux | grep dnsmasq

# Restart the AP connection to restart dnsmasq
sudo nmcli con down HimEdu-AP
sudo nmcli con up HimEdu-AP
```

**Clients get IP but can't reach the landing page (no captive portal):**
```bash
# Check iptables redirect rule
sudo iptables -t nat -L PREROUTING -n --line-numbers

# Re-apply walled garden rules manually
sudo /etc/NetworkManager/dispatcher.d/99-walled-garden wlan0 up

# Check captive portal DNS config exists
cat /etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf
```

**AP stops working after reboot:**
```bash
# Ensure the NM connection is set to auto-connect
sudo nmcli con modify HimEdu-AP connection.autoconnect yes

# Ensure iptables rules are saved
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent
```

**Change SSID or password without re-running full setup:**
```bash
sudo nmcli con modify HimEdu-AP wifi.ssid "new-ssid"
sudo nmcli con modify HimEdu-AP wifi-sec.psk "newpassword"
sudo nmcli con up HimEdu-AP
# Also update /etc/hostapd/hostapd.conf to match
```

---

### Kolibri

**Kolibri service not starting:**
```bash
sudo systemctl status kolibri
sudo journalctl -u kolibri -n 50 --no-pager
```

**Kolibri starts but setup wizard appears (no admin user):**
```bash
# Re-run admin setup manually
sudo -u him KOLIBRI_HOME=/opt/kolibri-data /opt/kolibri-venv/bin/kolibri manage shell -- -c "
from kolibri.core.auth.models import Facility, FacilityUser
from kolibri.core.device.models import DevicePermissions
facility, _ = Facility.objects.get_or_create(name='HimEdu')
user, created = FacilityUser.objects.get_or_create(username='him', defaults={'facility': facility})
user.facility = facility
user.set_password('ABCD_1234')
user.save()
DevicePermissions.objects.update_or_create(user=user, defaults={'is_superuser': True, 'can_manage_content': True})
print('Done')
"
sudo systemctl restart kolibri
```

**Can't log in to Kolibri (wrong password):**
```bash
# Reset password
sudo systemctl stop kolibri
sudo -u him KOLIBRI_HOME=/opt/kolibri-data /opt/kolibri-venv/bin/kolibri manage changepassword him
sudo systemctl start kolibri
```

**Kolibri running on wrong port or not accessible:**
```bash
# Check what port it's listening on
sudo ss -tlnp | grep kolibri
# Should show 0.0.0.0:8080

# Check service config
cat /etc/systemd/system/kolibri.service
```

**Kolibri data directory permissions error:**
```bash
sudo chown -R him:him /opt/kolibri-data
sudo systemctl restart kolibri
```

---

### NextCloud

**Internal Server Error (500) on first visit:**
```bash
# Check container logs
docker logs nextcloud 2>&1 | tail -30

# Clear stale Redis sessions (most common cause after reinstall)
docker exec redis redis-cli FLUSHALL

# Then clear browser cookies/cache and reload
```

**NextCloud DB tables missing (`oc_appconfig` not found):**
```bash
# The DB was wiped but config.php thinks it's installed
# Mark as not installed and re-run installer
sudo sed -i "s/'installed' => true,/'installed' => false,/" \
  /opt/him-edu2/docker/nextcloud/config/config.php

sudo chown -R 33:33 /opt/him-edu2/docker/nextcloud/config \
                    /opt/him-edu2/docker/nextcloud/data

docker exec -u www-data nextcloud php occ maintenance:install \
  --database mysql --database-host nextclouddb \
  --database-name nextcloud --database-user nextcloud \
  --database-pass dbpassword \
  --admin-user admin --admin-pass "TempSetup_9x!"
```

**Full NextCloud reset (fresh start):**
```bash
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml down
sudo rm -rf /opt/him-edu2/docker/nextcloud/nextclouddb/*
sudo rm -rf /opt/him-edu2/docker/nextcloud/html/
sudo rm -rf /opt/him-edu2/docker/nextcloud/config/
sudo bash /home/him/setup.sh
```

**NextCloud trusted domain error ("Access through untrusted domain"):**
```bash
# Add the IP/hostname you're accessing from
docker exec -u www-data nextcloud php occ config:system:set \
  trusted_domains 4 --value="192.168.1.100:8081"
```

**NextCloud login works but /settings/apps gives 500:**
```bash
# Stale encrypted sessions in Redis — flush them
docker exec redis redis-cli FLUSHALL
# Open a fresh incognito window and log in again
```

**MariaDB container keeps restarting:**
```bash
docker logs nextcloud-db 2>&1 | tail -20

# If "undo tablespace" errors appear, the DB dir has stale files
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml stop nextclouddb
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml rm -f nextclouddb
sudo rm -rf /opt/him-edu2/docker/nextcloud/nextclouddb/*
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d nextclouddb
```

**All containers stopped after reboot:**
```bash
# Containers have restart: unless-stopped so they should auto-start with Docker
sudo systemctl status docker

# Start manually if needed
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d
```

---

### Docker

**`docker` command requires sudo after setup:**
```bash
# Either re-login, or activate the group in current session:
newgrp docker
```

**Docker images fail to pull (no internet):**
```bash
# Check wired connection
ip addr show end0
ping -c 3 8.8.8.8

# If internet is fine, check DNS
cat /etc/resolv.conf
```
