# issue-33: test_fix_template_formats_with_error가 FIX_TEMPLATE 본문 문구 회귀를 못 잡음 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`engine/tests/test_prompts.py:15-17`의 `test_fix_template_formats_with_error`는
`FIX_TEMPLATE.format(error="x")` 결과에 `"x"`가 포함되는지만 확인한다.
"Return the corrected COMPLETE file. Same hard constraints as before." 같은
본문 핵심 문장이 삭제돼도 이 테스트는 통과한다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 2, good-to-fix).

## 검토 포인트
- `format()` 결과에 핵심 문장("Same hard constraints as before" 등) 포함
  여부를 검증하는 assert 추가

## 권장 구현(가이드)
```python
def test_fix_template_formats_with_error():
    result = FIX_TEMPLATE.format(error="x")
    assert "x" in result
    assert "Same hard constraints as before" in result
```

## 완료 조건(승격 후)
- [ ] FIX_TEMPLATE 본문 핵심 문장 포함 여부 assert 추가
- [ ] `cd engine && uv run pytest tests/test_prompts.py -q` 통과
