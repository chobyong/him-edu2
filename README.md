# HimEdu Server Setup

Automated setup script for the HimEdu educational hotspot server.
Deploys Kolibri, NextCloud, a WiFi access point, and a captive portal
on a Raspberry Pi 5 (or any Debian-based server).

---

## Requirements

- Debian-based server (Raspberry Pi 5, PC, VM) — arm64 or x86_64
- Wired internet connection during setup
- WiFi adapter that supports AP mode (auto-detected — no config needed)

---

## Quick Start

On the new server, run:
```bash
sudo apt install curl
sudo apt install git
```
Install Tailscale 
```bash
 curl -fsSL https://tailscale.com/install.sh | sudo sh

tailscale up -ssh
```

Download from github to install rest

```bash
curl -O https://raw.githubusercontent.com/chobyong/him-edu2/main/setup.sh
sudo bash setup.sh
```

Setup takes 5–15 minutes depending on internet speed.

After setup, connect to the `him-edu` WiFi or open a browser to `http://<wired-ip>:8080` (Kolibri) or `http://<wired-ip>:8081` (NextCloud).

---

## Documentation

| Topic | Description |
|---|---|
| [Configuration](docs/configuration.md) | Variables to edit before running setup.sh |
| [Setup Steps](docs/setup-steps.md) | What each step of setup.sh does |
| [Services & Access](docs/services.md) | Ports, URLs, default logins, directory structure |
| [WiFi Access Point](docs/wifi-ap.md) | AP setup, captive portal, walled garden troubleshooting |
| [Kolibri](docs/kolibri.md) | Kolibri service, channel install, server sync, troubleshooting |
| [NextCloud](docs/nextcloud.md) | NextCloud Docker stack troubleshooting |
| [Docker](docs/docker.md) | Docker general troubleshooting |
| [Reset & Re-testing](docs/troubleshooting-reset.md) | Full and partial server resets |
