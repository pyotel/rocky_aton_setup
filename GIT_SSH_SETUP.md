# Git SSH 설정 가이드

Rocky Linux에서 Git을 SSH로 사용하기 위한 설정이 완료되었습니다.

## ✅ 완료된 설정

### 1. SSH 키 확인
기존 SSH 키가 있고 GitHub에 등록되어 있습니다:
- **위치**: `~/.ssh/id_rsa` (private key)
- **공개키**: `~/.ssh/id_rsa.pub`
- **GitHub 인증**: ✅ 성공 (pyotel 계정)

### 2. Git Remote 변경
```bash
# 변경 전 (HTTPS)
origin  https://github.com/pyotel/aton_server.git

# 변경 후 (SSH)
origin  git@github.com:pyotel/aton_server.git
```

## 🔑 SSH 공개키

GitHub/GitLab 등에 등록된 공개키:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCbDb5+IYjXu9gcT70UmG7+RaO64lA/YqgFCOJ6SrVX6J7rDR+Wpz+y/yCLuEM/9qeleK8Z1beZpecnFXSjUcAedGD7kmuXKdMEWOJiMHnih7lJGmG0tM/MsC40g/pKmJ7iQBDwHR5ZSUzbGYoBWaV87gIUPIRPAOAszJN8CICqNGX/MbSC13zEeguVx3gOSOYp1qf62m4nwaez4V6m6xweLlgaqYNbg2WVo+iLve3eCPUhOUW+Go8cy6aDelidESRxXxPBzjxsg9e0+i9LPxe7ZZNxw2p8dxfrPVF1yKH9lnhUROYCyMqKKdBXENfQCRhW4VIk5XCXiIrt3RAFUhvb6FLCWTcnj9rDq61ZaSAu3JSFabKu3U5I1Nux1PvS8H0w5e5HuIgfXZpmlQMHX4+vC/DbAfDbWLzrrYdAZNefDl+su01oQBJrfeb0HOucs7lWnACPbb6+kzzTrVWVWXZU6me4MHZ9LRZoTLGdwdzzLuxazjY8k2ec6102L2EaiXE= keti@localhost.localdomain
```

## 📋 Git 명령어 사용법

### 기본 명령어

```bash
cd /home/keti/src/rocky_aton_setup/aton_server

# 원격 저장소에서 최신 코드 가져오기
git fetch

# 원격 저장소에서 가져오고 병합
git pull

# 로컬 변경사항 커밋
git add .
git commit -m "커밋 메시지"

# 원격 저장소에 푸시
git push origin main

# 브랜치 확인
git branch -a

# 상태 확인
git status
```

### SSH를 사용하는 다른 저장소 클론

```bash
# GitHub
git clone git@github.com:username/repository.git

# GitLab
git clone git@gitlab.com:username/repository.git

# 사용자 정의 서버
git clone git@your-server.com:repository.git
```

## 🔧 SSH 설정 관리

### SSH 키 확인
```bash
# 공개키 보기
cat ~/.ssh/id_rsa.pub

# SSH 키 목록
ls -la ~/.ssh/
```

### GitHub 연결 테스트
```bash
ssh -T git@github.com

# 성공 시 출력:
# Hi pyotel! You've successfully authenticated, but GitHub does not provide shell access.
```

### GitLab 연결 테스트
```bash
ssh -T git@gitlab.com
```

### 새로운 SSH 키 생성 (필요한 경우)
```bash
# 새 SSH 키 생성
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 또는 Ed25519 알고리즘 사용 (권장)
ssh-keygen -t ed25519 -C "your_email@example.com"

# SSH 에이전트에 키 추가
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

### SSH 공개키를 GitHub에 등록하기
```bash
# 1. 공개키 복사
cat ~/.ssh/id_rsa.pub

# 2. GitHub 웹사이트에서:
#    Settings → SSH and GPG keys → New SSH key
#    Title: 원하는 이름 (예: Rocky Linux Server)
#    Key: 복사한 공개키 붙여넣기

# 3. 테스트
ssh -T git@github.com
```

## 🔐 SSH Config 설정 (선택사항)

더 편리한 SSH 사용을 위한 설정:

```bash
# SSH config 파일 생성/편집
vi ~/.ssh/config
```

**~/.ssh/config 내용**:
```
# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

# GitLab
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes

# 사용자 정의 호스트
Host myserver
    HostName your-server.com
    User git
    Port 22
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
```

**권한 설정**:
```bash
chmod 600 ~/.ssh/config
```

## 🛠️ 트러블슈팅

