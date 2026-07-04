# XOXO Media Server Stack

Automated setup for **Jellyfin + qBittorrent + FileBrowser** with **native Nginx** and automatic SSL (Let's Encrypt).

---

## 🐳 Quick Start

1. **Clone the repository and enter directory:**
   ```bash
   git clone https://github.com/yashan223/media-server-stack.git
   cd media-server-stack
   ```

2. **Configure your environment:**
   ```bash
   cp .env.example .env
   nano .env
   ```

3. **Run setup:**
   ```bash
   sudo bash setup.sh
   ```

---

## 🔒 SSL Setup (Nginx Reverse Proxy)

1. Set your domains and email in `.env`.
2. Point your domain DNS (A records) to your server's IP.
3. Run the Nginx configuration script:
   ```bash
   sudo bash setup-nginx.sh
   ```

---

## 📂 Services & Ports

| Service | Default Port | Default Credentials |
| :--- | :---: | :--- |
| **Jellyfin** | `4096` | Configure in Web UI on first run |
| **qBittorrent** | `4080` | Set via `QBIT_WEBUI_USER` / `PASS` in `.env` |
| **FileBrowser** | `4085` | Set via `FILEBROWSER_USER` / `PASS` in `.env` |

---

## 🛠️ Management Commands

* **Start stack**: `docker compose up -d`
* **Stop stack**: `docker compose down`
* **Restart service**: `docker compose restart <service-name>`
* **View logs**: `docker compose logs -f`
* **Stop and clean up containers**: `sudo bash teardown.sh`
