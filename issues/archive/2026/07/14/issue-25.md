# issue-25: extract_code — 닫히지 않은 펜스(LLM 잘림 출력)에서 마커 노출 (good-to-fix)

## 상태


## 의존성
issue-4 완료 후

## 배경
LLM이 토큰 한도에서 잘려 ```` ```python\nprint(1) ```` 처럼 여는 펜스만 남긴 경우
`_FENCE_RE.findall`은 매칭이 없어 raw 텍스트를 strip해 반환한다. 반환 문자열 안에
```` ```python ```` 마커가 그대로 남아 다음 단계(`validate_html`의 "markdown fence
not stripped", `validate_python`의 SyntaxError)에서 잘못된 에러를 유발한다.

리뷰 출처: `issues/issue-4__TYPE-code-review__BY-sonnet.md` (Finding 2, good-to-fix).

## 검토 포인트
- 현재 동작은 "펜스가 열렸지만 닫히지 않음" 케이스를 구분하지 않음
- 호출자 파이프라인이 어떤 검증을 먼저 호출하느냐에 따라 결과가 달라짐 — 명세에
  그 순서가 정의되어 있지 않음
- 두 가지 정책 중 선택:
  1. **엄격**: 미닫힌 펜스는 별도 sentinel 반환 (`return None` 또는 예외)
  2. **관대**: 그대로 strip해서 반환하고 호출자가 `validate_html`의 fence 검출에 의존
- 옵션 1이 명시적이지만 spec 변경이 큼. 옵션 2는 spec 그대로지만 호출자가 책임.

## 권장 구현(가이드)
- 옵션 1 선택 시: `extract_code` 가 미닫힌 펜스를 감지하면 `None` 또는
  `Literal[""]` 반환 — 호출자가 명시적으로 처리 가능
- 옵션 2 선택 시: 현재 동작 유지 + spec에 "미닫힌 펜스는 호출자 책임" 명시

## 완료 조건(승격 후)
- [x] 미닫힌 펜스 처리 정책 명문화
- [x] 기존 15개 테스트 회귀 없음

## 구현 결과
- **구현 완료 일시**: 2026-07-14T00:39:00-04:00
- **선택한 정책**: 검토 포인트의 옵션 1/2 중 어느 쪽도 그대로 택하지 않고,
  둘의 절충안을 채택 — `extract_code`의 반환 타입은 `str`로 유지하되(옵션 2처럼
  spec 파괴 없음), 미닫힌 펜스를 감지하면 마커 라인만 잘라내고 그 뒤 텍스트를
  코드로 반환한다(옵션 1의 "명시적으로 구분해서 처리"라는 취지는 살림). 이로써
  `validate_python`의 `ast.parse`가 더 이상 마커 자체 때문에 SyntaxError를
  내지 않고, 실제 코드 완결성만을 반영한 에러를 낸다.
- **변경 파일**:
  - `engine/aimd/validators.py` — `_UNCLOSED_FENCE_RE` 정규식 추가.
    `extract_code`가 닫힌 3/4-backtick 매칭에 모두 실패하면 이 fallback으로
    미닫힌 여는 펜스 라인을 찾아 그 라인만 제거하고 나머지를 코드로 반환.
    매칭 자체가 없으면 기존처럼 전체를 strip. docstring에 정책 명문화.
  - `engine/tests/test_validators.py` — `test_extract_code_unclosed_fence_strips_marker`,
    `test_extract_code_unclosed_fence_no_language_tag`,
    `test_extract_code_unclosed_4backtick_fence_strips_marker` 추가 (3개)
  - `regression-tests/verify-issue-25.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `regression-tests/verify-issue-24.sh` — 2번 체크를 고정 `-A20` 줄-윈도우
    판정에서 `_4FENCE_RE.findall`/`_FENCE_RE.findall` 등장 순서 판정으로 변경
    (아래 편차 참고)
  - `regression-tests/verify-issue-24.conflict-with-25.md` — 신설, 위 변경의 배경 기록
  - `issues/issue-25__TYPE-agent-stats.json` — 신설, 계측 데이터
- **계획 대비 차이**: `verify-issue-24.sh`가 본 이슈의 docstring 확장으로 인해
  거짓 FAIL을 내는 것을 발견 — 원인은 그 스크립트의 "def 선언 후 20줄 이내"라는
  고정 윈도우 가정이 낡아진 것(회귀 아님). 순서 기반 판정으로 교체해 향후 유사한
  docstring 성장에도 견고하게 만들었다. 세부 내용은
  `regression-tests/verify-issue-24.conflict-with-25.md` 참고.
- **알려진 한계**: 미닫힌 펜스가 여는 마커 라인 자체(개행 포함)까지도 잘려서
  들어온 극단적인 경우(예: `` "```python" `` 로 텍스트가 끝나고 개행조차 없는
  경우)는 매칭되지 않아 기존처럼 raw 텍스트가 그대로(마커 포함) 반환된다 — 이
  경우 추출할 코드 자체가 없으므로 다운스트림 검증(`validate_python`)이 정확히
  실패하는 것이 맞는 동작이라 별도 처리하지 않았다.
- **검증 결과**:
  - `uv run pytest tests/test_validators.py -q` (engine/) → **24 passed** (기존 21 + 신규 3)
  - `uv run pytest -q` (engine/) → 1 failed(무관, `test_create_app_returns_dispatcher_instance` —
    WSL 환경의 inotify 파일감시 한계로 인한 기존 실패, 본 변경 이전에도 동일하게 실패함
    확인) + 83 passed
  - `uv run python -m compileall . -q` (engine/) → OK
  - `bash regression-tests/verify-issue-25.sh` → **OK**
  - `bash regression-tests/verify-issue-*.sh` 전체(29개) 재실행 → 전부 OK
    (verify-issue-24.sh는 위 편차 반영 수정 후 OK)
  - ruff/pyright: 이 프로젝트는 `pyproject.toml`이 없어(issue-24와 동일 컨벤션)
    미실행