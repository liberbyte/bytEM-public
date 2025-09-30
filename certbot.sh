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

# Variables already sourced above

# Extract domain info from environment variables
BYTEM_DOMAIN=${EXCHANGE_SERVER_HOSTNAME}
MATRIX_DOMAIN=${MATRIX_APP}
DOMAIN_NAME=${DOMAIN_NAME}
CONFIG_DIR="generated_config_files/"
SYNAPSE_CONTAINER_NAME="bytem-synapse"
ADMIN_USERNAME=${PANTALAIMON_USERNAME}
ADMIN_PASSWORD=${PANTALAIMON_USERNAME}
MATRIX_URL="http://bytem-synapse:8008"
RESTART_CONTAINER="bytem-be bytem-bot"

# Prompt or fetch environment variables
header_message "Enter the information needed to generate SSL certificate"

EMAIL=${EMAIL:-$(read -p "Enter your email for Certificate update Notifications: " REPLY && echo "$REPLY")}
# DOMAIN_NAME=${DOMAIN_NAME:-$(read -p "Enter your domain which you are using to deploy bytem (e.g., example.com): " REPLY && echo "$REPLY")}

# Validate the domain name (format: <domain>.<extension>, no prefixes like www.)
if [[ "$DOMAIN_NAME" =~ ^www\..* ]]; then
  echo -e "${RED}ERROR: Domain should not start with 'www.'Expected format: <domain>.<extension> (e.g., example.com).${NC}"
  exit 1
elif [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
  echo -e "${RED}ERROR: Invalid domain name format. Expected format: <domain>.<extension> (e.g., example.com).${NC}"
  exit 1
fi

# Define the matrix nginx config file
config_file="$CONFIG_DIR/nginx_config/matrix.$BYTEM_DOMAIN.conf"

# Check if the matrix.bytem nginx config file exists
if [ ! -f "$config_file" ]; then
  echo -e "${RED}ERROR: matrix.bytem nginx config file not found: $config_file${NC}"
  exit 1
fi

header_message "Generating SSL Certificates.."

# Generate SSL Certificates
echo -e "${YELLOW}Attempting to generate SSL certificates...${NC}"
if sudo docker exec bytem-app certbot --nginx --agree-tos -n -m "$EMAIL" -d "$BYTEM_DOMAIN,$MATRIX_DOMAIN"; then
    echo "SSL certificates generated successfully."

    # Uncomment lines starting with `#` and containing `listen` in matrix.bytem nginx config file
    echo -e "${YELLOW}Uncommenting necessary lines in the matrix.bytem nginx config file...${NC}"
    sed -i '/^#.*listen/s/^# *//' "$config_file"
    echo -e "${GREEN}Lines uncommented successfully.${NC}"

    # Reload nginx
    echo -e "${YELLOW}Reloading nginx...${NC}"
    if sudo docker exec bytem-app nginx -s reload; then
        echo -e "${GREEN}nginx reload successful.${NC}"
    else
        echo -e "${RED}Failed to reload nginx.${NC}"
        exit 2
    fi
else
    echo -e "${RED}SSL certificate generation failed. Exiting script.${NC}"
    exit 1
fi

# Generate Token
header_message "Generating Login Token.."

echo -e "${GREEN}Generating token by logging in...${NC}" 
RESPONSE=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl --location 'http://bytem-be:3000/authorize' \
    --header "matrix_server: ${MATRIX_URL}" \
    --header 'Content-Type: application/json' \
    --data-raw '{
        "password": "'${ADMIN_PASSWORD}'",
        "username": "'${ADMIN_USERNAME}'"
    }')

echo "Curl Response: $RESPONSE"

TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"//;s/"//')

if [[ -z "$TOKEN" ]]; then
    echo -e "${RED}Error: Token could not be generated. Response was: $RESPONSE ${NC}"
    exit 1
fi

header_message "Token Generated.."

echo "Captured token: $TOKEN"

header_message "Replacing Token in .env.bytem file.."

echo "Replacing token in .env.bytem..."

    sed -i "s/\${TOKEN}/$TOKEN/g" .env.bytem

echo "Token replaced successfully in .env.bytem."

# Override Ratelimit
header_message "Overriding Ratelimit.."

echo -e "${GREEN}Overriding Ratelimit..${NC}" 
RESPONSE=$(sudo docker exec "${SYNAPSE_CONTAINER_NAME}" curl -X POST "http://bytem-synapse:8008/_synapse/admin/v1/users/@${ADMIN_USERNAME}:$MATRIX_DOMAIN/override_ratelimit" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"messages_per_second": 0, "burst_count": 0}')

echo "Curl Response: $RESPONSE"

header_message "Restarting ${RESTART_CONTAINER} Container.."

echo "Restarting container ${RESTART_CONTAINER}..."
if sudo docker restart ${RESTART_CONTAINER}; then
    echo "Container ${RESTART_CONTAINER} restarted successfully."
else
    echo "Failed to restart container ${RESTART_CONTAINER}."
    exit 1
fi

header_message "Script completed successfully."
