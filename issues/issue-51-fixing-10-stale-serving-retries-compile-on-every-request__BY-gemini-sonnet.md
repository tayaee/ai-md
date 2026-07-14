# issue-51: fixing-10 — stale 서빙이 매 요청 LLM 호출을 유발해 DoS (must-fix)

## 부모
issue-10 (ASGI 디스패처)

## 출처
- `issues/issue-10__TYPE-code-review__BY-gemini.md` Finding 4 (must-fix / error-handling)
- `issues/issue-10__TYPE-code-review__BY-sonnet.md` §1 Verdict 4 (CONFIRMED)

## 문제
main.py의 stale 분기는 캐시가 있어도 매 요청마다 compile_spec을 호출한다. 디스크 mtime 기반 `is_stale`은 spec이 한 번도 갱신되지 않으면 영구히 True를 반환하므로, 컴파일이 계속 실패하는 동안 매 요청마다 30~90초의 LLM 호출 스레드가 실행된다.

```python
# engine/aimd/main.py:57-65
if artifacts.is_stale(name, self.settings):
    try:
        await asyncio.to_thread(compiler.compile_spec, name, self.settings)
    except Exception as e:
        if artifacts.artifact_path(name, self.settings) is None:
            return await _json(send, 502, {"error": f"compile failed: {e}"})
        log.error("recompile failed for %s, serving stale artifact: %s", name, e)
```

## 실패 시나리오
- 입력: spec 수정으로 is_stale=True, 기존 dist 아티팩트 존재, LLM 다운. 트래픽 5 req/s 인입.
- 잘못된 결과: 5 req/s × 30~90s/req = 매초 5개의 LLM 호출 스레드가 새로 뜨며 비용 폭증 + 응답 지연.

## 확인 방법 (Sonnet 재현 결과)
```
compile attempts: 5  (5개 요청에 대해 매번 호출됨)
```

## 권장 구현 방향
negative cache + exponential backoff:
- 컴파일 실패 시 (name, spec_mtime) → 마지막 실패 시각 기록
- 같은 (name, spec_mtime)에 대해 backoff 윈도우(예: 60s) 내 재시도 차단 → 캐시 서빙
- 백오프 윈도우 만료 후 1회 재시도, 또 실패 시 윈도우 2배
- settings로 윈도우 최대값, 초기값 노출 (env: `AIMD_COMPILE_BACKOFF_INIT_S`, `AIMD_COMPILE_BACKOFF_MAX_S`)

핵심 결정: "stale이지만 컴파일도 실패" 상태를 별도 캐시 엔트리로 모델링해야 한다. 현재 AIMDDispatcher는 컴파일 상태를 들고 있지 않으므로 name별 lock + 메모리 dict로 dispatcher 인스턴스에 저장.

## 완료 조건
- [ ] 컴파일 실패 시 (name, spec_mtime)별 마지막 실패 시각 + 백오프 종료 시각 저장
- [ ] 백오프 윈도우 내 요청은 compile_spec 호출 없이 stale 아티팩트 서빙
- [ ] 백오프 만료 후 1회 재시도, 실패 시 윈도우 2배 (max 캡)
- [ ] 정상 컴파일 성공 시 캐시 엔트리 제거
- [ ] 회귀 테스트: 컴파일 실패 mock 후 5회 요청 → compile_spec 호출 ≤1회