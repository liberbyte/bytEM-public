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

# Error handler
error_message() {
  echo -e "${RED}$1${NC}" >&2
}

# Success message
success_message() {
  echo -e "${GREEN}$1${NC}"
}

# Informational message
info_message() {
  echo -e "${YELLOW}$1${NC}"
}

# Directory to store all generated files
GENERATED_DIR="generated_config_files"

header_message "Cleaning up any previous installation"

# Stop any running containers and remove volumes
info_message "Stopping Docker containers and removing volumes..."
docker-compose down -v 2>/dev/null || true

# Remove previous generated files
if [ -d "$GENERATED_DIR" ] || [ -d "solr" ] || [ -d "certbot" ] || [ -f ".env.bytem" ]; then
  info_message "Removing previous generated files..."
  rm -rf generated_config_files/ solr/ certbot/ .env.bytem 2>/dev/null || true
  success_message "Previous installation files removed."
else
  success_message "No previous installation found - starting fresh."
fi

header_message "Creating the base directory '$GENERATED_DIR' to store config files generated from template files"

# Create the base directory
mkdir -p "$GENERATED_DIR"

# Create subdirectories for synapse_config and nginx_config
mkdir -p "$GENERATED_DIR/synapse_config" "$GENERATED_DIR/nginx_config"

info_message "Directory $GENERATED_DIR is created and config files are organized as follows:"
success_message "- .env.bytem: In the root of the project"
success_message "- Config files Base Directory: $GENERATED_DIR"
success_message "- Synapse Config: $GENERATED_DIR/synapse_config"
success_message "- Nginx Config: $GENERATED_DIR/nginx_config"


header_message "Please enter the values for variables:"

# Function to prompt for user input
prompt_for_value() {
  local var_name=$1
  local prompt_message=$2
  local value=""

  while true; do
    read -rp "Please enter $prompt_message: " value
    if [ -n "$value" ]; then
      eval "$var_name=\"$value\""
      break
    else
      echo -e "${RED}ERROR: $prompt_message cannot be empty.${NC}"
    fi
  done
}

