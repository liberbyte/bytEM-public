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

# Email handling with user prompt if not set
if [ -z "${SSL_EMAIL}" ]; then
    echo -e "${YELLOW}SSL_EMAIL not set in .env.bytem${NC}"
    read -p "Enter your email for SSL certificate registration: " SSL_EMAIL
    if [ -z "${SSL_EMAIL}" ]; then
        EMAIL="admin@${DOMAIN_NAME:-example.com}"
        echo -e "${YELLOW}Using default email: ${EMAIL}${NC}"
    else
        EMAIL="${SSL_EMAIL}"
        # Add email to .env.bytem for future use
        echo "SSL_EMAIL=${SSL_EMAIL}" >> .env.bytem
        echo -e "${GREEN}Email saved to .env.bytem${NC}"
    fi
else
    EMAIL="${SSL_EMAIL}"
fi

echo -e "${CYAN}BytEM SSL Setup${NC}"
echo -e "${CYAN}BYTEM: ${BYTEM_DOMAIN}${NC}"
echo -e "${CYAN}Matrix: ${MATRIX_DOMAIN}${NC}"
echo -e "${CYAN}Email: ${EMAIL}${NC}"

# Create directories
mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
mkdir -p "./certbot/conf/live/${MATRIX_DOMAIN}"
mkdir -p "./certbot/www/.well-known/acme-challenge"

# Check if local development or production
if [[ "$BYTEM_DOMAIN" == *"localhost"* ]] || [[ "$BYTEM_DOMAIN" == *".local"* ]]; then
    echo -e "${YELLOW}Development mode - using self-signed certificates${NC}"
    
    # Generate self-signed certificates for BYTEM domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
        -out "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=BytEM/CN=${BYTEM_DOMAIN}" 2>/dev/null
    
    # Generate self-signed certificates for Matrix domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "./certbot/conf/live/${MATRIX_DOMAIN}/privkey.pem" \
        -out "./certbot/conf/live/${MATRIX_DOMAIN}/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=BytEM/CN=${MATRIX_DOMAIN}" 2>/dev/null
    
    CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
    MATRIX_CERT_PATH="/etc/letsencrypt/live/${MATRIX_DOMAIN}"
