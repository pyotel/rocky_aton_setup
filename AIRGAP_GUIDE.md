# ATON Server 폐쇄망 환경 설치 가이드

이 가이드는 ATON Server를 완전히 폐쇄된 네트워크 환경(Air-gapped)에서 USB를 통해 설치하는 방법을 설명합니다.

## 개요

폐쇄망 환경에서 설치하려면 다음 두 단계가 필요합니다:

1. **준비 단계** (인터넷 연결 환경): 필요한 모든 파일 다운로드 및 패키징
2. **설치 단계** (폐쇄망 환경): USB를 통해 전송된 파일로 설치

## 1단계: 패키지 준비 (인터넷 연결 환경)

### 1.1 사전 요구사항

인터넷이 연결된 Rocky Linux 9 시스템에서:

```bash
# Docker 및 Docker Compose 설치 확인
docker --version
docker compose version

# 없다면 먼저 설치
sudo ./setup_aton_server.sh
```

### 1.2 폐쇄망 패키지 생성

```bash
# 패키지 생성 스크립트 실행 (root 권한 필요)
sudo ./export_for_airgap.sh
```

이 스크립트는 다음 작업을 수행합니다:
- Docker 이미지 빌드 및 tar 파일로 저장
- 필요한 모든 RPM 패키지 및 의존성 다운로드 (Docker Compose 플러그인 포함)
- 설치 스크립트 및 문서 생성
- 모든 파일을 `airgap_package.tar.gz`로 압축

### 1.3 생성된 패키지 확인

```bash
# 패키지 크기 확인
ls -lh airgap_package.tar.gz

# 내용 확인
tar tzf airgap_package.tar.gz | head -20
```

일반적으로 패키지 크기는 약 1~3GB입니다.

### 1.4 패키지 전송

폐쇄망 환경으로 패키지를 전송하는 방법은 두 가지가 있습니다:

#### 방법 A: USB를 통한 전송

```bash
# USB 마운트 확인
lsblk
df -h

# USB에 복사 (USB가 /media/usb에 마운트되었다고 가정)
cp airgap_package.tar.gz /media/usb/

# 또는 rsync 사용 (진행 상황 표시)
rsync -avh --progress airgap_package.tar.gz /media/usb/

# 안전하게 언마운트
sync
umount /media/usb
```

#### 방법 B: 네트워크를 통한 전송 (폐쇄망이 아닌 경우)

폐쇄망이지만 내부 네트워크가 있는 경우, 원격 서버에서 scp로 다운로드할 수 있습니다:

```bash
# 대상 시스템에서 실행 (원격 서버에서 다운로드)
./download_airgap_package.sh -h <원격서버IP>

# 예제: 원격 서버 192.168.1.100에서 다운로드
./download_airgap_package.sh -h 192.168.1.100

# 자동 압축 해제 옵션
./download_airgap_package.sh -h 192.168.1.100 -e

# 사용자 및 경로 지정
./download_airgap_package.sh -u keti -h 192.168.1.100 -r /path/to/airgap_package.tar.gz

# SSH 포트 지정
./download_airgap_package.sh -h 192.168.1.100 -p 2222
```

**download_airgap_package.sh 옵션:**
- `-u USER`: 원격 서버 사용자명 (기본값: keti)
- `-h HOST`: 원격 서버 호스트 (필수)
- `-r PATH`: 원격 파일 경로 (기본값: ~/src/rocky/airgap_package.tar.gz)
- `-l PATH`: 로컬 저장 경로 (기본값: ./airgap_package.tar.gz)
- `-e`: 다운로드 후 자동 압축 해제
- `-p PORT`: SSH 포트 (기본값: 22)

## 2단계: 폐쇄망 환경 설치

### 2.1 USB에서 파일 복사

폐쇄망 환경의 Rocky Linux 9 시스템에서:

```bash
# USB 마운트
mkdir -p /media/usb
mount /dev/sdb1 /media/usb  # USB 디바이스 경로 확인 필요

# 작업 디렉토리로 복사
cp /media/usb/airgap_package.tar.gz ~/
cd ~

# 압축 해제
tar xzf airgap_package.tar.gz
cd airgap_package

# 내용 확인
ls -la
```

### 2.2 설치 실행

```bash
# 설치 스크립트 실행 (root 권한 필요)
sudo ./scripts/install_airgap.sh
```

