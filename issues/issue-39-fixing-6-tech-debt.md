# issue-39: llm.chat — 토큰 한도 에러 문자열 대소문자 미구분 매칭 (good-to-fix)

## 상태


## 의존성
issue-6 완료 후

## 배경
`engine/aimd/llm.py:46-47`의 `("max_tokens" not in message and "token" not
in message)` 판정은 소문자만 매칭한다. API가
`"Error: Max_Tokens exceeded"`처럼 대소문자가 섞인 메시지를 반환하면
토큰 관련 에러인데도 재시도 없이 즉시 전파된다.

리뷰 출처: `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-gemini.md`
(Finding 2, good-to-fix).

## 검토 포인트
- issue-6.md 스펙 원문이 "에러 문자열에 max_tokens 또는 token이 포함되면"
  이라고 소문자로만 표기하고 있어, 대소문자 구분이 의도된 것인지 단순
  표기 관례인지 spec 저자에게 확인 필요
- 반대 의견(플래너 재검증 시 확보): minimax 리뷰는 "스펙이 소문자
  부분일치를 명시적으로 요구하므로 구현이 스펙을 그대로 따른 것"이라고
  보고 이 finding을 채택하지 않았음 — 승격 여부 결정 시 이 반론도 함께
  검토할 것

## 권장 구현(가이드)
승격한다면 `message.lower()` 기준으로 판정:
```python
lowered = message.lower()
if "max_tokens" not in lowered and "token" not in lowered:
    raise
```

## 완료 조건(승격 후)
- [ ] 대소문자 혼용 토큰 에러 메시지에서도 재시도 발생 확인
- [ ] `cd engine && uv run pytest tests/test_llm.py -q` 통과
