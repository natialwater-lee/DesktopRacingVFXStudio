# 충격파 / Shockwave — Game 적용 인계 (Studio → Codex, package 2개)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-shockwave-design.md`. 사전 확인: `docs/handoffs/2026-10-02-shockwave-codex-precheck.md`(Codex 회신 반영, 설계 4-1절).

## 0. 먼저 읽을 것

- **package 2개**: `talent.shockwave`(발동 차) + `talent.shockwave_impact`(영향받은 각 차, 해제될 때까지). 연출 기획·preset·package는 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- 지속 시간·반경은 **밸런스에 따라 바뀐다**(사용자). 두 package의 LOOP는 모두 연속 방출이라 길이와 무관하고, 발동 차 충격파 크기는 `effect_radius` 입력을 따른다 — 밸런스 변경 시 Studio 수정 불필요.
- **`effect_radius`를 처음 실제로 공급하는 package**(schema에는 원래 있었으나 Game 공급 없음). 로딩 성공 ≠ 공급 — 명시적으로 확인.
- impact package는 분노의 추월 스파크 텍스처를 재사용한다(package 안에 `talent_furious_overtake_spark.png` 사본 포함, byte 동일).

## 1. ID / 버전

| package | 버전 | runtime_inputs |
|---|---|---|
| `talent.shockwave` | Package 1 / **Runtime v2** / Schema 1 | `["effect_radius"]` |
| `talent.shockwave_impact` | Package 1 / Runtime v1 / Schema 1 | 없음 |

둘 다 `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER`. Game 정의(읽기 전용 확인): 실제 슬립 2회 후 30%, 지속 12초(가변), 반경 80 월드 px, 대상 주행 안정성 ×0.5. legacy `shockwave_aura`·`shockwave_pulse`(0.7s)·`shockwave_impact`.

## 2. 전달물 (Studio `exports/packages/`, byte 그대로 도입)

`talent.shockwave/`

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 1719 | c3ac6c300046 |
| `assets/talent_shockwave_ring.png` (512×512) | 361661 | 04e02fffb299 |
| `runtime/vfx_runtime_definition_v2.json` | 7882 | bdf3a9c9a0a8 |
| `source/talent.shockwave.vfx.json` | 7059 | 4da83945d85a |

`talent.shockwave_impact/`

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2639 | b36eae2846f2 |
| `assets/talent_furious_overtake_spark.png` (32×32) | 1082 | 869f6adcc994 |
| `assets/talent_shockwave_impact_arc_a.png` (192×320) | 58454 | 50e466f227c6 |
| `assets/talent_shockwave_impact_arc_b.png` (192×320) | 61809 | 9464035d7a10 |
| `runtime/vfx_runtime_definition_v1.json` | 8930 | dc5960db41ff |
| `source/talent.shockwave_impact.vfx.json` | 8472 | a3bb7af91a12 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 ADDITIVE)

**`talent.shockwave` — 발동 차**

| 구간 | layer | 내용 |
|---|---|---|
| START 0.7s | `start.wave` TEXTURED_SPRITE UNDER | 전기 고리(텍스처 고리 심 반지름 **231 texel**). scale = **`effect_radius` / 231**(LINEAR_RANGE 0..231 → 0..1, **외삽·clamp 없음**) × `wave.intro` LINEAR_PHASE(1.333Hz) 0.15→1, 불투명도 ×1→0.15 — 고리가 판정 반경까지 퍼지며 옅어짐 |
| | `start.core_flash` PARTICLE | 고리 BURST 크기 60→200, 수명 0.5s, 색 곱 파랑 |
| LOOP (가변) | `loop.ripple` PARTICLE | 고리 0.8/s max 2, 수명 1.2s, 크기 120→330, 알파 0.75, 색 곱 (0.55, 0.75, 1.0) — 차 둘레 잔진동 |
| END 0.3s | (빈) | 자연 소진 |

**`talent.shockwave_impact` — 영향받은 차**

