# 슈퍼 부스터(Super Booster) v2 설계

2026-10-10. 사용자 요청: 특수 장비인 슈퍼 부스터와 듀얼 슈퍼 부스터를 더 화려하고 강력해 보이게 개선하고, 발동 시 에너지를 모았다가 터뜨리는 연출을 넣는다. 이미지 리소스 교체 가능.
대상: `equipment.super_booster`(Mk.I·Mk.II), `equipment.super_booster.dual`(Mk.III), 신규 `equipment.super_booster.mk4`(Mk.IV). 기존 ID 유지.
상태 (2026-10-10): **FINAL — 사용자 승인(Studio 시안 확인 후 Game 적용, 녹화 2개 검토 뒤 파워 +25% 상향본으로 확정).** 값은 `tools/super_booster_preset_generator.gd`가 생성하며 package 3개 export와 Game 적용을 마쳤다. 구현 기록은 Game `docs/current/WORKLOG.md`.

## 1. 현재 상태 (package와 Game 코드 확인, 실제 경기 캡처 측정은 아직 안 함)

| # | 관찰 | 근거 |
| --- | --- | --- |
| 1 | 불꽃은 스프라이트 2장(코어, 소프트)이 전부이고 사인파 ±5% 맥동만 한다. | `loop.core_flame`, `loop.soft_flame`, `flame.pulse` 7Hz. 코어는 번개형, 소프트는 연기형이라 게임 크기(0.09배)에서 파란 덩어리로 합쳐질 가능성이 크다. |
| 2 | 장식은 6개짜리 작은 불꽃 입자뿐. | `loop.energy_spark_accent` 크기 28, 수명 0.16초. |
| 3 | 모으는 구간도 터지는 구간도 없다. | START 0.12초 동안 불꽃이 0.77배에서 시작해 커질 뿐. END 0.14초. |
| 4 | Dual이 Single보다 약해 보인다. | 불꽃 한 줄 크기가 Single의 약 87%(폭 0.33 대 0.38, 길이 1.14 대 1.31). |
| 5 | 불꽃은 ACTIVE 시작에 켜지고, 그 전 0.5초(DEPLOYING)는 장치만 펼쳐진다. | `SpecialEquipmentRuntimeState`: `is_effect_active()`는 ACTIVE에서만 참. 속도 배율도 ACTIVE부터. |
| 6 | 장치는 ACTIVE 종료 후 0.5초(RETRACTING) 더 접히는데 불꽃은 END 0.14초에 끝난다. | `_enter_retracting()`. |
| 7 | Mk.IV는 package가 없다(레거시 불꽃). | `SuperBoosterVfxIntegrationController.PACKAGE_ID_BY_MARK_ID`가 mk1~mk3만 매핑. Mk.IV 장비 이미지는 듀얼 형태. |

## 2. 사용자 결정 (2026-10-10)

1. **충전 시점 = A안:** 장치가 펼쳐지는 DEPLOYING 0.5초를 충전 구간으로 쓰고 ACTIVE 시작 순간에 터뜨린다. Game 변경 포함.
2. **월드에 남는 에너지 잔여(월드 광선 꼬리)는 하지 않는다.** 코너에서 차량 회전에 따라 휘는 꼬리는 반드시 유지한다(§4).
3. **Dual은 Single과 형태·연출을 다르게 만든다.** 두 줄을 모두 쓰므로 한 줄은 Single보다 조금 작아도 된다. 전체로는 Dual이 더 강력해 보여야 한다.
4. **Mk.IV package를 이번에 만든다**(Dual 형태, 게임 연결은 준비만).

## 3. 시간 구성 (A안)

START 구간 = DEPLOYING 구간 = 0.5초(모든 mark가 `deploy_duration_seconds` 0.5). LOOP는 ACTIVE 시작과 함께 시작한다. 효과 시계로 START가 0.5초에 끝나므로 폭발은 LOOP 첫 프레임이다.

