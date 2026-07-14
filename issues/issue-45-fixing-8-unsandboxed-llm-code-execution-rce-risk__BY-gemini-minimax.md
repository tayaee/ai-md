# issue-45: compiler._import_gate — LLM이 생성한 코드를 샌드박스 없이 그대로 실행(RCE 위협 모델 미문서화) (good-to-fix)

## 상태


## 의존성
issue-8 완료 후

## 배경
gemini와 minimax가 issue-8 리뷰에서 독립적으로 같은 결함을 발견했다 (중복
finding 규칙 적용 — 파생 이슈는 1개만 생성, `agent-stats.json`의 count는 두
리뷰어 모두 각각 +1).

- gemini Finding 2 (**must-fix**로 제안): "격리되지 않은 호스트 환경에서의
  임포트 실행 (RCE 취약점)"
  > `validators.load_module(tmp_path)` ... 샌드박싱이나 격리 조치가 전혀 없는
  > 호스트 프로세스 권한 그대로 해당 파이썬 코드가 실행되므로... OWASP Top 10
  > A03:2021-Injection

- minimax Finding 1 (**good-to-fix**로 제안): "_import_gate에서 LLM 출력
  코드의 top-level 실행으로 인한 side-effect (security note)"
  > ADR-0008은 "import 검증이 곧 배포 게이트"로 의도된 동작이지만... 위협
  > 모델이 명세/PR 본문에 명시되어 있지 않음... 1회 수정 재시도가 발동되면
  > 두 번 실행됨

원본 리뷰 파일:
- `issues/issue-8__TYPE-code-review__BY-gemini.md` (Finding 2)
- `issues/issue-8__TYPE-code-review__BY-minimax.md` (finding 1)

## 재검증 결과 (must-fix 후보 재검토 → good-to-fix로 강등)
인용은 실재하고 "샌드박스 없이 LLM 코드를 exec한다"는 주장 자체는 사실이다.
그러나:

- 이는 ADR-0004(hot-swap single-host)와 ADR-0008("import 검증이 곧 배포
  게이트")이 명시적으로 채택한 기존 아키텍처 결정이며, issue-8이 새로 도입한
  결함이 아니다 (`validators.load_module`은 이전 이슈에서 이미 구현·리뷰된
  협력자 — `_import_gate`는 이슈-8 스펙이 그대로 지시한 방식으로 이를 호출할
  뿐이다).
- `README.md`가 이미 이 위험을 명시적으로 경고한다: "이 시스템은 LLM이
  생성한 코드를 그대로 실행합니다. 공인 인터넷에 상시 노출하지 마세요."
- minimax는 같은 근본 원인을 독립적으로 good-to-fix(위협 모델 문서화 권고)로
  분류했다 — 두 리뷰어의 판단이 심각도에서만 갈렸다.

따라서 "이 이슈(issue-8)의 코드가 새로 도입한 버그"로 보기 어렵고, 프로젝트
전체의 알려진 트레이드오프에 대한 강화(hardening) 티켓으로 good-to-fix
강등한다. 근거를 남기고 재분류 — **재검증 실패(설계상 기존에 승인된 위험)에
따른 강등**.

## 목표
- (승격 시) 위협 모델을 명세/문서에 명시하거나, 샌드박스 격리(subprocess +
  resource limits 등) 도입을 검토한다.
- 최소한 `docs/adr/` 또는 `README.md`에 "compile 검증 단계에서 LLM 생성
  코드가 호스트 권한으로 실행된다"는 사실을 더 눈에 띄게 문서화한다.

## 구현 상세(가이드)
- 문서화만 하는 경우: `docs/adr/0008-validation-retry-atomic-write.md` 또는
  `README.md`의 경고 문구에 "`_import_gate`/`load_module`이 격리 없이
  exec한다"는 사실을 한 줄 추가.
- 격리를 도입하는 경우: 별도 subprocess(`resource.setrlimit` + 제한된
  환경변수 등)로 import를 실행하고 성공/실패만 부모 프로세스로 전달하는 방식
  검토 (설계 변경 폭이 커서 별도 스파이크가 필요할 수 있음).

## 완료 조건(승격 후)
- [ ] 문서화 또는 격리 방식 중 선택한 방향에 맞는 완료 조건을 승격 시점에
      구체화

## 구현 결과
(구현 후 기록)
