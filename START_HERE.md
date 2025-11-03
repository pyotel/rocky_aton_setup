# ATON Server MSA 시작 가이드

Rocky Linux 9에서 ATON Server MSA를 실행하기 위한 완전 가이드입니다.

## 🚀 빠른 시작 (3단계)

### 1단계: 시스템 준비
```bash
cd /home/keti/src/rocky_aton_setup

# 전제조건 확인
./check_prerequisites.sh

# Docker 및 필요 패키지 설치
sudo ./setup_aton_server.sh

# 로그아웃 후 재로그인 또는
newgrp docker
```

### 2단계: ATON 서버 설정
```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 환경 변수 확인 (필요시 수정)
cat .env
```

### 3단계: 서비스 시작
```bash
# 자동 테스트 스크립트 사용 (권장)
cd /home/keti/src/rocky_aton_setup
./test_services.sh

# 또는 수동으로
cd aton_server/aton_server_msa
docker-compose up -d
```

## 📋 문제 해결

### Docker Compose 빌드 에러가 발생하는 경우

docker-compose build 시 에러가 발생하면:

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 방법 1: 이미 수정된 docker-compose.yml 사용
docker-compose build
docker-compose up -d

# 방법 2: Docker 환경 패치 적용 (comm2center.py 수정)
./apply_docker_patch.sh
docker-compose build comm2center
docker-compose up -d
```

자세한 내용은 [DOCKER_COMPOSE_FIXES.md](DOCKER_COMPOSE_FIXES.md)를 참조하세요.

## 📚 문서 구조

| 문서 | 설명 | 언제 읽을까? |
|------|------|--------------|
| **START_HERE.md** (현재 문서) | 시작 가이드 | 처음 시작할 때 |
| [QUICKSTART.md](QUICKSTART.md) | 3단계 빠른 시작 | 빠르게 시작하고 싶을 때 |
| [INSTALL_INSTRUCTIONS.md](INSTALL_INSTRUCTIONS.md) | 상세 설치 가이드 | 수동 설치가 필요할 때 |
| [DOCKER_COMPOSE_FIXES.md](DOCKER_COMPOSE_FIXES.md) | 빌드 에러 해결 | 에러가 발생했을 때 |
| [SCRIPTS_GUIDE.md](SCRIPTS_GUIDE.md) | 스크립트 사용법 | 스크립트 상세 정보가 필요할 때 |
| [README.md](README.md) | 프로젝트 개요 | 전체 개요를 알고 싶을 때 |

## 🔧 제공되는 스크립트

### 1. check_prerequisites.sh
시스템이 ATON Server를 실행할 준비가 되었는지 확인합니다.

```bash
./check_prerequisites.sh
```

**확인 항목**:
- Operating System (Rocky Linux)
- Docker 설치 및 실행
- Docker Compose 설치
- 필요한 포트 (5000, 8086, 31883)
- 디스크 공간 및 메모리

### 2. setup_aton_server.sh
필요한 모든 소프트웨어를 자동으로 설치합니다.

```bash
sudo ./setup_aton_server.sh
```

**설치 항목**:
- Docker Engine
- Docker Compose
- Git 및 유틸리티
- 방화벽 설정

### 3. test_services.sh
ATON 서비스를 시작하고 모든 것이 정상 작동하는지 확인합니다.

```bash
./test_services.sh
```

**수행 작업**:
- 서비스 시작
- InfluxDB 테스트
- MQTT Broker 테스트
- RESTful API 테스트
- 로그 표시

### 4. apply_docker_patch.sh (선택사항)
comm2center.py를 Docker 환경에 최적화합니다.

```bash
cd aton_server/aton_server_msa
./apply_docker_patch.sh
```

## 🌐 서비스 엔드포인트

설치 완료 후 다음 엔드포인트에 접근할 수 있습니다:

| 서비스 | URL | 인증 정보 |
|--------|-----|-----------|
| RESTful API | http://localhost:5000 | - |
| InfluxDB | http://localhost:8086 | root / keti1234 |
| MQTT Broker | mqtt://localhost:31883 | keti / keti1234 |

## 🧪 서비스 테스트

### InfluxDB 테스트
```bash
curl http://localhost:8086/ping
```

### RESTful API 테스트
```bash
curl http://localhost:5000
```

### MQTT 테스트
```bash
# mosquitto-clients 설치 (처음 한 번만)
sudo dnf install -y mosquitto

