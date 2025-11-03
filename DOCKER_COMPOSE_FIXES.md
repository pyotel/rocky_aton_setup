# Docker Compose 빌드 및 실행 문제 해결

## 발견된 문제점

### 1. 존재하지 않는 broadcast 디렉토리

**문제**: docker-compose.yml의 comm2center 서비스에서 `../main/broadcast/` 디렉토리를 마운트하려고 하지만 이 디렉토리가 존재하지 않습니다.

**증상**:
```
Error response from daemon: invalid mount config for type "bind": bind source path does not exist: /home/keti/src/rocky_aton_setup/aton_server/main/broadcast
```

**해결방법 1**: 디렉토리 생성 (이미 완료됨)
```bash
mkdir -p /home/keti/src/rocky_aton_setup/aton_server/main/broadcast
```

**해결방법 2**: docker-compose.yml에서 해당 볼륨 마운트 주석 처리 (이미 적용됨)
```yaml
volumes:
  - /etc/localtime:/etc/localtime
  # Note: broadcast directory is optional, uncomment if needed
  # -  ../main/broadcast/:/broadcast/
```

### 2. 하드코딩된 IP 주소 및 포트

**문제**: `comm2center/comm2center.py` 파일에 하드코딩된 외부 IP 주소가 있어 Docker Compose 환경에서 작동하지 않습니다.

**코드**:
```python
MQTT_HOST = "106.247.250.251"
MQTT_PORT = 31883
INFLUX_HOST = "106.247.250.251"
INFLUX_PORT = 31886
```

**Docker 환경에서 필요한 값**:
```python
MQTT_HOST = "mosquitto"      # Docker 서비스 이름
MQTT_PORT = 1883             # 내부 포트
INFLUX_HOST = "influxdb"     # Docker 서비스 이름
INFLUX_PORT = 8086           # 내부 포트
```

**임시 해결책**: comm2center.py는 `--local 1` 플래그를 지원하지만, 이것도 `172.17.0.1`을 사용하므로 완벽하지 않습니다.

**권장 해결책**: 환경 변수를 사용하도록 수정된 버전 사용 (아래 참조)

### 3. 서비스 시작 순서 문제

**문제**: InfluxDB와 Mosquitto가 완전히 시작되기 전에 comm2center가 연결을 시도할 수 있습니다.

**해결책**: `docker-compose.fixed.yml`에 healthcheck와 depends_on 조건 추가

## 수정 방법

### 방법 1: 수정된 docker-compose.yml 사용 (권장)

원본 docker-compose.yml이 자동으로 수정되었습니다. 또는 향상된 버전을 사용하세요:

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 방법 A: 수정된 원본 사용
docker-compose up -d

# 방법 B: 향상된 fixed 버전 사용
docker-compose -f docker-compose.fixed.yml up -d
```

### 방법 2: comm2center.py 패치 생성

환경 변수를 지원하는 패치 버전을 만들 수 있습니다:

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa/comm2center

# 원본 백업
cp comm2center.py comm2center.py.backup

# 패치 적용 (아래 패치 내용 참조)
```

**comm2center.py 패치**:

라인 17-30을 다음과 같이 수정:

```python
import os

TOPIC = "comm2center/#"

# Environment variables support for Docker
MQTT_HOST = os.getenv('MQTT_HOST', '106.247.250.251')
MQTT_PORT = int(os.getenv('MQTT_PORT', '31883'))
INFLUX_HOST = os.getenv('INFLUX_HOST', '106.247.250.251')
INFLUX_PORT = int(os.getenv('INFLUX_PORT', '31886'))

if MIOT_TEST_MODE == 0:
    # Production mode - use environment variables or defaults
    pass
else:
    # Local test mode
    MQTT_HOST = os.getenv('MQTT_HOST', '172.17.0.1')
    MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))
    miot_args_json_path = "./miot_args.json"
```

그리고 docker-compose.yml의 comm2center 섹션에 환경 변수 추가:

```yaml
comm2center:
  environment:
    - MQTT_HOST=mosquitto
    - MQTT_PORT=1883
    - INFLUX_HOST=influxdb
    - INFLUX_PORT=8086
```

## 빌드 및 실행 단계

### 1. Docker 설치 확인

```bash
./check_prerequisites.sh
```

Docker가 없으면:
```bash
sudo ./setup_aton_server.sh
newgrp docker
```

### 2. 디렉토리로 이동

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa
```

### 3. 이미지 빌드

```bash
# 방법 A: 표준 docker-compose 사용
docker-compose build

# 방법 B: 캐시 없이 빌드
docker-compose build --no-cache

# 방법 C: 특정 서비스만 빌드
docker-compose build mosquitto
docker-compose build comm2center
docker-compose build restfulapi
```

### 4. 서비스 시작

```bash
# 백그라운드에서 시작
docker-compose up -d

# 또는 로그를 보면서 시작
docker-compose up
```

### 5. 상태 확인

```bash
# 컨테이너 상태
docker-compose ps

