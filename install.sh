#!/bin/bash

set -euo pipefail

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BRIGHT_GREEN='\033[1;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

header_message() {
  echo -e "${CYAN}==========================================${NC}"
  echo -e "${CYAN}$1${NC}"
  echo -e "${CYAN}==========================================${NC}"
}

# Source the .env.bytem file
set +u
source .env.bytem
set -u

# Variables
CONFIG_DIR="generated_config_files/"
SYNAPSE_CONTAINER_NAME="bytem-synapse"
ADMIN_USERNAME=${PANTALAIMON_USERNAME}
ADMIN_PASSWORD=${PANTALAIMON_USERNAME}
MATRIX_URL="http://bytem-synapse:8008"
RESTART_CONTAINER="bytem-be bytem-bot bytem-app"

# Helper function for logging
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

header_message "Changing the permissions of ${CONFIG_DIR}"

log "Setting ownership for ${CONFIG_DIR}..."
sudo chown -R 991:991 "${CONFIG_DIR}"

header_message "Ensuring clean Docker environment"

log "Stopping any existing containers..."
sudo docker-compose down 2>/dev/null || true

header_message "Pulling latest Docker images"

log "Pulling latest images from registry..."
sudo docker-compose pull

header_message "Building and starting the bytem docker stack"

log "Starting Docker containers..."
MAX_RETRIES=3
RETRY_DELAY=20
for i in $(seq 1 $MAX_RETRIES); do
    if sudo docker-compose up -d --build; then
        log "Docker containers started successfully."
        break
    elif [[ $i -eq $MAX_RETRIES ]]; then
        log "Failed to start Docker containers after ${MAX_RETRIES} attempts."
        exit 1
    else
        log "Retrying Docker startup in ${RETRY_DELAY} seconds..."
        sleep $RETRY_DELAY
    fi
done

header_message "Waiting for the bytem containers to start..."

log "Waiting for services to initialize..."
sleep 60

# Wait for Matrix server to be ready
log "Checking Matrix server readiness..."
MAX_WAIT=300  # 5 minutes
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # First check if container is running
    if ! sudo docker ps | grep -q "${SYNAPSE_CONTAINER_NAME}"; then
        log "ERROR: ${SYNAPSE_CONTAINER_NAME} container is not running!"
        log "Checking container status and logs..."
        sudo docker ps -a | grep "${SYNAPSE_CONTAINER_NAME}"
        log "Recent logs from ${SYNAPSE_CONTAINER_NAME}:"
        sudo docker logs --tail 20 "${SYNAPSE_CONTAINER_NAME}" 2>&1 || true
        log "Please check the logs above for errors. Common issues:"
        log "  1. Database password mismatch - ensure POSTGRES_PASSWORD matches SYNAPSE_POSTGRES_PASSWORD in .env.bytem"
        log "  2. Database not ready - synapse container may need more time"
        exit 1
    fi
    
    if sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -s http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
        log "Matrix server is ready!"
        break
    fi
    log "Matrix server not ready yet, waiting... (${WAIT_TIME}s/${MAX_WAIT}s)"
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log "ERROR: Matrix server did not become ready within ${MAX_WAIT} seconds!"
    log "Recent logs from ${SYNAPSE_CONTAINER_NAME}:"
    sudo docker logs --tail 30 "${SYNAPSE_CONTAINER_NAME}" 2>&1 || true
    exit 1
fi

header_message "Registering new Matrix user and getting bot token"

log "Waiting for Matrix server to be ready..."
sleep 30

# Extract bot username from BOT_USER_ID (remove @ and domain)
BOT_USERNAME=$(echo "${BOT_USER_ID}" | sed 's/@\([^:]*\):.*/\1/')
log "Bot username extracted: ${BOT_USERNAME}"

log "Registering bot user..."
if sudo docker exec "${SYNAPSE_CONTAINER_NAME}" register_new_matrix_user -a -c data/homeserver.yaml -u "${BOT_USERNAME}" -p "${BOT_USERNAME}" "${MATRIX_URL}"; then
    log "Bot user ${BOT_USERNAME} registered successfully."
else
    log "Bot user ${BOT_USERNAME} may already exist, continuing..."
fi

