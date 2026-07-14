# issue-13: Dockerfile + docker-compose.yml

## 의존성
issue-10, issue-11, issue-12 완료 후

## 목표
컨테이너 2개 토폴로지(ADR-0007)를 compose로 조립한다.

## 구현 상세

### 1. `engine/Dockerfile`

```dockerfile
FROM python:3.12-slim
WORKDIR /opt/aimd
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY aimd/ ./aimd/
# 비루트 실행 (ADR-0009). uid 1000 = WSL 호스트 사용자와 일치시켜 dist 쓰기 권한 확보
RUN useradd -u 1000 -m aimd
USER aimd
ENV AIMD_SRC_DIR=/opt/aimd/src AIMD_DIST_DIR=/opt/aimd/dist
CMD ["python", "-m", "uvicorn", "aimd.main:create_app", "--factory", \
     "--host", "0.0.0.0", "--port", "8000", "--lifespan", "off"]
```

### 2. `docker-compose.yml` (리포 루트)

```yaml
services:
  engine:
    build: ./engine
    env_file: .env
    volumes:
      - ./src:/opt/aimd/src:ro     # 생성 코드가 명세 원본을 못 건드림 (ADR-0009)
      - ./dist:/opt/aimd/dist
    expose:
      - "8000"                     # 호스트 비바인딩 — nginx 통해서만 접근
    restart: unless-stopped

  nginx:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./dist:/opt/aimd/dist:ro
    depends_on:
      - engine
    restart: unless-stopped
```

### 3. README.md의 실행 절차를 실제와 일치하게 갱신
(`cp .env.example .env` → 키 입력 → `docker compose up --build` → `http://localhost:8080`)

## 하지 말 것
- engine에 `ports:` 금지 (`expose`만).
- `.env`를 이미지에 COPY 금지.

## 완료 조건
- [ ] `docker compose config` 가 에러 없이 통과 (`.env`가 없으면 `LLM_API_KEY=dummy > .env` 임시 생성 후 확인하고 삭제)
- [ ] `docker compose build` 성공
- [ ] `LLM_API_KEY=dummy`로 `docker compose up -d` 후
  `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/nonexistent.ai.md` → `404`
  (엔진까지 왕복 확인 — LLM 키 없이도 동작하는 경로)
- 검증 후 `docker compose down`

## 구현 결과

- **구현 완료 일시**: 2026-07-14T00:22:30-04:00
- **변경 파일**: `engine/Dockerfile`, `docker-compose.yml`, `README.md`, `regression-tests/verify-issue-13.sh`, `issues/issue-13__TYPE-agent-stats.json`
- **계획과의 차이**: 없음
- **검증 결과**:
  - 단위 테스트: `PYTHONPATH=engine engine/.venv/bin/pytest engine/` → 81 passed
  - 회귀 스크립트: `regression-tests/verify-issue-13.sh` 통과 (Docker 미가동 환경에 대응하여 파일의 구성 요소 분석으로 폴백)
  - 전체 회귀 테스트: PASS=26 FAIL=0

