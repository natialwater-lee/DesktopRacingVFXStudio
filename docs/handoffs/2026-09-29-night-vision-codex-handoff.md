# 나이트 비전 / Night Vision — Game 적용 인계 (Studio → Codex)

2026-09-29 · 작성: Claude Code (Studio 담당) · 대상: Game GPT Codex

공용 작업 안내 `DesktopIdleRacing/docs/VFX_EXPORT_PACKAGE_V1.md#shared-vfx-workflow`의 공통 인계 형식을 따른다. 연출 합의·수치 이력은 Studio `docs/superpowers/specs/2026-09-29-talent-night-vision-design.md`.

## 0. 작성 주체 차이 — 먼저 읽을 것

이전 재능 package(Zero Zone, Photosynthesis, Solo Run)는 GPT/Codex 쪽 흐름으로 Studio 작업·인계가 이뤄졌다. **이번 나이트 비전은 연출 기획, Studio preset 작성, package 생성까지 모두 Claude가 수행했다.** 결과물 형식은 같은 Studio 파이프라인에서 나왔지만, 아래 차이가 있으므로 기존 관례를 전제하지 말고 코드와 package 기준으로 판단해 달라.

| 항목 | 이번 작업 | 기존과 같은 점 / 다른 점 |
|---|---|---|
| preset 작성 | JSON을 직접 작성함(에디터 UI의 저장 기능 미사용) | Studio 검증기 `VfxPresetPipeline.load_and_validate` 통과. package 안의 source 파일은 preset과 byte 동일 |
| package 생성 | 에디터 Export 버튼 대신, headless 일회성 스크립트에서 `VfxExportService.export_saved_source(..., "FAIL_IF_EXISTS")` 호출 | 버튼과 같은 service·compiler·atomic writer 경로. 스크립트는 저장소에 남기지 않음 |
| Runtime Definition | **v1** (compiler가 자동 선택. modulation·runtime_inputs 없음) | Zero Zone과 같은 v1. Photosynthesis는 v2. 새 버전이나 새 profile 없음 |
| layer type | GLOW, PARTICLE, **RING** | **RING은 운영 package 중 처음 사용함.** 기존 운영 package에는 RING이 없음(`VfxRuntimeRenderingTest` 단위 검사만 있음). 아래 3-2에서 확인 필요 |
| Studio 테스트 | focused 검사 파일을 추가하지 않음 | Photosynthesis에는 `tests/preview/test_photosynthesis_authoring.gd`가 있었음. Studio 전체 회귀는 실행하지 않음 |
| 계약 변경 | 없음 | Studio schema/compiler/renderer와 Game 코드 모두 변경하지 않음 |
| Game 분석 | Claude가 Game을 **읽기 전용으로만** 확인한 추정 | 아래 4장의 결론은 실행 검증이 아님. Codex가 실제 실행으로 재확인해야 함 |

기존 문서의 표현(예: "Game 후속 작업" 기록, 과거 수치)과 이 문서가 충돌하면 **이 문서와 package 파일이 최신**이다. 그래도 불명확하면 추측하지 말고 사용자에게 확인한다.

## 1. 작업 재능 / ID

- 재능: `night_vision` (`data/racers/race_ability_defs.json`, duration 20초, 밤 조건)
- preset·package ID: **`talent.night_vision`**
- Package format 1 / Runtime Definition v1 / VFX schema 1 / category `RACE_TALENT` / lifecycle `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` 1개 / runtime_inputs `[]`
- 대체할 legacy 효과: `vehicle_fx_id`/`visual_profile_id` = `night_vision_scan` (`RaceAbilityVisualController.gd`)

## 2. 전달물 (Studio, 읽기 전용 원본)

