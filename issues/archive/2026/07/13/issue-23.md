# issue-23: extract_code rstrip 동작의 의도 명세화 (good-to-fix)

## 의존성
issue-4 완료 후

## 구현 결과
- **구현 완료 일시**: 2026-07-13T23:10:05Z
- **변경 파일**:
  - `engine/aimd/validators.py` — `extract_code` docstring에 trailing-newline 정책 명시 추가 (rstrip 동작 유지, 손실 의식적 명세화)
  - `engine/tests/test_validators.py` — `test_extract_code_strips_all_trailing_newlines` 추가 — 단일/다중 trailing newline 모두 제거되는 현재 동작을 pytest로 잠금
  - `issues/archive/2026/07/12/issue-4.md` — spec의 extract_code docstring에 같은 정책 라인 추가
  - `regression-tests/verify-issue-23.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-23.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: **정책 결정은 손실 허용(rstrip 유지)**. 이슈가 제시한 "동작 보존(strip 1개) vs 손실 허용(전체 strip)" 중 손실 허용 쪽을 채택. 이유:
  -1. no-fence 경로의 `strip()` 동작과 일관성을 우선 (현재 구조 유지)
  -2. behavior change를 동반하는 fix는 good-to-fix 범위를 넘음 — 리뷰어의 핵심 요구는 "spec에 명시"였지 "행동 변경"이 아님
  -3. 호출자가 빈 줄 보존이 필요하면 명시적 메커니즘으로 처리 가능 (현재 spec/SA에 그런 요구 없음)
- **검증 결과**:
  - `uv run pytest tests/test_validators.py -q` (engine/) → **19 passed** (기존 17 + 신규 1 + 잠금 테스트 케이스)
  - `bash regression-tests/verify-issue-23.sh` → **OK**
    - extract_code docstring trailing-newline 정책 ✓
    - issue-4 spec에도 같은 정책 반영 ✓
    - `strips_all_trailing_newlines` 잠금 테스트 존재 ✓
    - pytest 통과 ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 17개) → **모두 통과** (23 새로 포함)

## 배경
`engine/aimd/validators.py:21` 의 `max(matches, key=len).rstrip("\n")` 동작은 사소한
손실이 발생할 수 있다. 의도된 단일 trailing newline 제거 vs 사용자가 의도한 trailing
빈 줄 모두 제거 — 두 동작 중 어느 것이 spec인지 명시되어 있지 않다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-gemini.md` (Finding 3, good-to-fix).

## 검토 포인트
- spec(issue-4.md)의 `extract_code` docstring에 "trailing newline strip 여부"를 명시화
- 현재 구현의 `.rstrip("\n")`은 사용자가 의도한 빈 줄까지 제거할 수 있음
- 동작 보존(strip 1개) vs 손실 허용(전체 strip) — 트레이드오프 명시 후 결정

## 권장 구현(가이드)
1. issue-4의 spec을 갱신해 trailing newline 정책 명시
2. `extract_code` docstring에 한 줄 추가
3. 테스트에 `"\n\n"` 끝 케이스를 추가해 동작을 명문화

## 완료 조건(승격 후)
- [ ] spec의 `extract_code` docstring에 trailing newline 정책 명시
- [ ] `cd engine && uv run pytest tests/test_validators.py -q` 통과