#!/bin/bash
set -euo pipefail

# ================= Colors =================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BRIGHT_GREEN='\033[1;32m'
CYAN='\033[0;36m'
NC='\033[0m'

header_message() {
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}==========================================${NC}"
}

# ================= Load environment =================
set +u
source .env.bytem
set -u

BYTEM_DOMAIN=${EXCHANGE_SERVER_HOSTNAME}
MATRIX_DOMAIN=${MATRIX_APP}
DOMAIN_NAME=${DOMAIN_NAME}
CONFIG_DIR="generated_config_files/"
SYNAPSE_CONTAINER_NAME="bytem-synapse"
ADMIN_USERNAME=${PANTALAIMON_USERNAME}
ADMIN_PASSWORD=${PANTALAIMON_USERNAME}
MATRIX_URL="http://bytem-synapse:8008"
RESTART_CONTAINER="bytem-be bytem-bot bytem-app"

# ================= Prompt email =================
header_message "Enter the information needed to generate SSL certificate"
EMAIL=${EMAIL:-$(read -p "Enter your email for Certificate Notifications: " REPLY && echo "$REPLY")}

# ================= Validate domain =================
if [[ "$DOMAIN_NAME" =~ ^www\..* ]]; then
  echo -e "${RED}ERROR: Domain should not start with 'www.'${NC}"
  exit 1
elif [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
  echo -e "${RED}ERROR: Invalid domain name format${NC}"
  exit 1
fi

# ================= Nginx config check =================
NGINX_BYTEM_CONF="/etc/nginx/conf.d/bytem.${BYTEM_DOMAIN}.conf"
NGINX_MATRIX_CONF="$CONFIG_DIR/nginx_config/matrix.${BYTEM_DOMAIN}.conf"

if [ ! -f "$NGINX_MATRIX_CONF" ]; then
  echo -e "${RED}ERROR: Matrix nginx config not found: $NGINX_MATRIX_CONF${NC}"
  exit 1
fi

# ================= Fix Nginx for ACME =================
header_message "Preparing nginx configuration for SSL..."

# Create temporary certificates if they don't exist
if [ ! -f "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" ]; then
    echo -e "${YELLOW}Creating temporary certificates for nginx...${NC}"
    sudo mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
    sudo openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
        -keyout "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
        -out "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${BYTEM_DOMAIN}" > /dev/null 2>&1
fi

# Reload nginx to ensure config is loaded
sudo docker exec bytem-app nginx -s reload

# ================= Generate SSL =================
header_message "Generating SSL Certificates..."
if certbot certonly --webroot -w ./certbot/www --agree-tos -n -m "$EMAIL" -d "$BYTEM_DOMAIN" -d "$MATRIX_DOMAIN"; then
    echo -e "${GREEN}SSL certificates generated successfully${NC}"
    
    # Copy certificates from system location to docker volume
    if [ -d "/etc/letsencrypt/live/${BYTEM_DOMAIN}" ]; then
        sudo cp "/etc/letsencrypt/live/${BYTEM_DOMAIN}/fullchain.pem" "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem"
        sudo cp "/etc/letsencrypt/live/${BYTEM_DOMAIN}/privkey.pem" "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem"
    elif [ -d "/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001" ]; then
        sudo cp "/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001/fullchain.pem" "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem"
        sudo cp "/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001/privkey.pem" "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem"
    fi

    # Wait for nginx to start
    sleep 5
    
    # Reload Nginx
    sudo docker exec bytem-app nginx -s reload
else
    echo -e "${RED}SSL certificate generation failed${NC}"
    echo -e "${YELLOW}Generating self-signed certificates as fallback...${NC}"
    
    # Create certificate directory
    sudo mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
    
    # Generate self-signed certificates
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
        -out "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${BYTEM_DOMAIN}"
    
    echo -e "${YELLOW}Self-signed certificates created${NC}"
    exit 1
fi

# ================= Generate Token =================
header_message "Generating Login Token..."
RESPONSE=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl --location 'http://bytem-be:3000/authorize' \
    --header "matrix_server: ${MATRIX_URL}" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "password": "'${ADMIN_PASSWORD}'",
        "username": "'${ADMIN_USERNAME}'"
    }')

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [[ -z "$TOKEN" ]]; then
    echo -e "${RED}Error: Token could not be generated. Response: $RESPONSE${NC}"
    exit 1
fi

echo "Replacing token in .env.bytem..."
sed -i "s/\${TOKEN}/$TOKEN/g" .env.bytem

# ================= Override Rate Limit =================
header_message "Overriding Rate Limit..."
sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -X POST \
    "http://bytem-synapse:8008/_synapse/admin/v1/users/@${ADMIN_USERNAME}:$MATRIX_DOMAIN/override_ratelimit" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"messages_per_second": 0, "burst_count": 0}'

# ================= Fix frontend =================
header_message "Fixing frontend configuration for HTTPS"
docker exec bytem-app sed -i "s|http://localhost:3000|https://${BYTEM_DOMAIN}|g" /usr/share/nginx/html/umi.js 2>/dev/null || true
docker exec bytem-app sed -i "s|matrix\.bytem0\.liberbyte\.app|${MATRIX_DOMAIN}|g" /usr/share/nginx/html/umi.js 2>/dev/null || true

# ================= Restart containers =================
header_message "Restarting containers..."
sudo docker restart ${RESTART_CONTAINER}

header_message "SSL & configuration setup completed successfully!"

