# 절대 방어 — 런타임 입력 `defense_impact` 추가 사전 확인 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 설계: Studio `docs/superpowers/specs/2026-10-02-talent-absolute-defense-design.md`

## 0. 배경

사용자가 절대 방어 VFX에 **뒤차의 추월을 막아 낸 순간 차 뒤 방어막이 번쩍이는 연출**을 승인했다. 에너지 전환의 `boost_active`처럼 새 입력 하나가 필요하다. **이번 요청은 사전 확인(가능 여부·방식·영향 보고)이며, 실제 구현은 package 인계 때 함께 요청한다.**

## 1. 제안 계약

- 입력 ID **`defense_impact`**: number, 범위 0~1, 기본 0.
- 의미: 해당 차량이 **유효 방어에 성공한 순간 1**, 이후 **0.5s에 걸쳐 선형으로 0까지 감소**. 감소 중 다시 성공하면 1로 재설정.
- 효과 시작 시 0, 레이스 일시정지 중 값 유지, 효과 종료 시 갱신 중단(`boost_active`와 같은 규칙).
- 신호원(Claude 확인, 읽기 전용): `CarAgent.race_ability_defense_succeeded(car, rear_car)`(`CarAgent.gd` 8·4797행) — 재능 판정 `valid_defense_success_count`가 세는 것과 같은 유효 방어.
- 감소 계산은 이 입력을 선언한 effect만(에너지 전환 보간과 같은 위치 `VfxEffectInstance` 권장 — 판단은 Codex).
- Studio 쪽(Claude): schema `x_vfx_runtime_inputs.defense_impact`, 문서, 미리보기 슬라이더 + Hit 버튼(1 → 0.5s 감소) — 이번에 추가.
- 사용처(예정): 뒤 방어막 TEXTURED_SPRITE의 불투명도·크기 변조.

## 2. Codex 확인 요청

1. 신호 → 입력 공급 경로와 감소 계산 위치 제안(차량 상태로 둘지, effect 쪽에서 신호를 받을지).
2. `race_ability_defense_succeeded`가 이 연출 의미("뒤차를 막아 냄")에 맞는 유일한 신호인지, 피트·정지·벤치마크 중 발생 여부.
3. 한 프레임에 여러 번 성공하거나 아주 잦은 경우 처리(1로 재설정이면 충분한지).
4. 20대 비용(재능 없는 차량엔 계산 없음 가능 여부).
5. Studio가 먼저 바꿀 것(이름·범위·감소 시간 제안 포함).

## 3. 다음

- Codex: 2 확인 결과를 공통 인계 형식으로 보고(코드 변경 없이 확인만).
- Claude: 결과 반영 → 시안 → package 인계 시 구현 요청.
- 부하 측정은 Claude가 한다. 변경하지 말 것: 방어 판정·규칙, 다른 VFX, 저장 데이터. 승인 없는 commit 금지.
