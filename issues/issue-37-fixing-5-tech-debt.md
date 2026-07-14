# issue-37: FIX_TEMPLATE의 "Same hard constraints as before" 문구가 SPA/API 컨텍스트를 구분하지 않음 (good-to-fix, 설계 메모)

## 상태


## 의존성
issue-5 완료 후, caller(향후 compiler/llm 이슈) 구현 시 재평가 필요

## 배경
`engine/aimd/prompts.py:34`의 `FIX_TEMPLATE`은
"Return the corrected COMPLETE file. Same hard constraints as before."라는
문구로 이전 턴의 hard constraints를 참조하지만, 어느 hard constraints인지
(SPA_SYSTEM인지 API_SYSTEM인지)를 템플릿 자체는 명시하지 않는다. caller가
stateless하게 호출한다면 LLM이 잘못된 제약(SPA 코드에 FastAPI 제약 등)을
적용할 위험이 이론적으로 있다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 6, good-to-fix — spec 원문 그대로의 wording이라 issue-5 구현 자체의
결함은 아니며, caller/워크플로 설계 이슈에 가까움).

## 검토 포인트
- caller가 SPA_SYSTEM/API_SYSTEM과 함께 대화 컨텍스트를 유지한 채
  FIX_TEMPLATE을 호출하는지(stateful), 아니면 매번 새로 구성하는지
  (stateless) 확인
- stateless라면 `FIX_TEMPLATE`을 분리하거나 `{kind}` placeholder 도입 검토

## 권장 구현(가이드)
caller 설계 시 SPA/API 구분이 필요하면:
```python
FIX_TEMPLATE = (
    "The code you produced failed validation with this error:\n"
    "{error}\n"
    "Return the corrected COMPLETE file. Same hard constraints as for {kind}. "
    "Output ONLY the raw code, no markdown fences, no explanations."
)
```

## 완료 조건(승격 후)
- [ ] caller의 호출 방식(stateful/stateless) 확인
- [ ] 필요 시 FIX_TEMPLATE 분리 또는 `{kind}` 도입 및 테스트
