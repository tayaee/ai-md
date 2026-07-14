# issue-42: classify 로그 형식을 spec docstring 단일 형식으로 통일

## 의존성
issue-7 완료 후

## 배경

issue-7 리뷰 사이클에서 gemini가 보고한 must-fix finding:

> **Finding G1** (engine/aimd/classifier.py:42-45) — LLM이 예상 외 답변을 반환했을 때
> `"LLM classification returned unexpected answer %r, falling back to keywords"`로
> 로그를 남기는데, 이는 spec docstring의 단일 로그 형식
> `log.warning("LLM classification failed, falling back to keywords: %s", ...)`과 다르다.

원본 리뷰 파일:
- `issues/issue-7__TYPE-code-review__BY-gemini.md` (Finding 1)

재검증 결과: 인용된 파일:라인이 실재함 (`classifier.py:42-49`), spec docstring
(`issues/archive/2026/07/13/issue-7-add-classifier.md:32` 의 `classify` 함수 본문)이
명시한 단일 로그 형식과 다름. 주장 성립 — **must-fix 승격 확정**.

## 목표

`classify()`가 LLM의 예상 외 답변을 받았을 때도 spec docstring이 명시한 단일
로그 형식으로 warn을 남기도록 수정한다. 두 폴백 경로(unexpected answer /
Exception)의 로그 형식을 통일한다.

## 구현 상세

파일: `engine/aimd/classifier.py`

**Spec docstring (이슈-7 구현 명세)**:
```python
def classify(spec_text: str, settings: Settings) -> Target:
    """llm.chat(CLASSIFY_SYSTEM, spec_text, settings)를 호출한다.
    - 응답을 strip().upper()해서 "SPA"면 "spa", "API"면 "api"
    - 그 외 답변이거나 Exception이 나면:
      log.warning("LLM classification failed, falling back to keywords: %s", ...)
      후 classify_by_keywords 결과를 반환
    """
```

**현재 구현 (위반 부분)**:
```python
try:
    response = llm.chat(CLASSIFY_SYSTEM, spec_text, settings)
    answer = response.strip().upper()
    if answer == "SPA":
        return "spa"
    if answer == "API":
        return "api"
    log.warning(
        "LLM classification returned unexpected answer %r, falling back to keywords",
        response,
    )
except Exception as e:
    log.warning(
        "LLM classification failed, falling back to keywords: %s", e
    )
return classify_by_keywords(spec_text)
```

**수정 후 (목표)**:
두 폴백 경로 모두 spec docstring과 동일한 단일 로그 형식 사용:
```python
try:
    response = llm.chat(CLASSIFY_SYSTEM, spec_text, settings)
    answer = response.strip().upper()
    if answer == "SPA":
        return "spa"
    if answer == "API":
        return "api"
    log.warning(
        "LLM classification failed, falling back to keywords: %s", response
    )
except Exception as e:
    log.warning(
        "LLM classification failed, falling back to keywords: %s", e
    )
return classify_by_keywords(spec_text)
```

## 실패 시나리오 (재현)

```python
import logging
from unittest.mock import patch
from aimd import classifier
from aimd.config import Settings

settings = Settings(api_key="k", base_url="http://t", model="MiniMax-M3",
                    max_tokens=8192, src_dir="./src", dist_dir="./dist")

# 현재 동작
with patch.object(classifier.llm, "chat", return_value="MAYBE"):
    with patch.object(classifier, "log") as mock_log:
        classifier.classify("anything", settings)
        # mock_log.warning 호출 인자: ("LLM classification returned unexpected answer %r...", "MAYBE")
        # → spec docstring의 단일 형식과 불일치
```

수정 후:
```python
# mock_log.warning 호출 인자: ("LLM classification failed, falling back to keywords: %s", "MAYBE")
# → spec 형식과 일치
```

## 하지 말 것
- 분류 결과 캐싱 금지 (ADR-0005) — 변경 없음.
- 응답 후처리 (`strip().upper()`) 변경 금지 — spec에 명시.

## 완료 조건
- `engine/tests/test_classifier.py`에 unexpected-answer 경로의 로그 형식을 검증하는 테스트 추가
- `cd engine && uv run python -m pytest tests/test_classifier.py -q` 통과
- `regression-tests/verify-issue-42.sh` 작성 + 실행 통과
- 다른 모든 회귀 스크립트도 통과 유지

## 구현 결과

**구현 완료 일시**: 2026-07-13T19:10:27Z
**변경 파일**:
- engine/aimd/classifier.py (로그 형식 통일)
- engine/tests/test_classifier.py (로그 형식 검증 테스트 2건 추가)
- regression-tests/verify-issue-42.sh (신규)
- issues/issue-42__TYPE-agent-stats.json (신규)

**스펙 대비 deviation**: 없음.

**verify 결과**:
- 회귀 스크립트 (`regression-tests/verify-issue-42.sh`) 통과.
- 전체 pytest: 44 passed.
- 전체 회귀 스크립트: 11/11 통과.