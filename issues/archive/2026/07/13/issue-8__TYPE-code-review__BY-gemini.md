모델명: Gemini 3.5 Flash (Medium)

# 코드 리뷰 결과: issue-8-add-compiler

이 문서는 `3ac33cc6f3a532f4501a67336a433edd160c18bd..00c0136` 범위의 변경에 대해 수행한 기계(정적 분석)가 감지하지 못하는 로직 오류, 스펙 불일치, 보안(OWASP Top 10), 동시성 및 경계 조건 리뷰 결과입니다.

---

### [Finding 1] 원자적 쓰기 전 이전 캐시 아티팩트의 성급한 언링크로 인한 캐시 유실

| 필드 | 내용 |
|---|---|
| 파일:라인 | [engine/aimd/compiler.py:93-94](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L93-L94) |
| 코드 인용 | ```python<br>if stale_artifact.exists():<br>    stale_artifact.unlink()<br>``` |
| 실패 시나리오 | 1. 이전 컴파일의 결과물로 `convert.ai.md.py`가 디스크에 존재하는 상태에서 새 명세가 입력되어 이번에는 `spa` (즉 `.html`) 타겟으로 새로 컴파일을 실행함.<br>2. 코드 검증(Syntax 검사 및 import 검사)은 성공했으나, 디스크 공간 부족, 권한 에러, 또는 쓰기 도중 프로세스 강제 종료 등 다양한 외부 요인으로 인해 96행의 `artifacts.atomic_write(out, code)` 호출 과정에서 예외가 발생함.<br>3. 그러나 이미 94행에서 기존 캐시 파일인 `convert.ai.md.py`를 `unlink()`하여 삭제해 버렸기 때문에, 새로 생성되어야 할 `convert.ai.md.html`도 생성되지 못하고 기존의 정상 동작하던 `convert.ai.md.py` 마저 유실된 채 컴파일이 실패하게 됨. 이는 "검증 실패 또는 오류 발생 시 기존 캐시를 보존한다"는 ADR-0008의 원자적 캐시 보존 보장 원칙을 위배함. |
| 확인 방법 | 1. `engine/tests/test_compiler.py` 등에 테스트 코드를 추가하거나 직접 스크립트로 mock을 설정.<br>2. `artifacts.atomic_write`가 임의로 예외를 발생시키도록 패치함.<br>3. `dist/convert.ai.md.py` 파일을 미리 생성해 두고, 컴파일을 수행하여 `CompileError`가 발생하는 것을 확인.<br>4. 컴파일 실패 후 `dist/convert.ai.md.py` 파일이 디스크에 남아있는지 확인하면, 파일이 삭제되어 존재하지 않는 것을 통해 캐시 유실 문제를 재현할 수 있음. |
| 심각도 제안 | must-fix |

---

### [Finding 2] 격리되지 않은 호스트 환경에서의 임포트 실행 (RCE 취약점)