| 구간 | layer | 내용 |
|---|---|---|
| START 0.4s | `start.hit_sparks` PARTICLE UNDER | 스파크 BURST 8, 360°, 색 곱 주황 |
| | `start.hit_arc` PARTICLE UNDER | 번개 A BURST, **수명 1.7s**(첫 LOOP 번개 1.65s까지) |
| LOOP (해제까지) | `loop.arc_a` / `loop.arc_b` PARTICLE UNDER | 주황 번개 A/B 0.8 / 0.65 per s, max 2, 수명 1.6 / 1.9s, 크기 336→349(빈 타원 ≈ 307×498, 가장 큰 차 둘레) — 천천히 감쌈 |
| | `loop.body_sparks` PARTICLE **OVER_VEHICLE**, emitter **BOX (150, 340)** | 차체 위 무작위 지점 스파크 4.5/s max 3, 수명 0.4s, 크기 130→40, 색 곱 (1.0, 0.85, 0.5) — 차 자체가 손상되는 느낌 |
| END 0.3s | (빈) | 자연 소진 |

impact LOOP 스프라이트 최대 7/대.

## 4. Codex 요청 작업 (사전 확인 회신 권장안 그대로)

1. 두 package 도입(`res://assets/vfx/packages/talent.shockwave/`, `.../talent.shockwave_impact/`), catalog 등록. `ABILITY_PRESET_IDS`에 `"shockwave": "talent.shockwave"`.
2. **발동 차 `effect_radius` 공급**: 발동 시 `effect_values.radius`를 `effect_radius = 판정 월드 반경 / CarSprite 실제 월드 배율`(부모 포함 `global_transform`, 고정 계수 금지)로 환산해 START 첫 프레임 전에 공급. 기본 0 의존 금지. 비균일 배율 처리 판정·보고. loader 범위 검증이 반경을 제한하지 않게.
3. **대상 차 impact 부착**: `_apply_shockwave_targets`(705행)가 발동 순간 선택한 목록 그대로(재검색 없음) 각 대상에 `talent.shockwave_impact` 시작. **대상당 effect 1개 공유** — source_key 집합 관리, 첫 참조에 START, 마지막 해제에 END(LOOP 종료 지시 → 자연 소진), 추가 source는 START 재실행·시간 초기화 없음. 외부 프로필 추가·해제·전체 해제(`CarAgent.gd` 3022행)에 시각 알림 연결(대상 차 레이서 교체 해제 포함). 차량 제거·레이스 정리 = 강제 정리. 게임플레이 안정성 계산(source별 곱)은 그대로.
4. **legacy 억제**: 발동 차 `shockwave_aura`(기존 package 소유권 처리), `shockwave_pulse` 직접 호출, 대상 `shockwave_impact` 외부 프로필 — 세 경로 모두. 두 package가 모두 준비된 경우에만 소유권 확정.

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 대상 다수 포함 측정)

1. 충격파 고리가 실제 판정 반경과 맞는지(반경 경계에 걸친 차가 맞았는지 시각적으로 대략 일치), 차종·트랙 배율이 달라도 원형 유지.
2. 대상 차 impact가 해제 시점까지 유지되고, 해제 후 자연 소진. 중복 피격 시 하나만 표시, 시간 초기화 없음.
3. 차체 스파크(OVER_VEHICLE, BOX)가 다른 차종에서 차체 밖으로 과하게 나가지 않는지.
4. 발동 차 효과가 대상 해제보다 먼저/나중에 끝나는 경우, 레이스 종료·리셋 정리.

## 6. 검증

- Claude 실행: PNG 3장 육안·고리 반지름(231)·빈 타원 측정, Studio 검증기·export(FAIL_IF_EXISTS) 2개, Studio 테스트 `tests/preview/test_shockwave_authoring.gd`·`test_main_scene_smoke.gd` 재능 행 14개, 미리보기 Radius 슬라이더 추가.
- Claude 미실행: Game 실행·공급·부하, 실제 경기 외형.
- 사용자 Studio 녹화 검토 4회(루프 잔진동 강화, 번개 느리게, 차체 스파크 추가·확대).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02). Game 실제 경기 외형: 미승인 — 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **Claude**: 적용 후 부하 측정(발동 6대 + 대상 다수).
- 변경하지 말 것: 충격파 판정·반경·안정성 수치, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
