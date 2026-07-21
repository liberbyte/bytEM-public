#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment
source .env.bytem

BYTEM_DOMAIN=${DOMAIN_NAME}
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
    IS_RENEWAL=false
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
            IS_RENEWAL=true
            rm -rf "./certbot/conf/live/${BYTEM_DOMAIN}"
            rm -rf "./certbot/conf/archive/${BYTEM_DOMAIN}"
            rm -f "./certbot/conf/renewal/${BYTEM_DOMAIN}.conf"
            mkdir -p "./certbot/conf/live/${BYTEM_DOMAIN}"
        fi
    fi
    
    # Generate new certificates if needed
    if [ "$SKIP_RENEWAL" = false ]; then
        echo -e "${YELLOW}Attempting Let's Encrypt certificate for ${BYTEM_DOMAIN} and ${MATRIX_DOMAIN}${NC}"

        # Initial acquisition: bytem-app can't start without certs (its entrypoint generates
        # an SSL nginx config via envsubst), so port 80 is never available for webroot mode.
        # Use certbot standalone instead — it binds port 80 directly, no nginx required.
        # Renewal: nginx is already running with valid certs, so webroot mode works fine.
        CERTBOT_SUCCESS=false
        if ! $IS_RENEWAL; then
            echo -e "${YELLOW}Initial acquisition: using standalone mode (stopping bytem-app to free port 80)${NC}"
            if sudo docker ps --format '{{.Names}}' | grep -q "^bytem-app$"; then
                sudo docker stop bytem-app >/dev/null 2>&1
                sleep 2
            fi
            docker run --rm \
                -v "${PWD}/certbot/conf:/etc/letsencrypt" \
                -p 80:80 \
                certbot/certbot certonly \
                --standalone \
                --email "$EMAIL" \
                --agree-tos \
                --no-eff-email \
                --non-interactive \
                --expand \
                -d "$BYTEM_DOMAIN" \
                -d "$MATRIX_DOMAIN" && CERTBOT_SUCCESS=true
        else
            echo -e "${YELLOW}Renewal: using webroot mode (nginx serves the challenge)${NC}"
            docker run --rm \
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
                -d "$MATRIX_DOMAIN" && CERTBOT_SUCCESS=true
        fi

        if $CERTBOT_SUCCESS; then
            
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

# Ensure matrix cert path resolves to real cert files (single multi-domain cert covers
# both domains, but the bytem-app image's own default.conf hardcodes the matrix-domain-named
# path — so that path needs to be a symlink to where the real cert actually lives, not just
# an empty directory that happens to exist from an earlier unconditional mkdir).
MATRIX_CERT_DIR="./certbot/conf/live/${MATRIX_DOMAIN}"
BYTEM_CERT_DIR="./certbot/conf/live/${BYTEM_DOMAIN}"
if [ ! -f "${MATRIX_CERT_DIR}/fullchain.pem" ] && [ -f "${BYTEM_CERT_DIR}/fullchain.pem" ] && [ "$MATRIX_CERT_DIR" != "$BYTEM_CERT_DIR" ]; then
    echo -e "${YELLOW}Linking matrix domain certificate path to the multi-domain certificate...${NC}"
    sudo rm -rf "${MATRIX_CERT_DIR}"
    # Relative symlink (just the sibling directory name) so it resolves correctly both on
    # the host and inside the container, where this directory is bind-mounted at a different
    # absolute path (/etc/letsencrypt) than it has on the host.
    sudo ln -s "${BYTEM_DOMAIN}" "${MATRIX_CERT_DIR}"
    echo -e "${GREEN}Symlink created: ${MATRIX_CERT_DIR} -> ${BYTEM_DOMAIN}${NC}"
fi

# Generate nginx configs with dynamic certificate path and fix HTTP/2 syntax
if [ -f "config_templates/nginx_config_templates/bytem.template" ]; then
    sudo sed -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
        -e "s|\${CERT_PATH}|$CERT_PATH|g" \
        -e "s/listen 443 ssl http2;/listen 443 ssl;/g" \
        -e "s/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g" \
        config_templates/nginx_config_templates/bytem.template > \
        generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf
    
    # Add single http2 directive after server_name
    sudo sed -i '/server_name.*{/a\    http2 on;' generated_config_files/nginx_config/${BYTEM_DOMAIN}.conf
    echo -e "${GREEN}Generated BYTEM nginx config with HTTP/2 fix${NC}"
