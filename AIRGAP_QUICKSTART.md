# 폐쇄망 환경 설치 빠른 시작 가이드

이 문서는 ATON Server를 폐쇄망 환경에서 빠르게 설치하는 방법을 요약합니다.

## 📋 체크리스트

### 준비 단계 (인터넷 연결 환경)

- [ ] Docker 및 Docker Compose 설치 확인
- [ ] `sudo ./export_for_airgap.sh` 실행
- [ ] `airgap_package.tar.gz` 파일 생성 확인
- [ ] USB에 파일 복사

### 설치 단계 (폐쇄망 환경)

- [ ] USB에서 파일 복사
- [ ] `tar xzf airgap_package.tar.gz` 압축 해제
- [ ] `sudo ./scripts/install_airgap.sh` 실행
- [ ] 로그아웃 후 재로그인
- [ ] `cd aton_server/aton_server_msa`
- [ ] `.env` 파일 확인 및 수정
- [ ] `docker compose up -d` 서비스 시작
- [ ] `docker compose ps` 상태 확인

## 🚀 빠른 명령어

### 1. 패키지 준비 (인터넷 환경)

#### 방법 A: 직접 생성

```bash
# 패키지 생성
sudo ./export_for_airgap.sh

# USB에 복사
cp airgap_package.tar.gz /media/usb/
sync
umount /media/usb
```

#### 방법 B: 원격 서버에서 다운로드

```bash
# 원격 서버에서 scp로 다운로드
./download_airgap_package.sh -h 192.168.1.100

# 자동 압축 해제
./download_airgap_package.sh -h 192.168.1.100 -e

# 사용자 및 경로 지정
./download_airgap_package.sh -u keti -h 192.168.1.100 -r /path/to/airgap_package.tar.gz
```

### 2. 폐쇄망 설치

```bash
# USB에서 복사 및 압축 해제
cp /media/usb/airgap_package.tar.gz ~/
cd ~
tar xzf airgap_package.tar.gz
cd airgap_package

# 설치
sudo ./scripts/install_airgap.sh

# 로그아웃 후 재로그인
exit

# 서비스 시작
cd ~/airgap_package/aton_server/aton_server_msa
docker compose up -d

# 상태 확인
docker compose ps
docker compose logs -f
```

## 🔍 빠른 확인

### Docker 이미지 확인

```bash
docker images | grep -E "influxdb|mosquitto|comm2center|restfulapi"
```

**예상 출력:**
```
influxdb                    1.8       ...
eclipse-mosquitto           1.5.6     ...
aton_server_msa-comm2center latest    ...
aton_server_msa-restfulapi  latest    ...
```

### 서비스 상태 확인

```bash
docker compose ps
```

**예상 출력:** 모든 서비스가 `Up` 상태

### 포트 확인

```bash
sudo netstat -tulpn | grep -E '5000|8086|31883'
```

**예상 출력:**
```
tcp  0.0.0.0:5000   (RESTful API)
tcp  0.0.0.0:8086   (InfluxDB)
tcp  0.0.0.0:31883  (MQTT)
```

### 서비스 테스트

```bash
# InfluxDB
curl http://localhost:8086/ping

# RESTful API
curl http://localhost:5000/

# 로그 확인
docker compose logs --tail=20
```

## ⚙️ 기본 설정

### 서비스 엔드포인트

- RESTful API: `http://localhost:5000`
- InfluxDB: `http://localhost:8086`
- MQTT: `mqtt://localhost:31883`

### 기본 계정

**InfluxDB:**
- 사용자: `root`
- 비밀번호: `keti1234`
- DB: `ketidb`

**MQTT:**
- 사용자: `keti`
- 비밀번호: `keti1234`

**⚠️ 프로덕션 환경에서는 반드시 비밀번호를 변경하세요!**

```bash
vi ~/airgap_package/aton_server/aton_server_msa/.env
```

## 🛠️ 자주 사용하는 명령어

### Docker Compose

```bash
# 서비스 시작
docker compose up -d

# 서비스 중지
docker compose stop

# 서비스 재시작
docker compose restart

# 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f [influxdb|mosquitto|comm2center|restfulapi]

# 서비스 종료 및 삭제
docker compose down
```

### Docker

```bash
# 실행 중인 컨테이너
docker ps

# 모든 컨테이너
docker ps -a

# 이미지 목록
docker images

# 컨테이너 로그
docker logs [container_name]

# 컨테이너 접속
docker exec -it [container_name] /bin/bash
```

## ❌ 문제 해결

### Docker 권한 오류

```bash
sudo usermod -aG docker $USER
exit  # 로그아웃 후 재로그인
```

### 포트 충돌

```bash
# 포트 사용 확인
sudo netstat -tulpn | grep -E '5000|8086|31883'

# 프로세스 종료 또는 docker compose.yml 수정
```

### 서비스 시작 실패

```bash
# 로그 확인
docker compose logs

# Docker 서비스 재시작
sudo systemctl restart docker

# 서비스 재시작
docker compose restart
```

### 이미지 없음

```bash
# 수동 이미지 로드
cd ~/airgap_package/docker_images
docker load -i influxdb_1.8.tar
docker load -i mosquitto_1.5.6.tar
docker load -i comm2center.tar
docker load -i restfulapi.tar
```

### 방화벽 문제

```bash
# 포트 열기
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8086/tcp
sudo firewall-cmd --permanent --add-port=31883/tcp
sudo firewall-cmd --reload
```

## 📊 시스템 모니터링

### 리소스 사용량

```bash
# 디스크 사용량
df -h

# 메모리 사용량
free -h

# Docker 디스크 사용량
docker system df

# 컨테이너 리소스 사용량
docker stats
```

### 로그 확인

```bash
# 모든 서비스 로그
docker compose logs --tail=100

# 실시간 로그
docker compose logs -f

# 시스템 로그
sudo journalctl -xe

# Docker 서비스 로그
sudo journalctl -u docker
```

## 🔄 서비스 업데이트

### 백업

```bash
# 데이터 백업
tar czf backup_$(date +%Y%m%d).tar.gz \
    ~/influxdb \
    ~/influxdb2 \
    ~/airgap_package/aton_server/aton_server_msa/mosquitto/data \
    ~/airgap_package/aton_server/aton_server_msa/restfulapi/img
```

### 업데이트

```bash
# 서비스 중지
docker compose down

# 백업 확인
ls -lh backup_*.tar.gz

# 새 패키지 설치
# (새로운 airgap_package로 교체)

# 서비스 시작
docker compose up -d
```

## 📝 시스템 요구사항

### 최소

- Rocky Linux 9.4+
- 2 CPU cores
- 2GB RAM
- 10GB disk

### 권장

- Rocky Linux 9.6
- 4+ CPU cores
- 4GB+ RAM
- 20GB+ SSD

## 📞 도움말

### 추가 문서

- 상세 가이드: `AIRGAP_GUIDE.md`
- 일반 설치: `INSTALL_INSTRUCTIONS.md`
- 빠른 시작: `QUICKSTART.md`

### 로그 수집

문제 발생 시 다음 정보를 수집하세요:

```bash
# 시스템 정보
uname -a > system_info.txt
cat /etc/os-release >> system_info.txt

# Docker 정보
docker version >> system_info.txt
docker compose version >> system_info.txt
docker images >> system_info.txt
docker ps -a >> system_info.txt

# 서비스 로그
docker compose logs > service_logs.txt

# 시스템 로그
journalctl -xe > system_logs.txt
```

---

**더 자세한 내용은 `AIRGAP_GUIDE.md`를 참조하세요.**
