#!/bin/bash

###########################################
# ATON Server - 폐쇄망 환경 설치 스크립트
# 이 스크립트는 폐쇄망 환경에서 실행됩니다.
# 지원 OS: Ubuntu, Rocky Linux
###########################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# OS 감지
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "OS를 감지할 수 없습니다."
        exit 1
    fi

    case "$OS" in
        ubuntu|debian)
            PKG_TYPE="deb"
            PKG_DIR="deb_packages"
            log_info "감지된 OS: Ubuntu/Debian"
            ;;
        rocky|rhel|centos)
            PKG_TYPE="rpm"
            PKG_DIR="rpm_packages"
            log_info "감지된 OS: Rocky Linux/RHEL/CentOS"
            ;;
        *)
            log_error "지원하지 않는 OS입니다: $OS"
            exit 1
            ;;
    esac
}

# Root 권한 확인
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "이 스크립트는 root 또는 sudo 권한으로 실행해야 합니다"
        exit 1
    fi
}

# 시스템 시간 동기화
sync_time() {
    log_step "시스템 시간 동기화..."
    timedatectl set-ntp true

    if [ "$PKG_TYPE" = "rpm" ]; then
        systemctl restart chronyd || true
    else
        systemctl restart systemd-timesyncd || true
    fi
}

# DEB 패키지 설치 (Ubuntu/Debian)
install_deb_packages() {
    log_step "DEB 패키지 설치 중..."

    if [ ! -d "deb_packages" ]; then
        log_error "deb_packages 디렉토리를 찾을 수 없습니다"
        exit 1
    fi

    cd deb_packages

    # 패키지 개수 확인
    DEB_COUNT=$(ls -1 *.deb 2>/dev/null | wc -l)
    log_info "설치할 패키지: ${DEB_COUNT}개"

    if [ ${DEB_COUNT} -eq 0 ]; then
        log_error "설치할 DEB 패키지가 없습니다"
        exit 1
    fi

    # 모든 DEB 패키지 설치 (의존성 무시)
    log_info "1차 설치 시도 중..."
    dpkg -i *.deb 2>&1 | tee /tmp/dpkg_install.log || true

    # 의존성 문제가 있는지 확인
    if dpkg -l | grep -q "^iU\|^iF"; then
        log_info "의존성 문제 해결 중..."

        # APT 로컬 저장소 설정 (폐쇄망에서는 외부 연결 없이)
        log_info "로컬 패키지로 의존성 해결 시도..."

        # dpkg를 사용하여 강제로 설정
        dpkg --configure -a 2>/dev/null || true

        # 한번 더 설치 시도
        dpkg -i *.deb 2>/dev/null || true
    fi

    # 설치 확인
    if command -v docker &> /dev/null; then
        log_info "Docker 설치 확인: $(docker --version)"
    else
        log_warn "Docker 설치를 확인할 수 없습니다"
    fi

    cd ..

    log_info "DEB 패키지 설치 완료"
}

