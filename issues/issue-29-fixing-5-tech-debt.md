# issue-29: verify-issue-5.sh의 subshell `(exit 1)`이 `set -e` 무력화 시 상위 셸을 중단시키지 못함 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`regression-tests/verify-issue-5.sh:16-19` 의
`grep -q "^CLASSIFY_SYSTEM" ... || (echo ...; exit 1)` 패턴은, `set -e`가
해제되거나 다른 스크립트에서 `source`로 호출되는 경우 subshell 안의
`exit 1`이 부모 셸을 종료시키지 못해 필수 상수 누락 검증이 우회될 수 있다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-gemini.md`
(Finding 2, good-to-fix).

## 검토 포인트
- 동일 패턴이 `verify-issue-4.sh` 등 다른 스크립트에도 존재하는지 확인 후
  일괄 정리 여부 결정
- `set -e`가 정상 동작하는 한(현재 스크립트를 직접 `bash`로 실행하는 한)
  실제 발현 조건은 제한적임에 유의

## 권장 구현(가이드)
subshell 대신 `if ! grep -q ...; then echo ...; exit 1; fi` 형태로 변경해
subshell 종속성을 제거.

## 완료 조건(승격 후)
- [ ] `set +e` 상태에서도 필수 상수 누락 시 스크립트가 실패로 종료됨을 확인
- [ ] `bash regression-tests/verify-issue-5.sh` 정상 케이스 회귀 없음
