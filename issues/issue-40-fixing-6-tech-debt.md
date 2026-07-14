# issue-40: llm.chat — response.choices가 빈 리스트일 때 IndexError가 무방비로 노출됨 (good-to-fix)

## 상태


## 의존성
issue-6 완료 후

## 배경
`engine/aimd/llm.py:53`의 `content = response.choices[0].message.content`는
`response.choices`가 빈 리스트인 경우(API 내부 필터링/비정상 응답 등)
`IndexError`를 그대로 노출한다. 같은 함수가 `content is None`인 경우는
`RuntimeError("empty LLM response")`로 변환하면서, `choices=[]`인 경우만
방어되지 않는 비대칭이 있다.

리뷰 출처:
- `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-gemini.md` (Finding 3, good-to-fix)
- `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-minimax.md` (Finding 2, good-to-fix — 동일 결함 독립 발견)

두 리뷰어 모두 같은 결함을 독립적으로 발견했다 (중복 finding 규칙 적용,
파생 이슈는 1개만 생성).

## 검토 포인트
- 실제 MiniMax API에서 빈 choices가 실무적으로 얼마나 자주 발생하는지는
  두 리뷰어 모두 확인하지 못함(이론적 방어 코드 제안)
- `content is None` 케이스와 동일하게 `RuntimeError("empty LLM response")`로
  통일하는 것이 자연스러움

## 권장 구현(가이드)
```python
if not response.choices:
    raise RuntimeError("empty LLM response")
content = response.choices[0].message.content
if content is None:
    raise RuntimeError("empty LLM response")
```

## 완료 조건(승격 후)
- [ ] `response.choices == []`인 경우 `IndexError` 대신 `RuntimeError("empty LLM response")` 발생
- [ ] 기존 `content is None` 케이스 회귀 없음
- [ ] `cd engine && uv run pytest tests/test_llm.py -q` 통과
