# issue-30: verify-issue-5.sh가 spec의 `python -m pytest` 대신 `uv run pytest`에 의존 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
issue-5.md의 완료 조건에 명시된 검증 명령은
`cd engine && python -m pytest tests/test_prompts.py -q`이지만,
`regression-tests/verify-issue-5.sh:29`는 `uv run pytest ...`를 사용한다.
`uv`가 없는 환경에서는 회귀 스크립트가 실행되지 않는다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-gemini.md`
(Finding 3, good-to-fix).

## 검토 포인트
- `uv run pytest`는 이 저장소 전체 회귀 스크립트(1~27)의 기존 관행이며
  issue-5만의 문제는 아님 — 관행 자체를 바꿀지, spec 문구를 관행에 맞게
  갱신할지 결정 필요
- `uv`가 이 프로젝트의 사실상 표준 도구인지(README/docs 확인) 먼저 검토

## 권장 구현(가이드)
- (A) 전 회귀 스크립트를 `uv`가 없으면 `python -m pytest`로 폴백하도록 통일
- (B) 또는 `docs/`에 "본 프로젝트는 `uv`를 표준 도구로 가정한다"를 명문화하고 spec 문구를 갱신

## 완료 조건(승격 후)
- [ ] (A)/(B) 중 선택한 방침을 issue-5 및 관련 스크립트에 반영
- [ ] `bash regression-tests/verify-issue-5.sh` 통과 유지
