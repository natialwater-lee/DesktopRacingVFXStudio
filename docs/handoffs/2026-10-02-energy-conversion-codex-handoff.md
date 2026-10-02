# 에너지 전환 / Energy Conversion — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-energy-conversion-design.md`. 사전 확인: `docs/handoffs/2026-10-02-energy-conversion-boost-input-codex-precheck.md`(Codex 회신 반영).

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- **새 런타임 입력 `boost_active`를 쓰는 첫 package**이며 **Runtime v2**다(Package 1 / Schema 1 유지). Studio schema·문서·미리보기에는 이미 추가했다(`schemas/vfx_schema_v1.json` `x_vfx_runtime_inputs.boost_active`, `docs/VFX_SCHEMA_V1.md`). **Game loader는 모르는 입력 이름도 받아들이므로 로딩 성공이 공급 지원을 뜻하지 않는다 — 공급 연결을 명시적으로 확인해 달라**(Codex 사전 확인 지적).
- 그 외 레이어는 기존 PARTICLE·TEXTURED_SPRITE 변조 범위.

## 1. ID / 버전

`energy_conversion` → **`talent.energy_conversion`** (신규). Package 1 / **Runtime v2** / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / `runtime_inputs: ["boost_active"]`.
Game 정의(읽기 전용 확인): 유효 방어 5회 후 30%, 지속 15초, 부스터 게이지 회복 ×1.3·일반 부스터 성능 ×1.3. `vehicle_fx_id`·`visual_profile_id` = `energy_conversion`(`RaceAbilityVisualController.gd` 132·179행), `player_screen_fx_id` 없음.

## 2. 전달물 (Studio `exports/packages/talent.energy_conversion/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 3172 | 73c52ea1589e |
| `assets/talent_energy_conversion_rear_arc_a.png` (256×192) | 43398 | 931d63ee6a93 |
| `assets/talent_energy_conversion_rear_arc_b.png` (256×192) | 55473 | 993802015247 |
| `assets/talent_energy_conversion_release.png` (96×256) | 24040 | 726e5a189424 |
| `assets/talent_energy_conversion_swirl.png` (320×320) | 147139 | 607f993d0609 |
| `runtime/vfx_runtime_definition_v2.json` | 14043 | 603a713c4a09 |
| `source/talent.energy_conversion.vfx.json` | 12382 | c56011aac9d1 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y, 뒤끝 ≈ +235. 전 레이어 ADDITIVE·UNDER_VEHICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.6s | `start.swirl` | 파란 소용돌이 BURST 1, 수명 0.55s, 크기 420→150, 각속도 −420°/s(회전하며 빨려 듦) |
| | `start.release_flash` | 청록 방출 섬광 BURST 1, (0, +403.8), 수명 0.8s(첫 LOOP 줄기까지) |
| | `start.arc_entry` | 뒤 아크 A BURST 1, (−5.0, +120), **수명 1.4s**(첫 LOOP 아크 ≈1.31s까지) |
| LOOP 15s | `loop.arc_a` / `loop.arc_b` | 뒤 펜더 파란 아크 A/B 1.4 / 1.15 per s, max 2, (−5.0 / −8.9, +120)(텍스처 치우침 보정), 수명 1.0 / 1.2s, 크기 170.5→179 |
| | `loop.release_trickle` | 옅은 청록 줄기 6/s max 3, (0, +344.7), 방향 180° 속도 30, 수명 0.5s, 크기 130→150, 알파 0.38 |
| | `loop.boost_release` | **TEXTURED_SPRITE** 청록 방출, (0, +386.2), scale (1.15, 1.4), pivot (0, −151.2)=뒤끝 뿌리. `boost_active` 0→1 ⇒ 불투명도 ×0→1, 길이 ×0.5→1.0, 폭 ×0.85→1.15 (입력 0이면 보이지 않음) |
| END 0.3s | (레이어 없음) | 새 발생 중단, 자연 소진 |

- 실제 일반 부스터(빨간 불꽃 4개, x ±22·±66, y +290~+377)와 함께 볼 때: 청록 방출은 가운데 두 불꽃 사이에서 시작해 불꽃보다 뒤로 이어진다(Studio에서 `driving.standard_boost` LOOP를 겹친 임시 비교 preset으로 확인 후 삭제).
- 차량당 스프라이트 LOOP 최대 8. importance CORE 7.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.energy_conversion/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"energy_conversion": "talent.energy_conversion"`.
3. legacy `energy_conversion` 차량 효과(`vehicle_fx_id`) 억제 — 다른 재능 package와 같은 방식, 보고.
4. **`boost_active` 입력 공급**(사전 확인 회신대로):
   - 원시값: `CarAgent` 기존 런타임 스냅샷 갱신에서 `_is_normal_boost_effective()` 기준, **벤치마크 고정 부스트 제외**, 준비·정지·피트 상태 0. 슈퍼 부스터 작동 중 잔존 `boost_active` 값은 쓰지 않는다. 날씨 배율이 걸린 일반 부스터는 대상.
   - 보간: `VfxEffectInstance`에서 이 입력 슬롯을 가진 effect만 선형 보간 — **켜짐 0.08s, 꺼짐 0.3s**. effect 시작 시 0, 레이스 일시정지 중 값 유지, effect 종료 시 갱신 중단(Studio 문서와 동일).
   - 재능이 없는 차량에는 보간 비용을 추가하지 않는다.
5. package loader/compiler가 Runtime v2 + `boost_active` 입력을 **공급 연결된 입력으로 인식**하는지 확인(로딩 성공만으로 판단 금지).

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 probe로 측정)

1. **공급 확인**: 발동 중 부스터 사용 시 `loop.boost_release`가 0.08s에 나타나고 부스터 종료 후 0.3s에 사라지는지. 부스터 미사용 시 보이지 않는지. 슈퍼 부스터·벤치마크 고정 부스트에서는 반응하지 않는지.
2. **phase보다 긴 수명**: `start.arc_entry` 1.4s·`release_flash` 0.8s > START 0.6s / LOOP 아크 ≤1.2s > END 0.3s. 강제 정리·차량 제거·레이스 정리.
3. **겹침**: 일반 부스터 불꽃과 청록 방출(색 섞임·가림), 슈퍼 부스터, 다른 재능(분노의 추월 진홍 빛줄기 등), 날씨 wake. 소용돌이(최대 지름 약 차 길이 1.4배)가 옆 차를 과하게 덮는지.
4. 효과 종료(15초) 직후 부스터가 켜져 있어도 `boost_release`가 남지 않는지.

## 6. 검증

- Claude 실행: PNG 4장 육안·알파·좌우 대칭 측정, Studio 검증기·export(FAIL_IF_EXISTS), package 1회 생성, Studio 테스트 `tests/preview/test_energy_conversion_authoring.gd` 추가·`test_main_scene_smoke.gd` 재능 10종, schema `boost_active` 추가 — preview 441 / contract 204 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·입력 공급·부하, 실제 경기 외형.
- 사용자 Studio 녹화 검토 3회(소용돌이 크기·속도, 아크 밝기·중심 보정·10% 확대, 청록 분출 폭).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02).
- Game 실제 경기 외형: 미승인 — 적용 후 사용자 녹화(발동 + 부스터 사용)로 확인. 청록 분출이 게임 크기에서 가늘면 Studio에서 조정.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **Claude**: 적용 후 부하 측정.
- **사용자**: 발동 + 부스터 사용 경기 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 부스터 규칙·게이지·성능, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
