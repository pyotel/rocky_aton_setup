#!/bin/bash

###########################################
# ATON Server - 폐쇄망 환경 준비 스크립트
# 이 스크립트는 인터넷이 연결된 환경에서 실행하여
# 폐쇄망 환경에 필요한 모든 파일을 준비합니다.
# 지원 OS: Ubuntu, Rocky Linux
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

# 작업 디렉토리 설정
EXPORT_DIR="./airgap_package"
IMAGES_DIR="${EXPORT_DIR}/docker_images"
SCRIPTS_DIR="${EXPORT_DIR}/scripts"

# 디렉토리 생성
prepare_directories() {
    log_step "작업 디렉토리 준비 중..."

    mkdir -p "${IMAGES_DIR}"
    mkdir -p "${EXPORT_DIR}/${PKG_DIR}"
    mkdir -p "${SCRIPTS_DIR}"

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
    docker compose build --no-cache

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

    # Docker 관련 패키지
    log_info "Docker 관련 패키지 다운로드 중..."
    apt-get download \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin || true

    # 의존성 패키지도 다운로드
    apt-get install --download-only -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin 2>/dev/null || true

    # 다운로드된 패키지 복사
    if [ -d /var/cache/apt/archives/ ]; then
        cp /var/cache/apt/archives/*.deb . 2>/dev/null || true
    fi

    # Git 관련 패키지
    log_info "Git 관련 패키지 다운로드 중..."
    apt-get download git git-man || true

    # 유틸리티 패키지
    log_info "유틸리티 패키지 다운로드 중..."
    apt-get download \
        curl \
        wget \
        vim \
        net-tools \
        dnsutils \
        tar \
        gzip \
        rsync || true

    log_info "DEB 패키지 다운로드 완료"
}

# RPM 패키지 다운로드 (Rocky Linux/RHEL)
download_rpm_packages() {
    log_info "RPM 패키지 다운로드 중..."

    # Docker 관련 패키지
    log_info "Docker 관련 패키지 다운로드 중..."
    dnf download --resolve --alldeps \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

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
        gzip

    # EPEL 저장소 패키지
    log_info "EPEL 저장소 패키지 다운로드 중..."
    dnf download epel-release

    log_info "RPM 패키지 다운로드 완료"
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

    cd deb_packages

    # 모든 DEB 패키지 설치
    log_info "패키지 설치 중..."
    dpkg -i *.deb 2>/dev/null || true

    # 의존성 문제 해결
    apt-get install -f -y || true

    cd ..

    log_info "DEB 패키지 설치 완료"
}

# RPM 패키지 설치 (Rocky Linux/RHEL)
install_rpm_packages() {
    log_step "RPM 패키지 설치 중..."

    cd rpm_packages

    # EPEL 저장소 먼저 설치
    log_info "EPEL 저장소 설치 중..."
    dnf install -y ./epel-release*.rpm || true

    # 모든 RPM 패키지 설치
    log_info "패키지 설치 중..."
    dnf install -y ./*.rpm --skip-broken

    cd ..

    log_info "RPM 패키지 설치 완료"
}

# 패키지 설치 (OS별 분기)
install_packages() {
    # Docker가 이미 설치되어 있는지 확인
    if command -v docker &> /dev/null; then
        log_info "Docker가 이미 설치되어 있습니다. 패키지 설치를 건너뜁니다."
        return 0
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

- **지원 OS**: Ubuntu 20.04/22.04 또는 Rocky Linux 9.4/9.6
- 최소 2GB RAM
- 10GB 이상의 디스크 공간
- **인터넷 연결 불필요**

## 설치 방법

### 1. 패키지 준비 (인터넷 연결된 환경)

인터넷이 연결된 환경에서 다음 스크립트를 실행하여 패키지를 준비합니다:

```bash
sudo ./export_for_airgap.sh
```

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
    echo "패키지 내용:"
    echo "  - Docker 이미지 (influxdb, mosquitto, comm2center, restfulapi)"
    if [ "$PKG_TYPE" = "deb" ]; then
        echo "  - DEB 패키지 (Docker, Git, 유틸리티) - Ubuntu용"
    else
        echo "  - RPM 패키지 (Docker, Git, 유틸리티) - Rocky Linux용"
    fi
    echo "  - 설치 스크립트 (OS 자동 감지)"
    echo "  - ATON Server 소스 코드"
    echo ""
    echo "다음 단계:"
    echo "  1. airgap_package.tar.gz 파일을 USB로 복사"
    echo "  2. 폐쇄망 환경으로 전송"
    echo "  3. 압축 해제: tar xzf airgap_package.tar.gz"
    echo "  4. 설치 실행: cd airgap_package && sudo ./scripts/install_airgap.sh"
    echo ""
    echo "참고:"
    echo "  - 설치 스크립트는 Ubuntu와 Rocky Linux를 자동으로 감지합니다"
    echo "  - 자세한 내용은 airgap_package/AIRGAP_INSTALL.md를 참조하세요"
    echo "============================================"
    echo ""
}

# 메인 실행
main() {
    log_info "ATON Server 폐쇄망 환경 준비 시작..."
    echo ""

    # OS 감지
    detect_os

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
    copy_project_files
    create_airgap_install_script
    create_airgap_readme
    compress_package
    show_summary

    log_info "준비 스크립트 완료!"
}

# 스크립트 실행
main "$@"