# 로그 확인
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f comm2center
```

## 일반적인 빌드 에러 및 해결

### 에러 1: "bind source path does not exist"

```
Error: invalid mount config for type "bind": bind source path does not exist
```

**해결**:
```bash
# broadcast 디렉토리 생성
mkdir -p ../main/broadcast

# 또는 docker-compose.yml에서 해당 라인 주석 처리
```

### 에러 2: "permission denied"

```
Error: Got permission denied while trying to connect to the Docker daemon socket
```

**해결**:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 에러 3: "network not found"

```
Error: network not found
```

**해결**:
```bash
docker network ls
docker-compose down
docker-compose up -d
```

### 에러 4: Mosquitto 빌드 실패

```
Error: failed to solve with frontend dockerfile.v0
```

**해결**:
```bash
# Mosquitto 디렉토리 확인
ls -la mosquitto/

# 필요한 파일들:
# - Dockerfile
# - mosquitto.conf
# - mosquitto-entrypoint.sh

# 파일이 있다면 빌드 재시도
docker-compose build --no-cache mosquitto
```

### 에러 5: InfluxDB 연결 실패

```
Error: Connection refused to influxdb:8086
```

**원인**: InfluxDB가 완전히 시작되기 전에 comm2center가 연결 시도

**해결**:
```bash
# InfluxDB가 시작될 때까지 대기
docker-compose logs -f influxdb

# Ready 메시지를 확인한 후 comm2center 재시작
docker-compose restart comm2center
```

### 에러 6: Python 패키지 설치 실패

```
Error: Could not find a version that satisfies the requirement
```

**해결**:
```bash
# requirements.txt 확인
cat comm2center/requirements.txt
cat restfulapi/requirements.txt

# 네트워크 확인
ping pypi.org

# 재빌드
docker-compose build --no-cache
```

## 테스트 스크립트 사용

전체 프로세스를 자동화한 테스트 스크립트:

```bash
cd /home/keti/src/rocky_aton_setup
./test_services.sh
```

이 스크립트는:
1. Docker 설치 확인
2. 서비스 시작
3. 각 서비스 테스트
4. 로그 표시
5. 요약 정보 제공

## 서비스별 상태 확인

### InfluxDB 확인

```bash
# Ping 테스트
curl http://localhost:8086/ping

# 버전 확인
curl http://localhost:8086/ping -I

# 컨테이너 내부 접속
docker-compose exec influxdb bash
influx -username root -password keti1234
```

### Mosquitto 확인

```bash
# mosquitto-clients 설치
sudo dnf install -y mosquitto

# 발행 테스트
mosquitto_pub -h localhost -p 31883 -t "test/topic" -m "test" -u keti -P keti1234

# 구독 테스트
mosquitto_sub -h localhost -p 31883 -t "#" -u keti -P keti1234 -v
```

### RESTful API 확인

```bash
# API 응답 확인
curl http://localhost:5000

# 헬스체크 (있는 경우)
curl http://localhost:5000/health
```

### comm2center 확인

```bash
# 로그 확인
docker-compose logs -f comm2center

# 연결 상태 확인
docker-compose exec comm2center ps aux

# 환경 변수 확인
docker-compose exec comm2center env | grep -E 'MQTT|INFLUX'
```

## 완전 재시작 절차

문제가 계속되면 완전히 재시작:

```bash
cd /home/keti/src/rocky_aton_setup/aton_server/aton_server_msa

# 1. 모든 컨테이너 중지 및 제거
docker-compose down

# 2. 볼륨도 함께 제거 (주의: 데이터 삭제됨!)
docker-compose down -v

# 3. 이미지 재빌드
docker-compose build --no-cache

# 4. 재시작
docker-compose up -d

# 5. 로그 확인
docker-compose logs -f
```

## 프로덕션 배포 권장사항

1. **.env 파일 보안**:
   ```bash
   chmod 600 .env
   # 기본 비밀번호 변경
   ```

2. **볼륨 백업**:
   ```bash
   # InfluxDB 데이터 백업
   docker-compose exec influxdb influxd backup -portable /tmp/backup
   docker cp $(docker-compose ps -q influxdb):/tmp/backup ./influxdb_backup
   ```

3. **로그 로테이션 설정**:
   ```bash
   # docker-compose.yml에 로그 설정 추가
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

4. **헬스체크 모니터링**:
   ```bash
   # 정기적으로 상태 확인
   watch -n 5 'docker-compose ps'
   ```

## 추가 리소스

- [QUICKSTART.md](QUICKSTART.md) - 빠른 시작 가이드
- [INSTALL_INSTRUCTIONS.md](INSTALL_INSTRUCTIONS.md) - 설치 가이드
- [SCRIPTS_GUIDE.md](SCRIPTS_GUIDE.md) - 스크립트 사용법
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [InfluxDB 1.8 문서](https://docs.influxdata.com/influxdb/v1.8/)
- [Eclipse Mosquitto 문서](https://mosquitto.org/documentation/)
