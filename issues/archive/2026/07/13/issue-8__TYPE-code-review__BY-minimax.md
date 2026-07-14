# code-review: issue-8 — compiler.py 명세→분류→생성→검증→1회 재시도→원자적 쓰기 파이프라인

- 리뷰어: minimax (MiniMax-M3 v2.1.207.308)
- 리뷰 일시: 2026-07-13
- 대상 커밋: 00c0136 (issue-8)
- 비교 베이스: 3ac33cc

## 1. 명세 / ADR 준수 점검 (대상 파일: engine/aimd/compiler.py)

| 단계 / 항목 | 위치 (compiler.py) | 결과 |
|---|---|---|
| 1단계: per-name 락 (_get_lock via _locks_guard) | L23-25, L57 | OK — _locks_guard가 defaultdict의 lazy lock 생성과 dict 조회를 원자화 |
| 2단계: 락 안 stale 재확인 (double-checked locking) | L58-61 | OK |
| 3단계: spec 부재 시 FileNotFoundError | L63-65 | OK |
| 4-5단계: spec_text → classify → system 결정 → llm.chat → extract_code | L67-72 | OK |
| 6단계 + 9단계 통합: _validate로 spa=validate_html / api=validate_python + _import_gate | L44-52 | OK — 명세의 "흐름을 단순하게 유지하기 위해 묶어도 된다" 지시와 일치. _validate 한 곳에 묶어 수정 재시도가 "정확히 1회"로 잠금 |
| 7단계: 1회 수정 재시도 (FIX_TEMPLATE) | L75-85 | OK |
| 7단계: 2회 모두 실패 시 CompileError + 영문 에러 로그 1줄 (log.error) | L83-85 | OK |
| 8단계: 검증 성공 후 atomic_write 전 반대 확장자 아티팩트 삭제 | L87-94 | OK |
| 10단계: atomic_write + out 반환 | L96-97 | OK (issue-20에서 자동 부모 디렉토리 생성 fix 포함) |
| llm.chat( 출현 = 2 (regression-tests §5 잠금) | regression-tests/verify-issue-8.sh:29 | OK |
| asyncio 미사용 (regression-tests §6 잠금) | regression-tests/verify-issue-8.sh:36 | OK |

명세 ("하지 말 것") 정책:
- 무한 재시도 금지 — llm.chat 호출 2회로 잠금. OK.
- 검증 통과 전 dist 쓰기 금지 — _validate 실패 시 즉시 raise, 8~10단계 모두 건너뜀. OK.
- asyncio 금지 — 회귀 스크립트로 잠금. OK.

ADR-0008 핵심 정책:
- api: 2단계 (ast.parse + import 검증) — _validate가 validate_python 통과 후 _import_gate. OK.
- spa: 1단계 (validate_html) — _validate가 spa 분기. OK.
- 1회 수정 재시도 + 영문 에러 로그 + 기존 캐시 유지 — 검증 실패 시 raise, 8단계 이전 exit. OK.
- 검증 통과 전 dist 절대 비변경 — _validate 실패 시 raise로 단락. OK.

## 2. finding

### finding 1 — _import_gate에서 LLM 출력 코드의 top-level 실행으로 인한 side-effect (security note)

| 필드 | 내용 |
|---|---|
| 파일:라인 | engine/aimd/compiler.py:36 (_import_gate 안) |
| 코드 인용 | validators.load_module(tmp_path) |
| 실패 시나리오 | LLM이 os.system(...), subprocess.run(...), 또는 top-level에서 os.environ 변형, sys.modules 변형 같은 side-effect 코드를 명세 결과로 만들면, 검증 시점에 import가 실행되며 side-effect가 그대로 일어남. ADR-0008은 "import 검증이 곧 배포 게이트"로 의도된 동작이지만, OWASP 관점에서 (특히 LLM 공급자 변조 / 프롬프트 인젝션 시나리오) 위협 모델이 명세/PR 본문에 명시되어 있지 않음. 또한, _import_gate의 부수효과 코드는 1회 수정 재시도가 발동되면 두 번 실행됨 |
| 확인 방법 | 1) 명세/PR 코멘트로 위협 모델 ("신뢰할 수 있는 LLM 공급자" 가정 + 잠재적 sandbox 격리 옵션) 을 한 줄로 적어두면 안전. 2) 임의 코드 실행 격리가 필요하면 별도 python subprocess + Resource limits 도입 검토. 3) 회귀 스크립트에 "샌드박스 미사용" 사실과 위협 모델을 명시적으로 박아두면 운영자가 의존성을 인지 가능 |
| 심각도 제안 | good-to-fix (security note) |