| 구간 | 시간(효과 시계) | Game 상태 | 연출 |
| --- | --- | --- | --- |
| 충전 | 0 ~ 0.35초 | DEPLOYING | 노즐 뒤에서 푸른 빛이 커지고, 수축 링이 노즐로 모이며, 번개 불똥이 노즐로 빨려 든다. |
| 압축 | 0.35 ~ 0.45초 | DEPLOYING | 빛이 작은 점으로 압축되며 흰색으로 달궈진다(예비 동작). |
| 점화 | 0.45 ~ 0.5초 | DEPLOYING 끝 | 섬광이 급팽창한다. |
| 폭발 | 0.5 ~ 0.9초 | ACTIVE 시작 | 불꽃이 길이 0에서 약 1.5배로 튀어나갔다가 1.0으로 안착(오버슛), 충격 호가 뒤로 퍼지고, 번개 불똥 분출. |
| 지속 | ACTIVE 동안 | ACTIVE | 층을 나눈 플라즈마 불꽃, 노즐 빛, 뒤로 흐르는 추력 파동. |
| 종료 | 약 0.35초 | RETRACTING | 불꽃이 끊기며 식는 잔광과 불똥(장치가 접히는 0.5초 중). |

Studio 기법:
- **오버슛 시계:** `LINEAR_PHASE`는 `fposmod(경과시간 × 주파수, 1)`이라 효과 시작부터 도는 톱니파다. 0.1Hz(주기 10초)로 두면 최대 효과 길이(Mk.IV 3.8초 + 0.5초)에서 한 번도 감기지 않아 "효과 시작 후 N초" 시계로 쓸 수 있다. 폭발 감쇠는 `LINEAR_RANGE`(입력 구간 밖은 끝값으로 고정됨, Evaluator의 `clampf` 확인)로 만든다. 예: 위상 0.05→0.09(0.5→0.9초)에서 길이 배율 1.5→1.0.
- **사다리꼴 곡선:** 한 목표값에 `LINEAR_RANGE` 두 개를 `MULTIPLY`로 겹쳐 오름·내림을 만든다.
- **지속 파동:** 빠른 `LINEAR_PHASE`(예: 3.3Hz)로 이동·크기·투명도를 만든다. 감길 때 투명도 0이어서 이음매가 없다.
- END 구간은 효과 시계 때문에 스프라이트 변화가 어렵다. 일반 부스터 v2처럼 PARTICLE 복제본으로 만든다.
- 스프라이트에는 틴트가 없다(텍스처와 투명도만). 색 구분은 아트로 한다.

## 4. 코너 꼬리 휨: 현재 방식 유지

**결정: 현재의 `visual_bend`(셰이더 휨) 방식을 계속 쓴다.** 월드 잔여 꼬리를 하지 않기로 했으므로 대안(월드 트레일)은 쓰지 않는다.

현재 동작(코드 확인):
- 입력: `turn_rate_normalized`(−1~1). 차량 회전 변화량을 한 틱의 최대 회전 가능량으로 나눈 값. 지연·보간 없음.
- 변환: `LINEAR_RANGE` ±0.20 → ±102 texel 오프셋(ADD), 목표 clamp. 셰이더가 노즐 뿌리(pivot)에서 `start_ratio` 지점부터 `weight = u²`로 **텍스처를 옆으로 밀어 샘플링**한다(`textured_bend.gdshaderinc`).
- 현재 최대 변위: 코어 102 texel × 가로 배율 0.38 ≈ 39 source px, 화면에서 약 3.5px. 그래서 "약간 휜다"로 보인다.

