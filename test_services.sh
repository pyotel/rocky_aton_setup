#!/bin/bash

###########################################
# ATON Server Services Test Script
# Tests all ATON Server MSA services
###########################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service directory
ATON_DIR="aton_server/aton_server_msa"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if directory exists
check_directory() {
    if [ ! -d "$ATON_DIR" ]; then
        log_error "Directory $ATON_DIR not found!"
        log_info "Please make sure you are in the rocky_aton_setup directory"
        exit 1
    fi
    log_success "Found ATON Server directory"
}

# Check Docker installation
check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_info "Please run: sudo ./setup_aton_server.sh"
        exit 1
    fi
    log_success "Docker is installed: $(docker --version)"
}

# Check Docker Compose installation
check_docker_compose() {
    log_info "Checking Docker Compose installation..."
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose is installed: $(docker-compose --version)"
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        log_success "Docker Compose Plugin is installed: $(docker compose version)"
        COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose is not installed!"
        log_info "Please run: sudo ./setup_aton_server.sh"
        exit 1
    fi
}

# Check Docker service
check_docker_service() {
    log_info "Checking Docker service..."
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        log_warn "Docker service is not running"
        log_info "Starting Docker service..."
        sudo systemctl start docker
    fi
    log_success "Docker service is running"
}

# Check Docker permissions
check_docker_permissions() {
    log_info "Checking Docker permissions..."
    if ! docker ps &> /dev/null; then
        log_error "Permission denied for Docker"
        log_info "Please run: sudo usermod -aG docker $USER"
        log_info "Then log out and log back in"
        return 1
    fi
    log_success "Docker permissions OK"
}

# Start services
start_services() {
    log_info "Starting ATON Server services..."
    cd "$ATON_DIR" || exit 1

    $COMPOSE_CMD up -d

    if [ $? -eq 0 ]; then
        log_success "Services started successfully"
    else
        log_error "Failed to start services"
        return 1
    fi

    cd - > /dev/null || exit 1
}

# Check container status
check_containers() {
    log_info "Checking container status..."
    cd "$ATON_DIR" || exit 1

    echo ""
    echo "===== Container Status ====="
    $COMPOSE_CMD ps
    echo "============================"
    echo ""

    cd - > /dev/null || exit 1
}

# Test InfluxDB
test_influxdb() {
    log_info "Testing InfluxDB (port 8086)..."

    sleep 5  # Wait for InfluxDB to fully start

    local max_attempts=12
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:8086/ping > /dev/null 2>&1; then
            log_success "InfluxDB is responding"
            return 0
        fi
        log_warn "InfluxDB not ready yet (attempt $attempt/$max_attempts)..."
        sleep 5
        ((attempt++))
    done

    log_error "InfluxDB is not responding"
    return 1
}

# Test MQTT Broker
test_mqtt() {
    log_info "Testing MQTT Broker (port 31883)..."

    if ! command -v mosquitto_pub &> /dev/null; then
        log_warn "mosquitto-clients not installed, skipping MQTT test"
        log_info "To install: sudo dnf install -y mosquitto"
        return 0
    fi

    # Test MQTT connection
    if timeout 5 mosquitto_pub -h localhost -p 31883 -t "test/topic" -m "test" -u keti -P keti1234 2>/dev/null; then
        log_success "MQTT Broker is responding"
    else
        log_error "MQTT Broker connection failed"
        return 1
    fi
}

# Test RESTful API
test_api() {
    log_info "Testing RESTful API (port 5000)..."

    local max_attempts=12
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:5000 > /dev/null 2>&1; then
            log_success "RESTful API is responding"
            return 0
        fi
        log_warn "RESTful API not ready yet (attempt $attempt/$max_attempts)..."
        sleep 5
        ((attempt++))
    done

    log_error "RESTful API is not responding"
    return 1
}

# Show service logs
show_logs() {
    log_info "Showing recent logs..."
    cd "$ATON_DIR" || exit 1

    echo ""
    echo "===== Recent Logs ====="
    $COMPOSE_CMD logs --tail=20
    echo "======================="
    echo ""

    cd - > /dev/null || exit 1
}

# Summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "           Test Summary"
    echo "=========================================="
    echo ""

    cd "$ATON_DIR" || exit 1

    # Check each service
    services=("influxdb" "mosquitto" "comm2center" "restfulapi")

    for service in "${services[@]}"; do
        if $COMPOSE_CMD ps | grep -q "$service.*Up"; then
            echo -e "${GREEN}✓${NC} $service: Running"
        else
            echo -e "${RED}✗${NC} $service: Not running"
        fi
    done

    cd - > /dev/null || exit 1

    echo ""
    echo "Service Endpoints:"
    echo "  - RESTful API: http://localhost:5000"
    echo "  - InfluxDB: http://localhost:8086"
    echo "  - MQTT Broker: mqtt://localhost:31883"
    echo ""
    echo "Useful Commands:"
    echo "  View logs: cd $ATON_DIR && $COMPOSE_CMD logs -f"
    echo "  Stop services: cd $ATON_DIR && $COMPOSE_CMD stop"
    echo "  Restart services: cd $ATON_DIR && $COMPOSE_CMD restart"
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    echo ""
    log_info "ATON Server MSA Service Test"
    echo ""

    check_directory
    check_docker
    check_docker_compose
    check_docker_service

    if ! check_docker_permissions; then
        exit 1
    fi

    start_services

    echo ""
    log_info "Waiting for services to start..."
    sleep 10
    echo ""

    check_containers

    # Run tests
    test_influxdb
    test_api
    test_mqtt

    show_logs
    show_summary

    log_success "Service test completed!"
}

# Run main function
main "$@"