log "Getting access token for bot user..."
# Get access token using Matrix API from inside container
BOT_TOKEN=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -s -X POST "${MATRIX_URL}/_matrix/client/r0/login" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"m.login.password\",\"user\":\"${BOT_USERNAME}\",\"password\":\"${BOT_USERNAME}\"}" | \
    grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -n "$BOT_TOKEN" ] && [ "$BOT_TOKEN" != "null" ]; then
    log "Bot token obtained successfully: ${BOT_TOKEN:0:20}..."
    # Update .env.bytem with the new token
    sed -i "s/BOT_USER_ACCESS_TOKEN=.*/BOT_USER_ACCESS_TOKEN=${BOT_TOKEN}/" .env.bytem
    log "Updated .env.bytem with new bot token."
else
    log "Warning: Could not obtain bot token automatically. Trying alternative method..."
    # Alternative: try with admin user credentials
    BOT_TOKEN=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -s -X POST "${MATRIX_URL}/_matrix/client/r0/login" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"m.login.password\",\"user\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | \
        grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [ -n "$BOT_TOKEN" ] && [ "$BOT_TOKEN" != "null" ]; then
        log "Bot token obtained with admin credentials: ${BOT_TOKEN:0:20}..."
        sed -i "s/BOT_USER_ACCESS_TOKEN=.*/BOT_USER_ACCESS_TOKEN=${BOT_TOKEN}/" .env.bytem
        log "Updated .env.bytem with new bot token."
    else
        log "ERROR: Could not obtain bot token. Manual intervention required."
    fi
fi

header_message "Restarting all containers to apply new bot token"

log "Performing full restart to apply updated token..."
if sudo docker-compose down && sudo docker-compose up -d; then
    log "All containers restarted successfully with new token."
    sleep 10  # Give containers time to initialize
else
    log "Failed to restart containers."
    exit 1
fi

header_message "Clearing Docker cache and unused images"

if sudo docker image prune -f; then
    log "Unused Docker images removed successfully."
else
    log "Failed to remove unused Docker images."
fi

# Fix frontend hardcoded domains
header_message "Fixing frontend configuration"
source .env.bytem

# Wait for container to be ready
sleep 5

# Fix hardcoded domains in frontend JavaScript
if sudo docker exec bytem-app test -f /usr/share/nginx/html/umi.js; then
    log "Backing up original frontend files..."
    sudo docker exec bytem-app cp /usr/share/nginx/html/umi.js /usr/share/nginx/html/umi.js.backup 2>/dev/null || true
    
    log "Replacing hardcoded domains with current configuration..."
    # Replace quoted bytem domains
    sudo docker exec bytem-app sed -i "s/\"bytem\.[^\"]*\"/\"${BYTEM_DOMAIN}\"/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/'bytem\.[^']*'/'${BYTEM_DOMAIN}'/g" /usr/share/nginx/html/umi.js
    
    # Replace quoted matrix.bytem domains  
    sudo docker exec bytem-app sed -i "s/\"matrix\.bytem\.[^\"]*\"/\"${MATRIX_DOMAIN}\"/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/'matrix\.bytem\.[^']*'/'${MATRIX_DOMAIN}'/g" /usr/share/nginx/html/umi.js
    
    # Replace https URLs
    sudo docker exec bytem-app sed -i "s|https://bytem\.[^/\"']*|https://${BYTEM_DOMAIN}|g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s|https://matrix\.bytem\.[^/\"']*|https://${MATRIX_DOMAIN}|g" /usr/share/nginx/html/umi.js
    
    # Replace unquoted domains (be more specific to avoid breaking other text)
    sudo docker exec bytem-app sed -i "s/\bbytem\.[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}\b/${BYTEM_DOMAIN}/g" /usr/share/nginx/html/umi.js
    sudo docker exec bytem-app sed -i "s/\bmatrix\.bytem\.[a-zA-Z0-9.-]*\.[a-zA-Z]{2,}\b/${MATRIX_DOMAIN}/g" /usr/share/nginx/html/umi.js
    
    log "Frontend configuration updated successfully."
else
    log "Frontend files not found, skipping domain fix."
fi

# Create welcome page for matrix subdomain
log "Creating welcome page for matrix subdomain..."
sudo docker exec bytem-app bash -c 'cat > /usr/share/nginx/html/matrix-welcome.html << "EOF"
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Matrix Server</title>
</head>
<body>
    <h1>Welcome to Nginx!</h1>
    <p>Matrix server is running successfully.</p>
</body>
</html>
EOF'
log "Welcome page created successfully."

header_message "Script completed successfully."
