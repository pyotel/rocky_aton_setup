#!/bin/bash

###########################################
# Prerequisites Check Script
# Checks if all required software is installed
###########################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

ISSUES_FOUND=0

echo ""
echo "=========================================="
echo "   ATON Server Prerequisites Check"
echo "=========================================="
echo ""

# Check OS
log_info "Checking Operating System..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "rocky" ]]; then
        log_success "OS: Rocky Linux $VERSION_ID"
    else
        log_warn "OS: $PRETTY_NAME (expected Rocky Linux)"
    fi
else
    log_warn "Could not determine OS version"
fi
echo ""

# Check Docker
log_info "Checking Docker..."
if command -v docker &> /dev/null; then
    VERSION=$(docker --version 2>/dev/null)
    log_success "Docker installed: $VERSION"

    # Check Docker service
    if systemctl is-active --quiet docker 2>/dev/null; then
        log_success "Docker service is running"
    else
        log_error "Docker service is not running"
        log_info "  Run: sudo systemctl start docker"
        ((ISSUES_FOUND++))
    fi

    # Check Docker permissions
    if docker ps &> /dev/null; then
        log_success "Docker permissions OK"
    else
        log_error "No permission to access Docker"
        log_info "  Run: sudo usermod -aG docker $USER"
        log_info "  Then log out and log back in"
        ((ISSUES_FOUND++))
    fi
else
    log_error "Docker is not installed"
    log_info "  Run: sudo ./setup_aton_server.sh"
    ((ISSUES_FOUND++))
fi
echo ""

# Check Docker Compose
log_info "Checking Docker Compose..."
COMPOSE_FOUND=0

if command -v docker-compose &> /dev/null; then
    VERSION=$(docker-compose --version 2>/dev/null)
    log_success "Docker Compose installed: $VERSION"
    COMPOSE_FOUND=1
elif docker compose version &> /dev/null 2>&1; then
    VERSION=$(docker compose version 2>/dev/null)
    log_success "Docker Compose Plugin installed: $VERSION"
    COMPOSE_FOUND=1
fi

if [ $COMPOSE_FOUND -eq 0 ]; then
    log_error "Docker Compose is not installed"
    log_info "  Run: sudo ./setup_aton_server.sh"
    ((ISSUES_FOUND++))
fi
echo ""

# Check Git
log_info "Checking Git..."
if command -v git &> /dev/null; then
    VERSION=$(git --version)
    log_success "Git installed: $VERSION"
else
    log_warn "Git is not installed (optional)"
    log_info "  Run: sudo dnf install -y git"
fi
echo ""

# Check required ports
log_info "Checking required ports..."
PORTS=("5000:RESTful API" "8086:InfluxDB" "31883:MQTT")

for port_info in "${PORTS[@]}"; do
    PORT="${port_info%%:*}"
    SERVICE="${port_info#*:}"

    if command -v netstat &> /dev/null; then
        if sudo netstat -tulpn 2>/dev/null | grep -q ":$PORT "; then
            log_warn "Port $PORT ($SERVICE) is already in use"
            log_info "  Check: sudo netstat -tulpn | grep $PORT"
        else
            log_success "Port $PORT ($SERVICE) is available"
        fi
    elif command -v ss &> /dev/null; then
        if sudo ss -tulpn 2>/dev/null | grep -q ":$PORT "; then
            log_warn "Port $PORT ($SERVICE) is already in use"
            log_info "  Check: sudo ss -tulpn | grep $PORT"
        else
            log_success "Port $PORT ($SERVICE) is available"
        fi
    else
        log_warn "Cannot check port availability (netstat/ss not found)"
        break
    fi
done
echo ""

# Check firewall
log_info "Checking firewall..."
if systemctl is-active --quiet firewalld 2>/dev/null; then
    log_info "Firewalld is active"

    REQUIRED_PORTS=("5000/tcp" "8086/tcp" "31883/tcp")
    for port in "${REQUIRED_PORTS[@]}"; do
        if sudo firewall-cmd --list-ports 2>/dev/null | grep -q "$port"; then
            log_success "Firewall: Port $port is open"
        else
            log_warn "Firewall: Port $port is not open"
            log_info "  Run: sudo firewall-cmd --permanent --add-port=$port && sudo firewall-cmd --reload"
        fi
    done
elif systemctl is-active --quiet ufw 2>/dev/null; then
    log_info "UFW firewall is active"
    log_warn "Please ensure ports 5000, 8086, and 31883 are allowed"
else
    log_info "No firewall detected or firewall is inactive"
fi
echo ""

# Check disk space
log_info "Checking disk space..."
AVAILABLE=$(df -h . | awk 'NR==2 {print $4}')
log_info "Available disk space: $AVAILABLE"
echo ""

# Check memory
log_info "Checking memory..."
if command -v free &> /dev/null; then
    TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
    AVAILABLE_MEM=$(free -h | awk '/^Mem:/ {print $7}')
    log_info "Total memory: $TOTAL_MEM, Available: $AVAILABLE_MEM"
else
    log_warn "Cannot check memory (free command not found)"
fi
echo ""

# Check ATON server directory
log_info "Checking ATON Server directory..."
if [ -d "aton_server/aton_server_msa" ]; then
    log_success "ATON Server directory found"

    if [ -f "aton_server/aton_server_msa/docker-compose.yml" ]; then
        log_success "docker-compose.yml found"
    else
        log_error "docker-compose.yml not found"
        ((ISSUES_FOUND++))
    fi

    if [ -f "aton_server/aton_server_msa/.env" ]; then
        log_success ".env file found"
    else
        log_warn ".env file not found"
    fi
else
    log_error "ATON Server directory not found"
    log_info "  The repository should be at: aton_server/aton_server_msa"
    ((ISSUES_FOUND++))
fi
echo ""

# Summary
echo "=========================================="
echo "              Summary"
echo "=========================================="
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    log_success "All prerequisites are met!"
    echo ""
    echo "You can now start the ATON Server:"
    echo "  ./test_services.sh"
    echo ""
    echo "Or manually:"
    echo "  cd aton_server/aton_server_msa"
    echo "  docker-compose up -d"
else
    log_error "Found $ISSUES_FOUND issue(s) that need to be resolved"
    echo ""
    echo "To install missing prerequisites:"
    echo "  sudo ./setup_aton_server.sh"
    echo ""
    echo "For detailed instructions, see:"
    echo "  INSTALL_INSTRUCTIONS.md"
fi

echo "=========================================="
echo ""

exit $ISSUES_FOUND
