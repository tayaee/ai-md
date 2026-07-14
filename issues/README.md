# AIMD 구현 이슈 로드맵

저지능 모델 실행 규칙: **번호 순서대로 하나씩**, 이슈 파일의 "구현 상세"를 그대로 따르고,
"완료 조건"의 검증 명령이 통과해야 다음 이슈로 넘어간다. 설계 판단이 필요해 보이면
docs/SPEC.md와 docs/adr/를 먼저 읽는다 — 판단은 이미 다 되어 있다.

## 의존성 그래프

```
issue-1 (뼈대)
 ├─ issue-2 (config) ──── issue-3 (artifacts) ─┐
 ├─ issue-4 (validators) ─┬─ issue-9 (registry) ├─ issue-8 (compiler) ─┬─ issue-10 (main 디스패처) ─┐
 ├─ issue-5 (prompts) ─┐  │                     │                      ├─ issue-11 (watcher) ──────┤
 ├─ issue-6 (llm) ─────┴─ issue-7 (classifier) ─┘                      │                           ├─ issue-13 (docker) ─ issue-14 (E2E)
 └─ issue-12 (nginx) ──────────────────────────────────────────────────┘
```

| 이슈 | 산출물 | 병렬 가능 |
|---|---|---|
| 1 | 디렉토리·명세·README 뼈대 | — |
| 2 | `aimd/config.py` | 3,4,5,12와 |
| 3 | `aimd/artifacts.py` | 4,5,12와 |
| 4 | `aimd/validators.py` | 2,3,5,12와 |
| 5 | `aimd/prompts.py` | 2,3,4,12와 |
| 6 | `aimd/llm.py` | 3,4,12와 |
| 7 | `aimd/classifier.py` | 9,12와 |
| 8 | `aimd/compiler.py` (심장) | 9,12와 |
| 9 | `aimd/registry.py` | 7,8,12와 |
| 10 | `aimd/main.py` (최난도) | 11,12와 |
| 11 | `aimd/watcher.py` | 10,12와 |
| 12 | `nginx/nginx.conf` | 2~11와 |
| 13 | Dockerfile, docker-compose.yml | — |
| 14 | scripts/smoke.sh, dist 커밋 | — |

공통 테스트 규칙: 모든 pytest는 `cd engine && python -m pytest -q`로 전체 통과 유지.
실 LLM·실 네트워크 호출 테스트 금지 (mock만). 실키 사용은 issue-14 2부에서만.
