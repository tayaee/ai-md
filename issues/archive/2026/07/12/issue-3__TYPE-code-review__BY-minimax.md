---
model: MiniMax-M3
---

# issue-3 코드 리뷰

- **리뷰 대상 커밋**: `2ab8c2a`
- **리뷰어 모델**: MiniMax-M3
- **리뷰 일시**: 2026-07-12
- **리뷰 범위**: `engine/aimd/artifacts.py`, `engine/tests/test_artifacts.py`, `regression-tests/verify-issue-3.sh`
- **회귀 스크립트 실행 결과**: `regression-tests/verify-issue-3.sh` → `OK` (정상 통과 확인)
- **전제**: 본 모듈은 파일시스템에 직접 접근하는 순수 I/O 컴포넌트이며, 비동기 호출이나 LLM 접근은 없다.

---

## 종합 평가

`engine/aimd/artifacts.py` 및 관련 테스트가 매우 깔끔하고 명확하게 구현되었습니다. `is_stale`에서 아티팩트의 부재 여부 체크, mtime 비교, `os.utime`을 이용한 시뮬레이션 등이 충실하게 구성되었으며, `list_specs`에서의 파일 필터링 규칙도 잘 동작합니다.

다만, `list_specs` 함수가 `src_dir`의 상태를 검사할 때 존재성(`exists()`)만 체크하고 있어, 비정상적인 환경(예: 디렉토리가 아닌 파일이 지정되거나 권한 오류 등)에서 에러가 전파될 수 있는 아쉬움이 있습니다.

---

## Finding 1 — list_specs에서 src_dir이 디렉토리가 아니거나 접근 권한이 없을 때 크래시 위험

| 항목 | 내용 |
|---|---|
| 파일:라인 | `engine/aimd/artifacts.py:65` (list_specs 함수 내) |
| 코드 인용 | ```python
def list_specs(settings: Settings) -> list[str]:
    """src_dir의 *.ai.md 파일명 목록(정렬). 하위 디렉토리는 보지 않는다."""
    if not settings.src_dir.exists():
        return []
    names = [p.name for p in settings.src_dir.iterdir() if p.is_file() and p.name.endswith(".ai.md")]
    return sorted(names)
``` |
| 실패 시나리오 | `settings.src_dir`이 실제로 디렉토리가 아닌 일반 파일이거나, 읽기 권한이 없는 디렉토리일 경우 `iterdir()` 호출은 각각 `NotADirectoryError` 또는 `PermissionError`를 던지며 크래시가 발생함. |
| 확인 방법 | 테스트에서 `settings.src_dir`을 파일 경로로 재지정한 뒤 `list_specs(settings)`를 호출하여 예외가 상위로 전파되는 것을 확인. |
| 심각도 제안 | good-to-fix (안정성 강화) |

**수정 제안**: 존재 여부(`exists()`) 외에도 `is_dir()` 여부를 함께 체크하거나, `iterdir()` 호출부를 `try-except OSError`로 감싸서 예외 발생 시 빈 리스트 `[]`를 반환하도록 보완.
