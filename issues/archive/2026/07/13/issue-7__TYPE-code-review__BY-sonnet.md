Claude Sonnet 5 (claude-sonnet-5)

# Code Review — issue-7 (classifier.py)

범위: `engine/aimd/classifier.py`, `engine/tests/test_classifier.py`, `issues/archive/2026/07/13/issue-7-add-classifier.md`, `issues/archive/2026/07/13/issue-7__TYPE-agent-stats.json`, `regression-tests/verify-issue-7.sh`. 커밋 범위: 24fe68a..9afd324.

명시 제약: ruff/pyright 잡는 스타일·타입 지적은 보고하지 않음. 로직 / 스펙 불일치 / OWASP / 동시성·경계조건만. 확인되지 않은 finding은 제외.

모든 finding은 메인 루프에서 직접 실행으로 재현 확인됨 (`uv run python -c ...`).

---

## Finding 1 — strict `==` 매칭이 모델 출력 부호/문장 부호에 너무 엄격함

- **파일:라인**: `engine/aimd/classifier.py:35-41`
- **코드 인용**:
  ```python
  response = llm.chat(CLASSIFY_SYSTEM, spec_text, settings)
  answer = response.strip().upper()
  if answer == "SPA":
      return "spa"
  if answer == "API":
      return "api"
  ```
- **실패 시나리오**: LLM 분류 응답은 단어 하나를 반환하라고 지시받지만 (`prompts.py:0-5`: "Answer with exactly one word: SPA if it describes a web page / user interface, or API if it describes an HTTP/REST backend service. No other words, no punctuation."), 실전 모델 출력은 다음처럼 흔히 표기된다.
  - `response = "SPA."` → `answer = "SPA."` → 어느 분기도 매칭 안 됨 → `log.warning("LLM classification returned unexpected answer 'SPA.', falling back to keywords")` → 키워드 폴백. API 명세가 들어왔고 키워드 분포가 spa 쪽으로 기울면 LLM의 의도("SPA")와 반대 결과 반환.
  - `response = "**SPA**"` → 동일 경로로 폴백.
  - `response = "The answer is SPA"` → 동일 경로.
  - `response = ""` (LLM이 content 없음 반환) → 동일 경로.
  - 직접 검증:
    - `classify('any', s)` with `llm.chat → "SPA."` → `"spa"` via 폴백 (로그: `LLM classification returned unexpected answer 'SPA.'`)
    - `llm.chat → "**SPA**"` → `"spa"` via 폴백
    - `llm.chat → ""` → `"spa"` via 폴백
    - `llm.chat → "The answer is SPA"` → `"spa"` via 폴백
- **확인 방법**: 위 시나리오를 다음 한 줄로 재현:
  ```python
  import aimd.llm; aimd.llm.chat = lambda *a: "SPA."
  from aimd import classifier; print(classifier.classify("any", object()))
  # → spa (LLM 의도와 반대 가능)
  ```
  또는 `engine/tests/test_classifier.py`에 다음 케이스 추가하여 pytest 실행:
  ```python
  def test_classify_returns_spa_when_llm_says_spa_with_punctuation(monkeypatch):
      s = make_settings()
      monkeypatch.setattr(classifier.llm, "chat", lambda *a: "SPA.")
      assert classifier.classify(INDEX_SPEC, s) == "spa"   # ← 키워드 결과와 무관하게 LLM의 "SPA"를 신뢰해야 함
  ```
- **심각도 제안**: good-to-fix — 명세는 literal `strip().upper()`을 명시하므로 **deviation은 아니지만**, `prompts.py`가 "No other words, no punctuation"을 지시했음에도 모델이 어길 때 LLM 신뢰를 잃고 폴백으로 결정이 뒤집히는 잠재 오분류.

---

## Finding 2 — `classify`의 `"API"` 분기를 직접 테스트하지 않음

- **파일:라인**: `engine/tests/test_classifier.py` (전체 86줄)
- **코드 인용**: 테스트 모음에 `llm.chat`이 정확히 `"API"`를 반환하는 케이스가 없다.
  - `test_classify_returns_spa_when_llm_says_spa` → `"SPA"`
  - `test_classify_returns_api_when_llm_says_api_with_whitespace` → `" api \n"`
  - `test_classify_falls_back_to_keywords_when_llm_returns_maybe` → `"MAYBE"`
  - `test_classify_falls_back_to_keywords_when_llm_raises` → 예외
