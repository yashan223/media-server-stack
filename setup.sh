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
    docker run --rm \
        -v "${MEDIA_DIR}/.filebrowser:/database" \
        filebrowser/filebrowser config init -d /database/filebrowser.db
    docker run --rm \
        -v "${MEDIA_DIR}/.filebrowser:/database" \
        filebrowser/filebrowser config set -d /database/filebrowser.db --address 0.0.0.0 --port 80 --root /srv
    docker run --rm \
        -v "${MEDIA_DIR}/.filebrowser:/database" \
        filebrowser/filebrowser users add admin adminadmin12 --perm.admin -d /database/filebrowser.db
    chown -R ${PUID}:${PGID} "${MEDIA_DIR}/.filebrowser"
    chmod -R 775 "${MEDIA_DIR}/.filebrowser"
    echo -e "${GREEN}✓ FileBrowser initialized (admin / adminadmin12)${NC}"
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
echo -e "  qBittorrent → http://${SERVER_IP}:${QBIT_PORT}  (admin / adminadmin)"
echo -e "  FileBrowser → http://${SERVER_IP}:${FILEBROWSER_PORT}  (admin / adminadmin12)"
echo -e "\n${YELLOW}To set up SSL with a domain name, run:${NC}"
echo -e "  sudo bash ${SCRIPT_DIR}/setup-nginx.sh"
echo -e "\n${YELLOW}Manage containers:${NC}"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml ps"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml logs -f"
echo -e "  docker compose -f ${SCRIPT_DIR}/docker-compose.yml restart"
echo -e "\n${GREEN}========================================${NC}"
