# issue-43: compiler.compile_spec — atomic_write 실패 시 기존(반대 확장자) 아티팩트가 이미 삭제되어 캐시 완전 유실

## 의존성
issue-8 완료 후

## 배경
gemini의 issue-8 리뷰 Finding 1(must-fix): `stale_artifact.unlink()`가 `atomic_write`
보다 먼저 실행되어, `atomic_write` 실패 시 dist에 아무 아티팩트도 남지 않는다.

원본 리뷰 파일: `issues/issue-8__TYPE-code-review__BY-gemini.md` (Finding 1)

인용:
> 코드 인용: `if stale_artifact.exists(): stale_artifact.unlink()`
> 실패 시나리오: ... `atomic_write` 호출 과정에서 예외가 발생함... 이미 기존 캐시
> 파일을 `unlink()`하여 삭제해 버렸기 때문에... 유실된 채 컴파일이 실패하게 됨.

## 재검증 결과 (실행 확인)
`compiler.artifacts.atomic_write`를 `OSError`를 던지도록 monkeypatch하고, dist에
기존 `.html` 아티팩트를 둔 채(spec을 api로 재분류되도록 구성) `compile_spec`을
호출해 재현했다:

```
compile_spec raised: OSError disk full (simulated)
old_html exists after failure: False
py exists after failure: False
dist listing: []
```

`OSError`가 전파된 후 dist 디렉터리가 완전히 빈 상태 — 기존 `.html`도 없고 새
`.py`도 없다. 인용·주장 모두 성립 — **must-fix 승격 확정**.

이는 ADR-0008 "결과: 깨진 아티팩트가 dist에 존재할 수 없고, 실패가 가용성을
해치지 않는다"는 원칙을 위반한다.

## 목표
`atomic_write` 자체가 실패(디스크 풀, 권한 등)하더라도 기존 아티팩트(반대
확장자든 동일 확장자든)가 남아있어야 한다 — "실패가 가용성을 해치지 않는다"
보장.

## 구현 상세

파일: `engine/aimd/compiler.py`

반대 확장자 아티팩트 삭제 시점을 `atomic_write` 성공 이후로 옮긴다:

```python
artifacts.atomic_write(out, code)  # 먼저 새 아티팩트를 원자적으로 쓴다
if stale_artifact.exists():
    stale_artifact.unlink()        # 성공한 뒤에만 반대 확장자 정리
return out
```

이렇게 하면 `atomic_write`가 실패해도 `stale_artifact`(구 아티팩트)는 그대로
남는다. 성공 후 `unlink` 실패(권한 등)는 별도 예외로 전파될 수 있지만, 이 경우도
새 아티팩트(`out`)는 이미 존재하므로 가용성은 보장된다.

## 완료 조건
- [ ] `atomic_write`가 예외를 던지는 시나리오에서 기존 반대 확장자 아티팩트가
      보존되는지 확인하는 테스트 추가
- [ ] `cd engine && uv run pytest tests/test_compiler.py -q` 통과
- [ ] `regression-tests/verify-issue-8.sh` 및 전체 회귀 스크립트 통과 유지

## 하지 말 것
- `compile_spec`의 시그니처·반환값 변경 금지
- 정상 경로(검증 통과 후 정상 쓰기)에서 반대 확장자를 삭제하는 동작 자체는 유지
  — 시점만 조정한다

## 구현 결과

**구현 완료 일시**: 2026-07-13T23:48:00Z
**변경 파일**:
- engine/aimd/compiler.py (반대 확장자 삭제를 atomic_write 성공 이후로 이동)
- engine/tests/test_compiler.py (회귀 테스트 1건 추가)
- regression-tests/verify-issue-43.sh (신규)
- issues/issue-43__TYPE-agent-stats.json (신규)

**스펙 대비 deviation**: 없음. 이 이슈 본문의 "구현 상세" 가이드를 그대로
채택 — `artifacts.atomic_write(out, code)`를 먼저 호출하고, 성공한 뒤에만
`stale_artifact.unlink()`를 실행하도록 순서를 뒤집었다.

**verify 결과**:
- red: 수정 전 재현 테스트가 실패함을 확인 (`old_html.exists()` → False).
- green: 순서 변경 후 같은 테스트 통과.
- 회귀 스크립트 (`regression-tests/verify-issue-43.sh`) 통과.
- 전체 pytest: 59 passed.
- 전체 회귀 스크립트: 20/20 통과.
- ruff/pyright: 리포에 `pyproject.toml`이 없어 미실행 (기존 관행과 동일).
