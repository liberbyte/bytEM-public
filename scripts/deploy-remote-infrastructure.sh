#!/bin/bash

#
# BytEM Remote Infrastructure Deployment Script
# 
# Deploys BytEM infrastructure to remote server 10.0.0.151 using domain names:
# - bytem1.liberbyte.app
# - bytem.environment.app  
# - bytem.cities.app
# 
# Usage:
#   ./scripts/deploy-remote-infrastructure.sh [--force]
# 
# Options:
#   --force    Skip confirmation prompts
#

set -e

# Configuration
REMOTE_HOST="10.0.0.151"
REMOTE_USER="david"
REMOTE_PATH="/www/wwwroot/bytem-docker"
PROJECT_NAME="bytem-docker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}🚀 $1${NC}"
}

# Remote command execution
run_remote() {
    sshpass -p 'Remember7!' ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "$1"
}

run_remote_sudo() {
    sshpass -p 'Remember7!' ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "echo 'Remember7!' | sudo -S $1"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if sshpass is available
    if ! command -v sshpass >/dev/null 2>&1; then
        log_error "sshpass is not installed. Install with: brew install sshpass"
        exit 1
    fi
    
    # Test remote connection
    log_info "Testing remote connection to $REMOTE_HOST..."
    if ! run_remote "echo 'Connection test successful'"; then
        log_error "Cannot connect to remote server $REMOTE_HOST"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create deployment package
create_deployment_package() {
    log_step "Creating deployment package..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    local package_file="$temp_dir/bytem-infrastructure.tar.gz"
    
    log_info "Creating deployment package: $package_file"
    
    # Create tar package with required files
    tar -czf "$package_file" \
        docker-compose-multi-infrastructure.yml \
        synapse-config/ \
        config/ \
        scripts/manage-synapse-users.sh \
        scripts/update-federation-whitelist.js
    
    echo "$package_file"
}

# Deploy to remote server
deploy_to_remote() {
    local package_file=$1
    
    log_step "Deploying to remote server..."
    
    # Upload deployment package
    log_info "Uploading deployment package to $REMOTE_HOST..."
    sshpass -p 'Remember7!' scp -o StrictHostKeyChecking=no "$package_file" "david@10.0.0.151:/tmp/bytem-infrastructure.tar.gz"
    
    # Create project directory
    log_info "Creating project directory..."
    run_remote_sudo "mkdir -p $REMOTE_PATH"
    run_remote_sudo "chown -R $REMOTE_USER:$REMOTE_USER $REMOTE_PATH"
    
    # Extract deployment package
    log_info "Extracting deployment package..."
    run_remote "cd $REMOTE_PATH && tar -xzf /tmp/bytem-infrastructure.tar.gz"
    
    # Set permissions
    log_info "Setting permissions..."
    run_remote "chmod +x $REMOTE_PATH/scripts/*.sh"
    
    # Clean up
    run_remote "rm -f /tmp/bytem-infrastructure.tar.gz"
    
    log_success "Deployment package deployed to remote server"
}

# Update hosts file on remote server
update_remote_hosts() {
    log_step "Updating remote server hosts file..."
    
    # Add domain entries to /etc/hosts if not already present
    local hosts_entries=(
        "127.0.0.1 bytem1.liberbyte.app"
        "127.0.0.1 bytem.environment.app"
        "127.0.0.1 bytem.cities.app"
    )
    
    for entry in "${hosts_entries[@]}"; do
        log_info "Adding hosts entry: $entry"
        run_remote_sudo "grep -q '$entry' /etc/hosts || echo '$entry' >> /etc/hosts"
    done
    
    log_success "Hosts file updated"
}

# Start infrastructure on remote server
start_remote_infrastructure() {
    log_step "Starting infrastructure on remote server..."
    
    # Stop any existing containers
    log_info "Stopping existing containers..."
    run_remote "cd $REMOTE_PATH && docker-compose -f docker-compose-multi-infrastructure.yml down || true"
    
    # Pull latest images
    log_info "Pulling latest Docker images..."
    run_remote "cd $REMOTE_PATH && docker-compose -f docker-compose-multi-infrastructure.yml pull"
    
    # Start infrastructure
    log_info "Starting infrastructure containers..."
    run_remote "cd $REMOTE_PATH && docker-compose -f docker-compose-multi-infrastructure.yml up -d"
    
    # Wait for services
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check status
    log_info "Checking container status..."
    run_remote "cd $REMOTE_PATH && docker-compose -f docker-compose-multi-infrastructure.yml ps"
    
    log_success "Infrastructure started on remote server"
}

# Setup users on remote Synapse
setup_remote_users() {
    log_step "Setting up Synapse users on remote server..."
    
    # Wait for Synapse to be ready
    log_info "Waiting for Synapse instances to be ready..."
    sleep 60
    
    # Run user management script on remote server
    log_info "Creating/updating Synapse users..."
    run_remote "cd $REMOTE_PATH && ./scripts/manage-synapse-users.sh --all"
    
    log_success "Synapse users setup completed"
}

# Display deployment summary
show_deployment_summary() {
    log_step "Remote Deployment Summary"
    echo ""
    echo "🎉 BytEM Infrastructure Deployed to Remote Server!"
    echo "=================================================="
    echo ""
    echo "🌐 Server: $REMOTE_HOST"
    echo "📁 Path: $REMOTE_PATH"
    echo ""
    echo "🔗 Service Endpoints (via domain names):"
    echo "========================================"
    echo "• Synapse BytEM1:     http://bytem1.liberbyte.app:8008"
    echo "• Synapse BytEM2:     http://bytem.environment.app:8009"
    echo "• RabbitMQ BytEM1:    http://bytem1.liberbyte.app:15672"
    echo "• RabbitMQ BytEM2:    http://bytem.environment.app:15673"
    echo "• Solr BytEM1:        http://bytem1.liberbyte.app:8983"
    echo "• Solr BytEM2:        http://bytem.environment.app:8984"
    echo "• SFTP BytEM1:        sftp://bytem1.liberbyte.app:2222"
    echo "• SFTP BytEM2:        sftp://bytem.environment.app:2223"
    echo ""
    echo "🔑 Matrix Federation:"
    echo "===================="
    echo "• BytEM1 Federation:  bytem1.liberbyte.app:8448"
    echo "• BytEM2 Federation:  bytem.environment.app:8449"
    echo ""
    echo "📋 Local Development:"
    echo "===================="
    echo "Start local services that connect to remote infrastructure:"
    echo "  CONFIG_TYPE=bytem1 node liberbyte/bytem/exchange/server.js"
    echo "  CONFIG_TYPE=bytem1 node liberbyte/bytem/bot/src/index.js"
    echo "  CONFIG_TYPE=bytem1 yarn start:bytem1"
    echo ""
    echo "🎯 Infrastructure is ready for local development!"
}

# Main deployment function
main() {
    local force_flag=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Usage: $0 [--force]"
                exit 1
                ;;
        esac
    done
    
    echo "🚀 BytEM Remote Infrastructure Deployment"
    echo "========================================="
    echo ""
    echo "Target Server: $REMOTE_HOST"
    echo "Deploy Path: $REMOTE_PATH"
    echo ""
    echo "This script will:"
    echo "• Deploy infrastructure to remote server using domain names"
    echo "• Start all containers (Synapse, RabbitMQ, Solr, SFTP)"
    echo "• Create/update all Synapse users"
    echo "• Update configuration with new credentials"
    echo ""
    
    if [[ "$force_flag" != "true" ]]; then
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    echo ""
    log_step "Starting remote infrastructure deployment..."
    
    # Execute deployment steps
    check_prerequisites
    
    local package_file=$(create_deployment_package)
    deploy_to_remote "$package_file"
    update_remote_hosts
    start_remote_infrastructure
    setup_remote_users
    show_deployment_summary
    
    # Cleanup
    rm -f "$package_file"
    
    echo ""
    log_success "🎉 Remote infrastructure deployment completed successfully!"
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"
