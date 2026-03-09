# NextCloud

## Overview

NextCloud runs as a Docker stack managed by `docker-compose.yml`.

- **Port**: 8081 (HTTP), 8443 (HTTPS)
- **Compose file**: `/opt/him-edu2/docker/nextcloud/docker-compose.yml`
- **Stack**: NextCloud, MariaDB, Redis, Collabora, Nginx Proxy Manager

---

## Troubleshooting

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

docker exec nextcloud chown www-data:www-data /var/www/html/config/config.php

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