설치 스크립트는 다음을 수행합니다:
1. 시스템 시간 동기화
2. RPM 패키지 설치 (Docker, Git, 유틸리티)
3. Docker 서비스 시작
4. Docker 이미지 로드
5. 방화벽 설정 (포트 5000, 8086, 31883)
6. 사용자를 Docker 그룹에 추가

### 2.3 설치 후 설정

```bash
# 로그아웃 후 다시 로그인 (Docker 그룹 권한 적용)
exit

# 다시 로그인 후
cd ~/airgap_package/aton_server/aton_server_msa

# .env 파일 확인
cat .env

# 필요시 비밀번호 변경
vi .env
```

### 2.4 서비스 시작

```bash
# 서비스 시작
docker compose up -d

# 서비스 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f
```

## 3단계: 설치 확인

### 3.1 Docker 이미지 확인

```bash
docker images
```

다음 이미지가 있어야 합니다:
- `influxdb:1.8`
- `eclipse-mosquitto:1.5.6`
- `aton_server_msa-comm2center:latest`
- `aton_server_msa-restfulapi:latest`

### 3.2 서비스 상태 확인

```bash
# 컨테이너 상태
docker compose ps

# 포트 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 서비스 로그
docker compose logs --tail=50
```

### 3.3 서비스 테스트

```bash
# InfluxDB 연결 테스트
curl http://localhost:8086/ping

# RESTful API 테스트
curl http://localhost:5000/

# MQTT 테스트 (mosquitto-clients 설치된 경우)
mosquitto_pub -h localhost -p 31883 -u keti -P keti1234 -t test -m "hello"
```

## 서비스 엔드포인트

설치 완료 후 다음 서비스를 사용할 수 있습니다:

- **RESTful API**: `http://localhost:5000`
- **InfluxDB**: `http://localhost:8086`
  - 사용자: `root`
  - 비밀번호: `keti1234` (기본값)
  - 데이터베이스: `ketidb`
- **MQTT Broker**: `mqtt://localhost:31883`
  - 사용자: `keti`
  - 비밀번호: `keti1234` (기본값)

## 환경 변수 설정

`aton_server/aton_server_msa/.env` 파일에서 다음 설정을 변경할 수 있습니다:

```env
INFLUX_ROOT_USER=root
INFLUX_ROOT_PASSWORD=keti1234
MOSQUITTO_USERNAME=keti
MOSQUITTO_PASSWORD=keti1234
MOSQUITTO_VERSION=1.5.6
```

**중요**: 프로덕션 환경에서는 반드시 기본 비밀번호를 변경하세요!

## 트러블슈팅

### Docker 권한 오류

```bash
# 현재 사용자 그룹 확인
groups

# docker 그룹에 없다면 추가
sudo usermod -aG docker $USER

# 로그아웃 후 다시 로그인
exit
```

### 포트 충돌

다른 서비스가 포트를 사용 중인 경우:

```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 프로세스 종료 또는 docker compose.yml에서 포트 변경
vi ~/airgap_package/aton_server/aton_server_msa/docker compose.yml
```

### Docker 서비스 시작 실패

```bash
# Docker 서비스 상태 확인
sudo systemctl status docker

# 로그 확인
sudo journalctl -u docker -n 50

# 서비스 재시작
sudo systemctl restart docker
```

### 이미지 로드 실패

```bash
# 수동으로 이미지 로드
cd ~/airgap_package/docker_images
docker load -i influxdb_1.8.tar
docker load -i mosquitto_1.5.6.tar
docker load -i comm2center.tar
docker load -i restfulapi.tar

# 이미지 확인
docker images
```

### 컨테이너 시작 실패

```bash
# 로그 확인
docker compose logs

# 특정 서비스 로그
docker compose logs influxdb
docker compose logs mosquitto
docker compose logs comm2center
docker compose logs restfulapi

# 서비스 재시작
docker compose restart
```

### 방화벽 문제

```bash
# 방화벽 상태 확인
sudo firewall-cmd --list-ports

# 수동으로 포트 열기
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --permanent --add-port=31883/tcp
sudo firewall-cmd --reload

# 또는 방화벽 비활성화 (권장하지 않음)
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

## Docker Compose 명령어 참고

```bash
# 서비스 시작 (백그라운드)
docker compose up -d

# 서비스 시작 (포어그라운드)
docker compose up

# 서비스 중지
docker compose stop

# 서비스 중지 및 컨테이너 제거
docker compose down

# 서비스 중지, 컨테이너 및 볼륨 제거
docker compose down -v

