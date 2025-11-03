# 스크립트 사용 가이드

이 문서는 Rocky ATON Setup 프로젝트에서 제공하는 스크립트들의 사용법을 설명합니다.

## 스크립트 개요

| 스크립트 | 목적 | 필요 권한 |
|---------|------|----------|
| `check_prerequisites.sh` | 시스템 전제조건 확인 | 일반 사용자 (일부 기능은 sudo) |
| `setup_aton_server.sh` | Docker 및 의존성 설치 | sudo 필요 |
| `test_services.sh` | ATON 서비스 시작 및 테스트 | Docker 권한 필요 |

---

## 1. check_prerequisites.sh

### 목적
시스템이 ATON Server를 실행하기 위한 모든 전제조건을 충족하는지 확인합니다.

### 사용법
```bash
./check_prerequisites.sh
```

### 확인 항목
- Operating System (Rocky Linux)
- Docker 설치 및 실행 상태
- Docker Compose 설치
- Docker 권한
- Git 설치
- 필요한 포트 사용 가능 여부 (5000, 8086, 31883)
- 방화벽 설정
- 디스크 공간
- 메모리
- ATON Server 디렉토리 및 파일

### 출력 예시
```
==========================================
   ATON Server Prerequisites Check
==========================================

[INFO] Checking Operating System...
[✓] OS: Rocky Linux 9.6

[INFO] Checking Docker...
[✓] Docker installed: Docker version 24.0.7
[✓] Docker service is running
[✓] Docker permissions OK

...

==========================================
              Summary
==========================================

[✓] All prerequisites are met!

You can now start the ATON Server:
  ./test_services.sh
==========================================
```

### 반환 코드
- `0`: 모든 전제조건 충족
- `> 0`: 문제 발견 (숫자는 문제 개수)

---

## 2. setup_aton_server.sh

### 목적
Rocky Linux 9에 ATON Server 실행에 필요한 모든 소프트웨어를 자동으로 설치합니다.

### 사용법
```bash
sudo ./setup_aton_server.sh
```

**주의**: 반드시 sudo 권한으로 실행해야 합니다.

### 설치 항목
1. 시스템 패키지 업데이트
2. EPEL 저장소
3. Git
4. Docker Engine
5. Docker Compose (플러그인 및 독립 실행형)
6. 추가 유틸리티 (curl, wget, vim, net-tools 등)
7. 방화벽 설정 (포트 5000, 8086, 31883)
8. 사용자를 docker 그룹에 추가

### 출력 예시
```
[INFO] Starting ATON Server MSA setup for Rocky Linux 9...
[INFO] Updating system packages...
[INFO] Installing Docker...
[INFO] Docker installed successfully
Docker version 24.0.7, build 311b9ff

...

===== Installation Summary =====
✓ Docker: Docker version 24.0.7
✓ Docker Compose: Docker Compose version v2.23.0
✓ Git: git version 2.47.3
✓ Docker service: Running
================================

===== Next Steps =====
1. If you added your user to the docker group, log out and log back in
2. Navigate to the aton_server_msa directory:
   cd aton_server/aton_server_msa
3. Review and edit the .env file if needed
4. Start the services:
   docker-compose up -d
...
```

### 설치 후 조치
```bash
# 로그아웃 후 다시 로그인
exit

# 또는 docker 그룹 즉시 적용
newgrp docker

# 설치 확인
docker --version
docker-compose --version
```

### 기능
- **시스템 업데이트**: dnf 패키지 관리자로 시스템 업데이트
- **Docker 설치**: 공식 Docker 저장소에서 최신 Docker CE 설치
- **방화벽 구성**: firewalld 활성화 시 필요한 포트 자동 개방
- **사용자 권한**: 현재 사용자를 docker 그룹에 자동 추가
- **검증**: 설치 완료 후 모든 구성 요소 확인

---

## 3. test_services.sh

### 목적
ATON Server의 모든 마이크로서비스를 시작하고 정상 작동을 확인합니다.

### 사용법
```bash
./test_services.sh
```

**주의**: Docker 권한이 필요합니다. `docker ps` 명령이 sudo 없이 실행되어야 합니다.

### 수행 작업
1. Docker 및 Docker Compose 설치 확인
2. Docker 서비스 실행 확인
3. Docker 권한 확인
4. `docker-compose up -d`로 모든 서비스 시작
5. 컨테이너 상태 확인
6. 각 서비스 테스트:
   - InfluxDB (포트 8086)
   - RESTful API (포트 5000)
   - MQTT Broker (포트 31883)
7. 최근 로그 표시
8. 요약 정보 제공

