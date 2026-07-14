MiniMax-M3 (claude-opus-4-8, 2025-Q4)

# 코드 리뷰 결과: issue-6

## 1. 개요
- **대상 커밋**: `10efb0040f16845a62ed215a7f96ea74943a3ff8..a09d8a1833204d33d0827a58251c9b0e27a011a3`
- **리뷰 범위**:
  - `engine/aimd/llm.py`
  - `engine/tests/test_llm.py`
  - `issues/archive/2026/07/13/issue-6.md` (스펙)
  - `regression-tests/verify-issue-6.sh`
- **기존 리뷰 참고**: `issue-6__TYPE-code-review__BY-gemini.md` 와 중복되는 F1은 임계값을 직접 재현해 보정함

---

## 2. Findings

### Finding 1: max_tokens 클램프 재시도 한도 소진 시 실제 `BadRequestError` 가 `RuntimeError("empty LLM response")` 로 마스킹됨

- **파일:라인**: `engine/aimd/llm.py:37-58`
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
  1. `AIMD_MAX_TOKENS=300000` 처럼 충분히 큰 값으로 설정한다.
  2. MiniMax API가 모든 호출에서 `openai.BadRequestError("max_tokens too large")` 를 반환한다고 가정한다.
  3. 루프 추적(검증됨):
     - iter 0: tokens=300000 → fail → `300000//2=150000`, continue
     - iter 1: 150000 → 75000, continue
     - iter 2: 75000 → 37500, continue
     - iter 3: 37500 → 18750, continue
     - iter 4: 18750 → 9375, continue
     - iter 5: 9375 → `max(4687, 4096)=4687`, continue
     - iter 6: 4686 로 호출 → fail → check `4687 <= 4096`? False → `max(2343, 4096)=4096`, continue
     - 루프 종료 (`range(7)` 모두 소진)
     - **trailing `raise RuntimeError("empty LLM response")` 실행**
  4. 호출부는 토큰 한도 문제(=`BadRequestError`)인데 "empty LLM response" 라는 완전히 다른 의미의 `RuntimeError` 를 받는다. 컨텍스트가 손실되어 상위 로깅/모니터링/리트라이 전략이 모두 잘못된 신호로 동작한다.
- **임계값(직접 측정)**: `_MAX_CLAMP_RETRIES=6`, `_MIN_TOKENS=4096` 일 때 **M ≥ 262208 (정확히는 `M > 64 * _MIN_TOKENS + r` , 여기서 r은 정수 나눗셈 floor 잔여)** 일 때 도달.
  - M = 262207 → `BadRequestError` (정상 전파, 7회 시도)
  - M = 262208 → `RuntimeError("empty LLM response")` (마스킹)
  - M = 524288 → 동일하게 `RuntimeError` (기존 gemini 리뷰의 임계값 524288은 너무 큼 — 실제로는 그 절반 지점부터 발생)
  - 기본 `AIMD_MAX_TOKENS=200000` 은 262144 미만이라 `BadRequestError` 로 정상 전파됨. 즉 **현장 기본 설정에서는 재현되지 않지만, 환경 변수만 바꾸면 즉시 발현**.
- **확인 방법** (직접 재현함):
  ```python
  # engine 디렉터리에서 실행
  import sys; sys.path.insert(0, ".")
  import httpx, openai
  from pathlib import Path
  from unittest.mock import patch
  from aimd import llm
  from aimd.config import Settings

  def bad_request(m):
      return openai.BadRequestError(m, response=httpx.Response(400, request=httpx.Request("POST","http://t")), body=None)

  class FC:
      def __init__(self): self.calls=[]
      def create(self, **kw):
          self.calls.append(kw["max_tokens"])
          raise bad_request("max_tokens too large")
  class FH: completions = FC()
  class FCli: chat = FH()

  def s(M): return Settings(api_key="k", base_url="http://t", model="m", max_tokens=M, src_dir=Path("./src"), dist_dir=Path("./dist"))

  for M in [200000, 262207, 262208, 300000]:
      f = FCli()
      with patch.object(llm, "_make_client", lambda x: f):
          try: llm.chat("s","u", s(M))
          except Exception as e: print(M, type(e).__name__, e)
  # → 200000 BadRequestError / 262207 BadRequestError / 262208 RuntimeError / 300000 RuntimeError
  ```
  이 스크립트는 실제로 위 출력을 생성했음을 확인했다 (`max_tokens rejected, retrying with ...` 로그도 7회 미만으로 끝남).
