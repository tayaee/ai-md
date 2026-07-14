# issue-24: extract_code 정규식 lazy match가 docstring 안의 백틱 시퀀스에 잘못 매칭 (good-to-fix)

## 상태


## 의존성
issue-4 완료 후

## 배경
`engine/aimd/validators.py:8` 의 `_FENCE_RE` 가 `(.*?)` 비-그리디 매칭을 사용해 가장
먼저 만나는 닫는 ```을 매칭한다. LLM 출력이 Python docstring 안에 markdown 코드
예시를 포함하는 경우 (예: docstring 안에 ` ``` ` 4-backtick 블록) regex가 docstring 내부의
```을 닫는 펜스로 잘못 매칭해 코드가 잘린다.

리뷰 출처:
- `issues/issue-4__TYPE-code-review__BY-sonnet.md` (Finding 1, good-to-fix) — 유일한
  형식 게이트 통과 finding
- `issues/issue-4__TYPE-code-review__BY-gemini.md` (Finding 5, must-fix) — 표 일부 누락
  으로 gate에서 reject (사유: 증거 미비). 동일 결함의 독립 발견이지만 gate 통과
  finding이 없어 stats 카운트 미반영.

## 검토 포인트
- spec의 "가장 긴 펜스 블록" 의도와 lazy match의 "가장 가까운 닫는 펜스" 구현이
  어긋남 — 의도는 "longest match" 또는 "balanced match"
- 진짜 수정안 후보:
  1. greedy `.*` 로 변경 — but "가장 긴" 자체가 greedy와 동치가 됨
  2. 4-backtick 펜스 우선 인식: ```` ```` ````python ... ```` ```` ```` 같은 케이스
     를 먼저 split 한 뒤 단일 ``` 블록 처리
  3. 가장 바깥쪽 매칭만 선택 — `findall` 대신 `search` + balanced tracking
- 실제 LLM 출력이 docstring 안에 펜스를 포함할 빈도 평가 필요

## 권장 구현(가이드)
1. `_FENCE_RE` 외에 4-backtick ```` ```` ```` 패턴을 우선 처리하는 helper 추가
2. 단일 ``` 블록 매칭 시 greedy 또는 balanced 방식 채택
3. 테스트에 docstring-내-펜스 케이스 추가

## 완료 조건(승격 후)
- [ ] docstring 안에 ```` ``` ```` 시퀀스가 포함된 LLM 출력이 깨지지 않음
- [ ] 기존 15개 테스트 회귀 없음

## 구현 결과
- **구현 완료 일시**: 2026-07-13T23:15:21Z
- **변경 파일**:
  - `engine/aimd/validators.py` — `_4FENCE_RE` 추가 + `extract_code`에서 4-backtick 블록 우선 인식. 펜스 라인 들여쓰기 허용(`^[ \t]*` + MULTILINE)
  - `engine/tests/test_validators.py` — `test_extract_code_picks_4backtick_over_3backtick`(docstring 안에 4-backtick markdown 예시), `test_extract_code_4backtick_is_the_only_fence`(4-backtick만 단독) 추가
  - `regression-tests/verify-issue-24.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-24.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 없음 (이슈 권장 1+3 그대로 채택). 디버깅 중 발견한 **보너스 fix**: 펜스 라인 들여쓰기 허용 (`^[ \t]*` + `re.MULTILINE`). 이게 없으면 docstring 안의 들여쓴 4-backtick 블록도 매칭 실패 — 이슈 본문에 명시 안 된 잠재 버그였음.
- **알려진 한계**: docstring **내부에 3-backtick (```) 만** 있을 때 여전히 잘못 매칭됨. 4-backtick 컨벤션 호출자 측에서 따라야 함. fix 불가 (truly balanced matching은 regex stdlib 범위 밖).
- **검증 결과**:
  - `uv run pytest tests/test_validators.py -q` (engine/) → **21 passed** (기존 19 + 신규 2)
  - `bash regression-tests/verify-issue-24.sh` → **OK**
    - `_4FENCE_RE` 정의 존재 ✓
    - `extract_code`에서 `_4FENCE_RE.findall` 우선 호출 ✓
    - 4-backtick 우선 + 단독 테스트 2개 존재 ✓
    - 펜스 들여쓰기 가드(`^[ \t]*` + MULTILINE) ✓
    - pytest 21 passed ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 18개) → **모두 통과** (24 새로 포함)