else
    echo -e "${YELLOW}Production - Let's Encrypt certificates${NC}"
    
    # Ensure webroot is accessible
    chmod -R 755 "./certbot/www"
    
    # Check if certificates already exist and are valid
    SKIP_RENEWAL=false
    if [ -f "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" ] && [ -f "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" ]; then
        echo -e "${YELLOW}Existing certificates found, checking validity...${NC}"
        
        # Check certificate expiry date
        CERT_FILE="./certbot/conf/live/${BYTEM_DOMAIN}/cert.pem"
        if [ ! -f "$CERT_FILE" ]; then
            CERT_FILE="./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem"
        fi
        
        if [ -f "$CERT_FILE" ]; then
            EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
            if [ -n "$EXPIRY_DATE" ]; then
                EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
                CURRENT_EPOCH=$(date +%s)
                DAYS_REMAINING=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
                
                echo -e "${CYAN}Certificate expires: $EXPIRY_DATE${NC}"
                echo -e "${CYAN}Days remaining: $DAYS_REMAINING${NC}"
                
                if [ "$DAYS_REMAINING" -gt 30 ]; then
                    echo -e "${GREEN}Certificate has $DAYS_REMAINING days remaining (>30), skipping renewal${NC}"
                    SKIP_RENEWAL=true
                    CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
                    MATRIX_CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
                else
                    echo -e "${YELLOW}Certificate expires in $DAYS_REMAINING days (≤30), renewal needed${NC}"
                fi
            else
                echo -e "${YELLOW}Could not read certificate expiry, proceeding with renewal${NC}"
            fi
        else
            echo -e "${YELLOW}Certificate file not found, proceeding with renewal${NC}"
        fi
        
        # Clean up if renewal is needed
        if [ "$SKIP_RENEWAL" = false ]; then
            echo -e "${YELLOW}Cleaning up existing certificates for renewal...${NC}"
            rm -rf "./certbot/conf/live/${BYTEM_DOMAIN}"
            rm -rf "./certbot/conf/archive/${BYTEM_DOMAIN}"
            rm -f "./certbot/conf/renewal/${BYTEM_DOMAIN}.conf"
            mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
        fi
    fi
    
    # Generate new certificates if needed
    if [ "$SKIP_RENEWAL" = false ] && [ ! -f "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" ]; then
        echo -e "${YELLOW}Attempting Let's Encrypt certificate for ${BYTEM_DOMAIN} and ${MATRIX_DOMAIN}${NC}"
        
        if docker run --rm \
            -v "${PWD}/certbot/conf:/etc/letsencrypt" \
            -v "${PWD}/certbot/www:/var/www/certbot" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            --expand \
            -d "$BYTEM_DOMAIN" \
            -d "$MATRIX_DOMAIN"; then
            
            echo -e "${GREEN}Let's Encrypt certificates obtained successfully${NC}"
            
            # Dynamically find the correct certificate directory
            if [ -d "./certbot/conf/live/${BYTEM_DOMAIN}-0001" ]; then
                CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001"
                MATRIX_CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}-0001"
            elif [ -d "./certbot/conf/live/${BYTEM_DOMAIN}" ]; then
                CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
                MATRIX_CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
            else
                echo -e "${RED}No certificate directory found${NC}"
                exit 1
            fi
            
            # Verify certificates exist locally
            if [ ! -f "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" ] && [ ! -f "./certbot/conf/live/${BYTEM_DOMAIN}-0001/fullchain.pem" ]; then
                echo -e "${RED}Certificate files not found after successful generation${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Let's Encrypt failed, falling back to self-signed certificates${NC}"
            
            # Generate self-signed certificates for BYTEM domain
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "./certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
                -out "./certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
                -subj "/C=US/ST=State/L=City/O=BytEM/CN=${BYTEM_DOMAIN}" 2>/dev/null
            
            # Generate self-signed certificates for Matrix domain
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "./certbot/conf/live/${MATRIX_DOMAIN}/privkey.pem" \
                -out "./certbot/conf/live/${MATRIX_DOMAIN}/fullchain.pem" \
                -subj "/C=US/ST=State/L=City/O=BytEM/CN=${MATRIX_DOMAIN}" 2>/dev/null
            
            CERT_PATH="/etc/letsencrypt/live/${BYTEM_DOMAIN}"
            MATRIX_CERT_PATH="/etc/letsencrypt/live/${MATRIX_DOMAIN}"
        fi
    fi
fi

echo -e "${YELLOW}Using certificate paths:${NC}"
echo -e "${YELLOW}BYTEM: ${CERT_PATH}${NC}"
echo -e "${YELLOW}Matrix: ${MATRIX_CERT_PATH}${NC}"

# Generate nginx configs with dynamic certificate path and fix HTTP/2 syntax
if [ -f "config_templates/nginx_config_templates/bytem.template" ]; then
    sed -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
        -e "s|\${CERT_PATH}|$CERT_PATH|g" \
        -e "s/listen 443 ssl http2;/listen 443 ssl;/g" \
        -e "s/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g" \
        config_templates/nginx_config_templates/bytem.template > \
        generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf
    
    # Add single http2 directive after server_name
    sed -i '/server_name.*{/a\    http2 on;' generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf
    echo -e "${GREEN}Generated BYTEM nginx config with HTTP/2 fix${NC}"
fi

