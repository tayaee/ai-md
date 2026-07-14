# issue-52: fixing-10 — load_module이 sys.modules에 미등록되어 pickle 실패 (good-to-fix / later)

## 상태


## 부모
issue-10 (ASGI 디스패처)

## 출처
- `issues/issue-10__TYPE-code-review__BY-gemini.md` Finding 2 (good-to-fix / contract)
- `issues/issue-10__TYPE-code-review__BY-sonnet.md` §1 Verdict 2 (PLAUSIBLE — 사실관계 약화)

## 문제
`validators.load_module`이 `compile + exec`로 만든 모듈을 `sys.modules`에 등록하지 않는다. 동적으로 생성된 모듈의 인스턴스를 pickle로 직렬화하거나 inspect / dill 같은 도구로 역조회할 때 실패할 수 있다.

```python
# engine/aimd/validators.py:96-108
module = importlib.util.module_from_spec(spec)
source = spec.loader.get_data(str(path))
code = compile(source, str(path), "exec")
exec(code, module.__dict__)
# sys.modules 등록 없음
```

## 실패 시나리오
- 입력: `load_module`이 반환한 모듈의 `app`이 동적 모듈 내 정의 클래스의 인스턴스. pickle.dumps 시도.
- 잘못된 결과: `AttributeError: Can't pickle local object ...` — 클래스 정의를 import할 수 없어 실패.

## 확인 방법 (Sonnet 재현 결과)
```
AttributeError: Can't pickle local object 'C'
```
단, Sonnet의 추가 검증에 따르면 **nested local class는 sys.modules 등록 여부와 무관하게 pickle 불가**. 일반적인 ASGI 서브앱은 pickle을 사용하지 않으므로 AIMD 파이프라인에서 이 제약이 실제로 발현될 시나리오는 드물다.

## 권장 구현 (승격 후)
load_module이 성공적으로 만든 모듈을 `sys.modules[module_name] = module`로 등록. 충돌 방지를 위해 `_counter`가 unique한 이름을 보장하므로 키 충돌은 없다. registry의 hot-swap 시 동일 모듈의 새 인스턴스를 만들면 sys.modules의 dict도 새 객체로 덮어쓰여야 한다.

## 완료 조건 (승격 후)
- [ ] `sys.modules[module_name] = module` 추가
- [ ] `test_load_module_registers_in_sys_modules` 신규 테스트
- [ ] 기존 `tests/test_validators.py` / `test_compiler.py` 회귀 없음