# Get or prompt for required values
if [ $# -ge 1 ]; then
  DOMAIN_NAME=$1
elif [ -n "${DOMAIN_NAME:-}" ]; then
  echo -e "${YELLOW}Using DOMAIN_NAME from environment variable: $DOMAIN_NAME${NC}"
else
  prompt_for_value DOMAIN_NAME "a domain name (e.g., example.com or liberbyte.app)"
fi

# Validate the domain name (format: <domain>.<extension>, no prefixes like www.)
if [[ "$DOMAIN_NAME" =~ ^www\..* ]]; then
  echo -e "${RED}ERROR: Domain should not start with 'www.' Expected format: <domain>.<extension> (e.g., example.com).${NC}"
  exit 1
elif [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
  echo -e "${RED}ERROR: Invalid domain name format. Expected format: <domain>.<extension> (e.g., example.com or example.co.uk).${NC}"
  exit 1
fi

# Prompt for subdomain prefix (optional)
if [ -n "${SUBDOMAIN_PREFIX:-}" ]; then
  echo -e "${YELLOW}Using SUBDOMAIN_PREFIX from environment variable: $SUBDOMAIN_PREFIX${NC}"
else
  echo -e "${CYAN}Examples:${NC}"
  echo -e "${CYAN}  - If you enter 'bm4', your domains will be: bytem.bm4.${DOMAIN_NAME}${NC}"
  echo -e "${CYAN}  - If you leave empty, your domains will be: bytem.${DOMAIN_NAME}${NC}"
  read -rp "Enter subdomain prefix (optional, press Enter to skip): " SUBDOMAIN_PREFIX
fi

# Set up domain variables based on subdomain prefix
if [ -n "$SUBDOMAIN_PREFIX" ]; then
  BYTEM_DOMAIN="bytem.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
  MATRIX_DOMAIN="matrix.bytem.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
else
  BYTEM_DOMAIN="bytem.${DOMAIN_NAME}"
  MATRIX_DOMAIN="matrix.bytem.${DOMAIN_NAME}"
fi

echo -e "${GREEN}Configuration:${NC}"
echo -e "${GREEN}  Base domain: $DOMAIN_NAME${NC}"
echo -e "${GREEN}  BytEM domain: $BYTEM_DOMAIN${NC}"
echo -e "${GREEN}  Matrix domain: $MATRIX_DOMAIN${NC}"

[[ -n "${BOT_USER:-}" ]] || prompt_for_value BOT_USER "BOT_USER (Will be converted to lowercase automatically)"
    BOT_USER=$(echo "$BOT_USER" | tr '[:upper:]' '[:lower:]')
[[ -n "${BOT_PASSWORD:-}" ]] || prompt_for_value BOT_PASSWORD "BOT_PASSWORD (Password for the bot user)"
[[ -n "${RABBITMQ_USERNAME:-}" ]] || prompt_for_value RABBITMQ_USERNAME "RABBITMQ_USERNAME (User for RabbitMQ)"
[[ -n "${RABBITMQ_PASSWORD:-}" ]] || prompt_for_value RABBITMQ_PASSWORD "RABBITMQ_PASSWORD (Password for RabbitMQ)"
[[ -n "${SYNAPSE_POSTGRES_PASSWORD:-}" ]] || prompt_for_value SYNAPSE_POSTGRES_PASSWORD "SYNAPSE_POSTGRES_PASSWORD (Password for PostgresDB used by synapse container. User will be 'synapse')"
[[ -n "${MATRIX_SSO_CLIENT_ID:-}" ]] || prompt_for_value MATRIX_SSO_CLIENT_ID "MATRIX_SSO_CLIENT_ID (Client ID for Matrix SSO)"
[[ -n "${MATRIX_SSO_CLIENT_SECRET:-}" ]] || prompt_for_value MATRIX_SSO_CLIENT_SECRET "MATRIX_SSO_CLIENT_SECRET (Client Secret for Matrix SSO)"
[[ -n "${MARKET_LIST:-}" ]] || prompt_for_value MARKET_LIST "MARKET_LIST (URL for market list, e.g., https://bytem.app/markets/byteM-market-list)"
[[ -n "${FEDERATION_MARKET_LIST_URL:-}" ]] || prompt_for_value FEDERATION_MARKET_LIST_URL "FEDERATION_MARKET_LIST_URL (URL for federation market list, e.g., https://bytem.app/markets/byteM-market-list)"

header_message "Generating .env.bytem file:"

# Generate .env.bytem from .env.template
ENV_TEMPLATE_FILE=".env.template"
ENV_OUTPUT_FILE=".env.bytem"

if [ -f "$ENV_TEMPLATE_FILE" ]; then
  # Check if the output file already exists
  if [ -f "$ENV_OUTPUT_FILE" ]; then
    echo -e "${YELLOW}WARNING: The file '$ENV_OUTPUT_FILE' already exists.${NC}"
    while true; do
      read -rp "Do you want to create a new one? Current $ENV_OUTPUT_FILE will be backed up if you choose yes. (yes/no): " response
      case $response in
        [Yy][Ee][Ss] )
          # Backup the existing file
          BACKUP_FILE="$ENV_OUTPUT_FILE.backup.$(date +%Y%m%d%H%M%S)"
          mv "$ENV_OUTPUT_FILE" "$BACKUP_FILE"
          echo -e "${GREEN}Existing file backed up as '$BACKUP_FILE'.${NC}"
          
          # Generate the new file
          sed \
            -e "s/\${DOMAIN}/$DOMAIN_NAME/g" \
            -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
            -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
            -e "s/\${BOT_USER}/$BOT_USER/g" \
            -e "s/\${BOT_PASSWORD}/$BOT_PASSWORD/g" \
            -e "s/\${RABBITMQ_USERNAME}/$RABBITMQ_USERNAME/g" \
            -e "s/\${RABBITMQ_PASSWORD}/$RABBITMQ_PASSWORD/g" \
            -e "s/\${SYNAPSE_POSTGRES_PASSWORD}/$SYNAPSE_POSTGRES_PASSWORD/g" \
            -e "s/\${MATRIX_SSO_CLIENT_ID}/$MATRIX_SSO_CLIENT_ID/g" \
            -e "s/\${MATRIX_SSO_CLIENT_SECRET}/$MATRIX_SSO_CLIENT_SECRET/g" \
            -e "s|\${MARKET_LIST}|$MARKET_LIST|g" \
            -e "s|\${FEDERATION_MARKET_LIST_URL}|$FEDERATION_MARKET_LIST_URL|g" \
            "$ENV_TEMPLATE_FILE" > "$ENV_OUTPUT_FILE"
          echo -e "${BRIGHT_GREEN}----- NEW ENV FILE GENERATED: $ENV_OUTPUT_FILE -----${NC}"
          break
          ;;
        [Nn][Oo] )
          echo -e "${YELLOW}Skipping the creation of '$ENV_OUTPUT_FILE'.${NC}"
          break
          ;;
        * )
          echo -e "${RED}Invalid response. Please answer 'yes' or 'no'.${NC}"
          ;;
      esac
    done
  else
    # Generate the file if it doesn't exist
    sed \
      -e "s/\${DOMAIN}/$DOMAIN_NAME/g" \
      -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
      -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
      -e "s/\${BOT_USER}/$BOT_USER/g" \
      -e "s/\${BOT_PASSWORD}/$BOT_PASSWORD/g" \
      -e "s/\${RABBITMQ_USERNAME}/$RABBITMQ_USERNAME/g" \
      -e "s/\${RABBITMQ_PASSWORD}/$RABBITMQ_PASSWORD/g" \
      -e "s/\${SYNAPSE_POSTGRES_PASSWORD}/$SYNAPSE_POSTGRES_PASSWORD/g" \
      -e "s/\${MATRIX_SSO_CLIENT_ID}/$MATRIX_SSO_CLIENT_ID/g" \
      -e "s/\${MATRIX_SSO_CLIENT_SECRET}/$MATRIX_SSO_CLIENT_SECRET/g" \
      -e "s|\${MARKET_LIST}|$MARKET_LIST|g" \
      -e "s|\${FEDERATION_MARKET_LIST_URL}|$FEDERATION_MARKET_LIST_URL|g" \
      "$ENV_TEMPLATE_FILE" > "$ENV_OUTPUT_FILE"
    echo -e "${BRIGHT_GREEN}----- ENV FILE GENERATED: $ENV_OUTPUT_FILE -----${NC}"
  fi
