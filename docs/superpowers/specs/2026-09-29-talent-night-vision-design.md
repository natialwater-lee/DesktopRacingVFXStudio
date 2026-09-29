# 나이트 비전 / Night Vision — 연출 합의 및 Claude Code 인계

2026-09-29. 연출 방향은 사용자 승인 완료(추천안). 아트 리소스 1장 수령·검수 완료.
**현재 상태(2026-09-29):** Studio 구현·사용자 시각 승인·package 생성 완료(Claude Code). Game 적용 요청은 [Codex 인계](../../handoffs/2026-09-29-night-vision-codex-handoff.md) 참고. 최종 수치는 preset 파일이 기준이며 아래 4장은 초기안 기록.

먼저 읽을 것: `docs/TALENT_VFX_GUIDELINES.md`(제작 지침 + 사용자 보충 지시), Game 공용 안내 `../DesktopIdleRacing/docs/VFX_EXPORT_PACKAGE_V1.md#shared-vfx-workflow`.

## 1. Game 정의 (읽기 전용 확인 결과)

- `data/racers/race_ability_defs.json` → `night_vision`: trigger `condition_after_active_racer_time` (condition `night`, 15초), activation_chance 0.3, **duration 20초**, effect: 야간 환경 페널티 0, 추월 배율 1.3. `vehicle_fx_id`/`visual_profile_id` = `night_vision_scan`(기존 legacy 효과 — package 소유 시 `should_suppress_legacy_vehicle_fx`로 억제됨).
- 종료: `RaceAbilityRuntimeController._end_state_effect(state, "duration_elapsed")`. 그 외 force clear / clear_race는 `RaceAbilityVfxIntegrationController`가 처리.
- 밤 조건이므로 **`driving.headlights`(흰색 좁은 전방 빔, TEXTURED_SPRITE 4장, offset y≈-318~-379)가 동시에 켜져 있음**. 나이트 비전은 이와 구별되어야 함.

## 2. 참고 자료

- 컷인 컨셉 이미지·영상: `docs/references/night_vision/night_vision_cutin_concept.png`, `night_vision_cutin.mp4`(4초, 854×480).
- 추출한 핵심: ① 발동 순간 차량 발밑 청록 원판 펄스(≈0.5s) ② 차량 전방 노면에 깔리는 부채꼴 청록 스캔광 + **앞으로 퍼지는 호형 스캔선**(소나/라이다 느낌, 재능 정체성) ③ 차량 가까이 밝고 멀수록 소멸.
- 생략·변경: 카메라·배경·반사 제거. 부채꼴 면 전체를 밝게 칠하지 않음(앞차·트랙 가림) → 옅은 전방 조명 + 움직이는 호로 표현. 전방향 파동은 시작 1회만(충격파와 구분).

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.45s | 발밑 청록 링이 차폭 약 2배까지 퍼지며 소멸 + 중심 짧은 섬광 | RING 1 + GLOW 1 (절차적) |
| LOOP 20s(Game 소유) | 전방 옅은 청록 조명. 약 0.6s 간격으로 스캔 호가 앞코에서 나와 커지며 약 1차 길이 앞까지 진행 후 소멸. 동시 호 최대 2 | GLOW 1 (DETAIL) + PARTICLE 호 (CORE) |
| END 0.35s | 새 호 없음, 남은 호 자연 소진, 링이 차량 쪽으로 수렴하며 소멸 | RING 1 (radius 축소) + 옅은 GLOW |

LOW LOD에서는 CORE인 스캔 호만 남아도 재능 식별 가능해야 함.

### 1차 시안 보정 (2026-09-29, 사용자 승인)

Studio 녹화 검토 후 반영. 아래 4장 초기 수치보다 우선.
- START에 `start.scan_arc_entry`(PARTICLE CORE, BURST 1, loop 호와 동일 수치) 추가 — CONTINUOUS 누적기가 0에서 시작해 첫 호가 1/rate초 늦게 나오던 시작→루프 공백 제거(Game scheduler도 동일 동작).
- 전방 조명(loop/end 공통): 떠 있는 원판 → 앞코에 붙은 긴 타원. radius 280, offset [0,-360], scale [0.7,1.6].
- `start.pulse_ring`: width 40, alpha_start 0.5 (얇은 UI 원 인상 완화).
- `end.converge_ring` 삭제 — 전방향 원 반복 제거(충격파와 구분). END는 남은 호 자연 소진 + 조명 페이드.
- `loop.scan_arc` rate 1.6 → 2.0 (max_particles 2 유지).

### 2차 보정 (2026-09-29, 사용자 승인 → package 생성)

- `start.scan_arc_entry` lifetime 0.75 → 1.0, speed 700 → 530 (진행 거리 ≈ 동일). 첫 loop 호(발동 후 ≈0.95s)까지 끊김 없이 이어지도록 함.

## 4. 초기 수치안 (시안 출발점 — 게임 크기에서 조정)

좌표: 차량 source px(256×512, CENTER, 전방 -Y). Hyper 게임 배율 ≈0.095. 전 레이어 `VEHICLE_LOCAL`, anchor `CENTER` 1개, `ADDITIVE`, `UNDER_VEHICLE`. 색 기준 청록 ≈ [0.25, 0.9, 1.0].

