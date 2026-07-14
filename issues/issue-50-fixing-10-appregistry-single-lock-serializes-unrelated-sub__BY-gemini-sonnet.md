# issue-50: fixing-10 — AppRegistry 단일 락이 무관한 서브앱 reload까지 직렬화 (must-fix)

## 부모
issue-10 (ASGI 디스패처)

## 출처
- `issues/issue-10__TYPE-code-review__BY-gemini.md` Finding 3 (must-fix / concurrency)
- `issues/issue-10__TYPE-code-review__BY-sonnet.md` §1 Verdict 3 (CONFIRMED)

## 문제
AppRegistry의 `get` 메서드는 디스패처당 1개 인스턴스에 단일 `self._lock`만 사용한다. 한 name의 reload(파일 읽기 + `compile + exec`) 중 다른 name 조회가 모두 블로킹된다.

```python
# engine/aimd/registry.py:36-56
def get(self, name: str, py_file: Path) -> Any:
    with self._lock:                      # ← name별 락이 아닌 전역 락
        current_mtime = py_file.stat().st_mtime
        entry = self._apps.get(name)
        ...
        module = validators.load_module(py_file)  # ← 무거운 작업이 락 안에서
        ...
        self._apps[name] = (app, current_mtime)
        return app
```

ADR-0004는 "디스패처당 1개 레지스트리"를 명시하지만, "모든 name이 같은 락 공유"는 명시하지 않았다 — spec 본문 22-23행의 "thread-safe: 모든 조작은 self._lock 안에서 수행"은 인터페이스 요구이지 락 범위 강제가 아니다. 이름별 락으로 분리 가능.

## 실패 시나리오
- 입력: app1.py (top-level에서 `time.sleep(2)` 후 `app = 1` 정의) + app2.py (즉시 로드 가능). 두 스레드가 동시에 각각 `reg.get("app1", ...)` / `reg.get("app2", ...)` 호출.
- 잘못된 결과: app2 조회가 ~1.8초 지연됨. SPEC상 의도되지 않은 직렬화.

## 확인 방법 (Sonnet 재현 결과)
```
app2 done in ~1.80s
```
전역 락이 없다면 ~0s.

## 권장 구현 방향
이름별 락으로 분리:
```python
from collections import defaultdict

class AppRegistry:
    def __init__(self) -> None:
        self._apps: dict[str, tuple[Any, float]] = {}
        self._locks: dict[str, threading.Lock] = {}
        self._locks_guard = threading.Lock()

    def _get_lock(self, name: str) -> threading.Lock:
        with self._locks_guard:
            lock = self._locks.get(name)
            if lock is None:
                lock = threading.Lock()
                self._locks[name] = lock
            return lock

    def get(self, name: str, py_file: Path) -> Any:
        with self._get_lock(name):
            ...
```

이름별 락이므로 다른 name의 reload는 병렬로 진행된다. drop도 자기 name 락만 잡으면 충분.

## 완료 조건
- [ ] AppRegistry가 이름별 락을 사용
- [ ] `test_concurrent_unrelated_reloads` 같은 회귀 테스트 추가 (스레드 2개로 검증)
- [ ] 기존 `test_registry.py` 7개 회귀 없음