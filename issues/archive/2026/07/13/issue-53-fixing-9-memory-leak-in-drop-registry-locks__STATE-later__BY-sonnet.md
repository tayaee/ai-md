# issue-53: fixing-9 — AppRegistry.drop 시 _locks 딕셔너리 미제거로 인한 메모리 누수 (good-to-fix)

## 부모
issue-9 (Registry)

## 출처
- `issues/issue-9__TYPE-code-review__BY-sonnet.md` Finding 1 (good-to-fix)

## 문제
`drop(name)`을 호출하여 서브앱을 제거할 때, `self._apps` 딕셔너리에서는 삭제되지만 `self._locks`에 캐싱된 이름별 Lock 객체는 계속 남아있습니다. 서브앱이 동적으로 계속 생성되고 폐기되는 환경이라면 `self._locks` 딕셔너리가 무한히 누적되어 잠재적인 메모리 누수 원인이 될 수 있습니다.

```python
# engine/aimd/registry.py:81-88
def drop(self, name: str) -> None:
    """등록 해제 (py 아티팩트가 삭제된 경우용). 없으면 무시."""
    with self._lock_for(name):
        self._apps.pop(name, None)
    # 락 dict에는 남겨둔다 — 같은 name 재등록 시 lock 자체를 재사용하면
    # stale lock 보유자가 새 get을 기다리는 행교를 피할 수 있다
```

## 실패 시나리오
- 입력: 임의의 고유 서브앱 이름들에 대해 지속적인 `get`과 `drop` 수행
- 잘못된 결과: `self._apps`에서는 아이템이 정상적으로 제거되지만, `self._locks` 딕셔너리는 계속해서 키가 늘어남

## 확인 방법
- good-to-fix이므로 재검증 생략.
- (참고) 고유한 여러 이름들에 대해 `get`과 `drop`을 수행한 후, `reg._locks` 딕셔너리 크기가 정리되지 않고 계속 늘어나고 있는지 확인.

## 권장 구현 방향
`drop(name)` 호출 시 안전하게 `self._locks`에서도 해당 이름의 락을 팝하거나 주기적인 정리 기능을 도입하는 방안을 고려합니다. 단, 동시성 이슈를 유발하지 않도록 설계되어야 합니다.
```python
with self._locks_guard:
    self._locks.pop(name, None)
```

## 완료 조건
- [ ] `engine/aimd/registry.py`의 `AppRegistry.drop` 메서드 내 락 정리 로직 개선
- [ ] `cd engine && uv run pytest tests/test_registry.py -q` 통과
