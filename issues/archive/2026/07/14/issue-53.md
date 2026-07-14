# issue-53: `.ai.md` 경로에 디렉토리 계층 허용 (예: /app/tetris.ai.md)

## 의존성
issue-10 완료 후 (main.py 디스패처가 이미 존재해야 함)

## 목표
지금은 `_AIMD_RE`가 `[^/]+\.ai\.md` 로 슬래시 없는 단일 세그먼트만 허용해서,
`src/*.ai.md`를 하위 디렉토리로 묶어 `http://localhost:8080/app/tetris.ai.md/...`,
`http://localhost:8080/api/convert.ai.md/...` 같은 URL로 서빙할 수 없다.
라우팅 규칙은 "URL이 `.ai.md`로 끝나는 세그먼트를 포함하는가"이지 "루트 바로
아래에 있는가"가 아니어야 하므로, 임의 깊이의 디렉토리 하위에 있는 `.ai.md`
파일도 동일하게 동작하도록 만든다.

## 구현 상세

### 1. `engine/aimd/main.py` — 정규식 확장
`_AIMD_RE`를 슬래시 세그먼트를 허용하도록 바꾼다:

```python
_AIMD_RE = re.compile(r"^/((?:[^/]+/)*[^/]+\.ai\.md)(/.*)?$")
```

- capture group 1(`name`)은 이제 `"tetris.ai.md"` 뿐 아니라 `"app/tetris.ai.md"`,
  `"api/v1/convert.ai.md"` 같은 하위 경로 포함 문자열이 될 수 있다.
- 나머지 로직(`artifacts.spec_path/html_path/py_path`는 `dir / name` 이므로
  `name`에 슬래시가 있어도 `pathlib`이 알아서 하위 경로로 처리한다. `atomic_write`는
  이미 `mkdir(parents=True, exist_ok=True)`로 부모 디렉토리를 만들므로 추가 변경
  불필요)와 `sub_scope["root_path"] = f"/{name}"`도 변경 없이 그대로 동작해야 한다.
- 기존 단일 세그먼트 케이스(`/tetris.ai.md`, `/convert.ai.md`)가 회귀하지 않는지
  반드시 확인한다 (정규식은 하위 호환이어야 함 — `(?:[^/]+/)*`가 0번 매칭되는 경우).

### 2. `engine/aimd/artifacts.py` — `list_specs` 재귀 스캔
지금은 `src_dir.iterdir()`로 최상위만 스캔한다 (`list_specs` 함수, docstring:
"Does not look into subdirectories"). 하위 디렉토리의 `.ai.md`도 찾도록
`rglob("*.ai.md")`로 바꾸고, 반환값은 `src_dir` 기준 상대 경로를 **POSIX 슬래시**로
반환한다 (Windows에서도 `main.py`가 쓰는 name 형식과 일치시키기 위해
`relative_to(src_dir).as_posix()` 사용). 정렬(`sorted()`) 유지, 디렉토리 자체나
`.ai.md`로 안 끝나는 파일은 여전히 제외.

이 함수는 현재 main.py/compiler.py 어디서도 호출되지 않는 유틸리티이지만(테스트만
존재), 하위 디렉토리 지원과 일관성을 맞추기 위해 함께 수정한다.

## 테스트로 검증해야 할 것
- `engine/tests/test_main.py`: `src/app/tetris.ai.md` 같은 하위 디렉토리 스펙에
  대해 `GET /app/tetris.ai.md` → 200 (dist의 `app/tetris.ai.md.html` 반환),
  그리고 py 서브앱인 경우 `sub_scope["root_path"]`가 `/app/name.ai.md`로 올바르게
  설정되는지 확인.
- `engine/tests/test_main.py`: 기존 루트 레벨 케이스(`/tetris.ai.md`,
  `/convert.ai.md`, `/nonexistent.ai.md` 404)가 여전히 통과하는지 (회귀 확인).
- `engine/tests/test_artifacts.py`: `list_specs`가 하위 디렉토리의 `.ai.md`
  파일을 `"app/tetris.ai.md"` 형태(슬래시 포함, 정렬됨)로 반환하는 케이스 추가.

## 하지 말 것
- `src/tetris.ai.md`, `src/convert.ai.md`를 실제로 하위 디렉토리로 옮기지 않는다
  (이 이슈는 "가능하게" 만드는 것이지 기존 데모 구조를 바꾸는 게 아니다).
