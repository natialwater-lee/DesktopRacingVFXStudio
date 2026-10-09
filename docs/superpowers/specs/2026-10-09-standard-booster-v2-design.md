# 일반 부스터(Standard Boost) v2 설계

2026-10-09. 사용자 요청: 일반 부스터를 더 좋게 만들고, 필요하면 아트를 새로 만들어도 된다.
대상: `driving.standard_boost` (ID 유지). 방향은 2026-10-09 사용자 승인 (아래 §3).
상태 (2026-10-09): GPT 아트 수령·등록 완료, **Studio 시안과 Game 시험 적용 완료, 사용자 시각 검토 대기.** 시안 값은 §4-1, 실제 경기 캡처·측정 결과는 §9. Game 적용은 브랜치 `claude/standard-booster-v2`(미커밋).

## 1. 측정 결과 (2026-10-09, Game 20대·해변·맑은 낮, 경기 20초 이후)

| # | 관찰 | 근거 |
| --- | --- | --- |
| 1 | START에서 LOOP로 넘어가며 불꽃이 약 0.08초 사라진다. | START 코어는 약 0.09초에 소멸, LOOP 첫 코어 0.173초, 꼬리 0.20초. CONTINUOUS 발생기는 누적값이 0에서 시작해 첫 입자가 1/rate초 뒤에 나온다. START에는 꼬리 제트가 없다. |
| 2 | LOOP 코어 제트가 깜빡인다. | `max_particles 1`, rate×수명 ≈ 1.08이라 용량이 찬 동안의 발생 요청은 누적값만 소비되고 버려진다. 코어는 LOOP 프레임의 55~58%만 켜져 있고(꼬리 95%), 4개 중 1~4개가 켜진 상태로 약 3.5Hz로 오르내린다. |
| 3 | 속도·상황과 무관하게 항상 같은 불꽃이다. | package는 `intensity`를 선언하지만 이를 쓰는 modulation이 없고 Game은 항상 1.0을 보낸다. Runtime v1. |
| 4 | 게임 크기에서 형태가 약하다. | 차 23×46px 뒤에 3~4px 폭의 가는 주황 가닥 4줄이 약 20px 붙을 뿐 하나의 분사로 묶이지 않는다(촛불형). 참고: `docs/references/standard_booster_current_game_crop.png`. |
| 5 | 사용 빈도·시간 | 평균 3.4~3.8대/20대가 동시 부스트(최대 10대), 한 번 약 2.1~2.3초. 부스트 시간의 67~74%가 코너(해변, 트랙별로 다름). |

## 2. 하지 않는 것: 속도 연동 길이

처음에는 `speed_normalized`로 불꽃 길이를 바꾸는 안을 냈으나 **철회한다.** 부스터는 장치가 추력으로 내는 분사이므로 불꽃 길이는 추력이 정하고 차량 속도가 정하지 않는다. 일반 부스터의 추력은 부스트마다 일정하다(`base_boost_speed + 부스트 파워 × 0.30`, 코너에서만 효율 0.35~1.0로 감소).

- 이번 v2는 **일정 추력**으로 만들고 변화는 시간 기반 동작(점화·연소·종료)만 둔다.
- 코너 페널티를 보여주고 싶으면 속도가 아니라 실제 값(`_get_boost_corner_efficiency`)을 새 Runtime Input으로 Game이 공급해야 한다. 지금은 하지 않는다(별도 승인·Game 변경 필요).

## 3. 설계 원칙 (사용자 승인 2026-10-09)

1. **기계 분사.** 곧고 단단한 원뿔형 제트. 중심은 흰빛 도는 노랑, 바깥은 주황, 끝은 투명. 제트 중간에 밝은 구슬 2~3개(충격 다이아몬드)를 넣어 작은 크기에서도 엔진 배기로 읽히게 한다. 혀 모양으로 날름거리는 불꽃은 쓰지 않는다.
2. **노즐 빛.** 제트 뿌리에 뜨거운 빛 번짐을 둬 4줄을 하나의 배기구처럼 묶는다. 점화 때는 같은 텍스처를 크게 써서 섬광으로 쓴다.
3. **시간 기반 동작.** 점화(섬광 + 제트가 짧게 늘어남) → 연소(빠르고 작은 길이·밝기 떨림) → 종료(빠르게 가늘어지며 꺼짐).
4. **지속 스프라이트.** 제트를 파티클이 아닌 TEXTURED_SPRITE로 바꿔 §1의 1·2를 구조적으로 없앤다(생성 지연·용량 손실이 없다).
5. **위치 유지.** 제트 x = ±22 / ±66, 뿌리 y ≈ 208(차체 아래에서 시작), `UNDER_VEHICLE`, `ADDITIVE`, `VEHICLE_LOCAL`. Engineer 노즐 링과 Energy Conversion 방출이 이 위치에 맞춰져 있어 변경하지 않는다.
6. **색 위계.** 주황~노랑 계열 유지. Super Booster(파랑)와 구분되고, 붉은 재능(분노의 추월·하위권의 반란)과는 노랑·흰빛 비중으로 구분한다.

