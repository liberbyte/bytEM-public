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
sudo chown -R 991 "${CONFIG_DIR}"

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

header_message "Registering new Matrix user"

log "Registering new Matrix user..."
if sudo docker exec -it "${SYNAPSE_CONTAINER_NAME}" register_new_matrix_user -a -c data/homeserver.yaml -u "${ADMIN_USERNAME}" -p "${ADMIN_PASSWORD}" "${MATRIX_URL}"; then
    log "User ${ADMIN_USERNAME} registered successfully."
else
    log "Error: Failed to register user ${ADMIN_USERNAME}."
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
