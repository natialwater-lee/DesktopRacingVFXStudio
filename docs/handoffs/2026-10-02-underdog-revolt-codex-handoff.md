# 하위권의 반란 / Underdog Revolt — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-underdog-revolt-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package `talent.underdog_revolt`(15개 재능 중 마지막). 연출·preset·package는 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- 기존 PARTICLE 범위, 계약·입력 변경 없음, Runtime v1. 스파크는 분노의 추월 텍스처 재사용(package 안 사본, byte 동일).
- **legacy `red_breakthrough`를 분노의 추월과 공유**한다 → 억제는 **하위권의 반란에만** 적용(분노의 추월은 이미 자기 package로 억제됨). 독주·샌드위치 탈출의 `gold_speed` 공유 처리와 같은 방식.
- LOOP는 연속 방출이라 지속 시간(12초, 밸런스 가변)과 무관.

## 1. ID / 버전

`underdog_revolt` → **`talent.underdog_revolt`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): 일반 8위 이하·그랑프리 16위 이하 8초 후 30%, 지속 12초, 최고 속도·가속·코너·브레이크 ×1.08. legacy `red_breakthrough`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).

## 2. 전달물 (Studio `exports/packages/talent.underdog_revolt/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2671 | 9d968e62bd9a |
| `assets/talent_furious_overtake_spark.png` (32×32) | 1082 | 869f6adcc994 |
| `assets/talent_underdog_revolt_ember_burst.png` (256×256) | 74575 | 870153dc0fcb |
| `assets/talent_underdog_revolt_flame_streak.png` (64×320) | 34892 | 18d54258963d |
| `runtime/vfx_runtime_definition_v1.json` | 10499 | 55da706d41e1 |
| `source/talent.underdog_revolt.vfx.json` | 10002 | 846544da3a7e |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.6s | `start.ember_burst` | 불티 덩어리 BURST, (0, +210), 수명 0.8s, 크기 260→370 |
| | `start.streak_l/r` | 불꽃 줄기 BURST, (∓150, +190), 방향 0°(앞) 속도 560, **수명 0.9s**(첫 LOOP 줄기 0.85s까지), 크기 220→200 |
| LOOP (가변) | `loop.streak_l/r` | 불꽃 줄기 4/s max 3, (∓150, +190), 방향 0° 속도 480, 수명 0.75s, 크기 210→190, 알파 0.8 — 차 옆을 따라 뒤→앞으로 흐름 |
| | `loop.embers` DETAIL | 스파크 3.5/s max 3, (0, +215), 방향 180° spread 120°, 속도 80~180, 수명 0.7s, 크기 70→20, 색 곱 (1.0, 0.55, 0.2) |
| END 0.3s | (빈) | 자연 소진 |

LOOP 스프라이트 최대 9. importance CORE 5 / DETAIL 1.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.underdog_revolt/`), catalog 등록. `ABILITY_PRESET_IDS`에 `"underdog_revolt": "talent.underdog_revolt"`.
2. legacy `red_breakthrough` 차량 효과를 **하위권의 반란에서만** 억제, 화면 효과(`player_screen_fx_id`)는 다른 재능 package와 같은 방식으로 처리하고 보고. 분노의 추월 동작이 바뀌지 않는지 확인.

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 측정)

1. 불꽃 줄기(차 옆 ±150, 앞코 너머까지 뻗음)가 나란히 달리는 옆 차·앞차를 과하게 가리지 않는지. 하위권은 차가 몰려 있는 경우가 많다.
2. 분노의 추월과 같은 차에 동시에 있을 때, 일반 부스터 불꽃·다른 재능과 겹침.
3. phase보다 긴 수명(START 줄기 0.9s > START 0.6s), 강제 정리·레이스 정리.

## 6. 검증

- Claude 실행: PNG 2장 육안, Studio 검증기·export(FAIL_IF_EXISTS), Studio 테스트 `tests/preview/test_underdog_revolt_authoring.gd`·`test_main_scene_smoke.gd` 재능 행 16개 — preview 463 / contract 204 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관). 스위트는 각각 4분 제한으로 별도 실행.
- Claude 미실행: Game 실행·부하, 실제 경기 외형.
- 사용자 Studio 녹화 검토 2회(줄기가 차에 바짝 붙고 약함 → 바깥 ±150·1.4배·밝기 0.8, 불티 덩어리 확대).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02). Game 실제 외형: 미승인 — 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **Claude**: 적용 후 부하 측정.
- 변경하지 말 것: 재능 판정·확률·지속시간, 분노의 추월 동작, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
