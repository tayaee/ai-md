# issue-1: 리포 뼈대 및 POC 시나리오 명세 파일 생성

## 의존성
없음 (첫 이슈)

## 목표
로직 없이 디렉토리 구조와 정적 파일만 만든다. 코드는 한 줄도 작성하지 않는다.

## 배경
- docs/SPEC.md 7장 (코드 배치), docs/adr/0009-deployment-security.md

## 구현 상세

다음 파일들을 정확히 이 내용으로 생성한다.

### 1. `.gitignore`
```
.env
__pycache__/
*.pyc
.pytest_cache/
```

### 2. `.env.example`
```
# MiniMax 글로벌(minimax.io) API 키. https://platform.minimax.io 에서 발급.
LLM_API_KEY=your-key-here
# 아래는 전부 선택 (기본값 있음)
#LLM_BASE_URL=https://api.minimax.io/v1
#LLM_MODEL=MiniMax-M3
#LLM_MAX_TOKENS=200000
```

### 3. `engine/requirements.txt`
```
fastapi>=0.115
uvicorn>=0.30
openai>=1.40
watchdog>=4.0
```

### 4. `engine/requirements-dev.txt`
```
pytest>=8.0
httpx>=0.27
```

### 5. `engine/aimd/__init__.py` — 빈 파일
### 6. `engine/tests/__init__.py` — 빈 파일
### 7. `dist/.gitkeep` — 빈 파일

### 8. `src/index.ai.md`
```markdown
# AIMD 메인 랜딩 페이지
이 페이지는 AIMD 프로젝트의 개념을 증명하는 테트리스 게임 내장 랜딩 페이지다.

## 디자인 규칙
- 테마: 터미널 다크 모드 (검은색 배경, 녹색 텍스트).
- 화면 중앙에 10x20 그리드의 테트리스 보드를 렌더링한다.

## 기능 요구사항
- 사용자가 키보드 방향키로 블록을 움직일 수 있어야 한다.
- 스코어보드가 실시간으로 작동해야 하며, 한 줄이 깨질 때마다 100점씩 올라간다.
```

### 9. `src/convert.ai.md`
```markdown
# 온도 변환 마이크로 서비스 API

## 라우팅 규칙
- POST /convert 엔드포인트를 개설한다.
- 입력값 규칙 (JSON): {"temperature": 30, "type": "C"} (type은 C 또는 F)

## 비즈니스 로직
- type이 "C"이면 섭씨를 화씨로 변환하여 리턴한다.
- type이 "F"이면 화씨를 섭씨로 변환하여 리턴한다.
- 출력값 규칙 (JSON): {"result": 변환된_값}
```

### 10. `README.md`
제목 `# AIMD — AI-powered Markdown Engine`과 다음 내용 포함:
- 한 줄 소개: ".ai.md 자연어 명세가 URL과 1:1 매핑되어 LLM으로 컴파일·서빙되는 POC"
- 실행법: `cp .env.example .env` 후 키 입력 → `docker compose up` → `http://localhost:8080`
- 경고 문단(굵게): "이 시스템은 LLM이 생성한 코드를 그대로 실행합니다. 공인 인터넷에 상시 노출하지 마세요. 일시 공개는 `ngrok http --basic-auth="user:pass" 8080`을 사용하세요."
- 문서 링크: docs/SPEC.md, docs/adr/

## 하지 말 것
- Python 로직, nginx 설정, Dockerfile 작성 금지 (뒤 이슈에서 한다).
- `.env` 파일 생성 금지 (example만).

## 완료 조건
- [ ] 위 10개 파일이 정확한 경로에 존재
- [ ] `git status`에 `.env`가 나타나지 않음 (gitignore 동작)
- 검증 명령: `test -f src/index.ai.md && test -f src/convert.ai.md && test -f engine/requirements.txt && echo OK`

## 구현 결과

- **구현 완료 일시**: 2026-07-13T01:30:50Z
- **변경 파일**: `.gitignore`, `.env.example`, `engine/requirements.txt`, `engine/requirements-dev.txt`, `engine/aimd/__init__.py`, `engine/tests/__init__.py`, `dist/.gitkeep`, `src/index.ai.md`, `src/convert.ai.md`, `README.md`, `regression-tests/verify-issue-1.sh`
- **계획과의 차이**: 없음 — 명세된 10개 파일을 정확한 경로·내용으로 생성. 추가로 tdd2 표준 절차에 따라 `regression-tests/verify-issue-1.sh`(회귀 스크립트, spec에 명시되지 않았으나 모든 이슈 공통 절차)를 작성함 — spec 위반이 아닌 절차상 필수 산출물.
- **검증 결과**: `regression-tests/verify-issue-1.sh` 통과 (OK). 회귀 스위트: 이 이슈가 첫 이슈라 다른 검증 스크립트 없음. Python 코드가 없는 순수 스캐폴딩 이슈라 ruff/pyright/pytest는 해당 사항 없음(`pyproject.toml` 미존재).
