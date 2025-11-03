# ATON Server MSA 빠른 시작 가이드

이 가이드는 Rocky Linux 9에서 ATON Server MSA를 빠르게 시작하는 방법을 설명합니다.

## 전제 조건

- Rocky Linux 9.4 이상
- sudo 권한
- 인터넷 연결

## 3단계 빠른 시작

### 1단계: 필수 패키지 설치

```bash
cd /home/keti/src/rocky_aton_setup
sudo ./setup_aton_server.sh
```

이 스크립트는 다음을 자동으로 설치합니다:
- Docker Engine
- Docker Compose
- 필요한 의존성 패키지
- 방화벽 설정

**중요**: 설치 후 로그아웃하고 다시 로그인하여 Docker 그룹 권한을 활성화하세요!

```bash
exit  # 로그아웃
# SSH로 다시 접속
```

또는 즉시 적용:
```bash
newgrp docker
```

### 2단계: ATON Server 서비스 시작

```bash
cd /home/keti/src/rocky_aton_setup
./test_services.sh
```

이 스크립트는 자동으로:
- Docker 및 Docker Compose 설치 확인
- ATON Server 서비스 시작 (docker-compose up -d)
- 모든 서비스 상태 확인
- InfluxDB, MQTT, RESTful API 테스트 수행

### 3단계: 서비스 확인

서비스가 정상적으로 실행되면 다음 엔드포인트에 접근할 수 있습니다:

#### RESTful API 테스트
```bash
curl http://localhost:5000
```

#### InfluxDB 테스트
```bash
curl http://localhost:8086/ping
```

#### MQTT 테스트
```bash
# mosquitto-clients 설치 (처음 한 번만)
sudo dnf install -y mosquitto

# MQTT 발행 테스트
mosquitto_pub -h localhost -p 31883 -t "test/topic" -m "Hello ATON" -u keti -P keti1234

# MQTT 구독 테스트 (다른 터미널에서)
mosquitto_sub -h localhost -p 31883 -t "#" -u keti -P keti1234 -v
```

## 기본 인증 정보

### InfluxDB
- URL: http://localhost:8086
- 데이터베이스: ketidb
- 사용자: root
- 비밀번호: keti1234

### MQTT Broker
- URL: mqtt://localhost:31883
- 사용자: keti
- 비밀번호: keti1234

### RESTful API
- URL: http://localhost:5000

## 일반적인 명령어

### 서비스 관리

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 서비스 시작
docker-compose up -d

# 서비스 중지
docker-compose stop

# 서비스 재시작
docker-compose restart

# 서비스 상태 확인
docker-compose ps

# 로그 보기
docker-compose logs -f

# 특정 서비스 로그만
docker-compose logs -f restfulapi
docker-compose logs -f influxdb
docker-compose logs -f mosquitto
docker-compose logs -f comm2center
```

### 문제 해결

```bash
# 모든 서비스 재시작
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
docker-compose restart

# 서비스 중지 및 재시작
docker-compose down
docker-compose up -d

# 컨테이너 상태 확인
docker ps -a

# 로그에서 오류 찾기
docker-compose logs | grep -i error
```

## 다음 단계

1. **보안 설정**: `.env` 파일의 기본 비밀번호 변경
   ```bash
   cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
   vi .env
   ```

2. **서비스 커스터마이징**: `docker-compose.yml` 파일 수정

3. **프로덕션 배포**:
   - HTTPS/TLS 설정
   - 적절한 방화벽 규칙
   - 정기 백업 설정
   - 모니터링 설정

## 추가 문서

- 상세 설치 가이드: [INSTALL_INSTRUCTIONS.md](INSTALL_INSTRUCTIONS.md)
- 전체 문서: [README.md](README.md)
- 원본 프로젝트: https://github.com/pyotel/aton_server

## 문제 발생 시

### Docker 권한 오류
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 포트 충돌
```bash
sudo netstat -tulpn | grep -E '5000|8086|31883'
```

### 서비스가 시작되지 않음
```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
docker-compose logs
```

자세한 트러블슈팅은 [INSTALL_INSTRUCTIONS.md](INSTALL_INSTRUCTIONS.md)를 참조하세요.
