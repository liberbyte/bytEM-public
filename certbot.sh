#!/bin/bash

set -euo pipefail

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

header_message() {
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}==========================================${NC}"
}

# Source the .env.bytem file
set +u
source .env.bytem
set -u

# Extract domain variables
BYTEM_DOMAIN=$(grep "^EXCHANGE_SERVER_HOSTNAME=" .env.bytem | cut -d'=' -f2)
MATRIX_DOMAIN=$(grep "^MATRIX_SERVER_NAME=" .env.bytem | cut -d'=' -f2)

# Variables
SYNAPSE_CONTAINER_NAME="bytem-synapse"
ADMIN_USERNAME=${PANTALAIMON_USERNAME}
ADMIN_PASSWORD=${PANTALAIMON_PASSWORD}
MATRIX_URL="http://bytem-synapse:8008"
RESTART_CONTAINER="bytem-be bytem-bot"

header_message "SSL Certificate Generation for bytEM"
echo -e "${CYAN}BYTEM Domain: ${BYTEM_DOMAIN}${NC}"
echo -e "${CYAN}Matrix Domain: ${MATRIX_DOMAIN}${NC}"

# Prompt for email
read -p "Enter your email for Certificate notifications: " EMAIL

header_message "Generating SSL Certificates using Docker certbot"

# Clean up any corrupted certificates first
echo -e "${YELLOW}Cleaning up any existing corrupted certificates...${NC}"
sudo rm -rf "./certbot/conf/live/${BYTEM_DOMAIN}"*
sudo rm -rf "./certbot/conf/renewal/${BYTEM_DOMAIN}.conf"

# Generate SSL Certificates using Docker certbot
echo -e "${YELLOW}Generating SSL certificates...${NC}"
if sudo docker run --rm \
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
    -d "$MATRIX_DOMAIN"; then
    
    echo -e "${GREEN}SSL certificates generated successfully.${NC}"
    
    # Determine certificate path
    if [ -d "./certbot/conf/live/${BYTEM_DOMAIN}" ]; then
        CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
    elif [ -d "./certbot/conf/live/${BYTEM_DOMAIN}-0001" ]; then
        CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001"
    else
        echo -e "${RED}Certificate directory not found${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Using certificate path: ${CERT_PATH}${NC}"
    
    # Update nginx configs with SSL
    header_message "Adding SSL configuration to nginx"
    
    # Add HTTPS redirect to HTTP section and SSL server block
    cat >> generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf << EOF

# SSL Configuration
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name ${BYTEM_DOMAIN};

    ssl_certificate ${CERT_PATH}/fullchain.pem;
    ssl_certificate_key ${CERT_PATH}/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    error_log /var/log/nginx/${BYTEM_DOMAIN}.log notice;
    
    underscores_in_headers on;

    # Gzip Compression for performance
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
    gzip_vary on;
    gzip_min_length 1024;

    location / {
        root /usr/share/nginx/html;
        try_files \$uri \$uri/ /index.html;
    }

    location /hub {
        proxy_pass http://bytem-be:3000/hub;
        proxy_buffering on;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host ${BYTEM_DOMAIN};
        proxy_set_header X-Custom-Header "matrix_server";
        proxy_pass_request_headers on;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /hub/authorize {
        proxy_pass http://bytem-be:3000/hub/authorize;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host ${BYTEM_DOMAIN};
        proxy_set_header X-Custom-Header "matrix_server";
        proxy_pass_request_headers on;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /solr/ {
        proxy_pass http://bytem-solr:8983/solr/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /hub/socket/ {
        proxy_pass http://bytem-be:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Update HTTP section to redirect to HTTPS
    sed -i 's|root /usr/share/nginx/html;.*try_files.*|return 301 https://\$server_name\$request_uri;|' generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf
    
    # Generate matrix nginx config  
    sed -e "s/\${DOMAIN}/$DOMAIN_NAME/g" \
        -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
        -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
        -e "s/\${BOT_USER}/$BOT_USER_ID/g" \
        -e "s/\${RABBITMQ_USERNAME}/$RABBITMQ_USERNAME/g" \
        -e "s/\${RABBITMQ_PASSWORD}/$RABBITMQ_PASSWORD/g" \
        -e "s/\${SYNAPSE_POSTGRES_PASSWORD}/$SYNAPSE_POSTGRES_PASSWORD/g" \
        -e "s/\${MATRIX_SSO_CLIENT_ID}/$MATRIX_SSO_CLIENT_ID/g" \
        -e "s/\${MATRIX_SSO_CLIENT_SECRET}/$MATRIX_SSO_CLIENT_SECRET/g" \
        -e "s|\${CERT_PATH}|$CERT_PATH|g" \
        config_templates/nginx_config_templates/matrix.bytem.template > \
        generated_config_files/nginx_config/matrix.${BYTEM_DOMAIN}.conf
    
    echo -e "${GREEN}Nginx configurations regenerated with SSL${NC}"

    # Reload nginx
    echo -e "${YELLOW}Reloading nginx...${NC}"
    if sudo docker exec bytem-app nginx -s reload; then
        echo -e "${GREEN}nginx reload successful.${NC}"
    else
        echo -e "${RED}Failed to reload nginx.${NC}"
        exit 2
    fi
else
    echo -e "${RED}SSL certificate generation failed.${NC}"
    exit 1
fi

# Generate Token
header_message "Generating Login Token"

echo -e "${GREEN}Generating token by logging in...${NC}" 
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

echo -e "${GREEN}Token generated successfully${NC}"

# Replace token in .env.bytem
sed -i "s/\${TOKEN}/$TOKEN/g" .env.bytem

# Override Ratelimit
header_message "Configuring Rate Limits"

RESPONSE=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -X POST \
    "http://bytem-synapse:8008/_synapse/admin/v1/users/@${ADMIN_USERNAME}:${MATRIX_DOMAIN}/override_ratelimit" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"messages_per_second": 0, "burst_count": 0}')

# Restart containers
header_message "Restarting Containers"
sudo docker restart ${RESTART_CONTAINER}

header_message "SSL Setup Complete!"
echo -e "${GREEN}✅ bytEM is now configured with SSL certificates${NC}"
echo -e "${CYAN}Access your bytEM at: https://${BYTEM_DOMAIN}${NC}"