# 메시지 발행
mosquitto_pub -h localhost -p 31883 -t "test/topic" -m "Hello" -u keti -P keti1234

# 메시지 구독 (다른 터미널에서)
mosquitto_sub -h localhost -p 31883 -t "#" -u keti -P keti1234 -v
```

## 📊 서비스 관리

### 상태 확인
```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
docker-compose ps
```

### 로그 보기
```bash
# 모든 서비스
docker-compose logs -f

# 특정 서비스
docker-compose logs -f restfulapi
docker-compose logs -f influxdb
docker-compose logs -f mosquitto
docker-compose logs -f comm2center
```

### 서비스 재시작
```bash
# 모든 서비스
docker-compose restart

# 특정 서비스
docker-compose restart restfulapi
```

### 서비스 중지
```bash
# 중지만
docker-compose stop

# 중지 및 컨테이너 제거
docker-compose down
```

## ❗ 일반적인 문제

### 1. Docker 권한 오류
```
Got permission denied while trying to connect to the Docker daemon socket
```

**해결**:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 2. 포트 충돌
```
Bind for 0.0.0.0:5000 failed: port is already allocated
```

**해결**:
```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 충돌하는 프로세스 종료 또는 docker-compose.yml에서 포트 변경
```

### 3. 빌드 에러
```
invalid mount config for type "bind": bind source path does not exist
```

**해결**: [DOCKER_COMPOSE_FIXES.md](DOCKER_COMPOSE_FIXES.md) 참조

### 4. 서비스 시작 실패
```bash
# 로그 확인
docker-compose logs

# 완전 재시작
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 🔒 보안 권장사항

### 1. 기본 비밀번호 변경
```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
vi .env
```

다음 항목을 변경하세요:
- INFLUX_ROOT_PASSWORD
- MOSQUITTO_PASSWORD

### 2. 방화벽 설정
```bash
# 외부 접근이 필요한 경우에만 포트 개방
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --permanent --add-port=31883/tcp
sudo firewall-cmd --reload
```

### 3. 정기 백업
```bash
# InfluxDB 데이터 백업
docker-compose exec influxdb influxd backup -portable /tmp/backup
docker cp $(docker-compose ps -q influxdb):/tmp/backup ./influxdb_backup_$(date +%Y%m%d)
```

## 📞 지원 및 문의

### 문제 발생 시

1. **로그 확인**: `docker-compose logs -f`
2. **문서 참조**: [DOCKER_COMPOSE_FIXES.md](DOCKER_COMPOSE_FIXES.md)
3. **전제조건 재확인**: `./check_prerequisites.sh`
4. **완전 재시작**: `docker-compose down && docker-compose up -d`

### 추가 리소스

- 원본 프로젝트: https://github.com/pyotel/aton_server
- Docker 문서: https://docs.docker.com/
- InfluxDB 문서: https://docs.influxdata.com/influxdb/v1.8/
- Mosquitto 문서: https://mosquitto.org/

## ✅ 체크리스트

설치 완료 전 확인 사항:

- [ ] Docker가 설치되고 실행 중
- [ ] Docker Compose가 설치됨
- [ ] 사용자가 docker 그룹에 속함
- [ ] 필요한 포트가 사용 가능
- [ ] aton_server 디렉토리가 클론됨
- [ ] .env 파일이 존재하고 설정이 확인됨
- [ ] docker-compose up -d 성공
- [ ] 모든 컨테이너가 "Up" 상태
- [ ] InfluxDB 응답 확인 (curl http://localhost:8086/ping)
- [ ] RESTful API 응답 확인 (curl http://localhost:5000)
- [ ] MQTT 연결 확인 (mosquitto_pub/sub)

---

**시작 준비가 되셨나요?**

```bash
# 1단계: 전제조건 확인
./check_prerequisites.sh

# 2단계: 설치 (필요시)
sudo ./setup_aton_server.sh
newgrp docker

# 3단계: 서비스 시작
./test_services.sh
```

모든 것이 정상이면 서비스가 실행 중입니다! 🎉
