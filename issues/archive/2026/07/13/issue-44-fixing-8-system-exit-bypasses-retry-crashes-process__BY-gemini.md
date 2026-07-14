# issue-44: compiler._import_gate — BaseException(SystemExit 등)이 except Exception에 잡히지 않아 재시도 없이 프로세스로 전파

## 의존성
issue-8 완료 후

## 배경
gemini의 issue-8 리뷰 Finding 3(must-fix): `_import_gate`가 `except Exception`만
잡아서 `SystemExit`/`KeyboardInterrupt` 같은 `BaseException` 하위 예외는 잡히지
않고 `compile_spec` 밖으로 그대로 전파된다.

원본 리뷰 파일: `issues/issue-8__TYPE-code-review__BY-gemini.md` (Finding 3)

인용:
> 코드 인용: `except Exception as e: return f"{type(e).__name__}: {e}"`
> 실패 시나리오: LLM이 생성한 코드에 `import sys; sys.exit(0)` 같은
> `BaseException`을 던지는 코드가 포함되면... `SystemExit`이 잡히지 않고 상위
> 호출 스레드/프로세스 전체로 전파되어 크래시(DoS)

## 재검증 결과 (실행 확인)
`llm.chat`이 `"import sys\nsys.exit(99)\napp = object()"`를 반환하도록
monkeypatch하고 `compile_spec`을 호출해 재현했다:

```
SystemExit propagated with code: 99
```

`SystemExit(99)`가 `compile_spec` 밖으로 그대로 전파됨 — 호출자가 별도로
`except SystemExit`로 잡지 않는 한 프로세스/스레드가 종료된다. ADR-0003의
동기 블로킹 모델 하에서 이 호출은 요청을 처리하는 스레드에서 실행되므로,
요청 스레드 전체가 죽을 수 있다. 인용·주장 모두 성립 — **must-fix 승격 확정**.

## 목표
LLM이 생성한 코드가 `BaseException`(`SystemExit`, `KeyboardInterrupt` 등)을
던지더라도, `compile_spec`은 이를 검증 실패로 처리해 1회 수정 재시도 후
`CompileError`로 변환해야 한다 — 프로세스/스레드를 죽이지 않는다.

## 구현 상세

파일: `engine/aimd/compiler.py`

`_import_gate`의 예외 처리 범위를 넓힌다. 최소한 `SystemExit`은 반드시
"검증 실패"로 취급해야 한다:

```python
except (Exception, SystemExit) as e:
    return f"{type(e).__name__}: {e}"
```

`KeyboardInterrupt`까지 포함할지는 신중히 판단한다 — 운영자의 실제 인터럽트
(Ctrl+C)까지 삼키면 안 되므로, 포함 여부는 구현자가 트레이드오프를 판단해
결정한다.

## 완료 조건
- [ ] LLM 출력이 `sys.exit(...)`를 포함하는 코드를 반환하는 시나리오에서
      `compile_spec`이 `SystemExit`을 전파하지 않고 정상적으로 재시도 후
      `CompileError`(2회 모두 실패 시)를 던지는지 확인하는 테스트 추가
- [ ] `cd engine && uv run pytest tests/test_compiler.py -q` 통과
- [ ] `regression-tests/verify-issue-8.sh` 및 전체 회귀 스크립트 통과 유지

## 하지 말 것
- 검증 로직의 나머지 흐름(`validate_python` 우선 실행, 1회 재시도 규칙) 변경 금지

## 구현 결과

**구현 완료 일시**: 2026-07-13T23:51:33Z
**변경 파일**:
- engine/aimd/compiler.py (`_import_gate`가 `SystemExit`도 잡도록 확장)
- engine/tests/test_compiler.py (회귀 테스트 1건 추가)
- regression-tests/verify-issue-44.sh (신규)
- issues/issue-44__TYPE-agent-stats.json (신규)

**스펙 대비 deviation**: `KeyboardInterrupt`는 포함하지 않았다 — 이슈 본문이
"운영자의 실제 인터럽트까지 삼키면 안 되므로 구현자 판단에 맡긴다"고 명시한
트레이드오프에 따라, 최소 요구사항인 `SystemExit`만 추가했다.

**verify 결과**:
- red: 수정 전 재현 테스트가 `SystemExit`을 잡지 못하고 그대로 전파됨을 확인.
- green: `except (Exception, SystemExit)`로 확장 후 같은 테스트 통과 — 1회
  수정 재시도까지 정상 소진되고 `CompileError`로 변환됨.
- 회귀 스크립트 (`regression-tests/verify-issue-44.sh`) 통과.
- 전체 pytest: 60 passed.
- 전체 회귀 스크립트: 21/21 통과.
- ruff/pyright: 리포에 `pyproject.toml`이 없어 미실행 (기존 관행과 동일).