### finding 2 — _import_gate의 fd 누수 가능성 (good-to-fix)

| 필드 | 내용 |
|---|---|
| 파일:라인 | engine/aimd/compiler.py:31-34 |
| 코드 인용 | `fd, tmp_name = tempfile.mkstemp(suffix=".py")` / `with os.fdopen(fd, "w", encoding="utf-8") as f:` |
| 실패 시나리오 | 디스크 풀, 시스템 fd 한도 도달, 또는 매우 드문 OS race로 os.fdopen 자체 또는 f.write(code)가 raise하면, outer except Exception이 잡지만 fd는 close되지 않음. 컴파일 빈도가 높은 long-running 환경 (예: dev 서버 재시작 사이클)에서 OS-level fd 누수가 누적될 가능성. 또한 f.write 실패 시 fd가 닫히지 않은 상태로 unlink가 finally에서 실행되는 경로가 잠재적으로 존재 |
| 확인 방법 | 1) ulimit -n 16 같은 저한도 환경에서 대량 호출 후 /proc/self/fd 사이즈 확인. 2) 수정 예: try: f = os.fdopen(fd, "w", encoding="utf-8") 후 finally에서 명시 close 보강, 또는 fd와 f를 분리해 os.close(fd)를 finally에 추가. 다만 명세상 simple 구현 의도가 강해 그대로 두는 것도 trade-off |
| 심각도 제안 | good-to-fix |

## 3. 명세 / ADR 핵심 정책 부합성 (상세)

- Double-checked locking (ADR-0003): _get_lock이 defaultdict + _locks_guard 조합으로 name별 Lock을 원자 생성/조회. 락 안에서 `if not artifacts.is_stale: existing = artifact_path; return existing` 으로 신선한 아티팩트가 있으면 LLM 호출 없이 즉시 반환. 동시 요청 병합 의도와 일치.
- 1회 수정 재시도 (무한 금지): `if error is not None` 분기에서 정확히 한 번 더 llm.chat + _validate 시도, 실패 시 CompileError. OK.
- 검증 실패 시 dist 보존: _validate 실패 → CompileError raise → 8단계 (stale_artifact.unlink)와 10단계 (atomic_write) 모두 건너뜀. ADR-0008 "기존 캐시 유지" 정책 일치.
- 원자적 쓰기 (issue-20): artifacts.atomic_write가 부모 디렉토리 자동 생성을 포함. OK.
- 무한 재시도 차단: llm.chat( 호출이 정확히 2회 (초기 + 재시도) — regression-tests §5로 잠금.

## 4. 동시성 / 경계 조건 점검

- artifacts.is_stale=False 그리고 artifact_path=None 케이스: spec_path가 없으면 is_stale=False 가능, artifact_path가 None이면 continue, spec_file.exists()가 False라 FileNotFoundError. spec_path가 있는데 artifact가 없는 경우는 is_stale=True이므로 분기 미도달. OK.
- is_stale의 mtime 비교가 strict greater-than: spec_file과 artifact가 같은 mtime면 stale=False로 즉시 반환 — 명세 미명시이나 의도된 정책으로 판단. OK.
- _locks_guard 보호 없이 defaultdict를 동시 접근하면 두 스레드가 다른 Lock 인스턴스를 받을 수 있는 race가 존재하지만, _locks_guard로 atomic 보장. OK.
- 반대 확장자 삭제 (8단계) + atomic_write (10단계) 사이 race: 락 안에서 일어나므로 동시 진입 불가. atomic_write가 os.replace로 원자적 교체. OK.
- 락 보유 시간: LLM 호출 30~90초 + import gate. ADR-0003 의도된 동작 (동기 블로킹).
- _import_gate의 import gate는 validators.load_module이 sys.modules에 매번 새 모듈을 등록함 (협력자 영역). 본 컴파일러 본체 책임 외.

## 5. 종합

명세 + ADR-0003 + ADR-0008 모두 충족. 두 finding 모두 good-to-fix 수준이며:
- finding 1은 security note (위협 모델 명시 권장)
- finding 2는 이론적 fd 누수 가능성

must-fix 없음. 구현이 명세를 충실히 따르며 변경 파일 외 협력자에 대한 본체 책임 외 이슈는 본 리뷰 범위에서 제외.