# RPM 패키지 설치 (Rocky Linux/RHEL)
install_rpm_packages() {
    log_step "RPM 패키지 설치 중..."

    if [ ! -d "rpm_packages" ]; then
        log_error "rpm_packages 디렉토리를 찾을 수 없습니다"
        exit 1
    fi

    cd rpm_packages

    # 패키지 개수 확인
    RPM_COUNT=$(ls -1 *.rpm 2>/dev/null | wc -l)
    log_info "설치할 패키지: ${RPM_COUNT}개"

    if [ ${RPM_COUNT} -eq 0 ]; then
        log_error "설치할 RPM 패키지가 없습니다"
        exit 1
    fi

    # EPEL 저장소 먼저 설치
    if ls epel-release*.rpm 1> /dev/null 2>&1; then
        log_info "EPEL 저장소 설치 중..."
        rpm -ivh --force ./epel-release*.rpm 2>&1 | tee /tmp/rpm_epel_install.log || log_warn "EPEL 설치 실패 (이미 설치되어 있을 수 있음)"
    fi

    # 모든 RPM 패키지 설치
    log_info "패키지 설치 중..."
    dnf install -y ./*.rpm --skip-broken --nobest 2>&1 | tee /tmp/rpm_install.log

    # 설치 확인
    if command -v docker &> /dev/null; then
        log_info "Docker 설치 확인: $(docker --version)"
    else
        log_warn "Docker 설치를 확인할 수 없습니다"
        log_warn "로그 확인: /tmp/rpm_install.log"
    fi

    cd ..

    log_info "RPM 패키지 설치 완료"
}

# 패키지 설치 (OS별 분기)
install_packages() {
    # Docker가 이미 설치되어 있는지 확인
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null)
        log_warn "Docker가 이미 설치되어 있습니다: ${DOCKER_VERSION}"
        read -p "패키지 설치를 건너뛰시겠습니까? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_info "패키지 설치를 건너뜁니다."
            return 0
        fi
    fi

    if [ "$PKG_TYPE" = "deb" ]; then
        install_deb_packages
    elif [ "$PKG_TYPE" = "rpm" ]; then
        install_rpm_packages
    fi
}

# Docker 서비스 시작
start_docker() {
    log_step "Docker 서비스 확인 중..."

    # Docker 서비스가 이미 실행 중인지 확인
    if systemctl is-active --quiet docker; then
        log_info "Docker 서비스가 이미 실행 중입니다."
        return 0
    fi

    log_step "Docker 서비스 시작 중..."
    systemctl start docker
    systemctl enable docker

    log_info "Docker 서비스 시작 완료"
}

# Docker 이미지 로드
load_docker_images() {
    log_step "Docker 이미지 로드 중..."

    cd docker_images

    for image in *.tar; do
        if [ -f "$image" ]; then
            log_info "이미지 로드: $image"
            docker load -i "$image"
        fi
    done

    cd ..

    log_info "Docker 이미지 로드 완료"
}

# 방화벽 설정
configure_firewall() {
    # firewalld (Rocky Linux)
    if systemctl is-active --quiet firewalld; then
        log_step "방화벽 설정 중 (firewalld)..."

        firewall-cmd --permanent --add-port=5000/tcp   # RESTful API
        firewall-cmd --permanent --add-port=8086/tcp   # InfluxDB
        firewall-cmd --permanent --add-port=31883/tcp  # MQTT

        firewall-cmd --reload

        log_info "방화벽 설정 완료"
    # ufw (Ubuntu)
    elif command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log_step "방화벽 설정 중 (ufw)..."

        ufw allow 5000/tcp   # RESTful API
        ufw allow 8086/tcp   # InfluxDB
        ufw allow 31883/tcp  # MQTT

        log_info "방화벽 설정 완료"
    else
        log_info "방화벽이 실행 중이 아닙니다. 방화벽 설정을 건너뜁니다."
    fi
}

# 사용자를 Docker 그룹에 추가
add_user_to_docker_group() {
    if [ -n "$SUDO_USER" ]; then
        log_step "사용자를 Docker 그룹에 추가 중..."
        usermod -aG docker "$SUDO_USER"
        log_info "사용자를 Docker 그룹에 추가했습니다. 로그아웃 후 다시 로그인하세요."
    fi
}

# 설치 확인
verify_installation() {
    log_step "설치 확인 중..."

    echo ""
    echo "===== 설치 요약 ====="

    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: $(docker --version)"
    else
        echo -e "${RED}✗${NC} Docker: 설치되지 않음"
    fi

    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker Compose: $(docker compose version)"
    else
        echo -e "${RED}✗${NC} Docker Compose: 설치되지 않음"
    fi

    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✓${NC} Docker 서비스: 실행 중"
    else
        echo -e "${RED}✗${NC} Docker 서비스: 실행 중이 아님"
    fi

    echo ""
    echo "Docker 이미지:"
    docker images

    echo "====================="
    echo ""
}

# 다음 단계 안내
show_next_steps() {
    log_info "폐쇄망 설치 완료!"
    echo ""
    echo "===== 다음 단계 ====="
    echo "1. 로그아웃 후 다시 로그인 (Docker 그룹 권한 적용)"
    echo "2. aton_server/aton_server_msa 디렉토리로 이동:"
    echo "   cd aton_server/aton_server_msa"
    echo "3. .env 파일 확인 및 수정 (필요시)"
    echo "4. 서비스 시작:"
    echo "   docker compose up -d"
    echo "5. 서비스 상태 확인:"
    echo "   docker compose ps"
    echo "6. 로그 확인:"
    echo "   docker compose logs -f"
    echo ""
    echo "===== 서비스 엔드포인트 ====="
    echo "- RESTful API: http://localhost:5000"
    echo "- InfluxDB: http://localhost:8086"
    echo "- MQTT Broker: mqtt://localhost:31883"
    echo "=========================="
    echo ""
}

# 메인 실행
main() {
    log_info "ATON Server 폐쇄망 환경 설치 시작..."
    echo ""

    detect_os
    check_root
    sync_time
    install_packages
    start_docker
    load_docker_images
    configure_firewall
    add_user_to_docker_group
    verify_installation
    show_next_steps

    log_info "설치 스크립트 완료!"
}

main "$@"
