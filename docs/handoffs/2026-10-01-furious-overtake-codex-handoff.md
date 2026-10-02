# 분노의 추월 / Furious Overtake — Game 적용 인계 (Studio → Codex)

2026-10-01 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-01-talent-furious-overtake-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(preset은 생성 스크립트로 작성 후 Studio 검증기·export 통과, repo preset = package `source` byte 동일). 이전 GPT 흐름 관례와 다를 수 있으니 package와 실제 코드 기준으로 판단해 달라.
- 계약·코드 변경 없음(기존 PARTICLE 범위).
- **이 재능은 충전 2회를 모두 쓰면 즉시 종료된다**(`RaceAbilityRuntimeController` `charges_consumed`). 표시 시간이 수 초~20초로 가변이다.

## 1. ID / 버전

`furious_overtake` → **`talent.furious_overtake`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): 유효 추월 실패 4회 후 30%, 최대 20초, 확정 추월 2회. legacy `red_breakthrough`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).

## 2. 전달물 (Studio `exports/packages/talent.furious_overtake/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 3107 | 1d5378eb607c |
| `assets/talent_furious_overtake_aura_a.png` (192×320) | 63738 | 522de09ddb6a |
| `assets/talent_furious_overtake_aura_b.png` (192×320) | 55422 | e6260fd8dac3 |
| `assets/talent_furious_overtake_rear_beam.png` (64×256) | 15472 | a74b01b51bb6 |
| `assets/talent_furious_overtake_spark.png` (32×32) | 1082 | 869f6adcc994 |
| `runtime/vfx_runtime_definition_v1.json` | 12123 | e1998989fae6 |
| `source/talent.furious_overtake.vfx.json` | 11587 | d9c2b35d0fd4 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE)

색 곱: 균열·빛줄기 (1.0, 0.45, 0.4) 진홍, 스파크 (1.0, 0.75, 0.65) 밝은 붉은색 — 주황 부스터 불꽃과 구분.

| 구간 | layer | 내용 |
|---|---|---|
| START 0.4s | `start.rage_flash` CORE | 뒤 빛줄기 BURST 1, offset (0, +434)(핵이 차 뒤끝 +235에 오도록 텍스처 핵 위치 보정), 수명 0.55s, 크기 280→330 |
| | `start.crack_burst` CORE | 균열 A BURST 1, offset (0, 0), **수명 2.0s(START보다 김 — 첫 LOOP 균열까지 연결)**, 크기 300→405, 알파 1 → 0 |
| | `start.spark_burst` CORE | 스파크 BURST 8, offset (0, +210), 방향 180° spread 300°, 속도 350~650, 수명 0.8s, 크기 80→30, 무작위 회전 |
| LOOP (≤20s, 충전 소진 시 조기 종료) | `loop.aura_a` / `loop.aura_b` CORE | 균열 A/B 1.4 / 1.15 per s, max 2, 수명 1.0 / 1.2s, 속도 0, 크기 380→405, 알파 0.95 → 0 (교대 일렁임) |
| | `loop.rear_beam` CORE | 뒤 빛줄기 6/s, max 3, offset (0, +405), 방향 180° 속도 40, 수명 0.4s, 크기 240→270, 알파 0.6 → 0 |
| | `loop.sparks` DETAIL | 스파크 10/s, max 8, offset (0, +210), 방향 180° spread 110°, 속도 300~550, 수명 0.75s, 크기 80→30, 무작위 회전 |
| END 0.3s | (레이어 없음) | 새 발생 중단, 남은 균열(≤1.2s)·스파크 소진 |

차량당 스프라이트 최대 15(균열 4 + 빛줄기 3 + 스파크 8), LOOP 렌더러 4.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.furious_overtake/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"furious_overtake": "talent.furious_overtake"`.
3. legacy `red_breakthrough` 차량 효과 억제, 화면 효과(`player_screen_fx_id`)는 다른 재능 package와 같은 방식으로 처리하고 보고.

## 5. 확인 요청

1. **충전 소진 조기 종료**: 발동 직후 확정 추월 2회를 바로 쓰는 경우(START 중·START 직후 종료 포함) STOP→END→소진이 정상인지, START 레이어가 잘리지 않고 자연 소진되는지.
2. **phase보다 긴 수명**: `start.crack_burst` 2.0s, 스파크 0.8s > START 0.4s / LOOP 균열 ≤1.2s > END 0.3s. 강제 정리·차량 제거·레이스 정리.
3. **시작→루프 연속성**: LOOP 첫 균열 ≈0.71s/0.87s 뒤, START 균열이 메우는지.
4. **기존 효과와 겹침**: 기본/슈퍼 부스터 불꽃(같은 차 뒤 — 진홍 빛줄기·스파크와 구분되는지), 비·눈 wake·바퀴 파티클, 다른 재능.
5. **추월 상황 판독성**: 추월 시도가 잦아 옆차와 나란히 있는 경우가 많다. 균열(약 40×66px)·스파크가 옆차를 과하게 가리지 않는지.
6. **부하**: 20대에서 5~8대 동시 발동 frame·draw call(스파크 8/대 포함). 앞서 조사 중인 발동 직후 프레임(파티클 풀 지연 확장 의심)에 이 package의 풀 크기도 포함해 확인.

## 6. 검증

- Claude 실행: PNG 4장 육안 검수, Studio 검증기·export, package 1회 생성, Studio 테스트 `tests/preview/test_furious_overtake_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 7종 — preview 427 / export contract 70 / performance 61 assertions 실패 0. editor 묶음 401 중 4 실패(기존 skeleton/schema 테스트, 이번 변경과 무관·원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 실제 추월 상황 모습.
- 사용자 Studio 녹화 검토 5회(진홍 색 곱, 균열 크기·위치, 시작→루프 공백 해소, 빛줄기 굵기, 스파크 크기·색·이동 거리).
- 같은 작업 중 Studio 편의 변경: 미리보기 Anchors 표시 기본값을 꺼짐으로(사용자 요청, Game 무관).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-01).
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 도입·연결 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 분노의 추월 발동 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간·충전 규칙, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
