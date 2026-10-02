# 엔지니어 / Engineer — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-engineer-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- **Runtime v2**, `runtime_inputs: ["boost_active"]` — 에너지 전환에서 연결한 일반 부스터 입력(0.08s/0.3s 보간)을 **그대로 재사용**한다. 새 계약 없음.
- 이 package는 대부분 **TEXTURED_SPRITE + 변조**로 이루어진다(레이어 18개 중 PARTICLE 4개). 처음 함께 쓰는 변조: `TRANSFORM_OFFSET_X/Y`(ADD)로 위치 이동, 효과 로컬 시간 기반 `LINEAR_PHASE`(START 연출)·`OSCILLATOR`(LOOP 스캐너·맥동), **`OVER_VEHICLE` TEXTURED_SPRITE**(스캔선이 차 위를 지남). Game에서 이 조합이 Studio와 같게 동작하는지 확인해 달라.
- 차종마다 형태·크기가 달라 차 윤곽 대신 **가장 큰 차 기준 상자**(꼭짓점 ±128, ±258 source px) 네 모서리 꺾쇠로 표현했다.

## 1. ID / 버전

`engineer` → **`talent.engineer`** (신규). Package 1 / **Runtime v2** / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER`.
Game 정의(읽기 전용 확인): 일반 부스터 4회 사용 후 30%, 지속 15초, 부스터 게이지 소모 ×0.5·일반 부스터 재사용 대기 ×0.5. legacy `engineer_pulse`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`; `RaceAbilityVisualController.gd` 110·171행).

## 2. 전달물 (Studio `exports/packages/talent.engineer/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2615 | 1be4ae11c1f6 |
| `assets/talent_engineer_corner_bracket.png` (128×128) | 10628 | 086fe50f8993 |
| `assets/talent_engineer_nozzle_ring.png` (64×64) | 7453 | ac651fad0504 |
| `assets/talent_engineer_scan_line.png` (256×64) | 19000 | 4b81c6af0b97 |
| `runtime/vfx_runtime_definition_v2.json` | 35776 | 74d16604fa97 |
| `source/talent.engineer.vfx.json` | 33579 | 50d5a57a01e0 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 ADDITIVE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.scan` (OVER_VEHICLE) | 스캔선 scale (1.05, 1.8), `bracket.intro` LINEAR_PHASE 1.9Hz ⇒ y −258 → +258 앞→뒤 1회 |
| | `start.bracket_fl/fr/rr/rl` | 꺾쇠 회전 0/90/180/270°, 바깥 46px에서 조여 들어오며 불투명도 0→1 |
| LOOP 15s | `loop.scan` (OVER_VEHICLE) | 스캐너 `scan.sweep` OSCILLATOR 0.28Hz ⇒ y −258 ↔ +258 왕복. **START 끝(효과 시작 0.5s)에 뒤끝에서 이어받도록 위상 39.6°** — 효과 로컬 시간 기준 |
| | `loop.bracket_*` | 꺾쇠 고정, `bracket.pulse` 0.6Hz ⇒ 불투명도 ×0.55~1.0 |
| | `loop.nozzle_1~4` | 노즐 고리 (−66·−22·22·66, +252) = `driving.standard_boost` 불꽃 뿌리, `boost_active` ⇒ 불투명도 ×0→1, 크기 ×0.7→1.0 |
| END 0.45s | `end.bracket_*` (PARTICLE) | 같은 위치·회전 꺾쇠 BURST, 알파 0.85→0(스프라이트가 툭 꺼지지 않게) |

스프라이트 LOOP 최대 9. importance CORE 18.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.engineer/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"engineer": "talent.engineer"`.
3. legacy `engineer_pulse` 차량 효과 억제, 화면 효과(`player_screen_fx_id`)는 다른 재능 package와 같은 방식으로 처리하고 보고.
4. `boost_active` 공급은 에너지 전환 구현을 그대로 사용 — 이 package도 공급 대상으로 인식되는지 확인.

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 측정)

1. **변조 동작**: `TRANSFORM_OFFSET_X/Y` ADD, LINEAR_PHASE·OSCILLATOR가 **효과 로컬 경과 시간** 기준으로 평가되는지(START 꺾쇠 조임, START 스캔 1회, LOOP 스캐너가 0.5s에 뒤끝에서 끊김 없이 이어지는지). OVER_VEHICLE TEXTURED_SPRITE가 차 위에 그려지는지.
2. **phase 전환**: START→LOOP 스프라이트 교체 시 꺾쇠·스캔이 튀지 않는지, LOOP→END에서 꺾쇠가 파티클로 자연스럽게 사라지는지.
3. **노즐**: 부스터 때만 불꽃 뿌리에 켜지는지(슈퍼 부스터·벤치마크 부스트 제외), 일반 부스터 불꽃과 겹침.
4. **상자 크기**: 차종별(작은 차·큰 차)로 꺾쇠가 차를 감싸는지, 뒤쪽 꺾쇠 가로 팔이 부스터 불꽃과 과하게 겹치지 않는지. 옆 차 가림.
5. 다른 재능·에너지 전환(같은 차에 동시 보유 가능 시) 겹침.

## 6. 검증

- Claude 실행: PNG 3장 육안·꼭짓점 위치 측정, Studio 검증기·export(FAIL_IF_EXISTS), package 1회 생성, Studio 테스트 `tests/preview/test_engineer_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 11종 — preview 446 / contract 204 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·부하, 차종별 실제 외형.
- 사용자 Studio 녹화 검토 3회(루프 스캔 추가, 스캔 위치·굵기·빈도).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02).
- Game 실제 경기 외형: 미승인 — 적용 후 사용자 녹화(발동 + 부스터)로 확인.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **Claude**: 적용 후 부하 측정.
- **사용자**: 발동 + 부스터 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 부스터 규칙, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
