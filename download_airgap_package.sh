#!/bin/bash

###########################################
# ATON Server - 폐쇄망 패키지 다운로드 스크립트
# 이 스크립트는 원격 서버에서 airgap_package.tar.gz를
# scp로 다운로드합니다.
###########################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

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

# 기본 설정값
REMOTE_USER="${REMOTE_USER:-keti}"
REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_PATH="${REMOTE_PATH:-~/src/rocky/airgap_package.tar.gz}"
LOCAL_PATH="${LOCAL_PATH:-./airgap_package.tar.gz}"
AUTO_EXTRACT="${AUTO_EXTRACT:-no}"

# 사용법 출력
usage() {
    cat << EOF
사용법: $0 [옵션]

옵션:
    -u USER         원격 서버 사용자명 (기본값: keti)
    -h HOST         원격 서버 호스트 (필수)
    -r PATH         원격 파일 경로 (기본값: ~/src/rocky/airgap_package.tar.gz)
    -l PATH         로컬 저장 경로 (기본값: ./airgap_package.tar.gz)
    -e              다운로드 후 자동 압축 해제
    -p PORT         SSH 포트 (기본값: 22)
    --help          도움말 표시

예제:
    # 기본 사용법
    $0 -h 192.168.1.100

    # 사용자 지정
    $0 -u myuser -h 192.168.1.100

    # 전체 옵션
    $0 -u keti -h 192.168.1.100 -r /path/to/airgap_package.tar.gz -l ./package.tar.gz

    # 다운로드 후 자동 압축 해제
    $0 -h 192.168.1.100 -e

    # 환경 변수 사용
    REMOTE_HOST=192.168.1.100 $0

EOF
    exit 1
}

# 인자 파싱
SSH_PORT=22
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            REMOTE_USER="$2"
            shift 2
            ;;
        -h)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -r)
            REMOTE_PATH="$2"
            shift 2
            ;;
        -l)
            LOCAL_PATH="$2"
            shift 2
            ;;
        -e)
            AUTO_EXTRACT="yes"
            shift
            ;;
        -p)
            SSH_PORT="$2"
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

# 필수 파라미터 확인
if [ -z "$REMOTE_HOST" ]; then
    log_error "원격 호스트가 지정되지 않았습니다."
    echo ""
    usage
fi

# scp 명령어 확인
check_scp() {
    if ! command -v scp &> /dev/null; then
        log_error "scp 명령어를 찾을 수 없습니다. openssh-clients를 설치하세요."
        echo "  sudo dnf install -y openssh-clients"
        exit 1
    fi
}

# 원격 서버 연결 테스트
test_connection() {
    log_step "원격 서버 연결 테스트 중..."

    if ssh -p ${SSH_PORT} -o ConnectTimeout=5 -o BatchMode=yes ${REMOTE_USER}@${REMOTE_HOST} exit 2>/dev/null; then
        log_info "연결 성공 (SSH Key 인증)"
    else
        log_warn "SSH Key 인증 실패. 비밀번호 입력이 필요합니다."
    fi
}

# 원격 파일 존재 확인
check_remote_file() {
    log_step "원격 파일 존재 확인 중..."

    if ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "test -f ${REMOTE_PATH}"; then
        # 파일 크기 확인
        REMOTE_SIZE=$(ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "du -h ${REMOTE_PATH} | cut -f1")
        log_info "원격 파일 확인: ${REMOTE_PATH} (크기: ${REMOTE_SIZE})"
    else
        log_error "원격 파일을 찾을 수 없습니다: ${REMOTE_PATH}"
        exit 1
    fi
}

# 로컬 디스크 공간 확인
check_local_space() {
    log_step "로컬 디스크 공간 확인 중..."

    # 원격 파일 크기 (바이트)
    REMOTE_SIZE_BYTES=$(ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "stat -c%s ${REMOTE_PATH}")

    # 로컬 사용 가능 공간 (바이트)
    LOCAL_DIR=$(dirname "${LOCAL_PATH}")
    LOCAL_AVAILABLE=$(df -B1 "${LOCAL_DIR}" | tail -1 | awk '{print $4}')

    # 필요 공간 (파일 크기 + 여유 공간 1GB)
    REQUIRED_SPACE=$((REMOTE_SIZE_BYTES + 1073741824))

    if [ ${LOCAL_AVAILABLE} -lt ${REQUIRED_SPACE} ]; then
        log_error "디스크 공간이 부족합니다."
        echo "  필요: $(numfmt --to=iec ${REQUIRED_SPACE})"
        echo "  사용 가능: $(numfmt --to=iec ${LOCAL_AVAILABLE})"
        exit 1
    else
        log_info "디스크 공간 충분: $(numfmt --to=iec ${LOCAL_AVAILABLE})"
    fi
}

