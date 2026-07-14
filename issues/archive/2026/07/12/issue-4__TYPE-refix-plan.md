# issue-4 refix plan

## 리뷰어별 finding 수

| 리뷰어 | 모델 | 총 finding | 형식 게이트 통과 | must-fix (승격) | good-to-fix | reject |
|---|---|---|---|---|---|---|
| gemini | unknown (첫 줄에 모델명 없음) | 5 | 4 | 2 | 1 | 2 |
| sonnet | Claude-Sonnet-5 | 5 | 5 | 0 | 4 | 1 |
| **합계** | | **10** | **9** | **2** | **5** | **3** |

## reject 사유

| finding | 출처 | 사유 |
|---|---|---|
| `extract_code` 중첩 펜스 표 일부 누락 | gemini | 증거 미비 (gate reject) |
| `load_module` 임의 .py 실행 (RCE) | gemini | 스펙 의도된 동작 (verify reject) — spec 51행 "import 중 예외는 그대로 전파한다(호출자가 잡는다)" 가 호출자 책임의 근거 |
| `load_module` 임의 .py 실행 | sonnet | 스펙 의도된 동작 (verify reject) — 동일 사유 |

## 분류 결과

### must-fix (승격, pending 파생 이슈)
1. **CRLF 펜스 미매칭** (gemini F1) → `issues/issue-21-fixing-4.md`
   - 파일:라인: `engine/aimd/validators.py:8`
   - 인용: `_FENCE_RE = re.compile(r"```[a-zA-Z0-9]*\n(.*?)```", re.DOTALL)`
   - 실패 시나리오: ```` ```python\r\n...\r\n``` ```` 입력 시 findall=[] 반환, raw 텍스트 그대로 strip
   - 재검증 결과: `[a-zA-Z0-9]*\n` 에서 `\r` 다음의 `\n` 매칭 실패 확인 — 인용 실재, 주장 성립
2. **언어식별자 직전 공백 미허용** (gemini F2) → `issues/issue-22-fixing-4.md`
   - 파일:라인: `engine/aimd/validators.py:8`
   - 인용: 동일 정규식
   - 실패 시나리오: ```` ``` python\n...\n``` ```` 입력 시 매칭 실패
   - 재검증 결과: `[a-zA-Z0-9]*` 매칭 후 `\n` 직전 문자가 공백이라 매칭 실패 — 인용 실재, 주장 성립

### good-to-fix (파킹, STATE-later)
1. **rstrip 동작 손실 가능성** (gemini F3) → `issue-23-fixing-4__STATE-later.md`
2. **중첩 펜스 lazy match 깨짐** (sonnet F1) → `issue-24-fixing-4__STATE-later.md`
   - 비고: gemini가 같은 결함을 F5로 보고했으나 표 일부 누락으로 gate reject. stats에는 sonnet만 반영.
3. **미닫힌 펜스 마커 노출** (sonnet F2) → `issue-25-fixing-4__STATE-later.md`
4. **`_counter` advance on failure** (sonnet F3) → `issue-26-fixing-4__STATE-later.md`
   - 비고: 의도된 동작이지만 docstring에 명시 부족 — 문서 보강 제안.
5. **`spec_from_file_location` None 가드 메시지** (sonnet F5) → `issue-27-fixing-4__STATE-later.md`

## 생성된 파생 이슈 목록

| 번호 | 파일 | 분류 | 비고 |
|---|---|---|---|
| 21 | `issues/issue-21-fixing-4.md` | pending (must-fix) | CRLF |
| 22 | `issues/issue-22-fixing-4.md` | pending (must-fix) | 언어식별자 공백 |
| 23 | `issues/issue-23-fixing-4__STATE-later.md` | later | rstrip |
| 24 | `issues/issue-24-fixing-4__STATE-later.md` | later | 중첩 펜스 |
| 25 | `issues/issue-25-fixing-4__STATE-later.md` | later | 미닫힌 펜스 |
| 26 | `issues/issue-26-fixing-4__STATE-later.md` | later | 카운터 advance |
| 27 | `issues/issue-27-fixing-4__STATE-later.md` | later | None 가드 메시지 |

## 정상 판정 항목 (재차 확인)

- `validate_html` 의 느슨한 검증(`"<html" in code.lower()`) — issue-4.md 39행 "느슨한 검증" 의도 부합.
- `validate_python` 의 `ast.parse` only — spec 의도 부합.
- `load_module` 의 `sys.modules` 미등록 + 매번 새 객체 + `hasattr` 게이트 — 5개 테스트로 보장됨.
- `load_module` 의 예외 전파 — `test_load_module_propagates_import_exception` 통과.
- `extract_code` 의 가장 긴 펜스 블록 선택 + trailing newline strip — 3개 테스트로 보장됨.