## 4. 레이어 구성 (초기값, Studio 시안에서 조정)

단위는 source px(차량 스프라이트 로컬, 게임 배율 약 0.09). 수명 구성은 `START_LOOP_END`를 유지한다.

| 단계 | 시간 | 레이어 | 형식 | 내용 |
| --- | --- | --- | --- | --- |
| START | 0.16초 (이전 0.10) | `start.jet_1~4` | TEXTURED_SPRITE, CORE | 길이 ×0.35 → 1.0, 폭 ×0.8 → 1.0, 투명도 0.6 → 1.0 (효과 로컬 시간 `LINEAR_PHASE` 6.25Hz, 뿌리 고정 pivot) |
| | | `start.flare_1~4` | TEXTURED_SPRITE, EXTRA/DETAIL | 노즐 섬광. 크기 ×1.3 → 0.6, 투명도 1.0 → 0.35. 끝 값이 LOOP 노즐 빛과 같아 이어진다. |
| LOOP | 지속 | `loop.jet_1~4` | TEXTURED_SPRITE, CORE | 제트마다 길이 계수 0.94~1.06, 약간씩 다른 폭. 떨림: 길이 ±4%(진동 2개 합성), 투명도 ±6%, 폭 ±3%. 제트별 진동수는 서로 어긋나게(예: 11.3/17.9, 12.7/19.3, 10.1/16.7, 13.9/21.1 Hz). |
| | | `loop.nozzle_1~4` | TEXTURED_SPRITE, 바깥 둘 DETAIL / 안쪽 둘 EXTRA | 노즐 빛. 투명도 약 0.35 ±0.06, 크기 ×0.55. 제트 뿌리 바로 뒤(y ≈ 250~270)에 둔다. |
| END | 0.16초 (이전 0.14) | `end.jet_1~4` | PARTICLE BURST, CORE | 텍스처 제트, 크기 100% → 45%, 투명도 0.95 → 0, 수명 0.16초. 뿌리가 내려가지 않게 `direction 0°`(차 전방)로 길이 감소분만큼 이동시킨다. |
| | | `end.nozzle_1~4` | PARTICLE BURST, DETAIL | 노즐 빛 0.35 → 0, 수명 0.10초. |

- 모든 modulation 소스는 `PRESET_SOURCE`(시간 기반)뿐이다. 새 Runtime Input이 없다. (Game 런타임 변경 1건은 §7.)
- 길이·폭 변경은 `modulation_pivot_local`을 제트 뿌리로 둬서 뿌리가 노즐에 고정되게 한다. 아트 도착 후 뿌리 좌표(`[0, 뿌리 y − 캔버스 중심]`)를 실측해 넣는다.
- END는 효과 로컬 시간 때문에 스프라이트로 END 구간 변화를 만들 수 없어 PARTICLE을 쓴다(Engineer END와 같은 방식). 뿌리 보정 이동이 Studio/Game에서 기대대로 되는지 확인하고, 안 되면 길이 감소 없이 투명도만 줄이는 안으로 대체한다.
- START→LOOP 연결: 제트가 모두 지속 스프라이트이므로 START 끝 값(길이 1.0, 투명도 1.0)과 LOOP 시작 값이 같아 공백이 없다. 이 연속성은 시안 녹화와 Game 캡처로 확인한다.
- `runtime_inputs`: **`intensity` 선언을 유지한다(사용은 안 함).** 현재 Game 컨트롤러가 `{"intensity": 1.0}`를 보내고 `VfxRuntimeInputResolver`가 선언되지 않은 입력을 `unknown_runtime_input`으로 거부하므로, 선언을 빼면 package 준비가 실패해 레거시 불꽃으로 되돌아간다.

### 4-1. Studio 시안 값 (2026-10-09, export된 package와 동일)

파티클 `size`는 Studio·Game 모두 **텍스처 긴 변의 절반**이다(스프라이트 높이 = 2 × size, 정사각 비율 유지). END 제트는 이 규칙으로 LOOP 제트와 같은 높이·폭이 되도록 맞췄다.

