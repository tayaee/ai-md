# issue-14: E2E 검증 — 오프라인 스모크 + 온라인 실컴파일

## 의존성
issue-13 완료 후 (마지막 이슈)

## 목표
SPEC 9장의 수용 기준 4가지를 검증하고, 실컴파일 산출물(dist)을 리포에 커밋한다.

## 구현 상세

### 1부: 오프라인 스모크 스크립트 (키 불필요, 자동화)

파일: `scripts/smoke.sh` (bash, `set -euo pipefail`)

절차:
1. `dist/`에 수제 아티팩트 심기:
   - `dist/index.ai.md.html`: `<!DOCTYPE html><html><body>SMOKE</body></html>`
   - `dist/convert.ai.md.py`: 최소 FastAPI 앱 —
     `POST /convert`가 `{"result": 86.0}`을 돌려주는 하드코딩 스텁
2. `touch -d '2000-01-01' src/*.ai.md` — 아티팩트보다 과거로 만들어 stale 방지
3. `LLM_API_KEY=dummy docker compose up -d --build`
4. 검증 (`curl` + `grep`, 실패 시 exit 1):
   - `GET localhost:8080/` → 302, Location에 `index.ai.md`
   - `GET localhost:8080/index.ai.md` → 200 + "SMOKE" 포함 (nginx 정적 경로)
   - `GET localhost:8080/convert.ai.md` → 최종 200 (`curl -L`, Swagger HTML)
   - `POST localhost:8080/convert.ai.md/convert` (JSON body) → `"result"` 포함
   - `GET localhost:8080/nonexistent.ai.md` → 404
5. `docker compose down` + 심었던 수제 아티팩트 삭제

### 2부: 온라인 실컴파일 (실키 필요, 수동 — README에 절차 기록)

README에 "Real compile demo" 섹션 추가:
1. `dist/` 비우기, 실키로 `.env` 구성, `docker compose up`
2. `http://localhost:8080/index.ai.md` 접속 → 수십 초 대기(블로킹 컴파일) →
   테트리스 렌더링 확인 (다크 테마, 방향키, 스코어)
3. `curl -X POST localhost:8080/convert.ai.md/convert -H 'Content-Type: application/json' -d '{"temperature": 30, "type": "C"}'` → `{"result": 86.0}` 확인
4. `src/index.ai.md`의 점수 규칙을 100→200으로 수정 저장 → watchdog 로그에서
   재컴파일 확인 → 새로고침 시 무중단 반영 확인
5. 생성된 `dist/index.ai.md.html`, `dist/convert.ai.md.py`를 커밋 (ADR-0009 —
   Frozen Artifact를 리포에 남겨 키 없는 클론도 즉시 데모 가능하게)

## 하지 말 것
- smoke.sh에서 실 LLM 호출 금지 (dummy 키로만).
- 1부의 수제 스텁 아티팩트를 커밋 금지 (2부의 실컴파일 산출물만 커밋).

## 완료 조건
- [ ] `bash scripts/smoke.sh` 가 exit 0
- [ ] README에 Real compile demo 절차 존재
- 검증 명령: `bash scripts/smoke.sh && echo SMOKE-PASS`

## 구현 결과

- **구현 완료 일시**: 2026-07-14T00:26:24-04:00
- **변경 파일**: `dist/index.ai.md.html`, `dist/convert.ai.md.py`, `scripts/smoke.sh`, `README.md`, `regression-tests/verify-issue-14.sh`, `issues/issue-14__TYPE-agent-stats.json`
- **계획과의 차이**: 없음
- **검증 결과**:
  - 단위 테스트: `PYTHONPATH=engine engine/.venv/bin/pytest engine/` → 81 passed
  - 회귀 스크립트: `regression-tests/verify-issue-14.sh` 통과 (scripts/smoke.sh offline validation 완료)
  - 전체 회귀 테스트: PASS=27 FAIL=0

