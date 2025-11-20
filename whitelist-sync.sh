#!/bin/bash
set -euo pipefail

# Get script directory and set relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate we're in the correct directory (should contain docker-compose file)
if [[ ! -f "$SCRIPT_DIR/docker-compose.yaml" ]]; then
    echo "❌ Error: Script must be run from bytEM installation directory"
    echo "Current directory: $SCRIPT_DIR"
    echo "Please run from the directory containing docker-compose.yaml"
    exit 1
fi

# Registry endpoint
REGISTRY_URL="https://bytem.app/markets/byteM-market-list"
# Local homeserver.yaml path
HOMESERVER_PATH="$SCRIPT_DIR/generated_config_files/synapse_config/homeserver.yaml"
# Nginx config path - dynamically find the config file
NGINX_CONFIG_DIR="$SCRIPT_DIR/generated_config_files/nginx_config"
NGINX_CONFIG_PATH=$(find "$NGINX_CONFIG_DIR" -name "bytem.*.conf" | head -1)

# Verify required files exist
if [[ ! -f "$HOMESERVER_PATH" ]]; then
    echo "❌ Error: homeserver.yaml not found at $HOMESERVER_PATH"
    exit 1
fi

if [[ -z "$NGINX_CONFIG_PATH" || ! -f "$NGINX_CONFIG_PATH" ]]; then
    echo "❌ Error: nginx config not found in $NGINX_CONFIG_DIR"
    echo "Looking for files matching pattern: bytem.*.conf"
    ls -la "$NGINX_CONFIG_DIR" 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo "✅ Configuration files found"
echo "✅ Using nginx config: $NGINX_CONFIG_PATH"

# --- Fetch domains ---
DOMAINS=$(curl -fsS "$REGISTRY_URL" | jq -r '.[]')
echo "✅ Registry domains fetched successfully"

# --- Filter domains to match current server's domain ---
# Extract parent domain from nginx config filename (e.g., bytem.bm1.liberbyte.app.conf -> liberbyte.app)
CONFIG_FILENAME=$(basename "$NGINX_CONFIG_PATH")
FULL_DOMAIN=$(echo "$CONFIG_FILENAME" | sed 's/^bytem\.//' | sed 's/\.conf$//')
CURRENT_DOMAIN=$(echo "$FULL_DOMAIN" | sed 's/^[^.]*\.//')

# Filter domains to only include same parent domain
FILTERED_DOMAINS=$(echo "$DOMAINS" | grep "\.${CURRENT_DOMAIN}$")
PEERS=$(echo "$FILTERED_DOMAINS" | tr '\n' ' ')
echo "✅ Current domain: $CURRENT_DOMAIN"
echo "✅ Filtered peers for whitelist: $PEERS"

# --- Backup original file ---
cp "$HOMESERVER_PATH" "$HOMESERVER_PATH.bak"

# --- Clean up the file completely ---
sed -i '/^federation_domain_whitelist:/d' "$HOMESERVER_PATH"
sed -i '/^  - matrix\./d' "$HOMESERVER_PATH"

# --- Add whitelist after enable_federation line ---
sed -i '/^enable_federation: true$/a\
federation_domain_whitelist:' "$HOMESERVER_PATH"

# --- Add each domain from market list ---
for domain in $DOMAINS; do
  sed -i "/^federation_domain_whitelist:$/a\\  - matrix.$domain" "$HOMESERVER_PATH"
done

echo "✅ Whitelist updated with all market domains"

# --- Get server IP ---
SERVER_IP=$(curl -4 -s ifconfig.me)
echo "✅ Current server IP: $SERVER_IP"

# --- Update nginx config with IP restrictions ---
cp "$NGINX_CONFIG_PATH" "$NGINX_CONFIG_PATH.bak"

# Remove existing allow/deny directives in /solr location
sed -i '/location \/solr\/ {/,/}/{/allow\|deny/d}' "$NGINX_CONFIG_PATH"

# Add current server IP first
sed -i "/location \/solr\/ {/a\\
        allow $SERVER_IP;" "$NGINX_CONFIG_PATH"

# Add IPs for all domains from the whitelist
for peer in $PEERS; do
    PEER_IP=$(dig +short matrix.$peer A | head -1)
    if [[ -n "$PEER_IP" && "$PEER_IP" != "$SERVER_IP" ]]; then
        sed -i "/location \/solr\/ {/a\\
        allow $PEER_IP;" "$NGINX_CONFIG_PATH"
        echo "✅ Added peer IP: $PEER_IP (matrix.$peer)"
    fi
done

# Add deny all at the end
sed -i "/location \/solr\/ {/a\\
        deny all;" "$NGINX_CONFIG_PATH"

echo "✅ Nginx config IP restrictions for /solr ENABLED"

# --- Reload bytem-app container ---
docker exec bytem-app nginx -s reload
echo "✅ Nginx reloaded in bytem-app container"

# --- Reload synapse container ---
docker kill -s HUP bytem-synapse
echo "✅ Synapse configuration reloaded"