| 항목 | 값 |
| --- | --- |
| 제트 x / 뿌리 y / pivot | −66, −22, 22, 66 / 208 / (0, −178) |
| 제트 폭 배율(scale X) | 1.235 / 1.30 / 1.196 / 1.274 (기본 0.95·1.00·0.92·0.98 × 1.3) |
| 제트 길이 배율(scale Y) | 0.78 / 0.84 / 0.80 / 0.76 (화면에서 차 뒤로 약 20~23px) |
| 제트 투명도 | 0.8 (START·LOOP 동일, END 파티클은 0.8 → 0) |
| LOOP 떨림 | 길이 ±4% 두 겹(진동수 쌍 11.3·17.9 / 12.7·19.3 / 10.1·16.7 / 13.9·21.1 Hz), 폭 ±3%(두 번째 진동수), 투명도 ±8%(7.7 / 8.9 / 9.7 / 6.9 Hz). 제트마다 위상을 어긋나게 둠. |
| START (0.16초) | 6.25Hz 선형 위상: 길이 0.35 → 1.0, 폭 0.8 → 1.0, 투명도 0.6 → 1.0 |
| 노즐 빛 | y 262, 크기 0.55, 투명도 0.5. START는 크기 ×2.4 → 1.0, 투명도 ×2.8 → 1.0으로 LOOP 값에 이어짐. LOOP 투명도는 제트 투명도 진동자를 ±15%로 공유. |
| END (0.16초) | 제트: 크기 192 × 길이 배율 → ×0.45, 투명도 0.8 → 0, 방향 0°(차 전방)로 속도 약 465~514 source px/s 이동해 뿌리 고정. 폭 배율은 LOOP 폭과 같게 맞춤. 노즐 빛: 투명도 0.5 → 0, 수명 0.10초. |

시험 적용에서 먼저 시도한 안 A(폭 ×1.0, 제트 0.7, 노즐 0.35)는 실제 크기에서 가는 바늘 4줄로 읽혀 폭 ×1.3, 제트 0.8, 노즐 0.5(안 B)로 올렸다. 안 B가 노즐 4줄이 하나의 배기로 묶여 보이고 머리 쪽 노랑이 분명하다.

### LOD

| 수준 | LOOP 레이어 | 연속 파티클 용량 |
| --- | --- | --- |
| HIGH | 8 (제트 4 + 노즐 4) | 0 (현재 12) |
| MEDIUM | 6 (제트 4 + 바깥 노즐 2) | 0 (현재 8) |
| LOW | 4 (제트 4) | 0 (현재 4) |

## 5. 아트 (GPT 요청: `docs/handoffs/2026-10-09-standard-booster-v2-gpt-art-request.md`)

PNG 2장. 논리 ID와 파일명은 다음과 같이 등록한다(기존 `fx.booster_flame_core/tail`은 교체 후 정리, Super Booster는 자체 `fx.super_booster_flame_*`를 쓴다).

| 논리 ID | 파일 | 크기 | 용도 |
| --- | --- | --- | --- |
| `fx.booster_jet` | `assets/vfx/booster_jet.png` | 96×384 | 제트 4줄 전부. 뿌리가 위, 분사는 아래(차 뒤). |
| `fx.booster_nozzle_flare` | `assets/vfx/booster_nozzle_flare.png` | 128×128 | 노즐 빛(LOOP·END)과 점화 섬광(START). |

## 6. 성능

- LOOP: 파티클 용량 12 → 0, 레이어 8 → 8(스프라이트). 차량당 modulation 평가는 제트 4개 × 바인딩 약 6개.
- 확인: Game 부하 probe(`boost_probe*.gd` 변형)로 이전/이후 A/B. 부스트 중인 차량 수가 많은 20대 경기로 비교.

## 7. 호환·테스트·정리

- Runtime v1 → v2(modulation). `intensity` 선언 유지. package ID·카탈로그 변경 없음.
- Game 런타임 코드는 바꾸지 않는다. package 파일 교체와 테스트 기대값 수정만이다. (END 1프레임 공백을 줄이려 `VfxEffectInstance.request_normal_stop`에 END 렌더러 `advance(0.0)`을 넣어 봤으나 캡처에서 효과가 없어 되돌렸다. §9.)
- Studio: `tests/preview/test_standard_booster_authoring.gd`(레이어·위치·텍스처 기대값), `tests/performance/test_standard_booster_budget.gd`(LOD 8/6/4, 용량 0), `tests/export/test_standard_booster_export_policy.gd`(새 PNG 2장)를 새 구성에 맞게 다시 쓴다. `config/vfx_export_asset_policy_v1.json`, `assets/preview/vfx_preview_asset_catalog_v1.json`에 새 ID를 등록하고 기존 `fx.booster_flame_core/tail` 항목과 PNG를 삭제한다.
- Game: `tests/vfx/StandardBoostVfxIntegrationTest.gd`가 loop 레이어의 `fx.booster_flame_core/tail`을 가정하므로 새 구성에 맞게 고친다. package 파일과 `.import`를 교체한다(`docs/BUILD_EXPORT_VFX_GAME_HANDOFF.md`의 원본 PNG 포함 규칙 확인).
- 겹침: Energy Conversion 방출·Engineer 노즐 링·고속 바람과 함께 켜진 상태를 Studio 시안과 Game 캡처에서 확인한다.

