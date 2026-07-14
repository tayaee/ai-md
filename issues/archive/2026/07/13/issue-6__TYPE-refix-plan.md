# issue-6 refix plan

## 리뷰어별 finding 수

| 리뷰어 | 모델 | 총 finding | 형식 게이트 통과 | must-fix (승격) | good-to-fix | reject |
|---|---|---|---|---|---|---|
| gemini | Gemini 3.5 Flash | 5 | 5 | 1 | 3 | 1 |
| minimax | MiniMax-M3 (claude-opus-4-8, 2025-Q4) | 2 | 2 | 1 | 1 | 0 |
| **합계** | | **7** | **7** | **2건(중복 1건 → 파생 1개)** | **4건(중복 1건 → 파생 3개)** | **1** |

## reject 사유

| finding | 출처 | 사유 |
|---|---|---|
| OpenAI 클라이언트/API 호출 타임아웃 미지정으로 무한 대기 가능 | gemini F5 | 재검증 실패 — `openai.OpenAI(...).timeout`을 직접 확인한 결과 SDK가 기본 `Timeout(connect=5.0, read=600, write=600, pool=600)`을 자동 설정함이 확인됨. "타임아웃 미지정으로 무한 대기 가능"이라는 핵심 주장이 사실과 다름(minimax 리뷰도 동일하게 반박). must-fix가 아닌 good-to-fix 제안이었지만 핵심 사실관계가 틀려 파생 이슈를 생성하지 않고 reject. |

## 실질 재검증 (must-fix)

| finding | 출처 | 재검증 방법 | 결과 |
|---|---|---|---|
| max_tokens 재시도 소진 시 BadRequestError가 RuntimeError로 둔갑 | gemini F1 / minimax F1 (중복 독립 발견) | `settings.max_tokens=524288`로 모든 호출이 실패하는 가짜 클라이언트를 구성해 직접 실행 | 실제 `RuntimeError: empty LLM response` 발생 확인 — 인용·주장 모두 성립. minimax가 정확한 임계값(M≥262208)까지 직접 실행으로 측정해 gemini의 524288 예시보다 더 정밀한 근거 제공. **must-fix로 승격.** |

## 분류 결과

### must-fix (승격, pending 파생 이슈)
1. **max_tokens 재시도 소진 시 BadRequestError → RuntimeError 둔갑** (gemini F1 + minimax F1, 중복) → `issues/issue-38-fixing-6.md`
   - 파일:라인: `engine/aimd/llm.py:37-58`
   - 재검증: 직접 실행으로 확인 (위 표 참조)

### good-to-fix (파킹, STATE-later)
1. **토큰 에러 문자열 대소문자 미구분 매칭** (gemini F2) → `issue-39-fixing-6__STATE-later.md`
   - 비고: minimax는 스펙이 소문자 부분일치를 명시하므로 이 finding을 자신의 리뷰에서는 채택하지 않았음(reject는 아니고 "스펙 준수"로 판단). 승격 여부 판단 시 이 반론도 함께 고려하도록 파생 이슈 본문에 기록.
2. **`response.choices` 빈 리스트 시 IndexError 노출** (gemini F3 + minimax F2, 중복) → `issue-40-fixing-6__STATE-later.md`
3. **매 호출 클라이언트 재생성 (커넥션 풀링 미활용)** (gemini F4) → `issue-41-fixing-6__STATE-later.md`
   - 비고: minimax는 "스펙 외 이슈"로 자신의 finding에서는 다루지 않았으나 기술적으로 유효한 관찰이라 파킹.

## 생성된 파생 이슈 목록

| 번호 | 파일 | 분류 | 비고 |
|---|---|---|---|
| 38 | `issues/issue-38-fixing-6.md` | pending (must-fix) | 재시도 소진 시 예외 둔갑 |
| 39 | `issues/issue-39-fixing-6__STATE-later.md` | later | 대소문자 미구분 |
| 40 | `issues/issue-40-fixing-6__STATE-later.md` | later | 빈 choices IndexError |
| 41 | `issues/issue-41-fixing-6__STATE-later.md` | later | 클라이언트 재생성 |

## 정상 판정 항목 (재차 확인)

- `_make_client`의 매 호출 재생성 자체는 스펙 위반이 아님(minimax) — 다만 good-to-fix로는 유효.
- openai SDK 기본 타임아웃이 존재함 — "무한 대기" 주장은 기각.
- `tokens <= _MIN_TOKENS`의 `<=` 사용은 스펙보다 더 방어적이라 문제 없음(minimax).
- 에러 메시지 소문자 부분일치는 스펙 원문을 그대로 따른 것(minimax 관점) — 다만 good-to-fix로 파킹.
- 동시성: `chat()`은 로컬 변수만 사용해 재진입 안전, 모듈 전역 mutable 상태 없음(minimax).
- 회귀 스크립트 `verify-issue-6.sh`의 openai import 단일 창구 검증 정상 동작.
