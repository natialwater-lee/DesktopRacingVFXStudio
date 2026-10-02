# 충격파 — 영향받은 차 package 부착 + `effect_radius` 공급 사전 확인 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 설계: Studio `docs/superpowers/specs/2026-10-02-talent-shockwave-design.md`

## 0. 배경

충격파는 **발동 차의 효과 + 반경 안 다른 차들에 붙는 효과** 두 가지가 필요하다(사용자). 현재 Studio package는 "재능을 가진 차"에만 붙으므로 Game 연결이 필요하다. **이번 요청은 사전 확인(가능 여부·방식·영향 보고)이며, 실제 구현은 package 인계 때 요청한다.** 지속 시간·반경은 **밸런스에 따라 바뀔 수 있다**(사용자) — package는 길이에 묶이지 않게 만든다.

## 1. 제안 구조

- `talent.shockwave`(발동 차): START 파란 전기 동심원이 **판정 반경까지** 퍼짐(TEXTURED_SPRITE 크기를 `effect_radius`로 변조), LOOP 작은 잔진동 물결(Game 소유 길이), END 자연 소진.
- `talent.shockwave_impact`(영향받은 차): START 주황 스파크, LOOP 주황 번개 A/B 교대, END 소진. **대상이 해제될 때까지** 유지.

## 2. Claude 확인 사항 (읽기 전용)

- 발동: `RaceAbilityRuntimeController.gd` 681행 `trigger_race_ability_transient_fx(activation_fx_id)` + `_apply_shockwave_targets`(705행): 반경(`effect_values.radius`, 월드 80) 안 대상마다 `set_race_ability_external_stability_multiplier`·`set_race_ability_external_visual_profile(source_key, impact_fx_id)`.
- 해제: `_clear_shockwave_targets`(728행) → `CarAgent.clear_race_ability_external_stability_multiplier`(3022행, 외부 프로필도 해제).
- `effect_radius`는 Studio schema `x_vfx_runtime_inputs`에 이미 있으나 Game 공급 코드는 없음(검색 확인).

## 3. Codex 확인 요청

1. **대상 차 package 부착**: `_apply_shockwave_targets`에서 대상 차마다 `talent.shockwave_impact` 시작, 해제 시 정지(END)하는 방법. 다른 차 소유 효과를 붙이는 기존 경로가 있는지, VfxService 수명·정리(대상 차 제거, 레이스 정리, 발동 차 효과 조기 종료) 처리.
2. **중복**: 같은 차가 두 발동 차의 충격파에 동시에 맞을 때(source_key 2개) — 효과 1개 공유 vs 개별. 권장안.
3. **`effect_radius` 공급**: 발동 차 effect에 `effect_values.radius`를 **차량 source px**(package 좌표, 256×512 기준)로 환산해 공급하는 방법과 환산식(Game VFX 배율). 효과 시작 시 값이 이미 들어가 있어야 함(START 첫 프레임부터 사용).
4. legacy 억제: 발동 차 `shockwave_aura`·`shockwave_pulse`, 대상 차 `shockwave_impact`(절차 그리기).
5. 부하: 대상 차가 많을 때(예: 19대 중 8대) 추가 effect 수·풀 생성 비용 우려 사항(측정은 Claude가 한다).
6. Studio가 먼저 정할 것(이름·입력 단위 제안 포함).

## 4. 다음

- Codex: 3 확인 결과를 공통 인계 형식으로 보고(코드 변경 없이 확인만).
- Claude: 결과 반영 → 시안 → package 2개 인계.
- 변경하지 말 것: 충격파 판정·반경·안정성 수치, 다른 VFX, 저장 데이터. 승인 없는 commit 금지.