# 서비스 상태 확인
docker compose ps

# 로그 보기 (실시간)
docker compose logs -f

# 로그 보기 (마지막 100줄)
docker compose logs --tail=100

# 특정 서비스 로그
docker compose logs -f [service_name]

# 서비스 재시작
docker compose restart

# 특정 서비스 재시작
docker compose restart [service_name]

# 이미지 재빌드 (필요시)
docker compose build --no-cache
```

## 데이터 백업

중요한 데이터는 정기적으로 백업하세요:

```bash
# InfluxDB 데이터
tar czf influxdb_backup.tar.gz ~/influxdb ~/influxdb2

# Mosquitto 데이터
tar czf mosquitto_backup.tar.gz ~/airgap_package/aton_server/aton_server_msa/mosquitto/data

# API 이미지
tar czf api_images_backup.tar.gz ~/airgap_package/aton_server/aton_server_msa/restfulapi/img
```

## 데이터 복구

```bash
# InfluxDB 데이터 복구
tar xzf influxdb_backup.tar.gz -C ~/

# Mosquitto 데이터 복구
tar xzf mosquitto_backup.tar.gz -C ~/airgap_package/aton_server/aton_server_msa/mosquitto/

# API 이미지 복구
tar xzf api_images_backup.tar.gz -C ~/airgap_package/aton_server/aton_server_msa/restfulapi/

# 서비스 재시작
cd ~/airgap_package/aton_server/aton_server_msa
docker compose restart
```

## 보안 권장사항

1. **비밀번호 변경**: `.env` 파일의 모든 기본 비밀번호를 변경하세요
2. **방화벽 설정**: 필요한 포트만 열고 신뢰할 수 있는 IP만 허용하세요
3. **정기 업데이트**: 보안 패치 적용을 위해 정기적으로 시스템을 업데이트하세요
4. **로그 모니터링**: 서비스 로그를 정기적으로 확인하세요
5. **백업**: 중요한 데이터는 정기적으로 백업하세요

## 시스템 요구사항

### 최소 요구사항

- **OS**: Rocky Linux 9.4 또는 9.6
- **CPU**: 2 코어
- **RAM**: 2GB
- **디스크**: 10GB

### 권장 사양

- **OS**: Rocky Linux 9.6
- **CPU**: 4 코어 이상
- **RAM**: 4GB 이상
- **디스크**: 20GB 이상 (SSD 권장)

## FAQ

### Q: 패키지 크기가 너무 큰데 줄일 수 있나요?

A: 패키지 크기는 Docker 이미지와 RPM 패키지로 구성됩니다. 필요 없는 유틸리티 패키지는 `export_for_airgap.sh`에서 제거할 수 있습니다.

### Q: Docker Compose 버전이 맞지 않으면?

A: Docker Compose는 `docker-compose-plugin` RPM 패키지로 설치됩니다. `export_for_airgap.sh` 스크립트가 현재 시스템에서 사용 가능한 버전을 다운로드합니다. 특정 버전이 필요한 경우 스크립트를 수정하여 해당 버전의 RPM을 다운로드하도록 변경하세요.

### Q: 다른 Rocky Linux 버전에서도 작동하나요?

A: Rocky Linux 9.x 버전에서는 대부분 작동합니다. 다른 버전은 테스트가 필요합니다.

### Q: 기존 설치를 업데이트하려면?

A: 새 패키지를 준비하고, 데이터를 백업한 후, 기존 서비스를 중지하고 새로 설치하세요.

```bash
# 데이터 백업
tar czf backup.tar.gz ~/influxdb ~/influxdb2 ~/airgap_package/aton_server/aton_server_msa/mosquitto/data

# 서비스 중지
docker compose down

# 새 패키지로 교체
# ...

# 데이터 복구
# ...

# 서비스 시작
docker compose up -d
```

## 참고 자료

- [Docker 공식 문서](https://docs.docker.com/)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [Rocky Linux 문서](https://docs.rockylinux.org/)
- [InfluxDB 문서](https://docs.influxdata.com/influxdb/v1.8/)
- [Eclipse Mosquitto 문서](https://mosquitto.org/documentation/)

## 지원

문제가 발생하면:

1. 로그 확인: `docker compose logs`
2. 시스템 로그: `journalctl -xe`
3. 트러블슈팅 섹션 참조
4. GitHub 이슈 등록

---

**Copyright 2021 - sycho (aton@2021)**
