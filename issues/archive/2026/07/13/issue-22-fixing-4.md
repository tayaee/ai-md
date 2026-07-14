# issue-22: extract_code — 펜스 마커(```)와 언어 식별자 사이 공백 허용 정규식 보강

## 의존성
issue-4 완료 후

## 배경
`engine/aimd/validators.py:8` 의 `_FENCE_RE` 정규식이 ```` ``` ```` 직후에 공백이 오는
경우(예: ```` ``` python ````, ```` ``` py ````)를 매칭하지 못한다. 일부 마크다운 도구/
LLM 변형이 ```` ``` python ```` 형태(언어 식별자 직전에 공백 한 칸)를 출력하는 경우가
있는데, 현재 구현은 이를 인식하지 못해 raw 텍스트가 그대로 반환된다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-gemini.md` (Finding 2, must-fix).
재검증: ```` ``` python\nprint(1)\n``` ```` 입력에서 `[a-zA-Z0-9]*` 매칭 후 `\n`이
와야 하는데 다음 문자가 공백이라 매칭 실패 — findall=[] 확인.

## 목표
- ```` ``` ```` 와 언어 식별자 사이의 단일 공백(`\s?`) 허용
- 기존 ```` ```python ```` (공백 없음) 입력 회귀 없음
- `_FENCE_RE` 공개 시그니처 무변경

## 구현 상세

파일: `engine/aimd/validators.py`

```python
# 변경 전
_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)

# 변경 후 (예시) — 언어 식별자 앞 공백 허용
_FENCE_RE = re.compile(r"```[a-zA-Z0-9 \t]*\n(.*?)```", re.DOTALL)
```

또는 ```` ``` ```` 직후 `\s?` 로 단일 공백 허용:
```python
_FENCE_RE = re.compile(r"```\s?[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)
```

두 방식 모두 동작하지만 후자가 의도를 더 명확히 표현. 구현자는 둘 중 선택.

테스트 파일: `engine/tests/test_validators.py` 에 케이스 추가:
- `test_extract_code_handles_space_after_fence`: ```` ``` python\nprint(1)\n``` ```` → `"print(1)"`
- `test_extract_code_handles_space_after_fence_py`: ```` ``` py\nx=1\n``` ```` → `"x=1"`

## 완료 조건
- [ ] `_FENCE_RE`가 ```` ``` python ```` / ```` ``` py ```` 매칭
- [ ] 기존 LF 케이스 + issue-21의 CRLF 케이스 모두 통과
- [ ] `cd engine && uv run pytest tests/test_validators.py -q` 통과
- [ ] `regression-tests/verify-issue-4.sh` 통과

## 하지 말 것
- ```` ```\n ```` (언어 식별자 없이 공백만) 허용은 불필요 — LLM이 그런 출력은 생성하지 않음
- `extract_code` 시그니처 변경 금지

## 구현 결과

- **구현 완료 일시**: 2026-07-13T05:57:00Z
- **변경 파일**: `engine/aimd/validators.py`, `engine/tests/test_validators.py`, `regression-tests/verify-issue-22.sh`
- **계획과의 차이**: 없음 — `_FENCE_RE`를 `` ```\s? `` 대신 `` ``` ? `` (단일 공백 허용)로 적용, 언어 식별자 앞 공백 한 칸을 허용하면서 기존 LF·issue-21의 CRLF 케이스 회귀 없음. 회귀 스크립트에 더블쿼트 안 백틱 3개가 커맨드 치환으로 잘못 파싱되던 버그가 있어 이스케이프 처리로 별도 수정.
- **검증 결과**:
  - 단위 테스트: `cd engine && uv run pytest tests/test_validators.py -q` → 18 passed
  - 전체 테스트: `cd engine && uv run pytest -q` → 26 passed
  - 회귀 스크립트: `regression-tests/verify-issue-22.sh` OK, `regression-tests/verify-issue-4.sh` 등 기존 스크립트도 모두 통과