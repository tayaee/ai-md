모델명: Gemini 3.5 Flash (Medium)

# 코드 리뷰 결과: issue-5 (스캐폴딩 프롬프트 상수)

본 리뷰는 지정된 커밋 범위(`9dc73e5f9589d3838c71ba6faa513b3c48f670f8..da1be306a51a1c77dfd7a0b587efe757bd687d08`) 내 변경 사항을 바탕으로 진행되었습니다.

---

## 구조화 Finding 목록

### Finding 1: 회귀 테스트 스크립트의 작업 디렉토리(CWD) 의존성 문제
- **파일:라인**: [verify-issue-5.sh:5](file:///home/user1/git/ai-md/regression-tests/verify-issue-5.sh#L5)
- **코드 인용**:
  ```bash
  # 1. 파일 존재 여부 확인
  if [ ! -f "engine/aimd/prompts.py" ]; then
      echo "engine/aimd/prompts.py does not exist"
      exit 1
  fi
  ```
- **실패 시나리오**:
  사용자나 CI/CD 파이프라인이 프로젝트 루트 디렉토리가 아닌 `regression-tests/` 디렉토리 내부로 이동한 뒤 `./verify-issue-5.sh` 스크립트를 직접 실행하는 경우, 스크립트 내부에서 사용되는 파일 상대 경로(`engine/aimd/prompts.py`)를 찾지 못하여 `engine/aimd/prompts.py does not exist` 에러를 출력하고 즉시 실패합니다.
- **확인 방법**:
  1. 터미널에서 `cd /home/user1/git/ai-md/regression-tests` 명령을 실행하여 작업 디렉토리를 변경합니다.
  2. `./verify-issue-5.sh`를 실행합니다.
  3. 화면에 `engine/aimd/prompts.py does not exist` 에러가 출력되며 종료 코드 1로 실패하는 것을 확인합니다.
- **심각도 제안**: `must-fix`

---

### Finding 2: `set -e` 무력화 시 필수 상수 누락 검증 우회 가능성 (subshell `(exit 1)` 사용 오작동)
- **파일:라인**: [verify-issue-5.sh:16-19](file:///home/user1/git/ai-md/regression-tests/verify-issue-5.sh#L16-L19)
- **코드 인용**:
  ```bash
  grep -q "^CLASSIFY_SYSTEM" "engine/aimd/prompts.py" || (echo "CLASSIFY_SYSTEM constant missing"; exit 1)
  grep -q "^SPA_SYSTEM" "engine/aimd/prompts.py" || (echo "SPA_SYSTEM constant missing"; exit 1)
  grep -q "^API_SYSTEM" "engine/aimd/prompts.py" || (echo "API_SYSTEM constant missing"; exit 1)
  grep -q "^FIX_TEMPLATE" "engine/aimd/prompts.py" || (echo "FIX_TEMPLATE constant missing"; exit 1)
  ```
- **실패 시나리오**:
  스크립트 실행 중 `set -e` 옵션이 해제되거나(예: 다른 스크립트에서 `set +e` 상태로 `source` 명령을 통해 이 스크립트를 호출하는 경우), 명시적으로 `set -e`가 꺼진 환경에서 실행될 때, subshell `(...)` 내에서의 `exit 1`은 subshell 프로세스만 종료시킬 뿐 부모 쉘 스크립트를 중단시키지 못합니다. 이로 인해 필수 상수가 누락되었음에도 불구하고 경고 메시지만 출력한 채 pytest 실행 등으로 계속 진행되어 최종적으로 성공(exit code 0) 처리될 위험이 있습니다.
- **확인 방법**:
  1. `regression-tests/verify-issue-5.sh` 파일의 2행인 `set -e`를 주석 처리하거나 `set +e`로 변경합니다.
  2. `engine/aimd/prompts.py` 파일 내에서 임의로 `CLASSIFY_SYSTEM` 상수의 이름을 다른 것으로 변경하여 누락 상태를 만듭니다.
  3. 스크립트(`regression-tests/verify-issue-5.sh`)를 실행합니다.
  4. `CLASSIFY_SYSTEM constant missing` 문구가 출력되지만, 부모 쉘이 종료되지 않고 이어서 `cd engine` 및 pytest를 정상 실행하며 최종 종료 코드 0을 반환함을 확인합니다.
- **심각도 제안**: `good-to-fix`

---

### Finding 3: 회귀 테스트 스크립트 내 검증 명령과 스펙의 불일치 (`uv run` 의존성)
- **파일:라인**: [verify-issue-5.sh:29](file:///home/user1/git/ai-md/regression-tests/verify-issue-5.sh#L29)
- **코드 인용**:
  ```bash
  uv run pytest tests/test_prompts.py -q
  ```
- **실패 시나리오**:
  이슈 스펙([issue-5.md](file:///home/user1/git/ai-md/issues/archive/2026/07/13/issue-5.md#L65))에 명시된 완료 조건의 검증 명령은 `cd engine && python -m pytest tests/test_prompts.py -q`입니다. 하지만 회귀 테스트 스크립트에서는 `uv run pytest` 명령어를 사용하고 있어, `uv` 도구가 설치되어 있지 않은 환경(예: 순수 파이썬 환경의 컨테이너 등)에서는 스크립트 실행이 실패하게 됩니다.
- **확인 방법**:
  1. `uv` 도구가 설치되지 않은 환경이나 `PATH`에서 `uv`가 제외된 환경을 준비합니다.
  2. 프로젝트 루트에서 `./regression-tests/verify-issue-5.sh`를 실행합니다.
  3. `uv: command not found` 오류가 발생하며 회귀 테스트가 정상적으로 동작하지 못하는 것을 확인합니다.
- **심각도 제안**: `good-to-fix`

---

### Finding 4: 이슈 완료 문서상의 미래 구현 완료 일시 오기
- **파일:라인**: [issue-5.md:69](file:///home/user1/git/ai-md/issues/archive/2026/07/13/issue-5.md#L69)
- **코드 인용**:
  ```markdown
  - **구현 완료 일시**: 2026-07-13T06:10:00Z
  ```
- **실패 시나리오**:
  현재 실제 시간인 `2026-07-13T02:04:35-04:00` (UTC 기준 `2026-07-13T06:04:35Z`)보다 약 5분 뒤의 미래 시간인 `2026-07-13T06:10:00Z`로 구현 완료 일시가 기입되어 있습니다. 이는 타임스탬프 기록의 정합성에 맞지 않는 휴먼 에러입니다.
- **확인 방법**:
  1. 리뷰 대상인 커밋이 생성된 실제 시간(또는 현재 시스템 시간)과 문서상 기재된 `2026-07-13T06:10:00Z`를 대조하여 미래의 시각이 작성되어 있음을 확인합니다.
- **심각도 제안**: `good-to-fix`
