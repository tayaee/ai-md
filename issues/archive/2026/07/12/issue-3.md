# issue-3: artifacts.py — 경로 매핑·신선도 판정·원자적 쓰기

## 의존성
issue-2 완료 후

## 목표
src↔dist 경로 규칙과 mtime 비교, 원자적 쓰기를 담는 순수 파일시스템 모듈.
LLM 접근 없음. 모든 함수는 `Settings`를 인자로 받는다.

## 배경
- docs/adr/0002-dumb-nginx.md (mtime은 Python 책임), docs/adr/0008 (원자적 쓰기)
- 이름 규칙: `name`은 항상 `"index.ai.md"`처럼 확장자 포함 파일명이다.

## 구현 상세

파일: `engine/aimd/artifacts.py`

```python
import os
import tempfile
from pathlib import Path

from .config import Settings


def spec_path(name: str, settings: Settings) -> Path:
    """src/<name>. 예: index.ai.md → src/index.ai.md"""
    return settings.src_dir / name


def html_path(name: str, settings: Settings) -> Path:
    """dist/<name>.html"""
    return settings.dist_dir / (name + ".html")


def py_path(name: str, settings: Settings) -> Path:
    """dist/<name>.py"""
    return settings.dist_dir / (name + ".py")


def artifact_path(name: str, settings: Settings) -> Path | None:
    """존재하는 아티팩트 경로를 반환. html 우선, 없으면 py, 둘 다 없으면 None."""


def is_stale(name: str, settings: Settings) -> bool:
    """컴파일이 필요하면 True.
    - 아티팩트가 하나도 없으면 True
    - spec_path의 mtime > 아티팩트 mtime 이면 True
    - spec 파일 자체가 없으면 False (컴파일 불가이므로 stale 아님)
    """


def atomic_write(path: Path, text: str) -> None:
    """같은 디렉토리에 tempfile.mkstemp로 tmp 파일을 만들어 text를 쓰고
    os.replace(tmp, path)로 원자적 교체. 실패 시 tmp 파일 삭제."""


def list_specs(settings: Settings) -> list[str]:
    """src_dir의 *.ai.md 파일명 목록(정렬). 하위 디렉토리는 보지 않는다."""
```

테스트 파일: `engine/tests/test_artifacts.py` (tmp_path fixture로 src/dist 구성)
- 경로 3함수의 문자열 결과 확인
- `artifact_path`: html만/py만/둘다(html 우선)/없음 4케이스
- `is_stale`: 아티팩트 없음→True, 아티팩트가 더 최신→False,
  spec을 `os.utime`으로 미래 mtime 설정→True, spec 없음→False
- `atomic_write`: 내용 기록 확인 + 기존 파일 덮어쓰기 확인 + tmp 잔여물 없음 확인

## 하지 말 것
- 전역 상태 금지. watchdog·LLM·비동기 코드 금지.

## 완료 조건
- [ ] docstring에 명시된 동작 전부 구현
- 검증 명령: `cd engine && python -m pytest tests/test_artifacts.py -q`

## 구현 결과

- **구현 완료 일시**: 2026-07-12T22:42:00Z
- **변경 파일**: `engine/aimd/artifacts.py`, `engine/tests/test_artifacts.py`, `regression-tests/verify-issue-3.sh`
- **계획과의 차이**: 없음 — 명세된 artifacts.py의 경로 매핑, is_stale, list_specs, atomic_write 함수 및 이에 상응하는 테스트 스위트를 충실하게 작성함.
- **검증 결과**: `regression-tests/verify-issue-3.sh` 통과. `cd engine && uv run pytest -q` 전체 통과 (8 passed).

