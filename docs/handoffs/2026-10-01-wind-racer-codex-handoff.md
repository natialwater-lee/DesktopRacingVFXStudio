# 바람의 레이서 / Wind Racer — Game 적용 인계 (Studio → Codex)

2026-10-01 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-01-talent-wind-racer-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(preset은 생성 스크립트로 작성 후 Studio 검증기·export 통과, repo preset = package `source` byte 동일). 이전 GPT 흐름 관례와 다를 수 있으니 package와 실제 코드 기준으로 판단해 달라.
- 계약·코드 변경 없음(기존 PARTICLE 범위). 실제 코드와 다르면 알려 달라.

## 1. ID / 버전

`wind_racer` → **`talent.wind_racer`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): 누적 슬립스트림 5초 후 30%, 15초, 슬립스트림 속도 ×2. legacy `wind_flow`(`vehicle_fx_id`·`visual_profile_id`), `player_screen_fx_id` `blue_focus`.

## 2. 전달물 (Studio `exports/packages/talent.wind_racer/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2560 | dfb86858edd5 |
| `assets/talent_wind_racer_flow_a.png` (192×320) | 63078 | f8bde62eab50 |
| `assets/talent_wind_racer_flow_b.png` (192×320) | 65103 | e20bea4a70b3 |
| `assets/talent_wind_racer_tail.png` (128×192) | 21406 | 4409493f5855 |
| `runtime/vfx_runtime_definition_v1.json` | 8829 | f514d81f1bcc |
| `source/talent.wind_racer.vfx.json` | 8371 | b42a26bfd392 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE, 색 곱 (0.75, 0.9, 1.0), 방향 180°(뒤))

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.gust_a` / `start.gust_b` CORE | 바람 결 다발 A/B BURST 1, offset (0, −120)/(0, −160), 속도 380/330, **수명 0.9/1.0s(START보다 김 — 첫 LOOP 다발까지 이어줌)**, 크기 300→400 / 320→400, 알파 1.0/0.9 → 0 |
| LOOP (Game 소유 15s) | `loop.flow_a` CORE | 다발 A, offset (0, −90), 3.2/s, max 4, 수명 1.0s, 속도 220, 크기 330→360, 알파 0.45 → 0 |
| | `loop.flow_b` CORE | 다발 B, 같은 위치, 2.7/s, max 4, 수명 1.2s, 속도 190, 같은 크기·알파 |
| | `loop.tail` CORE | 꼬리, offset (0, +230), 5/s, max 3, 수명 0.4s, 속도 420~520, spread 8°, 크기 130→170, 알파 0.7 → 0 |
| END 0.4s | (레이어 없음) | 새 발생 중단, 남은 다발(최대 1.2s) 뒤로 흘러 소진 |

- 파티클은 페이드 인이 없어 새 다발이 나타날 때 튀어 보이는 문제를 **옅은 다발 약 3장씩 겹침**(알파 0.45)으로 해결했다. 발생 수·알파를 크게 바꾸면 다시 튈 수 있다.
- 차량당 스프라이트 최대 11(다발 8 + 꼬리 3), LOOP 렌더러 3.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.wind_racer/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"wind_racer": "talent.wind_racer"`.
3. legacy `wind_flow` 차량 효과 억제 확인, `player_screen_fx_id: blue_focus` 화면 효과는 다른 재능 package와 같은 방식으로 처리하고 보고.

## 5. 확인 요청

1. **phase보다 긴 수명**: START 다발 0.9/1.0s > START 0.5s, LOOP 다발(최대 1.2s)이 빈 END(0.4s) 뒤 소진, 강제 정리·차량 제거·레이스 정리.
2. **시작→루프 연속성**: LOOP 첫 다발 ≈0.31s/0.37s 지연을 START 다발이 메우는지(끊김 없음).
3. **기존 효과와 겹침**: `driving.high_speed_wind`(흰 계열 고속 바람선)과 동시 표시 시 구분되는지(하늘색 곱으로 차이를 둠), 부스터 불꽃, 날씨(비·눈 wake, 강수)와의 겹침.
4. **밀집 판독성**: 발동 조건상 앞차 바로 뒤에 붙어 있는 경우가 많다. 다발(약 40×66px)이 앞차·옆차를 과하게 덮지 않는지.
5. **부하**: 20대에서 5~8대 동시 발동 frame·draw call.

## 6. 검증

- Claude 실행: PNG 3장 검수(다발 줄기 굵기 2~6px·꼬리 2~3px로 요청보다 가늘다는 GPT 메모 확인), Studio 검증기·export, package 1회 생성, Studio 테스트 `tests/preview/test_wind_racer_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 6종 — preview 422 / export contract 70 / performance 61 assertions 실패 0. editor 묶음 401 중 4 실패(기존 skeleton/schema 테스트, 이번 변경과 무관·원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 실제 주행 중 모습.
- 사용자 Studio 녹화 검토 4회(시작→루프 공백 해소, 루프 튐 해소, 하늘색 곱).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-01).
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 도입·연결 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 슬립스트림 발동 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터. 승인 없는 commit 금지.
