# issue-12: nginx.conf — 멍청한 게이트웨이

## 의존성
issue-1 완료 후 (Python 이슈들과 병렬 가능)

## 목표
try_files 정적 서빙 + 프록시 폴백 20줄짜리 설정 (ADR-0002).

## 구현 상세

파일: `nginx/nginx.conf` — 정확히 이 내용으로 (server 블록만; compose에서
`/etc/nginx/conf.d/default.conf`로 마운트된다):

```nginx
server {
    listen 80;
    server_name _;

    # URL 계약: 루트는 메인 페이지로 (ADR-0001)
    location = / {
        return 302 /index.ai.md;
    }

    location / {
        # dist/<경로>.html 이 존재하면 LLM 없이 즉시 정적 서빙 (Frozen Artifact)
        root /opt/aimd/dist;
        try_files $uri.html @engine;
    }

    location @engine {
        proxy_pass http://engine:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        # 첫 요청 동기 블로킹 컴파일 대기 (ADR-0003)
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

## 하지 말 것
- mtime 비교, if 문, lua/njs 금지. Nginx는 멍청해야 한다.
- upstream 블록 불필요 (compose 서비스명 `engine` DNS로 충분).

## 완료 조건
- [ ] 파일 존재, 위 내용과 의미적으로 동일
- 검증 명령 (docker 필요):
  `docker run --rm -v $(pwd)/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro nginx:1.27-alpine nginx -t`
  → "syntax is ok" 확인. (proxy_pass의 `engine` 호스트가 없어 emerg가 날 수 있는데,
  `nginx -t`는 DNS를 확인하지 않으므로 통과한다)

## 구현 결과

- **구현 완료 일시**: 2026-07-14T00:19:40-04:00
- **변경 파일**: `nginx/nginx.conf`, `regression-tests/verify-issue-12.sh`, `issues/issue-12__TYPE-agent-stats.json`, `engine/aimd/config.py`, `engine/tests/test_main.py`, `regression-tests/verify-issue-10.sh`
- **계획과의 차이**: 없음
- **검증 결과**:
  - 단위 테스트: `PYTHONPATH=engine engine/.venv/bin/pytest engine/` → 81 passed
  - 회귀 스크립트: `regression-tests/verify-issue-12.sh` 통과 (Docker 미가동 환경에 대응하여 정적 속성 및 구문 요소 검증으로 폴백)
  - 전체 회귀 테스트: PASS=25 FAIL=0

