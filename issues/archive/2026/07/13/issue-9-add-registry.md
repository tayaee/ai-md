# issue-9: registry.py — 동적 서브앱 레지스트리 (핫스왑)

## 의존성
issue-4 완료 후 (issue-8과 병렬 가능)

## 목표
`dist/*.ai.md.py`의 `app` 객체를 보관하고, 파일이 갱신되면 새 모듈로 교체하는
레지스트리. import 실패 시 기존 앱을 유지한다.

## 배경
- docs/adr/0004-hot-swap-single-host-app.md

## 구현 상세

파일: `engine/aimd/registry.py`

```python
import logging
import threading
from pathlib import Path
from typing import Any

from . import validators

log = logging.getLogger("aimd.registry")


class AppRegistry:
    """name(예: "convert.ai.md") → (ASGI app, 로드 시점 py mtime) 보관소."""

    def __init__(self) -> None:
        self._apps: dict[str, tuple[Any, float]] = {}
        self._lock = threading.Lock()

    def get(self, name: str, py_file: Path) -> Any:
        """py_file 기준 최신 app을 반환한다.
        - 미등록이거나 py_file.stat().st_mtime이 저장된 mtime보다 크면 reload 시도
        - reload: validators.load_module(py_file) → 성공 시 (module.app, mtime)로 교체
        - reload 실패: log.error("hot-swap failed for %s: %s", name, e) 후
          기존 app이 있으면 그대로 반환, 없으면 예외 전파
        - 전 과정을 self._lock 안에서 수행
        """

    def drop(self, name: str) -> None:
        """등록 해제 (py 아티팩트가 삭제된 경우용). 없으면 무시."""
```

테스트 파일: `engine/tests/test_registry.py` (tmp_path에 py 파일 작성; `app = <값>` 형태의 순수 python으로 충분)
- 최초 get → 로드되고 app 반환
- 파일 그대로 재호출 → 같은 객체 (reload 안 함 — load_module 호출 횟수를 세는 spy로 확인 가능)
- 파일 내용 갱신 + `os.utime`으로 mtime 증가 → 새 app 반환
- 갱신본이 import 실패(예: `raise RuntimeError`) → 기존 app 유지 + 예외 안 남
- 미등록 상태에서 import 실패 → 예외 전파
- drop 후 get → 재로드

## 하지 말 것
- 컴파일 트리거 금지 — 레지스트리는 dist만 본다. 컴파일은 main.py(issue-10) 책임.
- FastAPI import 금지 (validators.load_module이 `app` 존재만 보장).

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_registry.py -q`

## 구현 결과
- `engine/aimd/registry.py`에 `AppRegistry`를 성공적으로 구현하였습니다.
- 이름별 락(`_lock_for`)을 적용하여 동시성을 안전하게 처리하였고, `engine/tests/test_registry.py` 계약 테스트를 모두 통과하였습니다.
- `regression-tests/verify-issue-9.sh` 검증이 통과되었습니다.
