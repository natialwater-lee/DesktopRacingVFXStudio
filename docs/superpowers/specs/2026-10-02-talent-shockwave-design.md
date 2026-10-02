# 충격파 / Shockwave — 연출 합의 및 설계 (발동 차 + 영향받은 차 2개 package)

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-10-02 — 실제 판정 반경까지 퍼짐, 영향받은 차에는 해제될 때까지 표시)

## 1. Game 정의·동작 (읽기 전용 확인)

- `race_ability_defs.json` → `shockwave`: trigger `actual_slip_count` 2회, activation_chance 0.3, duration 12초(**밸런스에 따라 바뀔 수 있음** — 사용자), effect: `radius` 80(Game 월드 px), `target_driving_stability_multiplier` 0.5. visual: `vehicle_fx_id`/`visual_profile_id` `shockwave_aura`, `activation_fx_id` `shockwave_pulse`(0.7s), `impact_fx_id` `shockwave_impact`, 화면 효과 없음.
- 발동 시(`RaceAbilityRuntimeController.gd` 681·705행): 발동 차 `trigger_race_ability_transient_fx(activation_fx)` + `_apply_shockwave_targets` — 반경 안 다른 차 각각 `set_race_ability_external_stability_multiplier(source_key, 0.5)` + `set_race_ability_external_visual_profile(source_key, impact_fx_id)`. 효과 종료 시 `_clear_shockwave_targets`(728행) → 대상 `clear_race_ability_external_stability_multiplier`(`CarAgent.gd` 3022행, 외부 프로필도 함께 해제).
- 즉 **효과가 두 종류의 차에 붙는다**: 발동 차(지속 동안) + 영향받은 차들(해제될 때까지).

## 2. 참고 자료

- 컷인 `shockwave.mp4`(4.0초) + 컨셉 이미지: 0.5~2.2s 발동 차 중심 파란 전기 동심원 충격파가 퍼짐 → 2.4s~ 주변 차들이 주황 번개에 휘감기고 흰 연기, 흔들림.

## 3. 합의한 연출

### 3-1. `talent.shockwave` — 발동 차

| 구간 | 연출 | 구현(예정) |
|---|---|---|
| START ≈0.7s | 파란 전기 동심원 충격파가 **실제 판정 반경까지** 퍼지며 옅어짐 | TEXTURED_SPRITE(고리): 크기 = `effect_radius` 비례 × LINEAR_PHASE 0.1→1, 불투명도 1→0 |
| LOOP (Game 소유, 밸런스 가변) | 작은 파란 잔진동 물결이 약 1.5s마다 은은하게(반경보다 훨씬 작게) | PARTICLE CONTINUOUS(고리 텍스처, 크기 증가·페이드) — 길이와 무관 |
| END | 자연 소진 | 빈 phase |

### 3-2. `talent.shockwave_impact` — 영향받은 차(해제될 때까지)

| 구간 | 연출 | 구현(예정) |
|---|---|---|
| START ≈0.4s | 맞은 순간 주황 스파크가 팍 튐 | PARTICLE BURST(기존 `fx.furious_overtake_spark` 재사용, 주황~노랑 색 곱) + 번개 고리 BURST |
| LOOP (해제 시점 Game 소유) | 차 둘레 주황 번개 지지직(A/B 교대) + 가끔 작은 불꽃 | PARTICLE A/B 교대(광합성 방식) + 소량 스파크(DETAIL) |
| END ≈0.3s | 해제되면 자연 소진 | 빈 phase 또는 짧은 페이드 |

- 여러 대가 동시에 맞을 수 있어 impact는 **가볍게**(LOOP 스프라이트 ≤ 6/대).
- 색: 발동 차 전기 파랑(0.35, 0.65, 1.0) / 맞은 차 주황~노랑(1.0, 0.65, 0.2) — 분노의 추월 진홍과 구분.
- 구분: 나이트 비전 = 앞쪽 부채꼴 청록 호 / 절대 방어 = 옆 벽 ↔ 충격파 = **완전한 원형 동심원**(발동 차) + **다른 차에 붙는 주황 번개**.
- 모든 LOOP는 길이와 무관(연속 방출·교대). 지속 시간·반경 밸런스 변경에 Studio 수정 불필요.

## 4. Game 연동 (사전 확인 대상)

1. **영향받은 차에 package 부착**: `_apply_shockwave_targets`에서 각 대상 차에 `talent.shockwave_impact` 시작(source_key별), `_clear_shockwave_targets`/외부 프로필 해제 시 정지(END). 같은 차가 여러 충격파에 동시에 맞을 때 처리(source_key별 개별 or 1개 공유).
2. **`effect_radius` 공급**(schema에 이미 있는 입력, Game 공급 없음 확인): 발동 차 `talent.shockwave` effect에 `effect_values.radius`를 **차량 source px**로 환산해 공급(밸런스 반경 변경 자동 반영). 환산은 Game VFX 배율 기준(Codex 결정·보고). 기본 0이면 고리가 보이지 않으므로 공급 필수.
3. legacy: 발동 차 `shockwave_aura`·`shockwave_pulse`, 대상 차 `shockwave_impact`(`RaceAbilityVisualController.gd` 117·148·173행 절차 그리기) 억제.
- 사전 확인: `docs/handoffs/2026-10-02-shockwave-codex-precheck.md`.

## 4-1. Codex 사전 확인 회신 (2026-10-02, 읽기 전용) — 계약 확정

