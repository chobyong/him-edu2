# What Each Setup Step Does

## Step 0 — Clone Project from GitHub
Downloads the project files (docker-compose.yml, landing page, etc.) from GitHub to `/opt/him-edu2/`.
Skipped if the project is already present.

## Step 1 — Install System Packages
Installs Docker via the official `get.docker.com` script (handles repo setup automatically on any Debian variant — Raspberry Pi OS, Ubuntu, Debian trixie/bookworm, etc.).

Also installs via `apt`:
- `hostapd` — WiFi access point daemon
- `iptables-persistent` / `netfilter-persistent` — saves firewall rules across reboots
- `python3-venv` / `python3-full` — needed for the Kolibri virtual environment
- `iw` — wireless interface diagnostics

Enables the Docker service and adds the configured user to the `docker` group.

## WiFi Interface Detection
After packages are installed, the script automatically detects the WiFi interface name (e.g. `wlan0`, `wlp2s0`, `wlx...`) using `iw dev` and sysfs. The detected name is used for all subsequent AP and firewall steps — no manual configuration needed.

If no WiFi interface is found, a warning is shown and the script continues (NextCloud and Kolibri still install fully).

## Step 2 — Install Kolibri
- Creates a Python virtual environment at `/opt/kolibri-venv`
- Installs Kolibri via pip inside the venv
- Creates the data directory at `/opt/kolibri-data`
- Writes a systemd service file (`/etc/systemd/system/kolibri.service`) so Kolibri starts on boot
- On first visit, Kolibri's setup wizard runs — create your admin user there

## Step 3 — Configure hostapd
Writes `/etc/hostapd/hostapd.conf` using the auto-detected WiFi interface with:
- 2.4GHz, channel 6, WPA2-PSK
- SSID and password from configuration variables

Note: hostapd config is written for reference and fallback. The actual AP is managed by NetworkManager in Step 4.

## Step 4 — NetworkManager AP + DHCP
Creates a NetworkManager WiFi connection (`HimEdu-AP`) on the detected interface with:
- **mode: ap** — puts the interface into access point mode
- **ipv4.method: shared** — NetworkManager runs an internal dnsmasq to assign IP addresses (`10.42.0.x`) to connecting clients automatically
- Static IP `10.42.0.1/24` assigned to the server on the WiFi interface
- WPA2 security using the configured SSID and password

Also writes `/etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf` which makes NM's dnsmasq resolve **all domain names** to `10.42.0.1` — this triggers the captive portal prompt on client devices.

## Step 5 — Walled Garden (iptables)
Sets up firewall rules to intercept and redirect WiFi client traffic:
- Enables **IP forwarding** so the server can route traffic between WiFi clients and the wired network
- **MASQUERADE** — lets WiFi clients share the server's wired internet connection (NAT)
- **PREROUTING DNAT** — redirects all HTTP (port 80) requests from WiFi clients to the local Nginx Proxy Manager, showing the landing page instead of the internet
- Writes an **NM dispatcher script** (`/etc/NetworkManager/dispatcher.d/99-walled-garden`) that re-applies these rules automatically whenever the WiFi AP comes up after a reboot
- Saves all rules with `netfilter-persistent` for persistence

## Step 6 — NextCloud Docker Stack
- Creates all required data subdirectories under `/opt/him-edu2/docker/nextcloud/`
- Sets correct ownership for each Docker container user (www-data uid 33, mysql/redis uid 999)
- Pulls latest Docker images and starts the full stack: **NextCloud**, **MariaDB**, **Redis**, **Collabora**, **Nginx Proxy Manager**
- Waits for MariaDB to be ready before proceeding
- Fixes `config.php` ownership (NextCloud container may create it as root on first start)
- Runs `occ maintenance:install` if NextCloud is not yet installed
- Auto-detects the server's wired IP for trusted domains
- Sets **trusted domains** (wired IP, WiFi IP, local hostname)
- Temporarily disables the `password_policy` app to bypass the breach-database check, creates the admin user, then re-enables the app
- Deletes the default `admin` account
