# issue-26: load_module의 `_counter` 가 실패 시에도 advance되는 동작 docstring 명시 (good-to-fix)

## 상태


## 의존성
issue-4 완료 후

## 배경
`engine/aimd/validators.py:9, 54` 의 `_counter = itertools.count()` 와
`next(_counter)` 호출은 `exec_module` 가 RuntimeError/SyntaxError/ImportError로 실패해도
이미 advance된다. 이는 spec의 "재로드 시 신선한 객체 보장" 의도된 동작이지만, 운영
가시성(로깅/추적) 관점에서 "실제로 사용되지 않은 번호가 남는" 코너 케이스가 있다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-sonnet.md` (Finding 3, good-to-fix).
리뷰어 메모: "동작은 의도된 것이지만 spec 본문 49행에서 `next(_counter)` 만 강조하고
실패 시 동작에 대한 단서가 없음" — 기능 결함이 아닌 문서 보강 제안.

## 검토 포인트
- 현재 동작 자체는 spec 의도대로 — 수정 불필요
- spec 본문(`issues/archive/2026/07/12/issue-4.md` 49-52행) 또는
  `validators.py` docstring에 "실패 시 카운터도 advance됨" 명시 추가
- 운영 디버깅 시 "aimd_dyn_7이 어디로 갔지?" 같은 혼란 방지

## 권장 구현(가이드)
- `load_module` docstring에 한 줄 추가: "참고: 모듈 로드 실패 시에도 카운터는
  advance됩니다 (호출자가 새 모듈 이름을 추적할 때 유의)."

## 완료 조건(승격 후)
- [ ] `load_module` docstring에 카운터 advance 동작 명시
- [ ] 기존 5개 load_module 테스트 회귀 없음