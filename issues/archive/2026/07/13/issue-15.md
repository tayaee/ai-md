# issue-15: verify-issue-1.sh의 .env 검증 dead-code 정리 (fixing issue-1)

## 의존성
issue-1 완료 후

## 계보
- **원본 이슈**: issue-1 (리포 뼈대 및 POC 시나리오 명세 파일 생성)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-1__TYPE-code-review__BY-minimax3.md` (Finding 1)
- **인용**: "`.env`가 untracked 상태일 때 `git status --porcelain`은 `?? .env` (앞에 공백)을 출력한다. regex `(^|/)\.env$`는 `.env` 직전 문자가 `^`(행 시작) 또는 `/`여야 매치하는데, `?? .env`에서는 `.env` 직전이 공백이므로 매치되지 않는다. ... 25행의 `test ! -f .env`가 먼저 실패해 스크립트가 중단되므로 27행은 도달하지 못한다."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 심각도는 리뷰어 제안(good-to-fix)을 그대로 채택.

## 목표
`regression-tests/verify-issue-1.sh`의 `.env` 노출 검증 로직에서 도달 불가능한(dead) 코드를 정리하고, 회귀 보호력을 실질적으로 회복한다.

## 배경
- `regression-tests/verify-issue-1.sh` 25행 `test ! -f .env`가 `.env`가 실재할 경우 먼저 실패해 스크립트를 종료시키므로, 27–29행의 `git status --porcelain` 기반 regex 검사는 항상 도달하지 못한다.
- 게다가 그 regex(`(^|/)\.env$`) 자체도 `git status --porcelain`의 `?? .env` 출력(파일명 앞 공백)과 매치되지 않아, 만에 하나 도달하더라도 의도대로 동작하지 않는다.

## 구현 상세
`regression-tests/verify-issue-1.sh`를 수정한다:
- 27–29행(`git status --porcelain` 기반 검사)을 삭제한다 — 25행의 `test ! -f .env`가 이미 같은 케이스를 잡는다.
- 또는 삭제 대신 살리기로 결정한다면, regex를 untracked 전용으로 좁힌다: `grep -qE '^\?\? \.env$'` (또는 `grep -qF '.env'`로 단순화).

## 하지 말 것
- 25행(`test ! -f .env`) 검사 자체는 건드리지 않는다 — 정상 동작.

## 완료 조건
- [ ] dead-code 검사가 삭제되었거나, 실제로 도달·매치 가능하도록 수정됨
- [ ] `touch .env && bash regression-tests/verify-issue-1.sh`가 여전히 `.env` 존재를 이유로 실패함 (기존 25행 동작 유지)
- [ ] `rm .env && bash regression-tests/verify-issue-1.sh`가 `OK`로 통과함
- 검증 명령: `bash regression-tests/verify-issue-1.sh && echo OK`

## 구현 결과
- **구현 완료 일시**: 2026-07-13T22:13:55Z
- **변경 파일**:
  - `regression-tests/verify-issue-1.sh` — 27–29행 dead-code 블록(`git status --porcelain` regex 검사) 삭제
  - `regression-tests/verify-issue-15.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-15-fixing-1.md` — 본 파일 (구 `__STATE-later` 태그 떼고 승격)
- **계획 대비 차이**: 없음 — line 25 가드는 그대로 두고 dead-code만 제거하는 단순안 선택
- **검증 결과**:
  - `bash regression-tests/verify-issue-15.sh` → **OK**
    - dead-code(27–29행) 부재 확인 ✓
    - `.env` 부재 시 OK 출력 ✓
    - `.env` 존재 시 line 25 가드로 비정상 종료 + `'.env should not exist'` 사유 stderr 출력 ✓
    - 사전 가드: 본인 `.env`가 이미 있으면 destructive cleanup 회피 위해 즉시 중단
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 11개) → **모두 통과** (15 새로 포함)
