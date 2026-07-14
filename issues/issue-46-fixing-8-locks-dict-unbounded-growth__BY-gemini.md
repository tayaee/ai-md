# issue-46: compiler._locks — 파일별 Lock 객체가 정리되지 않아 장기 실행 시 무한 누적 (good-to-fix)

## 상태


## 의존성
issue-8 완료 후

## 배경
gemini의 issue-8 리뷰 Finding 4(good-to-fix): `_locks`가
`defaultdict(threading.Lock)`로 무제한 누적되고 정리 메커니즘이 없다.

원본 리뷰 파일: `issues/issue-8__TYPE-code-review__BY-gemini.md` (Finding 4)

인용:
> 코드 인용: `_locks: dict[str, threading.Lock] = defaultdict(threading.Lock)`
> 실패 시나리오: 롱러닝 서버 환경에서... 무제한으로 등록함. 완료된 락에 대해
> 사후 제거 메커니즘이 전혀 존재하지 않기 때문에... 메모리 점유율이 지속적으로
> 상승

## 검토 포인트
- good-to-fix로 리뷰어가 직접 제안 — 재검증 생략(정책).
- POC 단계에서는 고유 명세 파일 수가 제한적이라(실사용 `.ai.md` 파일 개수만큼)
  실질 위험이 낮을 수 있음 — 승격 여부는 사람이 트래픽 패턴을 보고 판단한다.

## 권장 구현(가이드)
승격한다면 `weakref` 기반 또는 명시적 락 해제 카운터를 도입하거나, `_locks`의
크기가 임계치를 넘으면 미사용 락을 정리하는 별도 청소 루틴을 검토한다.

## 완료 조건(승격 후)
- [ ] 반복 호출 후 `len(compiler._locks)`가 무한정 늘어나지 않음을 확인하는
      테스트 추가

## 구현 결과
(구현 후 기록)
