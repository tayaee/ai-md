# issue-41: llm.chat — 매 호출마다 OpenAI 클라이언트를 재생성해 커넥션 풀링을 활용하지 못함 (good-to-fix)

## 상태


## 의존성
issue-6 완료 후

## 배경
`engine/aimd/llm.py:30`(`client = _make_client(settings)`)는 `chat()` 호출마다
새 `openai.OpenAI` 클라이언트(및 하위 `httpx.Client`)를 생성한다. 고빈도
호출 환경에서는 TCP/TLS 핸드셰이크가 매번 발생해 지연시간이 늘고
커넥션 풀링을 활용하지 못한다.

리뷰 출처: `issues/archive/2026/07/13/issue-6__TYPE-code-review__BY-gemini.md`
(Finding 4, good-to-fix).

## 재검증 메모
minimax 리뷰는 같은 지점을 검토했으나 "issue-6 스펙이 client 재사용/풀링을
요구하지 않으므로 스펙 외 이슈"라며 자신의 finding으로는 채택하지 않았다
(reject하지는 않았고, 범위 밖으로 판단). 기술적으로는 유효한 관찰이므로
good-to-fix로 파킹한다 — 승격 여부는 이 모듈의 실제 호출 빈도(컴파일러
파이프라인에서 요청당 1회인지, 배치/루프인지)가 결정된 이후(issue-8
compiler 등) 판단하는 것이 합리적.

## 검토 포인트
- `_make_client`를 모듈 레벨 캐시나 `chat()` 호출자가 주입하는 방식으로
  전환할지 검토
- 테스트의 `monkeypatch.setattr(llm, "_make_client", ...)` 패턴과 호환되는
  형태로 설계해야 함(현재 테스트 인프라를 깨지 않아야 함)

## 권장 구현(가이드)
호출 빈도가 높다고 판단되면 모듈 레벨에 클라이언트를 lazy하게 캐싱하는
방식 검토(단, 테스트 격리를 위해 `_make_client`를 통한 monkeypatch 경로는
유지):
```python
_client_cache: dict[tuple[str, str], openai.OpenAI] = {}

def _make_client(settings: Settings) -> openai.OpenAI:
    key = (settings.api_key, settings.base_url)
    if key not in _client_cache:
        _client_cache[key] = openai.OpenAI(api_key=settings.api_key, base_url=settings.base_url)
    return _client_cache[key]
```

## 완료 조건(승격 후)
- [ ] 캐싱 방식 채택 시 기존 5개 테스트(monkeypatch 기반) 회귀 없음
- [ ] `cd engine && uv run pytest tests/test_llm.py -q` 통과