- **심각도 제안**: must-fix
  - 권장 수정안:
    - (a) trailing raise를 제거하고 마지막 `BadRequestError` 를 그대로 두기 — `for` 루프 안의 `continue` 분기 끝에서 `raise` 만 제거하면 자연스럽게 마지막 예외가 호출부로 전파됨
    - (b) 마지막 예외를 잡아 더 명확한 메시지로 감싸기: `raise RuntimeError(f"max_tokens clamp exhausted after {_MAX_CLAMP_RETRIES + 1} attempts: {last_message}")`
    - (c) 또는 `_MAX_CLAMP_RETRIES` 의 의미를 명세(스펙)와 코드 양쪽에서 "총 시도 횟수" 로 통일하고 의도된 fallback 임을 코멘트로 명시

---

### Finding 2: `response.choices` 가 빈 리스트일 때 `IndexError` 가 무방비로 노출됨

- **파일:라인**: `engine/aimd/llm.py:53`
- **코드 인용**:
  ```python
  content = response.choices[0].message.content
  ```
- **실패 시나리오**:
  1. API 가 HTTP 200 을 반환했지만, 내부 정책/필터링/극단적 race condition 으로 `choices=[]` 인 응답이 떨어진다 (예: 모델이 도구 호출을 위해 empty finish 를 반환하는 비정상 경로, 프록시/미들웨어가 choices 를 잘라낸 경우 등).
  2. `response.choices[0]` 에서 `IndexError: list index out of range` 가 발생.
  3. 이 예외는 스펙이 정의한 `BadRequestError` / `RuntimeError("empty LLM response")` 어느 쪽에도 해당하지 않아, 호출부는 의도하지 않은 예외 타입을 받아 모니터링 알람/리트라이/사용자 메시지 정책이 모두 깨진다.
- **확인 방법** (현재 테스트로 재현 불가 — `test_chat_raises_on_empty_content` 는 `choices[0].message.content=None` 만 다루고 빈 `choices` 는 다루지 않음):
  ```python
  # test_llm.py 끝에 임시 추가
  def test_chat_raises_runtime_error_on_empty_choices(monkeypatch):
      settings = make_settings(max_tokens=8192)

      class EmptyResp:
          choices = []  # ← 방어 코드 부재

      class EmptyCompletions:
          def create(self, **kw): return EmptyResp()
      class EmptyChat:
          completions = EmptyCompletions()
      class EmptyClient:
          chat = EmptyChat()

      monkeypatch.setattr(llm, "_make_client", lambda s: EmptyClient())
      with pytest.raises(RuntimeError, match="empty LLM response"):
          llm.chat("sys", "user", settings)
  ```
  위 테스트를 추가하면 현재 구현에서는 `pytest.fail` 로 `IndexError` 가 그대로 노출됨. `if not response.choices: raise RuntimeError("empty LLM response")` 같은 가드를 llm.py 에 추가하면 통과.
- **참고**: 같은 코드가 `content is None` 케이스(`llm.py:54-55`)는 정상적으로 `RuntimeError` 로 변환한다. `choices=[]` 만 방어되지 않는 비대칭.
- **심각도 제안**: good-to-fix
  - 실제 MiniMax 응답에서 빈 choices 가 발생할 빈도는 매우 낮지만, 스펙이 "성공 시 `response.choices[0].message.content`" 라고 가정하면서 그 가정의 실패 경로는 명시하지 않은 빈틈.

---

## 3. 명시적으로 검토했으나 문제 없음 (보고하지 않은 후보)

- **`_make_client` 의 매 호출 재생성**: 스펙이 client 재사용/풀링을 요구하지 않음. 매 호출 생성은 connection pooling 손해가 있지만 스펙 외 이슈.
- **openai SDK 기본 타임아웃**: `OpenAI()` 기본 생성 시 `httpx.Timeout(connect=5.0, read=600, write=600, pool=600)` 이 자동 적용됨 (`httpx wrapper` 확인). 무한 대기는 아님.
- **`tokens <= _MIN_TOKENS` 의 `<=` 사용**: 스펙은 "이미 `_MIN_TOKENS`인데" 라고 적었지만 `<=` 가 더 방어적(`tokens < _MIN_TOKENS` 인 비정상 입력에서도 즉시 전파). 문제 없음.
- **에러 메시지 대소문자 구분**: 스펙이 명시적으로 `"max_tokens"` / `"token"` 소문자 부분일치를 요구하므로 구현이 그대로 따르는 것은 스펙 준수. (기존 gemini 리뷰의 F2 는 본 리뷰 범위에서는 채택하지 않음 — 스펙 변경 이슈.)
- **동시성**: `chat()` 은 재진입 안전 (`tokens`, `messages`, `client` 모두 로컬). 모듈 전역 mutable 상태 없음.
- **회귀 스크립트 `verify-issue-6.sh`**: `engine/aimd/` 디렉터리의 `openai` import 가 `llm.py` 에만 있는지 확인하는 부분은 정상. 테스트 실행/파일 존재 확인 모두 OK.
