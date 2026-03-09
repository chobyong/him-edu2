# Docker

## Overview

Docker is installed via the official `get.docker.com` script, which automatically handles repo setup on any Debian variant (Raspberry Pi OS, Ubuntu, Debian trixie/bookworm, etc.). The `docker compose` plugin is included.

---

## Troubleshooting

**`docker` command requires sudo after setup:**
```bash
# Either re-login, or activate the group in the current session:
newgrp docker
```

**Docker images fail to pull (no internet):**
```bash
# Check wired connection
ip addr show
ping -c 3 8.8.8.8

# If internet is fine, check DNS
cat /etc/resolv.conf
```

**Docker service not running:**
```bash
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl enable docker
```

**Check all container status:**
```bash
docker ps -a
docker compose -f /opt/him-edu2/docker/nextcloud/docker-compose.yml ps
```

**View container logs:**
```bash
docker logs nextcloud 2>&1 | tail -30
docker logs nextcloud-db 2>&1 | tail -20
docker logs redis 2>&1 | tail -20
docker logs nginx-proxy 2>&1 | tail -20
```
