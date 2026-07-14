# issue-17: issue-1 구현 결과 보고서의 파일 수 불일치 정정 (fixing issue-1)

## 의존성
issue-1 완료 후

## 계보
- **원본 이슈**: issue-1 (리포 뼈대 및 POC 시나리오 명세 파일 생성)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-1__TYPE-code-review__BY-minimax3.md` (Finding 3)
- **인용**: "명세는 정확히 10개 파일만 요구하고 '위 10개 파일'이라 못박았지만, 구현은 11번째 파일 `regression-tests/verify-issue-1.sh`를 추가했고 보고서는 이를 '계획과의 차이 없음'이라 단언함. 두 진술이 모순."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 다만 `regression-tests/verify-issue-1.sh`는 `tdd2` 스킬의 표준 절차(모든 이슈에 회귀 스크립트 작성 의무)에 따라 추가된 것으로, 스펙 위반이 아니라 스펙에 명시가 누락된 것으로 판단됨.

## 목표
issue-1의 아카이브된 `구현 결과` 섹션(및 필요 시 원본 spec의 완료 조건)이 실제 산출물 개수·목록과 정확히 일치하도록 정정한다.

## 배경
- `issues/archive/2026/07/12/issue-1.md`의 `구현 결과` 섹션은 "계획과의 차이: 없음 — 명세된 10개 파일을 정확한 경로·내용으로 생성"이라 기술했으나, 실제 변경 파일 목록에는 spec에 없던 `regression-tests/verify-issue-1.sh`가 11번째로 포함되어 있다.
- 이는 `tdd2` 스킬의 표준 절차(모든 이슈는 회귀 스크립트를 작성해야 함)에 따른 정당한 추가이지만, 보고서 문구가 이를 반영하지 않아 "계획과의 차이 없음"이라는 진술과 모순된다.

## 구현 상세
`issues/archive/2026/07/12/issue-1.md`의 `## 구현 결과` 섹션 중 "계획과의 차이" 항목을 다음과 같이 정정한다:
```
명세된 10개 파일 전부 정확한 경로·내용으로 생성. 추가로 tdd2 표준 절차에 따라
regression-tests/verify-issue-1.sh(회귀 스크립트, spec에 명시되지 않았으나 모든
이슈 공통 절차)를 작성함 — spec 위반이 아닌 절차상 필수 산출물.
```

## 완료 조건
- [ ] 아카이브된 issue-1.md의 "계획과의 차이" 문구가 11번째 파일(회귀 스크립트)의 존재를 명시적으로 인정하도록 수정됨
- 검증 명령: `grep -q 'regression-tests/verify-issue-1.sh' issues/archive/2026/07/12/issue-1.md && grep -q '계획과의 차이' issues/archive/2026/07/12/issue-1.md`

## 구현 결과
- **구현 완료 일시**: 2026-07-13T22:22:04Z
- **변경 파일**:
  - `issues/archive/2026/07/12/issue-1.md` — 100행 "계획과의 차이" 문구에 회귀 스크립트(11번째 파일)의 존재를 명시 인정
  - `regression-tests/verify-issue-17.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-17.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 없음 — 이슈가 제시한 새 문구를 한 줄로 압축해 적용 (3줄 박스 → 1행으로 가독성 우선)
- **검증 결과**:
  - `bash regression-tests/verify-issue-17.sh` → **OK**
    - `regression-tests/verify-issue-1.sh` 변경 파일 목록 포함 ✓
    - `**계획과의 차이**: ` 라인 보존 ✓
    - 새 문구 "절차상 필수 산출물" 등장 ✓
    - 그 문구가 회귀 스크립트 파일명을 인접 문맥으로 참조 ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 13개) → **모두 통과** (17 새로 포함)