else
  echo -e "${RED}----- ERROR: Template file not found: $ENV_TEMPLATE_FILE -----${NC}"
  exit 1
fi

header_message "Generating Matrix Synapse Config Files:"

# Generate homeserver.yaml from homeserver-template.yaml
HOMESERVER_TEMPLATE_FILE="config_templates/synapse_config_templates/homeserver-template.yaml"
HOMESERVER_OUTPUT_FILE="$GENERATED_DIR/synapse_config/homeserver.yaml"
HOMESERVER_LOG_FILE="config_templates/synapse_config_templates/log.config"

if [ -f "$HOMESERVER_TEMPLATE_FILE" ]; then
  sed \
    -e "s/\${DOMAIN}/$DOMAIN_NAME/g" \
    -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
    -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
    -e "s/\${BOT_USER}/$BOT_USER/g" \
    -e "s/\${BOT_PASSWORD}/$BOT_PASSWORD/g" \
    -e "s/\${RABBITMQ_USERNAME}/$RABBITMQ_USERNAME/g" \
    -e "s/\${RABBITMQ_PASSWORD}/$RABBITMQ_PASSWORD/g" \
    -e "s/\${SYNAPSE_POSTGRES_PASSWORD}/$SYNAPSE_POSTGRES_PASSWORD/g" \
    -e "s/\${MATRIX_SSO_CLIENT_ID}/$MATRIX_SSO_CLIENT_ID/g" \
    -e "s/\${MATRIX_SSO_CLIENT_SECRET}/$MATRIX_SSO_CLIENT_SECRET/g" \
    "$HOMESERVER_TEMPLATE_FILE" > "$HOMESERVER_OUTPUT_FILE"
  echo -e "${BRIGHT_GREEN}----- HOMESERVER CONFIG FILE GENERATED: $HOMESERVER_OUTPUT_FILE -----${NC}"
  cp "$HOMESERVER_LOG_FILE" "$GENERATED_DIR/synapse_config/"
  echo -e "${BRIGHT_GREEN}----- HOMESERVER LOG FILE COPIED: $HOMESERVER_LOG_FILE -----${NC}"
else
  echo -e "${RED}----- ERROR: Template file not found: $HOMESERVER_TEMPLATE_FILE -----${NC}"
  exit 1
fi

header_message "Generating Nginx Config Files:"

# Nginx template files
NGINX_TEMPLATES=(
    "config_templates/nginx_config_templates/bytem.template"
    "config_templates/nginx_config_templates/matrix.bytem.template"
)

