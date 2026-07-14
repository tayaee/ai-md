# issue-48: compiler._import_gate — os.fdopen/write 실패 시 fd가 close되지 않을 가능성 (good-to-fix)

## 상태


## 의존성
issue-8 완료 후

## 배경
minimax의 issue-8 리뷰 Finding 2(good-to-fix): `tempfile.mkstemp`로 얻은 fd를
`os.fdopen`으로 감싸는 과정 자체 또는 write 중 예외가 나면, outer
`except Exception`은 잡지만 fd가 명시적으로 close되지 않는 경로가 이론적으로
존재한다.

원본 리뷰 파일: `issues/issue-8__TYPE-code-review__BY-minimax.md` (finding 2)

인용:
> 코드 인용: `fd, tmp_name = tempfile.mkstemp(suffix=".py")` /
> `with os.fdopen(fd, "w", encoding="utf-8") as f:`
> 실패 시나리오: 디스크 풀, 시스템 fd 한도 도달... `os.fdopen` 자체 또는
> `f.write(code)`가 raise하면... fd는 close되지 않음

## 검토 포인트
- good-to-fix로 리뷰어가 직접 제안 — 재검증 생략(정책).
- 실제로 `os.fdopen(fd, "w")` 호출 자체가 실패하는 경우는 매우 드물다(파일
  디스크립터가 이미 유효하다고 가정하면 실패 확률 낮음) — 승격 시 실질 발생
  가능성 재평가가 필요하다.

## 권장 구현(가이드)
승격한다면 fd 획득과 파일 쓰기를 try/finally로 감싸 명시적으로 `os.close(fd)`를
보강하거나, `tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False)`로
대체해 컨텍스트 매니저가 자체적으로 안전하게 닫도록 리팩터링한다.

## 완료 조건(승격 후)
- [ ] fd 누수 시나리오를 재현하는 테스트(또는 코드 리뷰로 대체) 후 수정 확인

## 구현 결과
(구현 후 기록)