# 파일 다운로드
download_file() {
    log_step "파일 다운로드 중..."

    echo ""
    log_info "원격: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    log_info "로컬: ${LOCAL_PATH}"
    echo ""

    # 기존 파일 확인
    if [ -f "${LOCAL_PATH}" ]; then
        read -p "$(echo -e ${YELLOW}로컬에 동일한 파일이 있습니다. 덮어쓰시겠습니까? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "다운로드를 취소합니다."
            exit 0
        fi
    fi

    # scp 다운로드
    if scp -P ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH} ${LOCAL_PATH}; then
        log_info "다운로드 완료!"

        # 파일 크기 확인
        LOCAL_SIZE=$(du -h "${LOCAL_PATH}" | cut -f1)
        log_info "다운로드된 파일 크기: ${LOCAL_SIZE}"
    else
        log_error "다운로드 실패"
        exit 1
    fi
}

# 파일 무결성 확인
verify_file() {
    log_step "파일 무결성 확인 중..."

    # 로컬 파일 크기
    LOCAL_SIZE=$(stat -c%s "${LOCAL_PATH}")

    # 원격 파일 크기
    REMOTE_SIZE=$(ssh -p ${SSH_PORT} ${REMOTE_USER}@${REMOTE_HOST} "stat -c%s ${REMOTE_PATH}")

    if [ ${LOCAL_SIZE} -eq ${REMOTE_SIZE} ]; then
        log_info "파일 크기 일치: $(numfmt --to=iec ${LOCAL_SIZE})"
    else
        log_error "파일 크기 불일치!"
        echo "  로컬: $(numfmt --to=iec ${LOCAL_SIZE})"
        echo "  원격: $(numfmt --to=iec ${REMOTE_SIZE})"
        exit 1
    fi

    # tar 파일 검증
    if tar tzf "${LOCAL_PATH}" > /dev/null 2>&1; then
        log_info "압축 파일 검증 성공"
    else
        log_error "압축 파일이 손상되었습니다"
        exit 1
    fi
}

# 압축 해제
extract_file() {
    if [ "${AUTO_EXTRACT}" = "yes" ]; then
        log_step "압축 해제 중..."

        tar xzf "${LOCAL_PATH}"

        if [ -d "airgap_package" ]; then
            log_info "압축 해제 완료: airgap_package/"
        else
            log_error "압축 해제 실패"
            exit 1
        fi
    fi
}

# 다음 단계 안내
show_next_steps() {
    echo ""
    echo "============================================"
    echo "  다운로드 완료!"
    echo "============================================"
    echo ""
    echo "다운로드된 파일: ${LOCAL_PATH}"
    echo ""

    if [ "${AUTO_EXTRACT}" = "yes" ]; then
        echo "다음 단계:"
        echo "  1. cd airgap_package"
        echo "  2. sudo ./scripts/install_airgap.sh"
    else
        echo "다음 단계:"
        echo "  1. 압축 해제: tar xzf ${LOCAL_PATH}"
        echo "  2. cd airgap_package"
        echo "  3. sudo ./scripts/install_airgap.sh"
    fi
    echo ""
    echo "자세한 내용은 AIRGAP_INSTALL.md를 참조하세요."
    echo "============================================"
    echo ""
}

# 메인 실행
main() {
    log_info "ATON Server 폐쇄망 패키지 다운로드 시작..."
    echo ""

    check_scp
    test_connection
    check_remote_file
    check_local_space
    download_file
    verify_file
    extract_file
    show_next_steps

    log_info "다운로드 스크립트 완료!"
}

# 스크립트 실행
main "$@"