# Generate nginx config files
echo -e "${YELLOW}----- Generating Nginx configuration files... -----${NC}"
for template in "${NGINX_TEMPLATES[@]}"; do
  if [ -f "$template" ]; then
    # Generate appropriate filename based on template
    if [[ "$template" == *"matrix.bytem.template" ]]; then
      output_file="$GENERATED_DIR/nginx_config/matrix.${BYTEM_DOMAIN}.conf"
      CERT_PATH="/etc/letsencrypt/live/$MATRIX_DOMAIN"
    else
      output_file="$GENERATED_DIR/nginx_config/${BYTEM_DOMAIN}.conf"
      CERT_PATH="/etc/letsencrypt/live/$BYTEM_DOMAIN"
    fi
    sed \
      -e "s/\${DOMAIN}/$DOMAIN_NAME/g" \
      -e "s/\${BYTEM_DOMAIN}/$BYTEM_DOMAIN/g" \
      -e "s/\${MATRIX_DOMAIN}/$MATRIX_DOMAIN/g" \
      -e "s/\${BOT_USER}/$BOT_USER/g" \
      -e "s/\${BOT_PASSWORD}/$BOT_PASSWORD/g" \
      -e "s/\${RABBITMQ_USERNAME}/$RABBITMQ_USERNAME/g" \
      -e "s/\${RABBITMQ_PASSWORD}/$RABBITMQ_PASSWORD/g" \
      -e "s/\${SYNAPSE_POSTGRES_PASSWORD}/$SYNAPSE_POSTGRES_PASSWORD/g" \
      -e "s/\${MATRIX_SSO_CLIENT_ID}/$MATRIX_SSO_CLIENT_ID/g" \
      -e "s/\${MATRIX_SSO_CLIENT_SECRET}/$MATRIX_SSO_CLIENT_SECRET/g" \
      -e "s|\${CERT_PATH}|$CERT_PATH|g" \
      "$template" > "$output_file"
    echo -e "${GREEN}Generated file: $output_file${NC}"
  else
    echo -e "${RED}ERROR: Template file not found: $template${NC}"
    exit 1
  fi
done

# Generate frontend config.js file
header_message "Generating Frontend Config File:"
CONFIG_JS_TEMPLATE="config_templates/config.js.template"
CONFIG_JS_OUTPUT="$GENERATED_DIR/nginx_config/config.js"

if [ -f "$CONFIG_JS_TEMPLATE" ]; then
  sed \
    -e "s/DOMAIN_PLACEHOLDER/$BYTEM_DOMAIN/g" \
    "$CONFIG_JS_TEMPLATE" > "$CONFIG_JS_OUTPUT"
  echo -e "${GREEN}Generated frontend config: $CONFIG_JS_OUTPUT${NC}"
else
  echo -e "${RED}ERROR: Template file not found: $CONFIG_JS_TEMPLATE${NC}"
  exit 1
fi

header_message "Setting up SSL configuration"

# Create SSL directories
mkdir -p "certbot/conf/live/${BYTEM_DOMAIN}"
mkdir -p "certbot/www"

# Always create proper self-signed certificates for development
echo -e "${YELLOW}Creating self-signed SSL certificates for development...${NC}"

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "certbot/conf/live/${BYTEM_DOMAIN}/privkey.pem" \
    -out "certbot/conf/live/${BYTEM_DOMAIN}/fullchain.pem" \
    -subj "/C=US/ST=State/L=City/O=BytEM/CN=${BYTEM_DOMAIN}" 2>/dev/null

# Also create for matrix domain
mkdir -p "certbot/conf/live/${MATRIX_DOMAIN}"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "certbot/conf/live/${MATRIX_DOMAIN}/privkey.pem" \
    -out "certbot/conf/live/${MATRIX_DOMAIN}/fullchain.pem" \
    -subj "/C=US/ST=State/L=City/O=BytEM/CN=${MATRIX_DOMAIN}" 2>/dev/null

echo -e "${GREEN}Created self-signed SSL certificates for development${NC}"

header_message "Setting up Solr directories"

# Create Solr directories
mkdir -p "solr/data"
mkdir -p "solr/logs"

header_message "----- ALL SET..! -----"

echo -e "${RED}IMPORTANT: ${BRIGHT_GREEN}PLEASE BACKUP THE FILE $ENV_OUTPUT_FILE TO ENSURE NOT TO LOSE THE SET CREDENTIALS!!!${NC}"
echo -e "${YELLOW}----- If you are not happy with the set values, delete the file $ENV_OUTPUT_FILE and directory $GENERATED_DIR and start over!!! -----${NC}"
echo -e "${CYAN}==========================================${NC}"
