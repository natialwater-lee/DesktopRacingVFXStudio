# 에너지 전환 / Energy Conversion — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 + 부스터 연동 선택 사항 개발 승인, Studio 시안 승인 2026-10-02)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `energy_conversion`: trigger `valid_defense_success_count` 5회, activation_chance 0.3, **duration 15초**, effect: 부스터 게이지 회복 ×1.3, 일반 부스터 성능 ×1.3. `vehicle_fx_id`·`visual_profile_id` = `energy_conversion`(`RaceAbilityVisualController.gd` 132·179행), `player_screen_fx_id` 없음.
- 의미: **막아 낸 에너지를 흡수해 부스터 힘으로 변환**.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"energy_conversion": "talent.energy_conversion"`, catalog 등록, legacy 차량 효과 억제.
- 부스터 상태: `CarAgent.boost_active`(bool), 런타임 입력 스냅샷은 `CarAgent.gd` 1321행 `_vfx_runtime_input_snapshot.set_values(...)`, 슬롯 처리 `VfxEffectInstance.gd`(현재 speed_normalized·longitudinal_load·turn_rate_normalized).

## 2. 참고 자료

- 컷인 `energyconversion.mp4`(4.0초) + 컨셉 이미지: 0~1s 파란 전기 에너지가 차 둘레를 소용돌이치며 감김(흡수) → 1~2.4s 차체 뒤 윤곽·배기구가 파랗게 맺힘(저장) → 2.7s~ 배기구에서 주황·청록 불꽃 분출(변환).
- 정체성: **파랑(흡수) → 청록(방출) 색 변환**.
- 생략: 주황 불꽃(일반/슈퍼 부스터 불꽃과 혼동), 배경·반사·카메라.

## 3. 합의한 연출 — "흡수 → 변환"

| 구간 | 연출 | 구현 |
|---|---|---|
| START ≈0.6s | 차 바깥에서 파란 전기 소용돌이가 회전하며 차 쪽으로 말려 들어옴(흡수) → 끝에 차 뒤에서 파랑→청록 섬광 1회 | PARTICLE BURST(소용돌이: 크기 축소 + 회전) + BURST(방출 섬광) |
| LOOP 15s | ① 뒤쪽 양 펜더에 파란 전기 아크가 지지직(A/B 교대, 뒷부분만) ② 배기구에서 짧고 옅은 청록 에너지 줄기(저장된 에너지가 새어 나옴) ③ **부스터 작동 중**에는 청록 방출 줄기가 크고 밝게 분출 | PARTICLE ×2(아크 A/B) + PARTICLE(옅은 줄기) + **TEXTURED_SPRITE(방출, `boost_active` 입력으로 불투명도·크기 변조)** |
| END 0.3s | 새 발생 중단, 자연 소진 | 빈 phase |

- 전 레이어 ADDITIVE, `UNDER_VEHICLE`(아크·방출은 차 가장자리/뒤로 나옴).
- 구분: 광합성 = 금빛이 사방에서 직선으로 모임 + 연두 아크 하부 전체 / 분노의 추월 = 진홍 균열이 차 전체 + 진홍 빛줄기 / 레인 서퍼 = 파란 네온 하부광 + 노면 잔류 / 윈드 레이서 = 흰 기류선 앞→뒤 / 스노우 보더 = 청록 노면 잔류 ↔ 에너지 전환 = **회전하며 빨려드는 소용돌이(시작) + 뒷부분만 파란 아크 + 배기구 청록 방출(부스터 시 분출)**. 노면 잔류·하부광 없음.
- 부스터 불꽃(주황)과 같은 위치에 나오지만 색(청록)·형태(곧은 에너지 줄기)로 구분. 겹침은 Game에서 확인.
- 교훈 적용: 텍스처 기반, 가는 선 금지(게임 크기 기준), 작은 반짝임 금지, 이동/주기 파티클은 옅게 겹쳐 연속, START가 LOOP 첫 발생까지 연결.

## 4. 부스터 연동 (선택 사항 — 사용자 개발 승인 2026-10-02)

- 새 런타임 입력 **`boost_active`**: number 0~1, 기본 0. 의미: 해당 차량의 일반 부스터가 작동 중이면 1, 아니면 0. 깜빡임 방지를 위해 Game에서 **켜질 때 약 0.08s, 꺼질 때 약 0.3s로 부드럽게 보간한 값**을 넘긴다(Studio 변조는 즉시 반영이므로 보간은 입력 쪽 책임).
- Studio: `schemas/vfx_schema_v1.json` `x_vfx_runtime_inputs`에 `boost_active` 추가, 문서(`docs/VFX_SCHEMA_V1.md`, `docs/VFX_STUDIO_ARCHITECTURE.md`)·미리보기 슬라이더 추가(Claude). 이 preset은 `runtime_inputs: ["boost_active"]` → Runtime 버전은 export 결과를 따른다(speed 입력 package와 같은 방식 예상).
- Game(Codex): 입력 계약에 `boost_active` 추가, `CarAgent` 런타임 스냅샷에 값 공급(`boost_active` bool → 보간), `VfxEffectInstance` 변조 슬롯 연결. 슈퍼 부스터는 대상 아님(효과가 일반 부스터 성능) — Codex 사전 확인에서 판단 보고.
- 사전 확인: `docs/handoffs/2026-10-02-energy-conversion-boost-input-codex-precheck.md`.
- **Codex 사전 확인 결과(2026-10-02, 읽기 전용)**: 추가 가능, 기존 입력 변조·TEXTURED_SPRITE renderer 재사용. 계약 `number 0~1 기본 0` 유지. 변조가 있으면 compiler가 Runtime v2 선택(Package v1·Schema v1 유지). **Game loader는 모르는 입력 이름도 구조만 맞으면 받아들이므로, 로딩 성공 ≠ 공급 지원 — 인계 시 공급 연결을 명시적으로 확인.** 공급: `CarAgent` 기존 스냅샷 갱신에서 원시 상태, 판정은 `CarAgent.boost_active`가 아니라 `_is_normal_boost_effective()` + 벤치마크 고정 부스트 제외(슈퍼 부스터 중 잔존값 문제), 준비·정지·피트는 0, 날씨 배율이 걸린 일반 부스터는 대상. 보간: `VfxEffectInstance`에서 해당 입력 슬롯을 가진 effect만 선형 보간(켜짐 0.08s / 꺼짐 0.3s) — 재능 없는 차량엔 보간 비용 없음.
- **Studio 반영(Claude, 2026-10-02)**: `schemas/vfx_schema_v1.json` `x_vfx_runtime_inputs.boost_active` 추가, `docs/VFX_SCHEMA_V1.md`(의미·보간·시작 0·일시정지 유지·종료 처리)·`docs/VFX_STUDIO_ARCHITECTURE.md` 갱신, 미리보기 `Boost` 슬라이더 + 토글(Game과 같은 0.08s/0.3s 램프). 임시 preset으로 검증·export 계획 통과(manifest `runtime_inputs: ["boost_active"]`, Runtime v2) 확인 후 삭제. preview 436 / contract 204 / export contract 70 실패 0, editor 401 중 기존 4 실패.

## 5. 최종 수치 (Studio 시안 승인 2026-10-02)

좌표: 차량 source px(256×512, CENTER, 전방 −Y), 뒤끝 ≈ +235. 전 레이어 ADDITIVE·UNDER_VEHICLE, 색 곱 흰색. 실제 일반 부스터(`driving.standard_boost`)는 빨간 불꽃 4개(x ±22·±66, y +290~+377) — 영상의 큰 불꽃과 다름(사용자 지적) → 청록 방출은 가운데 좁게(±55 이내) 시작해 불꽃보다 뒤로 이어지게 배치.

| layer | 내용 |
|---|---|
| `start.swirl` | 소용돌이 BURST 1, (0, 0), 수명 0.55s, 크기 420→150, 각속도 −420°/s, 알파 0.9 → 0 |
| `start.release_flash` | 방출 BURST 1, (0, +403.8)(뿌리 = 뒤끝), 수명 0.8s, 크기 200→240 |
| `start.arc_entry` | 아크 A BURST 1, (−5.0, +120), 수명 1.4s(첫 LOOP 아크 ≈1.31s까지), 크기 170.5→179 |
| `loop.arc_a` / `loop.arc_b` | 아크 A/B 1.4 / 1.15 per s, max 2, (−5.0 / −8.9, +120), 수명 1.0 / 1.2s, 크기 170.5→179, 알파 1 → 0. **x 보정**: GPT 텍스처의 좌우 아크 중간점이 A +3.75 / B +6.7 texel 오른쪽으로 치우침(사용자 지적 "우측이 더 보임") |
| `loop.release_trickle` | 방출 6/s max 3, (0, +344.7), 방향 180° 속도 30, 수명 0.5s, 크기 130→150, 알파 0.38 |
| `loop.boost_release` | TEXTURED_SPRITE 방출, (0, +386.2), scale (1.15, 1.4), pivot (0, −151.2)(= 뒤끝 뿌리), opacity 0.95. `boost_active` 0→1 ⇒ 불투명도 ×0→1, 길이(scale Y) ×0.5→1.0, 폭(scale X) ×0.85→1.15 |

START 0.6s / END 0.3s(빈 phase). importance CORE 7. `runtime_inputs: ["boost_active"]` → **Runtime v2**. 차량당 스프라이트 LOOP 최대 8(아크 4 + 줄기 3 + 방출 1).

## 5-1. 초기 수치안 (시안 출발점, 기록용)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 뒤끝 ≈ +235, 뒷바퀴 ≈ (±84, +160).

- `start.swirl` `fx.energy_conversion_swirl` BURST 1, offset (0, 0), 수명 0.7, 크기 520 → 220(빨려듦), 각속도 −360°/s, 알파 1 → 0.
- `start.release_flash` `fx.energy_conversion_release` BURST 1, offset 뿌리가 뒤끝, 수명 0.6, 크기 200 → 260, 알파 1 → 0(LOOP 첫 발생까지 연결).
- `loop.arc_a` / `loop.arc_b` `fx.energy_conversion_rear_arc_a/b` CONTINUOUS 1.4 / 1.15 per s, max 2, offset (0, +110)(뒷부분), 수명 1.0 / 1.2, 크기 300 → 320, 알파 0.85 → 0(광합성 A/B 교대 방식).
- `loop.release_trickle` `release` CONTINUOUS 6/s, max 3, 뿌리 뒤끝, 방향 180° 속도 30, 수명 0.5, 크기 150 → 170, 알파 0.35 → 0.
- `loop.boost_release` `release` TEXTURED_SPRITE, 뿌리 뒤끝, 기본 opacity 0.95, 변조 `boost_active` 0→1 ⇒ VISUAL_OPACITY_MULTIPLIER 0→1, TRANSFORM_SCALE_Y 0.6→1.3.

Preset: `presets/examples/talent.energy_conversion.vfx.json`, preset_id `talent.energy_conversion`, `RACE_TALENT`, `START_LOOP_END`.

## 6. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-energy-conversion-gpt-art-request.md) — 4장.
`talent_energy_conversion_swirl.png`(320×320), `talent_energy_conversion_rear_arc_a.png` / `_b.png`(256×192), `talent_energy_conversion_release.png`(96×256).

## 7. 시안 이력 (사용자 Studio 녹화 검토 3회, 일반 부스터 겹침 비교용 preset 사용 후 삭제)

1. 소용돌이가 차 길이 약 2배로 너무 크고 진함, 아크가 작고 흐림 → 소용돌이 560→240을 420→150·0.55s·−420°/s, 아크 알파 1.0·크기 155.
2. 소용돌이 흡수감·아크 번개 확인, 부스터 불꽃과 청록 분출 구분 확인. 사용자: 아크가 중심에서 어긋나 우측이 더 보임, 10% 확대, 청록 분출 폭 약간 넓게 → 텍스처 치우침 측정 후 x 보정, 크기 170.5, 방출 scale X 1.15·변조 0.85→1.15, 줄기 130→150.
3. **승인**.
4. **Game 적용 후(2026-10-02)**: 사용자 요청 — 청록은 부스터 때만 → 상시 줄기 `loop.release_trickle` 제거(발동 순간 `start.release_flash` 유지). REPLACE_EXISTING 재생성, 재적용 요청 `docs/handoffs/2026-10-02-energy-conversion-boost-only-teal-codex.md`. Claude 부하 측정(방어 조건 강제 6대 발동): 프레임 +0.1ms, draw +37, 발동 순간 튐 없음.

## 8. 다음 작업

1. Codex: [인계](../../handoffs/2026-10-02-energy-conversion-codex-handoff.md) — package·연결·legacy 억제·`boost_active` 공급/보간.
2. Claude: 적용 후 부하 측정(probe).
3. 사용자: 발동 + 부스터 사용 경기 녹화 → Claude 검토(청록 분출 굵기).