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
for domain in bytem.bfr.data-playground.de matrix.bytem.bfr.data-playground.de; do
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
  size=$(sudo du -sh /tmp/mock-bfr-liberbyte/bytem/docker/volumes/$vol/_data 2>/dev/null | awk '{print $1}')
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
grep -A 5 'federation_domain_whitelist:' "$whitelist_file" | grep -E 'matrix.org|matrix.bytem.bfr.data-playground.de' | sed 's/- //' | while read wl; do
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
