# ADR-0009: 배포·보안 — 로컬 Docker Desktop + ngrok 일시 공개

상태: 승인 (2026-07-12)

## 맥락

이 시스템은 LLM이 생성한 Python 코드를 컨테이너 안에서 그대로 실행한다.
LLM 출력은 원리적으로 신뢰 불가 입력이다. 또 컴파일 트리거가 공개되면
임의 방문자가 소유자의 MiniMax 키로 비용을 유발할 수 있다.
GitHub Pages는 정적 호스팅 전용이라 엔진 실행이 불가함을 확인했다.

## 결정

- **실행 환경**: 로컬 Docker Desktop(WSL2). `docker compose up` → `localhost:8080`.
- **일시 공개**: `ngrok http --basic-auth="user:pass" 8080` — basic auth로
  임의 방문자의 컴파일 트리거(LLM 비용 유발)를 차단한다.
- **공인망 상시 노출 금지**. README에 경고를 명시한다.
- 샌드박스(gVisor 등)는 넣지 않는다(POC 범위 초과). 대신 공짜 방어선 3개:
  ① 컨테이너 비루트(uid 1000) 실행, ② `src/` 읽기 전용 마운트
  (생성 코드가 명세 원본을 못 건드림), ③ engine 포트 호스트 비바인딩.
- **공개 리포 위생**: `.env`는 gitignore, `.env.example`만 커밋.
  `LLM_API_KEY`는 어떤 파일에도 커밋 금지.
- **`dist/` 산출물은 리포에 커밋**한다 — 클론한 사람이 키 없이
  `docker compose up`만으로 즉시 동작하는 데모를 보게 하고, "Frozen Artifact"
  개념을 리포에 시각적으로 드러낸다.
- 소스는 gitlab.local(origin)에서 관리, 검증 후 GitHub 이전 예정.
- 에러 로그는 간결한 영어(초안 6장 조항 유지).

## 결과

- 개인 키가 리포·아티팩트 어디에도 노출되지 않는다.
- 키 없는 사용자: 얼린 데모 체험. 키 있는 사용자: 재컴파일까지 2단계 데모.
