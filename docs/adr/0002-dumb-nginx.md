# ADR-0002: 멍청한 Nginx + 이벤트 기반 신선도 관리

상태: 승인 (2026-07-12)

## 맥락

초안 룰 3은 Nginx가 src와 dist의 mtime을 비교해 stale 판정을 하라고 요구했다.
순정 Nginx는 두 파일의 mtime 비교가 불가능하다(OpenResty/Lua 또는 njs 필요).
또 룰 1~2는 Nginx가 파일이 SPA인지 API인지 알아야 하는데, 이는 dist의
산출물 확장자를 봐야만 알 수 있다.

## 결정

Nginx는 두 가지만 한다:

1. `try_files $uri.html @engine` — `dist/<경로>.html`이 존재하면 즉시 정적 서빙 (1ms 목표).
2. 그 외 모든 요청은 engine(8000)으로 프록시 (`proxy_read_timeout 300s`).

신선도 판정은 전부 Python이 담당한다:
- **1차: watchdog** — `src/` 저장 이벤트 시 즉시 선컴파일 (요청 경로에서 stale 판정 자체가 불필요해짐).
- **2차: 요청 시 이중 체크** — engine에 도달한 요청은 mtime을 한 번 더 비교 (Python에선 한 줄).

## 결과

- nginx.conf가 ~20줄로 유지되고 Lua/njs 의존성이 없다.
- mtime 로직이 Python 한 곳에만 존재해 테스트가 쉽다.
- 트레이드오프: src 저장 직후 watchdog 컴파일이 끝나기 전의 짧은 창에서
  nginx가 stale HTML을 정적 서빙할 수 있다. POC에서 수용한다.
