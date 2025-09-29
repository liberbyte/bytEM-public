#!/bin/bash
set -euo pipefail

# Registry endpoint
REGISTRY_URL="https://bytem.app/markets/byteM-market-list"
# Local homeserver.yaml path
HOMESERVER_PATH="/root/test.bk/generated_config_files/synapse_config/homeserver.yaml"
# Nginx config path
NGINX_CONFIG_PATH="/root/test.bk/generated_config_files/nginx_config/bytem.bm3.liberbyte.app.conf"

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
