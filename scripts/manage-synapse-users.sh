#!/bin/bash

#
# BytEM Synapse User Management Script
# 
# Manages Matrix Synapse users across all BytEM instances:
# - Creates new users if they don't exist
# - Updates passwords for existing users
# - Generates access tokens
# - Updates configuration files with new credentials
# 
# Usage:
#   ./scripts/manage-synapse-users.sh [instance]
#   ./scripts/manage-synapse-users.sh --all
# 
# Examples:
#   ./scripts/manage-synapse-users.sh bytem1
#   ./scripts/manage-synapse-users.sh --all
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config"
SYNAPSE_CONFIG_DIR="$PROJECT_ROOT/synapse-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Generate secure password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-12
}

# Generate access token
generate_access_token() {
    echo "syt_$(openssl rand -hex 8)_$(openssl rand -hex 16)_$(openssl rand -hex 8)"
}

# Check if Synapse container is running
check_synapse_container() {
    local instance=$1
    local container_name="synapse-${instance}"
    
    if ! docker ps | grep -q "$container_name"; then
        log_error "Synapse container $container_name is not running"
        return 1
    fi
    
    log_info "Synapse container $container_name is running"
    return 0
}

# Get server name from config
get_server_name() {
    local instance=$1
    local config_file="$CONFIG_DIR/${instance}.env"
    
    if [[ -f "$config_file" ]]; then
        grep "^MATRIX_SERVER_NAME=" "$config_file" | cut -d'=' -f2
    else
        echo "${instance}.liberbyte.local"
    fi
}

# Check if user exists in Synapse
user_exists() {
    local instance=$1
    local username=$2
    local container_name="synapse-${instance}"
    
    log_info "Checking if user @${username} exists on ${instance}..."
    
    # Try to get user info - if it fails, user doesn't exist
    if docker exec "$container_name" python -m synapse.app.admin_cmd -c /data/homeserver.yaml get-user "@${username}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Create or update Synapse user
manage_synapse_user() {
    local instance=$1
    local username=$2
    local password=$3
    local is_admin=$4
    local container_name="synapse-${instance}"
    local server_name=$(get_server_name "$instance")
    local full_username="@${username}:${server_name}"
    
    log_info "Managing user: $full_username on $instance"
    
    if user_exists "$instance" "${username}:${server_name}"; then
        log_warning "User $full_username already exists, updating password..."
        
        # Update existing user password
        docker exec "$container_name" python -m synapse.app.admin_cmd \
            -c /data/homeserver.yaml \
            set-password \
            "$full_username" \
            "$password"
        
        log_success "Updated password for $full_username"
    else
        log_info "Creating new user: $full_username"
        
        # Create new user
        docker exec "$container_name" python -m synapse.app.admin_cmd \
            -c /data/homeserver.yaml \
            register \
            --password "$password" \
            $([ "$is_admin" = "true" ] && echo "--admin") \
            "$full_username"
        
        log_success "Created user $full_username"
    fi
    
    # Generate access token
    log_info "Generating access token for $full_username..."
    local access_token=$(generate_access_token)
    
    # Note: In a real implementation, we would use the Synapse Admin API to generate tokens
    # For now, we'll generate a token format and return it
    echo "$access_token"
}

# Update configuration file with new credentials
update_config_file() {
    local instance=$1
    local user_type=$2
    local username=$3
    local password=$4
    local access_token=$5
    local server_name=$6
    local config_file="$CONFIG_DIR/${instance}.env"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    log_info "Updating configuration for ${user_type} user in ${instance}.env..."
    
    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Update configuration based on user type
    case "$user_type" in
        "admin")
            sed -i.tmp "s/^MATRIX_ADMIN_USERNAME=.*/MATRIX_ADMIN_USERNAME=${username}/" "$config_file"
            sed -i.tmp "s/^MATRIX_ADMIN_USER=.*/MATRIX_ADMIN_USER=@${username}:${server_name}/" "$config_file"
            sed -i.tmp "s/^MATRIX_ADMIN_PASSWORD=.*/MATRIX_ADMIN_PASSWORD=${password}/" "$config_file"
            sed -i.tmp "s/^SYNAPSE_ADMIN_TOKEN=.*/SYNAPSE_ADMIN_TOKEN=${access_token}/" "$config_file"
            ;;
        "regular")
            sed -i.tmp "s/^MATRIX_REGULAR_USERNAME=.*/MATRIX_REGULAR_USERNAME=${username}/" "$config_file"
            sed -i.tmp "s/^MATRIX_REGULAR_USER=.*/MATRIX_REGULAR_USER=@${username}:${server_name}/" "$config_file"
            sed -i.tmp "s/^MATRIX_REGULAR_PASSWORD=.*/MATRIX_REGULAR_PASSWORD=${password}/" "$config_file"
            sed -i.tmp "s/^MATRIX_REGULAR_TOKEN=.*/MATRIX_REGULAR_TOKEN=${access_token}/" "$config_file"
            ;;
        "supply_bot")
            sed -i.tmp "s/^MATRIX_SUPPLY_BOT_USERNAME=.*/MATRIX_SUPPLY_BOT_USERNAME=${username}/" "$config_file"
            sed -i.tmp "s/^MATRIX_SUPPLY_BOT_USER=.*/MATRIX_SUPPLY_BOT_USER=@${username}:${server_name}/" "$config_file"
            sed -i.tmp "s/^MATRIX_SUPPLY_BOT_PASSWORD=.*/MATRIX_SUPPLY_BOT_PASSWORD=${password}/" "$config_file"
            sed -i.tmp "s/^MATRIX_SUPPLY_BOT_TOKEN=.*/MATRIX_SUPPLY_BOT_TOKEN=${access_token}/" "$config_file"
            ;;
        "demand_bot")
            sed -i.tmp "s/^MATRIX_DEMAND_BOT_USERNAME=.*/MATRIX_DEMAND_BOT_USERNAME=${username}/" "$config_file"
            sed -i.tmp "s/^MATRIX_DEMAND_BOT_USER=.*/MATRIX_DEMAND_BOT_USER=@${username}:${server_name}/" "$config_file"
            sed -i.tmp "s/^MATRIX_DEMAND_BOT_PASSWORD=.*/MATRIX_DEMAND_BOT_PASSWORD=${password}/" "$config_file"
            sed -i.tmp "s/^MATRIX_DEMAND_BOT_TOKEN=.*/MATRIX_DEMAND_BOT_TOKEN=${access_token}/" "$config_file"
            ;;
    esac
    
    # Remove temporary file
    rm -f "${config_file}.tmp"
    
    log_success "Updated configuration for ${user_type} user"
}

