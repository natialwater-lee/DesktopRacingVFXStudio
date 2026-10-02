# 스노우 보더 / Snow Boarder — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-snow-boarder-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(preset은 생성 스크립트로 작성 후 Studio 검증기·export 통과, repo preset = package `source` byte 동일). 이전 GPT 흐름 관례와 다를 수 있으니 package와 실제 코드 기준으로 판단해 달라.
- 계약·코드 변경 없음 예상. 쓰는 기능은 모두 Game에서 이미 검증됨: **`VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE**(레인 서퍼 빛줄기), **ALPHA PARTICLE**(`driving.snow_tire_spray`), 회전 고정 BURST.
- **Studio 미리보기 차는 움직이지 않아 월드 잔류 빛줄기의 실제 길이·간격·굵기를 Claude가 보지 못했다.** 수치는 레인 서퍼 최종값(Codex 실측 확정)을 그대로 썼다. Game에서 실측하고 필요하면 보고해 달라(수정은 Studio에서).
- 레인 서퍼와 구분: 하부광 없음, 빛줄기는 흰빛~옅은 청록 서리 질감(레인 서퍼는 진한 파랑 네온), 결정 반짝임, 시작은 뒷바퀴 눈가루.

## 1. ID / 버전

`snow_boarder` → **`talent.snow_boarder`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / default `VEHICLE_LOCAL`(LOOP 4개 레이어는 `VEHICLE_FOLLOW_WORLD_TRAIL`) / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): 눈 날씨에서 주행 15초 후 30%, 지속 20초, 눈 주행 속도 ×1.1. legacy `snow_frost`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`; `RaceAbilityVisualController.gd`에서 레인 서퍼의 `rain_cool`과 같은 분기).

## 2. 전달물 (Studio `exports/packages/talent.snow_boarder/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2628 | 5683e6f38bfe |
| `assets/talent_snow_boarder_frost_trail.png` (32×128) | 8305 | 09df9a298fa8 |
| `assets/talent_snow_boarder_ice_glint.png` (32×32) | 759 | 34e05b94841a |
| `assets/talent_snow_boarder_powder_fan.png` (128×160) | 31454 | 272d93c6819a |
| `runtime/vfx_runtime_definition_v1.json` | 12229 | f523b46d889f |
| `source/talent.snow_boarder.vfx.json` | 11857 | 94a67aaa8668 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y, 뒷바퀴 접지 공용 (±84, +160). 전 레이어 PARTICLE·UNDER_VEHICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.powder_left` / `_right` CORE **ALPHA** | 눈가루 부채꼴 BURST 1, offset (∓125.0, +272.8), 회전 +20° / −20°(뿌리가 뒷바퀴, 바깥 뒤로 퍼짐), 방향 180° 속도 120, **수명 0.6s**, 크기 150→210, 알파 0.95 → 0 |
| | `start.glints` CORE ADDITIVE | 얼음 결정 BURST 8, offset (0, +170), 방향 180° spread 160°, 속도 150~350, **수명 0.6s**, 크기 90→30, 회전 0~45° |
| LOOP 20s | `loop.trail_left` / `_right` CORE ADDITIVE **월드 잔류** | 서리 빛줄기 18/s max 9, offset (∓84, +200), 속도 0, 수명 0.45s, 크기 120→100, 알파 0.9 → 0 |
| | `loop.glint_left` / `_right` DETAIL ADDITIVE **월드 잔류** | 얼음 결정 3/s max 3, offset (∓84, +215), 수명 0.8s, 크기 80→24, 알파 1 → 0, 회전 0~45° |
| END 0.3s | (레이어 없음) | 새 발생 중단, 남은 빛줄기(0.45s)·결정(0.8s) 자연 소진 |

차량당 스프라이트 LOOP 최대 24(빛줄기 18 + 결정 6), 레이어 max 합 34. importance CORE 5 / DETAIL 2.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.snow_boarder/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"snow_boarder": "talent.snow_boarder"`.
3. legacy `snow_frost` 차량 효과 억제, 화면 효과(`player_screen_fx_id`)는 레인 서퍼(`rain_cool`)와 같은 방식으로 처리하고 보고.

## 5. 확인 요청

1. **빛줄기 실측**: 직선·코너에서 조각 길이·간격, 연속선으로 보이는지(레인 서퍼 때처럼 수치로 보고). 서리 텍스처 심이 레인 서퍼보다 굵다(약 18/32px).
2. **눈 화면 가독성**: 눈 트랙 색 보정·눈 내림 아래에서 ADDITIVE 흰빛 빛줄기·결정이 묻히지 않는지, ALPHA 눈가루가 보이는지.
3. **기존 효과와 겹침**: 같은 뒷바퀴 위치의 눈 wake·바퀴 자국·`driving.snow_tire_spray` 바퀴 눈가루. 빛줄기가 wake 위에 보여야 한다(draw order 확인).
4. **phase보다 긴 수명**: START 레이어 0.6s > START 0.5s / LOOP 결정 0.8s > END 0.3s. 강제 정리·차량 제거·레이스 정리(월드 잔류 입자 포함).
5. **정지·저속**: 레인 서퍼처럼 정지 시 빛줄기 조각이 겹쳐 밝은 덩어리가 되는지(레인 서퍼는 수용).
6. **부하**: 20대에서 여러 대 동시 발동(눈 경기라 날씨 효과와 동시) frame·draw call, 월드 잔류 입자 20초 유지.

## 6. 검증

- Claude 실행: PNG 3장 육안·알파 검수, Studio 검증기·export(FAIL_IF_EXISTS), package 1회 생성, Studio 테스트 `tests/preview/test_snow_boarder_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 9종 — preview 436 / export contract 70 / performance 61 assertions 실패 0, editor 401 중 4 실패(기존, 무관·원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 움직이는 차에서의 빛줄기 모습.
- 사용자 Studio 녹화 검토 2회(눈가루 크기·속도, 결정 크기).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02). 빛줄기는 Game 녹화로 판단하기로 합의.
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 도입·연결 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 눈 경기 스노우 보더 발동 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형: 경기 진행과 관계없이 관리 버튼·메뉴는 항상 조작 가능해야 함). 승인 없는 commit 금지.
