# Services After Setup

## WiFi Access Point

| Setting | Value |
|---|---|
| SSID | `him-edu` |
| Password | `1234567890` |
| Server IP | `10.42.0.1` |
| Client DHCP range | `10.42.0.2 – 10.42.0.254` |

All HTTP traffic from WiFi clients is redirected to the landing page. DNS resolves all domains to `10.42.0.1`.

## Access URLs

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

## Default Logins

| Service | Username | Password |
|---|---|---|
| Kolibri | set via setup wizard on first visit | — |
| NextCloud (admin) | `him` | `ABCD_1234` |
| NextCloud (users) | `user1` – `user5` | `User@1234` |
| NPM (first login) | `admin@example.com` | `changeme` |

## Directory Structure

```
/opt/him-edu2/
├── setup.sh              <- main setup script
├── reset.sh              <- revert server to initial state
├── nextcloud-apps.sh     <- install NextCloud apps on running server
├── nextcloud-users.sh    <- create user1–user5 on running server
├── kolibri-channels.sh   <- download Kolibri channels from internet
├── kolibri-sync.sh       <- copy Kolibri content from master server
├── docs/                 <- this documentation
├── apps/
│   └── landing/www/      <- landing page (index.html, styles.css)
└── docker/nextcloud/
    ├── docker-compose.yml
    ├── config/           <- NextCloud config (auto-generated)
    ├── data/             <- NextCloud user files
    ├── html/             <- NextCloud app files
    ├── nextclouddb/      <- MariaDB data files
    ├── redis/            <- Redis data
    ├── npm-data/         <- Nginx Proxy Manager config
    └── letsencrypt/      <- SSL certificates

/opt/kolibri-venv/        <- Kolibri Python virtualenv
/opt/kolibri-data/        <- Kolibri database and content
```

## Re-running the Script

The script is **idempotent** — safe to run again on an existing server:
- Kolibri skipped if already installed in the venv
- NM AP connection deleted and re-created (picks up any config changes)
- NextCloud install skipped if already installed

To fully reset a server and start fresh, see the [reset guide](troubleshooting-reset.md).