| 필드 | 내용 |
|---|---|
| 파일:라인 | [engine/aimd/compiler.py:36](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L36) (혹은 [engine/aimd/validators.py:91](file:///home/user1/git/ai-md/engine/aimd/validators.py#L91)) |
| 코드 인용 | - `engine/aimd/compiler.py` 36행:<br>```python<br>validators.load_module(tmp_path)<br>```<br>- `engine/aimd/validators.py` 91행:<br>```python<br>spec.loader.exec_module(module)<br>``` |
| 실패 시나리오 | 1. 공격자가 원격 코드 실행(RCE)을 유발하는 악성 명세(`.ai.md`)를 작성하거나, LLM 탈옥(Prompt Injection)을 통해 `import os; os.system("...")` 또는 파이썬의 `eval`, `subprocess` 등을 활용한 악성 코드가 컴파일 대상 코드로 생성됨.<br>2. API 검증 단계인 `_import_gate` 내에서 `validators.load_module(tmp_path)`가 호출되고, 이는 내부적으로 `exec_module`을 실행함.<br>3. 이 과정에서 샌드박싱이나 격리 조치가 전혀 없는 호스트 프로세스 권한 그대로 해당 파이썬 코드가 실행되므로, 컴파일러가 실행되는 시스템 전체가 제어권을 탈취당할 수 있는 원격 코드 실행(RCE) 취약점(OWASP Top 10 A03:2021-Injection)이 발생함. |
| 확인 방법 | 1. LLM 호출부(`llm.chat`)가 `import os; os.mkdir('/tmp/rce_hacked_test')` 코드를 반환하도록 Mock 혹은 명세 파일을 주입.<br>2. `compiler.compile_spec("rce_test.ai.md", settings)`를 실행함.<br>3. 컴파일 실행 후 실제로 호스트 서버의 `/tmp/rce_hacked_test` 경로에 디렉토리가 생성되었는지 확인하여 격리 없는 코드 실행 취약점을 검증함. |
| 심각도 제안 | must-fix |

---

### [Finding 3] `BaseException` (예: `SystemExit`) 발생 시 예외 미처리로 인한 프로세스 크래시 (DoS 취약점)

| 필드 | 내용 |
|---|---|
| 파일:라인 | [engine/aimd/compiler.py:37-38](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L37-L38) |
| 코드 인용 | ```python<br>except Exception as e:<br>    return f"{type(e).__name__}: {e}"<br>``` |
| 실패 시나리오 | 1. LLM이 생성한 파이썬 코드 내에 `import sys; sys.exit(0)` 등 `BaseException`을 상속하는 예외를 직접 던지는 코드(예: `SystemExit`, `KeyboardInterrupt`)가 포함되어 있음.<br>2. `_import_gate` 내의 `load_module`이 해당 코드를 동적으로 로드 및 실행하는 과정에서 `SystemExit` 예외가 발생함.<br>3. 그러나 `_import_gate`는 `except Exception`으로만 예외를 캐치하고 있기 때문에, `Exception`이 아닌 `BaseException` 그룹에 속하는 `SystemExit`은 전혀 잡히지 않고 상위 호출 스레드 및 웹 서비스 프로세스 전체로 전파되어 웹 서버 자체가 크래시(서비스 거부, DoS)를 유발함. |
| 확인 방법 | 1. `llm.chat`이 `import sys; sys.exit(99)`를 반환하도록 모킹함.<br>2. `compile_spec`을 호출함.<br>3. 호출 시 `CompileError`로 감싸져서 안전하게 복구되거나 1회 재시도하지 못하고, 호출 스레드 또는 파이썬 프로세스 전체가 즉시 exit code 99로 크래시 및 종료되는 것을 확인함. |
| 심각도 제안 | must-fix |

---

### [Finding 4] `_locks` 딕셔너리의 무제한 Lock 객체 누적으로 인한 메모리 누수

| 필드 | 내용 |
|---|---|
| 파일:라인 | [engine/aimd/compiler.py:15](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L15) |
| 코드 인용 | ```python<br>_locks: dict[str, threading.Lock] = defaultdict(threading.Lock)<br>``` |
| 실패 시나리오 | 1. 롱러닝 서버 환경에서 수많은 사용자가 고유한 명세서 파일명(예: 대규모 동적 파일명 생성 등)에 대해 컴파일을 연속 요청함.<br>2. `compile_spec`이 호출될 때마다 `_get_lock(name)`이 수행되어 `_locks` 사전에 파일명 키와 새로운 `threading.Lock` 인스턴스를 무제한으로 등록함.<br>3. 완료된 락에 대해 사후 제거(clean up) 메커니즘이 전혀 존재하지 않기 때문에, 서버의 메모리 점유율이 지속적으로 상승(Memory Leak)하여 장기적으로 OOM(Out of Memory) 크래시가 유발될 수 있음. |
| 확인 방법 | 1. 10,000번의 루프를 돌며 매번 무작위 고유 파일명(예: `f"spec_{i}.ai.md"`)을 사용하여 `compile_spec`을 모의 호출함.<br>2. 루프가 끝난 뒤 `len(compiler._locks)` 값을 확인하여 사용되지 않는 락 오브젝트가 사전에 고스란히 남아 메모리를 소모하고 있는지 점검함. |
| 심각도 제안 | good-to-fix |

---

### [Finding 5] 동적 임포트 과정에서 자동 생성되는 바이트코드 캐시(`.pyc`)의 누적으로 인한 디스크 누수

| 필드 | 내용 |
|---|---|
| 파일:라인 | [engine/aimd/compiler.py:36](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L36) (혹은 [engine/aimd/compiler.py:40](file:///home/user1/git/ai-md/engine/aimd/compiler.py#L40) 및 [engine/aimd/validators.py:91](file:///home/user1/git/ai-md/engine/aimd/validators.py#L91)) |
| 코드 인용 | - `engine/aimd/compiler.py` 36행: `validators.load_module(tmp_path)`<br>- `engine/aimd/compiler.py` 40행: `tmp_path.unlink(missing_ok=True)` |
| 실패 시나리오 | 1. `_import_gate` 검증 시 `tempfile.mkstemp`를 통해 `/tmp/tmpXXXX.py` 와 같이 공용 임시 디렉토리에 파이썬 코드를 씀.<br>2. `load_module`이 `exec_module`을 통해 모듈을 동적 임포트하여 실행하는 과정에서 파이썬 인터프리터가 자동으로 해당 임시 파일에 대한 바이트코드 캐시 파일(`.pyc`)을 `__pycache__` 디렉토리 하위에 컴파일하여 생성함.<br>3. `finally` 블록에서 원본 `.py` 파일만 `unlink`하고, 파이썬이 생성한 `__pycache__/` 디렉토리와 `.pyc` 파일은 지우지 않고 그대로 방치함.<br>4. 이로 인해 임포트 검증을 할 때마다 지워지지 않는 바이트코드 캐시 파일들이 시스템 디렉토리에 계속 쌓여 디스크 용량 누수 및 Inode 고갈을 야기함. |
| 확인 방법 | 1. 컴파일러를 다수 호출하여 컴파일을 수행함.<br>2. 시스템 임시 디렉토리(예: `/tmp/__pycache__/`)를 조회하여, 이미 지워진 원본 임시 파일들에 대치되는 컴파일 캐시 파일들(`.pyc`)이 다량으로 잔존하여 디렉토리에 누적되고 있는지 확인함. |
| 심각도 제안 | good-to-fix |
