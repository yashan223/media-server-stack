# XOXO Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** on Ubuntu VPS.

---

## Installation

```bash
git clone https://github.com/yashan223/xoxo-media.git
cd xoxo-media
sudo bash install.sh
```

## SSL Setup (Optional)

```bash
sudo bash setup-nginx.sh
```

## Uninstall

```bash
sudo bash uninstall.sh
```

---

## Services

| Service | Port | Default Credentials |
|---------|:----:|---------------------|
| Jellyfin | 4096 | Setup wizard |
| qBittorrent | 4080 | admin / adminadmin |
| FileBrowser | 4085 | admin / adminadmin12 |

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

## Commands

```bash
# Status
systemctl status jellyfin qbittorrent-nox filebrowser

# Restart
sudo systemctl restart jellyfin
sudo systemctl restart qbittorrent-nox
sudo systemctl restart filebrowser

# Logs
journalctl -u jellyfin -f
```

---

## Requirements

- Ubuntu 20.04+
- Root access
- Ports: 4096, 4080, 4085
