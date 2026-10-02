# 절대 방어 / Absolute Defense — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-absolute-defense-design.md`. 사전 확인: `docs/handoffs/2026-10-02-absolute-defense-impact-input-codex-precheck.md`(Codex 회신 반영).

## 0. 먼저 읽을 것

- 새 재능 package. 연출 기획·preset 작성·package 생성은 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- **새 런타임 입력 `defense_impact`를 쓰는 첫 package**, **Runtime v2**(Package 1 / Schema 1). Studio schema·문서·미리보기(Hit 버튼)는 추가 완료. **로딩 성공 ≠ 공급 지원 — 공급 연결과 loader 범위 검증을 명시적으로 확인해 달라**(Codex 회신 지적).
- 엔지니어와 같은 TEXTURED_SPRITE 변조 조합(`TRANSFORM_OFFSET_X` ADD, 효과 로컬 시간 `LINEAR_PHASE`·`OSCILLATOR`, `TRANSFORM_SCALE_X/Y`·`VISUAL_OPACITY_MULTIPLIER` MULTIPLY). Game에 이미 지원됨(엔지니어 적용 시 OFFSET ADD 추가).

## 1. ID / 버전

`absolute_defense` → **`talent.absolute_defense`** (신규). Package 1 / **Runtime v2** / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / `runtime_inputs: ["defense_impact"]`.
Game 정의(읽기 전용 확인): 3위 이내 8초 유지 후 30%, 지속 12초, 방어 ×1.5·방어 라인 선택 ×3·코너 속도 ×1.1. legacy `blue_shield`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).

## 2. 전달물 (Studio `exports/packages/talent.absolute_defense/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2728 | c2b6f33881ff |
| `assets/talent_absolute_defense_rear_shield.png` (320×128) | 32051 | a02f49366085 |
| `assets/talent_absolute_defense_side_wall_a.png` (64×320) | 30003 | b86dfb7be4d8 |
| `assets/talent_absolute_defense_side_wall_b.png` (64×320) | 30246 | 13ee7002bc07 |
| `runtime/vfx_runtime_definition_v2.json` | 21574 | eca3319af737 |
| `source/talent.absolute_defense.vfx.json` | 19895 | b9cd14bb44e8 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 ADDITIVE·UNDER_VEHICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.wall_l/r` | 벽 TEXTURED_SPRITE (∓150, 0) scale 1.3, LINEAR_PHASE ⇒ 페이드인·바깥으로 35px·길이 ×0.45→1 |
| | `start.shield_flash` | 방어막 PARTICLE BURST (0, +240), 수명 0.7s |
| LOOP 12s | `loop.wall_{l,r}_{a,b}` | 벽 A/B 역위상 교차(OSCILLATOR 0.45Hz) — 무늬 흐름 |
| | `loop.shield` | 방어막 TEXTURED_SPRITE (0, +240), pivot (0, −40), 일렁임(0.9Hz) + **`defense_impact` ⇒ 불투명도 ×1→2.2, 폭 ×1→1.3, 뒤로 ×1→1.65** |
| END 0.45s | `end.wall_l/r`, `end.shield` | PARTICLE 복사본 페이드아웃 |

벽은 가장 큰 차 바로 바깥(차 가장자리 ±115 기준, 벽 중심 ±150, 폭 ≈83). 스프라이트 LOOP 최대 5. importance CORE 11.

## 4. Codex 요청 작업

1. package 도입(`res://assets/vfx/packages/talent.absolute_defense/`), catalog 등록.
2. `ABILITY_PRESET_IDS`에 `"absolute_defense": "talent.absolute_defense"`.
3. legacy `blue_shield` 차량 효과 억제, 화면 효과는 다른 재능 package와 같은 방식으로 처리하고 보고.
4. **`defense_impact` 입력 공급**(Codex 회신 권장안 그대로, Studio 문서 `docs/VFX_SCHEMA_V1.md`와 일치):
   - 이 입력을 선언한 `VfxEffectInstance`만 해당 차량의 `race_ability_defense_succeeded`(`CarAgent.gd` 4766행 추월 차단 판정 성공)를 구독.
   - 시작 0, 성공 시 1(같은 프레임 여러 성공은 1회 재설정), 이후 VFX 시간 기준 **0.5s 선형 감소** — 감쇠는 snapshot 갱신과 독립적으로 `advance()`에서.
   - 일시정지 중 값 유지, **END 진입 시 수신·감쇠 중단**, 차량 제거·강제 정리 시 구독 해제.
   - 수신부에서 준비·정지·완주·피트 상태 이벤트 무시(방어 판정 자체는 변경 금지).
   - loader 입력 범위(0~1) 정확 검증 + 공급 preflight 연결.
5. 첫 표시 프레임 피크 처리, pause·END·재발동 규칙이 Studio 미리보기(Hit: 1 → 0.5s 감소)와 같게.

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 측정)

1. **공급 확인**: 발동 중 실제 방어 성공 시 방어막이 번쩍이며 뒤로 부풀고 0.5s에 원래대로. 방어 성공이 없으면 변화 없음. 효과 종료 후 신호가 와도 반응 없음.
2. **변조 동작**: START 벽 펼침, LOOP 벽 A/B 교차, 방어막 일렁임이 Studio와 같게. START→LOOP·LOOP→END 전환 시 튐 없음.
3. **겹침·가림**: 벽(차 옆 바깥 ≈4px)이 나란히 달리는 옆 차를 과하게 가리지 않는지, 차종별(작은 차·큰 차) 벽 위치, 부스터 불꽃·다른 재능(에너지 전환 아크, 엔지니어 꺾쇠)과 함께일 때.

## 6. 검증

- Claude 실행: PNG 3장 육안·호 위치 측정, Studio 검증기·export(FAIL_IF_EXISTS), package 1회 생성, schema `defense_impact` 추가, Studio 테스트 `tests/preview/test_absolute_defense_authoring.gd`·`test_main_scene_smoke.gd` 재능 12종 — preview 451 / contract 204 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·입력 공급·부하, 실제 경기 외형.
- 사용자 Studio 녹화 검토 2회(방어 성공 번쩍임 강화).

## 7. 사용자 시각 승인

- Studio 시안: 검토 완료, Codex 사전 확인 회신과 함께 package 진행(2026-10-02).
- Game 실제 경기 외형: 미승인 — 적용 후 사용자 녹화(발동 + 방어 성공)로 확인.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **Claude**: 적용 후 부하 측정.
- **사용자**: 발동 + 방어 성공 장면 녹화 → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 방어 판정·규칙, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
