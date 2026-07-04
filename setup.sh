#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  xoxo-media Docker Setup${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[1/4] Checking Docker...${NC}"
if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

if ! docker compose version &>/dev/null; then
    echo -e "${YELLOW}Installing Docker Compose plugin...${NC}"
    apt-get install -y docker-compose-plugin
fi

echo -e "\n${YELLOW}[2/4] Loading configuration...${NC}"
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${RED}.env file not found in ${SCRIPT_DIR}${NC}"
    exit 1
fi
set -a; source "${SCRIPT_DIR}/.env"; set +a

export SCRIPT_DIR
if [ -f "${SCRIPT_DIR}/qbittorrent.conf" ]; then
    echo -e "${YELLOW}Configuring qBittorrent credentials...${NC}"
    if python3 -c '
import base64, hashlib, os, re

password = os.environ.get("QBIT_WEBUI_PASS")
username = os.environ.get("QBIT_WEBUI_USER")
script_dir = os.environ.get("SCRIPT_DIR")
config_path = os.path.join(script_dir, "qbittorrent.conf") if script_dir else "qbittorrent.conf"

if not password or not username or not os.path.exists(config_path):
    exit(1)

salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000)
qbit_hash = f"@ByteArray({base64.b64encode(salt).decode()}:{base64.b64encode(dk).decode()})"

with open(config_path, "r") as f:
    content = f.read()

content = re.sub(r"(WebUI\\Username=).*", r"\g<1>" + username, content)
content = re.sub(r"(WebUI\\Password_PBKDF2=).*", r"\g<1>" + "\"" + qbit_hash + "\"", content)

with open(config_path, "w") as f:
    f.write(content)
' 2>/dev/null; then
        echo -e "${GREEN}✓ qBittorrent credentials updated in config${NC}"
    else
        echo -e "${YELLOW}Could not update qBittorrent credentials. Defaulting to admin / adminadmin.${NC}"
    fi
fi

echo -e "\n${YELLOW}[3/5] Creating media directories...${NC}"
mkdir -p "${MEDIA_DIR}/downloads"
mkdir -p "${MEDIA_DIR}/movies"
mkdir -p "${MEDIA_DIR}/tv-shows"
mkdir -p "${MEDIA_DIR}/music"
mkdir -p "${MEDIA_DIR}/.filebrowser"
chown -R ${PUID}:${PGID} "${MEDIA_DIR}"
chmod -R 775 "${MEDIA_DIR}"
echo -e "${GREEN}✓ Directories created at ${MEDIA_DIR}${NC}"

echo -e "\n${YELLOW}[4/5] Initializing FileBrowser...${NC}"
if [ -d "${MEDIA_DIR}/.filebrowser/filebrowser.db" ]; then
    echo -e "${YELLOW}Removing invalid filebrowser.db directory...${NC}"
    rm -rf "${MEDIA_DIR}/.filebrowser/filebrowser.db"
fi

if [ ! -f "${MEDIA_DIR}/.filebrowser/filebrowser.db" ]; then
    if ! (
        docker run --rm \
            -v "${MEDIA_DIR}/.filebrowser:/database" \
            filebrowser/filebrowser config init -d /database/filebrowser.db && \
        docker run --rm \
            -v "${MEDIA_DIR}/.filebrowser:/database" \
            filebrowser/filebrowser config set -d /database/filebrowser.db --address 0.0.0.0 --port 80 --root /srv --minimumPasswordLength 6 && \
        docker run --rm \
            -v "${MEDIA_DIR}/.filebrowser:/database" \
            filebrowser/filebrowser users add "${FILEBROWSER_USER}" "${FILEBROWSER_PASS}" --perm.admin -d /database/filebrowser.db
    ); then
        echo -e "${RED}FileBrowser initialization failed. Cleaning up database...${NC}"
        rm -f "${MEDIA_DIR}/.filebrowser/filebrowser.db"
        exit 1
    fi
    chown -R ${PUID}:${PGID} "${MEDIA_DIR}/.filebrowser"
    chmod -R 775 "${MEDIA_DIR}/.filebrowser"
    echo -e "${GREEN}✓ FileBrowser initialized (${FILEBROWSER_USER} / ${FILEBROWSER_PASS})${NC}"
else
    echo -e "${GREEN}✓ FileBrowser database already exists${NC}"
fi

echo -e "\n${YELLOW}[5/5] Starting containers...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" --env-file "${SCRIPT_DIR}/.env" up -d

SERVER_IP=$(hostname -I | awk '{print $1}')

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Stack is up!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Services:${NC}"
echo -e "  Jellyfin    → http://${SERVER_IP}:${JELLYFIN_PORT}"
echo -e "  qBittorrent → http://${SERVER_IP}:${QBIT_PORT}  (${QBIT_WEBUI_USER} / ${QBIT_WEBUI_PASS})"
echo -e "  FileBrowser → http://${SERVER_IP}:${FILEBROWSER_PORT}  (${FILEBROWSER_USER} / ${FILEBROWSER_PASS})"
echo -e "\n${YELLOW}To set up SSL with a domain name, run:${NC}"
echo -e "  sudo bash ${SCRIPT_DIR}/setup-nginx.sh"
echo -e "\n${YELLOW}Manage containers:${NC}"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml ps"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml logs -f"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml restart"
echo -e "\n${GREEN}========================================${NC}"
