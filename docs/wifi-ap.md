# WiFi Access Point

## Overview

The WiFi AP is managed by NetworkManager (`HimEdu-AP` connection) using `ipv4.method: shared`, which runs an internal dnsmasq for DHCP. A captive portal DNS config redirects all domain lookups to `10.42.0.1`, triggering the captive portal prompt on client devices.

- **Interface**: auto-detected (`wlan0`, `wlp2s0`, `wlx...`)
- **NM Connection**: `HimEdu-AP`
- **Server IP**: `10.42.0.1/24`
- **DHCP range**: `10.42.0.2 – 10.42.0.254`
- **Captive DNS config**: `/etc/NetworkManager/dnsmasq-shared.d/captive-portal.conf`
- **Walled garden rules**: `/etc/NetworkManager/dispatcher.d/99-walled-garden`

---

## Troubleshooting

**AP not showing up / SSID not visible:**
```bash
# Check what WiFi interface was detected
iw dev

# Check connection status
nmcli device status
nmcli con show HimEdu-AP

# Bring it up manually
sudo nmcli con up HimEdu-AP

# Verify the interface has the right IP
ip addr show wlan0
```

**SSID visible but clients can't connect:**
```bash
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
