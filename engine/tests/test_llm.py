from pathlib import Path

import httpx
import openai
import pytest
from aimd import llm
from aimd.config import Settings


def make_settings(max_tokens: int = 8192) -> Settings:
    return Settings(
        api_key="k",
        base_url="http://t",
        model="MiniMax-M3",
        max_tokens=max_tokens,
        src_dir=Path("./src"),
        dist_dir=Path("./dist"),
    )


def bad_request(message: str) -> openai.BadRequestError:
    return openai.BadRequestError(
        message,
        response=httpx.Response(400, request=httpx.Request("POST", "http://t")),
        body=None,
    )


class _FakeMessage:
    def __init__(self, content):
        self.content = content


class _FakeChoice:
    def __init__(self, content):
        self.message = _FakeMessage(content)


class _FakeResponse:
    def __init__(self, content):
        self.choices = [_FakeChoice(content)]


class _FakeCompletions:
    def __init__(self, side_effects):
        self.side_effects = list(side_effects)
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        effect = self.side_effects.pop(0)
        if isinstance(effect, Exception):
            raise effect
        return _FakeResponse(effect)


class _FakeChat:
    def __init__(self, side_effects):
        self.completions = _FakeCompletions(side_effects)


class _FakeClient:
    def __init__(self, side_effects):
        self.chat = _FakeChat(side_effects)


def _install_fake_client(monkeypatch, side_effects):
    fake = _FakeClient(side_effects)
    monkeypatch.setattr(llm, "_make_client", lambda settings: fake)
    return fake


def test_chat_returns_content_with_expected_kwargs(monkeypatch):
    settings = make_settings(max_tokens=8192)
    fake = _install_fake_client(monkeypatch, ["hello"])

    result = llm.chat("sys", "user", settings)

    assert result == "hello"
    assert len(fake.chat.completions.calls) == 1
    kwargs = fake.chat.completions.calls[0]
    assert kwargs["temperature"] == 0.0
    assert kwargs["max_tokens"] == 8192
    assert kwargs["model"] == "MiniMax-M3"


def test_chat_retries_with_halved_max_tokens_on_token_error(monkeypatch):
    settings = make_settings(max_tokens=8192)
    fake = _install_fake_client(
        monkeypatch,
        [bad_request("max_tokens too large"), "ok after retry"],
    )

    result = llm.chat("sys", "user", settings)

    assert result == "ok after retry"
    assert len(fake.chat.completions.calls) == 2
    assert fake.chat.completions.calls[0]["max_tokens"] == 8192
    assert fake.chat.completions.calls[1]["max_tokens"] == 4096


def test_chat_propagates_non_token_bad_request(monkeypatch):
    settings = make_settings(max_tokens=8192)
    _install_fake_client(monkeypatch, [bad_request("invalid api key")])

    with pytest.raises(openai.BadRequestError):
        llm.chat("sys", "user", settings)


def test_chat_raises_on_empty_content(monkeypatch):
    settings = make_settings(max_tokens=8192)
    _install_fake_client(monkeypatch, [None])

    with pytest.raises(RuntimeError):
        llm.chat("sys", "user", settings)


def test_chat_stops_retrying_at_min_tokens_floor(monkeypatch):
    min_tokens_x2 = llm._MIN_TOKENS * 2
    settings = make_settings(max_tokens=min_tokens_x2)
    fake = _install_fake_client(
        monkeypatch,
        [
            bad_request("max_tokens too large"),
            bad_request("max_tokens too large"),
        ],
    )

    with pytest.raises(openai.BadRequestError):
        llm.chat("sys", "user", settings)

    assert fake.chat.completions.calls[0]["max_tokens"] == min_tokens_x2
    assert fake.chat.completions.calls[1]["max_tokens"] == llm._MIN_TOKENS


def test_chat_raises_bad_request_when_retries_exhausted_before_floor(monkeypatch):
    settings = make_settings(max_tokens=524288)
    _install_fake_client(
        monkeypatch,
        [bad_request("max_tokens too large")] * (llm._MAX_CLAMP_RETRIES + 1),
    )

    with pytest.raises(openai.BadRequestError):
        llm.chat("sys", "user", settings)
