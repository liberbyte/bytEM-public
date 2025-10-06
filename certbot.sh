#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment
source .env.bytem

BYTEM_DOMAIN=${EXCHANGE_SERVER_HOSTNAME}
MATRIX_DOMAIN=${MATRIX_SERVER_NAME}
EMAIL="admin@liberbyte.app"

echo -e "${CYAN}BytEM SSL Setup${NC}"
echo -e "${CYAN}BYTEM: ${BYTEM_DOMAIN}${NC}"
echo -e "${CYAN}Matrix: ${MATRIX_DOMAIN}${NC}"

# Create directories
mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
mkdir -p "./certbot/www/.well-known/acme-challenge"

# Check if local development
if [[ "$BYTEM_DOMAIN" == *"localhost"* ]] || [[ "$BYTEM_DOMAIN" == *".local"* ]]; then
    echo -e "${YELLOW}Local development - self-signed certificates${NC}"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
        -out "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=BytEM/CN=${BYTEM_DOMAIN}" 2>/dev/null
    
    CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
else
    echo -e "${YELLOW}Production - Let's Encrypt certificates${NC}"
    
    docker run --rm \
        -v "${PWD}/certbot/conf:/etc/letsencrypt" \
        -v "${PWD}/certbot/www:/var/www/certbot" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --expand \
        -d "$BYTEM_DOMAIN" \
        -d "$MATRIX_DOMAIN" 2>/dev/null || echo "Certificate already exists or failed"
    
    # Dynamically find the correct certificate directory
    if [ -d "./certbot/conf/live/${BYTEM_DOMAIN}-0001" ]; then
        CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001"
    elif [ -d "./certbot/conf/live/${BYTEM_DOMAIN}" ]; then
        CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
    else
        echo -e "${RED}No certificate directory found${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}Using certificate path: ${CERT_PATH}${NC}"

# Generate nginx configs with dynamic certificate path
sed -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
    -e "s|\${CERT_PATH}|$CERT_PATH|g" \
    config_templates/nginx_config_templates/bytem.template > \
    generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf

sed -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
    -e "s|\${CERT_PATH}|$CERT_PATH|g" \
    config_templates/nginx_config_templates/matrix.bytem.template > \
    generated_config_files/nginx_config/matrix.${MATRIX_DOMAIN}.conf

# Clean up and reload
docker exec bytem-app rm -f /etc/nginx/conf.d/matrix.bytem.bm1.liberbyte.app.conf 2>/dev/null
docker exec bytem-app nginx -t && docker exec bytem-app nginx -s reload

echo -e "${GREEN}✅ SSL Setup Complete${NC}"
echo -e "${CYAN}Certificate Path: ${CERT_PATH}${NC}"
echo -e "${CYAN}BYTEM: https://${BYTEM_DOMAIN}${NC}"
echo -e "${CYAN}Matrix: https://${MATRIX_DOMAIN}${NC}"
