# issue-4: validators.py — 코드 추출·검증·모듈 로딩

## 의존성
issue-1 완료 후 (issue-2/3과 병렬 가능)

## 목표
LLM 출력에서 코드를 뽑고, SPA/API 아티팩트를 검증하고, py 모듈을 실제 import하는
순수 모듈. LLM 접근 없음.

## 배경
- docs/adr/0008-validation-retry-atomic-write.md

## 구현 상세

파일: `engine/aimd/validators.py`

```python
import ast
import importlib.util
import itertools
import re
from pathlib import Path
from types import ModuleType

_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)
_counter = itertools.count()


def extract_code(llm_output: str) -> str:
    """LLM 출력에서 코드 본문을 추출한다.
    - 마크다운 코드펜스(```)가 있으면: 가장 긴 펜스 블록의 내용을 반환
    - 없으면: 전체를 strip해서 반환
    - trailing-newline 정책 (issue-23로 명세화): 펜스 케이스는 매칭된 블록의
      모든 trailing newline을 rstrip으로 제거한다. 의도적 빈 줄도 함께 사라지는
      손실이 있지만, no-fence 경로의 ``strip()`` 동작과 일관된다.
    """


def validate_html(code: str) -> str | None:
    """SPA 아티팩트 느슨한 검증. 문제 없으면 None, 있으면 영어 에러 메시지.
    - 빈 문자열 → "empty output"
    - "<html" 미포함 (대소문자 무시) → "missing <html tag"
    - "```" 포함 → "markdown fence not stripped"
    """


def validate_python(code: str) -> str | None:
    """1단계 문법 검증. ast.parse 성공 시 None, SyntaxError 시
    f"SyntaxError: {e}" 형태의 영어 메시지."""


def load_module(path: Path) -> ModuleType:
    """2단계 검증 겸 로더. path의 py 파일을 매번 새 모듈 객체로 import한다.
    - 모듈명은 f"aimd_dyn_{next(_counter)}" 로 유일하게 만든다 (재로드 시 신선한 객체 보장)
    - importlib.util.spec_from_file_location + module_from_spec + exec_module
    - import 중 예외는 그대로 전파한다 (호출자가 잡는다)
    - 성공 후 hasattr(module, "app")이 False면 raise AttributeError("module has no 'app' object")
    """
```

테스트 파일: `engine/tests/test_validators.py`
- `extract_code`: 펜스 있음(언어 태그 포함), 펜스 2개 중 긴 것 선택, 펜스 없음 3케이스
- `validate_html`: 정상 html→None, 빈 문자열, `<html` 없음, 펜스 잔존 4케이스
- `validate_python`: 정상 코드→None, 문법 오류→메시지
- `load_module` (tmp_path에 py 파일 작성):
  - `app = "dummy"` 있는 파일 → 성공, `module.app == "dummy"`
  - `app` 없는 파일 → `AttributeError`
  - import 시 `raise RuntimeError` 하는 파일 → `RuntimeError` 전파
  - 같은 파일 2번 로드 → 서로 다른 모듈 객체 (`m1 is not m2`)

## 하지 말 것
- `load_module`에서 FastAPI 타입 체크 금지 — `app` 속성 존재만 본다
  (테스트에서 FastAPI 없이도 돌릴 수 있게).
- `sys.modules`에 등록 금지.

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_validators.py -q`

## 구현 결과

- **구현 완료 일시**: 2026-07-12T22:50:00Z
- **변경 파일**: `engine/aimd/validators.py`, `engine/tests/test_validators.py`, `regression-tests/verify-issue-4.sh`
- **계획과의 차이**: 없음 — 명세된 4개 함수(extract_code, validate_html, validate_python, load_module)와 테스트 스위트를 충실히 작성함. `extract_code`는 no-fence 케이스의 strip 동작과 일관되도록 가장 긴 펜스 블록의 trailing newline을 rstrip 처리. `load_module`의 `spec_from_file_location`이 None을 반환하는 드문 경우를 방어적으로 `AttributeError`로 일관 처리.
- **검증 결과**:
  - ruff(`engine/aimd/validators.py`, `engine/tests/test_validators.py`): All checks passed
  - pyright(scoped): 0 errors, 0 warnings
  - pyright-full: 3 errors 모두 `Import "pytest" could not be resolved` — issue-3의 기존 `test_artifacts.py`에도 동일하게 발생하는 pre-existing 환경 이슈로, 이번 변경과 무관
  - 단위 테스트: `cd engine && uv run pytest -q` → 23 passed (validators 15 + artifacts 4 + config 4)
  - 회귀 스크립트: `regression-tests/verify-issue-4.sh` OK, 다른 회귀 스크립트(1,2,3)도 모두 통과
