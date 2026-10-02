# 샌드위치 탈출 / Sandwich Escape — Game 적용 인계 (Studio → Codex)

2026-10-01 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-01-talent-sandwich-escape-design.md`.

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(preset은 생성 스크립트로 작성 후 Studio 검증기·export 통과, repo preset = package `source` byte 동일). 이전 GPT 흐름 관례와 다를 수 있으니 package와 실제 코드 기준으로 판단해 달라.
- 계약·코드 변경 없음(기존 PARTICLE 범위). START에 CONTINUOUS 레이어 2개가 있다(광합성 `start.green_release`·레인 서퍼 `start.neon_on`과 같은 방식).
- **컷인의 "좌우 차 사이에 끼인" 연출은 쓰지 않았다.** 실제 발동은 특정 순위 구간에 일정 시간 머무는 것이고 좌우 차량과 무관하다(사용자 확인). 연출 주제는 "중위권 정체를 뚫고 앞으로 치고 나가는 돌파".

## 1. ID / 버전

`sandwich_escape` → **`talent.sandwich_escape`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): `rank_range_for_duration`(일반전 4~6위 / 그랑프리 8~12위에 8초), 30%, 지속 10초, 추월 ×1.2·최고 속도 ×1.1·가속 ×1.1. legacy `gold_speed`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).

## 2. 전달물 (Studio `exports/packages/talent.sandwich_escape/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2637 | 40a3916e5542 |
| `assets/talent_sandwich_escape_chevron.png` (128×96) | 14007 | 7aee0a45d335 |
| `assets/talent_sandwich_escape_path.png` (48×192) | 11179 | 1c9067f85d18 |
| `assets/talent_sandwich_escape_thrust.png` (96×192) | 20878 | d4bd35a224b8 |
| `runtime/vfx_runtime_definition_v1.json` | 13889 | c51e08a7393e |
| `source/talent.sandwich_escape.vfx.json` | 13314 | c2632a232ba0 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y, 앞코 ≈ −240, 뒤끝 ≈ +235. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE, 색 곱 흰색 = 텍스처 금빛)

offset은 텍스처 기준점(화살 꼭짓점·길 밝은 끝·추진 뿌리)이 앞코/뒤끝에 오도록 크기에서 계산한 값이다.

| 구간 | layer | 내용 |
|---|---|---|
| START 0.4s | `start.thrust` CORE | 추진 섬광 BURST 1, offset (0, +418.3), 방향 180° 속도 0, **수명 0.6s**, 크기 220→260 |
| | `start.rear_follow` DETAIL | 추진 CONTINUOUS 6/s max 3, offset (0, +381.7), 수명 0.5s, 크기 176→190, 알파 0.28 — 섬광 아래 루프 뒤 빛줄기를 미리 쌓음 |
| | `start.chevron` CORE | 화살 BURST 1, offset (0, −172.0), 방향 0° 속도 700, 수명 0.6s, 크기 150→110 |
| | `start.chevron_follow` CORE | 화살 CONTINUOUS 5/s max 2, offset (0, −181.1), 속도 600, **수명 0.75s**, 크기 130→95, 알파 0.7 — 첫 LOOP 화살까지 이음 |
| LOOP 10s | `loop.chevrons` CORE | 화살 3.5/s max 3, offset (0, −185.6), 방향 0° 속도 600, 수명 0.75s(이동 ≈450 = 차 한 대 이내), 크기 120→90, 알파 0.55 |
| | `loop.path_left` / `loop.path_right` CORE | 길 2.5/s max 3, offset (∓55, −348.3), 방향 0° 속도 120, 수명 1.0s, 크기 200→220, 알파 0.45 |
| | `loop.rear_thrust` DETAIL | 추진 6/s max 3, offset (0, +381.7), 속도 0, 수명 0.5s, 크기 176→190, 알파 0.28 (옅게 겹쳐 일렁이는 보조) |
| END 0.3s | (레이어 없음) | 새 발생 중단, 남은 화살·길(≤1.0s)·뒤 빛줄기 소진 |

차량당 스프라이트: LOOP 정상 최대 12(화살 3 + 길 6 + 뒤 3), 레이어 max 합 19. START·LOOP 렌더러 각 4.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.sandwich_escape/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"sandwich_escape": "talent.sandwich_escape"`.
3. legacy `gold_speed` 차량 효과 억제, 화면 효과(`player_screen_fx_id`)는 다른 재능 package와 같은 방식으로 처리하고 보고. **`gold_speed`는 독주(`solo_run`, 이미 package 적용)와 공유한다**(`race_ability_defs.json` 확인). 독주 적용 때의 억제 방식을 그대로 따르고, 두 재능 중 하나만 바꾸는 처리라면 서로 영향이 없는지 확인해 달라.

## 5. 확인 요청

1. **시작→루프 연속성**: 첫 LOOP 화살 ≈0.69s, 첫 LOOP 뒤 빛줄기 ≈0.57s, 첫 길 ≈0.8s. START CONTINUOUS 레이어(`start.chevron_follow`·`start.rear_follow`)가 START 동안 방출되고, phase 전환 때 이미 나온 입자가 잘리지 않고 자연 소진되는지.
2. **phase보다 긴 수명**: START 레이어 수명 0.5~0.75s > START 0.4s / LOOP 길 1.0s > END 0.3s. 강제 정리·차량 제거·레이스 정리.
3. **앞차 가림**: 중위권(4~6위, 그랑프리 8~12위)에서 발동하므로 앞차가 가깝다. 화살·길이 앞차를 과하게 덮지 않는지(설계상 차 한 대 길이 이내).
4. **차 뒤 겹침**: 기본/슈퍼 부스터 불꽃, 분노의 추월 진홍 빛줄기, 독주 금빛 리본(같은 금빛 계열), 비·눈 wake·바퀴 파티클과 같이 나올 때 구분되는지. 뒤 빛줄기는 옅은 보조여야 한다.
5. **부하**: 20대에서 여러 대 동시 발동 시 frame·draw call. 앞서 조사 중인 발동 직후 프레임 항목에 이 package도 포함해 확인.

## 6. 검증

- Claude 실행: PNG 3장 육안 검수, Studio 검증기·export, package 1회 생성(FAIL_IF_EXISTS), Studio 테스트 `tests/preview/test_sandwich_escape_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 8종 — preview 432 / export contract 70 / performance 61 assertions 실패 0. editor 묶음 401 중 4 실패(기존 skeleton/schema 테스트, 이번 변경과 무관·원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 실제 경기 모습.
- 사용자 Studio 녹화 검토 4회(시작→루프 화살 공백 해소, 루프 뒤 빛줄기 추가, 뒤 빛줄기 전환 끊김 해소·밝기 조정).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-01).
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 도입·연결 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 샌드위치 탈출 발동 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형: 경기 진행과 관계없이 관리 버튼·메뉴는 항상 조작 가능해야 함). 승인 없는 commit 금지.
