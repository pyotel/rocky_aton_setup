#!/bin/bash

###########################################
# ATON Server MSA Setup Script for Rocky Linux 9
# This script installs all required dependencies and sets up
# the ATON Server MSA environment
###########################################

sudo timedatectl set-ntp true
sudo systemctl restart chronyd

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Update system
update_system() {
    log_info "Updating system packages..."
    dnf update -y
    dnf install -y epel-release
    log_info "System update completed"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_warn "Docker is already installed"
        docker --version
    else
        log_info "Installing Docker..."

        # Remove old versions if they exist
        dnf remove -y docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-engine \
                      podman \
                      runc 2>/dev/null || true

        # Install required packages
        dnf install -y dnf-plugins-core

        # Add Docker repository
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

        # Install Docker Engine
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Start and enable Docker
        systemctl start docker
        systemctl enable docker

        log_info "Docker installed successfully"
        docker --version
    fi
}

# Install Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log_warn "Docker Compose is already installed"
        docker compose version 2>/dev/null || docker-compose --version
    else
        log_info "Installing Docker Compose (standalone)..."

        # Get latest version
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

        # Download and install
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # Create symlink
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

        log_info "Docker Compose installed successfully"
        docker-compose --version
    fi
}

# Install Git (if not already installed)
install_git() {
    if command -v git &> /dev/null; then
        log_warn "Git is already installed"
        git --version
    else
        log_info "Installing Git..."
        dnf install -y git
        log_info "Git installed successfully"
        git --version
    fi
}

# Install additional utilities
install_utilities() {
    log_info "Installing additional utilities..."
    dnf install -y \
        curl \
        wget \
        vim \
        net-tools \
        bind-utils \
        tar \
        gzip
    log_info "Utilities installed successfully"
}

# Configure firewall
configure_firewall() {
    if systemctl is-active --quiet firewalld; then
        log_info "Configuring firewall..."

        # Allow required ports
        firewall-cmd --permanent --add-port=5000/tcp   # RESTful API
        firewall-cmd --permanent --add-port=8086/tcp   # InfluxDB
        firewall-cmd --permanent --add-port=31883/tcp  # MQTT

        firewall-cmd --reload

        log_info "Firewall configured successfully"
    else
        log_warn "Firewalld is not running. Skipping firewall configuration."
    fi
}

# Add user to docker group
add_user_to_docker_group() {
    if [ -n "$SUDO_USER" ]; then
        log_info "Adding user $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER"
        log_info "User added to docker group. Please log out and log back in for changes to take effect."
    else
        log_warn "Could not determine non-root user. Please manually add your user to the docker group:"
        log_warn "  sudo usermod -aG docker <your-username>"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    echo ""
    echo "===== Installation Summary ====="

    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: $(docker --version)"
    else
        echo -e "${RED}✗${NC} Docker: Not installed"
    fi

    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version)"
    else
        echo -e "${RED}✗${NC} Docker Compose: Not installed"
    fi

    if command -v git &> /dev/null; then
        echo -e "${GREEN}✓${NC} Git: $(git --version)"
    else
        echo -e "${RED}✗${NC} Git: Not installed"
    fi

    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✓${NC} Docker service: Running"
    else
        echo -e "${RED}✗${NC} Docker service: Not running"
    fi

    echo "==============================="
    echo ""
}

# Display next steps
show_next_steps() {
    log_info "Setup completed successfully!"
    echo ""
    echo "===== Next Steps ====="
    echo "1. If you added your user to the docker group, log out and log back in"
    echo "2. Navigate to the aton_server_msa directory:"
    echo "   cd aton_server/aton_server_msa"
    echo "3. Review and edit the .env file if needed"
    echo "4. Start the services:"
    echo "   docker-compose up -d"
    echo "5. Check service status:"
    echo "   docker-compose ps"
    echo "6. View logs:"
    echo "   docker-compose logs -f"
    echo ""
    echo "===== Service Endpoints ====="
    echo "- RESTful API: http://localhost:5000"
    echo "- InfluxDB: http://localhost:8086"
    echo "- MQTT Broker: mqtt://localhost:31883"
    echo "======================"
    echo ""
}

# Main execution
main() {
    log_info "Starting ATON Server MSA setup for Rocky Linux 9..."
    echo ""

    check_root
    update_system
    install_git
    install_utilities
    install_docker
    install_docker_compose
    configure_firewall
    add_user_to_docker_group
    verify_installation
    show_next_steps

    log_info "Setup script completed!"
}

# Run main function
main "$@"


