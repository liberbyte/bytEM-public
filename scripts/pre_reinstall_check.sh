#!/bin/bash

# Pre-reinstall state check for bytEM stack
# Usage: ./scripts/pre_reinstall_check.sh > /tmp/pre-reinstall-state.txt

set -euo pipefail

OUTFILE="/tmp/pre-reinstall-state.txt"
DATE=$(date '+%b %d, %Y')

echo "========================================"
echo "PRE-REINSTALL STATE ($DATE)"
echo "========================================"
echo
echo "1. SSL CERTIFICATES:"
# Discover domains from .env.bytem if available, else scan certbot directory
if [ -f .env.bytem ]; then
  _BYTEM_DOMAIN=$(grep '^BYTEM_DOMAIN=' .env.bytem | cut -d= -f2 | head -1)
  _MATRIX_DOMAIN=$(grep '^MATRIX_DOMAIN=' .env.bytem | cut -d= -f2 | head -1)
  _DOMAINS="${_BYTEM_DOMAIN} ${_MATRIX_DOMAIN}"
else
  _DOMAINS=$(ls certbot/conf/live/ 2>/dev/null | grep -v README | tr '\n' ' ')
fi
for domain in ${_DOMAINS}; do
  cert_path="certbot/conf/live/$domain/fullchain.pem"
  if [ -f "$cert_path" ]; then
    mod_date=$(stat -c %y "$cert_path" | cut -d'.' -f1)
    echo "   ✅ $domain ($mod_date)"
  else
    echo "   ❌ $domain (missing)"
  fi
done
echo
echo "2. DOCKER VOLUMES:"
docker volume ls --format '{{.Name}}' | grep '^bytem-' | while read vol; do
  vol_path=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
  size=$([ -n "$vol_path" ] && sudo du -sh "$vol_path" 2>/dev/null | awk '{print $1}' || echo "unknown")
  echo "   ✅ $vol (${size:-unknown})"
done
echo
echo "3. MATRIX USERS:"
user=$(sudo docker exec bytem-synapse-db psql -U synapse -d synapse -t -c "SELECT name FROM users LIMIT 1;" | xargs)
if [[ "$user" == @* ]]; then
  echo "   ✅ $user"
else
  echo "   ❌ No user found"
fi
echo
echo "4. WHITELIST:"
whitelist_file="generated_config_files/synapse_config/homeserver.yaml"
_WL_PATTERN=$([ -n "${_MATRIX_DOMAIN:-}" ] && echo "$_MATRIX_DOMAIN" || echo "matrix\.bytem\.")
grep -A 5 'federation_domain_whitelist:' "$whitelist_file" | grep -E "matrix.org|${_WL_PATTERN}" | sed 's/- //' | while read wl; do
  echo "   ✅ $wl"
done
echo
echo "5. DATABASE:"
db_size=$(sudo docker exec bytem-synapse-db du -sh /var/lib/postgresql/data | awk '{print $1}')
echo "   ✅ Size: $db_size"
echo
echo "6. DOCKER ROOT:"
docker_root=$(docker info --format '{{.DockerRootDir}}')
echo "   ✅ $docker_root"