## 8. 진행 순서와 미확인 항목

1. 설계 문서와 GPT 아트 요청서(이 문서). ← 지금
2. GPT 아트 수령 → 크기·알파·뿌리 y·구슬 y 확인 → 에셋 등록.
3. Studio 시안(실제 경기 크기 확인, 사용자 녹화 검토) → 조정.
4. package export(Runtime v2) → Game 적용·테스트 → Game 캡처, 부하 A/B → 사용자 최종 승인.

미확인(구현 전 가정):
- 효과 로컬 시간 `LINEAR_PHASE`가 START 구간에서 0 → 1로 정확히 진행하고 Game에서도 같다(Engineer START가 같은 방식을 쓴다).
- `modulation_pivot_local`로 SCALE_Y/X 변경 시 뿌리가 고정된다(Headlights 선례, Game 평가기 지원 확인됨).
- END PARTICLE의 뿌리 보정 이동(`direction 0°` + 속도).
- 신규 아트가 게임 크기(제트 폭 약 4~6px)에서 구슬 모양이 읽히는지.
- 사용자의 게임 내 시각 승인.

## 9. 시안 검증 결과 (2026-10-09)

Game 20대·해변·맑은 낮 경기(seed 927)에서 실제 렌더러로 캡처하고 측정했다. 참고 이미지: `docs/references/standard_booster_current_game_crop.png`(이전), `standard_booster_v2_game_crop.png`(v2 LOOP), `standard_booster_v2_game_end_frames.png`(v2 종료 12프레임), `standard_booster_v2_art_check_old_vs_new_6x.png`(아트 수령 직후의 합성 비교).

- **START→LOOP 공백 제거:** 점화 후 프레임 모두에서 불꽃이 연속이다. 이전의 약 0.08초 소멸이 없다. 측정(주입한 부스트): START 끝 프레임 1235 → LOOP 첫 프레임 1104 → 이후 1350~1500(불꽃 색 픽셀 수).
- **LOOP 깜빡임 제거:** 제트 4줄이 항상 켜져 있고 작게 떨린다(이전 코어 켜짐 비율 55~58%).
- **END:** 제트가 짧아지고 옅어지며 뿌리가 차체 뒤에 붙은 채 약 0.16초에 걸쳐 사라진다(뿌리 고정 이동이 실제 Game에서 동작).
- **알려진 한계, 부스트가 끝나는 첫 1프레임(약 7~16ms)에 불꽃이 비어 있다.** LOOP 스프라이트는 정지 즉시 사라지고 END 파티클은 다음 프레임에 그려진다. 데이터로는 같은 프레임에 파티클 8개가 활성이고 상태·스프라이트 속성도 정상인데, 같은 프레임 캡처에는 그려지지 않는다(같은 프레임에 만든 일반 CanvasItem은 보이므로 캡처 문제가 아니다). 원인은 찾지 못했다. START→LOOP(스프라이트→스프라이트) 전환에는 없다. 시도한 `advance(0.0)` 보정은 효과가 없어 되돌렸다. 육안으로 거슬리는지 사용자 확인이 필요하며, 거슬리면 END를 스프라이트로 바꾸거나 Game 쪽 원인을 더 추적한다.
- **부하 A/B** (같은 seed, 평균 4대 부스트 중, 2회씩): 프레임 평균 7.00 / 6.97 ms(v2) vs 6.97 / 6.96 ms(이전), p95 13.59 / 13.53 vs 13.55 / 13.53. draw call 평균 215 / 213(v2) vs 203 / 209(이전)로 약 +2~5%, 최대 324 / 282 vs 256 / 294. 프레임 시간은 오차 안쪽이다.
- **테스트:** Studio preview 474, performance 61, export_contract 70, contract 204, export 83 모두 실패 0. Game `tests/vfx` 39개 중 38 통과. 실패 1건 `HeadlightVfxIntegrationTest`는 이번 변경과 무관하다(고속 바람 v2 package가 가짜 차량에서 `boost_active_snapshot_unavailable`로 시작하지 못해 효과 수가 1 적게 집계됨). 별도 작업으로 분리했다.
- **실행하지 못한 것:** Studio 앱 화면에서의 시안 확인(사용자 몫), editor 테스트, 야간·비·눈, 다른 효과(Energy Conversion 방출, Engineer 노즐 링, 고속 바람)와 겹친 모습, Game 빌드 export 확인, 사용자의 게임 내 시각 승인.
