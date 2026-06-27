# XOXO Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** with **native Nginx** on Ubuntu VPS.
- Docker containers for media services
- Native Nginx with automatic SSL certificates (Let's Encrypt)

---

## 🐳 Quick Start

> One command starts the entire stack. No manual port configuration. Services run in Docker, Nginx runs natively with SSL support.

```bash
git clone https://github.com/yashan223/media-server-stack.git
cd media-server-stack

# Copy the example config and fill in your values
cp .env.example .env
nano .env

# Start Docker containers
sudo bash setup.sh
```

### SSL Setup (Native Nginx)

```bash
# 1. Set domains and email in .env:
# JELLYFIN_DOMAIN=jellyfin.example.com
# QBIT_DOMAIN=qbit.example.com
# FILEBROWSER_DOMAIN=files.example.com
# SSL_EMAIL=your-email@example.com

# 2. Point your domains to your VPS IP (DNS A records)

# 3. Run the Nginx setup (installs Nginx natively + configures SSL)
sudo bash setup-nginx.sh
```

**What this does:**
- Installs Nginx and Certbot on the host
- Issues SSL certificates from Let's Encrypt
- Creates virtual host configs for each domain
- Reloads Nginx so vhosts are immediately live
- Sets up automatic certificate renewal via systemd timer
- Proxies requests to Docker containers

### Stop / Remove

```bash
# Stop and remove only Docker containers (Nginx/SSL unaffected)
sudo bash teardown.sh
```

**Teardown options:**
- Removes Docker containers
- Optionally remove Docker volumes
- Preserves Nginx and SSL certificates (requires manual cleanup if needed)

---

## Configuration (.env)

Copy `.env.example` to `.env` and edit the values. The `.env` file is **gitignored** and never committed — keep your credentials safe.

```bash
# User & Permissions
PUID=1000
PGID=1000
TZ=UTC

# Media Directory (host path)
MEDIA_DIR=/var/media/jellyfin

# Service Ports (host-side)
JELLYFIN_PORT=4096
QBIT_PORT=4080
FILEBROWSER_PORT=4085

# qBittorrent WebUI credentials
QBIT_WEBUI_USER=admin
QBIT_WEBUI_PASS=changeme

# FileBrowser credentials
FILEBROWSER_USER=admin
FILEBROWSER_PASS=changeme

# Optional: Domains for SSL (leave empty to skip SSL setup)
JELLYFIN_DOMAIN=jellyfin.example.com
QBIT_DOMAIN=qbit.example.com
FILEBROWSER_DOMAIN=files.example.com
SSL_EMAIL=your-email@example.com
```

> **Note:** Jellyfin uses its own first-run setup wizard for credentials.

---

## Services

| Service | Default Port | Credentials |
|---------|:------------:|-------------|
| Jellyfin | 4096 | First-run setup wizard |
| qBittorrent | 4080 | Set via `QBIT_WEBUI_USER` / `QBIT_WEBUI_PASS` in `.env` |
| FileBrowser | 4085 | Set via `FILEBROWSER_USER` / `FILEBROWSER_PASS` in `.env` |

---

## Directory Structure

```
/var/media/jellyfin/
├── downloads/
├── movies/
├── tv-shows/
└── music/
```

---

## Docker Management

```bash
# View running containers
docker compose -f docker-compose.yml ps

# Live logs
docker compose -f docker-compose.yml logs -f

# Restart a service
docker compose -f docker-compose.yml restart jellyfin

# Pull latest images and restart
docker compose -f docker-compose.yml pull && docker compose -f docker-compose.yml up -d
```

### Nginx Management

```bash
# Check Nginx status
sudo systemctl status nginx

# Test Nginx config
sudo nginx -t

# Reload Nginx (after config changes)
sudo systemctl reload nginx

# View virtual hosts
ls -la /etc/nginx/sites-available/

# View certificate renewal status
sudo systemctl status certbot.timer
sudo certbot certificates
```

---

## Requirements

- Ubuntu 20.04+ / Debian 11+
- Root access
- Ports open: `4096`, `4080`, `4085`, `80`, `443` (for SSL)
- Domain name(s) with DNS A records pointing to your VPS IP (for SSL setup)

---

## Troubleshooting

**Nginx won't start:**
```bash
sudo nginx -t
sudo systemctl status nginx
sudo journalctl -u nginx -n 50
```

**Certificate renewal issues:**
```bash
sudo certbot renew --dry-run
sudo systemctl restart certbot.timer
```

**Port conflicts:**
```bash
sudo lsof -i :80
sudo lsof -i :443
```

**qBittorrent WebUI not accessible:**
```bash
# Check the container is running
docker compose -f docker-compose.yml ps
# Check logs
docker compose -f docker-compose.yml logs qbittorrent
```

---

## File Structure

```
media-server-stack/
├── docker-compose.yml      # Docker services config
├── qbittorrent.conf        # qBittorrent WebUI config
├── setup.sh                # Initial setup script
├── setup-nginx.sh          # Nginx + SSL setup script
├── teardown.sh             # Cleanup script
├── .env.example            # Config template (copy to .env)
└── README.md               # This file
```
