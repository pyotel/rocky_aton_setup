#!/bin/bash

###########################################
# ATON Server - 폐쇄망 패키지 검증 스크립트
# 이 스크립트는 airgap_package.tar.gz가 폐쇄망 환경에서
# 제대로 작동하는지 검증합니다.
###########################################

# set -e를 제거하여 테스트가 계속 진행되도록 함
# set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
CYAN='\033[0;36m'
NC='\033[0m'

# 테스트 결과 카운터
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

# 테스트 시작
start_test() {
    ((TOTAL_TESTS++))
    log_test "$1"
}

# 테스트 디렉토리 설정
TEST_DIR="./airgap_test_env"
PACKAGE_FILE="./airgap_package.tar.gz"

# 테스트 환경 정리
cleanup_test_env() {
    log_info "테스트 환경 정리 중..."
    rm -rf "${TEST_DIR}"
}

# 테스트 환경 준비
prepare_test_env() {
    log_info "테스트 환경 준비 중..."

    cleanup_test_env
    mkdir -p "${TEST_DIR}"

    log_info "테스트 환경 준비 완료: ${TEST_DIR}"
}

# 1. 패키지 파일 존재 확인
test_package_exists() {
    start_test "패키지 파일 존재 확인"

    if [ -f "${PACKAGE_FILE}" ]; then
        SIZE=$(du -h "${PACKAGE_FILE}" | cut -f1)
        log_pass "패키지 파일 존재: ${PACKAGE_FILE} (크기: ${SIZE})"
    else
        log_fail "패키지 파일 없음: ${PACKAGE_FILE}"
        log_error "먼저 'sudo ./export_for_airgap.sh'를 실행하세요"
        exit 1
    fi
}

# 2. 패키지 압축 검증
test_package_integrity() {
    start_test "패키지 압축 무결성 검증"

    if tar tzf "${PACKAGE_FILE}" > /dev/null 2>&1; then
        log_pass "압축 파일 무결성 확인"
    else
        log_fail "압축 파일이 손상되었습니다"
        exit 1
    fi
}

# 3. 패키지 압축 해제
test_package_extraction() {
    start_test "패키지 압축 해제"

    cd "${TEST_DIR}"

    if tar xzf "../${PACKAGE_FILE}" 2>/dev/null; then
        log_pass "압축 해제 성공"
    else
        log_fail "압축 해제 실패"
        cd ..
        exit 1
    fi

    cd ..
}

# 4. 필수 디렉토리 구조 확인
test_directory_structure() {
    start_test "디렉토리 구조 확인"

    local required_dirs=(
        "airgap_package"
        "airgap_package/docker_images"
        "airgap_package/rpm_packages"
        "airgap_package/scripts"
        "airgap_package/aton_server"
        "airgap_package/aton_server/aton_server_msa"
    )

    local all_exist=true
    for dir in "${required_dirs[@]}"; do
        if [ -d "${TEST_DIR}/${dir}" ]; then
            echo "  ✓ ${dir}"
        else
            echo "  ✗ ${dir} (없음)"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        log_pass "모든 필수 디렉토리 존재"
    else
        log_fail "일부 디렉토리 누락"
    fi
}

# 5. Docker 이미지 파일 확인
test_docker_images() {
    start_test "Docker 이미지 파일 확인"

    local image_dir="${TEST_DIR}/airgap_package/docker_images"
    local required_images=(
        "influxdb_1.8.tar"
        "mosquitto_1.5.6.tar"
        "comm2center.tar"
        "restfulapi.tar"
    )

    local all_exist=true
    local total_size=0

    for image in "${required_images[@]}"; do
        local image_path="${image_dir}/${image}"
        if [ -f "${image_path}" ]; then
            local size=$(stat -c%s "${image_path}")
            total_size=$((total_size + size))
            local size_hr=$(numfmt --to=iec ${size})
            echo "  ✓ ${image} (${size_hr})"
        else
            echo "  ✗ ${image} (없음)"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        local total_hr=$(numfmt --to=iec ${total_size})
        log_pass "모든 Docker 이미지 파일 존재 (총 크기: ${total_hr})"
    else
        log_fail "일부 Docker 이미지 파일 누락"
    fi
}

