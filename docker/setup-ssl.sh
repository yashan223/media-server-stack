#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  xoxo-media SSL Setup${NC}"
echo -e "${GREEN}========================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

set -a; source "${SCRIPT_DIR}/.env"; set +a

if [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}SSL_EMAIL is not set in .env${NC}"
    exit 1
fi

if [ -z "$JELLYFIN_DOMAIN" ] && [ -z "$QBIT_DOMAIN" ] && [ -z "$FILEBROWSER_DOMAIN" ]; then
    echo -e "${RED}No domains set in .env (JELLYFIN_DOMAIN, QBIT_DOMAIN, FILEBROWSER_DOMAIN)${NC}"
    exit 1
fi

NGINX_CONFD="${SCRIPT_DIR}/nginx-confd"
mkdir -p "${NGINX_CONFD}"

# ── Issue certs via Certbot (HTTP-01 challenge through nginx) ─────────────────
echo -e "\n${YELLOW}[1/3] Issuing SSL certificates...${NC}"

DOMAINS=""
[ -n "$JELLYFIN_DOMAIN" ]    && DOMAINS="$DOMAINS -d $JELLYFIN_DOMAIN"
[ -n "$QBIT_DOMAIN" ]        && DOMAINS="$DOMAINS -d $QBIT_DOMAIN"
[ -n "$FILEBROWSER_DOMAIN" ] && DOMAINS="$DOMAINS -d $FILEBROWSER_DOMAIN"

docker compose -f "${SCRIPT_DIR}/docker-compose.yml" --env-file "${SCRIPT_DIR}/.env" \
    run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    ${DOMAINS} \
    --email "${SSL_EMAIL}" \
    --agree-tos --non-interactive

echo -e "${GREEN}✓ Certificates issued${NC}"

# ── Write per-service nginx configs ──────────────────────────────────────────
echo -e "\n${YELLOW}[2/3] Writing Nginx virtual hosts...${NC}"

write_vhost() {
    local domain="$1"
    local upstream="$2"
    local extra="$3"
    cat > "${NGINX_CONFD}/${domain}.conf" <<EOF
server {
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate     /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

${extra}

    location / {
        proxy_pass         ${upstream};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_buffering    off;
    }
}
EOF
}

[ -n "$JELLYFIN_DOMAIN" ]    && write_vhost "$JELLYFIN_DOMAIN"    "http://jellyfin:8096"  ""
[ -n "$QBIT_DOMAIN" ]        && write_vhost "$QBIT_DOMAIN"        "http://qbittorrent:${QBIT_PORT}" \
    "    proxy_cookie_path / \"/; Secure\";"
[ -n "$FILEBROWSER_DOMAIN" ] && write_vhost "$FILEBROWSER_DOMAIN" "http://filebrowser:80" \
    "    client_max_body_size 0;"

echo -e "${GREEN}✓ Nginx virtual hosts written${NC}"

# ── Reload nginx ──────────────────────────────────────────────────────────────
echo -e "\n${YELLOW}[3/3] Reloading Nginx...${NC}"
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" --env-file "${SCRIPT_DIR}/.env" \
    exec nginx nginx -s reload

echo -e "${GREEN}✓ Nginx reloaded${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  SSL Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Your services are now available at:${NC}"
[ -n "$JELLYFIN_DOMAIN" ]    && echo -e "  Jellyfin    → https://${JELLYFIN_DOMAIN}"
[ -n "$QBIT_DOMAIN" ]        && echo -e "  qBittorrent → https://${QBIT_DOMAIN}"
[ -n "$FILEBROWSER_DOMAIN" ] && echo -e "  FileBrowser → https://${FILEBROWSER_DOMAIN}"
echo -e "\n${YELLOW}Certificates auto-renew every 12 hours via the certbot container.${NC}"
echo -e "\n${GREEN}========================================${NC}"
