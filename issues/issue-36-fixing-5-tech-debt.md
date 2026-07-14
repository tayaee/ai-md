# issue-36: FIX_TEMPLATE의 {error} 플레이스홀더가 caller 구현 시 프롬프트 인젝션 표면이 될 수 있음 (good-to-fix, 설계 메모)

## 상태


## 의존성
issue-5 완료 후, caller(향후 compiler/llm 이슈) 구현 시 재평가 필요

## 배경
`engine/aimd/prompts.py:31-36`의 `FIX_TEMPLATE`은 `{error}` 자리에 검증 에러
텍스트를 그대로 삽입한다. caller가 `traceback.format_exc()`나 예외 메시지를
가공 없이 채워 넣을 경우, 사용자가 spec에 주입한 임의 텍스트가 다음 LLM
호출에 "검증 에러"로 위장되어 전달될 수 있다 (OWASP LLM01 Prompt Injection
패턴). 현재는 caller가 구현되지 않아 실제 발현 여부는 검증 불가한
이론적/설계 표면이다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 5, 리뷰어 자체 표기 `must-consider` — 현재는 설계 메모로 good-to-fix
파킹, caller 구현 이슈에서 재평가 필요).

## 검토 포인트
- caller(예: compiler.py, issue-8)가 `{error}`에 어떤 문자열을 채우는지
  확인 — `str(SyntaxError)`처럼 소스 미포함인지, `traceback.format_exc()`
  처럼 소스 포함인지가 핵심
- 소스/사용자 원문이 섞일 가능성이 있다면 caller 측에서 정제 단계 필요

## 권장 구현(가이드)
caller 구현 이슈(issue-8 compiler 등)에서 `{error}`에 채워 넣는 문자열을
`str(exception)` 수준으로 제한하고, spec 원문이나 LLM 원본 출력 전체를
그대로 넣지 않도록 명시.

## 완료 조건(승격 후)
- [ ] caller 구현 코드에서 `{error}`에 들어가는 문자열의 출처 확인
- [ ] 필요 시 정제/escape 로직 추가 및 테스트
