# issue-2: config.py — 환경 변수 설정 로딩

## 의존성
issue-1 완료 후

## 목표
환경 변수를 읽어 불변 설정 객체를 만드는 순수 모듈. LLM·파일시스템 접근 없음.

## 배경
- docs/adr/0006-minimax-integration.md, docs/SPEC.md 6장

## 구현 상세

파일: `engine/aimd/config.py`

```python
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    api_key: str
    base_url: str
    model: str
    max_tokens: int
    src_dir: Path
    dist_dir: Path


def load_settings() -> Settings:
    """환경 변수에서 설정을 읽는다. LLM_API_KEY가 없으면 RuntimeError."""
    api_key = os.environ.get("LLM_API_KEY", "")
    if not api_key:
        raise RuntimeError("LLM_API_KEY environment variable is required")
    return Settings(
        api_key=api_key,
        base_url=os.environ.get("LLM_BASE_URL", "https://api.minimax.io/v1"),
        model=os.environ.get("LLM_MODEL", "MiniMax-M3"),
        max_tokens=int(os.environ.get("AIMD_MAX_TOKENS", "200000")),
        src_dir=Path(os.environ.get("AIMD_SRC_DIR", "./src")),
        dist_dir=Path(os.environ.get("AIMD_DIST_DIR", "./dist")),
    )
```

테스트 파일: `engine/tests/test_config.py`
- `monkeypatch.setenv`로 키만 설정 → 기본값 전부 확인 (base_url, model, max_tokens=200000)
- 키 없음(`monkeypatch.delenv`) → `pytest.raises(RuntimeError)`
- 전 변수 오버라이드 → 반영 확인

## 하지 말 것
- 전역 싱글턴 설정 객체 금지. 항상 `load_settings()` 호출로 얻는다.
- dotenv 로딩 금지 (docker compose의 `env_file`이 주입한다).

## 완료 조건
- [ ] 위 시그니처 그대로 구현
- [ ] 테스트 3케이스 통과
- 검증 명령: `cd engine && python -m pytest tests/test_config.py -q`

## 구현 결과
**구현 완료 일시**: 2026-07-12T22:33:00-04:00
**변경 파일**:
- `engine/aimd/config.py`
- `engine/tests/test_config.py`
- `regression-tests/verify-issue-2.sh`

**계획 대비 편차**: 없음
**검증 결과**: `regression-tests/verify-issue-2.sh` 및 `regression-tests/verify-issue-1.sh` 테스트 모두 정상 통과.

