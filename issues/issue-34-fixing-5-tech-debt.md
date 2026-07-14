# issue-34: verify-issue-5.sh의 "no functions/classes" grep이 async def/들여쓴 정의를 누락 (good-to-fix)

## 상태


## 의존성
issue-5 완료 후

## 배경
`regression-tests/verify-issue-5.sh:22`의 `grep -qE "^(def |class )"`는
`async def`나 들여쓴 정의를 매칭하지 못한다. issue-5.md는 "상수 4개뿐인
파일"을 명시하지만 이 회귀 스크립트만으로는 그 제약이 완전히 보장되지
않는다.

리뷰 출처: `issues/archive/2026/07/13/issue-5__TYPE-code-review__BY-minimax.md`
(Finding 3, good-to-fix).

## 검토 포인트
- `^(def |async def |class )`로 확장할지, 아니면 `ast` 모듈로
  `FunctionDef`/`AsyncFunctionDef`/`ClassDef` 부재를 파싱 검사할지 결정

## 권장 구현(가이드)
```bash
if grep -qE "^(def |async def |class )" "engine/aimd/prompts.py"; then
    echo "prompts.py must contain constants only, no functions/classes"
    exit 1
fi
```

## 완료 조건(승격 후)
- [ ] `async def`/`class` 추가 시 회귀 스크립트가 실패로 감지
- [ ] `bash regression-tests/verify-issue-5.sh` 정상 케이스 회귀 없음
