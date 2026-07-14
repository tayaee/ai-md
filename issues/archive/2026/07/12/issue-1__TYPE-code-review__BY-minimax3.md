---
model: MiniMax-M3
---

# issue-1 코드 리뷰

- **리뷰 대상 커밋**: `142b703` (root commit)
- **리뷰어 모델**: MiniMax-M3
- **리뷰 일시**: 2026-07-12
- **리뷰 범위**: `.env.example`, `.gitignore`, `README.md`, `dist/.gitkeep`, `engine/aimd/__init__.py`, `engine/requirements-dev.txt`, `engine/requirements.txt`, `engine/tests/__init__.py`, `issues/archive/2026/07/12/issue-1.md`, `regression-tests/verify-issue-1.sh`, `src/convert.ai.md`, `src/index.ai.md`
- **회귀 스크립트 실행 결과**: `regression-tests/verify-issue-1.sh` → `OK` (정상 통과 확인)
- **전제**: 이 이슈는 "코드 한 줄 작성 금지" 명시 제약이 있는 순수 스캐폴딩. Python 코드 부재로 ruff/pyright/pytest 적용 대상 아님.

---

## 종합 평가

스펙 vs 실제 파일 10개(`.gitignore`, `.env.example`, `engine/requirements.txt`, `engine/requirements-dev.txt`, `engine/aimd/__init__.py`, `engine/tests/__init__.py`, `dist/.gitkeep`, `src/index.ai.md`, `src/convert.ai.md`, `README.md`)는 모두 **바이트 단위로 명세 일치** 확인. `.env`는 추적되지 않으며 `.gitignore`가 정상 작동. `.env.example`에 실제 비밀값 없음. README의 경고 문단·도큐먼트 링크·em-dash(`—`)·중간점(`·`) 모두 정확.

다만 회귀 스크립트에 사각지대 1건, README의 ngrok 명령에 문서 정확성 이슈 1건, 구현 결과 보고서와 실제 산출물 카운트 불일치 1건 발견.

---

## Finding 1 — 회귀 스크립트의 git status regex 사각지대

| 항목 | 내용 |
|---|---|
| 파일:라인 | `regression-tests/verify-issue-1.sh:27` |
| 코드 인용 | `if git status --porcelain 2>/dev/null \| grep -qE '(^\|/)\.env$'; then` |
| 실패 시나리오 | `.env`가 untracked 상태일 때 `git status --porcelain`은 `?? .env` (앞에 공백) 을 출력한다. regex `(^\|/)\.env$`는 `.env` 직전 문자가 `^`(행 시작) 또는 `/`여야 매치하는데, `?? .env`에서는 `.env` 직전이 **공백**이므로 매치되지 않는다. 검증 결과 (`echo "?? .env" \| grep -qE '(^\|/)\.env$'`) → `NO MATCH`. |
| 확인 방법 | `cd /home/user1/git/ai-md && touch .env && bash regression-tests/verify-issue-1.sh` 실행 시 25행의 `test ! -f .env`가 먼저 실패해 스크립트가 중단되므로 27행은 도달하지 못함. 즉 27행은 **사각지대가 있는 dead-code 검사**. |
| 심각도 제안 | good-to-fix |

**수정 제안**: 27–29행 전체를 삭제하거나, regex를 `grep -qE '^\?\? \.env$'`로 바꿔 untracked 전용으로 좁히거나, `grep -qF '.env'`로 단순화. 단 25행이 이미 같은 케이스를 잡으므로 **삭제가 가장 깔끔**.

---

## Finding 2 — README ngrok 명령어의 비표준 `=` 문법

| 항목 | 내용 |
|---|---|
| 파일:라인 | `README.md:19` |
| 코드 인용 | ``**… 일시 공개는 `ngrok http --basic-auth="user:pass" 8080`을 사용하세요.**`` |
| 실패 시나리오 | ngrok v3 CLI의 `--basic-auth` 플래그는 **공백 구분**(`ngrok http --basic-auth "user:pass" 8080`)이 표준이고, `--basic-auth=value` 형식은 ngrok v2 스타일. ngrok v3에서 `=` 접붙이형이 통하는지는 버전/플래그 파서에 따라 다르며, 사용자가 그대로 복붙하면 환경에 따라 인자 파싱 실패로 명령이 거부될 수 있음. |
| 확인 방법 | 로컬에 `ngrok`이 설치돼 있지 않아 직접 재현 불가(컨테이너/호스트 의존). 다만 ngrok 공식 문서(`https://ngrok.com/docs/ngrok-agent/cli/` — WebFetch 필요)는 v3에서 `--basic-auth <value>` (공백) 형식을 제시함. |
| 심각도 제안 | good-to-fix (문서 정확성, 보안 결함 아님) |

