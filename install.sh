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
    if sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -s http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
        log "Matrix server is ready!"
        break
    fi
    log "Matrix server not ready yet, waiting..."
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log "Warning: Matrix server may not be fully ready, but continuing..."
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

header_message "Restarting ${RESTART_CONTAINER} container"

log "Restarting container ${RESTART_CONTAINER}..."
if sudo docker restart ${RESTART_CONTAINER}; then
    log "Container ${RESTART_CONTAINER} restarted successfully."
else
    log "Failed to restart container ${RESTART_CONTAINER}."
    exit 1
fi

header_message "Clearing Docker cache and unused images"

if sudo docker image prune -f; then
    log "Unused Docker images removed successfully."
else
    log "Failed to remove unused Docker images."
fi

header_message "Script completed successfully."
