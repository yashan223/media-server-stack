#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

JELLYFIN_PORT=4096
QBIT_PORT=4080
FILEBROWSER_PORT=4085

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Nginx Reverse Proxy + SSL Setup${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Enter your domain names (leave blank to skip):${NC}"
read -p "Jellyfin domain (e.g., jellyfin.example.com): " JELLYFIN_DOMAIN
read -p "qBittorrent domain (e.g., qbit.example.com): " QBIT_DOMAIN
read -p "FileBrowser domain (e.g., files.example.com): " FILEBROWSER_DOMAIN
read -p "Email for SSL certificates: " SSL_EMAIL

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Email is required!${NC}"
    exit 1
fi

if [ -z "$JELLYFIN_DOMAIN" ] && [ -z "$QBIT_DOMAIN" ] && [ -z "$FILEBROWSER_DOMAIN" ]; then
    echo -e "${RED}At least one domain is required!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Configuration:${NC}"
[ -n "$JELLYFIN_DOMAIN" ] && echo -e "  Jellyfin: https://${JELLYFIN_DOMAIN}"
[ -n "$QBIT_DOMAIN" ] && echo -e "  qBittorrent: https://${QBIT_DOMAIN}"
[ -n "$FILEBROWSER_DOMAIN" ] && echo -e "  FileBrowser: https://${FILEBROWSER_DOMAIN}"
echo -e "  SSL Email: ${SSL_EMAIL}"
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

echo -e "\n${YELLOW}[1/4] Installing Nginx and Certbot...${NC}"
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

echo -e "${GREEN}✓ Nginx and Certbot installed${NC}"

if [ -n "$JELLYFIN_DOMAIN" ]; then
echo -e "\n${YELLOW}[2/5] Configuring Nginx for Jellyfin...${NC}"
cat > /etc/nginx/sites-available/jellyfin <<EOF
server {
    listen 80;
    server_name ${JELLYFIN_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${JELLYFIN_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Protocol \$scheme;
        proxy_set_header X-Forwarded-Host \$http_host;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_buffering off;
    }
}
EOF
ln -sf /etc/nginx/sites-available/jellyfin /etc/nginx/sites-enabled/
echo -e "${GREEN}✓ Jellyfin configured${NC}"
fi

if [ -n "$QBIT_DOMAIN" ]; then
echo -e "\n${YELLOW}[3/5] Configuring Nginx for qBittorrent...${NC}"
cat > /etc/nginx/sites-available/qbittorrent <<EOF
server {
    listen 80;
    server_name ${QBIT_DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${QBIT_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_cookie_path / "/; Secure";
    }
}
EOF
ln -sf /etc/nginx/sites-available/qbittorrent /etc/nginx/sites-enabled/
echo -e "${GREEN}✓ qBittorrent configured${NC}"
fi

if [ -n "$FILEBROWSER_DOMAIN" ]; then
echo -e "\n${YELLOW}[4/5] Configuring Nginx for FileBrowser...${NC}"
cat > /etc/nginx/sites-available/filebrowser <<EOF
server {
    listen 80;
    server_name ${FILEBROWSER_DOMAIN};

    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:${FILEBROWSER_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
ln -sf /etc/nginx/sites-available/filebrowser /etc/nginx/sites-enabled/
echo -e "${GREEN}✓ FileBrowser configured${NC}"
fi

nginx -t

systemctl restart nginx

echo -e "${GREEN}✓ Nginx configured${NC}"

DOMAINS=""
[ -n "$JELLYFIN_DOMAIN" ] && DOMAINS="$DOMAINS -d $JELLYFIN_DOMAIN"
[ -n "$QBIT_DOMAIN" ] && DOMAINS="$DOMAINS -d $QBIT_DOMAIN"
[ -n "$FILEBROWSER_DOMAIN" ] && DOMAINS="$DOMAINS -d $FILEBROWSER_DOMAIN"

echo -e "\n${YELLOW}[5/5] Setting up SSL certificates...${NC}"
certbot --nginx $DOMAINS --non-interactive --agree-tos --expand -m ${SSL_EMAIL}

systemctl enable certbot.timer
systemctl start certbot.timer

echo -e "${GREEN}✓ SSL certificates installed${NC}"

if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "\n${YELLOW}Configuring firewall...${NC}"
    ufw allow 'Nginx Full'
    echo -e "${GREEN}✓ Firewall configured${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Your services are now available at:${NC}"
[ -n "$JELLYFIN_DOMAIN" ] && echo -e "  Jellyfin: https://${JELLYFIN_DOMAIN}"
[ -n "$QBIT_DOMAIN" ] && echo -e "  qBittorrent: https://${QBIT_DOMAIN}"
[ -n "$FILEBROWSER_DOMAIN" ] && echo -e "  FileBrowser: https://${FILEBROWSER_DOMAIN}"
echo -e "\n${YELLOW}SSL certificates will auto-renew.${NC}"
echo -e "\n${YELLOW}Nginx Commands:${NC}"
echo -e "  systemctl status nginx"
echo -e "  systemctl restart nginx"
echo -e "  nginx -t  (test config)"
echo -e "\n${GREEN}========================================${NC}"
