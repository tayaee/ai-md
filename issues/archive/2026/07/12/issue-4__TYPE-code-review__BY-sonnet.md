Claude-Sonnet-5

issue-4 (`validators.py`) 코드 리뷰입니다. spec은 ADR 0008에 따른 LLM 출력 추출·검증·모듈 로딩의 1차 구현이며, ruff/pyright/pytest/regression이 모두 통과한 상태입니다. 따라서 본 리뷰는 기계가 잡지 못하는 **로직/스펙 불일치/보안/경계조건**에 집중합니다.

# 종합 판정

스펙(issue-4.md)에 명시된 4개 함수의 계약(시그니처, 반환값, 부수효과)은 모두 충족합니다. 하지만 `extract_code`의 정규식 lazy matching이 코드 본문 안에 ` ``` ` 시퀀스가 등장하는 실제적인 케이스에서 잘못된 매칭을 일으키고, `load_module`은 호출자 책임을 전제로 한 임의 코드 실행 경로라는 점을 짚어야 합니다.

---

# Finding 1 — extract_code 정규식이 docstring 안의 백틱을 잘못 매칭한다

| Field | Value |
|---|---|
| file:line | `engine/aimd/validators.py:8` |
| code quote | `_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)` |
| failure scenario | LLM 출력에 Python docstring 안에 markdown 코드 예시가 포함된 경우, 예: ` ```python\ndef f():\n    """\n    Example:\n    ```\n    pass\n    ```\n    """\n``` ` → regex는 가장 먼저 만나는 닫는 ``` 을 매칭하므로 `def f():\n    """\n    Example:\n    `까지만 추출되고 docstring이 깨진 채 반환. 이 결과는 검증 단계를 통과하지 못하거나, 더 나쁜 경우 부분적으로 통과하여 import 시 비-결정적 동작을 유발. spec은 "가장 긴 펜스 블록"이라고만 명시하지만 구현은 lazy `.*?`로 가장 가까운 닫는 펜스를 잡으므로 spec의 "긴 블록" 의도와 어긋남. |
| verification method | `cd engine && python3 -c "from aimd.validators import extract_code; print(extract_code('\`\`\`python\ndef f():\n    \"\"\"\n    Example:\n    \`\`\`\n    pass\n    \`\`\`\n    \"\"\"\n\`\`\`'))"` → 결과가 깨진 코드를 포함하는 것을 확인. |
| severity | `good-to-fix` |

# Finding 2 — 닫히지 않은 펜스(LLM 잘림 출력)에서 마커 그대로 노출

| Field | Value |
|---|---|
| file:line | `engine/aimd/validators.py:18-22` |
| code quote | `matches = _FENCE_RE.findall(llm_output)\n    if matches:\n        # 코드펜스 닫기 직전의 개행은 블록 구분용이므로 제거한다.\n        return max(matches, key=len).rstrip("\n")\n    return llm_output.strip()` |
| failure scenario | LLM이 토큰 한도에서 잘려 ` ```python\nprint(1)` 처럼 여는 펜스만 남긴 경우, `_FENCE_RE.findall`은 매칭이 없어 raw 텍스트를 strip해서 반환. 반환 문자열 안에는 ``\`\`\`python`` 마커가 그대로 남아있음. 이 결과가 곧바로 `validate_python`/`validate_html`로 들어가는 파이프라인이라면, `validate_html`이 "markdown fence not stripped"로 검출해 주지만 spec에는 그 단계가 분리돼 있지 않고 호출자가 직접 호출하는 구조이므로 위험. 특히 `validate_python` 단계의 `ast.parse`는 ``\`\`\`python`` 같은 마커를 만나면 `SyntaxError`를 내므로 호출자가 어느 검증을 먼저 호출하느냐에 따라 결과가 달라짐. |
| verification method | `cd engine && python3 -c "from aimd.validators import extract_code, validate_python; s = extract_code('hi\n\`\`\`python\nprint(1)'); print(repr(s)); print('fence in out:', '\`\`\`' in s); print(validate_python(s))"` → `\`\`\`python`이 결과에 그대로 남아있고 `validate_python`은 그것을 SyntaxError로 잡음. |
| severity | `good-to-fix` |

# Finding 3 — `_counter` 모듈 전역 — 실패 후 advance로 디버깅성 손실

