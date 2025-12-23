#!/bin/bash

###########################################
# ATON Server - 폐쇄망 환경 준비 스크립트
# 이 스크립트는 인터넷이 연결된 환경에서 실행하여
# 폐쇄망 환경에 필요한 모든 파일을 준비합니다.
# 타겟 OS: Rocky Linux (기본값)
###########################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 타겟 OS 설정 (기본값: Rocky Linux)
TARGET_OS="${TARGET_OS:-rocky}"

# 타겟 OS에 따른 패키지 타입 설정
set_target_package_type() {
    case "$TARGET_OS" in
        ubuntu|debian)
            PKG_TYPE="deb"
            PKG_DIR="deb_packages"
            log_info "타겟 OS: Ubuntu/Debian"
            log_warn "현재 시스템이 Ubuntu/Debian이 아니면 DEB 패키지 다운로드가 실패할 수 있습니다."
            ;;
        rocky|rhel|centos)
            PKG_TYPE="rpm"
            PKG_DIR="rpm_packages"
            log_info "타겟 OS: Rocky Linux/RHEL/CentOS"
            log_warn "현재 시스템이 Rocky/RHEL/CentOS가 아니면 RPM 패키지 다운로드가 실패할 수 있습니다."
            ;;
        *)
            log_error "지원하지 않는 타겟 OS입니다: $TARGET_OS"
            log_error "지원 OS: ubuntu, debian, rocky, rhel, centos"
            exit 1
            ;;
    esac
}

# 현재 시스템 OS 확인
check_current_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        CURRENT_OS=$ID
        log_info "현재 시스템 OS: $CURRENT_OS"
    else
        log_warn "현재 OS를 감지할 수 없습니다."
    fi
}

# 작업 디렉토리 설정
EXPORT_DIR="./airgap_package"
IMAGES_DIR="${EXPORT_DIR}/docker_images"
SCRIPTS_DIR="${EXPORT_DIR}/scripts"

# Python 패키지 디렉토리
PIP_DIR="${EXPORT_DIR}/pip_packages"

# 디렉토리 생성
prepare_directories() {
    log_step "작업 디렉토리 준비 중..."

    mkdir -p "${IMAGES_DIR}"
    mkdir -p "${EXPORT_DIR}/${PKG_DIR}"
    mkdir -p "${SCRIPTS_DIR}"
    mkdir -p "${PIP_DIR}"

    log_info "디렉토리 생성 완료"
}

# Docker 이미지 빌드 및 저장
export_docker_images() {
    log_step "Docker 이미지 빌드 및 저장 중..."

    cd aton_server/aton_server_msa

    # .env 파일 확인
    if [ ! -f .env ]; then
        log_error ".env 파일이 없습니다. 먼저 .env 파일을 생성하세요."
        exit 1
    fi

    # .env 파일 로드
    source .env

    log_info "Docker Compose 이미지 빌드 중..."
    docker compose build

    # InfluxDB 이미지 다운로드 및 저장
    log_info "InfluxDB 이미지 저장 중..."
    docker pull influxdb:1.8
    docker save influxdb:1.8 -o ../../${IMAGES_DIR}/influxdb_1.8.tar

    # Mosquitto 이미지 저장
    log_info "Mosquitto 이미지 저장 중..."
    MOSQUITTO_VERSION=${MOSQUITTO_VERSION:-1.5.6}
    docker save eclipse-mosquitto:${MOSQUITTO_VERSION} -o ../../${IMAGES_DIR}/mosquitto_${MOSQUITTO_VERSION}.tar

    # comm2center 이미지 저장
    log_info "comm2center 이미지 저장 중..."
    docker save aton_server_msa-comm2center:latest -o ../../${IMAGES_DIR}/comm2center.tar

    # restfulapi 이미지 저장
    log_info "restfulapi 이미지 저장 중..."
    docker save aton_server_msa-restfulapi:latest -o ../../${IMAGES_DIR}/restfulapi.tar

    cd ../..

    log_info "Docker 이미지 저장 완료"
}

