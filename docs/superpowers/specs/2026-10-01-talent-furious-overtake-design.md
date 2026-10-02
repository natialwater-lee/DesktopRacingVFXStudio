# 분노의 추월 / Furious Overtake — 연출 합의 및 설계

2026-10-01 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-10-01)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `furious_overtake`: trigger `valid_overtake_failure_count` 4회, activation_chance 0.3, duration 20초, effect: `guaranteed_overtake_charges` 2. legacy `red_breakthrough`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).
- **조기 종료**: `RaceAbilityRuntimeController` 490행 — 충전 2회를 모두 쓰면 `_end_state_effect(state, "charges_consumed")`. 실제 표시 시간은 수 초~20초로 가변 → 짧게 끝나도 어색하지 않은 시작·종료.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"furious_overtake": "talent.furious_overtake"`, catalog 등록.

## 2. 참고 자료

- 컷인 `furiousovertake.mp4`(4.0초) + 컨셉 이미지. 1.4~2.0s 차 뒤 중앙에 붉은 핵이 터지며 강한 빛줄기가 뒤로 → 2.0s~ 차 둘레·노면에 붉은 전기 균열과 스파크, 붉은 빛줄기가 뒤로 찢어지듯 흐름.
- 가져올 것: 뒤 중앙 붉은 핵·빛줄기, 차 둘레 붉은 전기 균열, 스파크.
- 생략·변경: 배경·노면 반사·카메라. 노면 전체로 번지는 균열은 차 둘레로 축소(뒤차·옆차 가림 방지).
- 구분: 붉은 재능은 처음이라 색으로 구분되나, **부스터 불꽃(주황)이 같은 차 뒤**에 나온다 → 불꽃형 대신 진홍·날카로운 전기 균열·가늘고 곧은 빛줄기.

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.4s | 뒤 중앙 붉은 섬광 + 차 둘레 붉은 전기 균열 확산 + 스파크 사방 | PARTICLE BURST ×3 |
| LOOP(≤20s, 충전 소진 시 조기 종료) | ① 붉은 전기 기운 A/B 교대 ② 뒤 중앙 곧은 붉은 빛줄기 ③ 뒤로 튀는 스파크 | PARTICLE ×4 |
| END 0.3s | 새 발생 중단, 자연 소진 | 빈 phase |

- 전 레이어 ADDITIVE, `UNDER_VEHICLE`(스파크는 차 뒤로 나가므로 가림 없음).
- 교훈: 텍스처 기반, 굵게, 이동 파티클은 옅게 겹침, START가 LOOP 첫 발생까지 이어지게.

## 4. 초기 수치안 (시안 출발점)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 뒤 끝 ≈ +240.

- `start.rage_flash` `fx.furious_overtake_rear_beam` BURST 1, offset (0, +250), 속도 0, 수명 0.5, 크기 200 → 260, 알파 1 → 0.
- `start.crack_burst` `fx.furious_overtake_aura_a` BURST 1, offset (0, 0), 수명 0.9(LOOP 첫 기운까지 연결), 크기 260 → 380, 알파 1 → 0.
- `start.spark_burst` `fx.furious_overtake_spark` BURST 8, POINT offset (0, +200), 방향 180° spread 300°, 속도 300~600, 수명 0.4, 크기 26 → 10, 회전 무작위.
- `loop.aura_a` / `loop.aura_b` `aura_a` / `aura_b` CONTINUOUS 1.4 / 1.15 per s, max 2, 수명 1.0 / 1.2, 속도 0, 크기 340 → 368, 알파 0.7 → 0.
- `loop.rear_beam` `rear_beam` CONTINUOUS 6/s, max 3, offset (0, +250), 방향 180° 속도 80, 수명 0.4, 크기 180 → 210, 알파 0.5 → 0(옅게 겹쳐 깜빡임 방지).
- `loop.sparks` `spark` CONTINUOUS 10/s, max 5, offset (0, +210), 방향 180° spread 70°, 속도 250~450, 수명 0.35, 크기 24 → 10, 회전 무작위.

Preset: `presets/examples/talent.furious_overtake.vfx.json`, preset_id `talent.furious_overtake`, `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]` → Runtime v1 예상. 차량당 스프라이트 최대 12, LOOP 렌더러 4.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-01-furious-overtake-gpt-art-request.md) — 4장.
`talent_furious_overtake_aura_a.png` / `_b.png`(192×320), `talent_furious_overtake_rear_beam.png`(64×256), `talent_furious_overtake_spark.png`(32×32).

## 6. Game 지원·후속 선택 사항

- 기존 PARTICLE 범위, 계약·코드 변경 없음. 인계 시: 충전 소진 조기 종료 시 END 정상 처리, 부스터 불꽃과의 구분, legacy `red_breakthrough` 억제·화면 효과 처리, 밀집 추월 상황 판독성.
- **선택(미승인)**: 확정 추월이 실제 소비되는 순간마다 짧은 붉은 섬광 — Game에서 "추월 충전 소비" 이벤트를 VFX로 전달하는 기능 필요(Game 확장). 기본 구성 완료 후 사용자 판단.

## 7. 다음 작업

1. 사용자: GPT에 아트 요청(컷인 캡처 첨부).
2. Claude: PNG 검수 → 등록 → preset → Studio 시안.
3. 승인 → 테스트 → package → Codex 인계.
