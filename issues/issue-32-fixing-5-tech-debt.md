# issue-32: test_constants_are_nonempty_strings가 프롬프트의 하드제약 문구 삭제(의미론적 회귀)를 못 잡음 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`engine/tests/test_prompts.py:9-12`의 `test_constants_are_nonempty_strings`는
문자열이 비어있지 않은지만 확인한다. `SPA_SYSTEM`에서
"No external libraries, no CDN links, no fetch to other origins" 같은
보안 하드제약 bullet이 삭제돼도 이 테스트와 기존 키워드
테스트("HTML"/"FastAPI" 포함 여부)는 모두 통과한다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 1, good-to-fix).

## 검토 포인트
- 각 상수의 핵심 보안/제약 키워드를 명시적으로 검증하는 테스트 추가 여부
  (예: `"No external libraries" in SPA_SYSTEM`,
  `"Do NOT call uvicorn.run()" in API_SYSTEM`,
  `"No other words" in CLASSIFY_SYSTEM`)
- issue-5.md의 "함수·클래스 추가 금지" 제약과 충돌 없음(테스트 추가는
  prompts.py 자체가 아닌 test_prompts.py에 해당)

## 권장 구현(가이드)
`engine/tests/test_prompts.py`에 상수별 핵심 제약 키워드 포함 여부를 검증하는
테스트를 추가.

## 완료 조건(승격 후)
- [ ] SPA_SYSTEM/API_SYSTEM/CLASSIFY_SYSTEM 각각의 핵심 하드제약 문구 존재
      테스트 추가
- [ ] `cd engine && uv run pytest tests/test_prompts.py -q` 통과