- nginx.conf는 변경 불필요 (`try_files $uri.html @engine`은 깊이와 무관하게 이미
  동작함) — 손대지 말 것.
- `public/index.html` (랜딩 페이지, `.ai.md` 파이프라인 밖)은 이 이슈와 무관.

## 완료 조건
- [x] `src/app/tetris-nested.ai.md` 같은 임시 픽스처로 하위 디렉토리 스펙이
      `GET /app/tetris-nested.ai.md`로 정상 서빙됨을 pytest로 확인
- [x] 기존 `engine/tests/test_main.py`, `test_artifacts.py` 전체 통과 (회귀 없음)
- 검증 명령: `cd engine && python -m pytest -q`

## 구현 결과

- **구현 완료 일시**: 2026-07-14T18:52:49+0000
- **변경 파일**:
  - `engine/aimd/main.py` — `_AIMD_RE`를 `^/((?:[^/]+/)*[^/]+\.ai\.md)(/.*)?$`로
    확장해 디렉토리 세그먼트를 허용 (하위 호환 유지)
  - `engine/aimd/artifacts.py` — `list_specs`를 `iterdir()` 평면 스캔에서
    `rglob("*.ai.md")` 재귀 스캔으로 변경, POSIX 상대 경로 반환
  - `engine/tests/test_main.py` — `test_nested_dir_spa_served`,
    `test_nested_dir_py_subapp_receives_correct_scope` 추가
  - `engine/tests/test_artifacts.py` — `test_list_specs`가 하위 디렉토리
    스펙도 포함하도록 갱신
  - `regression-tests/verify-issue-53.sh` (신규)
  - `regression-tests/verify-issue-19.sh` — `list_specs`의 필터 방식이
    `endswith` → `rglob` 패턴으로 바뀐 것을 허용하도록 체크 갱신
  - `regression-tests/verify-issue-19.conflict-with-53.md` (신규) — 위 변경 근거 문서화
- **계획과의 차이**:
  - nginx.conf는 계획대로 변경 없음.
  - 계획에 없던 부수 발견: 이번 세션 앞선(이슈로 관리되지 않은) 도커
    env-var 우선순위 재설계 작업 때문에 `verify-issue-13.sh`가 이미 깨져
    있었음(`env_file: .env`, `docker compose up --build` 문자열 체크가
    현재 `docker-compose.yml`/`README.md`와 불일치). issue-53과는 무관하지만
    같은 세션에서 발생한 회귀라 `verify-issue-13.sh`를 현재 설계에 맞게
    갱신하고 `verify-issue-13.conflict-with-docker-env-redesign.md`로
    근거를 남김.
  - pytest 실행에 `pytest-asyncio`가 필요했으나 `engine/requirements-dev.txt`에
    빠져 있어서 로컬 검증이 아예 안 되고 있었음 — `requirements-dev.txt`에
    `pytest-asyncio`를 추가함 (이 세션 환경에서 `engine/.venv` 신규 생성).
- **검증 결과**:
  - 단위 테스트: `PYTHONPATH=. engine/.venv/Scripts/python.exe -m pytest -q`
    (engine/ 내부에서 실행) → 85 passed, 1 failed
    (`test_create_app_returns_dispatcher_instance` — Windows에서 `watchdog`이
    상대 경로 `./src`를 관찰하지 못해 발생하는 기존 환경 이슈. `git stash`로
    이 이슈 변경분을 걷어낸 클린 상태에서도 동일하게 재현되어 issue-53과
    무관함을 확인함)
  - 회귀 스크립트: `regression-tests/verify-issue-53.sh` 통과
  - 전체 회귀 스위트: `verify-issue-13/19`는 갱신 후 통과. 다음은 issue-53과
    무관한 기존(HEAD 시점부터 이미 실패 중) 실패로 확인되어 손대지 않음 —
    `verify-issue-1.sh`/`15.sh`/`18.sh`(README 제목 문자열 불일치),
    `verify-issue-16.sh`(README에 ngrok 문구 부재), `verify-issue-14.sh`
    (README에 "Real compile demo" 섹션 부재), `verify-issue-25.sh`
    (validators.py의 `_UNCLOSED_FENCE_RE` 관련). 나머지 전부 통과.
