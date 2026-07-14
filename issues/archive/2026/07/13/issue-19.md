# issue-19: list_specs의 src_dir 비정상 경로 대응 (fixing issue-3)

## 의존성
issue-3 완료 후

## 계보
- **원본 이슈**: issue-3 (artifacts.py — 경로 매핑·신선도 판정·원자적 쓰기)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-3__TYPE-code-review__BY-minimax.md` (Finding 1)
- **인용**: "`settings.src_dir`이 실제로 디렉토리가 아닌 일반 파일이거나, 읽기 권한이 없는 디렉토리일 경우 `iterdir()` 호출은 각각 `NotADirectoryError` 또는 `PermissionError`를 던지며 크래시가 발생함."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 심각도는 리뷰어 제안(good-to-fix)을 그대로 채택.

## 목표
`engine/aimd/artifacts.py`의 `list_specs` 함수에서 `src_dir`이 디렉토리가 아니거나 권한 문제가 있을 때 발생할 수 있는 크래시 예외를 안전하게 처리한다.

## 배경
- `list_specs` 함수는 `src_dir`이 없을 경우 빈 리스트를 리턴하고 있으나, 파일인데 디렉토리처럼 지정되어 `exists()`는 참이고 `iterdir()`에서 터지는 상황은 방어하지 못한다.

## 구현 상세
`engine/aimd/artifacts.py` 내의 `list_specs` 함수를 수정한다:
- `settings.src_dir.exists()` 체크 외에 `settings.src_dir.is_dir()` 인지도 체크하여 참일 때만 리스트를 모으고, 그렇지 않으면 `[]`를 반환하도록 한다.
- 혹은 전체를 `try-except OSError`로 감싸 안전하게 처리한다.

## 하지 말 것
- 정상적인 `*.ai.md` 파일을 목록화하여 정렬 반환하는 기존 사양은 변경하지 않는다.

## 완료 조건
- [ ] `src_dir`이 일반 파일로 지정된 설정 객체로 `list_specs`를 호출했을 때, 크래시 없이 `[]`를 반환함
- 검증 명령: `cd engine && python -m pytest tests/test_artifacts.py -q` (기존 테스트 통과 유지)

## 구현 결과
- **구현 완료 일시**: 2026-07-13T23:02:16Z
- **변경 파일**:
  - `engine/aimd/artifacts.py` — `list_specs`에 `is_dir()` 가드 + `try-except OSError` 추가. src_dir이 없거나 디렉토리가 아니거나 권한이 없는 경우 `[]` 반환
  - `engine/tests/test_artifacts.py` — `test_list_specs_src_is_regular_file`(비정상 경로), `test_list_specs_src_does_not_exist`(부재 경로) 두 케이스 추가
  - `regression-tests/verify-issue-19.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-19.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 이슈는 "is_dir 체크 또는 try-except OSError" 중 하나만 제안했지만 **둘 다 적용** — 두 방어가 서로 다른 실패 모드(파일 지정 vs 권한 거부)를 커버해 단일 가드만으론 한쪽이 뚫림. 코드 변경은 4줄 안팎.
- **검증 결과**:
  - `uv run pytest tests/test_artifacts.py -q` (engine/) → **7 passed** (기존 5 + 신규 2)
  - `bash regression-tests/verify-issue-19.sh` → **OK** — 가드 존재 + .ai.md 필터·sorted() 사양 보존 + pytest 통과
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 15개) → **모두 통과** (19 새로 포함)
- **선행 상태 메모**: issue-3 자체의 commit은 보이지 않지만(현재 main history에 issue-3 단독 커밋 없음) `bf90e1a feat: Add issue tracking and code review documentation for issues 4 to 9` 커밋에 artifacts.py가 함께 추가되어 tracked 상태. issue-3가 별도 `issue-3:` prefix 커밋으로 분리되지 않은 점이 우려지만, 본 이슈 19의 fix 적용 자체에는 지장 없음.
