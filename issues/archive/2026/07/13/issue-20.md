# issue-20: atomic_write 호출 시 부모 디렉토리 부재 대응 (fixing issue-3)

## 의존성
issue-3 완료 후

## 계보
- **원본 이슈**: issue-3 (artifacts.py — 경로 매핑·신선도 판정·원자적 쓰기)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-3__TYPE-code-review__BY-sonnet.md` (Finding 1)
- **인용**: "타겟 경로(`path`)의 부모 디렉토리(`dir_path`)가 아직 디스크에 만들어지지 않았거나 실수로 삭제된 상태일 때, `tempfile.mkstemp(dir=...)`는 부모 폴더가 없다는 이유로 `FileNotFoundError` 예외를 발생시키며 즉시 중단됨."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 심각도는 리뷰어 제안(good-to-fix)을 그대로 채택.

## 목표
`engine/aimd/artifacts.py`의 `atomic_write` 함수에서 타겟 경로의 부모 디렉토리가 없는 경우에도 안전하게 디렉토리를 생성하고 쓰기를 성공할 수 있도록 내결함성을 높인다.

## 배경
- 아티팩트 저장소로 설정된 `dist/` 내의 특정 디렉토리 구조가 아직 물리적으로 생성되지 않았을 때 원자적 쓰기가 작동하지 않는 문제를 방지한다.

## 구현 상세
`engine/aimd/artifacts.py` 내의 `atomic_write` 함수를 수정한다:
- `tempfile.mkstemp`를 호출하기 전에 타겟 경로의 부모 디렉토리를 `mkdir(parents=True, exist_ok=True)`를 통해 생성해 둔다.

## 하지 말 것
- 원자적으로 쓰기를 수행하고 기존 파일을 덮어쓰며, 실패 시 임시 파일을 unlink하는 기존 코어 메커니즘을 훼손하지 않는다.

## 완료 조건
- [ ] 부모 디렉토리가 존재하지 않는 새 경로를 `atomic_write`에 넘겨줬을 때, 정상적으로 디렉토리가 생성되고 파일이 쓰여지는지 테스트로 검증함
- 검증 명령: `cd engine && python -m pytest tests/test_artifacts.py -q` (기존 테스트 통과 유지)

## 구현 결과
- **구현 완료 일시**: 2026-07-13T23:04:00Z
- **변경 파일**:
  - `engine/aimd/artifacts.py` — `atomic_write`가 `tempfile.mkstemp` 호출 전 `dir_path.mkdir(parents=True, exist_ok=True)`로 부모 디렉토리 자동 생성. docstring에 의도 명시 추가. 기존 `mkstemp` + `os.replace` + 실패 시 tmp unlink 코어 메커니즘 그대로 보존
  - `engine/tests/test_artifacts.py` — `test_atomic_write_creates_missing_parent` 케이스 추가 (nested 2-depth 부재 부모 → 자동 생성 + 쓰기 성공 검증)
  - `regression-tests/verify-issue-20.sh` — 신설, 본 이슈 회귀 보호 스크립트 (mkdir 가드 존재 + 코어 메커니즘 보존 + pytest 통과)
  - `issues/issue-20.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 없음 — 이슈가 명시한 `mkdir(parents=True, exist_ok=True)` 패턴 그대로. 기존 docstring은 이 결정을 "명세에 충실합시다"라며 보류했는데 본 이슈가 그 명세를 정정함.
- **검증 결과**:
  - `uv run pytest tests/test_artifacts.py -q` (engine/) → **8 passed** (기존 7 + 신규 1)
  - `bash regression-tests/verify-issue-20.sh` → **OK**
    - mkdir(parents=True, exist_ok=True) 가드 존재 ✓
    - mkstemp + os.replace + unlink 코어 메커니즘 보존 ✓
    - pytest 8 passed ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 16개) → **모두 통과** (20 새로 포함)
