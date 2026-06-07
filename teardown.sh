#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  xoxo-media Teardown${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "\n${RED}WARNING: This will stop and remove all xoxo-media containers.${NC}"
echo -e "${YELLOW}Docker volumes (config, databases) are preserved by default.${NC}"
echo -e "${YELLOW}Nginx and SSL certificates are NOT affected.${NC}"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Teardown cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}[1/3] Stopping and removing Docker containers...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down
echo -e "${GREEN}✓ Containers removed${NC}"

read -p "Also delete all Docker volumes (config, databases)? THIS IS IRREVERSIBLE (yes/no): " REMOVE_VOLUMES

if [ "$REMOVE_VOLUMES" = "yes" ]; then
    echo -e "\n${YELLOW}[2/3] Removing Docker volumes...${NC}"
    docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down -v
    echo -e "${GREEN}✓ Volumes removed${NC}"
else
    echo -e "\n${YELLOW}[2/3] Volumes preserved.${NC}"
fi

echo -e "\n${YELLOW}[3/3] Nginx and SSL status:${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${YELLOW}Nginx is still running. To clean up Nginx setup, run:${NC}"
    echo -e "  sudo systemctl stop nginx"
    echo -e "  sudo rm -rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*"
    echo -e "  sudo systemctl restart nginx"
    echo -e "\n${YELLOW}To remove SSL certificates, run:${NC}"
    echo -e "  sudo certbot delete --cert-name DOMAIN_NAME"
else
    echo -e "${GREEN}✓ Nginx is not running${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Docker Teardown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Summary:${NC}"
echo -e "  • Docker containers: Stopped and removed"
echo -e "  • Docker volumes: $([ "$REMOVE_VOLUMES" = "yes" ] && echo 'Removed' || echo 'Preserved')"
echo -e "  • Nginx: Still running (manual cleanup available)"
echo -e "  • SSL certificates: Preserved at /etc/letsencrypt/live/"
echo -e "${GREEN}========================================${NC}"
