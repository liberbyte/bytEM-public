#!/bin/bash
set -euo pipefail

# Get script directory and set relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate we're in the correct directory (should contain docker-compose file)
if [[ ! -f "$SCRIPT_DIR/docker-compose-client.yaml" ]]; then
    echo "❌ Error: Script must be run from bytEM installation directory"
    echo "Current directory: $SCRIPT_DIR"
    echo "Please run from the directory containing docker-compose-client.yaml"
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

# --- Use all domains from registry ---
PEERS=$(echo "$DOMAINS" | tr '\n' ' ')
echo "✅ Peers for whitelist: $PEERS"

# --- Backup original file ---
cp "$HOMESERVER_PATH" "$HOMESERVER_PATH.bak"

# --- Clean up the file completely ---
sed -i '/^federation_domain_whitelist:/d' "$HOMESERVER_PATH"
sed -i '/^  - matrix\./d' "$HOMESERVER_PATH"

# --- Add whitelist after enable_federation line ---
sed -i '/^enable_federation: true$/a\
federation_domain_whitelist:' "$HOMESERVER_PATH"

# --- Add each peer ---
for peer in $PEERS; do
  sed -i "/^federation_domain_whitelist:$/a\\  - matrix.$peer" "$HOMESERVER_PATH"
done

echo "✅ Whitelist cleaned and updated with bm3 and bm4 domains only"

# --- Get server IPs ---
BM3_IP=$(curl -4 -s ifconfig.me)
BM4_IP=$(dig +short bytem.bm4.liberbyte.app A | head -1)

echo "✅ BM3 server IP: $BM3_IP"
echo "✅ BM4 server IP: $BM4_IP"

# --- Update nginx config with IP restrictions ---
cp "$NGINX_CONFIG_PATH" "$NGINX_CONFIG_PATH.bak"

# Remove existing allow/deny directives in /solr location
sed -i '/location \/solr\/  {/,/}/{/allow\|deny/d}' "$NGINX_CONFIG_PATH"

# Add IP restrictions after the location /solr/ { line
sed -i "/location \/solr\/  {/a\\
                allow $BM3_IP;\\
                allow $BM4_IP;\\
                deny all;" "$NGINX_CONFIG_PATH"

echo "✅ Nginx config updated with IP restrictions for /solr"

# --- Reload bytem-app container ---
docker exec bytem-app nginx -s reload
echo "✅ Nginx reloaded in bytem-app container"

# --- Reload synapse container ---
docker exec synapse kill -HUP 1
echo "✅ Synapse configuration reloaded"
