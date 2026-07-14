# ADR-0006: MiniMax 연동 규격 — 현행 값 + 전면 환경 변수화

상태: 승인 (2026-07-12)

## 맥락

초안의 `https://api.minimax.chat/v1`은 구 엔드포인트, `abab6.5-chat`은 단종 모델이다.
2026-07 조사 결과: 현행 글로벌 OpenAI-호환 베이스 URL은 `https://api.minimax.io/v1`,
코딩·에이전트 특화 최신 모델은 `MiniMax-M3`. 사용자는 글로벌(minimax.io) 개인 키 사용.

## 결정

코드에 아무것도 하드코딩하지 않고 환경 변수로 전부 주입한다:

- `LLM_API_KEY` (필수, 기본값 없음)
- `LLM_BASE_URL` (기본 `https://api.minimax.io/v1`)
- `LLM_MODEL` (기본 `MiniMax-M3`)
- `LLM_MAX_TOKENS` (기본 `200000`)

`max_tokens`는 **출력 토큰 상한**이다(컨텍스트 윈도우 아님). 모델별 출력 상한이
별도로 낮게 걸린 경우 API가 400을 반환하므로, **값을 절반으로 줄여 재시도**
(최대 6회, 하한 4096)하는 클램프 로직을 넣는다. 어떤 상한이 걸려 있어도
항상 모델의 실질 최대 출력으로 동작한다.

`temperature=0.0` 고정(결정론). 클라이언트는 OpenAI 공식 Python SDK.

## 결과

- 모델 교체나 다른 OpenAI-호환 프로바이더(로컬 vLLM 등) 전환 시 코드 수정 0.
- 파일 잘림(초안이 금지)은 200k 상한 + 클램프로 방지.
