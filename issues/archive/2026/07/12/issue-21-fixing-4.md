# issue-21: extract_code — Windows 스타일 CRLF 개행이 들어온 LLM 출력에서 펜스를 인식하지 못하는 버그 수정

## 의존성
issue-4 완료 후

## 배경
`engine/aimd/validators.py:8` 의 `_FENCE_RE` 정규식이 `\n`(LF)만 매칭하고 `\r\n`(CRLF)을
매칭하지 못한다. LLM 출력이 Windows에서 작성된 파일을 거치거나 LLM 클라이언트가 CRLF로
출력하는 경우 `_FENCE_RE.findall`이 빈 리스트를 반환하고, `extract_code`는 원본 텍스트를
그대로 strip해서 반환한다. 결과적으로 펜스가 벗겨지지 않은 raw 텍스트가 다음 단계
(`validate_python`/`validate_html`)로 흘러들어 잘못된 에러 메시지를 유발한다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-gemini.md` (Finding 1, must-fix).
재검증: `engine/aimd/validators.py:8` 의 정규식 `r"```[a-zA-Z0-9]*\n(.*?)```"`, re.DOTALL
에서 `\n`은 literal LF. 입력 ```` ```python\r\nprint(1)\r\n``` ```` 에서 `[a-zA-Z0-9]*\n`
매칭 시도 시 `\r` 다음의 `\n` 직전 위치가 `\r`이라 매칭 실패 — findall=[] 확인.

## 목표
- 펜스 open/close 모두에서 `\r\n` 또는 `\n` 양쪽을 매칭하는 정규식으로 변경
- 기존 LF-only 입력에 대한 회귀 없음
- `_FENCE_RE` 명세를 issue-4와 동일하게 보존(공개 시그니처 무변경)

## 구현 상세

파일: `engine/aimd/validators.py`

```python
# 변경 전
_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)

# 변경 후 (예시) — \r? 를 \n 앞에 둔다
_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\r?\n(.*?)\r?\n```", re.DOTALL)
```

또는 `re.splitlines` 후 라인 단위로 처리하는 방식도 가능. 단, `(.*?)` 캡처가 라인을
넘어서는 멀티라인을 지원해야 하므로 정규식 유지가 단순.

추가로 `extract_code`의 `rstrip("\n")`은 변경하지 않는다 — issue-4의 기존 동작 보존.

테스트 파일: `engine/tests/test_validators.py` 에 케이스 추가:
- `test_extract_code_handles_crlf_fence`: ```` ```python\r\nprint(1)\r\n``` ```` → `"print(1)"`
- (기존 LF 케이스 회귀 없음 확인)

## 완료 조건
- [ ] `_FENCE_RE`가 CRLF 입력을 매칭
- [ ] 기존 LF 케이스 회귀 없음 (15개 테스트 모두 통과)
- [ ] `cd engine && uv run pytest tests/test_validators.py -q` 통과
- [ ] `regression-tests/verify-issue-4.sh` 통과

## 하지 말 것
- `_FENCE_RE` 공개 동작(가장 긴 매칭 반환)을 변경하지 않는다
- `extract_code` 시그니처 변경 금지

## 구현 결과

- **구현 완료 일시**: 2026-07-12T23:05:00Z
- **변경 파일**: `engine/aimd/validators.py`, `engine/tests/test_validators.py`, `regression-tests/verify-issue-21.sh`
- **계획과의 차이**: 없음 — issue-21 spec에서 제시한 `\r?\n` 예시 그대로 적용. open/close 양쪽 모두 CRLF 허용.
- **검증 결과**:
  - ruff(`engine/aimd/validators.py`, `engine/tests/test_validators.py`): All checks passed
  - pyright(scoped): 0 errors
  - 단위 테스트: `cd engine && uv run pytest -q` → 24 passed (validators 16 + artifacts 4 + config 4)
  - 회귀 스크립트: `regression-tests/verify-issue-21.sh` OK + 기존 1,2,3,4 모두 통과