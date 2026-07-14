# verify-issue-24.sh × issue-25 충돌 메모

`issue-25` 구현이 `engine/aimd/validators.py`의 `extract_code` docstring에
"미닫힌 펜스 정책" 설명 문단을 추가하면서, `def extract_code` 선언부와 실제
`_4FENCE_RE.findall(...)` 호출부 사이의 줄 수가 늘어났다.

`verify-issue-24.sh`의 2번 체크는 원래
`grep -A20 'def extract_code' "$TARGET" | grep -qE '_4FENCE_RE\.findall'`
처럼 "def 선언 뒤 20줄 이내에 호출이 있는가"라는 고정 윈도우로 판정하고
있었는데, docstring이 길어지며 실제 호출이 그 20줄 창을 벗어나 항상 FAIL이
나는 상태가 됐다 — **회귀가 아니라 스크립트 자체의 가정(고정 줄 수 윈도우)이
낡아진 것**.

## 조치
2번 체크를 "def 선언 후 N줄 이내"가 아니라 "`_4FENCE_RE.findall` 호출이
`_FENCE_RE.findall` 호출보다 파일 내에서 먼저 나타나는가"라는 순서 기반 판정으로
바꿨다. 이는 원래 체크가 검증하려던 실제 의도(4-backtick을 3-backtick보다
먼저 시도한다)를 그대로 지키면서, docstring 길이 변화에 더 이상 취약하지
않다.

## 검토 필요
사람이 이 메모를 확인하고, 순서 기반 판정이 향후 `extract_code`가 더 크게
리팩터링될 때도(예: 두 findall 호출이 헬퍼 함수로 추출되는 경우) 여전히
유효한 방식인지 재확인하는 것을 권장.
