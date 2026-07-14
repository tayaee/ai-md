# issue-7: classifier.py — SPA/API 유형 판별

## 의존성
issue-5, issue-6 완료 후

## 목표
명세 텍스트를 `"spa"` 또는 `"api"`로 판별. LLM 우선, 실패 시 키워드 폴백.

## 배경
- docs/adr/0005-llm-intent-classification.md

## 구현 상세

파일: `engine/aimd/classifier.py`

```python
import logging
from typing import Literal

from . import llm
from .config import Settings
from .prompts import CLASSIFY_SYSTEM

log = logging.getLogger("aimd.classifier")

Target = Literal["spa", "api"]

_API_KEYWORDS = ["POST", "GET", "PUT", "DELETE", "JSON", "API", "엔드포인트", "endpoint"]
_SPA_KEYWORDS = ["HTML", "UI", "화면", "페이지", "렌더링", "디자인", "버튼", "게임"]


def classify_by_keywords(spec_text: str) -> Target:
    """대소문자 구분 카운트. api 점수가 spa 점수보다 크면 "api", 아니면 "spa".
    (동점이면 "spa" — 랜딩 페이지 쪽이 안전한 기본값)"""


def classify(spec_text: str, settings: Settings) -> Target:
    """llm.chat(CLASSIFY_SYSTEM, spec_text, settings)를 호출한다.
    - 응답을 strip().upper()해서 "SPA"면 "spa", "API"면 "api"
    - 그 외 답변이거나 Exception이 나면:
      log.warning("LLM classification failed, falling back to keywords: %s", ...)
      후 classify_by_keywords 결과를 반환
    """
```

테스트 파일: `engine/tests/test_classifier.py`
- `classify_by_keywords`: `src/index.ai.md` 원문 → "spa",
  `src/convert.ai.md` 원문 → "api" (파일에서 읽지 말고 테스트에 문자열로 복사)
- `classify`: `monkeypatch.setattr(classifier.llm, "chat", ...)`로
  - "SPA" 응답 → "spa" / " api \n" 응답 → "api" (공백·대소문자 관용)
  - "MAYBE" 응답 → 키워드 폴백 경로
  - `chat`이 raise → 키워드 폴백 경로

## 하지 말 것
- 분류 결과 캐싱 금지 (산출물 확장자가 캐시다 — ADR-0005).

## 완료 조건
- 검증 명령: `cd engine && python -m pytest tests/test_classifier.py -q`

## 구현 결과

**구현 완료 일시**: 2026-07-13T18:58:22Z
**변경 파일**:
- engine/aimd/classifier.py (신규)
- engine/tests/test_classifier.py (신규)
- regression-tests/verify-issue-7.sh (신규)
- issues/issue-7__TYPE-agent-stats.json (신규)

**스펙 대비 deviation**: 없음.

**verify 결과**:
- 회귀 스크립트 (`regression-tests/verify-issue-7.sh`) 통과.
- 전체 pytest: 42 passed.
- 전체 회귀 스크립트: 10/10 통과.