v2에서 바꾸는 것:
1. **모든 불꽃 몸통 레이어(엔벨로프, 제트, Mk.IV 금빛 코어)에 같은 휨을 건다.** 안쪽 층은 적게, 바깥 층은 많이 휘게(현재 코어 ±102 / 소프트 ±178와 같은 원리) 해서 곡선이 층져 보이게 한다.
2. **휨량을 키운다.** 새 텍스처는 가로 배율을 1.0 근처로 쓰므로 같은 texel 오프셋이 그대로 source px가 된다. 목표 꼬리 끝 변위는 화면 약 6~8px(source 70~90 px). 시험 적용에서 조정.
3. **아트 조건:** 셰이더는 스프라이트 사각형 안에서 UV를 밀기 때문에 **불꽃 몸통 양옆에 투명 여백이 휨량 이상 있어야** 잘리지 않는다(아트 요청서에 반영).
4. 충전·폭발용 레이어(링, 섬광, 충격 호, 불똥)는 노즐 근처에 있으므로 휘지 않는다.
5. **Studio 미리보기는 휨을 그리지 않는다**(B2 계약). 휨 확인은 Game 시험 적용과 기존 `SuperBoosterTurnResponseTest` 확장으로 한다.
6. 선택(이번 범위 밖): 회전 입력에 관성을 줘 꼬리가 늦게 따라오게 하는 안은 Game 입력 변경이 필요하므로 하지 않는다.

## 5. 레이어 구성 (초기값, Studio 시안에서 조정)

공통: `VEHICLE_LOCAL`, `UNDER_VEHICLE`, 앵커 `REAR_CENTER`, 노즐 뿌리 좌표는 현재와 같이 유지한다(Single (0, 279), Dual (±60, 279); `SuperBoosterTurnResponseTest`가 이 값을 검사). 길이·폭 변화는 `modulation_pivot_local`을 뿌리로 둔다. `runtime_inputs`는 `turn_rate_normalized`만 유지한다.

### 5-1. Single (Mk.I·Mk.II): "플라즈마 랜스"

한 줄의 굵고 곧은 창. 폭발 때 모든 것이 한 점에 모이고 한 줄로 뻗는다.

| 단계 | 레이어 | 형식 | 내용 |
| --- | --- | --- | --- |
| START 0.5초 | `start.charge_flare` | SPRITE ADDITIVE | 노즐 빛(flare). 크기 0.25 → 1.0(0~0.35초) → 0.5(압축, 0.45초) → 1.8(0.5초), 투명도 0.15 → 0.8 → 1.0. 사다리꼴·구간 `LINEAR_RANGE` 겹침. |
| | `start.charge_ring_a/b` | SPRITE ADDITIVE | 수축 링 2개(시작 0초, 0.18초). 크기 2.2 → 0.35, 투명도 0 → 0.9 → 0. |
| | `start.inhale_bolts` | PARTICLE | 번개 불똥이 노즐 뒤 120px 띠에서 앞(방향 0°)으로 모여든다. 속도 약 600, 수명 0.22초, 초당 30개. |
| LOOP | `burst.shock_arc` | SPRITE ADDITIVE | 충격 호. 0.5초에 노즐에서 시작해 뒤로 약 260px 이동하며 크기 0.5 → 2.5, 투명도 1 → 0(0.35초). |
| | `burst.flare_flash` | SPRITE ADDITIVE | 0.5초 크기 1.8 → 0.6, 투명도 1.0 → 0.5(0.2초), 이후 `loop.nozzle_glow` 값으로 이어짐. |
| | `burst.bolt_spray` | PARTICLE BURST | 번개 불똥 분출 12개, 속도 500~800, 수명 0.3초. |
| | `loop.envelope` | SPRITE ADDITIVE, DETAIL | 부드러운 외곽 빛. 폭발 오버슛 길이 ×1.5→1.0, 투명도 0.45, 휨 바깥층. |
| | `loop.jet` | SPRITE ADDITIVE, CORE | 플라즈마 제트. 오버슛 길이·폭 ×1.5/1.3 → 1.0, 지속 중 길이 ±3%(두 진동수 합성), 투명도 ±6%, 휨 안쪽층. |
| | `loop.nozzle_glow` | SPRITE ADDITIVE | 노즐 뒤 빛. 투명도 약 0.5. |
| | `loop.pulse_a/b` | SPRITE ADDITIVE | 뒤로 흐르는 추력 파동 2개(충격 호 텍스처 작게, 3.3Hz, 반 주기 어긋남). 노즐에서 뒤 약 300px로 이동, 크기 0.5 → 1.1, 투명도 사다리꼴. |
| | `loop.sparks` | PARTICLE CONTINUOUS | 번개 불똥(새 텍스처). 초당 12개, 수명 0.2초, 크기 40 정도(게임에서 보이는 크기). |
| END 0.35초 | `end.jet` | PARTICLE BURST | 제트 텍스처 복제본: 크기 100% → 40%, 투명도 0.9 → 0, 방향 0°로 뿌리 보정 이동. |
| | `end.flare_cool` | PARTICLE BURST | 노즐 빛 0.6 → 0, 수명 0.35초. |
| | `end.sparks` | PARTICLE BURST | 불똥 6개, 수명 0.3초. |

