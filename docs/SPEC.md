# AIMD (AI-powered Markdown Engine) — 확정 사양서 v1

> 이 문서가 유일한 권위 있는 사양이다. 초기 초안 명세와 충돌하면 이 문서가 이긴다.
> 개별 결정의 근거는 `docs/adr/` 참조. 구현 작업 단위는 `issues/` 참조.

## 1. 개념

`.ai.md` 자연어 명세 파일이 URL과 1:1 매핑되어, 첫 요청(또는 파일 저장) 시
LLM(MiniMax)으로 컴파일되고, 이후에는 얼린(Frozen) 아티팩트가 서빙되는
AI-Native 웹 엔진의 POC. PHP의 파일 기반 라우팅 모델을 계승한다.

- `src/*.ai.md` — 인간이 쓰는 자연어 명세 (읽기 전용 영역)
- `dist/*.ai.md.html` / `dist/*.ai.md.py` — 기계가 구운 아티팩트 (캐시 영역)
- `public/` — `.ai.md` 파이프라인 밖의 순수 정적 자산 (LLM이 만들지 않음)

## 2. URL 계약 (ADR-0001)

**`.ai.md` 파이프라인은 URL이 `.ai.md` 확장자를 가질 때만 적용된다.** 그 외
경로(루트 `/` 포함)는 전적으로 nginx의 일반 정적 서빙 규칙을 따르고 엔진/LLM과
무관하다. `.ai.md` 파일 하나 = 미니 앱 하나, 파일 경로가 URL prefix가 된다.

| 요청 | 동작 |
|---|---|
| `GET /` | `public/index.html` 정적 서빙 (엔진을 거치지 않음) |
| `GET /tetris.ai.md` | `dist/tetris.ai.md.html` 반환 (테트리스 SPA) |
| `GET /convert.ai.md` | `302 → /convert.ai.md/docs` (Swagger UI) |
| `POST /convert.ai.md/convert` | 명세가 정의한 실제 엔드포인트 |
| 그 외 `.ai.md` 경로 (`src/`에 대응 파일 없음) | `404` |
| 컴파일 최종 실패 + 기존 캐시 없음 | `502` + JSON 에러 본문 |

명세 본문 안의 라우팅 규칙(예: "POST /convert")은 해당 파일 prefix 하위에 마운트된다.

## 3. 아키텍처 (ADR-0002, ADR-0007)

컨테이너 2개.

```
[브라우저] → :8080 nginx ──(`/` → public/index.html 정적 서빙, engine 안 거침)
                     ├─(dist/*.html 있으면 try_files 정적 서빙)
                     └─(그 외 `.ai.md` 전부)→ engine:8000 (호스트 비바인딩)

engine (단일 Python 프로세스, uvicorn):
  ├─ ASGI 디스패처 (main.py) — URL 계약 구현, lazy 컴파일 트리거
  ├─ AppRegistry (registry.py) — dist/*.py 동적 import + 핫스왑
  ├─ 컴파일러 (compiler.py) — 분류→프롬프트→LLM→검증→원자적 쓰기
  └─ watchdog 스레드 (watcher.py) — src/ 저장 이벤트 시 선컴파일
```

- Nginx는 멍청하다: `location = /`는 `public/index.html` 고정 서빙, 그 외는
  `try_files $uri.html @engine` + 프록시 폴백만 한다.
  mtime 신선도 판정은 전부 Python 쪽 책임 (watchdog 이벤트 + 요청 시 이중 체크).
- 볼륨: `src/` → engine 읽기 전용. `dist/` → engine 쓰기, nginx 읽기 전용.
  `public/` → nginx 읽기 전용 (engine은 마운트하지 않음 — 이 파이프라인과 무관).

## 4. 컴파일 파이프라인 (ADR-0003, ADR-0005, ADR-0008)

```
읽기(src) → 분류(LLM 1단어 호출, 실패 시 키워드 폴백)
  → 스캐폴딩 프롬프트 선택(SPA/API) → LLM 생성 호출(temperature 0.0)
  → 코드 추출(마크다운 펜스 제거) → 검증
  → [실패 시] 에러 피드백 포함 수정 재요청 1회 → 재검증
  → 통과 시 tmp 파일 + os.replace 원자적 쓰기 → dist/
  → [최종 실패 시] 기존 캐시 유지, 영어 에러 로그 1줄
```

- 첫 요청은 동기 블로킹 (nginx `proxy_read_timeout 300s`).
- 파일별 `threading.Lock`으로 동시 첫 요청의 LLM 중복 호출을 병합.
- 검증 기준: API = `ast.parse` + 실제 import + `app` 객체(FastAPI) 존재.
  SPA = 비어있지 않음 + `<html` 포함 + 펜스 제거 완료 (느슨하게).

## 5. 런타임 핫스왑 (ADR-0004)