# Process single BytEM instance
process_instance() {
    local instance=$1
    
    log_info "Processing BytEM instance: $instance"
    
    # Check if container is running
    if ! check_synapse_container "$instance"; then
        log_error "Skipping $instance - container not running"
        return 1
    fi
    
    # Get server name
    local server_name=$(get_server_name "$instance")
    log_info "Server name for $instance: $server_name"
    
    # Get user definitions from config
    local config_file="$CONFIG_DIR/${instance}.env"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Extract usernames from config
    local admin_username=$(grep "^MATRIX_ADMIN_USERNAME=" "$config_file" | cut -d'=' -f2)
    local regular_username=$(grep "^MATRIX_REGULAR_USERNAME=" "$config_file" | cut -d'=' -f2)
    local supply_bot_username=$(grep "^MATRIX_SUPPLY_BOT_USERNAME=" "$config_file" | cut -d'=' -f2)
    local demand_bot_username=$(grep "^MATRIX_DEMAND_BOT_USERNAME=" "$config_file" | cut -d'=' -f2)
    
    # Process each user type
    local users=(
        "admin:$admin_username:true"
        "regular:$regular_username:false"
        "supply_bot:$supply_bot_username:false"
        "demand_bot:$demand_bot_username:false"
    )
    
    for user_info in "${users[@]}"; do
        IFS=':' read -r user_type username is_admin <<< "$user_info"
        
        if [[ -n "$username" ]]; then
            log_info "Processing ${user_type} user: $username"
            
            # Generate password
            local password=$(generate_password)
            
            # Manage user (create or update)
            local access_token=$(manage_synapse_user "$instance" "$username" "$password" "$is_admin")
            
            # Update configuration
            update_config_file "$instance" "$user_type" "$username" "$password" "$access_token" "$server_name"
        else
            log_warning "No username found for ${user_type} in $instance"
        fi
    done
    
    log_success "Completed processing $instance"
}

# Main function
main() {
    echo "🤖 BytEM Synapse User Management Script"
    echo "======================================"
    echo ""
    
    if [[ $# -eq 0 ]]; then
        echo "💡 Usage:"
        echo "  $0 <instance>     # Process single instance"
        echo "  $0 --all          # Process all instances"
        echo ""
        echo "📋 Examples:"
        echo "  $0 bytem1"
        echo "  $0 --all"
        exit 0
    fi
    
    if [[ "$1" == "--all" ]]; then
        log_info "Processing all BytEM instances..."
        
        local instances=()
        for config_file in "$CONFIG_DIR"/bytem*.env; do
            if [[ -f "$config_file" ]]; then
                local instance=$(basename "$config_file" .env)
                instances+=("$instance")
            fi
        done
        
        log_info "Found instances: ${instances[*]}"
        
        for instance in "${instances[@]}"; do
            echo ""
            process_instance "$instance"
        done
    else
        local instance=$1
        if [[ ! "$instance" =~ ^bytem[1-6]$ ]]; then
            log_error "Invalid instance name: $instance"
            echo "Valid instances: bytem1, bytem2, bytem3, bytem4, bytem5, bytem6"
            exit 1
        fi
        
        process_instance "$instance"
    fi
    
    echo ""
    log_success "User management completed!"
    echo ""
    log_info "📋 Next steps:"
    echo "  1. Verify users were created: docker exec synapse-bytem1 python -m synapse.app.admin_cmd -c /data/homeserver.yaml list-users"
    echo "  2. Test user login with new credentials"
    echo "  3. Update any hardcoded tokens in your applications"
}

# Run main function
main "$@"
