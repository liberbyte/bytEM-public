#!/bin/bash
# Script: create_users_for_liberbyte.sh
# Purpose: Create Matrix admin users in bytem-synapse Docker container

set -e

CONTAINER="bytem-synapse"
HOMESERVER_YAML="/data/homeserver.yaml"
MATRIX_URL="http://localhost:8008"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}  Matrix Admin User Creation Tool${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Prompt for users to create
echo -e "${YELLOW}Enter usernames to create (space-separated):${NC}"
echo -e "${CYAN}Example: tero ahmad neel yugank${NC}"
read -rp "Usernames: " USER_INPUT

# Convert to array
read -ra USERS <<< "$USER_INPUT"

if [ ${#USERS[@]} -eq 0 ]; then
    echo -e "${RED}No users specified. Exiting.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Enter password for all users:${NC}"
read -rsp "Password: " PASSWORD
echo ""
echo ""

# Confirm
echo -e "${CYAN}Users to create: ${GREEN}${USERS[*]}${NC}"
read -rp "Proceed? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Creating users...${NC}"
echo ""

for user in "${USERS[@]}"; do
    echo -e "${YELLOW}Registering user: $user${NC}"
    if sudo docker exec -i "$CONTAINER" register_new_matrix_user \
        -c "$HOMESERVER_YAML" \
        --user "$user" \
        --password "$PASSWORD" \
        --admin \
        "$MATRIX_URL"; then
        echo -e "${GREEN}✅ User $user registered successfully.${NC}"
    else
        echo -e "${RED}❌ User $user may already exist or registration failed. Skipping.${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  User creation complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