fi

if [ -f "config_templates/nginx_config_templates/matrix.bytem.template" ]; then
    sudo sed -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
        -e "s|\${CERT_PATH}|$MATRIX_CERT_PATH|g" \
        -e "s/listen 443 ssl http2;/listen 443 ssl;/g" \
        -e "s/listen \[::\]:443 ssl http2;/listen [::]:443 ssl;/g" \
        config_templates/nginx_config_templates/matrix.bytem.template > \
        generated_config_files/nginx_config/matrix.${BYTEM_DOMAIN}.conf
    
    # Add single http2 directive after server_name
    sudo sed -i '/server_name.*{/a\    http2 on;' generated_config_files/nginx_config/matrix.${BYTEM_DOMAIN}.conf
    echo -e "${GREEN}Generated Matrix nginx config with HTTP/2 fix${NC}"
fi

# Restart the container to pick up the new SSL config (it was running HTTP-only during
# the bootstrap/certbot phase), then wait for it to be reachable before testing.
if sudo docker ps -a --format '{{.Names}}' | grep -q "^bytem-app$"; then
    echo -e "${YELLOW}Restarting bytem-app to load SSL configuration...${NC}"
    sudo docker restart bytem-app >/dev/null 2>&1
    WAIT_COUNT=0
    until sudo docker exec bytem-app nginx -t 2>/dev/null; do
        sleep 3
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge 20 ]; then
            echo -e "${RED}bytem-app did not become ready after 60s${NC}"
            break
        fi
    done
fi

# Test and reload nginx if container is running
if sudo docker ps | grep -q "bytem-app"; then
    echo -e "${YELLOW}Testing nginx configuration...${NC}"
    if sudo docker exec bytem-app nginx -t; then
        echo -e "${GREEN}Nginx config test passed, reloading...${NC}"
        sudo docker exec bytem-app nginx -s reload || {
            echo -e "${YELLOW}Nginx reload failed, restarting container...${NC}"
            sudo docker restart bytem-app
            sleep 5
        }

        # Copy config.js to web root to ensure it's accessible
        echo -e "${YELLOW}Ensuring config.js is accessible...${NC}"
        sudo docker exec bytem-app cp /etc/nginx/conf.d/config.js /usr/share/nginx/html/config.js 2>/dev/null || true
        echo -e "${GREEN}Config.js copied to web root${NC}"
    else
        echo -e "${YELLOW}Nginx config test failed, restarting container...${NC}"
        sudo docker restart bytem-app
        sleep 5

        # Copy config.js to web root after restart
        echo -e "${YELLOW}Ensuring config.js is accessible after restart...${NC}"
        sudo docker exec bytem-app cp /etc/nginx/conf.d/config.js /usr/share/nginx/html/config.js 2>/dev/null || true
        echo -e "${GREEN}Config.js copied to web root${NC}"
    fi
fi

# Fix frontend hardcoded domains after SSL setup. By this point bytem-app is guaranteed to
# be running (we just verified nginx above), unlike the equivalent step in install.sh which
# runs before certificates exist and silently skips on a fresh install. Match ANY old bytem.*
# domain baked into the bundle at build time, not just the bm-N.liberbyte.app naming pattern.
echo -e "${YELLOW}Fixing frontend configuration...${NC}"
if sudo docker exec bytem-app test -f /usr/share/nginx/html/umi.js; then
    echo -e "${YELLOW}Updating frontend domains...${NC}"
    sudo docker exec bytem-app cp /usr/share/nginx/html/umi.js /usr/share/nginx/html/umi.js.backup 2>/dev/null || true
    sudo docker exec bytem-app sed -i "s/\"bytem\.[^\"]*\"/\"${BYTEM_DOMAIN}\"/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/'bytem\.[^']*'/'${BYTEM_DOMAIN}'/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/\"matrix\.bytem\.[^\"]*\"/\"${MATRIX_DOMAIN}\"/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/'matrix\.bytem\.[^']*'/'${MATRIX_DOMAIN}'/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s|https://bytem\.[^/\"']*|https://${BYTEM_DOMAIN}|g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s|https://matrix\.bytem\.[^/\"']*|https://${MATRIX_DOMAIN}|g" /usr/share/nginx/html/umi.js
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
