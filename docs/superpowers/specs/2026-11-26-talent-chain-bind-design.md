# 체인 바인드(Chain Bind) 경기용 VFX 연출 제안 — ①단계

- 작성: 2026-11-26 (이펙트툴 세션). 상태: **① 합의 완료 (지훈 11-26, "제안대로 확정")**. GPT 아트 도착 후 ②로 이어간다.
- 재능 id: `chain_bind` (야센 전용, NPC도 사용). 게임 기능은 **미개발**(휠투휠 다음 차례).
- 예정 preset/package ID:
  - `talent.chain_bind` — 묶은 차(재능 보유 차)에 붙는다. 사슬 + 내 쪽 고리.
  - `talent.chain_bind_shackle` — 묶인 차(대상)에 붙는다. 뒷범퍼 족쇄.
  - `talent.chain_bind_break` — 대상을 다시 추월해 끊길 때 한 번 재생.
- 기준 자료:
  - 게임 `Claude outputs/신규재능_기획_v1.md` "VFX 일정"과 1장
  - `docs/TALENT_VFX_GUIDELINES.md`
  - 충격파 선례: `docs/superpowers/specs/2026-10-02-talent-shockwave-design.md`, 게임 `docs/archive/SHOCKWAVE_GAME_HANDOFF.md`, 게임 `RaceAbilityVfxIntegrationController.gd`
  - 컷인 `chainbind.mp4`(4.04초, 854×480, 지훈 PC `J:\…\1. 체인 바인드  Chain Bind\영상제작\`), 컨셉 `Chain Bind.png`

## 1. 재능 사실 (기획서 확정)

- 조건: 연속으로 추월당함 2회. 내 방어 성공 시에만 횟수 0으로.
- 대상: 조건을 채운 추월의 차(방금 나를 추월한 차).
- 효과 12초: 대상과의 거리가 **D = 30**까지 벌어진 순간부터 내 실제 속도 = 대상 속도. 내가 더 빠르면 평소대로 좁힌다.
  - 미끄러지는 동안은 맞추지 않는다. 코너에서는 내 한계 속도까지만 맞춘다. → 거리가 잠시 30보다 커졌다가 다시 30으로 돌아온다.
  - 사이에 다른 차가 끼어도 사슬은 유지된다.
- 종료: 지속 끝 / **대상을 다시 추월(`chain_broken`, 사슬 끊김 연출)** / 대상·나 피트 진입·완주·정지 / 레이서 교대.
- 컷인 색감: 그을린 강철 + 쇳물 주황.

### 화면 크기 사실 (게임 코드에서 계산)
- 차 길이 = 텍스처 높이 × 0.38 × 0.25 × race_object_scale(약 0.85) ≈ **44~49 월드 px**. source px → 월드 배율 약 0.08075(충격파 인계 실측). 즉 **화면 1px ≈ source 12.4px**(x1).
- D = 30은 경주 거리 기준 **중심 간 거리**다. 차 길이(약 48)보다 짧다. 그래서 묶인 동안 두 차는 대개 **차선이 달라 비스듬히 반쯤 나란한 상태**이고, 사슬의 보이는 길이는 차 길이보다 짧을 때가 많다(추정 10~40px). 코너·미끄러짐으로 벌어질 때만 길어진다.
- → 사슬이 짧아도 읽히도록 **사슬을 굵게(화면 폭 약 7px), 양 끝(내 고리·대상 족쇄)을 강하게** 만든다. 실제 길이 분포는 게임 기능 세션의 측정으로 확인한다(7절).

## 2. 컷인 분석

| 시간 | 장면 |
|---|---|
| 0.0~0.5초 | 빨간 차 뒤에서 파란 대상 차가 앞서 달린다. 사슬 없음. |
| 0.75초 | 내 차 오른쪽 앞에서 **달아오른 주황 사슬이 날아가 대상 뒷범퍼에 걸린다**. 걸린 곳에 흰빛 스파크 섬광. |
| 1.25초 | 사슬이 **팽팽하게 곧게** 이어진다. 사슬 아래로 불티가 떨어지고, 젖은 노면에 주황 반사. |
| 2.25~3.75초 | 대상 뒷범퍼를 **빛나는 쇠 띠(족쇄)**가 가로로 감싼다. 코너에서 사슬이 살짝 휘며 일정 거리로 따라간다. |

참고 캡처(GPT 첨부용): 공용 노트 폴더 `chain_bind_ref/` — `0.75s_hook_hit`, `1.25s_chain_taut_sparks`, `2.25s_shackle_rear`.

### 가져올 요소
1. **굵은 사슬 고리**(타원 고리가 앞면·옆면으로 번갈아 보이는 입체 사슬). 그을린 강철 몸체 + 이음매가 쇳물처럼 달아오른 주황·흰빛.
2. **대상 뒷범퍼 족쇄** — 대상 쪽 끝. NPC가 플레이어를 묶을 때 플레이어가 알아보는 핵심 표시.
3. **걸리는 순간의 스파크 섬광**, **팽팽할 때 달아오름**.

### 뺄 / 바꿀 요소
- 사슬이 날아가는 곡선 궤적·카메라 연출 → 0.22초 "뻗어 나감"으로 줄인다.
- 사슬 아래로 계속 떨어지는 불티 → 지속 입자는 8대 부하가 커서 뺀다. 걸림·잠김·끊김 순간에만 스파크.
- 노면 주황 반사 → 사슬 아래 **넓은 열기 빛 띠**(가산) 하나로 대신한다.
- 내 쪽 연결점: 컷인은 오른쪽 앞 모서리지만 차종마다 모양이 달라 **앞 중앙(FRONT)**에 둔다.

### 기존 VFX와 구분
| 기존 | 체인 바인드와 차이 |
|---|---|
| 리바운드: 민트, 뒷바퀴 림 + 양옆 고정 레일 | 색(강철·쇳물)과 형태(고리가 이어진 사슬). **두 차를 잇는 유일한 연출**. |
| 드리프트 마스터: 자홍 네온 꼬리, 뒤로만 뻗음 | 앞으로, 다른 차를 향해 뻗음. 빛줄기가 아닌 **금속 물체**. |
| 하위권의 반란: 적주황 불꽃 줄기가 옆을 따라 흐름 | 불꽃이 아니라 단단한 쇠. 흐르지 않고 **팽팽함·늘어짐**으로 반응. |
| 분노의 추월: 진홍 전기 / 기본 부스터: 주황 불꽃 | 전기·불꽃 없음. 주황은 **쇠가 달아오른 빛**으로만, 몸체는 어두운 강철. |
| 충격파 impact: 대상 차 둘레 번개 | 대상 쪽은 **뒷범퍼 한 줄 족쇄**만. 둘레를 감싸지 않는다. |

## 3. 연출

### 3-1. 묶은 차 `talent.chain_bind` (12초, 사슬 소유)

사슬은 **내 앞 중앙(FRONT) → 대상 뒷범퍼 중앙(REAR_CENTER)**을 잇는다. 매 프레임 두 점 사이를 다시 잇는다. 사슬은 OVER_VEHICLE(차와 겹쳐도 보이게), 그림자·열기 띠는 UNDER_VEHICLE.

| 레이어 (새 LINK 타입) | 역할 |
|---|---|
| `chain.shadow` ALPHA, UNDER | 사슬 그림자. 열기 띠 텍스처를 검게, 화면 약 (+2, +3)px 비켜서 깐다. **사슬이 노면 위에 떠 있는 입체감**. |
| `chain.glow` ADDITIVE, UNDER | 사슬 아래 넓은 열기 빛 띠(폭 약 18px). 노면에 비친 쇳물 빛. |
| `chain.links` ALPHA, OVER | 사슬 본체. 고리가 **반복(타일)**되어 길이가 바뀌어도 고리 모양이 늘어나지 않는다. 화면 폭 약 7px, 고리 하나 약 7px. |
| `chain.heat` ADDITIVE, OVER | 같은 고리의 달아오른 이음매만. 팽팽함에 따라 밝아진다. |
| `hook.clamp` TEXTURED_SPRITE, OVER | 내 앞 중앙의 쇠고리(사슬이 나가는 곳). 약 9×9px. |

**시작 START ≈0.5초 — "던져서 건다"**
- 사슬이 내 앞에서 대상 뒤까지 **0.22초 만에 뻗어 나간다**(보이는 비율 0→1). 이때 최대로 달아올라 있다.
- 닿는 순간(0.22초) 대상 쪽 끝에 **스파크 BURST + 흰 섬광**(사슬 위 위치 t=1에서 생성).
- 내 고리 `hook.clamp`는 ×1.6으로 번쩍였다가 0.3초에 정착.

**유지 LOOP — 거리에 반응**
- 입력 `link_distance_ratio` = 실제 거리 / D.
- **느슨함(비율 0.75 이하, 내가 더 가까움)**: 사슬이 처지고(가운데가 뒤쪽으로 끌리는 곡선, 화면 약 4px), 식은 강철색(heat 0.15, glow 0.3).
- **팽팽함(비율 1.0, 속도를 맞추는 중)**: 곧게 펴지고 이음매가 쇳물 주황으로 달아오름(heat 1.0, glow 0.7). 지속의 대부분이 이 상태다.
- **버팀(비율 1.0~1.5, 코너·미끄러짐으로 벌어짐)**: 흰빛에 가깝게 더 달아오르고 폭 ×1.12, 열기 띠 ×1.4. "사슬이 버티고 있다".
- **잠김 순간** — 입력 `link_lock_pulse`(속도 맞춤이 시작될 때 1 → 0.4초에 0): 사슬 heat ×1.8 번쩍, 폭 ×1.15 "철컥", 내 고리 번쩍. 대상 족쇄도 같은 입력으로 번쩍.
- 숨쉬기·지속 입자 없음(리바운드 0.8 Hz 숨쉬기와 구분). 변화는 전부 실제 거리 상태에서 나온다.

**종료 END ≈0.4초 (지속 끝·피트·완주·정지)** — 사슬이 대상 쪽부터 내 쪽으로 감겨 들어오며(보이는 비율 1→0) 식어 사라진다. 레이서 교대·차 제거는 강제 정리로 즉시 제거.

### 3-2. 대상 차 `talent.chain_bind_shackle` (사슬이 있는 동안)

- `shackle.band` ALPHA, OVER: 뒷범퍼를 가로로 감싸는 **굵은 강철 족쇄 띠**(화면 약 26×10px), 가운데에 사슬이 걸리는 고리 눈.
- `shackle.heat` ADDITIVE, OVER: 같은 띠의 달아오른 이음매. `link_distance_ratio`·`link_lock_pulse`를 같은 값으로 받는다.
- START 0.4초: 사슬이 닿는 0.22초에 맞춰 ×1.5로 "철컥" 조였다가 정착(0~0.22초는 투명).
- END 0.3초: 페이드. 끊김은 3-3.
- **플레이어가 묶였을 때**: 내 차 뒤에 달아오른 족쇄 + 뒤차에서 뻗어 온 사슬이 보인다. 화면 효과는 넣지 않는다. 알림 문구가 더 필요하면 게임 HUD 쪽 일(기능 세션 판단).

### 3-3. 끊김 `talent.chain_bind_break` (≈0.7초, 1회)

`chain_broken`일 때 게임이 본 package와 족쇄를 **즉시 정리**하고 이것을 묶은 차에 시작한다(같은 대상 참조).
- 사슬 가운데가 **튕기듯 벌어지며**(가운데 틈 0→1, 0.3초) 두 동강이 각자 끝 쪽으로 감겨 들어간다. 처짐이 커지고 주황→어두운 강철로 식는다.
- 끊긴 지점(t=0.5)에 **큰 스파크 BURST + 섬광**, 대상 쪽 끝(t=1)에 작은 스파크(족쇄가 풀림).
- 끝나면 아무것도 남지 않는다(월드 잔류 없음).

## 4. 부하 (8대 동시 발동 기준)

| 구간 | 묶은 차 1대 | 대상 1대 | 8쌍 |
|---|---|---|---|
| START | LINK 4 + 스프라이트 1 + BURST 입자 약 8 | 스프라이트 2 | 40 + 입자 64 |
| LOOP | LINK 4 + 스프라이트 1 | 스프라이트 2 | **56 그리기**, 지속 입자 0 |
| 끊김 | LINK 4 + BURST 입자 약 12 | – | 0.7초 |

- LINK 1개 = Line2D 1개(점 약 10개, 매 프레임 점 위치만 갱신, 생성·할당 없음).
- 리바운드 최종(LOOP 10/대 → 8대 80)보다 가볍다. 번짐 레이어는 `chain.glow` 하나뿐이다.
- 더 줄여야 하면 `chain.shadow`를 먼저 뺀다(입체감은 줄어듦).

## 5. 새 기능 범위 — 연결형 VFX (LINK)

기존 레이어는 모두 차 한 대에 고정된 좌표만 쓴다. 두 차 사이 **길이·방향이 매 프레임 바뀌는** 사슬은 기존 기능으로 만들 수 없다.
- TEXTURED_SPRITE를 회전·늘이기로 쓰면 고리 모양이 늘어나고, LINEAR_RANGE로는 각도(atan2)를 만들 수 없으며, 처짐 곡선도 안 된다. → 새 레이어 타입이 필요하다.

### 5-1. 스키마 (Studio)
1. **새 레이어 타입 `LINK_STRIP`** (일반 기능. 체인 바인드 전용 이름 아님)
   - 시작점: 레이어의 Anchor + transform offset (호스트 차 source-local, 기존 그대로).
   - 끝점: **링크 대상 차**의 Anchor(`link_target_anchor`, 예 `REAR_CENTER`) + `link_target_offset`. 런타임이 매 프레임 호스트 source-local로 환산한다.
   - 파라미터: `texture_asset_ref`, `texture_mode`(`TILE` 반복 / `STRETCH` 한 장 늘이기), `tile_length_source_px`(TILE 한 주기 길이), `width_source_px`, `opacity`, `color_rgba`, `start_inset_source_px` / `end_inset_source_px`, `sag_source_px`(기본 처짐), `segments`(곡선 점 수, 2~16).
   - 처짐 방향: 호스트 기준 뒤쪽(+Y)을 링크에 수직으로 투영한 방향(달리는 차에 끌리는 사슬). 링크와 거의 평행이면 +X 수직 방향.
   - 새 모듈레이션 타깃(LINK_STRIP 전용): `LINK_REVEAL`(0~1, 시작점부터 보이는 비율), `LINK_RETRACT`(0~1, 끝점부터 사라지는 비율 — END 감겨 들어옴), `LINK_GAP`(0~1, 가운데 틈 — 끊김), `LINK_SAG_OFFSET`(ADD, source px), `LINK_WIDTH_SCALE`(MULTIPLY). 투명도는 기존 opacity 타깃.
   - END에서도 시간 램프가 동작해야 한다(리바운드 교훈: TEXTURED_SPRITE는 END 시간 램프 불가). LINK_STRIP은 END의 LINEAR_PHASE를 지원하도록 계약에 넣는다.
2. **PARTICLE 발생 위치 `LINK_POINT`**: 새 Anchor. `link_t`(0~1) 위치(사슬 위 비율)에서 BURST를 낸다. 생성 순간 위치만 쓰고 이후 입자는 기존대로.
3. **새 runtime 입력 2개** (`x_vfx_runtime_inputs`)
   - `link_distance_ratio`: 0~2, 기본 0. 링크 대상과의 실제 거리 / 바인드 거리 D. 보간 없음(게임 값이 이미 연속).
   - `link_lock_pulse`: 0~1, 기본 0. 사건형(`defense_impact`와 같은 방식). 맞춤 시작 신호에 1, 0.4초에 걸쳐 0.
4. **링크 대상 선언**: preset 최상위 `link_target: {required: true}`. 이 선언이 있는 effect는 **대상 차 참조 없이는 시작하지 않는다**(조용히 0 길이로 대체 금지).

### 5-2. preview (Studio)
- **대상 차 표시**: preview에 두 번째 차(같은 차 스프라이트, 반투명 아님)를 그린다.
- 대상 위치 조작: 앞쪽 거리·옆 간격 슬라이더 + 마우스 드래그. "자동" 토글 — 거리 0.6D↔1.4D, 옆 간격 ±1차선으로 천천히 오가며 늘었다 줄었다를 보여 준다.
- `link_distance_ratio`는 대상 위치에서 자동 계산(D 입력칸, 기본 30 월드 = source 약 372px). 수동 슬라이더로 덮어쓰기 가능.
- **Lock 버튼**(`link_lock_pulse` 1→0), **Break 버튼**(본 effect 정리 + break preset 재생).
- **짝 preset 동시 재생**: 묶은 차에 `talent.chain_bind`, 대상 차에 `talent.chain_bind_shackle`. preview가 effect 2개를 서로 다른 차에 동시에 붙이는 기능.
- 게임 크기 보기(기존 game scale 기능)에서 사슬 폭 7px가 굵게 보이는지 확인.

### 5-3. package 계약 (Studio export ↔ Game loader)
- Runtime Definition에 LINK_STRIP 레이어와 `link_target` 선언을 싣는다. 새 capability `LINK_TARGET_V1`(이름은 ②에서 확정)을 manifest에 표시한다.
- 이 capability를 모르는 Game은 package를 **명시적으로 거부**한다. Runtime Definition 버전 번호는 ②에서 기존 v2 확장(additive)로 충분한지 판단하고, 부족하면 v3로 올린다 — 양쪽 같이 바꾼다(번호만 먼저 올리지 않는다).
- 좌표: 끝점 환산은 호스트 CarSprite `global_transform` 역변환(충격파 `effect_radius`와 같은 기준). 비균일 배율은 거부.
- 대상이 사라지거나(노드 해제) 무효가 되면 effect를 강제 정리한다.

### 5-4. Game ③에서 할 일 (VFX 세션)
- `VfxRendererFactory`에 LINK_STRIP 렌더러(Line2D, TILE/STRETCH, 점 위치만 갱신).
- `VfxEffectInstance`에 링크 대상 참조·끝점 환산, 새 입력 2개 슬롯, `link_lock_pulse` 감쇠.
- `VfxService.start_vehicle_effect` 옵션에 `link_target_car`. 공급자 검사.
- `RaceAbilityVfxIntegrationController`: `chain_bind` 시작 시 대상 차 참조 전달, 대상에 족쇄 시작(충격파 impact와 같은 외부 시각 프로필 경로), `chain_broken` 종료 시 break 재생, 그 외 종료는 END.
- 8대 부하 측정, OVER/UNDER 평면에서 사슬이 다른 차와 겹칠 때 그리기 순서 확인.

## 6. 게임 기능 세션이 만들어 둘 런타임 입력 (VFX는 받아 쓰기만)

기능 세션은 `RaceAbilityRuntimeController`·`CarAgent`·`RaceManager`만 고치고, 아래를 **VFX가 읽을 수 있게** 만들어 둔다. 이름은 제안이며 바꾸면 기획서에 적는다.

| # | 입력 | 형태 | 내용 |
|---|---|---|---|
| 1 | 대상 차 참조 (발동 순간) | `on_ability_activated` context에 `chain_bind_target_car: CarAgent` | 조건을 채운 추월의 차. 발동 context에 실어 VFX 연결 컨트롤러가 받는다(충격파 `shockwave_source_key` 선례). |
| 2 | 대상 차 참조 (조회) | `CarAgent.get_chain_bind_target() -> CarAgent` | 효과 중이면 대상, 아니면 null. VFX가 매 프레임 유효성 확인용. |
| 3 | 대상 쪽 표시 신호 | 대상 차에 `set_race_ability_external_visual_profile(source_key, "chain_bind_shackle")`, 종료 때 해제 | 충격파 impact와 **같은 경로**. 대상 레이서 교대·피트·정리 때도 해제 신호가 나와야 한다. `source_key`는 묶은 차 발동마다 고유. |
| 4 | 거리 비율 | `CarAgent.get_chain_bind_distance_ratio() -> float` | 묶은 차 기준 `대상과의 앞쪽 경주 거리 / D`. 속도 맞춤 판정과 **같은 틱의 같은 거리**를 쓴다. 효과가 없거나 거리를 못 구하면 0. 0~2로 자른다. |
| 5 | 속도 맞춤 상태 | `CarAgent.is_chain_bind_matching() -> bool` + 신호 `chain_bind_match_state_changed(car, matching: bool)` | 이 틱에 실제 속도를 대상 속도로 맞췄는지. 미끄러짐·코너 예외로 안 맞춘 틱은 false. VFX는 false→true 변화에서 `link_lock_pulse`를 만든다. 코너에서 자주 켜졌다 꺼지면 VFX 쪽에서 최소 간격(1초)을 둔다. |
| 6 | 종료 사유 | `on_ability_ended` context `reason` | `chain_broken`(대상 재추월) / `duration_end` / `pit_entry`(나 또는 대상, 누구인지 `ended_by: "self"|"target"`) / `finished` / `stopped` / `racer_tagged`. **`chain_broken`일 때 context에 `chain_bind_target_car`를 함께 실어야** 끊김 연출이 대상 위치를 안다. |
| 7 | 발동 순간 위치 관계 | (추가 작업 없음) | 발동 직후 거리는 30보다 짧다(방금 추월당함). 30에 닿을 때 #5가 처음 true가 된다 — 이게 "잠김" 순간. |

### 기능 세션에 부탁할 측정
- 실제 경기에서 바인드 중 **내 FRONT ↔ 대상 REAR_CENTER 화면 거리**(월드 px) 분포: 평균·10/50/90 % 값, 그리고 대상과의 차선 차이(lane_delta) 분포. 드리프트 마스터 측정처럼 몇 트랙·×8 속도로. ②에서 사슬 폭·고리 크기·처짐 값을 정하는 데 쓴다.
- 대상이 내 뒤로 가는 경우(대상을 재추월하면 끊기므로 원래 없어야 함)가 실제로 있는지.

### 기능 세션이 정해 줄 것
- 대상 차의 레이서가 교대되면 바인드가 끝나는지(VFX는 그대로 따른다).
- 같은 차가 두 명에게 동시에 묶일 수 있는지(가능하면 족쇄는 충격파처럼 대상당 1개 공유, source_key 집합).

## 7. 필요한 GPT 아트 (5장, 예정)

| 파일 | 용도 | 크기 | 합성 |
|---|---|---|---|
| `talent_chain_bind_chain_links.png` | 사슬 본체 TILE(세로 반복, 고리 2개: 앞면 타원 + 옆면 막대) | 128×256 | ALPHA (heat는 ②에서 이 그림의 달아오른 부분만 뽑아 만든다 — 위치가 정확히 맞도록) |
| `talent_chain_bind_heat_glow.png` | 사슬 아래 열기 빛 띠(STRETCH) + 그림자 | 128×512 | ADDITIVE / 그림자는 검게 ALPHA |
| `talent_chain_bind_shackle.png` | 대상 뒷범퍼 족쇄 띠 + 고리 눈 | 512×256 | ALPHA (heat 동일 방식) |
| `talent_chain_bind_clamp.png` | 내 앞 중앙 쇠고리 | 256×256 | ALPHA (heat 동일 방식) |
| `talent_chain_bind_snap_flash.png` | 걸림·잠김·끊김 순간 흰-주황 섬광 별 | 256×256 | ADDITIVE |

- 스파크는 기존 `fx.furious_overtake_spark`를 호박색으로 곱해 재사용(충격파 선례).
- 재사용 검토: 리바운드 레일·드리프트 꼬리는 빛줄기라 금속 사슬이 아니다. 하위권의 반란 불꽃은 불꽃 재질이라 쓰지 않는다.

## 8. 합의 결과

2026-11-26 지훈: **제안 그대로 확정**.
1. 사슬 연결점: 내 앞 중앙 ↔ 대상 뒷범퍼 중앙, 사슬은 차 위(OVER).
2. 거리 반응 3단계(느슨·팽팽·버팀) + 잠김 번쩍임(`link_lock_pulse`).
3. 끊김은 별도 1회 package(`talent.chain_bind_break`).
4. 플레이어가 묶였을 때: 족쇄 + 사슬만, 화면 효과 없음.
5. 새 기능 범위(5절)와 기능 세션 입력 목록(6절).
6. 아트 5장(7절).

- GPT 아트 요청서: `docs/handoffs/2026-11-26-chain-bind-gpt-art-request.md`.
- 다음:
  - 체인 바인드 게임 기능 세션(휠투휠 다음)이 6절 입력과 측정을 만든다.
  - GPT 아트가 오면 ②: LINK_STRIP 스키마·preview·export 구현, 시안, package 3개.
  - ③ 게임 연결은 기능이 master에 병합된 뒤. LINK_STRIP 렌더러·링크 대상 공급을 함께 만든다.
