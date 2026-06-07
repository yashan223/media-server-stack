# XOXO Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** with **native Nginx** on Ubuntu VPS.
- Docker containers for media services
- Native Nginx with automatic SSL certificates (Let's Encrypt)

---

## 🐳 Quick Start

> One command starts the entire stack. No manual port configuration. Services run in Docker, Nginx runs natively with SSL support.

```bash
git clone https://github.com/yashan223/xoxo-media.git
cd xoxo-media

# Edit ports, paths, user IDs
nano .env

# Start the stack
sudo bash setup.sh
```

### SSL Setup (Native Nginx)

```bash
# Fill JELLYFIN_DOMAIN, QBIT_DOMAIN, FILEBROWSER_DOMAIN, SSL_EMAIL in .env first
# This installs Nginx natively and configures SSL without Docker
sudo bash setup-nginx.sh
```

### Stop / Remove (Docker)

```bash
sudo bash teardown.sh
```

### Docker Commands

```bash
# View running containers
docker compose ps

# Live logs
docker compose logs -f

# Restart a service
docker compose restart jellyfin

# Pull latest images
docker compose pull && docker compose up -d
```

---

## Services

| Service | Port | Default Credentials |
|---------|:----:|---------------------|
| Jellyfin | 4096 | Setup wizard |
| qBittorrent | 4080 | admin / adminadmin |
| FileBrowser | 4085 | admin / admin |

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

## Requirements

- Ubuntu 20.04+ / Debian 11+
- Root access
- Ports open: 4096, 4080, 4085, 80, 443 (for SSL)
