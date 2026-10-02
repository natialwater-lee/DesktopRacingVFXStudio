# 에너지 전환 — 런타임 입력 `boost_active` 추가 사전 확인 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 설계: Studio `docs/superpowers/specs/2026-10-02-talent-energy-conversion-design.md`

## 0. 배경

사용자가 에너지 전환 VFX에 **부스터를 쓸 때 청록 에너지가 크게 분출되는 연출**을 승인했다(재능 효과: 일반 부스터 성능 ×1.3). 현재 package가 받는 차량 런타임 입력은 `speed_normalized`·`longitudinal_load`·`turn_rate_normalized`뿐이라 부스터 상태를 알 수 없다. 새 입력 하나를 추가하려 한다. **이번 요청은 사전 확인(가능 여부·방식·영향 보고)이며, 실제 구현은 package 인계 때 함께 요청한다.**

## 1. 제안 계약

- 입력 ID **`boost_active`**: number, 범위 0~1, 기본 0.
- 의미: 해당 차량의 **일반 부스터**가 작동 중이면 1, 아니면 0.
- **보간은 Game 책임**: 켜질 때 약 0.08s, 꺼질 때 약 0.3s로 선형(또는 지수) 보간한 값을 매 물리/프레임 갱신. (Studio 변조는 입력값을 즉시 반영하므로 bool을 그대로 넘기면 깜빡인다.)
- Studio 쪽(Claude): `schemas/vfx_schema_v1.json` `x_vfx_runtime_inputs`에 추가, 문서·미리보기 슬라이더 추가. 이 입력을 쓰는 package는 `runtime_inputs: ["boost_active"]`를 선언한다.
- 사용처(예정): TEXTURED_SPRITE 1개의 `VISUAL_OPACITY_MULTIPLIER`(0→1)·`TRANSFORM_SCALE_Y`(0.6→1.3) 변조(`LINEAR_RANGE`, 기존 speed 변조와 같은 경로).

## 2. Claude 확인 사항 (읽기 전용)

- `CarAgent.gd` 232행 `var boost_active: bool`, 1321행 `_vfx_runtime_input_snapshot.set_values(...)`에서 speed·longitudinal·turn 공급.
- `VfxEffectInstance.gd` 30·130~135행: 입력 슬롯별 `set_runtime_modulation_input`.

## 3. Codex 확인 요청

1. Game 입력 계약(Studio schema 사본/검증기)에 새 입력을 추가하는 방법과 영향(기존 package 호환, Runtime 버전 변화 여부).
2. `boost_active` 값 공급 위치·보간 방식 제안. 보간을 스냅샷 쪽에서 할지 별도 상태로 할지.
3. **일반 부스터만** 대상이 맞는지(슈퍼 부스터·환경 부스터·벤치마크 고정 부스트 제외 여부)와 `boost_active` bool이 그 의미와 일치하는지.
4. 재능 발동 중이 아닌 차량에서도 입력을 계산하는 비용(20대) — 필요하면 해당 입력을 선언한 effect가 있을 때만 계산.
5. Studio에서 먼저 해 둘 일(입력 이름·범위·기본값 변경 제안 포함).

## 4. 다음

- Codex: 3 확인 결과를 공통 인계 형식으로 보고(코드 변경 없이 확인만 — 바로 구현해도 되는 단순한 경우라도 보고 후 진행).
- Claude: 결과 반영해 Studio schema·미리보기 추가 → 시안 → package 인계 시 구현 요청.
- 변경하지 말 것: 부스터 규칙·게이지·성능 수치, 다른 VFX, 저장 데이터. 승인 없는 commit 금지.
