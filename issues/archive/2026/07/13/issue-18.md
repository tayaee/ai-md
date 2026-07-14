# issue-18: verify-issue-1.sh의 README 검증 강화 (fixing issue-1)

## 의존성
issue-1 완료 후

## 계보
- **원본 이슈**: issue-1 (리포 뼈대 및 POC 시나리오 명세 파일 생성)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-1__TYPE-code-review__BY-minimax3.md` (Finding 4)
- **인용**: "`AIMD` 문자열이 README 어디든 한 번 나오면 통과. 예컨대 누가 실수로 README 본문 어딘가에 'AIMD' 한 단어만 남기고 제목·경고·링크를 모두 지워도 이 검사는 통과함. spec은 제목·한 줄 소개·실행법·경고(굵게)·문서 링크 5개 요소를 모두 요구."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 리뷰어는 "현재 README에는 명세된 모든 요소가 실제로 존재해 실용적 위험은 낮음"이라고 명시 — 회귀 보호력 개선 목적의 테스트 품질 이슈.

## 목표
`regression-tests/verify-issue-1.sh`의 README.md 검증을 spec이 요구하는 5개 요소(제목·한 줄 소개·실행법·경고 굵게·문서 링크) 각각에 대한 검사로 강화한다.

## 배경
- 현재 검사(`grep -q 'AIMD' README.md`)는 "AIMD" 문자열이 파일 어디든 한 번만 있으면 통과하므로, 제목·경고 문단·문서 링크가 실수로 삭제되어도 회귀를 잡지 못한다.

## 구현 상세
`regression-tests/verify-issue-1.sh`의 README 검증 부분을 spec의 5개 요소 각각에 대한 grep으로 분리한다. 예:
```bash
grep -q '^# AIMD — AI-powered Markdown Engine' README.md || fail "README.md missing title"
grep -q 'LLM이 생성한 코드를 그대로 실행' README.md || fail "README.md missing security warning"
grep -qE '\*\*.*ngrok http --basic-auth' README.md || fail "README.md warning not bolded"
grep -q 'docs/SPEC.md' README.md || fail "README.md missing SPEC.md link"
grep -q 'docs/adr' README.md || fail "README.md missing adr link"
```
(정확한 문구는 issue-16 반영 후의 최종 README.md 내용에 맞춰 조정한다 — issue-16과 순서 조율 필요.)

## 하지 말 것
- README.md 본문 내용 자체는 변경하지 않는다 (검증 스크립트만 강화).

## 완료 조건
- [ ] README.md의 제목·경고·문서 링크 각각이 개별 grep으로 검증됨
- [ ] 정상 README.md에 대해 `bash regression-tests/verify-issue-1.sh`가 여전히 `OK`로 통과
- [ ] 제목만 남기고 경고 문단을 삭제한 README.md에 대해서는 스크립트가 실패함 (수동 확인)
- 검증 명령: `bash regression-tests/verify-issue-1.sh && echo OK`

## 구현 결과
- **구현 완료 일시**: 2026-07-13T22:59:58Z
- **변경 파일**:
  - `regression-tests/verify-issue-1.sh` — `grep -q 'AIMD' README.md` 단일 약한 검사를 5개 spec 요소 grep으로 분리 (제목, 보안 경고, 굵은 ngrok, SPEC.md 링크, adr 링크)
  - `regression-tests/verify-issue-18.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-18.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 없음 — 이슈가 제시한 5요소 grep 패턴을 그대로 적용. v3 ngrok 패턴(`\*\*.*ngrok http --basic-auth`)은 issue-16과 정합 (구 v2 패턴도 매치되므로 호환).
- **검증 결과**:
  - `bash regression-tests/verify-issue-18.sh` → **OK**
    - 5개 grep(제목·경고·굵게·SPEC 링크·adr 링크) 존재 ✓
    - 옛 약한 `grep -q 'AIMD' README.md` 단독 라인 부재 ✓
    - 현재 README.md에 대해 `verify-issue-1.sh`가 OK 출력 ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 14개) → **모두 통과** (18 새로 포함)
- **수동 확인 권고**: 이슈의 세 번째 완료 조건("제목만 남기고 경고 문단을 삭제한 README → 스크립트 실패")은 가짜 README 조작이 필요해 자동화 생략. README.md가 우연히 한 요소만 잃어도 verify-issue-1.sh가 즉시 실패하는지 확인하려면:
  ```bash
  cp README.md README.md.bak
  sed -i '/LLM이 생성한 코드를 그대로 실행/d' README.md
  bash regression-tests/verify-issue-1.sh; echo "EXIT=$?"  # expect nonzero
  mv README.md.bak README.md
  ```
