# ADR-0001: URL 계약 — PHP식 1:1 매핑 + 파일 단위 서브 마운트

상태: 승인 (2026-07-12)

## 맥락

초안 명세에 내부 모순이 있었다. 라우팅 룰은 "`.ai.md` 확장자가 보이는 URL"을
정의했는데(`/src/convert.ai.md`), 시나리오 B 본문은 확장자 없는
"`POST /convert` 엔드포인트 개설"을 요구했다.

## 결정

`.php`와 같은 해석 모델을 채택한다: **`.ai.md` 파일 하나 = 미니 앱 하나**,
파일 경로가 URL prefix가 되고, 명세 본문의 라우트는 그 prefix **하위에** 마운트된다.

- `GET /index.ai.md` → 컴파일된 SPA HTML
- `GET /convert.ai.md` → 해당 API 앱의 Swagger UI(`/docs`로 302)
- `POST /convert.ai.md/convert` → 명세 본문이 정의한 실제 엔드포인트
- `GET /` → `/index.ai.md`로 302, 대응 파일 없는 경로 → 404

## 결과

- 파일 1:1 매핑 철학과 명세 본문 라우팅이 모순 없이 공존한다.
- URL에 `.ai.md`가 그대로 노출되어 POC의 데모 가치(자연어 파일이 곧 앱)가 산다.
- FastAPI 서브앱의 자동 `/docs`가 prefix 하위에서 공짜로 나온다.