### 출력 예시
```
[INFO] ATON Server MSA Service Test

[SUCCESS] Found ATON Server directory
[SUCCESS] Docker is installed: Docker version 24.0.7
[SUCCESS] Docker Compose is installed
[SUCCESS] Docker service is running
[SUCCESS] Docker permissions OK

[INFO] Starting ATON Server services...
[SUCCESS] Services started successfully

===== Container Status =====
NAME                 STATUS              PORTS
influxdb             Up 10 seconds       0.0.0.0:8086->8086/tcp
mosquitto            Up 10 seconds       0.0.0.0:31883->1883/tcp
comm2center          Up 10 seconds
restfulapi           Up 10 seconds       0.0.0.0:5000->5000/tcp
============================

[INFO] Testing InfluxDB (port 8086)...
[SUCCESS] InfluxDB is responding

[INFO] Testing RESTful API (port 5000)...
[SUCCESS] RESTful API is responding

[INFO] Testing MQTT Broker (port 31883)...
[SUCCESS] MQTT Broker is responding

========================================
           Test Summary
========================================

✓ influxdb: Running
✓ mosquitto: Running
✓ comm2center: Running
✓ restfulapi: Running

Service Endpoints:
  - RESTful API: http://localhost:5000
  - InfluxDB: http://localhost:8086
  - MQTT Broker: mqtt://localhost:31883

Useful Commands:
  View logs: cd aton_server/aton_server_msa && docker-compose logs -f
  Stop services: cd aton_server/aton_server_msa && docker-compose stop
  Restart services: cd aton_server/aton_server_msa && docker-compose restart
========================================
```

### 테스트 항목

#### InfluxDB 테스트
- HTTP 엔드포인트 `/ping` 호출
- 최대 12회 재시도 (5초 간격)
- 응답 확인

#### RESTful API 테스트
- HTTP 엔드포인트 루트 `/` 호출
- 최대 12회 재시도 (5초 간격)
- 응답 확인

#### MQTT 테스트
- `mosquitto_pub` 클라이언트로 테스트 메시지 발행
- 인증 정보: keti / keti1234
- mosquitto-clients 미설치 시 경고만 표시

### 문제 해결

#### Docker 권한 오류
```bash
sudo usermod -aG docker $USER
newgrp docker
./test_services.sh
```

#### 서비스 시작 실패
```bash
cd aton_server/aton_server_msa
docker-compose logs
```

---

## 권장 워크플로우

### 초기 설정 (최초 1회)
```bash
# 1. 전제조건 확인
./check_prerequisites.sh

# 2. 필요한 소프트웨어 설치
sudo ./setup_aton_server.sh

# 3. 로그아웃 후 재로그인 또는
newgrp docker

# 4. 다시 전제조건 확인
./check_prerequisites.sh
```

### 서비스 시작 및 테스트
```bash
# 서비스 시작 및 자동 테스트
./test_services.sh
```

### 일상 운영
```bash
cd aton_server/aton_server_msa

# 서비스 시작
docker-compose up -d

# 서비스 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f

# 서비스 중지
docker-compose stop

# 서비스 재시작
docker-compose restart
```

---

## 고급 사용법

### 특정 서비스만 재시작
```bash
cd aton_server/aton_server_msa
docker-compose restart restfulapi
```

### 서비스 재빌드
```bash
cd aton_server/aton_server_msa
docker-compose build --no-cache
docker-compose up -d
```

### 로그 필터링
```bash
cd aton_server/aton_server_msa

# 특정 서비스 로그만
docker-compose logs -f restfulapi

# 에러만 표시
docker-compose logs | grep -i error

# 최근 100줄
docker-compose logs --tail=100
```

### 환경 변수 변경
```bash
cd aton_server/aton_server_msa

# .env 파일 편집
vi .env

# 서비스 재시작 (환경 변수 적용)
docker-compose down
docker-compose up -d
```

---

## 트러블슈팅

### 스크립트 실행 권한 오류
```bash
chmod +x check_prerequisites.sh
chmod +x setup_aton_server.sh
chmod +x test_services.sh
```

### setup_aton_server.sh 실행 시 "sudo: a password is required"
```bash
# 대화형 터미널에서 실행
sudo ./setup_aton_server.sh
```

### Docker 명령어에서 권한 오류
```bash
# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# 로그아웃 후 재로그인 또는
newgrp docker

# 확인
docker ps
```

### 포트 충돌
```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 충돌하는 프로세스 종료 또는 docker-compose.yml에서 포트 변경
cd aton_server/aton_server_msa
vi docker-compose.yml
```

---

## 추가 리소스

- [QUICKSTART.md](QUICKSTART.md) - 빠른 시작 가이드
- [INSTALL_INSTRUCTIONS.md](INSTALL_INSTRUCTIONS.md) - 상세 설치 가이드
- [README.md](README.md) - 프로젝트 개요
- [원본 리포지토리](https://github.com/pyotel/aton_server)

---

## 스크립트 유지보수

### 스크립트 수정
각 스크립트는 독립적으로 작동하므로 필요에 따라 수정할 수 있습니다.

### 버전 확인
```bash
# Docker 버전
docker --version

# Docker Compose 버전
docker-compose --version

# OS 버전
cat /etc/os-release
```

### 로그 위치
스크립트는 표준 출력으로 로그를 출력하며, 필요 시 리디렉션할 수 있습니다:
```bash
./test_services.sh 2>&1 | tee service_test.log
```