- `start.pulse_ring` RING CORE: radius 140→520, width 22, duration 0.45, repeat 0, alpha 0.85→0.
- `start.core_flash` GLOW DETAIL: radius 240, opacity ≈0.35, pulse_hz 0, scale [0.9,1.3].
- `loop.forward_wash` GLOW DETAIL: offset [0,-400], radius ≈300, scale ≈[1.2,1.0], opacity ≈0.12, pulse_hz 0.
- `loop.scan_arc` PARTICLE CORE: offset [0,-250], emitter POINT, CONTINUOUS, rate ≈1.6/s, max_particles 2, lifetime ≈0.75, direction 0, spread 0, speed ≈700(min=max), acceleration [0,0], rotation 0, angular velocity 0, size_start ≈105 → size_end ≈250 (긴 변=2×size → 폭 약 20→48 게임 px), alpha 0.95→0, color 흰색에 가까운 청록(텍스처 색 유지).
- `end.converge_ring` RING DETAIL: radius ≈420→150, width ≈16, duration 0.35, alpha ≈0.5→0.
- `end.forward_wash_fade` GLOW DETAIL: loop와 같은 배치, opacity ≈0.05.

Preset 제안: `presets/examples/talent.night_vision.vfx.json`, preset_id `talent.night_vision`, category `RACE_TALENT`, lifecycle `START_LOOP_END`, runtime_inputs `[]`, modulation 없음 → Runtime Definition v1.

## 5. 아트 리소스 (수령·검수 완료)

- 파일: `assets/vfx/talent_night_vision_scan_arc.png` (이미 배치됨, 아직 카탈로그·export 정책 미등록, `.import` 미생성)
- 512×192 RGBA straight alpha, 배경 alpha 0, 가장자리 여백 alpha 0, 투명부 RGB 청록(가산 합성 시 어두운 테두리 없음). bbox x8–503, y12–155. 위쪽 볼록 = 차량 전방, 가로 중앙 정렬, 좌우 대칭 1장.
- 게임 크기 폭 20/34/48px 가산 합성 모의 확인: 모두 호로 판독됨. 요청 가이드보다 호 각도가 약간 넓고 잔광이 약 30px로 짧지만 판독성상 유리하여 수용.
- 등록할 logical ID: `fx.night_vision_scan_arc` → preview 카탈로그 `assets/preview/vfx_preview_asset_catalog_v1.json`(TEXTURE) + `config/vfx_export_asset_policy_v1.json`(EXPORTABLE TEXTURE_PNG). 기존 항목 형식을 그대로 따를 것.

## 6. Game 지원 판단 (코드 확인 결과)

`scripts/vfx/runtime/VfxRendererFactory.gd` 및 각 renderer `validate_layer` 기준:
- START_LOOP_END만, START/END duration > 0 필요 → 0.45 / 0.35 충족.
- VEHICLE_LOCAL, UNDER/OVER_VEHICLE, anchor 정확히 1개 → 충족.
- RING / GLOW(pulse_hz 0만) / PARTICLE(emitter POINT·CIRCLE·BOX만) 지원 → 모두 충족. TRAIL·SHIELD 미사용.
- 계약 변경·공통 기능 확장 **없음**. Codex 작업은 `RaceAbilityVfxIntegrationController.ABILITY_PRESET_IDS`에 `"night_vision": "talent.night_vision"` 추가 + `data/vfx/vfx_package_catalog.json` 등록 + package 도입.

## 7. 우선 확인할 미해결 항목

1. **Game PARTICLE 좌표계**: `VfxParticleRuntimeRenderer`는 `GPUParticles2D`를 쓰며 `local_coords` 설정을 확인하지 못함(Godot 4 기본값 false = world). world이면 방출 후 호가 차량에 붙어 가지 않고 노면에 남아, 주행 속도에 따라 차량이 호를 따라잡을 수 있음. Studio preview(`vfx_particle_layer_renderer.gd`)의 VEHICLE_LOCAL 동작과 Game 동작이 일치하는지 먼저 확인하고, 불일치면 속도·수명 조정 또는 Codex 요청으로 처리.
2. GPU 파티클 renderer의 인스턴스당 준비 비용(material/curve/gradient 생성 시점) — 5~8대 동시 발동 기준으로 매 발동 시 리소스 생성이 있는지 확인.
3. 헤드라이트와 겹친 상태의 게임 크기 판독성(Game Canvas 100%, Hyper 외 차종 포함).

## 8. 다음 작업 (Claude Code)

1. 위 7-1, 7-2를 해당 파일 범위만 읽어 확인.
2. asset 등록(카탈로그·export 정책), preset 작성.
3. Studio 실행 → Game Canvas 100%에서 시각 확인, focused 검사와 parse/diff만. 전체 회귀·반복 export·대량 캡처 금지.
4. 사용자 시각 승인 후 package 1회 생성 → 공용 인계 형식으로 Codex에 전달.

수정하지 않을 것: 독주 static_ribbon, 광합성, 제로의 영역, 기존 package, Game 파일. 포스필드 타이어 보조 VFX 재개 금지.