| Field | Value |
|---|---|
| file:line | `engine/aimd/validators.py:9,54` |
| code quote | `_counter = itertools.count()\n...\n    module_name = f"aimd_dyn_{next(_counter)}"` |
| failure scenario | `exec_module`이 `RuntimeError`/`SyntaxError`/`ImportError`로 실패해도 `next(_counter)`는 이미 호출돼 카운터가 진행됨. 이는 코너 케이스는 아니지만, 로깅/추적 관점에서 "aimd_dyn_7"이 실제로 사용된 적이 없는 번호로 남을 수 있음. 또한 멀티스레드 호출 시(`asyncio.to_thread` 등 GIL 외 영역은 아니지만 같은 스레드라면 문제 없음)에는 다음 호출의 모듈명이 실패 횟수만큼 점프. 정확성에는 영향이 없으나 운영 가시성 문제. |
| verification method | `cd engine && python3 -c "from aimd.validators import load_module; from pathlib import Path; import tempfile, os; t = tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False); t.write('raise RuntimeError(\"boom\")'); t.close(); 
try: load_module(Path(t.name))
except RuntimeError: pass
print('counter advanced on failure — expected by design but worth a comment')"`. 동작은 의도된 것이지만 spec 본문 49행에서 "`next(_counter)`"만 강조하고 실패 시 동작에 대한 단서가 없음. |
| severity | `good-to-fix` |

# Finding 4 — `load_module`의 임의 .py 실행 — 호출자 책임 경계 미명시

| Field | Value |
|---|---|
| file:line | `engine/aimd/validators.py:46-66` |
| code quote | `def load_module(path: Path) -> ModuleType:\n    ...\n    spec = importlib.util.spec_from_file_location(module_name, path)\n    ...\n    spec.loader.exec_module(module)` |
| failure scenario | 스펙은 "LLM이 생성한 artifact를 import한다"가 전제이지만, 함수 자체에는 어떤 경로 검증/샌드박스도 없음. 호출자가 검증되지 않은 사용자 입력 경로(예: 업로드 디렉토리 안의 파일명, URL-인코딩된 path traversal `..%2Fetc%2Fpasswd` 등)를 넘기면 임의 .py가 실행되어 RCE 가능. 이는 OWASP A03(Injection) 측면의 LLM 산출물 검증 부재 사안이며, issue-4 자체의 함수 책임이 아니라면 함수 docstring에 "caller must ensure path is trusted, no path validation is performed"라고 명시하는 것이 옳음. 현재 docstring은 "성공 후 `hasattr(module, 'app')`이 False면 raise …"만 기술. |
| verification method | `cd engine && python3 -c "from aimd.validators import load_module; from pathlib import Path; m = load_module(Path('/home/user1/git/ai-md/engine/tests/test_validators.py')); print(type(m).__name__)"` — 임의의 .py 파일을 그대로 import하는 것이 가능함을 확인. (보안 위험 자체가 아니라 "함수에 경계가 명시되어 있지 않다"는 점에 대한 finding) |
| severity | `good-to-fix` |

# Finding 5 — `spec_from_file_location`의 None 가드 메시지가 의미적으로 부정확

| Field | Value |
|---|---|
| file:line | `engine/aimd/validators.py:56-59` |
| code quote | `if spec is None or spec.loader is None:\n        # spec_from_file_location 이 None을 반환하는 경우는 거의 없지만\n        # 방어적으로 AttributeError로 일관되게 처리한다.\n        raise AttributeError("module has no 'app' object")` |
| failure scenario | 실제로 `spec_from_file_location`이 None을 반환하는 경우는 드물지만, 반환되는 시나리오는 "유효하지 않은 모듈명/loader"이지 "module has no app object"와는 원인 자체가 다름. 예외 메시지가 동일한 `AttributeError("module has no 'app' object")`로 던져지면 호출자는 두 가지 다른 실패를 구분할 수 없고, 디버깅 시 "왜 spec_from_file_location이 None을 반환했는지" 파악 불가. 이는 spec에 명시되지 않은 동작이며, 변경 시 "문서/스펙 갱신" 동반이 필요. |
| verification method | 코드 인스펙션. 가드 분기에 도달하는 입력은 운영상 거의 없으므로 unit test로 reproduce하기는 어려움. 그러나 caller가 `except AttributeError`만 잡고 있다면 다른 원인(spec/loader 부재)을 구분하지 못함. |
| severity | `good-to-fix` |

# 명확히 정상이라 판단한 항목

- `extract_code`의 "긴 블록 선택 + trailing newline strip" 동작: 테스트(`test_extract_code_picks_longest_of_two_fences`, `test_extract_code_with_fence_returns_content`)에 의해 보장됨.
- `validate_html`의 느슨한 검증 (`"<html" in code.lower()`): spec 39행이 "느슨한 검증"이라 명시했고 의도된 약한 검사.
- `validate_python`이 `ast.parse`만 수행: spec 45행 명시와 일치. 임의 모듈 import는 `load_module`이 담당.
- `load_module`의 "sys.modules 미등록 + 매번 새 객체 + `hasattr` 게이트": 테스트 5건(`test_load_module_*`)에 의해 보장됨.
- `load_module`의 예외 전파: `test_load_module_propagates_import_exception` 통과.

# 검증 명령

리뷰 자체의 재현 절차:
```
cd /home/user1/git/ai-md
regression-tests/verify-issue-4.sh
# 또는
cd engine && python3 -m pytest tests/test_validators.py -q
```
양쪽 모두 현재 통과. 위 finding들은 pytest가 잡지 못하는 의미/스펙 경계 측면의 이슈입니다.
