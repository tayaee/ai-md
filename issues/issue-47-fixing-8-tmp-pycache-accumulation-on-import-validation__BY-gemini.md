# issue-47: compiler._import_gate — 임시 .py 파일 import 시 생성되는 __pycache__ 잔여물 정리 안 됨 (good-to-fix)

## 상태


## 의존성
issue-8 완료 후

## 배경
gemini의 issue-8 리뷰 Finding 5(good-to-fix): `_import_gate`가 tempfile로 만든
`.py`는 unlink하지만, import 시 파이썬이 자동 생성하는 `__pycache__/*.pyc`는
정리하지 않는다.

원본 리뷰 파일: `issues/issue-8__TYPE-code-review__BY-gemini.md` (Finding 5)

## 검토 포인트
- good-to-fix로 리뷰어가 직접 제안 — 재검증 생략(정책).
- `validators.load_module`이 `spec_from_file_location` + `exec_module`을
  사용하므로, 표준 importlib 캐싱 동작에 따라 `__pycache__`가 생성될 수 있음
  (구현체·인터프리터 옵션에 따라 다를 수 있음 — 승격 시 실제 재현 확인 필요).

## 권장 구현(가이드)
승격한다면 `_import_gate`의 `finally` 블록에서
`tmp_path.parent / "__pycache__"`도 함께 정리하거나, 임포트 직전
`sys.dont_write_bytecode = True`를 임시로 설정하는 방식을 검토한다.

## 완료 조건(승격 후)
- [ ] 반복 호출 후 임시 디렉터리에 `__pycache__` 잔여물이 남지 않음을
      확인하는 테스트 추가

## 구현 결과
(구현 후 기록)
