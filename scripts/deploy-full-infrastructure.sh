#!/bin/bash

#
# BytEM Full Infrastructure Deployment Script
# 
# Completely recreates BytEM infrastructure with:
# - All containers (Synapse, RabbitMQ, Solr, SFTP)
# - All Synapse users (admin, regular, supply bot, demand bot)
# - Updated configuration files with new credentials
# 
# Usage:
#   ./scripts/deploy-full-infrastructure.sh [--force]
# 
# Options:
#   --force    Skip confirmation prompts
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose-multi-infrastructure.yml"

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

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "docker-compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check if compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Stop and remove existing containers
cleanup_existing_containers() {
    log_step "Cleaning up existing containers..."
    
    # Stop containers if they're running
    if docker-compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
        log_info "Stopping existing containers..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # Remove any orphaned containers
    log_info "Removing orphaned containers..."
    docker container prune -f >/dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

# Pull latest images
pull_images() {
    log_step "Pulling latest Docker images..."
    
    docker-compose -f "$COMPOSE_FILE" pull
    
    log_success "Images pulled successfully"
}

# Start infrastructure containers
start_containers() {
    log_step "Starting infrastructure containers..."
    
    # Start containers in detached mode
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for containers to be healthy
    log_info "Waiting for containers to start..."
    sleep 30
    
    # Check container status
    log_info "Container status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    log_success "Infrastructure containers started"
}

# Wait for services to be ready
wait_for_services() {
    log_step "Waiting for services to be ready..."
    
    # Wait for Synapse instances
    local instances=("bytem1" "bytem2")
    for instance in "${instances[@]}"; do
        log_info "Waiting for Synapse $instance to be ready..."
        local container_name="synapse-${instance}"
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if docker exec "$container_name" curl -s http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
                log_success "Synapse $instance is ready"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Synapse $instance failed to start after ${max_attempts} attempts"
                return 1
            fi
            
            log_info "Attempt $attempt/$max_attempts - waiting 10 seconds..."
            sleep 10
            ((attempt++))
        done
    done
    
    # Wait for RabbitMQ instances
    for instance in "${instances[@]}"; do
        log_info "Waiting for RabbitMQ $instance to be ready..."
        local container_name="rabbitmq-${instance}"
        local max_attempts=15
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if docker exec "$container_name" rabbitmqctl status >/dev/null 2>&1; then
                log_success "RabbitMQ $instance is ready"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "RabbitMQ $instance failed to start after ${max_attempts} attempts"
                return 1
            fi
            
            log_info "Attempt $attempt/$max_attempts - waiting 10 seconds..."
            sleep 10
            ((attempt++))
        done
    done
    
    # Wait for Solr instances
    for instance in "${instances[@]}"; do
        log_info "Waiting for Solr $instance to be ready..."
        local container_name="solr-${instance}"
        local max_attempts=15
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if docker exec "$container_name" curl -s http://localhost:8983/solr/admin/cores >/dev/null 2>&1; then
                log_success "Solr $instance is ready"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Solr $instance failed to start after ${max_attempts} attempts"
                return 1
            fi
            
            log_info "Attempt $attempt/$max_attempts - waiting 10 seconds..."
            sleep 10
            ((attempt++))
        done
    done
    
    log_success "All services are ready"
}

# Setup Synapse users
setup_synapse_users() {
    log_step "Setting up Synapse users..."
    
    if [[ -x "$SCRIPT_DIR/manage-synapse-users.sh" ]]; then
        "$SCRIPT_DIR/manage-synapse-users.sh" --all
    else
        log_error "User management script not found or not executable: $SCRIPT_DIR/manage-synapse-users.sh"
        return 1
    fi
    
    log_success "Synapse users setup completed"
}

# Display deployment summary
show_deployment_summary() {
    log_step "Deployment Summary"
    echo ""
    echo "🎉 BytEM Infrastructure Deployed Successfully!"
    echo "=============================================="
    echo ""
    echo "📊 Services Status:"
    docker-compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}"
    echo ""
    echo "🌐 Service Endpoints:"
    echo "===================="
    echo "• Synapse BytEM1:     http://localhost:8008"
    echo "• Synapse BytEM2:     http://localhost:8009"
    echo "• RabbitMQ BytEM1:    http://localhost:15672 (admin:bytem1/bytem1_pass)"
    echo "• RabbitMQ BytEM2:    http://localhost:15673 (admin:bytem2/bytem2_pass)"
    echo "• Solr BytEM1:        http://localhost:8983"
    echo "• Solr BytEM2:        http://localhost:8984"
    echo "• SFTP BytEM1:        sftp://localhost:2222 (user:solr/solr_pass)"
    echo "• SFTP BytEM2:        sftp://localhost:2223 (user:solr/solr_pass)"
    echo ""
    echo "🔑 Matrix Federation:"
    echo "===================="
    echo "• BytEM1 Federation:  localhost:8448"
    echo "• BytEM2 Federation:  localhost:8449"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Test Matrix user login with updated credentials"
    echo "2. Verify federation between instances"
    echo "3. Test SFTP file upload functionality"
    echo "4. Start local development services:"
    echo "   CONFIG_TYPE=bytem1 node liberbyte/bytem/exchange/server.js"
    echo "   CONFIG_TYPE=bytem1 node liberbyte/bytem/bot/src/index.js"
    echo ""
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
    
    echo "🚀 BytEM Full Infrastructure Deployment"
    echo "======================================="
    echo ""
    echo "This script will:"
    echo "• Stop and remove all existing containers"
    echo "• Pull latest Docker images"
    echo "• Start all infrastructure services"
    echo "• Create/update all Synapse users"
    echo "• Update configuration files with new credentials"
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
    log_step "Starting BytEM infrastructure deployment..."
    
    # Execute deployment steps
    check_prerequisites
    cleanup_existing_containers
    pull_images
    start_containers
    wait_for_services
    setup_synapse_users
    show_deployment_summary
    
    echo ""
    log_success "🎉 BytEM infrastructure deployment completed successfully!"
}

# Error handling
trap 'log_error "Deployment failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"
