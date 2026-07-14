# issue-27: load_module의 `spec_from_file_location` None 가드 메시지 의미 분리 (good-to-fix)

## 상태


## 의존성
issue-4 완료 후

## 배경
`engine/aimd/validators.py:56-59` 의 가드 분기:
```python
if spec is None or spec.loader is None:
    # spec_from_file_location 이 None을 반환하는 경우는 거의 없지만
    # 방어적으로 AttributeError로 일관되게 처리한다.
    raise AttributeError("module has no 'app' object")
```

`spec_from_file_location` 이 None 을 반환하는 경우(유효하지 않은 모듈명/loader)와
`hasattr(module, "app")` 가 False인 경우는 원인 자체가 다르지만 동일한 AttributeError
메시지로 던져진다. 호출자가 `except AttributeError` 만 잡으면 두 실패를 구분할 수 없다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-sonnet.md` (Finding 5, good-to-fix).

## 검토 포인트
- spec에 이 분기 동작이 명시되어 있지 않음 — 구현자 판단 영역
- 두 가지 정책:
  1. **구분**: spec/loader None은 별도 `ImportError` 또는 다른 메시지로 던짐
  2. **유지**: 현재대로 동일한 AttributeError — 디버깅 정보 손실 감수
- 옵션 1이 디버깅 친화적. 옵션 2는 호출자 단순화.

## 권장 구현(가이드)
- 옵션 1 선택 시:
  ```python
  if spec is None or spec.loader is None:
      raise ImportError(f"cannot load spec from {path}")
  ```
  또는 RuntimeError.
- 옵션 2 선택 시: 현재 동작 유지 + docstring에 분기 설명 추가

## 완료 조건(승격 후)
- [ ] spec/loader None 가드가 의도한 메시지로 던져짐
- [ ] 기존 5개 load_module 테스트 회귀 없음