import logging

import httpx
import openai
from openai.types.chat import ChatCompletionMessageParam

from .config import Settings

log = logging.getLogger("aimd.llm")

_MIN_TOKENS = 4096
_MAX_CLAMP_RETRIES = 6
_ANTHROPIC_VERSION = "2023-06-01"


def _make_client(settings: Settings) -> openai.OpenAI:
    """Kept separate so it can be monkeypatched in tests."""
    return openai.OpenAI(api_key=settings.api_key, base_url=settings.base_url)


def chat(system: str, user: str, settings: Settings) -> str:
    """Single completion call with messages=[{system},{user}], temperature=0.0.

    The call style branches on settings.provider:
    - "claude": Anthropic Messages API (x-api-key header, /messages endpoint)
    - anything else ("openai" default): an OpenAI Chat Completions-compatible
      endpoint (openai / deepseek / minimax / openrouter, etc.)

    Both paths follow the same max_tokens clamp-and-retry rule: start with
    settings.max_tokens, and if it's an HTTP 400 whose error string contains
    "max_tokens" or "token", halve it and retry. Up to _MAX_CLAMP_RETRIES
    times, with a floor of _MIN_TOKENS. Any other exception propagates as-is.

    Returns the response text (str) on success. Raises RuntimeError on an empty response.
    """
    log.info("llm call start provider=%s model=%s", settings.provider, settings.model)
    if settings.provider == "claude":
        result = _chat_anthropic(system, user, settings)
    else:
        result = _chat_openai_compatible(system, user, settings)
    log.info("llm call done provider=%s model=%s", settings.provider, settings.model)
    return result


def _chat_openai_compatible(system: str, user: str, settings: Settings) -> str:
    client = _make_client(settings)
    tokens = settings.max_tokens
    messages: list[ChatCompletionMessageParam] = [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]

    last_error: openai.BadRequestError | None = None
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

    # If the retry budget (_MAX_CLAMP_RETRIES) is exhausted before reaching the
    # _MIN_TOKENS floor -- propagate the last actual BadRequestError as-is.
    # Do not disguise it as "empty LLM response" (issue-38).
    assert last_error is not None
    raise last_error


def _make_anthropic_client(settings: Settings) -> httpx.Client:
    """Kept separate so it can be monkeypatched in tests."""
    return httpx.Client(
        base_url=settings.base_url,
        headers={
            "x-api-key": settings.api_key,
            "anthropic-version": _ANTHROPIC_VERSION,
            "content-type": "application/json",
        },
    )


def _chat_anthropic(system: str, user: str, settings: Settings) -> str:
    client = _make_anthropic_client(settings)
    tokens = settings.max_tokens

    last_error: httpx.HTTPStatusError | None = None
    for _ in range(_MAX_CLAMP_RETRIES + 1):
        response = client.post(
            "/messages",
            json={
                "model": settings.model,
                "max_tokens": tokens,
                "temperature": 0.0,
                "system": system,
                "messages": [{"role": "user", "content": user}],
            },
        )
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as e:
            body = response.text
            if response.status_code != 400 or (
                "max_tokens" not in body and "token" not in body
            ):
                raise
            last_error = e
            if tokens <= _MIN_TOKENS:
                raise
            tokens = max(tokens // 2, _MIN_TOKENS)
            log.warning("max_tokens rejected, retrying with %d", tokens)
            continue

        data = response.json()
        blocks = data.get("content") or []
        text = "".join(b.get("text", "") for b in blocks if b.get("type") == "text")
        if not text:
            raise RuntimeError("empty LLM response")
        return text

    assert last_error is not None
    raise last_error
