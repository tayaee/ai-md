# issue-54: fixing-9 — main.py의 AppRegistry.get 동기 호출로 인한 이벤트 루프 블로킹 (must-fix)

## 부모
issue-9 (Registry)

## 출처
- `issues/issue-9__TYPE-code-review__BY-sonnet.md` Finding 1 (must-fix)

## 문제
`AppRegistry.get()` 내부의 `validators.load_module()`(파일 I/O + compile + exec) 등 무거운 블로킹 로직이 `AIMDDispatcher.__call__` 비동기 메소드 내에서 `await`나 `asyncio.to_thread` 없이 동기 함수로 직접 호출됩니다. 
이로 인해 uvicorn의 단일 asyncio 이벤트 루프 스레드가 완전히 점유되어, 로딩 중인 서브앱뿐만 아니라 서버가 처리하고 있는 다른 모든 서브앱의 요청들까지 전부 블로킹되는 심각한 병목 현상이 발생합니다. 이는 이름별 락(`_lock_for`)의 의도(서브앱 간 리로드 격리)를 실질적으로 무색하게 만듭니다.

```python
# engine/aimd/main.py:88
app = self.registry.get(name, py)
```

## 실패 시나리오
- 입력: 여러 개의 서브앱(예: app1, app2)에 대한 비동기 요청이 동시 유입되며, 그 중 app1은 리로드가 필요하여 무거운 compile/import 로직을 수행함.
- 잘못된 결과: app1 로드가 완료될 때까지 단일 이벤트 루프 스레드가 블로킹되어, 리로드가 필요 없는 app2의 요청조차 처리되지 못하고 직렬화되어 대기함.

## 확인 방법 (재검증 완료)
- `AIMDDispatcher`를 통한 동시 비동기 요청 시뮬레이션을 수행하거나, `asyncio.gather`를 통해 한 서브앱의 `registry.get`이 수행되는 동안 다른 서브앱 요청 코루틴이 블로킹되는 것을 스케줄 지연 시간을 측정하여 검증함.

## 권장 구현 방향
`main.py:88`의 `registry.get` 호출부를 `asyncio.to_thread`로 감싸서 별도 스레드 풀에서 안전하게 실행하도록 수정합니다.
```python
app = await asyncio.to_thread(self.registry.get, name, py)
```

## 완료 조건
- [ ] `engine/aimd/main.py` 내의 `self.registry.get` 호출부를 `asyncio.to_thread`를 사용하여 비동기 오프로딩하도록 수정
- [ ] 단위 테스트 작성 및 `pytest` 통과
