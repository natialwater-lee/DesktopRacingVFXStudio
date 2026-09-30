# 레인 서퍼 / Rain Surfer — Game 적용 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-09-30-talent-rain-surfer-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package다. 연출 기획·preset 작성·package 생성은 Claude가 했다(preset은 생성 스크립트로 작성 후 Studio 검증기·export 통과, repo preset = package `source` byte 동일). 이전 GPT 흐름의 관례와 다를 수 있으니 package와 실제 코드 기준으로 판단해 달라.
- **`VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE을 쓰는 첫 운영 package**다(Game v0.2-35.30.18 엔진 지원, 합의 범위 PARTICLE·UNDER_VEHICLE·non-bent 그대로). 비·눈 타이어 package가 한때 썼다가 wake로 대체되어 현재 운영 사용처가 없다.
- Studio preview는 차량이 이동하지 않아 **빛줄기가 주행 경로에 남는 모습은 Studio에서 검증하지 못했다.** 수명·간격은 Codex 계측(직선 ≈200, 코너 ≈119 화면 px/s)으로 계산한 값이다. 실제 경기에서 선이 끊겨 보이거나 과하면 수치·현상을 Studio로 알려 달라.

## 1. ID / 버전

`rain_surfer` → **`talent.rain_surfer`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / 기본 `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음. **필요 Game ≥ 0.2-35.30.18.**

Game 정의(읽기 전용 확인): 비 날씨 15초 주행 후 30%, 20초, 빗길 페이스 ×1.10. legacy `rain_cool`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).

## 2. 전달물 (Studio `exports/packages/talent.rain_surfer/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 3046 | 553fe65b7802 |
| `assets/talent_rain_surfer_splash_wing.png` (160×128) | 33732 | 08d6225c275e |
| `assets/talent_rain_surfer_neon_a.png` (192×320) | 85429 | eacdf9740f70 |
| `assets/talent_rain_surfer_neon_b.png` (192×320) | 83174 | 6ec8a34e78b9 |
| `assets/talent_rain_surfer_light_trail.png` (32×128) | 7595 | 6b78823afb34 |
| `runtime/vfx_runtime_definition_v1.json` | 10559 | 00eafa05e956 |
| `source/talent.rain_surfer.vfx.json` | 10144 | 00f69b1b422d |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.6s | `start.bow_splash` CORE | `splash_wing` BURST 1, 회전 180°(뿌리가 앞코, 두 날개가 양옆 뒤로), offset (25, −41)(텍스처 뿌리가 중심에서 6px 치우쳐 보정), 방향 180° 속도 108, **수명 0.75s(START보다 김)**, 크기 280 → 400, 알파 1 → 0 |
| | `start.neon_on` CORE | `neon_a` CONTINUOUS 5/s·max 2(**첫 방출 0.2s 지연을 의도적으로 사용**), 수명 1.2s, 크기 300 → 360, 알파 0.9 → 0 |
| LOOP (Game 소유 20s) | `loop.neon_a` / `loop.neon_b` CORE | 하부 네온 변형 2장을 1.3 / 1.05 /s, max 2, 수명 1.1 / 1.3s, 크기 340 → 368, 알파 0.7 → 0, 속도 0으로 번갈아 겹침(광합성 기운과 같은 방식) |
| | `loop.trail_left` / `loop.trail_right` CORE, **`VEHICLE_FOLLOW_WORLD_TRAIL`** | `light_trail`, offset (∓84, +200)(공통 뒷바퀴 접점 x), POINT, **16/s, max 7, 수명 0.4s**, 속도 0, 회전 0(생성 순간 차량 방향 캡처), 크기 70 → 60, 알파 0.85 → 0 |
| END 0.4s | (레이어 없음) | 새 발생 중단, 남은 네온(최대 1.3s)·빛줄기(0.4s) 자연 소진 |

- 빛줄기 계산: 직선 200px/s·16/s → 조각 간격 ≈12.5px, 조각 길이 ≈13px(크기 70 source × 2 × 0.095) → 겹쳐서 연속 선, 꼬리 ≈80px. 코너 119px/s → 간격 ≈7px, 꼬리 ≈48px.
- 차량당 스프라이트 최대 네온 4 + 빛줄기 14 = 18, 렌더러 4(LOOP).

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.rain_surfer/`), catalog 등록.
2. `RaceAbilityVfxIntegrationController.ABILITY_PRESET_IDS`에 `"rain_surfer": "talent.rain_surfer"`.
3. legacy `rain_cool` 차량 효과가 package 소유 시 억제되는지 확인. **`player_screen_fx_id: rain_cool`(화면 효과)을 유지할지는 현재 다른 재능 package의 처리와 같게** 하고, 어떻게 했는지 보고해 달라.

## 5. 확인 요청 (체크리스트)

1. **월드 잔류 첫 운영 사용**: ADDITIVE 파티클이 월드 host(자국 위·차량 아래)에서 가산 합성으로 그려지는지, 생성 순간 위치·회전·배율 캡처, 직선에서 선이 이어지고 코너에서 휘는지, 조각 사이가 끊겨 점선으로 보이지 않는지.
2. **phase보다 긴 수명**: `start.bow_splash` 0.75s·`start.neon_on` 1.2s > START 0.6s, LOOP 네온·빛줄기가 빈 END(0.4s) 뒤 소진. STOP·force clear·차량 제거·트랙 교체·레이스 정리 시 월드 조각 정리.
3. **첫 방출 지연**: LOOP 네온 첫 입자 ≈0.77s/0.95s 뒤(START 네온이 메움), 빛줄기 ≈0.06s 뒤.
4. **기존 효과와 겹침**: 비 wake 띠(회색, 같은 뒷바퀴 위치)·젖은 타이어 자국·바퀴 빗방울·트랙 강수(z 4000)·부스터 불꽃과 함께 파란 빛줄기가 구별되는지. wake와 같은 위치라 빛줄기가 묻히면 알려 달라.
5. **저속·정지**: 빛줄기 발생률은 속도와 무관 → 거의 멈추면 뒷바퀴 뒤에 조각이 겹쳐 밝게 뭉칠 수 있음. 눈에 띄는지.
6. **부하**: 비·20대에서 5~8대 동시 발동 frame·draw call(월드 host의 CPU 풀 파티클 14/대).

## 6. 검증

- Claude 실행: PNG 4장 육안 검수(수치 측정은 물보라 뿌리 위치만), Studio 검증기·export, package 1회 생성, 새 Studio 테스트 `tests/preview/test_rain_surfer_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 5종 — preview 418 / export contract 70 / performance 61 assertions 실패 0. editor 묶음 401 중 4 실패(기존 skeleton/schema 테스트, 이번 변경과 무관·원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 빛줄기의 실제 이동 중 모습, 비 환경과의 겹침.
- 사용자 Studio 녹화 검토 5회(유지 중 물보라 제거, 시작 물보라 중심·지속 보정).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-09-30, "게임에 적용하자"). 단 빛줄기 잔류는 Studio에서 볼 수 없어 승인 범위 밖.
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 도입·연결 → 5 확인 → 공통 인계 형식 보고(빛줄기 실제 모습 캡처 포함). 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 비 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터. 승인 없는 commit 금지.