- **실패 시나리오**: 미래에 `if answer == "API":` 분기가 `is`로 바뀌거나, 오타로 `"AP1"`이 되거나, 위 Finding 1의 strip 후처리 변경 시 `"API"` happy-path 회귀가 잡히지 않는다. pytest는 현재 6/6 통과 (실제 실행 확인).
- **확인 방법**: `engine/tests/test_classifier.py`에 추가:
  ```python
  def test_classify_returns_api_when_llm_says_api(monkeypatch):
      s = make_settings()
      monkeypatch.setattr(classifier.llm, "chat", lambda *a: "API")
      assert classifier.classify("anything", s) == "api"
  ```
  `uv run python -m pytest tests/test_classifier.py -q`로 통과 확인 후 위 분기를 의도적으로 깨서 테스트가 빨갛게 되는지 검증하면 회귀 가드의 유효성이 확인됨.
- **심각도 제안**: good-to-fix.

---

## Finding 3 — `classify_by_keywords(None)` → `AttributeError` (None 입력 경계조건)

- **파일:라인**: `engine/aimd/classifier.py:14-25`
- **코드 인용**:
  ```python
  def _count_occurrences(text: str, keywords: list[str]) -> int:
      return sum(text.count(k) for k in keywords)

  def classify_by_keywords(spec_text: str) -> Target:
      ...
      api_score = _count_occurrences(spec_text, _API_KEYWORDS)
      spa_score = _count_occurrences(spec_text, _SPA_KEYWORDS)
      return "api" if api_score > spa_score else "spa"
  ```
- **실패 시나리오**: `classify_by_keywords(None)` 호출 시 `_count_occurrences(None, _API_KEYWORDS)` 안에서 `None.count(k)` → `AttributeError: 'NoneType' object has no attribute 'count'` (직접 실행 확인). 현재 `classify()`는 LLM 성공 시 키워드 분기를 거치지 않으므로 실제 흐름에서는 도달하지 않지만, 함수 시그니처가 `str`로 선언되어 있어 None 거부는 호출자의 책임이며, type-narrowing 가드가 없으면 향후 다른 호출자(예: test_llm.py의 `monkeypatch.setattr(classifier.llm, "chat", ...)` 잘못 작성, 또는 issue-8에서 spec_text를 옵셔널 처리할 때)에서 AttributeError로 분류 단계가 크래시.
- **확인 방법**:
  ```python
  from aimd import classifier
  classifier.classify_by_keywords(None)
  # AttributeError: 'NoneType' object has no attribute 'count'
  ```
- **심각도 제안**: good-to-fix.

---

## Finding 4 — 모듈 레벨 가변 리스트 (동시성·테스트 오염 가능성)

- **파일:라인**: `engine/aimd/classifier.py:11-12`
- **코드 인용**:
  ```python
  _API_KEYWORDS = ["POST", "GET", "PUT", "DELETE", "JSON", "API", "엔드포인트", "endpoint"]
  _SPA_KEYWORDS = ["HTML", "UI", "화면", "페이지", "렌더링", "디자인", "버튼", "게임"]
  ```
- **실패 시나리오**: 모듈 전역 `list`이므로 프로세스 내에서 어떤 코드든 `classifier._API_KEYWORDS.append("X")`로 오염 가능. 단일 분류 함수 내부에서 동시에 두 키워드 리스트를 iterate하지는 않으므로 thread-safety는 사실상 안전하지만, **테스트 격리가 약해짐**. 예: `test_a`가 임시로 키워드를 추가한 뒤 `teardown`이 없으면 후속 `test_b`의 분류가 영향받음. 직접 검증: 한 번 `append("X-FAKE")` 후 `classify_by_keywords("X-FAKE")` → `"api"`로 오염됨.
- **확인 방법**:
  ```python
  from aimd import classifier
  classifier._API_KEYWORDS.append("X-FAKE")
  print(classifier.classify_by_keywords("X-FAKE"))  # → api
  ```
- **심각도 제안**: good-to-fix — `tuple(...)` 또는 `MappingProxyType(...)`로 바꾸면 잠재 오염 차단. 단, 현재 동시성 호출 패턴은 위험 없음.

---

## Finding 5 — 회귀 스크립트의 `classify → llm.chat` 검증이 테스트 파일에서만 grep됨

- **파일:라인**: `regression-tests/verify-issue-7.sh:15-18`
- **코드 인용**:
  ```bash
  echo "=== 3. classify는 CLASSIFY_SYSTEM을 llm.chat에 넘긴다 ==="
  grep -q 'CLASSIFY_SYSTEM' engine/aimd/classifier.py
  grep -q 'classifier.llm, "chat"' engine/tests/test_classifier.py
  ```
