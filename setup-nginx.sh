#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Native Nginx Setup${NC}"
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
    echo -e "${RED}No domains set in .env (JELLYFIN_DOMAIN / QBIT_DOMAIN / FILEBROWSER_DOMAIN)${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[1/5] Installing Nginx and Certbot...${NC}"
apt-get update -qq
apt-get install -y nginx certbot python3-certbot-nginx > /dev/null 2>&1
echo -e "${GREEN}✓ Nginx and Certbot installed${NC}"

echo -e "\n${YELLOW}[2/5] Creating Nginx directories...${NC}"
mkdir -p /var/www/certbot
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/conf.d
echo -e "${GREEN}✓ Directories created${NC}"

echo -e "\n${YELLOW}[3/5] Configuring Nginx for ACME challenge...${NC}"
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

cat > /etc/nginx/sites-available/default-http <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/certbot;

    location /.well-known/acme-challenge/ {
    }
    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

ln -sf /etc/nginx/sites-available/default-http /etc/nginx/sites-enabled/default-http
nginx -t
systemctl restart nginx
echo -e "${GREEN}✓ Nginx configured for ACME${NC}"

echo -e "\n${YELLOW}[4/5] Issuing SSL certificates...${NC}"
DOMAINS=""
[ -n "$JELLYFIN_DOMAIN" ]    && DOMAINS="$DOMAINS $JELLYFIN_DOMAIN"
[ -n "$QBIT_DOMAIN" ]        && DOMAINS="$DOMAINS $QBIT_DOMAIN"
[ -n "$FILEBROWSER_DOMAIN" ] && DOMAINS="$DOMAINS $FILEBROWSER_DOMAIN"

CERT_DOMAIN=$(echo $DOMAINS | awk '{print $1}')
certbot certonly --webroot -w /var/www/certbot \
    $(for domain in $DOMAINS; do echo "-d $domain"; done) \
    --email "${SSL_EMAIL}" \
    --agree-tos \
    --expand \
    --non-interactive

echo -e "${GREEN}✓ Certificates issued${NC}"

echo -e "\n${YELLOW}[5/5] Writing Nginx virtual hosts...${NC}"

write_vhost() {
    local domain="$1"
    local upstream="$2"
    local extra="$3"
    local cert_domain="$4"
    local extra_headers="$5"

    cat > "/etc/nginx/sites-available/${domain}" <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$cert_domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$cert_domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
$extra_headers

$extra

    location / {
        proxy_pass $upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

    ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/${domain}"
    echo -e "${GREEN}  ✓ $domain${NC}"
}

# Create vhosts for each domain
# Jellyfin: no X-Frame-Options — Jellyfin's web UI uses iframes internally and
# setting SAMEORIGIN breaks the interface. All other services get it.
if [ -n "$JELLYFIN_DOMAIN" ]; then
    write_vhost "$JELLYFIN_DOMAIN" "http://localhost:${JELLYFIN_PORT}" "" "$CERT_DOMAIN" ""
fi

if [ -n "$QBIT_DOMAIN" ]; then
    write_vhost "$QBIT_DOMAIN" "http://localhost:${QBIT_PORT}" "
    proxy_cookie_path / \"/; Secure\";
    proxy_hide_header Referer;
    proxy_hide_header Origin;
    proxy_set_header Referer '';
    proxy_set_header Origin '';" "$CERT_DOMAIN" "
    add_header X-Frame-Options \"SAMEORIGIN\" always;"
fi

if [ -n "$FILEBROWSER_DOMAIN" ]; then
    write_vhost "$FILEBROWSER_DOMAIN" "http://localhost:${FILEBROWSER_PORT}" "
    client_max_body_size 0;" "$CERT_DOMAIN" "
    add_header X-Frame-Options \"SAMEORIGIN\" always;"
fi

nginx -t && systemctl reload nginx
echo -e "${GREEN}✓ Nginx reloaded — vhosts are live${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Nginx Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Your services are now available at:${NC}"
[ -n "$JELLYFIN_DOMAIN" ]    && echo -e "  Jellyfin    → https://${JELLYFIN_DOMAIN}"
[ -n "$QBIT_DOMAIN" ]        && echo -e "  qBittorrent → https://${QBIT_DOMAIN}"
[ -n "$FILEBROWSER_DOMAIN" ] && echo -e "  FileBrowser → https://${FILEBROWSER_DOMAIN}"
echo -e "\n${YELLOW}Automatic certificate renewal:${NC}"
echo -e "  Certbot runs daily via systemd timer.${NC}"
echo -e "  Check status: sudo systemctl status certbot.timer${NC}"
echo -e "\n${YELLOW}Nginx configuration:${NC}"
echo -e "  Main config: /etc/nginx/nginx.conf${NC}"
echo -e "  Sites: /etc/nginx/sites-available/${NC}"
echo -e "  Test config: sudo nginx -t${NC}"
echo -e "  Restart: sudo systemctl restart nginx${NC}"
echo -e "${GREEN}========================================${NC}"
