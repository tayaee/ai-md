# issue-5 refix plan

## 리뷰어별 finding 수

| 리뷰어 | 모델 | 총 finding | 형식 게이트 통과 | must-fix (승격) | good-to-fix | reject |
|---|---|---|---|---|---|---|
| gemini | Gemini 3.5 Flash (Medium) | 4 | 4 | 0 | 4 | 0 |
| minimax | MiniMax-M3 | 6 | 6 | 0 | 6 | 0 |
| **합계** | | **10** | **10** | **0** | **10** | **0** |

## reject 사유

없음 — 형식 게이트를 통과하지 못한 finding도, gate reject된 finding도 없다.

## 재검증 실패로 강등된 must-fix 후보

| finding | 출처 | 원래 제안 | 재검증 결과 | 강등 사유 |
|---|---|---|---|---|
| verify-issue-5.sh 상대경로 CWD 의존 | gemini F1 | must-fix | good-to-fix로 강등 | 인용·주장 모두 성립하나, 전 회귀 스크립트(1~22)에 공통된 기존 관행이며 실제 호출 경로(`acpd`/`autotdd`, 항상 저장소 루트에서 실행)에서는 발현하지 않음. 무인 `/autotdd` 풀사이클을 발동할 정도의 실질 리스크가 아니라고 판단. → `issue-28-fixing-5__STATE-later.md` |

## 분류 결과

### must-fix (승격, pending 파생 이슈)

없음 — 이번 사이클에서 must-fix로 승격된 finding 없음.

### good-to-fix (파킹, STATE-later)

1. **verify-issue-5.sh 상대경로 CWD 의존** (gemini F1, 재검증 후 강등) → `issue-28-fixing-5__STATE-later.md`
2. **subshell `(exit 1)`이 `set -e` 무력화 시 우회 가능** (gemini F2) → `issue-29-fixing-5__STATE-later.md`
3. **`uv run pytest`가 spec의 `python -m pytest`와 불일치** (gemini F3) → `issue-30-fixing-5__STATE-later.md`
4. **구현 완료 일시 기재 오차** (gemini F4) → `issue-31-fixing-5__STATE-later.md`
5. **하드제약 문구 삭제 회귀를 테스트가 못 잡음** (minimax F1) → `issue-32-fixing-5__STATE-later.md`
6. **FIX_TEMPLATE 본문 문구 회귀를 테스트가 못 잡음** (minimax F2) → `issue-33-fixing-5__STATE-later.md`
7. **grep이 `async def`/들여쓴 정의를 누락** (minimax F3) → `issue-34-fixing-5__STATE-later.md`
8. **grep이 주석·접두어까지 과매칭** (minimax F4) → `issue-35-fixing-5__STATE-later.md`
9. **`{error}` 플레이스홀더의 잠재적 프롬프트 인젝션 표면** (minimax F5, `must-consider`) → `issue-36-fixing-5__STATE-later.md`
10. **`FIX_TEMPLATE`의 SPA/API 컨텍스트 모호성** (minimax F6) → `issue-37-fixing-5__STATE-later.md`

## 생성된 파생 이슈 목록

| 번호 | 파일 | 분류 | 비고 |
|---|---|---|---|
| 28 | `issues/issue-28-fixing-5__STATE-later.md` | later | CWD 의존 (재검증 강등) |
| 29 | `issues/issue-29-fixing-5__STATE-later.md` | later | subshell exit 우회 |
| 30 | `issues/issue-30-fixing-5__STATE-later.md` | later | uv run vs spec 불일치 |
| 31 | `issues/issue-31-fixing-5__STATE-later.md` | later | 타임스탬프 오차 |
| 32 | `issues/issue-32-fixing-5__STATE-later.md` | later | 하드제약 회귀 미검출 |
| 33 | `issues/issue-33-fixing-5__STATE-later.md` | later | FIX_TEMPLATE 본문 회귀 미검출 |
| 34 | `issues/issue-34-fixing-5__STATE-later.md` | later | grep async def 누락 |
| 35 | `issues/issue-35-fixing-5__STATE-later.md` | later | grep 과매칭 |
| 36 | `issues/issue-36-fixing-5__STATE-later.md` | later | 프롬프트 인젝션 설계 메모 |
| 37 | `issues/issue-37-fixing-5__STATE-later.md` | later | SPA/API 모호성 설계 메모 |

## 정상 판정 항목 (재차 확인)

- `engine/aimd/prompts.py`의 4개 상수는 issue-5.md 명세 코드 블록과 `diff` 결과 완전 일치(verbatim).
- `FIX_TEMPLATE.format(error="...{evil}...")` — 값에 포함된 `{}`는 치환 대상이 아니므로 안전(둘 다 리뷰어가 직접 실행해 확인).
- `SPA_SYSTEM`에 "HTML" 포함, `API_SYSTEM`에 "FastAPI" 포함 — spec 요구사항 충족.
- 함수·클래스 추가 없음(파일이 상수 4개로만 구성) — 두 리뷰어 모두 확인.
