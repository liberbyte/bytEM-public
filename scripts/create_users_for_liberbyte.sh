#!/bin/bash
# Script: create_users_for_liberbyte.sh
# Purpose: Create Matrix admin users in bytem-synapse Docker container for liberbyte team

set -e

USERS=(tero ahmad neel yugank)
PASSWORD="BytEM2025!"
CONTAINER="bytem-synapse"
HOMESERVER_YAML="/data/homeserver.yaml"
MATRIX_URL="http://localhost:8008"

for user in "${USERS[@]}"; do
    echo "Registering user: $user"
    if sudo docker exec -i "$CONTAINER" register_new_matrix_user \
        -c "$HOMESERVER_YAML" \
        --user "$user" \
        --password "$PASSWORD" \
        --admin \
        "$MATRIX_URL"; then
        echo "User $user registered successfully."
    else
        echo "User $user may already exist or registration failed. Skipping."
    fi
done
