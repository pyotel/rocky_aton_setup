# ATON Server MSA Setup for Rocky Linux 9

이 프로젝트는 Rocky Linux 9.4/9.6에서 ATON Server MSA를 쉽게 설치하고 실행할 수 있도록 도와주는 설정 스크립트를 제공합니다.

## 개요

ATON Server는 항로표지(Aids To Navigation) IoT 장비로부터 데이터를 수집하고 관리하는 MSA(Microservice Architecture) 기반 시스템입니다.

## 프로젝트 구조

```
rocky_aton_setup/
├── aton_server/               # 클론된 ATON Server 리포지토리
│   └── aton_server_msa/       # MSA 서비스 디렉토리
│       ├── docker-compose.yml
│       ├── .env
│       ├── mosquitto/
│       ├── comm2center/
│       └── restfulapi/
├── setup_aton_server.sh       # 자동 설치 스크립트
├── check_prerequisites.sh     # 전제조건 확인 스크립트
├── test_services.sh           # 서비스 테스트 스크립트
├── QUICKSTART.md              # 빠른 시작 가이드
├── INSTALL_INSTRUCTIONS.md    # 상세 설치 가이드
└── README.md                  # 이 파일
```

## 시스템 요구사항

- Rocky Linux 9.4 또는 9.6
- 최소 2GB RAM
- 10GB 이상의 디스크 공간
- 인터넷 연결

## 빠른 시작

### 0. 전제조건 확인 (선택사항)

```bash
./check_prerequisites.sh
```

### 1. 설치 스크립트 실행

```bash
sudo ./setup_aton_server.sh
```

이 스크립트는 다음을 자동으로 설치합니다:
- Docker Engine
- Docker Compose
- Git
- 필요한 유틸리티들
- 방화벽 설정 (포트 5000, 8086, 31883)

### 2. 사용자 그룹 설정 완료

Docker 그룹에 추가된 후에는 로그아웃 후 다시 로그인해야 합니다:

```bash
exit  # 현재 세션 종료
# 다시 로그인
```

### 3. ATON Server 실행

```bash
cd aton_server/aton_server_msa
docker-compose up -d
```

### 4. 서비스 상태 확인

```bash
docker-compose ps
docker-compose logs -f
```

## 서비스 구성

### 주요 컴포넌트

1. **InfluxDB 1.8** - 시계열 데이터베이스
   - 포트: 8086
   - 기본 DB: ketidb
   - 기본 사용자: root / keti1234

2. **Mosquitto MQTT Broker 1.5.6**
   - 포트: 31883
   - 기본 사용자: keti / keti1234

3. **comm2center** - 데이터 수집 서비스
   - MQTT 메시지를 InfluxDB에 저장
   - Python 3.13 기반

4. **RESTful API** - Flask 기반 웹 API
   - 포트: 5000
   - 데이터 조회, 이미지 관리, MQTT 메시지 발행

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

설치 완료 후 다음 엔드포인트로 접근할 수 있습니다:

- **RESTful API**: http://localhost:5000
- **InfluxDB**: http://localhost:8086
- **MQTT Broker**: mqtt://localhost:31883

## 트러블슈팅

### Docker 권한 오류

```bash
# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# 로그아웃 후 다시 로그인하거나
newgrp docker
```

### 포트 충돌

다른 서비스가 이미 포트를 사용 중인 경우:

```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# docker-compose.yml에서 포트 변경
```

### 방화벽 이슈

```bash
# 방화벽 상태 확인
sudo firewall-cmd --list-ports

# 수동으로 포트 열기
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --permanent --add-port=31883/tcp
sudo firewall-cmd --reload
```

### 서비스 로그 확인

```bash
cd aton_server/aton_server_msa

# 모든 서비스 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f influxdb
docker-compose logs -f mosquitto
docker-compose logs -f comm2center
docker-compose logs -f restfulapi
```

### 서비스 재시작

```bash
cd aton_server/aton_server_msa

# 모든 서비스 재시작
docker-compose restart

# 특정 서비스만 재시작
docker-compose restart restfulapi
```

## Docker Compose 명령어

```bash
# 서비스 시작 (백그라운드)
docker-compose up -d

# 서비스 중지
docker-compose stop

# 서비스 중지 및 컨테이너 제거
docker-compose down

# 서비스 상태 확인
docker-compose ps

# 로그 보기
docker-compose logs -f [service_name]

# 서비스 재빌드
docker-compose build --no-cache

# 서비스 재시작
docker-compose restart
```

## 데이터 볼륨

Docker Compose는 다음 디렉토리에 데이터를 저장합니다:

- **InfluxDB 데이터**: ~/influxdb, ~/influxdb2
- **Mosquitto 데이터**: ./mosquitto/data
- **Mosquitto 로그**: ./mosquitto/log
- **API 이미지**: ./restfulapi/img

## 보안 주의사항

1. 프로덕션 환경에서는 `.env` 파일의 기본 비밀번호를 변경하세요
2. 방화벽 규칙을 적절히 설정하세요
3. 필요한 경우 HTTPS/TLS를 설정하세요
4. 정기적으로 시스템과 Docker 이미지를 업데이트하세요

## 원본 저장소

- ATON Server: https://github.com/pyotel/aton_server

## 라이선스

Copyright 2021 - sycho (aton@2021)

## 문의

문제가 발생하면 이슈를 등록해주세요.
