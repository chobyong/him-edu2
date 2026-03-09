# Resetting the Server

## Full Reset (for re-testing setup.sh)

Use `reset.sh` to fully revert a server to its initial state before re-running `setup.sh`:

```bash
curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/reset.sh
sudo bash reset.sh
```

This stops and removes:
- All Docker containers and volumes
- `/opt/him-edu2/` project directory
- Kolibri venv, data, and systemd service
- `HimEdu-AP` NetworkManager connection
- iptables NAT and FORWARD rules
- `setup.sh` from `/home/him/`

After reset, run setup again from scratch:
```bash
curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/setup.sh
sudo bash setup.sh
```

---

## Partial Resets

**Reset NextCloud only (keep Kolibri and AP):**
```bash
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml down
sudo rm -rf /opt/him-edu2/docker/nextcloud/nextclouddb/*
sudo rm -rf /opt/him-edu2/docker/nextcloud/html/
sudo rm -rf /opt/him-edu2/docker/nextcloud/config/
# Re-run setup.sh — it will skip Kolibri and AP, and re-install NextCloud
sudo bash /home/him/setup.sh
```

**Reset Kolibri only:**
```bash
sudo systemctl stop kolibri
sudo systemctl disable kolibri
sudo rm -f /etc/systemd/system/kolibri.service
sudo rm -rf /opt/kolibri-venv /opt/kolibri-data
# Re-run setup.sh — it will re-install Kolibri only
sudo bash /home/him/setup.sh
```

**Reset WiFi AP only:**
```bash
sudo nmcli con delete HimEdu-AP 2>/dev/null || true
sudo iptables -t nat -F
sudo iptables -F FORWARD
# Re-run setup.sh — it will re-configure the AP
sudo bash /home/him/setup.sh
```