**수정 제안**: `` `ngrok http --basic-auth "user:pass" 8080` `` 로 공백 형식으로 변경.

---

## Finding 3 — 구현 결과 보고서가 "10개 파일"이라 명시했으나 실제 변경 파일은 11개

| 항목 | 내용 |
|---|---|
| 파일:라인 | `issues/archive/2026/07/12/issue-1.md:92` (완료 조건), `:99` (변경 파일 목록), `:100` (계획과의 차이) |
| 코드 인용 | 완료 조건: `> - [ ] 위 10개 파일이 정확한 경로에 존재` / 변경 파일 목록: `regression-tests/verify-issue-1.sh` 포함 11개 / 계획과의 차이: `없음 — 명세된 10개 파일을 정확한 경로·내용으로 생성.` |
| 실패 시나리오 | 명세는 정확히 10개 파일만 요구하고 "위 10개 파일"이라 못박았지만, 구현은 11번째 파일 `regression-tests/verify-issue-1.sh`를 추가했고 보고서는 이를 "계획과의 차이 없음"이라 단언함. 두 진술이 모순. |
| 확인 방법 | `git show --stat HEAD` → 12개 파일 변경(issue-1.md 자체 변경 포함) 중 새로 추가된 산출물은 11개. spec의 "구현 상세" 섹션 1–10번과 1:1 대조 시 11번째는 spec 어디에도 언급 없음. |
| 심각도 제안 | good-to-fix (보고서 진술 정확성) |

**수정 제안**: 보고서에서 "10개 파일" → "명세된 10개 파일 + 회귀 테스트 1개"로 정정하거나, spec의 완료 조건에 회귀 스크립트 1줄을 추가해 정합성 회복.

---

## Finding 4 — 회귀 스크립트의 README 검증이 너무 느슨

| 항목 | 내용 |
|---|---|
| 파일:라인 | `regression-tests/verify-issue-1.sh:23` |
| 코드 인용 | `grep -q 'AIMD' README.md \|\| fail "README.md missing title"` |
| 실패 시나리오 | `AIMD` 문자열이 README 어디든 한 번 나오면 통과. 예컨대 누가 실수로 README 본문 어딘가에 "AIMD" 한 단어만 남기고 제목·경고·링크를 모두 지워도 이 검사는 통과함. spec은 제목·한 줄 소개·실행법·경고(굵게)·문서 링크 5개 요소를 모두 요구. |
| 확인 방법 | `sed -i '/^#/d' /tmp/fake.md; echo "AIMD" > /tmp/fake.md; cp /tmp/fake.md README.md; bash regression-tests/verify-issue-1.sh` → `OK` (검증 통과). 단, 현재 README에는 명세된 모든 요소가 실제로 존재해 실용적 위험은 낮음. |
| 심각도 제안 | good-to-fix (테스트 품질 — 회귀 보호력 부족) |

**수정 제안**: spec 요구 5개 요소를 각각 grep으로 검증. 예: `grep -q '^# AIMD — AI-powered Markdown Engine'`, `grep -q 'AIMD가 생성한 코드를 그대로 실행'`, `grep -qE '\*\*.*ngrok http --basic-auth'`, `grep -q 'docs/SPEC.md'`, `grep -q 'docs/adr/'`. 회귀 스크립트가 spec 진영의 단일 진실 공급원이 되도록.

---

## Spec 일치 검증 (모두 통과, 보강 정리용)

아래는 spec의 "구현 상세 1–10"과 실제 파일의 라인 단위 대조 결과. 차이 0건.

| spec 번호 | 파일 | 라인 수 일치 | 내용 일치 |
|---|---|---|---|
| 1 | `.gitignore` | ✓ (4 라인) | ✓ |
| 2 | `.env.example` | ✓ (6 라인) | ✓ |
| 3 | `engine/requirements.txt` | ✓ (4 라인) | ✓ |
| 4 | `engine/requirements-dev.txt` | ✓ (2 라인) | ✓ |
| 5 | `engine/aimd/__init__.py` | ✓ (빈 파일) | ✓ |
| 6 | `engine/tests/__init__.py` | ✓ (빈 파일) | ✓ |
| 7 | `dist/.gitkeep` | ✓ (빈 파일) | ✓ |
| 8 | `src/index.ai.md` | ✓ (10 라인) | ✓ |
| 9 | `src/convert.ai.md` | ✓ (10 라인) | ✓ |
| 10 | `README.md` | ✓ | 제목·한 줄 소개·실행법·경고(굵게)·문서 링크 모두 포함. em-dash `—`, backtick, `**` 굵게 모두 정확 |