`C:\GodotProjects\DesktopRacingVFXStudio\exports\packages\talent.night_vision\`

| 파일 | byte | sha256(앞 12자) |
|---|---:|---|
| `manifest.json` | 1726 | — |
| `assets/talent_night_vision_scan_arc.png` | 73144 | 4abc6be13bb4 |
| `runtime/vfx_runtime_definition_v1.json` | 7408 | a52f49e7e25d |
| `source/talent.night_vision.vfx.json` | 6911 | e17dad38f38d |

전체 hash는 `manifest.json`에 있다. Studio 쪽 변경은 아직 커밋하지 않았다(사용자가 커밋 예정). 복사할 때는 위 폴더의 파일을 그대로 사용한다.

### 연출 요약 (preset 기준, 좌표는 차량 source px 256×512, 전방 -Y)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.45s | `start.pulse_ring` RING CORE | radius 140→520, width 40, alpha 0.5→0, 0.45s, 반복 없음 |
| | `start.core_flash` GLOW DETAIL | radius 240, opacity 0.35, pulse_hz 0 |
| | `start.scan_arc_entry` PARTICLE CORE | BURST 1개, lifetime **1.0s(START 길이보다 김)**, speed 530, 크기 105→250 |
| LOOP (Game 소유, 20s) | `loop.forward_wash` GLOW DETAIL | 앞코에 붙은 긴 타원 조명. radius 280, offset (0,-360), scale (0.7,1.6), opacity 0.12 |
| | `loop.scan_arc` PARTICLE CORE | CONTINUOUS 2.0/s, max 2, lifetime 0.75, speed 700, 크기 105→250, 전방(direction 0) |
| END 0.35s | `end.forward_wash_fade` GLOW DETAIL | loop 조명과 같은 배치, opacity 0.05 |

- 전 layer: `ADDITIVE`, `UNDER_VEHICLE`.
- END에는 새 호가 없다. loop에서 나간 호는 방출이 멈춘 뒤 스스로 소진되어야 한다.
- LOW LOD에서 CORE만 남아도 링과 스캔 호로 재능을 알아볼 수 있다.

## 3. Codex 요청 작업

계약 변경이 없으므로 아래는 기존 도입 절차의 범위다.

1. **package 도입**: 위 폴더를 `res://assets/vfx/packages/talent.night_vision/`에 byte 그대로 복사한다. PNG `.import`는 Game 에디터 import로 생성한다. package JSON은 Game에서 고치지 않는다. 문제가 있으면 Studio로 되돌려 재생성한다.
2. **catalog**: `data/vfx/vfx_package_catalog.json`의 `package_ids`에 `"talent.night_vision"`을 추가한다.
3. **재능 연결**: `scripts/race/RaceAbilityVfxIntegrationController.gd`의 `ABILITY_PRESET_IDS`에 `"night_vision": "talent.night_vision"`을 추가한다.
4. **legacy 억제 확인**: package 소유 시 `should_suppress_legacy_vehicle_fx("night_vision")` 경로로 `night_vision_scan`이 재생되지 않는지 확인한다(`RaceManager.gd` ≈18275, `RaceAbilityVisualController.gd` 128/177). 이중 재생 금지.

### 3-2. Game에서 확인해 달라는 항목

- **RING 운영 첫 사용**: loader → `VfxRendererFactory.preflight_effect/preflight_layer` → `VfxRingRuntimeRenderer`가 실제 경기에서 정상 동작하는지 확인한다. RING의 필수 파라미터 7개(radius_start/end, width, duration_seconds, repeat_interval_seconds=0, alpha_start/end)와 color_rgba는 모두 들어 있다.
- **START의 BURST 호 소진**: START 구간(0.45s)이 끝난 뒤에도 수명 1.0s인 호가 끝까지 이어지는지 확인한다. 참고 선례로 Zero Zone `start.tunnel_arc_entry`(수명 0.74s > START 0.16s)가 있다. 도중에 잘리면 시작 호가 너무 일찍 사라져 보인다.
- **종료·정리**: duration이 끝나 `_end_state_effect(..., "duration_elapsed")`가 호출되면 END 재생 후 남은 호가 소진되는지 확인한다. `force_clear_vehicle`, `clear_race`에서는 즉시 제거되어야 한다. 재발동도 확인한다.
- **판독성(실제 경기)**: 밤 조건이라 `driving.headlights`가 항상 같이 켜져 있다. 전방 청록 타원과 흰 헤드라이트가 겹친 상태에서 스캔 호가 읽히는지, 그리고 Hyper 외 차종에서도 읽히는지 확인한다. Studio에서는 헤드라이트 없이만 확인했다.
- **동시 발동 부하**: 5~8대가 동시에 재능 VFX를 가진 상황(날씨·부스터가 상시 발생)을 기준으로 확인한다. 검증 조건은 이 재능의 실제 규칙(밤 + 15초 후 30% 확률, 20초 지속)에 맞춰 정한다. 독주의 검증 조건을 그대로 쓰지 않는다.