- **실패 시나리오**: 두 번째 grep은 **production 코드가 아니라 테스트 파일**에서 `classifier.llm, "chat"` 문자열을 찾는다. 이는 테스트가 monkeypatch를 어떻게 부르는지만 검증할 뿐, `engine/aimd/classifier.py`가 실제로 `llm.chat(...)`을 호출하는지는 검증하지 않는다. 우회적으로 §5의 pytest가 실행되며 코드 경로가 호출되므로 사실상 검증되지만, "스펙 §구현상세의 함수 본문이 llm.chat을 호출해야 한다"는 명세를 회귀 스크립트가 직접 가드하지 못함. (현재는 본문에 `llm.chat(CLASSIFY_SYSTEM, spec_text, settings)`이 존재하므로 OK.)
- **확인 방법**:
  ```bash
  grep -nE 'llm\.chat\(' engine/aimd/classifier.py
  # → 36:        response = llm.chat(CLASSIFY_SYSTEM, spec_text, settings)
  ```
  이 grep이 누락되면 회귀 스크립트가 FAIL하도록 보강 권장:
  ```bash
  grep -q 'llm\.chat(' engine/aimd/classifier.py
  ```
- **심각도 제안**: good-to-fix — 명세 §구현상세 라인의 직접 가드가 없음.

---

## Finding 6 — `issue-7__TYPE-agent-stats.json`의 `loc_added: 0`은 사실과 다름

- **파일:라인**: `issues/archive/2026/07/13/issue-7__TYPE-agent-stats.json:9`
- **코드 인용**:
  ```json
  "mvp": {
    "ts": "2026-07-13T18:58:22Z",
    "loc_added": 0,
    "static_analysis_failures": {
      "ruff": null,
      "pyright": null
    }
  }
  ```
- **실패 시나리오**: `git diff --stat`은 5 files changed, 199 insertions. `engine/aimd/classifier.py`만 50줄이 추가되었고 그 중 docstring/import을 제외한 실행 코드(`_count_occurrences` 본문, `classify_by_keywords` 본문, `classify` 본문, 예외 처리)가 포함됨. `loc_added: 0`은 `engine/aimd/classifier.py`의 신규 파일 본문 카운트가 누락된 메타데이터 오기재. 자동 리뷰/회귀 분석이 이 JSON을 신뢰해 "구현이 비어 있다"고 오판할 위험.
- **확인 방법**:
  ```bash
  git diff --stat 24fe68a...9afd324 -- 'engine/aimd/*.py'
  # → engine/aimd/classifier.py | 50 +++++++++++++
  ```
- **심각도 제안**: good-to-fix — 산출 메타데이터 정확성.

---

## (보강) 검증된 비-finding

다음 항목은 검토했으나 finding으로 채택하지 않음:

- **C7** `except Exception`이 `KeyboardInterrupt` 등 `BaseException`을 통과시키는 동작 (line 46) — 직접 검증: `KeyboardInterrupt` 전파됨. 명세는 "Exception이 나면 폴백"이므로 의도와 일치. OK.
- **C8** 키워드 비교의 `api_score > spa_score` (line 25) — 명세 "동점이면 spa"와 일치. OK.
- **C9** OWASP LLM01 (Prompt Injection) — `spec_text`는 `user` role에만 주입되고 system prompt와 분리되어 있으며 (`prompts.py:0-5`로 단어-하나 응답 강제), 출력은 enum 비교 후 산출물 확장으로만 분기되며 실행/eval되지 않음. 분류 결과에 따라 단일 스크립트(HTML) 또는 단일 모듈(Python) 생성이지만 그 단계는 본 PR 범위 밖이며 issue-8의 책임. 범위 내 OWASP 표면은 깨끗함.
- **C10** 스펙 §구현상세는 `classify_by_keywords` / `classify`의 본문이 비어 있는 docstring 스켈레톤만 보여주지만, `## 구현 결과`에서 "스펙 대비 deviation: 없음"이라 명시. 실제 본문은 docstring 텍스트 그대로(문자열 인용)을 충실히 채웠으므로 deviation 없음 확인.
- **C11** `pytest` 결과 6 passed (직접 실행) — Finding 2 외 결함 없음.
- **C12** 회귀 스크립트 `bash -n` 문법 OK, `grep -qE 'lru_cache|cache\('`로 캐싱 흔적 없음 확인 (직접 grep 결과 없음).

---

## 한 줄 요약

- Standards 축: 6건 모두 good-to-fix (회귀 가드 강화·경계조건·메타데이터 정확성).
- Spec 축: deviation 없음 (specification drift 0건).
- 가장 강한 finding은 F1 (strict equality가 모델 출력 부호/문장 부호에 취약) — 명세 deviation은 아니지만 실제 환경에서 LLM 의도를 무시할 잠재력.