| spec "하지 말 것" | 준수 여부 |
|---|---|
| Python 로직 작성 금지 | ✓ |
| nginx 설정 작성 금지 | ✓ |
| Dockerfile 작성 금지 | ✓ (정확히 Dockerfile/docker-compose/yaml 파일 없음 — `find` 검증) |
| `.env` 파일 생성 금지 | ✓ (`.env` 추적 안 됨 — `git ls-files` 검증) |

| 보안 점검 | 결과 |
|---|---|
| `.env`가 추적 목록에 없는가 | ✓ (`git ls-files \| grep '\.env$'` → empty) |
| `.env`가 working tree에도 없는가 | ✓ (현재 부재, regression test 통과) |
| `.env.example`에 실제 비밀값이 있는가 | ✗ (placeholder `your-key-here`만 존재) |
| `.gitignore`의 `.env` 라인이 정확히 `.env`인가 (인접 공백/주석 없는지) | ✓ (`cat -A`로 검증, 라인 끝 `$`만) |

---

## OWASP Top 10 관점 (이 이슈 적용분)

| 카테고리 | 점검 | 결과 |
|---|---|---|
| A01 Broken Access Control | N/A (코드 없음) | — |
| A02 Cryptographic Failures | README가 ngrok + basic-auth를 권장. basic-auth는 매 요청마다 자격증명 송신 → ngrok HTTPS 위에서는 허용 가능한 일시 공개 수준이나, 자격증명이 평문 저장·로그 노출 위험은 존재. 그러나 **이 이슈는 스캐폴딩 단계이고 추후 docker-compose/nginx에서 더 단단한 경계가 추가됨**. 본 단계에서는 good-to-fix 권고 수준. | good-to-fix (Finding 2와 동일) |
| A03 Injection | N/A (LLM 호출/프롬프트 코드 없음 — 후속 이슈) | — |
| A04 Insecure Design | README 경고 문단은 LLM 임의 코드 실행 위험을 명시. 그러나 README가 권장하는 ngrok basic-auth는 "임시 공개" 용도임을 명시했으므로 의도된 insecure-by-design 영역을 라벨링한 것으로 봄. | OK |
| A05 Security Misconfiguration | `.env.example`이 `.env`로 잘못 복사되지 않게 placeholder 사용, gitignore도 정상. | OK |
| A06 Vulnerable Components | `requirements.txt`는 버전 하한만 지정(`>=`) — lock 파일/상한 없어 재현성·취약점 추적 어려움. 단, **이 이슈는 "로직 작성 금지" 명시 제약으로 lock 파일 도입 불가**. 후속 이슈에서 poetry/uv 도입 검토 필요. | not-applicable (스캐폴딩 제약) |
| A07 Identification & Auth Failures | N/A (코드 없음) | — |
| A08 Software & Data Integrity | N/A (코드 없음 — LLM 출력 신뢰성은 후속 이슈에서 다룸) | — |
| A09 Logging Failures | N/A | — |
| A10 SSRF | N/A | — |

---

## 동시성 / 경계조건

- **경계조건**: 회귀 스크립트 27행의 regex는 위 Finding 1에서 다룸.
- **동시성**: 본 이슈에 동시성 표면 없음 (코드·소켓·파일 핸들러 없음).

---

## 미확인 / 추가 검증 필요 항목 (작성하지 않음)

아래는 의심은 가지만 **이번 리뷰에서 재현·확인하지 못해 finding으로 올리지 않은 것**:

- README.md의 ngrok 명령이 **최신 ngrok v3.x에서 `=` 문법을 실제로 거부하는지** — 컨테이너/호스트에 ngrok 미설치로 미재현. ngrok 공식 문서 cross-check 권장(별도 작업).
- `dist/`에 실제 산출물이 추가될 때 `.gitignore`가 그것들을 무시하지 못함 (`.gitkeep`만 추적됨). 단 spec이 4개 항목만 명시했으므로 **spec 위반은 아님**. 후속 이슈에서 `.gitignore` 보강 필요.
- `requirements.txt`의 상한 부재로 인한 transitive 취약점 가능성 — **이 이슈의 spec 범위 밖**.

---

## 요약

| ID | 제목 | 심각도 |
|---|---|---|
| F1 | verify-issue-1.sh 27행 regex 사각지대 | good-to-fix |
| F2 | README ngrok 명령 비표준 `=` 문법 | good-to-fix |
| F3 | 구현 보고서 "10개" vs 실제 11개 불일치 | good-to-fix |
| F4 | verify-issue-1.sh의 README 검증이 너무 느슨 | good-to-fix |

**must-fix 없음.** 모두 회귀 보호력·문서 정확성·보고서 정합성 부류. spec 자체와의 일치도는 10/10 파일 라인 단위로 확인됨. 회귀 스크립트 자체는 통과(OK)하며, 통과했다는 사실이 spec의 모든 요건을 검증했다는 의미는 아님(F4).