### 1. Permission denied (publickey)

```bash
# SSH 에이전트 시작
eval "$(ssh-agent -s)"

# SSH 키 추가
ssh-add ~/.ssh/id_rsa

# 권한 확인
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### 2. Host key verification failed

```bash
# known_hosts 제거
rm ~/.ssh/known_hosts

# 다시 연결 시도
ssh -T git@github.com
```

### 3. Git push 권한 없음

```bash
# 원격 저장소 URL 확인
git remote -v

# SSH로 변경
git remote set-url origin git@github.com:username/repository.git

# 권한이 있는지 확인 (저장소 소유자 또는 collaborator)
```

### 4. SSH 키가 작동하지 않음

```bash
# SSH 연결 디버그
ssh -vT git@github.com

# SSH 키 테스트
ssh-keygen -l -f ~/.ssh/id_rsa.pub
```

### 5. 여러 GitHub 계정 사용

**~/.ssh/config**:
```
# 첫 번째 GitHub 계정
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa

# 두 번째 GitHub 계정
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_work
```

**사용법**:
```bash
# 첫 번째 계정
git clone git@github.com:username/repo.git

# 두 번째 계정
git clone git@github-work:work-username/repo.git
```

## 📚 추가 Git 설정

### Git 사용자 정보 설정

```bash
# 전역 설정
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 특정 저장소만 설정
cd /path/to/repository
git config user.name "Your Name"
git config user.email "your.email@example.com"

# 설정 확인
git config --list
```

### Git 편의 기능

```bash
# 색상 활성화
git config --global color.ui auto

# 기본 편집기 설정
git config --global core.editor vim

# 자동 줄바꿈 변환 (Linux)
git config --global core.autocrlf input

# Credential 저장 (HTTPS 사용 시)
git config --global credential.helper cache
```

### Git Alias 설정

```bash
# 유용한 alias 추가
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.unstage 'reset HEAD --'
git config --global alias.last 'log -1 HEAD'

# 사용 예:
git st  # = git status
git co main  # = git checkout main
```

## 🔒 보안 권장사항

1. **SSH 키 보호**
   ```bash
   # Private key 권한
   chmod 600 ~/.ssh/id_rsa

   # 디렉토리 권한
   chmod 700 ~/.ssh
   ```

2. **Passphrase 사용**
   - SSH 키 생성 시 passphrase 설정 권장
   - ssh-agent로 자동 관리 가능

3. **정기적인 키 교체**
   - 보안을 위해 1-2년마다 SSH 키 교체

4. **SSH 키 백업**
   ```bash
   # 안전한 위치에 백업
   cp ~/.ssh/id_rsa ~/backup/ssh_key_backup
   cp ~/.ssh/id_rsa.pub ~/backup/ssh_key_backup.pub
   ```

5. **접근 제한**
   - GitHub/GitLab에서 필요한 권한만 부여
   - Deploy keys 또는 read-only keys 사용 고려

## ✅ 체크리스트

- [x] SSH 키가 생성되어 있음
- [x] SSH 키가 GitHub에 등록됨
- [x] GitHub SSH 연결 테스트 성공
- [x] Git remote가 SSH로 변경됨
- [ ] Git 사용자 정보 설정 (필요시)
- [ ] SSH config 설정 (선택사항)
- [ ] 다른 저장소도 SSH로 변경 (필요시)

## 📖 참고 자료

- [GitHub SSH 키 설정 가이드](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [GitLab SSH 키 설정 가이드](https://docs.gitlab.com/ee/user/ssh.html)
- [Git 공식 문서](https://git-scm.com/doc)
- [Pro Git Book (한글)](https://git-scm.com/book/ko/v2)

## 💡 자주 사용하는 명령어 모음

```bash
# 저장소 상태 확인
git status

# 변경사항 확인
git diff

# 로그 보기
git log --oneline --graph --all

# 원격 브랜치 확인
git branch -r

# 로컬 변경사항 임시 저장
git stash
git stash pop

# 특정 파일만 커밋
git add specific-file.txt
git commit -m "Update specific file"

# 마지막 커밋 수정
git commit --amend

# 원격 저장소 정보 업데이트
git fetch --prune

# 브랜치 생성 및 전환
git checkout -b new-branch

# 브랜치 병합
git merge branch-name

# 원격 브랜치 삭제
git push origin --delete branch-name
```

---

**설정 완료! 이제 SSH로 Git을 사용할 수 있습니다.** 🎉

```bash
# 테스트
cd /home/keti/src/rocky_aton_setup/aton_server
git fetch
git pull
```
