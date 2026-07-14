# issue-16: README ngrok basic-auth 명령어 표준 문법 수정 (fixing issue-1)

## 의존성
issue-1 완료 후

## 계보
- **원본 이슈**: issue-1 (리포 뼈대 및 POC 시나리오 명세 파일 생성)
- **출처 리뷰**: `issues/archive/2026/07/12/issue-1__TYPE-code-review__BY-minimax3.md` (Finding 2)
- **인용**: "ngrok v3 CLI의 `--basic-auth` 플래그는 공백 구분(`ngrok http --basic-auth \"user:pass\" 8080`)이 표준이고, `--basic-auth=value` 형식은 ngrok v2 스타일. ngrok v3에서 `=` 접붙이형이 통하는지는 버전/플래그 파서에 따라 다르며, 사용자가 그대로 복붙하면 환경에 따라 인자 파싱 실패로 명령이 거부될 수 있음."
- **재검증 결과**: 해당 없음 — good-to-fix는 Step 3에서 재검증을 생략(파킹, 사람이 승격 시 확인). 리뷰어 스스로도 로컬에 ngrok 미설치로 직접 재현하지 못했다고 명시했으므로, 승격 시 ngrok 공식 문서(`https://ngrok.com/docs/ngrok-agent/cli/`) 재확인을 권장.

## 목표
README.md의 ngrok 임시 공개 안내 명령어를 ngrok v3 표준 문법(공백 구분)으로 수정해, 복붙 시 파싱 실패 위험을 없앤다.

## 배경
- 현재 `README.md`의 경고 문단은 `` `ngrok http --basic-auth="user:pass" 8080` `` (등호 접붙이형, v2 스타일)을 예시로 제시하고 있다.
- 이 값을 그대로 복붙하는 사용자가 환경에 따라 명령 실패를 겪을 수 있다.

## 구현 상세
`README.md`의 해당 문단을 다음과 같이 수정한다 (공백 구분):
```
ngrok http --basic-auth "user:pass" 8080
```
승격 시 착수 전에 ngrok 공식 CLI 문서에서 v3 현재 문법을 재확인한다.

## 완료 조건
- [ ] README.md의 ngrok 명령이 공백 구분 `--basic-auth "user:pass"` 형식으로 수정됨
- [ ] 나머지 문구(경고 굵게 처리 등)는 그대로 유지
- 검증 명령: `grep -F 'ngrok http --basic-auth "user:pass" 8080' README.md`

## 구현 결과
- **구현 완료 일시**: 2026-07-13T22:19:51Z
- **변경 파일**:
  - `README.md` — 19행 ngrok 명령의 `--basic-auth="user:pass"` → `--basic-auth "user:pass"` (v3 표준)
  - `regression-tests/verify-issue-16.sh` — 신설, 본 이슈 회귀 보호 스크립트
  - `issues/issue-16.md` — 본 파일 (구 `__STATE-later` 떼고 슬러그 압축, acpd 단계에서 최종 리네임)
- **계획 대비 차이**: 없음 — 이슈가 명시한 명령 문자열을 그대로 적용
- **검증 결과**:
  - `bash regression-tests/verify-issue-16.sh` → **OK**
    - v3 표준(`ngrok http --basic-auth "user:pass" 8080`) 등장 ✓
    - v2 스타일(`--basic-auth=...`) 부재 ✓
    - 경고 문단 나머지(LLM 실행 경고·공인 노출 금지·일시 공개) 보존 ✓
  - 전체 회귀(`regression-tests/verify-issue-*.sh` 12개) → **모두 통과** (16 새로 포함)
- **재확인 메모**: ngrok v3 표준 문법 가정은 이슈 본문과 리뷰어 권고에 따른 것. 로컬에 ngrok 미설치라 직접 재현은 생략. 추후 ngrok 공식 문서(`https://ngrok.com/docs/ngrok-agent/cli/`)에서 `--basic-auth` v3 동작 재확인 권장(이슈 본문 권고와 동일).
