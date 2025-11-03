# ATON Server MSA 설치 가이드 (Rocky Linux 9)

## 자동 설치 (권장)

루트 권한으로 자동 설치 스크립트를 실행하세요:

```bash
cd /home/keti/src/rocky_aton_setup
sudo ./setup_aton_server.sh
```

설치가 완료되면 로그아웃 후 다시 로그인하여 docker 그룹 권한을 활성화하세요.

---

## 수동 설치

자동 설치가 작동하지 않는 경우 다음 단계를 따라 수동으로 설치하세요:

### 1. 시스템 업데이트

```bash
sudo dnf update -y
sudo dnf install -y epel-release
```

### 2. Docker 설치

```bash
# 기존 Docker 관련 패키지 제거 (있는 경우)
sudo dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc 2>/dev/null || true

# Docker 저장소 설정
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Docker 설치
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 서비스 시작 및 활성화
sudo systemctl start docker
sudo systemctl enable docker

# 설치 확인
docker --version
```

### 3. Docker Compose 설치

Docker Compose Plugin이 함께 설치되었지만, 독립 실행형 버전도 설치할 수 있습니다:

```bash
# 최신 버전 설치
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 설치 확인
docker-compose --version
```

### 4. 사용자를 Docker 그룹에 추가

```bash
# 현재 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# 변경사항 적용을 위해 로그아웃 후 다시 로그인
# 또는 다음 명령어로 즉시 적용:
newgrp docker
```

### 5. 방화벽 설정 (선택사항)

```bash
# 방화벽이 활성화되어 있는 경우 필요한 포트 열기
sudo firewall-cmd --permanent --add-port=5000/tcp   # RESTful API
sudo firewall-cmd --permanent --add-port=8086/tcp   # InfluxDB
sudo firewall-cmd --permanent --add-port=31883/tcp  # MQTT
sudo firewall-cmd --reload
```

### 6. Git 설치 (이미 설치되어 있지 않은 경우)

```bash
sudo dnf install -y git
git --version
```

### 7. 추가 유틸리티 설치

```bash
sudo dnf install -y curl wget vim net-tools bind-utils tar gzip
```

---

## ATON Server 실행

### 1. 디렉토리 이동

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
```

### 2. 환경 변수 확인 및 수정 (필요시)

```bash
cat .env
# 필요한 경우 편집
vi .env
```

기본 설정:
- InfluxDB 사용자: root / keti1234
- MQTT 사용자: keti / keti1234
- Mosquitto 버전: 1.5.6

### 3. Docker Compose로 서비스 시작

```bash
# 백그라운드에서 실행
docker-compose up -d

# 또는 로그를 보면서 실행
docker-compose up
```

### 4. 서비스 상태 확인

```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f

# 특정 서비스 로그만 확인
docker-compose logs -f restfulapi
docker-compose logs -f influxdb
docker-compose logs -f mosquitto
docker-compose logs -f comm2center
```

### 5. 서비스 테스트

```bash
# RESTful API 테스트
curl http://localhost:5000

# InfluxDB 테스트
curl http://localhost:8086/ping

# MQTT 테스트 (mosquitto-clients 필요)
sudo dnf install -y mosquitto
mosquitto_pub -h localhost -p 31883 -t test/topic -m "Hello ATON" -u keti -P keti1234
```

---

## 서비스 관리 명령어

### 시작/중지/재시작

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 시작
docker-compose up -d

# 중지
docker-compose stop

# 재시작
docker-compose restart

# 중지 및 컨테이너 삭제
docker-compose down

# 중지, 컨테이너 및 볼륨 삭제 (주의: 데이터 삭제됨)
docker-compose down -v
```

### 로그 확인

```bash
# 모든 서비스 로그
docker-compose logs -f

# 마지막 100줄만
docker-compose logs --tail=100

# 특정 서비스
docker-compose logs -f influxdb
```

### 서비스 재빌드

```bash
# 모든 서비스 재빌드
docker-compose build --no-cache

# 특정 서비스만 재빌드
docker-compose build --no-cache restfulapi

# 재빌드 후 재시작
docker-compose up -d --build
```

---

## 트러블슈팅

### Docker 권한 오류

```bash
# 오류: Got permission denied while trying to connect to the Docker daemon socket
sudo usermod -aG docker $USER
newgrp docker
```

### 포트 충돌

```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 프로세스 종료 또는 docker-compose.yml에서 포트 변경
```

### 컨테이너가 시작되지 않음

```bash
# 로그 확인
docker-compose logs [service_name]

# 컨테이너 상태 확인
docker ps -a

# 강제 재시작
docker-compose down
docker-compose up -d
```

### InfluxDB 연결 오류

```bash
# InfluxDB가 완전히 시작될 때까지 기다리기 (약 30초)
docker-compose logs -f influxdb

# InfluxDB 컨테이너 내부로 접속
docker-compose exec influxdb bash
influx -username root -password keti1234
```

### MQTT 연결 오류

```bash
# Mosquitto 로그 확인
docker-compose logs -f mosquitto

# Mosquitto 설정 확인
docker-compose exec mosquitto cat /opt/mosquitto.conf

# MQTT 클라이언트로 테스트
mosquitto_sub -h localhost -p 31883 -t '#' -u keti -P keti1234 -v
```

---

## 서비스 엔드포인트

설치 완료 후 다음 엔드포인트로 접근 가능:

- **RESTful API**: http://localhost:5000
- **InfluxDB**: http://localhost:8086
- **MQTT Broker**: mqtt://localhost:31883

---

## 데이터 백업

```bash
# InfluxDB 데이터 백업
docker-compose exec influxdb influxd backup -portable /var/lib/influxdb/backup
docker cp aton_server_msa_influxdb_1:/var/lib/influxdb/backup ./influxdb_backup

# Mosquitto 데이터는 이미 호스트에 마운트됨
# ./mosquitto/data 디렉토리를 백업하세요
```

---

## 보안 권장사항

1. `.env` 파일의 기본 비밀번호를 변경하세요
2. 프로덕션 환경에서는 적절한 방화벽 규칙을 설정하세요
3. HTTPS/TLS 인증서를 설정하세요
4. 정기적으로 백업하세요
5. 시스템과 Docker 이미지를 최신 상태로 유지하세요

---

## 추가 정보

- 원본 저장소: https://github.com/pyotel/aton_server
- Rocky Linux 문서: https://docs.rockylinux.org/
- Docker 문서: https://docs.docker.com/
- Docker Compose 문서: https://docs.docker.com/compose/