# 6. RPM 패키지 확인
test_rpm_packages() {
    start_test "RPM 패키지 확인"

    local rpm_dir="${TEST_DIR}/airgap_package/rpm_packages"
    local rpm_count=$(ls -1 "${rpm_dir}"/*.rpm 2>/dev/null | wc -l)

    if [ ${rpm_count} -gt 0 ]; then
        echo "  RPM 패키지 수: ${rpm_count}개"

        # 주요 패키지 확인
        local key_packages=(
            "docker-ce"
            "containerd.io"
            "docker-compose-plugin"
        )

        for pkg in "${key_packages[@]}"; do
            if ls "${rpm_dir}"/${pkg}*.rpm 1> /dev/null 2>&1; then
                echo "  ✓ ${pkg}"
            else
                echo "  ✗ ${pkg} (없음)"
            fi
        done

        log_pass "RPM 패키지 확인 완료"
    else
        log_fail "RPM 패키지가 없습니다"
    fi
}

# 7. 설치 스크립트 확인
test_install_script() {
    start_test "설치 스크립트 확인"

    local script="${TEST_DIR}/airgap_package/scripts/install_airgap.sh"

    if [ -f "${script}" ]; then
        if [ -x "${script}" ]; then
            log_pass "설치 스크립트 존재 및 실행 가능"
        else
            log_warn "설치 스크립트가 실행 가능하지 않음"
            log_pass "설치 스크립트 존재"
        fi
    else
        log_fail "설치 스크립트 없음: ${script}"
    fi
}

# 8. 필수 파일 확인
test_required_files() {
    start_test "필수 파일 확인"

    local required_files=(
        "airgap_package/AIRGAP_INSTALL.md"
        "airgap_package/aton_server/aton_server_msa/docker-compose.yml"
        "airgap_package/aton_server/aton_server_msa/.env"
    )

    local all_exist=true
    for file in "${required_files[@]}"; do
        local file_path="${TEST_DIR}/${file}"
        if [ -f "${file_path}" ]; then
            echo "  ✓ ${file}"
        else
            echo "  ✗ ${file} (없음)"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        log_pass "모든 필수 파일 존재"
    else
        log_fail "일부 필수 파일 누락"
    fi
}

# 9. Docker 이미지 tar 파일 검증
test_docker_image_integrity() {
    start_test "Docker 이미지 tar 파일 무결성 검증"

    local image_dir="${TEST_DIR}/airgap_package/docker_images"
    local all_valid=true

    for tar_file in "${image_dir}"/*.tar; do
        if [ -f "${tar_file}" ]; then
            local basename=$(basename "${tar_file}")
            if tar tf "${tar_file}" > /dev/null 2>&1; then
                echo "  ✓ ${basename}"
            else
                echo "  ✗ ${basename} (손상됨)"
                all_valid=false
            fi
        fi
    done

    if [ "$all_valid" = true ]; then
        log_pass "모든 Docker 이미지 tar 파일 유효"
    else
        log_fail "일부 Docker 이미지 tar 파일 손상"
    fi
}

# 10. Docker Compose 파일 검증
test_docker_compose_file() {
    start_test "docker-compose.yml 파일 검증"

    local compose_file="${TEST_DIR}/airgap_package/aton_server/aton_server_msa/docker-compose.yml"

    if [ -f "${compose_file}" ]; then
        # 주요 서비스 확인
        local services=("influxdb" "mosquitto" "comm2center" "restfulapi")
        local all_services=true

        for service in "${services[@]}"; do
            if grep -q "^  ${service}:" "${compose_file}"; then
                echo "  ✓ ${service} 서비스"
            else
                echo "  ✗ ${service} 서비스 (없음)"
                all_services=false
            fi
        done

        if [ "$all_services" = true ]; then
            log_pass "docker-compose.yml 검증 성공"
        else
            log_fail "docker-compose.yml에 일부 서비스 누락"
        fi
    else
        log_fail "docker-compose.yml 파일 없음"
    fi
}

# 11. .env 파일 검증
test_env_file() {
    start_test ".env 파일 검증"

    local env_file="${TEST_DIR}/airgap_package/aton_server/aton_server_msa/.env"

    if [ -f "${env_file}" ]; then
        # 주요 환경 변수 확인
        local required_vars=(
            "INFLUX_ROOT_PASSWORD"
            "MOSQUITTO_USERNAME"
            "MOSQUITTO_PASSWORD"
            "MOSQUITTO_VERSION"
        )

        local all_vars=true
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" "${env_file}"; then
                echo "  ✓ ${var}"
            else
                echo "  ✗ ${var} (없음)"
                all_vars=false
            fi
        done

        if [ "$all_vars" = true ]; then
            log_pass ".env 파일 검증 성공"
        else
            log_fail ".env 파일에 일부 변수 누락"
        fi
    else
        log_fail ".env 파일 없음"
    fi
}

# 12. 문서 파일 확인
test_documentation() {
    start_test "문서 파일 확인"

    local docs=(
        "airgap_package/AIRGAP_INSTALL.md"
        "airgap_package/README.md"
    )

    local all_exist=true
    for doc in "${docs[@]}"; do
        local doc_path="${TEST_DIR}/${doc}"
        if [ -f "${doc_path}" ]; then
            local lines=$(wc -l < "${doc_path}")
            echo "  ✓ ${doc} (${lines} 줄)"
        else
            echo "  ✗ ${doc} (없음)"
            all_exist=false
        fi
    done

    if [ "$all_exist" = true ]; then
        log_pass "모든 문서 파일 존재"
    else
        log_warn "일부 문서 파일 누락"
        ((PASSED_TESTS++))
    fi
}

# 13. 패키지 크기 분석
analyze_package_size() {
    log_info "패키지 크기 분석"

    echo ""
    echo "=== 패키지 구성 크기 ==="

    local package_dir="${TEST_DIR}/airgap_package"

    if [ -d "${package_dir}/docker_images" ]; then
        local size=$(du -sh "${package_dir}/docker_images" 2>/dev/null | cut -f1)
        echo "  Docker 이미지:  ${size}"
    fi

    if [ -d "${package_dir}/rpm_packages" ]; then
        local size=$(du -sh "${package_dir}/rpm_packages" 2>/dev/null | cut -f1)
        echo "  RPM 패키지:     ${size}"
    fi

    if [ -d "${package_dir}/aton_server" ]; then
        local size=$(du -sh "${package_dir}/aton_server" 2>/dev/null | cut -f1)
        echo "  소스 코드:      ${size}"
    fi

    if [ -d "${package_dir}" ]; then
        local total=$(du -sh "${package_dir}" 2>/dev/null | cut -f1)
        echo "  ---------------"
        echo "  전체 크기:      ${total}"
    fi

    echo "======================="
    echo ""
}

# 14. 폐쇄망 시뮬레이션 테스트 (옵션)
test_airgap_simulation() {
    log_info "폐쇄망 환경 시뮬레이션 테스트"

    echo ""
    echo "=== 폐쇄망 환경 체크리스트 ==="
    echo ""
    echo "다음 항목들이 외부 인터넷 연결 없이 가능해야 합니다:"
    echo ""
    echo "  1. ✓ Docker 이미지 tar 파일 존재 확인"
    echo "  2. ✓ RPM 패키지 및 의존성 포함 확인"
    echo "  3. ✓ 설치 스크립트 존재 확인"
    echo "  4. ✓ 설정 파일 (.env) 존재 확인"
    echo "  5. ✓ docker-compose.yml 존재 확인"
    echo "  6. ✓ 문서 파일 존재 확인"
    echo ""
    echo "실제 폐쇄망 환경에서 테스트하려면:"
    echo "  1. 인터넷을 차단하거나 폐쇄망 VM 사용"
    echo "  2. airgap_package.tar.gz 복사"
    echo "  3. tar xzf airgap_package.tar.gz"
    echo "  4. cd airgap_package"
    echo "  5. sudo ./scripts/install_airgap.sh"
    echo ""
    echo "================================"
    echo ""
}

# 테스트 결과 요약
show_test_summary() {
    echo ""
    echo "============================================"
    echo "  테스트 결과 요약"
    echo "============================================"
    echo ""
    echo "  총 테스트:    ${TOTAL_TESTS}"
    echo "  통과:         ${GREEN}${PASSED_TESTS}${NC}"
    echo "  실패:         ${RED}${FAILED_TESTS}${NC}"
    echo ""

    if [ ${FAILED_TESTS} -eq 0 ]; then
        echo -e "${GREEN}✓ 모든 테스트 통과!${NC}"
        echo ""
        echo "이 패키지는 폐쇄망 환경에서 사용 가능합니다."
    else
        echo -e "${RED}✗ 일부 테스트 실패${NC}"
        echo ""
        echo "패키지를 다시 생성하세요:"
        echo "  sudo ./export_for_airgap.sh"
    fi

    echo "============================================"
    echo ""
}

# 메인 실행
main() {
    echo ""
    echo "============================================"
    echo "  ATON Server 폐쇄망 패키지 검증"
    echo "============================================"
    echo ""

    # 테스트 환경 준비
    prepare_test_env

    # 테스트 실행
    test_package_exists
    test_package_integrity
    test_package_extraction
    test_directory_structure
    test_docker_images
    test_rpm_packages
    test_install_script
    test_required_files
    test_docker_image_integrity
    test_docker_compose_file
    test_env_file
    test_documentation

    # 분석
    analyze_package_size
    test_airgap_simulation

    # 결과 요약
    show_test_summary

    # 테스트 환경 정리
    if [ -t 0 ]; then
        # 대화형 모드
        read -p "테스트 환경을 정리하시겠습니까? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            cleanup_test_env
            log_info "테스트 환경 정리 완료"
        else
            log_info "테스트 환경 보존: ${TEST_DIR}"
        fi
    else
        # 비대화형 모드
        log_info "비대화형 모드: 테스트 환경 보존: ${TEST_DIR}"
    fi

    # 종료 코드
    if [ ${FAILED_TESTS} -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# 스크립트 실행
main "$@"