uvicorn은 호스트 앱 하나만 상시 구동. `dist/*.ai.md.py`는 importlib로
매번 새 모듈 객체로 로드하고, 성공 시에만 레지스트리 dict의 참조를 교체한다.
import 실패 시 기존 모듈이 그대로 서빙된다. 프로세스 재시작 없음.

서브앱 호출 시 ASGI scope를 조정한다:
`root_path="/<파일명>.ai.md"`, `path=<하위경로 또는 "/">`.
이 덕분에 FastAPI 서브앱의 `/docs`, `/openapi.json`이 prefix 하위에서 그대로 동작한다.

## 6. LLM 연동 (ADR-0006)

환경 변수 (필수 표기 없으면 기본값 존재):

| 변수 | 기본값 | 설명 |
|---|---|---|
| `LLM_API_KEY` | (없음, 필수) | 글로벌(minimax.io) 키 |
| `LLM_BASE_URL` | `https://api.minimax.io/v1` | OpenAI-호환 베이스 URL |
| `LLM_MODEL` | `MiniMax-M3` | 생성·분류 공용 모델 |
| `LLM_MAX_TOKENS` | `200000` | 출력 토큰 상한 |
| `AIMD_SRC_DIR` | `./src` | 명세 디렉토리 |
| `AIMD_DIST_DIR` | `./dist` | 아티팩트 디렉토리 |

- `temperature=0.0` 고정.
- `max_tokens` 초과로 API가 400을 돌려주면 값을 절반으로 줄여 재시도
  (최대 6회, 하한 4096) — 어떤 모델 상한이 걸려 있어도 항상 동작.
- OpenAI 공식 Python SDK(`openai`)를 클라이언트로 사용.

## 7. 코드 배치

```
/ (repo root = 컨테이너 /opt/aimd)
├── docker-compose.yml
├── .env.example            # 키 견본 (실제 .env는 gitignore)
├── nginx/nginx.conf
├── engine/
│   ├── Dockerfile          # 비루트(uid 1000) 실행
│   ├── requirements.txt    # fastapi, uvicorn, openai, watchdog
│   ├── aimd/               # 파이썬 패키지
│   │   ├── config.py       # Settings, load_settings()
│   │   ├── artifacts.py    # 경로 매핑, is_stale, atomic_write
│   │   ├── validators.py   # extract_code, validate_*, load_module
│   │   ├── prompts.py      # 프롬프트 상수 4종
│   │   ├── llm.py          # chat() — 클램프 재시도 포함
│   │   ├── classifier.py   # classify() — LLM + 키워드 폴백
│   │   ├── compiler.py     # compile_spec() — 파이프라인 + 파일락
│   │   ├── registry.py     # AppRegistry — 핫스왑
│   │   ├── watcher.py      # watchdog 스레드
│   │   └── main.py         # ASGI 디스패처 `app`
│   └── tests/              # pytest (LLM은 전부 mock)
├── src/                    # tetris.ai.md, convert.ai.md
├── dist/                   # 컴파일 산출물 — 리포에 커밋한다 (ADR-0009)
└── public/                 # index.html — 손으로 작성한 랜딩 페이지 (정적, LLM 무관)
```

## 8. 배포·보안 (ADR-0009)

- 개발·데모: 로컬 Docker Desktop(WSL2). `docker compose up` → `http://localhost:8080`.
- 일시 공개: `ngrok http --basic-auth="user:pass" 8080` — 임의 방문자의 LLM 비용 유발 차단.
- 공인망 상시 노출 금지 (LLM 생성 코드가 그대로 실행되는 시스템임). README에 경고 명시.
- `.env` gitignore, `dist/` 커밋(키 없이 클론 즉시 데모 가능), 에러 로그는 영어 1줄.

## 9. POC 시나리오 (수용 기준)

- `src/tetris.ai.md`: 터미널 다크 테마(검정 배경/녹색 텍스트) 테트리스 SPA.
  10x20 보드, 방향키 조작, 줄 제거당 +100점 실시간 스코어보드.
- `public/index.html`: 애플 스타일의 미니멀한 랜딩 페이지 (손으로 작성한 정적
  HTML, `.ai.md` 파이프라인 밖). tetris/convert 데모로 가는 트리거 카드 2개.
- `src/convert.ai.md`: `POST /convert`, 입력 `{"temperature": 30, "type": "C"}`
  (type은 "C"|"F"), C→F 또는 F→C 변환, 출력 `{"result": <값>}`.
- E2E: ① 캐시 없는 상태에서 첫 요청 → 블로킹 컴파일 → 정상 응답,
  ② 캐시 있는 상태 → nginx가 LLM 없이 즉시 서빙,
  ③ src 저장 → watchdog 재컴파일 → 무중단 반영,
  ④ 컴파일 실패 주입 → 기존 캐시로 계속 서빙.