### 5-2. Dual (Mk.III): "트윈 헬릭스"

두 노즐이 엇갈려 충전되고 마지막에 전기 아크로 이어졌다가 함께 폭발한다. Single의 중앙 집중 창과 달리 **두 줄이 벌어지는 쌍발** 형태다.

차이점:
- 불꽃 텍스처: 꼬아진 이중 나선 가닥, 청록 흰색 계열(Single은 짙은 파랑 창). 한 줄 크기는 Single의 약 70~75%(폭 약 70, 길이 약 480 source px). 두 줄 합계 폭은 Single보다 넓다.
- 충전: 왼쪽 노즐이 먼저(0초), 오른쪽이 0.1초 늦게 충전되고 링은 노즐마다 1개. 마지막 0.15초에 두 노즐 사이를 잇는 **가로 전기 아크**(번개 텍스처를 가로로 늘림)가 번쩍인다.
- 폭발: 두 섬광이 동시에, 충격 호는 두 노즐 중간에서 하나로 크게. 불꽃은 바깥쪽으로 약 ±3° 벌어졌다가 오버슛 후 평행으로 돌아온다.
- LOOP: 두 줄의 떨림 위상을 어긋나게(좌우 교대로 번쩍), 추력 파동은 좌우가 엇갈려 흐른다. 가운데에서 두 줄 사이를 아크가 약 1초마다 한 번 번쩍인다(PARTICLE 1개).
- 레이어는 Single 구성에서 좌우 2배이되 충격 호·섬광·아크는 공용 1개씩이라 합계는 Single의 약 1.6배.

### 5-3. Mk.IV (`equipment.super_booster.mk4`): Dual + 금빛 코어

장비 이미지(파랑 몸체에 금색 링)와 맞춰 Dual 구성에 **따뜻한 금백색 코어 층**(`fx.super_booster_core_gold`)을 제트 안쪽에 얹고, 크기를 약 ×1.15, 충격 호 ×1.3, LOOP에 약 1.3초마다 큰 추력 파동 1개를 더한다. Mk.IV는 아직 게임에 없으므로 Game 연결은 매핑과 package 준비만 한다.

### LOD

| 수준 | 유지 레이어 |
| --- | --- |
| HIGH | 전부 |
| MEDIUM | 추력 파동, 번개 불똥 연속 발생 제외 |
| LOW | 엔벨로프, 제트, 노즐 빛만 |

기존 예산 테스트(`test_super_booster_budget`, `test_super_booster_dual_budget`)의 상한을 새 레이어 수에 맞게 갱신한다.

## 6. 아트 (GPT 요청: `docs/handoffs/2026-10-10-super-booster-v2-gpt-art-request.md`, 8장)

