Gemini 3.5 Flash

# 코드 리뷰 결과: issue-6

## 1. 개요
- **대상 커밋**: `10efb0040f16845a62ed215a7f96ea74943a3ff8..a09d8a1833204d33d0827a58251c9b0e27a011a3`
- **리뷰 범위**:
  - [engine/aimd/llm.py](file:///home/user1/git/ai-md/engine/aimd/llm.py)
  - [engine/tests/test_llm.py](file:///home/user1/git/ai-md/engine/tests/test_llm.py)
  - [issues/archive/2026/07/13/issue-6.md](file:///home/user1/git/ai-md/issues/archive/2026/07/13/issue-6.md)
  - [regression-tests/verify-issue-6.sh](file:///home/user1/git/ai-md/regression-tests/verify-issue-6.sh)

---

## 2. 코드 리뷰 Findings

### Finding 1: max_tokens 재시도 횟수 초과 시 OpenAI BadRequestError 예외가 RuntimeError로 왜곡되어 전파되는 현상
- **파일:라인**: [engine/aimd/llm.py:37-58](file:///home/user1/git/ai-md/engine/aimd/llm.py#L37-L58)
- **코드 인용**:
  ```python
  for _ in range(_MAX_CLAMP_RETRIES + 1):
      try:
          response = client.chat.completions.create(
              model=settings.model,
              messages=messages,
              temperature=0.0,
              max_tokens=tokens,
          )
      except openai.BadRequestError as e:
          message = str(e)
          if ("max_tokens" not in message and "token" not in message) or tokens <= _MIN_TOKENS:
              raise
          tokens = max(tokens // 2, _MIN_TOKENS)
          log.warning("max_tokens rejected, retrying with %d", tokens)
          continue

      content = response.choices[0].message.content
      if content is None:
          raise RuntimeError("empty LLM response")
      return content

  raise RuntimeError("empty LLM response")
  ```
- **실패 시나리오**:
  1. `settings.max_tokens` 값이 매우 높은 값(예: `524288`)으로 입력됩니다.
  2. OpenAI API를 호출할 때마다 계속해서 `openai.BadRequestError("max_tokens too large")` 예외가 발생한다고 가정합니다.
  3. 루프가 반복되면서 `tokens` 값은 `524288` -> `262144` -> `131072` -> `65536` -> `32768` -> `16384` -> `8192` -> `4096` 순서로 매 반복마다 절반으로 줄어듭니다.
  4. 마지막 7번째 루프 반복(`tokens` = 8192)에서 또 다시 `BadRequestError`가 발생했을 때, `tokens <= _MIN_TOKENS` (8192 <= 4096) 조건은 거짓(`False`)입니다.
  5. 따라서 예외가 즉시 전파(`raise`)되지 않고, `tokens` 값은 `max(4096, 4096)` = 4096으로 업데이트되며 `continue`로 인해 루프가 계속되려 합니다.
  6. 하지만 루프 횟수 제한(`_MAX_CLAMP_RETRIES + 1` = 7회)이 모두 소진되었으므로 루프를 이탈하고, 함수 맨 밑줄에 있는 `raise RuntimeError("empty LLM response")`가 실행됩니다.
  7. 결과적으로 실제 API 오류인 `openai.BadRequestError`가 아니라 엉뚱한 `RuntimeError`로 예외 타입이 왜곡되어 상위 호출부로 전달됩니다.
- **확인 방법**:
  1. [engine/tests/test_llm.py](file:///home/user1/git/ai-md/engine/tests/test_llm.py) 파일 끝에 아래 테스트 케이스를 임시 추가합니다.
     ```python
     def test_chat_raises_bad_request_when_retries_exhausted_before_floor(monkeypatch):
         settings = make_settings(max_tokens=524288)
         fake = _install_fake_client(
             monkeypatch,
             [bad_request("max_tokens too large")] * 7,
         )
         with pytest.raises(openai.BadRequestError):
             llm.chat("sys", "user", settings)
     ```
  2. `cd engine && uv run pytest tests/test_llm.py` 명령어를 통해 테스트를 실행합니다.
  3. 결과가 `RuntimeError: empty LLM response` 실패로 종료되는 것을 확인합니다.
- **심각도 제안**: must-fix

### Finding 2: BadRequestError 발생 시 에러 메시지 대소문자 미구분으로 인한 재시도 조기 전파 오류
- **파일:라인**: [engine/aimd/llm.py:46-47](file:///home/user1/git/ai-md/engine/aimd/llm.py#L46-L47)
- **코드 인용**:
  ```python
  message = str(e)
  if ("max_tokens" not in message and "token" not in message) or tokens <= _MIN_TOKENS:
      raise
  ```
- **실패 시나리오**:
  1. `settings.max_tokens` 값이 `8192`인 상태에서 API가 `openai.BadRequestError("Error: Max_Tokens exceeded")` 혹은 `openai.BadRequestError("Invalid value in Token limit")` 와 같이 대소문자가 혼용된 예외를 반환합니다.
  2. 예외 메시지 `message` 변수에 담긴 텍스트 `"Error: Max_Tokens exceeded"` 혹은 `"Invalid value in Token limit"`는 소문자인 `"max_tokens"` 나 `"token"` 과 일치하지 않습니다.
  3. 이로 인해 `("max_tokens" not in message and "token" not in message)`가 참(`True`)이 되어 조건문 안에서 `raise`가 바로 수행됩니다.
  4. 원래는 토큰 한도 초과 에러이므로 토큰 수를 `4096`으로 낮춰 재시도해야 함에도 불구하고, 대소문자 차이로 인해 재시도 없이 예외가 즉시 밖으로 전파되는 오류가 발생합니다.
- **확인 방법**:
  1. [engine/tests/test_llm.py](file:///home/user1/git/ai-md/engine/tests/test_llm.py) 파일 끝에 아래 테스트 케이스를 임시 추가합니다.
     ```python
     def test_chat_ignores_case_on_token_error(monkeypatch):
         settings = make_settings(max_tokens=8192)
         fake = _install_fake_client(
             monkeypatch,
             [bad_request("Max_Tokens too large"), "ok after retry"],
         )
         result = llm.chat("sys", "user", settings)
         assert result == "ok after retry"
     ```
  2. `cd engine && uv run pytest tests/test_llm.py` 명령어를 실행합니다.
  3. 테스트가 `openai.BadRequestError: Max_Tokens too large` 를 그대로 발생시키며 통과하지 못하는 것을 확인합니다.
- **심각도 제안**: good-to-fix

### Finding 3: response.choices 리스트가 비어 있는 경우 IndexError 발생 취약점
- **파일:라인**: [engine/aimd/llm.py:53](file:///home/user1/git/ai-md/engine/aimd/llm.py#L53)
- **코드 인용**:
  ```python
  content = response.choices[0].message.content
  ```
- **실패 시나리오**:
  1. API 호출은 성공하여 정상적인 HTTP 200 응답이 오지만, API 측 콘텐츠 필터링이나 내부 상황에 의해 생성 결과가 누락되어 `response.choices` 리스트가 빈 배열(`[]`)로 반환됩니다.
  2. `response.choices[0]` 인덱스 접근 시 `IndexError: list index out of range` 예외가 발생하여, 애플리케이션 전체가 제어되지 않은 오류로 중단됩니다.
- **확인 방법**:
  1. [engine/tests/test_llm.py](file:///home/user1/git/ai-md/engine/tests/test_llm.py) 파일에서 mock API 응답의 `choices` 리스트를 강제로 비워둔 상태로 `llm.chat`을 호출해 봅니다.
  2. `IndexError` 예외가 발생하는 것을 확인합니다. (방어 코드 `if not response.choices` 등을 통한 `RuntimeError` 처리 권장)
- **심각도 제안**: good-to-fix

### Finding 4: OpenAI 클라이언트 객체 매 생성으로 인한 네트워크 리소스 비효율 및 커넥션 풀링 불가
- **파일:라인**: [engine/aimd/llm.py:30](file:///home/user1/git/ai-md/engine/aimd/llm.py#L30)
- **코드 인용**:
  ```python
  client = _make_client(settings)
  ```
- **실패 시나리오**:
  1. `llm.chat`이 고부하, 다중 사용자 스레드, 혹은 반복되는 에이전트 루프 상에서 매우 빈번하게 호출되는 상황이 생깁니다.
  2. 매 `chat` 호출 시마다 새로운 `openai.OpenAI` 객체와 하위의 `httpx.Client`가 새로 생성되고 소멸합니다.
  3. 이로 인해 HTTP 커넥션 풀링(Connection Pooling)이 전혀 활용되지 못하고 매번 TCP 3-way handshake 및 TLS handshake가 일어나 응답 대기 시간이 증가(Latency 손실)하고 시스템 리소스(로컬 포트, 소켓 등) 부족 또는 소켓 고갈(socket exhaustion)을 겪게 됩니다.
- **확인 방법**:
  1. 잦은 주기로 `llm.chat`을 루프로 연속 호출하면서 서버의 활성 TCP 커넥션(ESTABLISHED, TIME_WAIT 등) 개수가 호출할 때마다 비례하여 증가하고 소멸하는지 확인합니다.
- **심각도 제안**: good-to-fix

### Finding 5: OpenAI 클라이언트 및 API 호출 시 타임아웃 미지정으로 인한 무한 대기 가능성
- **파일:라인**: [engine/aimd/llm.py:39-44](file:///home/user1/git/ai-md/engine/aimd/llm.py#L39-L44)
- **코드 인용**:
  ```python
  response = client.chat.completions.create(
      model=settings.model,
      messages=messages,
      temperature=0.0,
      max_tokens=tokens,
  )
  ```
- **실패 시나리오**:
  1. 네트워크 연결 상태가 불안정하거나 MiniMax API 서버 장애 등으로 인해, 요청 수신 이후 응답이 영구적으로 반환되지 않고 커넥션이 무한히 멈추는(hanging) 상황이 발생합니다.
  2. `create` 호출이나 클라이언트 생성 시 명시적인 `timeout` 값이 설정되어 있지 않아서, 호출 스레드나 프로세스가 기본 타임아웃 만료 시까지 대기하게 되어 가용성(Availability)이 급격히 저하됩니다.
- **확인 방법**:
  1. Mock 서버를 생성하여 클라이언트 요청을 수신한 후 아무런 응답을 주지 않고 커넥션을 유지하게 합니다.
  2. `llm.chat`을 호출하여 매우 긴 시간(예: 수십 분) 동안 대기 상태에 빠지는 것을 확인합니다.
- **심각도 제안**: good-to-fix
