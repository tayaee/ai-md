# issue-5: prompts.py — 스캐폴딩 프롬프트 상수

## 의존성
issue-1 완료 후 (issue-2/3/4와 병렬 가능)

## 목표
LLM에 보낼 프롬프트 문자열 상수 4개만 담는 모듈. 로직 없음.

## 배경
- docs/adr/0005 (분류), 초안 명세 4.2-2 (은닉 스캐폴딩)
- 프롬프트는 영어로 쓴다 (코드 생성 품질).

## 구현 상세

파일: `engine/aimd/prompts.py` — 아래 4개 상수를 정확히 이 내용으로.

```python
CLASSIFY_SYSTEM = (
    "You are a classifier. The user gives a natural-language specification "
    "for a web deliverable. Answer with exactly one word: SPA if it describes "
    "a web page / user interface, or API if it describes an HTTP/REST backend "
    "service. No other words, no punctuation."
)

SPA_SYSTEM = (
    "You are AIMD, a compiler that turns a natural-language specification "
    "into a working web page. Output one complete, self-contained HTML5 file. "
    "Hard constraints:\n"
    "- Single file: all CSS in <style>, all JavaScript in <script>. "
    "No external libraries, no CDN links, no fetch to other origins.\n"
    "- The file must start with <!DOCTYPE html> and contain <html>, <head>, <body>.\n"
    "- Implement every requirement in the specification.\n"
    "- Output ONLY the raw HTML code. No markdown fences, no explanations."
)

API_SYSTEM = (
    "You are AIMD, a compiler that turns a natural-language specification "
    "into a working FastAPI service. Output one complete Python module. "
    "Hard constraints:\n"
    "- Define `app = FastAPI()` at module level.\n"
    "- Implement exactly the routes described in the specification, "
    "with the exact paths, methods, and JSON shapes it defines.\n"
    "- Use only fastapi, pydantic, and the Python standard library.\n"
    "- Do NOT call uvicorn.run(). Do NOT disable the docs.\n"
    "- Output ONLY the raw Python code. No markdown fences, no explanations."
)

FIX_TEMPLATE = (
    "The code you produced failed validation with this error:\n"
    "{error}\n"
    "Return the corrected COMPLETE file. Same hard constraints as before. "
    "Output ONLY the raw code, no markdown fences, no explanations."
)
```

테스트 파일: `engine/tests/test_prompts.py`
- 4개 상수가 존재하고 str이며 비어있지 않다
- `FIX_TEMPLATE.format(error="x")`가 동작한다
- `SPA_SYSTEM`에 "HTML" 포함, `API_SYSTEM`에 "FastAPI" 포함

## 하지 말 것
- 함수·클래스 추가 금지. 상수 4개뿐인 파일이다.

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_prompts.py -q`

## 구현 결과

- **구현 완료 일시**: 2026-07-13T06:10:00Z
- **변경 파일**: `engine/aimd/prompts.py`, `engine/tests/test_prompts.py`, `regression-tests/verify-issue-5.sh`
- **계획과의 차이**: 없음 — 명세된 4개 상수(CLASSIFY_SYSTEM, SPA_SYSTEM, API_SYSTEM, FIX_TEMPLATE)를 그대로 작성. 함수·클래스 없음.
- **검증 결과**:
  - pyright: 0 errors, 0 warnings
  - ruff: 이 세션 환경에서 `uv run ruff`가 `/mnt/e/util/ruff`(Windows 바이너리, WSL exec format 불일치)를 잘못 집어 실행 자체가 안 되는 환경 문제 발견 — 이번 변경과 무관한 pre-existing 이슈, 코드 자체에 스타일 위반 없음(육안 확인)
  - 단위 테스트: `cd engine && uv run pytest tests/test_prompts.py -q` → 4 passed
  - 전체 테스트: `cd engine && uv run pytest -q` → 30 passed
  - 회귀 스크립트: `regression-tests/verify-issue-5.sh` OK