| 파일(요청 이름) | 크기 | 역할 | 사용처 |
| --- | --- | --- | --- |
| `sb_jet_single.png` | 256×640 | 곧은 플라즈마 제트, 충격 다이아몬드 4개 | Single, 배율만 바꿔 Mk.I~II |
| `sb_jet_twin.png` | 192×576 | 꼬인 이중 나선 제트(청록 흰색) | Dual, Mk.IV |
| `sb_envelope.png` | 256×640 | 부드러운 외곽 빛(연기·혀 없음) | 공용 |
| `sb_flare.png` | 256×256 | 노즐 빛 번짐과 섬광 | 공용 |
| `sb_charge_ring.png` | 256×256 | 수축 링(이중 링, 눈금) | 공용 |
| `sb_shock_arc.png` | 256×96 | 뒤로 퍼지는 충격 호(∪형) | 공용(추력 파동·폭발) |
| `sb_bolt.png` | 128×128 | 번개 불똥(가지 2개) | 공용(불똥·아크) |
| `sb_core_gold.png` | 192×576 | 금백색 얇은 코어 | Mk.IV |

기존 `fx.super_booster_flame_core/soft`, `super_booster_spark_blue`는 교체 후 정리한다(Studio 카탈로그·테스트·package 포함). 논리 ID는 `fx.super_booster_*`로 등록한다.

## 7. Game 변경 (Studio 시안 승인 후, 브랜치에서)

1. **deploy 시작에 package 시작:** `CarAgent`가 DEPLOYING 진입에서 `super_booster_visual_state_changed(true)`를 내보내도록 한다(현재는 ACTIVE 진입에서만). 레거시 불꽃(`SuperBoosterFlame`)은 기존 ACTIVE 조건을 유지하고 package가 소유하는 동안 숨긴다. DEPLOYING 중 취소(스틴트 종료, 정지, 피트 진입)에서 package가 정리되는지 확인한다.
2. **START 길이 정렬:** package START 0.5초와 `deploy_duration_seconds`가 같아야 폭발이 ACTIVE 시작과 맞는다. 두 시계(VFX 효과 시계와 장비 상태 시계) 어긋남을 시험으로 측정한다.
3. **Mk.IV 매핑:** `PACKAGE_ID_BY_MARK_ID`에 `mk4 → equipment.super_booster.mk4` 추가, `data/vfx/vfx_package_catalog.json`과 package 폴더 추가.
4. 일반 부스터 불꽃은 현재 ACTIVE에서 숨겨진다. DEPLOYING 중에는 일반 부스터가 켜져 있을 수 있어, 주황 불꽃 → 파랑 충전 → 폭발의 전환이 자연스러운지 캡처로 확인한다.
5. 테스트: `SuperBoosterVfxIntegrationTest`, `SuperBoosterTurnResponseTest`(레이어 목록·뿌리·휨 확인 갱신), `VfxPackageIngestionTest`, Mk.IV 통합.

## 8. 검증 계획

- Studio: 시안 녹화 검토(충전 → 폭발 → 지속 → 종료), 신규 `tests/preview/test_super_booster_v2_authoring.gd` 등 기존 3종 테스트 갱신.
- Game: 시험 적용 후 deploy부터 종료까지 캡처, 코너 휨 캡처(회전 입력 실측), 동시 부스터 수에 따른 프레임·draw call 부하(Claude 부하 측정 방식), START→LOOP 공백 여부, 폭발 시점과 속도 상승의 어긋남.
- 한 번에 속성 하나, 10~30% 단위로 조정한다(고속 바람 v2에서 얻은 교훈). 시각 조정 중에는 집중 테스트 1개와 캡처 1회만 돌리고 전체 회귀는 병합 직전에 한다.

## 9. 열린 항목

- 아트 수령 후 레이어 수치 확정(§5는 초기값).
- 폭발 순간 속도 상승과의 체감 일치는 Game에서만 확인 가능.
- 종료 잔광 0.35초가 장치 접힘 0.5초와 어색하지 않은지 확인.
