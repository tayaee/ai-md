---
model: Claude-3.5-Sonnet
---

# issue-3 코드 리뷰

- **리뷰 대상 커밋**: `2ab8c2a`
- **리뷰어 모델**: Claude-3.5-Sonnet
- **리뷰 일시**: 2026-07-12
- **리뷰 범위**: `engine/aimd/artifacts.py`, `engine/tests/test_artifacts.py`, `regression-tests/verify-issue-3.sh`
- **회귀 스크립트 실행 결과**: `regression-tests/verify-issue-3.sh` → `OK` (정상 통과 확인)
- **전제**: 이 컴포넌트는 오프라인 I/O 처리를 목적으로 설계되었으며, 성능 및 동시성 락을 고려한 안전한 쓰기 메커니즘을 평가한다.

---

## 종합 평가

`engine/aimd/artifacts.py` 모듈은 원자적 교체(`os.replace`) 기법을 안정적으로 구현하여, 동시성 상황이나 비정상 종료 시에도 파일이 깨지는 현상을 방지하도록 정석대로 작성되었습니다. pytest를 활용한 시간 시뮬레이션 및 정리 작업(cleanup) 검증도 우수합니다.

하지만 `atomic_write`에서 임시 파일을 생성하는 대상 부모 디렉토리가 존재하지 않는 시나리오에 대비한 방어적 프로그래밍 측면에서 개선할 수 있는 사각지대가 존재합니다.

---

## Finding 1 — atomic_write 호출 시 부모 디렉토리가 존재하지 않을 때 FileNotFoundError 발생

| 항목 | 내용 |
|---|---|
| 파일:라인 | `engine/aimd/artifacts.py:48` (atomic_write 함수 내) |
| 코드 인용 | ```python
def atomic_write(path: Path, text: str) -> None:
    """같은 디렉토리에 tempfile.mkstemp로 tmp 파일을 만들어 text를 쓰고
    os.replace(tmp, path)로 원자적 교체. 실패 시 tmp 파일 삭제."""
    dir_path = path.parent
    fd, tmp_path = tempfile.mkstemp(dir=str(dir_path))
``` |
| 실패 시나리오 | 타겟 경로(`path`)의 부모 디렉토리(`dir_path`)가 아직 디스크에 만들어지지 않았거나 실수로 삭제된 상태일 때, `tempfile.mkstemp(dir=...)`는 부모 폴더가 없다는 이유로 `FileNotFoundError` 예외를 발생시키며 즉시 중단됨. |
| 확인 방법 | 존재하지 않는 하위 디렉토리를 포함한 임의의 경로(예: `dist/non_existent_subdir/file.html`)를 대상으로 `atomic_write`를 실행할 때, 예외가 터지며 파일이 작성되지 않는 것을 확인. |
| 심각도 제안 | good-to-fix (안정성 강화) |

**수정 제안**: `tempfile.mkstemp` 호출 전에 `dir_path.mkdir(parents=True, exist_ok=True)`를 수행하여 필요한 디렉토리가 항상 자동 생성되도록 보완함으로써 모듈의 내결함성(fault-tolerance)을 개선할 수 있음.
