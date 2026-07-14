# issue-8 refix-plan

리뷰 파일: `issues/issue-8__TYPE-code-review__BY-gemini.md`,
`issues/issue-8__TYPE-code-review__BY-minimax.md` (둘 다 정상 수신, 누락 없음)

## 1. 리뷰어별 finding 수

| 리뷰어 | finding 수 | 형식 게이트 reject | must-fix (재검증 후) | good-to-fix |
|---|---|---|---|---|
| gemini | 5 | 0 | 2 | 3 |
| minimax | 2 | 0 | 0 | 2 |

## 2. 형식 게이트

모든 finding이 3요소(파일:라인+코드 인용 / 실패 시나리오 / 확인 방법)를 갖춤
— reject 없음.

## 3. 분류 결과

### must-fix (재검증 완료, 승격 확정)

| # | 원본 finding | 재검증 | 파생 이슈 |
|---|---|---|---|
| 1 | gemini Finding 1 — atomic_write 실패 시 반대 확장자 아티팩트가 이미 삭제되어 캐시 완전 유실 | 실행 재현 확인 (OSError 주입 → dist 완전히 빔) | `issue-43-fixing-8-atomic-write-failure-loses-existing-artifact__BY-gemini.md` |
| 2 | gemini Finding 3 — `_import_gate`가 `except Exception`만 잡아 `SystemExit` 등 `BaseException`이 재시도 없이 프로세스로 전파 | 실행 재현 확인 (`sys.exit(99)` 반환 코드 → `SystemExit` 전파) | `issue-44-fixing-8-system-exit-bypasses-retry-crashes-process__BY-gemini.md` |

### good-to-fix (파킹)

| # | 원본 finding | 비고 | 파생 이슈 |
|---|---|---|---|
| 1 | gemini Finding 2 (RCE, must-fix로 제안) + minimax Finding 1 (동일 근본 원인, good-to-fix로 제안) — 중복 finding, 1개만 생성 | gemini의 must-fix 제안을 재검증 과정에서 good-to-fix로 강등: ADR-0004/ADR-0008이 채택한 기존 아키텍처 결정이며 issue-8이 새로 도입한 결함이 아님(README에 이미 경고 문구 존재), minimax도 독립적으로 good-to-fix로 판단 | `issue-45-fixing-8-unsandboxed-llm-code-execution-rce-risk__STATE-later__BY-gemini-minimax.md` |
| 2 | gemini Finding 4 — `_locks` dict 무제한 누적(메모리 누수) | 리뷰어 자체 good-to-fix 제안, 재검증 생략 | `issue-46-fixing-8-locks-dict-unbounded-growth__STATE-later__BY-gemini.md` |
| 3 | gemini Finding 5 — 임시 `.py` import 시 `__pycache__` 잔여물 미정리 | 리뷰어 자체 good-to-fix 제안, 재검증 생략 | `issue-47-fixing-8-tmp-pycache-accumulation-on-import-validation__STATE-later__BY-gemini.md` |
| 4 | minimax Finding 2 — `_import_gate`의 fd 누수 가능성(write 실패 경로) | 리뷰어 자체 good-to-fix 제안, 재검증 생략 | `issue-48-fixing-8-import-gate-fd-leak-on-write-failure__STATE-later__BY-minimax.md` |

### reject

없음 (모든 finding이 형식 게이트를 통과했고, must-fix 제안 1건만 재검증
결과 good-to-fix로 강등되었을 뿐 완전 기각된 finding은 없음).

## 4. 생성된 파생 이슈 목록

- `issue-43-fixing-8-atomic-write-failure-loses-existing-artifact__BY-gemini.md` (must-fix)
- `issue-44-fixing-8-system-exit-bypasses-retry-crashes-process__BY-gemini.md` (must-fix)
- `issue-45-fixing-8-unsandboxed-llm-code-execution-rce-risk__STATE-later__BY-gemini-minimax.md` (good-to-fix, 파킹)
- `issue-46-fixing-8-locks-dict-unbounded-growth__STATE-later__BY-gemini.md` (good-to-fix, 파킹)
- `issue-47-fixing-8-tmp-pycache-accumulation-on-import-validation__STATE-later__BY-gemini.md` (good-to-fix, 파킹)
- `issue-48-fixing-8-import-gate-fd-leak-on-write-failure__STATE-later__BY-minimax.md` (good-to-fix, 파킹)

Step 4(코더 재수정)는 태그 없는 pending 파생 이슈(`issue-43`, `issue-44`)만
처리한다. `__STATE-later` 파생 이슈(`issue-45`~`issue-48`)는 사람이 STATE
태그를 지울 때까지 건드리지 않는다.
