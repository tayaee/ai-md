# issue-35: verify-issue-5.sh의 상수명 grep이 주석·접두어까지 과매칭 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`regression-tests/verify-issue-5.sh:16-19`의
`grep -q "^CLASSIFY_SYSTEM" ...`는 `# CLASSIFY_SYSTEM: 옛 분류 프롬프트` 같은
주석 줄에도 매칭된다. 실질적인 1차 방어선 역할은 거의 못 하며(뒤이은
pytest의 ImportError가 실제 방어선), 방어 심도가 낮다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 4, good-to-fix).

## 검토 포인트
- `^[A-Z_]+ =` 형태의 실제 할당 행만 매칭하도록 grep 패턴을 좁힐지 검토

## 권장 구현(가이드)
```bash
grep -q "^CLASSIFY_SYSTEM = " "engine/aimd/prompts.py" || (echo "CLASSIFY_SYSTEM constant missing"; exit 1)
```

## 완료 조건(승격 후)
- [ ] grep이 실제 할당 행만 매칭하고 주석은 매칭하지 않음을 확인
- [ ] `bash regression-tests/verify-issue-5.sh` 정상 케이스 회귀 없음
