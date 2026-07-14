# issue-8: compiler.py — 컴파일 파이프라인 + 파일별 락

## 의존성
issue-3, issue-4, issue-7 완료 후

## 목표
"명세 읽기 → 분류 → 생성 → 검증 → 1회 수정 재시도 → 원자적 쓰기" 전체 파이프라인.
이 프로젝트의 심장이다. 테스트는 전부 mock.

## 배경
- docs/adr/0003 (파일별 락), docs/adr/0008 (검증·재시도·원자적 쓰기)

## 구현 상세

파일: `engine/aimd/compiler.py`

```python
import logging
import threading
from collections import defaultdict
from pathlib import Path

from . import artifacts, classifier, llm, validators
from .config import Settings
from .prompts import API_SYSTEM, FIX_TEMPLATE, SPA_SYSTEM

log = logging.getLogger("aimd.compiler")

_locks: dict[str, threading.Lock] = defaultdict(threading.Lock)
_locks_guard = threading.Lock()


class CompileError(Exception):
    """검증까지 최종 실패. 기존 캐시는 건드리지 않았음을 보장한다."""


def _get_lock(name: str) -> threading.Lock:
    with _locks_guard:
        return _locks[name]


def compile_spec(name: str, settings: Settings) -> Path:
    """name(예: "convert.ai.md")을 컴파일하고 아티팩트 경로를 반환한다.

    절차:
    1. _get_lock(name) 획득 (with 문)
    2. 락 안에서 재확인: artifacts.is_stale(name, settings)가 False면
       기존 artifacts.artifact_path(...)를 즉시 반환 (동시 요청 병합)
    3. spec 파일이 없으면 FileNotFoundError
    4. spec_text 읽기 → target = classifier.classify(spec_text, settings)
    5. system = SPA_SYSTEM if target == "spa" else API_SYSTEM
       raw = llm.chat(system, spec_text, settings)
       code = validators.extract_code(raw)
    6. 검증:
       - spa: error = validators.validate_html(code)
       - api: error = validators.validate_python(code)
    7. error가 있으면 수정 재시도 1회:
       raw2 = llm.chat(system, spec_text + "\n\n" + FIX_TEMPLATE.format(error=error), settings)
       code = validators.extract_code(raw2) 후 재검증.
       또 실패하면 log.error("compile failed for %s: %s", name, error) 후
       raise CompileError(error)  # dist는 건드리지 않았다
    8. 쓰기 전 반대 확장자 아티팩트 삭제(분류가 바뀐 경우 대비):
       target이 spa면 py_path 삭제(존재 시), api면 html_path 삭제(존재 시)
    9. api 타겟이면 추가 게이트: artifacts.atomic_write는 마지막에 하고,
       그 전에 임시 파일에 쓴 뒤 validators.load_module(임시경로)로 import가
       실제로 성공하는지 확인한다. 실패 시 7과 동일하게 수정 재시도 1회 → CompileError.
    10. out = html_path 또는 py_path → artifacts.atomic_write(out, code) → out 반환
    """
```

주의: 9단계 import 게이트는 6단계 검증과 별개다. 흐름을 단순하게 유지하기 위해
"검증 함수" 하나로 묶어도 된다: api는 `validate_python` 통과 후 tmp 파일에 써서
`load_module`까지 성공해야 검증 통과로 친다. 수정 재시도는 전체에서 딱 1회다.

테스트 파일: `engine/tests/test_compiler.py`
(모두 tmp_path에 src/dist 구성, `monkeypatch.setattr`로 `classifier.classify`와 `llm.chat` mock)
- spa 정상: chat이 유효 HTML 반환 → dist/<name>.html 생성, 내용 일치
- api 정상: chat이 `from fastapi import FastAPI\napp = FastAPI()` 류 반환
  → dist/<name>.py 생성 (FastAPI 미설치 환경 고려: 테스트에서는 `app = object()` 수준의
  순수 python 코드로 대체 가능 — load_module은 `app` 존재만 본다)
- 1회 수정 성공: chat이 1회차 깨진 코드, 2회차 정상 코드 반환 → 성공, chat 2회 호출 확인
- 2회 모두 실패: `CompileError`, dist에 파일 없음
- 기존 캐시 보존: dist에 구버전 아티팩트를 미리 두고 컴파일 실패 → 구버전 내용 그대로
- 동시 병합: 신선한 아티팩트가 이미 있으면 chat 호출 0회
- spec 없음 → `FileNotFoundError`

## 하지 말 것
- 무한 재시도 금지 (수정 재시도는 정확히 1회).
- 검증 통과 전 dist 쓰기 금지.
- asyncio 금지 — 이 모듈은 순수 동기. (비동기 어댑팅은 issue-10의 main.py가 한다)

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_compiler.py -q`

## 구현 결과

**구현 완료 일시**: 2026-07-13T23:28:57Z
**변경 파일**:
- engine/aimd/compiler.py (신규)
- engine/tests/test_compiler.py (신규)
- regression-tests/verify-issue-8.sh (신규)
- issues/issue-8__TYPE-agent-stats.json (신규)

**스펙 대비 deviation**: 없음. 단, 명세 9단계의 "6단계 검증과 별개" 주석을
따라 api 타겟의 문법 검증(`validate_python`)과 import 게이트
(`load_module`)를 `_validate` 헬퍼 하나로 묶어 수정 재시도가 전체에서
정확히 1회만 발생하도록 구현했다 (명세의 "흐름을 단순하게 유지" 지시와
일치).

**verify 결과**:
- 회귀 스크립트 (`regression-tests/verify-issue-8.sh`) 통과.
- 전체 pytest: 58 passed.
- 전체 회귀 스크립트: 19/19 통과.
- `uv run python -m compileall . -q` 통과.
- ruff/pyright: 리포 루트에 `pyproject.toml`이 없어 이 저장소의 기존
  관행(issue-7 등)과 동일하게 미실행 — `agent-stats.json`에
  `null`로 기록.
- `tools/log-cost-*.sh` 비용 계측 스크립트가 이 리포에 아직 존재하지
  않아 cost_details 계측은 스킵함 (감사용이며 게이트가 아니므로 진행에
  영향 없음).
