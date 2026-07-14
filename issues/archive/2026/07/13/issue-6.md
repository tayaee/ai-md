# issue-6: llm.py — MiniMax 클라이언트 (max_tokens 클램프 재시도)

## 의존성
issue-2 완료 후

## 목표
OpenAI SDK로 MiniMax를 호출하는 유일한 창구. 테스트는 전부 mock — 실 API 호출 금지.

## 배경
- docs/adr/0006-minimax-integration.md

## 구현 상세

파일: `engine/aimd/llm.py`

```python
import logging

import openai

from .config import Settings

log = logging.getLogger("aimd.llm")

_MIN_TOKENS = 4096
_MAX_CLAMP_RETRIES = 6


def _make_client(settings: Settings) -> openai.OpenAI:
    """테스트에서 monkeypatch할 수 있도록 분리해 둔다."""
    return openai.OpenAI(api_key=settings.api_key, base_url=settings.base_url)


def chat(system: str, user: str, settings: Settings) -> str:
    """messages=[{system},{user}], temperature=0.0 으로 1회 완성 호출.

    max_tokens 클램프: settings.max_tokens로 시작한다.
    openai.BadRequestError(HTTP 400)가 나고 에러 문자열에 "max_tokens" 또는
    "token"이 포함되면, max_tokens를 절반으로 줄여 재시도한다.
    최대 _MAX_CLAMP_RETRIES회, 하한 _MIN_TOKENS. 그 외 예외는 그대로 전파.

    성공 시 response.choices[0].message.content(str)를 반환.
    content가 None이면 RuntimeError("empty LLM response").
    """
```

구현 지침:
- 루프: `tokens = settings.max_tokens` → 호출 → `BadRequestError`이고 메시지에
  token 관련 문구가 있으면 `tokens = max(tokens // 2, _MIN_TOKENS)` 후 재시도.
  이미 `_MIN_TOKENS`인데 또 실패하면 전파.
- 재시도 시 `log.warning("max_tokens rejected, retrying with %d", tokens)` 영어 로그.

테스트 파일: `engine/tests/test_llm.py`
- 가짜 클라이언트 클래스를 만들어 `monkeypatch.setattr(llm, "_make_client", ...)`:
  - 정상 응답 → content 반환, 호출 kwargs에 `temperature == 0.0`,
    `max_tokens == settings.max_tokens`, `model == settings.model` 확인
  - 1회차에 `openai.BadRequestError`(메시지에 "max_tokens" 포함) → 2회차 성공:
    2회차 `max_tokens`가 절반으로 줄었는지 확인
  - token과 무관한 `BadRequestError` → 즉시 전파
  - content=None → `RuntimeError`
- `openai.BadRequestError` 생성이 번거로우면
  `openai.BadRequestError(message, response=httpx.Response(400, request=httpx.Request("POST", "http://t")), body=None)` 패턴을 쓴다.

## 하지 말 것
- 스트리밍 금지. 실제 네트워크 호출 테스트 금지.
- 이 모듈 밖에서 openai import 금지 (창구는 여기 하나).

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_llm.py -q`

## 구현 결과

- **구현 완료 일시**: 2026-07-13T07:33:22Z
- **변경 파일**: `engine/aimd/llm.py`, `engine/tests/test_llm.py`, `regression-tests/verify-issue-6.sh`
- **계획과의 차이**: 없음 — 명세된 `chat`/`_make_client` 시그니처와 max_tokens 클램프 재시도 로직(절반씩 감소, 하한 `_MIN_TOKENS`, 도달 후 재실패 시 전파)을 그대로 구현. pyright 타입 체크를 위해 `messages`에 `ChatCompletionMessageParam` 타입 애노테이션 추가(spec에 없던 세부사항이나 동작에는 영향 없음).
- **검증 결과**:
  - pyright: 0 errors, 0 warnings
  - ruff: 이 세션 환경 문제(Windows용 ruff 바이너리가 WSL PATH에 잘못 잡힘)로 미실행 — issue-5와 동일한 pre-existing 이슈
  - 단위 테스트: `cd engine && uv run pytest tests/test_llm.py -q` → 5 passed (정상 응답/kwargs 확인, 토큰 에러 재시도, 비토큰 에러 전파, content=None RuntimeError, 하한 도달 후 전파)
  - 전체 테스트: `cd engine && uv run pytest -q` → 35 passed
  - 회귀 스크립트: `regression-tests/verify-issue-6.sh` OK (openai import가 llm.py에만 있는지도 함께 검증)
