# Rotor Lift Downwash 재제작 설계 (2026-10-08)

대상: 특수장비 로터 리프트 / preset·package `equipment.rotor_lift.downwash` (Formula 전용, Mk.I~IV).

## 1. 기존 효과의 문제 (Studio 장착 preview로 확인)

- 위치: 장비는 256px 프레임 × (기준폭 512/256) × `runtime_visual.scale 1.25` = 2.5배로 그려져 팬 중심이 차량 원본 기준 약 **±187px**. 기존 VFX 중심은 ±150px이라 회전 중심이 팬 허브와 어긋남.
- 가림: Game에서 UNDER_VEHICLE VFX(z −20)는 장비 underlay(z −10) 아래. 코어 스파이럴은 하우징에 가려지고 바깥 테두리만 보여 **하얀 톱니가 도는 것처럼** 읽힘.
- 중복 회전: 장비 지속 프레임(24fps, 24장)이 이미 팬 회전을 보여 주는데 VFX도 2.4Hz / 1.35Hz로 따로 회전.
- 화풍: 붓질 소용돌이가 하드서피스 메카닉 아트와 맞지 않음.

## 2. 새 방향 — "아래로 내뿜은 바람이 차체를 들어 올린다"

탑뷰에서 하강 기류는 지면에 부딪혀 **바깥으로 퍼지는 압력 파동과 흩날리는 먼지·안개**로만 보인다. 회전 표현은 장비 애니메이션에 맡기고, VFX는 **팬 중심에서 바깥으로 밀려나는 공기**만 그린다.

- 중심: 좌우 팬 허브 **(−187.5, 0), (187.5, 0)** — 장비 placement에서 계산한 값.
- 평면: UNDER_VEHICLE 유지. 하우징 반경(약 100px) 안쪽은 장비에 가려지므로 **반경 100px 밖에서 읽히는 형태**로 설계. 링이 작을 때 시작해 커지며 하우징 밖으로 나오므로 루프 이음새는 하우징 아래에 숨는다.
- 색: 무채색 흰 공기·옅은 회청색 안개(Mk 색상과 충돌 없음). ALPHA 블렌드.
- 회전 레이어 없음.

### START (약 0.35s) — 이륙 분사
- 팬마다 `lift_burst` 1장: 스케일 0.6→1.15로 커지며 opacity 1→0. 팬 아래에서 바람이 한 번 "펑" 터져 나가며 차를 띄우는 순간.
- 같은 타이밍에 `air_ring` 1장이 크게 퍼짐.

### LOOP — 지속 하강 기류
- 팬마다 `air_ring` 2장. 각각 LINEAR_PHASE로 스케일 작게→크게, opacity 1→0. Game LINEAR_PHASE는 위상 오프셋을 지원하지 않으므로 **두 링의 주파수를 다르게**(예: 1.7Hz / 2.3Hz) 두어 엇갈린 불규칙 리듬을 만든다(실제 난류처럼).
- 팬마다 `mist_puff` PARTICLE: 하우징 가장자리(반경 ~100px)에서 생성, 바깥으로 흩어짐 + 뒤쪽(+y) 가속으로 주행 중 뒤로 쓸려 가는 느낌. 저밀도(LOD EXTRA).

### END (0.2s, 장비 회수 0.5s와 동시)
- 약한 `air_ring` 1장이 퍼지며 소멸. 회수 애니메이션이 이어서 마무리.

### R5 Studio 시안 (2026-10-08, 사용자 피드백 반영 — 시각 승인 대기)

R5 후속(R6): R5 반경이 너무 좁다는 피드백 → 링 최대 0.85→1.05, START blast 0.9→1.1, 안개 속도 LOOP 95~155 / START 140~210. 아래 R5 수치 중 해당 항목은 이 값으로 대체.

R4 피드백: `lift_burst` 방사형 줄기가 꽃잎처럼 보여 부자연스럽고, 바람이 너무 넓게 퍼짐. → `lift_burst` 제거(자산 등록 해제), 링 최대 스케일 1.3→0.85, 안개 속도·크기 축소.

- sources(모두 LINEAR_PHASE): `rotor.burst.phase` 1/0.35Hz, `rotor.ring_a.phase` 1.6Hz, `rotor.ring_b.phase` 2.15Hz. Game source 시간은 효과 시작 기준(`VfxEffectInstance._instance_elapsed`).
- START: 팬마다 `air_ring` blast(CORE 0.7, 0.42→0.9, opacity ×(1→0)) + `mist_puff` BURST 6개(EXTRA).
- LOOP: 팬마다 `air_ring` 2장(A CORE 0.5 / B DETAIL 0.38, 좌우 A/B 주파수 교차), 스케일 0.42→0.85(바깥 가장자리 ≈ 하우징 반경 2배), opacity ×(0→2)×(2→0) 포물선. `mist_puff` CONTINUOUS(EXTRA, 10/s, 최대 5, 속도 70~120, 후방 가속 160, 크기 70→115, alpha 0.5→0).
- END: LOOP 링 4장 opacity ×0.55.
- LOD: LOOP HIGH 6 / MEDIUM 4 / LOW 2.
- 포물선 opacity는 입력 0..1 전 구간 매핑만 사용한다(Studio preview는 LINEAR_RANGE 입력을 클램프하지 않음).