# 패키지 다운로드 (OS별 분기)
download_packages() {
    log_step "패키지 다운로드 중..."

    cd "${EXPORT_DIR}/${PKG_DIR}"

    if [ "$PKG_TYPE" = "deb" ]; then
        download_deb_packages
    elif [ "$PKG_TYPE" = "rpm" ]; then
        download_rpm_packages
    fi

    cd ../..

    log_info "패키지 다운로드 완료"
}

# DEB 패키지 다운로드 (Ubuntu/Debian)
download_deb_packages() {
    log_info "DEB 패키지 다운로드 중..."

    # apt 캐시 업데이트
    log_info "APT 캐시 업데이트 중..."
    apt-get update

    # 캐시 디렉토리 정리
    apt-get clean
    rm -rf /var/cache/apt/archives/*.deb

    # Docker 저장소 확인
    log_info "Docker 저장소 확인 중..."
    if ! grep -q "download.docker.com" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_warn "Docker 저장소가 설정되어 있지 않습니다. Docker 공식 저장소 추가 방법:"
        log_warn "  sudo apt-get install -y ca-certificates curl"
        log_warn "  sudo install -m 0755 -d /etc/apt/keyrings"
        log_warn "  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
        log_warn "  sudo chmod a+r /etc/apt/keyrings/docker.asc"
        log_warn "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
        log_warn "  sudo apt-get update"
    fi

    # Docker 관련 패키지와 모든 의존성 다운로드
    log_info "Docker 패키지 및 의존성 다운로드 중..."
    apt-get install --download-only -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Git 및 의존성 다운로드
    log_info "Git 패키지 다운로드 중..."
    apt-get install --download-only -y git

    # 유틸리티 패키지 다운로드
    log_info "유틸리티 패키지 다운로드 중..."
    apt-get install --download-only -y \
        curl \
        wget \
        vim \
        net-tools \
        dnsutils \
        tar \
        gzip \
        rsync \
        ca-certificates \
        gnupg \
        lsb-release

    # 다운로드된 모든 패키지 복사
    log_info "패키지 복사 중..."
    if [ -d /var/cache/apt/archives/ ]; then
        cp /var/cache/apt/archives/*.deb . 2>/dev/null || true

        # 복사된 파일 개수 확인
        DEB_COUNT=$(ls -1 *.deb 2>/dev/null | wc -l)
        log_info "총 ${DEB_COUNT}개의 DEB 패키지 다운로드 완료"

        if [ ${DEB_COUNT} -eq 0 ]; then
            log_error "다운로드된 패키지가 없습니다!"
            exit 1
        fi
    else
        log_error "APT 캐시 디렉토리를 찾을 수 없습니다"
        exit 1
    fi

    log_info "DEB 패키지 다운로드 완료"
}

# RPM 패키지 다운로드 (Rocky Linux/RHEL)
# 호스트가 RHEL 계열이 아니면 Docker 컨테이너를 사용하여 다운로드
download_rpm_packages() {
    log_info "RPM 패키지 다운로드 중..."

    # 현재 시스템이 RHEL 계열인지 확인
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            rocky|rhel|centos|fedora|almalinux)
                log_info "RHEL 계열 시스템 감지됨. 직접 다운로드합니다."
                download_rpm_packages_native
                return $?
                ;;
            *)
                log_info "비-RHEL 계열 시스템 감지됨 ($ID). Docker 컨테이너를 사용하여 다운로드합니다."
                download_rpm_packages_docker
                return $?
                ;;
        esac
    else
        log_warn "OS를 감지할 수 없습니다. Docker 컨테이너를 사용하여 다운로드합니다."
        download_rpm_packages_docker
        return $?
    fi
}

# RPM 패키지 직접 다운로드 (RHEL 계열 호스트용)
download_rpm_packages_native() {
    log_info "네이티브 RPM 패키지 다운로드 중..."

    # Docker 저장소 확인
    log_info "Docker 저장소 확인 중..."
    if ! dnf repolist | grep -q "docker"; then
        log_warn "Docker 저장소가 설정되어 있지 않습니다. Docker 공식 저장소 추가 방법:"
        log_warn "  sudo dnf install -y dnf-plugins-core"
        log_warn "  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
        log_warn "  sudo dnf makecache"
    fi

    # EPEL 저장소 패키지 먼저 다운로드
    log_info "EPEL 저장소 패키지 다운로드 중..."
    dnf download epel-release 2>/dev/null || log_warn "EPEL 저장소 패키지 다운로드 실패 (이미 설치되어 있을 수 있음)"

    # Docker 관련 패키지
    log_info "Docker 관련 패키지 다운로드 중..."
    dnf download --resolve --alldeps \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin 2>&1 | tee /tmp/dnf_download.log

    # Git 관련 패키지
    log_info "Git 관련 패키지 다운로드 중..."
    dnf download --resolve --alldeps git

    # 유틸리티 패키지
    log_info "유틸리티 패키지 다운로드 중..."
    dnf download --resolve --alldeps \
        curl \
        wget \
        vim \
        net-tools \
        bind-utils \
        tar \
        gzip \
        rsync \
        tmux

    # Mosquitto MQTT 브로커 및 클라이언트
    log_info "Mosquitto 패키지 다운로드 중..."
    dnf download --resolve --alldeps mosquitto

    # mosquitto-clients는 선택적 (EPEL에서 사용 가능한 경우만)
    dnf download --resolve --alldeps mosquitto-clients 2>/dev/null || log_warn "mosquitto-clients 패키지를 사용할 수 없습니다 (mosquitto 패키지에 포함되어 있을 수 있음)"

    # 다운로드된 패키지 개수 확인
    RPM_COUNT=$(ls -1 *.rpm 2>/dev/null | wc -l)
    log_info "총 ${RPM_COUNT}개의 RPM 패키지 다운로드 완료"

    if [ ${RPM_COUNT} -eq 0 ]; then
        log_error "다운로드된 RPM 패키지가 없습니다!"
        log_error "다음을 확인하세요:"
        log_error "  1. Docker 저장소가 설정되어 있는지 확인"
        log_error "  2. 인터넷 연결 확인"
        log_error "  3. /tmp/dnf_download.log 파일 확인"
        exit 1
    fi

    log_info "RPM 패키지 다운로드 완료"
}

# Docker 컨테이너를 사용하여 RPM 패키지 다운로드 (비-RHEL 계열 호스트용)
download_rpm_packages_docker() {
    log_info "Rocky Linux 9 Docker 컨테이너를 사용하여 RPM 패키지 다운로드 중..."

    # Rocky Linux 이미지 pull
    log_info "Rocky Linux 9 이미지 다운로드 중..."
    docker pull rockylinux:9

    # 컨테이너 내에서 실행할 스크립트 생성
    cat > /tmp/download_rpm.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "[INFO] Docker 저장소 설정 중..."
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf makecache

echo "[INFO] EPEL 저장소 설정 중..."
dnf install -y epel-release
dnf makecache

cd /rpm_packages

echo "[INFO] EPEL 저장소 패키지 다운로드 중..."
dnf download epel-release 2>/dev/null || echo "[WARN] EPEL 저장소 패키지 다운로드 실패"

echo "[INFO] Docker 관련 패키지 다운로드 중..."
dnf download --resolve --alldeps \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "[INFO] Git 관련 패키지 다운로드 중..."
dnf download --resolve --alldeps git

echo "[INFO] 유틸리티 패키지 다운로드 중..."
dnf download --resolve --alldeps \
    curl \
    wget \
    vim \
    net-tools \
    bind-utils \
    tar \
    gzip \
    rsync \
    tmux

echo "[INFO] Mosquitto 패키지 다운로드 중..."
dnf download --resolve --alldeps mosquitto

# mosquitto-clients는 선택적
dnf download --resolve --alldeps mosquitto-clients 2>/dev/null || echo "[WARN] mosquitto-clients 패키지를 사용할 수 없습니다"

# Python 패키지 다운로드를 위한 pip 설치
echo "[INFO] Python pip 설치 중..."
dnf install -y python3-pip

echo "[INFO] Python 패키지 다운로드 중..."
cd /pip_packages
pip3 download paho-mqtt influxdb

echo "[INFO] 다운로드 완료!"
ls -la /rpm_packages/
ls -la /pip_packages/
EOFSCRIPT

    chmod +x /tmp/download_rpm.sh

    # 현재 디렉토리의 절대 경로 얻기 (이미 rpm_packages 디렉토리에 있음)
    RPM_DIR=$(pwd)

    # PIP 디렉토리 절대 경로 (rpm_packages와 같은 레벨)
    PIP_PKG_DIR=$(cd ../pip_packages 2>/dev/null && pwd || echo "${RPM_DIR}/../pip_packages")
    mkdir -p "${PIP_PKG_DIR}"
    PIP_PKG_DIR=$(cd "${PIP_PKG_DIR}" && pwd)

    log_info "RPM 패키지 디렉토리: ${RPM_DIR}"
    log_info "PIP 패키지 디렉토리: ${PIP_PKG_DIR}"

    # Docker 컨테이너 실행
    log_info "Docker 컨테이너에서 패키지 다운로드 실행 중..."
    docker run --rm \
        -v "${RPM_DIR}:/rpm_packages" \
        -v "${PIP_PKG_DIR}:/pip_packages" \
        -v "/tmp/download_rpm.sh:/download_rpm.sh:ro" \
        rockylinux:9 \
        /bin/bash /download_rpm.sh

    # 다운로드된 패키지 개수 확인
    RPM_COUNT=$(ls -1 "${RPM_DIR}"/*.rpm 2>/dev/null | wc -l)
    log_info "총 ${RPM_COUNT}개의 RPM 패키지 다운로드 완료"

    if [ ${RPM_COUNT} -eq 0 ]; then
        log_error "다운로드된 RPM 패키지가 없습니다!"
        exit 1
    fi

    # 임시 스크립트 정리
    rm -f /tmp/download_rpm.sh

    log_info "RPM 패키지 다운로드 완료 (Docker 컨테이너 사용)"
}

# Python 패키지 다운로드
download_pip_packages() {
    log_step "Python 패키지 다운로드 중..."

    # Docker 컨테이너로 이미 다운로드된 경우 확인
    PIP_PKG_DIR=$(cd "${PIP_DIR}" && pwd)
    EXISTING_COUNT=$(ls -1 "${PIP_PKG_DIR}"/*.whl "${PIP_PKG_DIR}"/*.tar.gz 2>/dev/null | wc -l)

    if [ ${EXISTING_COUNT} -gt 0 ]; then
        log_info "Python 패키지가 이미 다운로드되어 있습니다 (${EXISTING_COUNT}개). 건너뜁니다."
        return 0
    fi

    cd "${PIP_DIR}"

    # pip가 설치되어 있는지 확인
    if ! command -v pip3 &> /dev/null; then
        log_warn "pip3가 설치되어 있지 않습니다. Python 패키지 다운로드를 건너뜁니다."
        cd ../..
        return 0
    fi

    # MQTT 클라이언트 패키지
    log_info "paho-mqtt 패키지 다운로드 중..."
    pip3 download paho-mqtt

    # InfluxDB 클라이언트 패키지 (InfluxDB 1.x용)
    log_info "influxdb 패키지 다운로드 중..."
    pip3 download influxdb

    # 다운로드된 패키지 개수 확인
    PIP_COUNT=$(ls -1 *.whl *.tar.gz 2>/dev/null | wc -l)
    log_info "총 ${PIP_COUNT}개의 Python 패키지 다운로드 완료"

    cd ../..

    log_info "Python 패키지 다운로드 완료"
}

# 프로젝트 파일 복사
copy_project_files() {
    log_step "프로젝트 파일 복사 중..."

    # aton_server 디렉토리 복사 (git 제외)
    log_info "aton_server 디렉토리 복사 중..."
    rsync -av --exclude='.git' aton_server/ "${EXPORT_DIR}/aton_server/"

    # 설정 파일 복사
    log_info "설정 파일 복사 중..."
    cp README.md "${EXPORT_DIR}/"
    cp INSTALL_INSTRUCTIONS.md "${EXPORT_DIR}/"
    cp QUICKSTART.md "${EXPORT_DIR}/"
    cp START_HERE.md "${EXPORT_DIR}/"
    cp check_prerequisites.sh "${EXPORT_DIR}/"
    cp test_services.sh "${EXPORT_DIR}/"

    log_info "프로젝트 파일 복사 완료"
}

# 폐쇄망 설치 스크립트 생성
create_airgap_install_script() {
    log_step "폐쇄망 설치 스크립트 생성 중..."

    cat > "${SCRIPTS_DIR}/install_airgap.sh" << 'EOFSCRIPT'
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

        firewall-cmd --permanent --add-port=31020/tcp  # RESTful API
        firewall-cmd --permanent --add-port=31886/tcp  # InfluxDB
        firewall-cmd --permanent --add-port=31883/tcp  # MQTT

        firewall-cmd --reload

        log_info "방화벽 설정 완료"
    # ufw (Ubuntu)
    elif command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log_step "방화벽 설정 중 (ufw)..."

        ufw allow 31020/tcp  # RESTful API
        ufw allow 31886/tcp  # InfluxDB
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
    echo "- RESTful API: http://localhost:31020"
    echo "- InfluxDB: http://localhost:31886"
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
EOFSCRIPT

    chmod +x "${SCRIPTS_DIR}/install_airgap.sh"

    log_info "폐쇄망 설치 스크립트 생성 완료"
}

# README 파일 생성
create_airgap_readme() {
    log_step "폐쇄망 설치 가이드 생성 중..."

    cat > "${EXPORT_DIR}/AIRGAP_INSTALL.md" << 'EOFREADME'
# ATON Server - 폐쇄망 환경 설치 가이드

이 패키지는 인터넷 연결이 없는 폐쇄망 환경에서 ATON Server를 설치하기 위한 모든 파일을 포함하고 있습니다.

## 패키지 구성

```
airgap_package/
├── docker_images/          # Docker 이미지 tar 파일
│   ├── influxdb_1.8.tar
│   ├── mosquitto_1.5.6.tar
│   ├── comm2center.tar
│   └── restfulapi.tar
├── rpm_packages/           # RPM 패키지 및 의존성 (Rocky Linux용)
│   ├── docker-ce-*.rpm
│   ├── docker-compose-plugin-*.rpm
│   ├── git-*.rpm
│   └── ...
├── deb_packages/           # DEB 패키지 및 의존성 (Ubuntu용)
│   ├── docker-ce_*.deb
│   ├── docker-compose-plugin_*.deb
│   ├── git_*.deb
│   └── ...
├── scripts/                # 설치 스크립트
│   └── install_airgap.sh
├── aton_server/            # ATON Server 소스 코드
└── AIRGAP_INSTALL.md       # 이 파일
```

## 시스템 요구사항

- **타겟 OS (폐쇄망)**: Rocky Linux 9.4/9.6
- **준비 OS (인터넷 연결)**: Rocky Linux (RPM 다운로드용) 또는 Ubuntu (DEB 다운로드용)
- 최소 2GB RAM
- 10GB 이상의 디스크 공간
- **폐쇄망 환경에서는 인터넷 연결 불필요**

## 설치 방법

### 1. 패키지 준비 (인터넷 연결된 환경)

인터넷이 연결된 Rocky Linux 환경에서 다음 스크립트를 실행하여 패키지를 준비합니다:

```bash
# Rocky Linux용 패키지 준비 (기본값)
sudo ./export_for_airgap.sh

# 또는 명시적으로 지정
sudo ./export_for_airgap.sh --target-os rocky
```

**중요**: Ubuntu에서 실행 시 DEB 패키지가 다운로드되므로, Rocky Linux용 패키지를 준비하려면 반드시 Rocky Linux 시스템에서 실행하세요.

이 스크립트는 `airgap_package` 디렉토리에 필요한 모든 파일을 준비합니다.

### 2. 패키지 전송

준비된 `airgap_package` 디렉토리를 USB 또는 다른 매체를 통해 폐쇄망 환경으로 전송합니다:

```bash
# 패키지 압축 (선택사항)
tar czf airgap_package.tar.gz airgap_package/

# USB에 복사
cp airgap_package.tar.gz /media/usb/

# 또는 디렉토리 전체 복사
cp -r airgap_package /media/usb/
```

### 3. 폐쇄망 환경 설치

폐쇄망 환경에서 다음 단계를 수행합니다:

```bash
# 패키지 압축 해제 (압축한 경우)
tar xzf airgap_package.tar.gz

# 패키지 디렉토리로 이동
cd airgap_package

# 설치 스크립트 실행 (root 권한 필요)
sudo ./scripts/install_airgap.sh
```

### 4. 설치 후 설정

```bash
# 로그아웃 후 다시 로그인 (Docker 그룹 권한 적용)
exit

# 다시 로그인 후
cd airgap_package/aton_server/aton_server_msa

# .env 파일 확인 및 수정 (필요시)
vi .env

# 서비스 시작
docker compose up -d

# 서비스 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f
```

## 환경 변수 설정

`aton_server/aton_server_msa/.env` 파일에서 다음 설정을 변경할 수 있습니다:

```env
INFLUX_ROOT_USER=root
INFLUX_ROOT_PASSWORD=keti1234
MOSQUITTO_USERNAME=keti
MOSQUITTO_PASSWORD=keti1234
MOSQUITTO_VERSION=1.5.6
```

## 서비스 엔드포인트

- **RESTful API**: http://localhost:5000
- **InfluxDB**: http://localhost:8086
- **MQTT Broker**: mqtt://localhost:31883

## 트러블슈팅

### Docker 이미지 확인

```bash
docker images
```

다음 이미지가 있어야 합니다:
- influxdb:1.8
- eclipse-mosquitto:1.5.6
- aton_server_msa-comm2center:latest
- aton_server_msa-restfulapi:latest

### Docker 서비스 상태 확인

```bash
systemctl status docker
```

### 포트 확인

```bash
sudo netstat -tulpn | grep -E '5000|8086|31883'
```

### 방화벽 확인

```bash
sudo firewall-cmd --list-ports
```

다음 포트가 열려 있어야 합니다:
- 5000/tcp (RESTful API)
- 8086/tcp (InfluxDB)
- 31883/tcp (MQTT)

### 서비스 로그 확인

```bash
cd aton_server/aton_server_msa

# 모든 서비스 로그
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f influxdb
docker compose logs -f mosquitto
docker compose logs -f comm2center
docker compose logs -f restfulapi
```

## Docker Compose 명령어

```bash
# 서비스 시작
docker compose up -d

# 서비스 중지
docker compose stop

# 서비스 중지 및 컨테이너 제거
docker compose down

# 서비스 상태 확인
docker compose ps

# 서비스 재시작
docker compose restart
```

## 주의사항

1. 설치 전에 시스템 시간이 올바르게 설정되어 있는지 확인하세요
2. 충분한 디스크 공간이 있는지 확인하세요
3. Docker 그룹에 추가된 후에는 반드시 로그아웃 후 다시 로그인해야 합니다
4. 프로덕션 환경에서는 `.env` 파일의 기본 비밀번호를 변경하세요

## 도움말

문제가 발생하면 다음을 확인하세요:
1. 시스템 로그: `journalctl -xe`
2. Docker 로그: `docker compose logs`
3. 시스템 리소스: `df -h`, `free -h`
4. 네트워크 포트: `netstat -tulpn`

EOFREADME

    log_info "폐쇄망 설치 가이드 생성 완료"
}

# 패키지 압축
compress_package() {
    log_step "패키지 압축 중..."

    log_info "tar.gz 파일 생성 중... (시간이 걸릴 수 있습니다)"
    tar czf airgap_package.tar.gz airgap_package/

    log_info "패키지 압축 완료: airgap_package.tar.gz"

    # 크기 확인
    SIZE=$(du -sh airgap_package.tar.gz | cut -f1)
    log_info "압축 파일 크기: ${SIZE}"
}

# 요약 정보 출력
show_summary() {
    echo ""
    echo "============================================"
    echo "  폐쇄망 환경 준비 완료!"
    echo "============================================"
    echo ""
    echo "생성된 파일:"
    echo "  - airgap_package/ (디렉토리)"
    echo "  - airgap_package.tar.gz (압축 패일)"
    echo ""
    echo "타겟 OS: ${TARGET_OS}"
    echo ""
    echo "패키지 내용:"
    echo "  - Docker 이미지 (influxdb, mosquitto, comm2center, restfulapi)"
    if [ "$PKG_TYPE" = "deb" ]; then
        echo "  - DEB 패키지 (Docker, Git, 유틸리티) - Ubuntu/Debian용"
    else
        echo "  - RPM 패키지 (Docker, Git, 유틸리티) - Rocky Linux/RHEL용"
    fi
    echo "  - 설치 스크립트 (OS 자동 감지)"
    echo "  - ATON Server 소스 코드"
    echo ""
    echo "다음 단계:"
    echo "  1. airgap_package.tar.gz 파일을 USB로 복사"
    echo "  2. Rocky Linux 폐쇄망 환경으로 전송"
    echo "  3. 압축 해제: tar xzf airgap_package.tar.gz"
    echo "  4. 설치 실행: cd airgap_package && sudo ./scripts/install_airgap.sh"
    echo ""
    echo "참고:"
    echo "  - 이 패키지는 ${TARGET_OS} 시스템용으로 준비되었습니다"
    echo "  - 자세한 내용은 airgap_package/AIRGAP_INSTALL.md를 참조하세요"
    echo "============================================"
    echo ""
}

# 사용법 출력
usage() {
    cat << EOF
사용법: $0 [옵션]

옵션:
    --target-os OS      타겟 OS 지정 (기본값: rocky)
                        지원: ubuntu, debian, rocky, rhel, centos
    --help              도움말 표시

예제:
    # Rocky Linux용 패키지 준비 (기본값)
    $0

    # Ubuntu용 패키지 준비
    $0 --target-os ubuntu

    # 환경 변수 사용
    TARGET_OS=rocky $0

EOF
    exit 0
}

# 인자 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --target-os)
            TARGET_OS="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            usage
            ;;
    esac
done

# 메인 실행
main() {
    log_info "ATON Server 폐쇄망 환경 준비 시작..."
    echo ""

    # 현재 시스템 OS 확인
    check_current_os

    # 타겟 OS 설정
    set_target_package_type

    # Docker 확인
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되어 있지 않습니다. 먼저 Docker를 설치하세요."
        exit 1
    fi

    # Docker Compose 확인
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose가 설치되어 있지 않습니다."
        exit 1
    fi

    prepare_directories
    export_docker_images
    download_packages
    download_pip_packages
    copy_project_files
    create_airgap_install_script
    create_airgap_readme
    compress_package
    show_summary

    log_info "준비 스크립트 완료!"
}

# 스크립트 실행
main "$@"
