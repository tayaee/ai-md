# issue-38: llm.chat — max_tokens 클램프 재시도 소진 시 실제 BadRequestError가 RuntimeError로 둔갑하는 버그 수정

## 의존성
issue-6 완료 후

## 배경
`engine/aimd/llm.py:37-58`의 재시도 루프는 `range(_MAX_CLAMP_RETRIES + 1)`로
시도 횟수를 제한한다. `settings.max_tokens`가 충분히 커서 `_MIN_TOKENS`에
도달하기까지 필요한 절반화 횟수가 `_MAX_CLAMP_RETRIES`를 초과하면, 루프가
`_MIN_TOKENS` 도달 전에(즉 `tokens <= _MIN_TOKENS` 조건이 한 번도 참이
되지 못한 채) 시도 횟수를 소진하고 루프를 빠져나온다. 이 경우 마지막
`raise RuntimeError("empty LLM response")`가 실행되어, 실제로는 지속된
`openai.BadRequestError`(토큰 한도 문제)인데 완전히 다른 의미인
"응답이 비어있다"는 `RuntimeError`로 예외 타입이 둔갑해 호출부에 잘못된
신호를 전달한다.

리뷰 출처:
- `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-gemini.md` (Finding 1, must-fix)
- `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-minimax.md` (Finding 1, must-fix — 동일 결함 독립 발견)

두 리뷰어 모두 같은 결함을 독립적으로 발견했다 (중복 finding 규칙 적용,
파생 이슈는 1개만 생성).

## 재검증 결과 (실행 확인)
`engine` 디렉터리에서 `settings.max_tokens=524288`(gemini 예시)로
`_make_client`를 모두 `BadRequestError("max_tokens too large")`를 던지는
가짜 클라이언트로 monkeypatch한 뒤 `llm.chat(...)`을 호출해 직접 재현함:
- 결과: `RuntimeError: empty LLM response` — 실제 발생했어야 할
  `openai.BadRequestError`가 아님. 인용·주장 모두 성립 확인.
- minimax 리뷰가 정확한 임계값을 직접 실행으로 측정: `_MAX_CLAMP_RETRIES=6`,
  `_MIN_TOKENS=4096` 기준 `M >= 262208`부터 발현 (`M=262207`까지는 정상
  전파, `M=262208`부터 마스킹). 기본값 `AIMD_MAX_TOKENS=200000`은 임계값
  미만이라 현재 기본 설정에서는 재현되지 않지만, 환경 변수만 올리면 즉시
  발현하는 잠재적 결함.

## 목표
- 재시도 예산이 소진되더라도, 마지막으로 발생한 실제 `BadRequestError`가
  (또는 그에 준하는 명확한 컨텍스트를 포함한 예외가) 호출부로 전파되어야
  한다.
- `RuntimeError("empty LLM response")`는 스펙이 정의한 대로 "content가
  None인 경우"에만 발생해야 한다 — 재시도 소진과 혼동되지 않아야 한다.
- 기존 5개 테스트(정상 응답, 재시도 성공, 비토큰 에러 즉시 전파, None
  content, `_MIN_TOKENS` 도달 후 전파) 회귀 없음.

## 구현 상세

파일: `engine/aimd/llm.py`

미니맥스 리뷰가 제안한 방식 (a)를 권장: trailing raise를 제거하고, 루프의
`continue` 분기 끝에서 무조건적인 `raise`를 제거해 마지막 예외가 자연스럽게
전파되도록 한다. 즉 다음 두 갈래를 구조적으로 합친다 — "메시지에 토큰
관련 문구가 없으면 즉시 전파" 갈래와 "재시도 예산이 소진됐으면 전파" 갈래를
하나의 조건으로 정리하거나, 마지막 반복임을 감지해 명시적으로 `raise`하도록
루프 구조를 바꾼다.

```python
# 방향 예시 — range 대신 명시적 카운터로 "마지막 시도인가"를 판별
last_error: openai.BadRequestError | None = None
for attempt in range(_MAX_CLAMP_RETRIES + 1):
    try:
        response = client.chat.completions.create(
            model=settings.model,
            messages=messages,
            temperature=0.0,
            max_tokens=tokens,
        )
    except openai.BadRequestError as e:
        message = str(e)
        if "max_tokens" not in message and "token" not in message:
            raise
        last_error = e
        if tokens <= _MIN_TOKENS:
            raise
        tokens = max(tokens // 2, _MIN_TOKENS)
        log.warning("max_tokens rejected, retrying with %d", tokens)
        continue

    content = response.choices[0].message.content
    if content is None:
        raise RuntimeError("empty LLM response")
    return content

# 정상적으로는 위 루프 안에서 return 또는 raise로 항상 빠져나가야 한다.
# 방어적으로만 남겨두되, RuntimeError("empty LLM response")로 오인되지 않게
# 마지막 BadRequestError를 재전파한다.
if last_error is not None:
    raise last_error
raise RuntimeError("empty LLM response")
```

구현자는 위 구조를 그대로 따르거나, 동등한 결과(재시도 예산 소진 시
마지막 `BadRequestError`가 전파됨)를 내는 다른 구조를 선택해도 된다.

테스트 파일: `engine/tests/test_llm.py`에 케이스 추가:
- `test_chat_raises_bad_request_when_retries_exhausted_before_floor`:
  `max_tokens=524288`(또는 minimax가 측정한 임계값 `262208`)로 설정하고
  매 호출이 전부 `BadRequestError("max_tokens too large")`를 던지도록
  구성 → `llm.chat(...)` 호출 시 `RuntimeError`가 아니라
  `openai.BadRequestError`가 전파되는지 확인.

## 완료 조건
- [ ] 재시도 예산 소진 시 `openai.BadRequestError`가 전파됨 (위 테스트로 확인)
- [ ] 기존 5개 테스트 회귀 없음
- [ ] `cd engine && uv run pytest tests/test_llm.py -q` 통과
- [ ] `regression-tests/verify-issue-6.sh` 통과

## 하지 말 것
- `chat` 함수 시그니처 변경 금지
- `_MIN_TOKENS`/`_MAX_CLAMP_RETRIES` 값 자체는 변경하지 않는다 (루프 종료
  시점의 예외 처리만 고친다)

## 구현 결과

- **구현 완료 일시**: 2026-07-13T07:47:51Z
- **변경 파일**: `engine/aimd/llm.py`, `engine/tests/test_llm.py`
- **계획과의 차이**: 없음 — 제안된 방향 예시(`last_error` 추적 후 루프 종료 시 재전파)를 그대로 채택. trailing `raise RuntimeError("empty LLM response")`는 "도달 불가능" 상태가 되어 `assert last_error is not None; raise last_error`로 교체.
- **검증 결과**:
  - pyright: 0 errors, 0 warnings
  - ruff: 이 세션 환경 문제로 미실행 (issue-5/6과 동일한 pre-existing 이슈)
  - 단위 테스트: `cd engine && uv run pytest tests/test_llm.py -q` → 6 passed (기존 5개 + `test_chat_raises_bad_request_when_retries_exhausted_before_floor` 신규)
  - 전체 테스트: `cd engine && uv run pytest -q` → 36 passed
  - 회귀 스크립트: `regression-tests/verify-issue-6.sh` OK
  - 재현 확인: `max_tokens=524288`로 모든 호출이 실패하도록 구성한 시나리오에서 이제 `openai.BadRequestError`가 정상 전파됨 (수정 전에는 `RuntimeError: empty LLM response`로 둔갑했었음)