## 3. 필요한 아트 (GPT)

요청서: `docs/handoffs/2026-10-08-rotor-lift-downwash-gpt-art-request.md`
- `rotor_lift_air_ring.png` 512×512
- `rotor_lift_lift_burst.png` 512×512 (R5에서 미사용 — 꽃잎처럼 보임)
- `rotor_lift_mist_puff.png` 128×128

기존 `rotor_lift_downwash_core/soft`, `rotor_lift_turbulence_particle`은 새 package에서 제외.

## 4. 기존 기능 재사용 / 계약

- TEXTURED_SPRITE + PARTICLE, PRESET_SOURCE LINEAR_PHASE, TRANSFORM_SCALE_X/Y MULTIPLY, VISUAL_OPACITY_MULTIPLIER MULTIPLY — 모두 Game Runtime 2 loader 지원 범위. 새 계약 없음.
- Game 연결(`SuperBoosterVfxIntegrationController`의 `ROTOR_LIFT_DOWNWASH_PRESET_ID`)과 package ID 유지, 자산만 교체.

## 5. Studio 장착 preview (완료)

- `assets/preview/special_equipment/` — Game 프레임 사본 + 배치 카탈로그(복사 원본 명시).
- `src/preview/equipment/vfx_preview_equipment_catalog.gd` — Game `resolve_visual_placement`와 같은 계산, 지속 24fps 루프, 회수 = 전개 역재생 0.5s.
- 그리는 순서: UNDER VFX → 장비 underlay → 차량 → (overlay 장비) → OVER VFX.
- 재생 매핑: VFX START/LOOP = 장비 ACTIVE, VFX END = 장비 RETRACT(VFX 소진 후에도 0.5s까지 재생). 전개(DEPLOY)는 Game에서 VFX 시작 전 구간이라 preview에 표시하지 않음.
- 미포함: 장비 그림자(Game `SpecialEquipmentShadow`), 차량별 `vehicle_visual_overrides`(현재 로터 리프트는 비어 있음).
- `tests/preview/test_special_equipment_preview.gd` — Game 정의·PNG와 사본 일치 검사(Game 프로젝트가 없으면 생략).

## 6. Game 적용 (2026-10-08)

R6 사용자 승인 후 package export(REPLACE_EXISTING) → Game `assets/vfx/packages/equipment.rotor_lift.downwash` 교체, Game 브랜치 `claude/rotor-lift-downwash-r6`, v0.2-35.30.44. 기록: Game `docs/current/WORKLOG.md`.

R7(2026-10-08 게임 화면 피드백: 연하고 느림): 링 opacity A 0.85 / B 0.7, 주파수 2.4 / 3.1Hz, START 링 0.9, 안개 alpha 0.7·14/s·최대 7. Game 재적용.

R8(2026-10-08 피드백: 빨라졌다 느려짐): 2.4/3.1Hz 링이 맥놀이(0.7Hz)를 만듦 → 단일 source `rotor.ring.phase` 2.8Hz, A 0.42→1.05, B(안쪽 따라오는 링) 0.42→0.8. 좌우 동일 박자. Game 재적용.

R9(2026-10-08 피드백: 한 번씩 쏘는 느낌 → 연속적으로): fade-in 제거(opacity 1→0, 시작 크기 0.42는 하우징에 가려짐), `rotor.ring.phase` 2Hz(A 0.42→1.05) + `rotor.ring_fast.phase` 4Hz(B 0.42→0.85)로 0.25초마다 링, 안개 22/s·최대 11. Game 재적용.

R10(2026-10-08 피드백: 여전히 쉬면서 나오고 약함): 2Hz·4Hz 링 동시 출발로 강약 → 링을 PARTICLE로 전환(`loop.left_rings`/`right_rings`, CORE, POINT, 7/s, 수명 0.45, half size 107→269, alpha 1→0, 회전 ±25°/s). END 레이어 없음(LOOP 입자 자연 소진). source는 `rotor.burst.phase`만. LOD: HIGH 4 / MEDIUM·LOW 링 방출기 2.

R10 반경 조정(2026-10-08): 반복 속도 승인, 넓이 +15% → 링 half size_end 269→309(지름 618px), 안개 속도 110~178.

## 7. 확정 (2026-10-08)

사용자 확정: R10(링 입자) + 넓이 15%(size_end 309). Game 적용 완료.
