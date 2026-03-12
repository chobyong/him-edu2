# NextCloud

## Overview

NextCloud runs as a Docker stack managed by `docker-compose.yml`.

- **Port**: 8081 (HTTP), 8443 (HTTPS)
- **Compose file**: `/opt/him-edu2/docker/nextcloud/docker-compose.yml`
- **Stack**: NextCloud, MariaDB, Redis, OnlyOffice Document Server, Nginx Proxy Manager

---

## Apps

The following apps are installed automatically during setup:

| App | ID | Description |
|---|---|---|
| Notes | `notes` | Personal notes |
| OnlyOffice | `onlyoffice` | Document/spreadsheet/presentation editing |
| Calendar | `calendar` | Calendar and events |
| Contacts | `contacts` | Address book |
| Whiteboard | `whiteboard` | Collaborative whiteboard |
| Mail | `mail` | Email client |
| Forms | `forms` | Surveys and forms |

OnlyOffice connects to the `onlyoffice/documentserver` container at port 9980.
Supported formats: `.docx`, `.xlsx`, `.pptx`, `.odt`, `.ods`, `.odp` and more.

To install apps on an already-running server:
```bash
sudo bash /opt/him-edu2/nextcloud-apps.sh
```

---

## User Accounts

Setup creates one admin and five generic user accounts:

| Username | Password | Role |
|---|---|---|
| `him` | `ABCD_1234` | Admin |
| `user1` – `user5` | `User@1234` | Regular user |

To create user accounts on an already-running server:
```bash
sudo bash /opt/him-edu2/nextcloud-users.sh
```

---

## Troubleshooting

**"Access through untrusted domain" error:**
```bash
sudo bash /opt/him-edu2/nextcloud-trust-domains.sh
```
This clears and re-adds all interface IPs (wired + wireless AP) automatically.

**Internal Server Error (500) on first visit:**
```bash
docker logs nextcloud 2>&1 | tail -30
docker exec redis redis-cli FLUSHALL
# Clear browser cookies/cache and reload
```

**NextCloud DB tables missing (`oc_appconfig` not found):**
```bash
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

**OnlyOffice editor not loading:**
```bash
# Check OnlyOffice container is running
sudo docker ps | grep onlyoffice

# Test document server is reachable
curl -s http://10.42.0.1:9980/healthcheck

# Re-apply OnlyOffice config
sudo docker exec --workdir /var/www/html -u www-data nextcloud \
  php occ config:app:set onlyoffice DocumentServerUrl --value="http://10.42.0.1:9980/"
sudo docker exec --workdir /var/www/html -u www-data nextcloud \
  php occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://onlyoffice/"
```

**Full NextCloud reset (fresh start):**
```bash
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml down
sudo rm -rf /opt/him-edu2/docker/nextcloud/nextclouddb/*
sudo rm -rf /opt/him-edu2/docker/nextcloud/html/
sudo rm -rf /opt/him-edu2/docker/nextcloud/config/
sudo bash /opt/him-edu2/setup.sh
```

**MariaDB container keeps restarting:**
```bash
docker logs nextcloud-db 2>&1 | tail -20
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml stop nextclouddb
sudo rm -rf /opt/him-edu2/docker/nextcloud/nextclouddb/*
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d nextclouddb
```

**All containers stopped after reboot:**
```bash
sudo systemctl status docker
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml up -d
```
