`issues/issue-9__TYPE-code-review__BY-sonnet.md`에 리뷰를 작성했습니다.

- 기존에 이미 채워져 있던 파일의 두 must-fix 항목(**Finding 1**: `py_file.stat()`이 try/except 밖에 있어 캐시된 정상 app이 있어도 파일이 일시적으로 사라지면 크래시함, **Finding 2**: mtime이 우연히 동일하면 새 내용이 영구히 무시되는 stale-forever 버그)을 직접 재현 스크립트로 검증했고, 실제로 재현됨을 확인했습니다.
- 제가 독자적으로 발견한 **Finding 6**(`test_unchanged_file_returns_same_object`가 CPython의 문자열 interning 때문에 "reload 안 함" 회귀를 실제로는 검증하지 못함 — 캐시 로직을 완전히 무력화해도 테스트가 통과함을 직접 확인)을 good-to-fix로 추가했습니다.
- 제가 검토했던 `_locks` 무한 누적 문제는 이미 기존 Finding 5로 포함되어 있어 중복 추가하지 않았습니다.
move` 후 `get()` 호출로 실제 크래시 재현 확인.

TOCTOU mtime 관련 의심 사항(finding B)은 결정론적 재현에 실패해 보고서에서 제외했고, `drop()` 미사용 건은 registry.py 자체 결함이 아니라 issue-10 통합 쪽 문제로 보여 범위 밖으로 분류해 참고 항목으로만 남겼습니다.
프(프로세스당 1스레드)에서 ASGI 앱을 실행한다. `AIMDDispatcher.__call__`은 `async def`이지만 `self.registry.get(name, py)`는 `await` 없이 동기 호출된다. `AppRegistry.get()` 내부의 `threading.Lock.acquire()`, `py_file.stat()`, `validators.load_module()`(파일 읽기+compile+exec)은 전부 이벤트 루프 스레드에서 그대로 실행되며 중간에 `await` 지점이 전혀 없다. 따라서 이름이 다른 서브앱(app1, app2)에 대한 두 개의 동시 asyncio 요청이 들어와도, app1의 무거운 로드가 실행되는 동안 app2 요청 코루틴은 스케줄조차 되지 못하고 대기한다 — issue-50이 없애려던 바로 그 "무관한 서브앱 조회 블로킹"이 이름별 락과 무관하게 그대로 재현된다. `test_concurrent_unrelated_reloads_do_not_block` 테스트는 `threading.Thread`로 실제 OS 스레드 병렬성을 만들어 검증하므로 통과하지만, 이는 프로덕션의 실제 호출 방식(단일 이벤트 루프, 동기 직접 호출)과 다르다 — 테스트가 증명하는 병렬성은 실제로 발생하지 않는다.

- **확인 방법**: 아래 스크립트로 재현됨 (실행 결과 첨부).
  ```python
  # /tmp/repro_eventloop_block2.py — main.py:88의 실제 호출 패턴(동기 reg.get()을
  # await 없이 async 함수 안에서 호출)을 그대로 재현
  import asyncio, time
  from pathlib import Path
  from aimd.registry import AppRegistry

  async def main():
      tmp = Path("/tmp/repro_registry"); tmp.mkdir(exist_ok=True)
      app1 = tmp / "app1.ai.md.py"
      app1.write_text("import time as _t\n_t.sleep(2)\napp = 'app1'\n")
      app2 = tmp / "app2.ai.md.py"
      app2.write_text("app = 'app2'\n")
      reg = AppRegistry(); t0 = time.monotonic()

      async def handle(name, path):
          started = time.monotonic() - t0
          reg.get(name, path)  # main.py:88과 동일 — await 없음
          print(f"{name}: started={started:.2f}s finished={time.monotonic()-t0:.2f}s")

      async def req1(): await handle("app1.ai.md", app1)
      async def req2():
          await asyncio.sleep(0.1)
          await handle("app2.ai.md", app2)

      await asyncio.gather(req1(), req2())
  asyncio.run(main())
  ```
  실행: `cd engine && PYTHONPATH=. uv run python /tmp/repro_eventloop_block2.py`
  실측 출력:
  ```
  app1.ai.md: started=0.00s finished=2.04s -> app1
  app2.ai.md: started=2.14s finished=2.14s -> app2
  ```
  app2 요청은 0.1초 뒤 스케줄되어야 하지만 실제로는 app1이 끝난 뒤(2.14s)에야 시작됨 — 이름별 락에도 불구하고 완전히 직렬화됨.

- **심각도 제안**: must-fix (issue-50의 완료 조건 "한 서브앱의 느린 모듈 로드가 다른 서브앱 조회를 블로킹하지 않는다"가 실제 서비스 경로에서는 충족되지 않음. 수정 방향: `main.py:88`을 `await asyncio.to_thread(self.registry.get, name, py)`로 오프로드하거나, `AppRegistry.get`을 async화해야 이번 diff의 이름별 락이 실질적 효과를 가짐.)

---

### Finding 2 — `_locks` dict가 `drop()` 이후에도 정리되지 않아 장기 실행 시 무한 누적

- **파일:라인**: `engine/aimd/registry.py:81-88`
- **코드 인용**:
  ```python
  def drop(self, name: str) -> None:
      with self._lock_for(name):
          self._apps.pop(name, None)
      # 락 dict에는 남겨둔다 — ...
  ```
- **실패 시나리오**: 서브앱 이름이 동적으로 생성/삭제되는 운영 패턴(예: 프리뷰용 임시 `.ai.md` 스펙을 자주 만들었다 지우는 경우)에서 `drop()`이 호출될 때마다 `_apps`에서는 제거되지만 `_locks[name]`의 `threading.Lock` 객체는 프로세스 종료까지 영구 보관된다. 서로 다른 name이 누적적으로 계속 생겨나면 `_locks` dict가 무한정 커진다.
- **확인 방법**: `for i in range(100000): reg.get(f"x{i}.ai.md", py); reg.drop(f"x{i}.ai.md")` 후 `len(reg._locks)`를 확인하면 100000으로 계속 증가함을 직접 확인 가능.
- **심각도 제안**: good-to-fix
