# issue-10: main.py — ASGI 디스패처 (URL 계약 구현)

## 의존성
issue-8, issue-9 완료 후

## 목표
uvicorn이 구동할 호스트 ASGI 앱. URL 계약(ADR-0001) 전체와 lazy 컴파일
트리거(ADR-0003)를 구현한다. 가장 어려운 이슈 — 아래 골격을 그대로 따른다.

## 배경
- docs/adr/0001, 0003, 0004. docs/SPEC.md 2장 표가 수용 기준이다.

## 구현 상세

파일: `engine/aimd/main.py`

```python
import asyncio
import json
import logging
import re
from pathlib import Path

from . import artifacts, compiler
from .config import Settings, load_settings
from .registry import AppRegistry

log = logging.getLogger("aimd.main")

_AIMD_RE = re.compile(r"^/([^/]+\.ai\.md)(/.*)?$")


class AIMDDispatcher:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or load_settings()
        self.registry = AppRegistry()

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return  # lifespan 등은 무시 (uvicorn --lifespan off 로 구동)
        path = scope["path"]
        if path == "/":
            return await _redirect(send, "/index.ai.md")
        m = _AIMD_RE.match(path)
        if not m:
            return await _plain(send, 404, "not found")
        name, subpath = m.group(1), m.group(2)

        if not artifacts.spec_path(name, self.settings).exists():
            return await _plain(send, 404, "no such spec")

        # lazy 컴파일 (동기 compile_spec을 스레드로)
        if artifacts.is_stale(name, self.settings):
            try:
                await asyncio.to_thread(compiler.compile_spec, name, self.settings)
            except Exception as e:
                if artifacts.artifact_path(name, self.settings) is None:
                    return await _json(send, 502, {"error": f"compile failed: {e}"})
                log.error("recompile failed for %s, serving stale artifact: %s", name, e)

        html = artifacts.html_path(name, self.settings)
        py = artifacts.py_path(name, self.settings)

        if html.exists():
            return await _file(send, html)  # SPA: subpath 무시하고 html 반환
        if py.exists():
            if not subpath and scope["method"] == "GET":
                return await _redirect(send, f"/{name}/docs")
            app = self.registry.get(name, py)
            sub_scope = dict(scope)
            sub_scope["root_path"] = f"/{name}"
            sub_scope["path"] = subpath or "/"
            return await app(sub_scope, receive, send)
        return await _json(send, 502, {"error": "no artifact"})


# ── 저수준 ASGI 응답 헬퍼 3개 ──────────────────────────
async def _plain(send, status: int, text: str): ...
async def _json(send, status: int, obj: dict): ...
async def _redirect(send, location: str): ...   # 302 + Location 헤더
async def _file(send, path: Path): ...          # 200 + text/html; charset=utf-8


app = AIMDDispatcher
```

헬퍼 구현 지침 (전부 동일 패턴):
`await send({"type": "http.response.start", "status": ..., "headers": [(b"content-type", ...)]})`
→ `await send({"type": "http.response.body", "body": ...})`.
`_file`은 `path.read_bytes()`로 통째 읽기(POC 규모에서 충분).

마지막 줄 주의: uvicorn 구동은 `uvicorn aimd.main:app --factory` 형태를 쓰지 않고,
`app = AIMDDispatcher()` **인스턴스**를 모듈 레벨에 만들면 import 시점에
`load_settings()`가 필요해 테스트가 불편하다. 따라서:

```python
def create_app() -> AIMDDispatcher:
    return AIMDDispatcher()
```

로 팩토리를 두고, 컨테이너에서는 `uvicorn "aimd.main:create_app" --factory`로 구동한다.

테스트 파일: `engine/tests/test_main.py`
- `httpx.AsyncClient(transport=httpx.ASGITransport(app=dispatcher), base_url="http://t")` 사용
- dispatcher는 `AIMDDispatcher(settings=테스트설정)`으로 직접 생성 (환경 변수에 가짜 키 주입)
- `compiler.compile_spec`은 `monkeypatch`로 mock (실 LLM 금지)
- 케이스:
  1. `GET /` → 302, Location `/index.ai.md`
  2. `GET /없는파일.ai.md` → 404
  3. dist에 html 있음 + 신선 → 200, 내용 일치, compile_spec 호출 0회
  4. dist 비어있음 → compile_spec 1회 호출됨 (mock이 html 생성) → 200
  5. compile_spec raise + 캐시 없음 → 502 JSON
  6. compile_spec raise + 캐시 있음(stale) → 200 (stale 서빙)
  7. py 아티팩트(`async def app(scope, receive, send)`인 미니 ASGI 앱을 문자열로 작성) +
     `GET /x.ai.md` → 302 `/x.ai.md/docs`
  8. 같은 py + `POST /x.ai.md/convert` → 서브앱이 받은 scope의
     `root_path == "/x.ai.md"`, `path == "/convert"` 확인

## 하지 말 것
- FastAPI/Starlette로 호스트 앱 만들기 금지 — 순수 ASGI 디스패처다
  (라우팅 규칙이 정규식 하나라 프레임워크가 오히려 방해).
- watchdog 연결 금지 (issue-11).

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_main.py -q`

## 구현 결과

**구현 완료 일시**: 2026-07-14T01:59:27Z
**구현 범위**: issue-10 본체 + issue-9 선행 의존성(AppRegistry)

**변경 파일**:
- `engine/aimd/main.py` — AIMDDispatcher + ASGI 헬퍼 4종 (`_plain`, `_json`, `_redirect`, `_file`) + `create_app()` 팩토리
- `engine/aimd/registry.py` — AppRegistry (hot-swap, mtime 기반 reload, thread-safe)
- `engine/aimd/validators.py` — `load_module` 의 pyc timestamp 캐시 우회 (compile+exec 직접 호출로 변경) — registry의 mtime 기반 reload를 무력화시키던 회귀 수정
- `engine/tests/test_main.py` — 케이스 10개 (이슈 본문 8개 + lifespan 무시 + create_app 팩토리)
- `engine/tests/test_registry.py` — 케이스 7개 (이슈-9 spec 6개 + drop nonexistent noop)
- `regression-tests/verify-issue-10.sh` — 메커니컬 체크 21개 (PASS=21)

**스펙과의 차이**:
- 없음 — 이슈 본문이 명시한 골격을 그대로 따랐다.
- 부수적 결정: `validators.load_module` 의 pyc timestamp 캐시 검증이 registry의 mtime 기반 reload를 사실상 무력화시키는 회귀가 있어 hot-swap을 위해 `compile + exec` 직접 호출로 우회했다 (`SourceFileLoader`의 `_validate_timestamp_pyc`는 같은 초 안의 두 번 쓰기를 구분하지 못한다). 이 변경은 기존 load_module 사용처(compiler의 `_import_gate`)의 외부 동작을 유지한다 — module.app 이 노출되는 계약은 동일.

**검증 결과**:
- `cd engine && uv run pytest -q` → 77 passed
- `cd engine && uv run pyright` → 0 errors
- `bash regression-tests/verify-issue-10.sh` → PASS=21 FAIL=0
- `bash acpd/defaults/run-regression-tests.sh` → PASS=22 FAIL=0
