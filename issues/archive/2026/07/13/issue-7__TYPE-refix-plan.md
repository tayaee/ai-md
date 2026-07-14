# issue-7 refix-plan

## 리뷰어 요약

| 리뷰어 | 모델 | finding 수 | gate_rejected | verify_rejected | must_fix | good_to_fix |
|---|---|---|---|---|---|---|
| sonnet | Claude Sonnet 5 (claude-sonnet-5) | 6 | 0 | 0 | 0 | 6 |
| gemini | Gemini 3.5 Flash (gemini-3.5-flash) | 5 | 0 | 1 | 1 | 4 |

## 형식 게이트

모든 finding(11건)이 파일:라인 + 코드 인용 + 실패 시나리오 + 확인 방법 3요소를 충족. gate_rejected = 0.

## 실질 재검증 (must-fix 한정)

### G1 — `classify` 로그 형식이 spec docstring 단일 형식과 다름 (must-fix 승격)

- **리뷰어**: gemini (Finding 1)
- **파일:라인 인용 실재 확인**: `engine/aimd/classifier.py:42-49` — 로그 두 분기 모두 실재. ✓
- **Spec docstring 인용 실재 확인**: `issues/archive/2026/07/13/issue-7-add-classifier.md` 의 `classify` docstring은 `"LLM classification failed, falling back to keywords: %s"` 단일 형식을 명시. ✓
- **주장 성립 확인**: 구현은 "unexpected answer %r" 분기와 "failed: %s" 분기로 로그 형식이 두 갈래. spec docstring은 단일 형식만 명세하므로 deviation. ✓
- **판정**: **must-fix 승격**. 파생 이슈 `issue-42-fixing-7-log-format-spec-deviation__BY-gemini.md` 생성.

## 중복 finding 처리 (issue-44)

| finding 쌍 | 결함 | 영향 |
|---|---|---|
| S1 = G2 | strict `==` 매칭이 모델 출력 부호에 취약 | 두 리뷰어 stats good_to_fix +1씩. 파생 이슈 미생성 (good-to-fix는 파킹). |
| S4 = G4 | 모듈 레벨 가변 `list` | 두 리뷰어 stats good_to_fix +1씩. 파생 이슈 미생성. |

나머지 finding들은 단일 리뷰어 발견.

## good-to-fix 분류 (파킹, `__STATE-later` 미부여 — 이 파일들에 별도 STATE 태그를 붙이지 않음)

good-to-fix finding은 Step 4에서 처리하지 않음 — 사람이 STATE 태그를 지워 승격할 때까지 대기. 현재 사이클에서 파생 이슈로 생성되지 않은 finding:

| ID | 리뷰어 | finding | 파일:라인 |
|---|---|---|---|
| S1 / G2 | sonnet, gemini | strict `==` 매칭이 부호에 취약 | classifier.py:38-41 |
| S2 | sonnet | `classify`의 `"API"` 분기 직접 테스트 부재 | test_classifier.py |
| S3 | sonnet | `classify_by_keywords(None)` → AttributeError | classifier.py:20-25 |
| S4 / G4 | sonnet, gemini | 모듈 레벨 가변 `list` | classifier.py:12-13 |
| S5 | sonnet | verify-issue-7.sh가 production `llm.chat` 호출을 grep으로 직접 가드하지 않음 | verify-issue-7.sh:16-18 |
| S6 | sonnet | agent-stats.json `loc_added: 0`이 사실과 다름 | issue-7__TYPE-agent-stats.json:9 |
| G3 | gemini | 소문자 키워드 카운팅 누락 | classifier.py:16-17, 23-24 |
| G5 | gemini | 프롬프트 인젝션 (OWASP LLM01) | classifier.py:36 |

## reject 사유 요약

| 사유 | 건수 |
|---|---|
| 증거 미비 (형식 게이트) | 0 |
| 재검증 실패 (must-fix 한정) | 0 |

## 생성된 파생 이슈

| 파일명 | 원본 | finding | BY |
|---|---|---|---|
| `issue-42-fixing-7-log-format-spec-deviation__BY-gemini.md` | issue-7 | G1 (로그 형식 spec deviation) | gemini |

## review_outcome (Step 4를 위한 카운터)

- `coders.minimax.review_outcome`:
  - refix_plans_written: 1 (이 파일 작성)
  - findings_received: 0 (minimax는 reviewer가 아님)
  - must_fix_count: 0 (minimax의 finding 중 must-fix로 승격된 건수)
  - good_to_fix_count: 0
- `reviewers.gemini.must_fix`: 1 (G1 → issue-42 생성)
- `reviewers.gemini.good_to_fix`: 4 (G2, G3, G4, G5)
- `reviewers.sonnet.must_fix`: 0
- `reviewers.sonnet.good_to_fix`: 6 (S1~S6)
- `derived_by_reviewers`: [`issue-42-fixing-7-log-format-spec-deviation__BY-gemini.md`]