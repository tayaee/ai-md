# issue-11: watcher.py — watchdog 선컴파일 스레드

## 의존성
issue-8 완료 후 (issue-10과 병렬 가능)

## 목표
`src/*.ai.md` 저장 이벤트를 감지해 백그라운드에서 미리 컴파일한다.
요청 경로에서 stale을 만날 일을 없애는 1차 신선도 방어선(ADR-0002).

## 구현 상세

파일: `engine/aimd/watcher.py`

```python
import logging
import threading
import time

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from . import compiler
from .config import Settings

log = logging.getLogger("aimd.watcher")

_DEBOUNCE_SECONDS = 0.5


class _SpecEventHandler(FileSystemEventHandler):
    """created/modified 이벤트 중 *.ai.md 파일만 처리한다.
    - 디렉토리 이벤트 무시
    - 파일별 마지막 이벤트 시각을 기록해 _DEBOUNCE_SECONDS 안의 중복 이벤트 무시
    - 처리: threading.Thread(target=self._compile, args=(name,), daemon=True).start()
    - _compile은 compiler.compile_spec을 try/except로 감싸고 실패 시
      log.error("background compile failed for %s: %s", name, e) 만 남긴다 (전파 금지)
    """


def start_watcher(settings: Settings) -> Observer:
    """Observer를 만들어 settings.src_dir을 비재귀로 감시 시작하고 반환한다.
    호출자가 프로세스 수명 동안 참조를 유지한다."""
```

main.py 연결 (이 이슈에서 수정): `create_app()` 안에서
`start_watcher(settings)`를 호출하고 반환된 observer를 dispatcher 속성에 보관한다.
단, 테스트에서 파일 감시가 뜨지 않도록 `AIMDDispatcher.__init__`에
`watch: bool = False` 인자를 추가하고 `create_app()`에서만 `watch=True`로 켠다.

테스트 파일: `engine/tests/test_watcher.py`
- `compiler.compile_spec`을 mock(호출 기록)한 뒤 tmp src_dir로 `start_watcher`
- `.ai.md` 파일 생성 → `time.sleep(1.5)` 폴링 → compile_spec이 해당 name으로 호출됨
- `.txt` 파일 생성 → 호출 없음
- 같은 파일 빠른 연속 저장 2회 → 호출 1회 (디바운스)
- 테스트 끝에 `observer.stop(); observer.join()`

## 하지 말 것
- asyncio 금지 — watchdog 콜백은 자체 스레드에서 돈다.
- 컴파일 실패를 예외로 올리기 금지 (로그만).

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_watcher.py -q`

## 구현 결과
- `engine/aimd/watcher.py`에 `FileSystemEventHandler` 및 `Observer`를 활용한 동적 선컴파일 감시 스레드를 구현하였습니다.
- `engine/tests/test_watcher.py`에서 생성/변경 이벤트 감지, txt 무시, 디바운스 등의 계약 요구 사항을 완벽히 테스트하고 통과하였습니다.
- `regression-tests/verify-issue-11.sh` 검증이 통과되었습니다.