## 4. Claude의 Game 읽기 전용 분석 (실행 검증 아님)

- **파티클 좌표계**: `project.godot`의 렌더링 방식이 `gl_compatibility`이므로, `VfxParticleRuntimeRenderer`는 CPU 백엔드(`VfxCompatibilityParticleRuntimeRenderer`)를 쓴다. 이 경우 Sprite2D가 renderer의 자식이라 호가 차량을 따라간다. 이는 Studio preview(VEHICLE_LOCAL)와 같다.
  - 참고로 GPU 경로(`mobile`/`forward_plus`)의 `GPUParticles2D`에는 `local_coords` 설정이 없다(기본값 world). 렌더링 방식을 바꾸면 호가 노면에 남을 수 있다. 현재 설정에서는 영향이 없다고 판단했다.
- **준비 비용**: CPU 경로에서 발동할 때마다 만드는 것은 renderer 노드와 PARTICLE Sprite2D 풀(loop 2개 + start 1개)이다. material은 `cache.get_material_for_blend_mode`로 공유하고, 텍스처는 package에서 한 번만 읽는다. Gradient/Curve는 만들지 않는다. RING은 수명 동안 `draw_arc` 48분할로 그린다. 별도의 사전 준비(Static Ribbon식 SETUP 워밍업)는 필요 없다고 판단했다.
- **CONTINUOUS 첫 방출 지연**: `VfxParticleEmissionScheduler`는 누적값 0에서 시작하므로 loop의 첫 호가 loop 시작 후 1/rate(0.5s) 뒤에 나온다. 이 동작을 고치라는 요청이 아니다. 이미 preset에서 START의 BURST 호로 이 공백을 메웠다.

## 5. 검증

**실행한 것 (Studio, Godot 4.7.1)**
- 새 PNG headless import
- preset 검증(`VfxPresetPipeline.load_and_validate`) 통과, 텍스처 512×192 로드
- package 생성 1회 성공. source/asset 파일이 원본과 SHA-256 동일함 확인
- Studio Game Canvas 100% 녹화(사용자 제공)로 프레임 단위 시각 검토 2회

**실행하지 않은 것**
- Studio 전체 회귀, focused 테스트 파일 추가, canonical 재export
- Game 실행, Game 테스트, 실제 경기 판독성, 헤드라이트와 겹친 상태, 성능 측정
- 참고: 사용자 녹화 속 차량이 약 45×88px로, 실제 게임 크기(20~24×41~49px)의 약 2배였다(화면 배율 추정). 실제 크기에서는 링과 조명이 더 옅게 보일 수 있다.

## 6. 사용자 시각 승인

- Studio 시안: **승인**(2026-09-29). 2차 보정(시작 호 수명과 속도) 반영 후 package 생성을 지시받음.
- Game 실제 경기 외형: **미승인**. Codex 적용 후 사용자가 확인한다.

## 7. 다음 담당자 작업

- **Codex**: 3장 도입·연결 → 3-2 확인 → 결과를 공통 인계 형식으로 보고. 외형 수정이 필요하면 Game에서 package를 고치지 말고 수치·현상을 Studio(Claude)로 전달한다.
- **사용자**: Game 실제 경기에서 최종 시각 승인. Studio 변경분 커밋.
- 수정하지 말 것: Solo Run `talent.solo_run.static_ribbon`, Photosynthesis, Zero Zone, 기존 package, 재능 판정·게임플레이·저장 데이터. 포스필드 타이어 보조 VFX 재개 금지.
