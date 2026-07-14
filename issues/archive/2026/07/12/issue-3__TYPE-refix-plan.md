# issue-3 refix-plan

## 입력
- 리뷰어: minimax (1/1, 실패 없음), sonnet (1/1, 실패 없음)
- 리뷰 파일:
  - `issues/issue-3__TYPE-code-review__BY-minimax.md`
  - `issues/issue-3__TYPE-code-review__BY-sonnet.md`

## 리뷰어별 finding 수
| 리뷰어 | finding 수 |
|---|---|
| minimax | 1 |
| sonnet | 1 |

## 형식 게이트
전 2건 통과 — 각 finding이 파일:라인+코드 인용 / 실패 시나리오 / 확인 방법 3요소를 모두 갖춤. gate reject 없음.

## 분류
| ID | 요약 | 리뷰어 제안 | 최종 분류 | 사유 |
|---|---|---|---|---|
| F1 | list_specs:65 src_dir이 디렉토리가 아닐 경우 크래시 | good-to-fix | good-to-fix | 환경적 엣지 케이스이며 기존 기능 사양에는 디렉토리 외 체크 예외 조항 없음 |
| F2 | atomic_write:48 부모 디렉토리가 없으면 FileNotFoundError | good-to-fix | good-to-fix | 원자적 쓰기 환경의 내결함성 개선 사항으로, 심각한 기능 오작동은 아님 |

**must-fix 0건 → Step 3.4 실질 재검증 생략** (승격 후보 없음).

## reject 사유
음 (게이트 reject, 재검증 reject 모두 0건).

## 생성된 파생 이슈 (전부 __STATE-later 파킹)
| 파생 이슈 | 출처 finding | 상태 |
|---|---|---|
| `issues/issue-19-fixing-3__STATE-later.md` | F1 | 파킹 (사람이 STATE 태그 제거 시 승격) |
| `issues/issue-20-fixing-3__STATE-later.md` | F2 | 파킹 |

채번 근거: 파생 이슈 생성 직전 `issues/` + `issues/archive/` 전체에서 확인한 기존 최대 번호는 18 → 19부터 순차 채번.

## Step 4 처리 대상
pending(태그 없는) 파생 이슈 없음 — 전부 `__STATE-later`로 파킹되어 이번 Step 4에서는 `/autotdd` 대상이 없다. Step 4는 리뷰 산출물 아카이빙만 수행한다.
