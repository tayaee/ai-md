# issue-28: verify-issue-5.sh의 상대경로가 실행 디렉토리에 의존 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`regression-tests/verify-issue-5.sh:5` 의 `[ ! -f "engine/aimd/prompts.py" ]` 등
파일 경로가 저장소 루트 기준 상대경로로 하드코딩되어 있어, `regression-tests/`
디렉토리 내부에서 직접 실행하면 실패한다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-gemini.md`
(Finding 1, 리뷰어 제안은 must-fix).

## 재검증 메모 (must-fix → good-to-fix 강등 사유)
인용(`verify-issue-5.sh:5`)은 실재하고, "regression-tests/ 안에서 직접
`./verify-issue-5.sh`를 실행하면 실패한다"는 주장 자체는 성립한다. 다만:
- 동일한 상대경로 패턴이 `verify-issue-1.sh`~`verify-issue-22.sh` **전체**에
  공통으로 존재하는 기존 관행이며 issue-5가 새로 만든 결함이 아니다.
- 이 프로젝트의 실제 호출 경로(`acpd`/`aacp.sh`, `autotdd`, 사람의 수동 실행)는
  전부 저장소 루트에서 `bash regression-tests/verify-issue-N.sh` 형태로만
  호출하며, `regression-tests/` 내부로 cd한 뒤 실행하는 경로는 실사용에
  없다.
- 무인 `/autotdd` 풀사이클을 발동하는 must-fix로 승격하기엔 실제 노출
  경로가 없어 오판 비용이 더 크다고 판단, good-to-fix로 강등해 파킹한다.
  (전 스크립트 공통 패턴이므로 고칠 거면 issue-5 하나만이 아니라 전체를
  일괄 정리하는 것이 맞다 — 이 파생 이슈는 그 논의의 트리거로 남겨둔다.)

## 검토 포인트
- `regression-tests/` 내 모든 `verify-issue-*.sh`에 공통되는 패턴인지 재확인
- `cd "$(dirname "$0")/.."` 같은 self-locating 방식으로 일괄 전환할지, 아니면
  "항상 저장소 루트에서 실행" 관행을 문서화(README)하는 것으로 충분한지 결정

## 권장 구현(가이드)
승격 시 스크립트 상단에 아래 패턴 추가 검토:
```bash
cd "$(git rev-parse --show-toplevel)"
```

## 완료 조건(승격 후)
- [ ] 전 회귀 스크립트(1~27)의 동일 패턴 처리 방침 결정 및 반영
- [ ] `bash regression-tests/verify-issue-5.sh`를 `regression-tests/` 내부에서 직접 실행해도 통과