if [ -f "config_templates/nginx_config_templates/matrix.bytem.template" ]; then
    sed -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
        -e "s|\${CERT_PATH}|$MATRIX_CERT_PATH|g" \
        -e "s/listen 443 ssl http2;/listen 443 ssl;/g" \
        -e "s/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g" \
        config_templates/nginx_config_templates/matrix.bytem.template > \
        generated_config_files/nginx_config/matrix.${BYTEM_DOMAIN}.conf
    
    # Add single http2 directive after server_name
    sed -i '/server_name.*{/a\    http2 on;' generated_config_files/nginx_config/matrix.${BYTEM_DOMAIN}.conf
    echo -e "${GREEN}Generated Matrix nginx config with HTTP/2 fix${NC}"
fi

# Test and reload nginx if container is running
if docker ps | grep -q "bytem-app"; then
    echo -e "${YELLOW}Testing nginx configuration...${NC}"
    if docker exec bytem-app nginx -t; then
        echo -e "${GREEN}Nginx config test passed, reloading...${NC}"
        docker exec bytem-app nginx -s reload || {
            echo -e "${YELLOW}Nginx reload failed, restarting container...${NC}"
            docker restart bytem-app
            sleep 5
        }
        
        # Copy config.js to web root to ensure it's accessible
        echo -e "${YELLOW}Ensuring config.js is accessible...${NC}"
        docker exec bytem-app cp /etc/nginx/conf.d/config.js /usr/share/nginx/html/config.js 2>/dev/null || true
        echo -e "${GREEN}Config.js copied to web root${NC}"
    else
        echo -e "${YELLOW}Nginx config test failed, restarting container...${NC}"
        docker restart bytem-app
        sleep 5
        
        # Copy config.js to web root after restart
        echo -e "${YELLOW}Ensuring config.js is accessible after restart...${NC}"
        docker exec bytem-app cp /etc/nginx/conf.d/config.js /usr/share/nginx/html/config.js 2>/dev/null || true
        echo -e "${GREEN}Config.js copied to web root${NC}"
    fi
fi

# Fix frontend hardcoded domains after SSL setup
echo -e "${YELLOW}Fixing frontend configuration...${NC}"
if docker exec bytem-app test -f /usr/share/nginx/html/umi.js; then
    echo -e "${YELLOW}Updating frontend domains...${NC}"
    docker exec bytem-app cp /usr/share/nginx/html/umi.js /usr/share/nginx/html/umi.js.backup 2>/dev/null || true
    docker exec bytem-app sed -i "s/bytem\.bm[0-9]*\.liberbyte\.app/${BYTEM_DOMAIN}/g" /usr/share/nginx/html/umi.js
    echo -e "${GREEN}Frontend domains updated successfully${NC}"
fi

# Final verification
echo -e "${YELLOW}Final SSL verification...${NC}"
sleep 3

# Test HTTPS connectivity
echo -e "${YELLOW}Testing HTTPS connectivity...${NC}"
if curl -s -k -I "https://${BYTEM_DOMAIN}" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ BYTEM HTTPS working${NC}"
else
    echo -e "${RED}❌ BYTEM HTTPS not responding${NC}"
fi

# Test Matrix API endpoint instead of root domain
if curl -s -k -I "https://${MATRIX_DOMAIN}/_matrix/client/versions" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Matrix HTTPS working${NC}"
else
    echo -e "${RED}❌ Matrix HTTPS not responding${NC}"
fi

echo -e "${GREEN}✅ SSL Setup Complete${NC}"
echo -e "${CYAN}Certificate Path: ${CERT_PATH}${NC}"
echo -e "${CYAN}BYTEM: https://${BYTEM_DOMAIN}${NC}"
echo -e "${CYAN}Matrix: https://${MATRIX_DOMAIN}${NC}"

# Show certificate expiry if available
if [ -f "./certbot/conf/live/${BYTEM_DOMAIN}/cert.pem" ] || [ -f "./certbot/conf/live/${BYTEM_DOMAIN}-0001/cert.pem" ]; then
    echo -e "${YELLOW}Certificate expires:${NC}"
    docker exec bytem-app openssl x509 -in ${CERT_PATH}/cert.pem -noout -dates 2>/dev/null | grep "notAfter" || echo "Could not read certificate expiry"
fi