- 부착: `VfxService`(45행)는 재능 소유와 무관하게 지정 차량에 package 부착 가능, START/LOOP/END·소진·강제 정리 재사용. 대상은 **발동 순간 `_apply_shockwave_targets`가 선택한 목록 그대로**(반경 재검색 없음). 외부 프로필 추가·해제·전체 해제(`CarAgent.gd` 3022행)에 시각 알림 연결 — 대상 차 레이서 교체 시 해제도 포함. 정상 해제 = END, 차량 제거·레이스 정리 = 강제 정리.
- 중복: **대상당 impact effect 1개 공유** — source_key 집합 관리, 첫 참조에 START, 마지막 해제에 END, 추가 source는 START 재실행·시간 초기화 없음. 게임플레이 안정성 곱(0.5×0.5)은 별개로 유지.
- `effect_radius`: 이름 유지, **반지름·차량 source px**. Game 공급식 `effect_radius = 판정 월드 반경 / CarSprite 실제 월드 배율`(부모 배율 포함 `global_transform`, 고정 계수 금지), 발동 시 명시 공급, START 첫 프레임부터 적용. 비균일 배율은 원 보장 불가 → 지원 판정 필요. 기본 0 의존 금지, 입력 범위·clamp가 반경을 제한하지 않게.
- legacy: `shockwave_aura`는 기존 package 소유권 처리, `shockwave_pulse` 직접 호출·대상 `shockwave_impact` 외부 프로필은 별도 억제. 두 package 모두 준비된 경우에만 소유권 확정.
- 부하 우려: 발동 1 + 대상 8 = effect 9개, 대상 LOOP 스프라이트 최대 ~48 + START/END 잔여. CPU 파티클·layer별 풀 생성(측정은 Claude).
- **Studio 반영**: 고리 텍스처 기준 반지름 **231 texel**(측정) → `scale = effect_radius / 231`를 무제한 선형 매핑(`LINEAR_RANGE` 0..231 → 0..1, 외삽)으로 구현, clamp 없음. END는 양의 지속 시간(0.3s, 빈 레이어).

## 4-2. 초기 시안 수치 (2026-10-02)

| package | layer | 내용 |
|---|---|---|
| `talent.shockwave` | `start.wave` TEXTURED_SPRITE | 고리, scale = `effect_radius`/231 × `wave.intro` LINEAR_PHASE(1.333Hz, 0.7s에 0.93) 0.15→1, 불투명도 ×1→0.15 |
| | `start.core_flash` | 고리 PARTICLE BURST, 크기 60→200, 수명 0.5s, 색 곱 (0.7, 0.85, 1.0) |
| | `loop.ripple` | 고리 PARTICLE 0.7/s max 2, 수명 1.2s, 크기 80→230, 알파 0.45 → 0, 색 곱 파랑 |
| `talent.shockwave_impact` | `start.hit_sparks` | 스파크(`fx.furious_overtake_spark`) BURST 8, 색 곱 (1.0, 0.7, 0.3), 360°, 속도 250~450, 수명 0.6s, 크기 75→25 |
| | `start.hit_arc` | 번개 A BURST, 수명 1.05s(첫 LOOP 번개 ≈1.03s까지), 크기 309→349 |
| | `loop.arc_a` / `loop.arc_b` | 번개 A/B 1.6 / 1.3 per s, max 2, 수명 0.8 / 0.95s, 크기 336→349(빈 타원 ≈ 307×498 source px, 가장 큰 차 둘레) |
| | `loop.sparks` DETAIL | 스파크 3/s max 2, 수명 0.5s, 크기 60→20 |

START 0.7 / 0.4s, END 0.3s(빈). impact LOOP 스프라이트 최대 6/대.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-shockwave-gpt-art-request.md) — 3장.
`talent_shockwave_ring.png`(512×512), `talent_shockwave_impact_arc_a.png` / `_b.png`(192×320). 스파크는 `fx.furious_overtake_spark` 재사용(색 곱).

## 6. 다음 작업

1. 사용자: GPT 아트 요청(컷인 캡처 첨부), Codex 사전 확인 전달.
2. Claude: 미리보기 `effect_radius` 슬라이더 추가 → PNG 검수 → 등록 → preset 2개 → Studio 시안.
3. 승인 → 테스트 → package 2개 → Codex 인계 → Claude 부하 측정(대상 차 다수 포함).

## 8. Game 적용 후 (2026-10-02)

- Codex 적용(Game `docs/SHOCKWAVE_GAME_HANDOFF.md`): 반경 START 전 공급, 대상당 impact 1개 공유, legacy 3경로 억제. Codex 지적 — Game은 일반 LINEAR_RANGE binding을 clamp하고 반경 scale만 외삽(`wave.intro` 마지막 표본 Studio ≈1.003 vs Game 1, 반경 80 기준 ≈0.24px 차, 수용).
- Claude 부하(측정 스크립트에 `_race_cars.assign(_cars)` 추가 + 직접 발동 시도, 20대 뉴욕, 2회): 발동 없음 7.03·6.96ms / draw 216·219 → **발동 6대 + 맞은 차 15·16대** 7.10·7.20ms / draw 282·286, 발동 순간 17.9·17.8ms(발동 6 + impact 15~16 시작이 한 프레임, 최악 조건). 판단: 부하 문제 없음.
- 사용자 경기 녹화: 맞은 차들의 주황 번개 타원이 전체 화면 크기에서도 보임.
