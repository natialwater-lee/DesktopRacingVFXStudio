# 스노우 보더 / Snow Boarder — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-10-02, Studio 시안 승인 2026-10-02)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `snow_boarder`: trigger `weather_after_active_racer_time`(눈 날씨, 주행 15초 후), activation_chance 0.3, **duration 20초**, effect: 눈 날씨 주행 속도 ×1.1(`weather_pace_multiplier`). legacy `snow_frost`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`; `RaceAbilityVisualController.gd`·`RaceAbilityScreenEffect.gd`에서 사용).
- **항상 눈 날씨에서만 보인다** → 눈 트랙 색 보정·눈 내림·바퀴 자국/wake·`driving.snow_tire_spray` 바퀴 눈가루와 함께 보인다.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"snow_boarder": "talent.snow_boarder"`, catalog 등록.

## 2. 참고 자료

- 컷인 `snowboarder.mp4`(4.0초) + 컨셉 이미지: 0~0.3s 바퀴에서 큰 눈보라 폭발, 이후 뒷바퀴 두 개에서 청록 빛줄기가 노면에 길게 남고 눈가루 안개가 뒤로 흩날림.
- 가져올 것: 뒷바퀴에서 노면에 남는 빛줄기(정체성), 시작 눈보라 폭발.
- 생략: 배경·카메라·차체 반사, 유지 중 눈가루 안개(날씨 바퀴 눈가루와 겹쳐 묻힘).

## 3. 합의한 연출 — "얼음 위를 가르는 카빙"

| 구간 | 연출 | 구현 |
|---|---|---|
| START ≈0.5s | 뒷바퀴 양쪽에서 눈가루가 부채꼴로 크게 터짐 + 얼음 결정 반짝임 몇 개 | PARTICLE BURST(눈가루 좌·우, ALPHA) + BURST(반짝임, ADDITIVE) |
| LOOP 20s(Game 소유) | ① 뒷바퀴에서 흰빛~옅은 청록 **서리 빛줄기**가 노면에 남음 ② 빛줄기 위에 작은 **얼음 결정 반짝임**이 드문드문 남았다 사라짐 | PARTICLE `VEHICLE_FOLLOW_WORLD_TRAIL` ×2(좌·우 빛줄기) + ×2(좌·우 반짝임, DETAIL) |
| END 0.3s | 새 발생 중단, 자연 소진 | 빈 phase |

- **레인 서퍼와 구분**(사용자 확인 포인트): 레인 서퍼 = 진한 파랑 네온 하부광 + 파랑 네온 빛줄기 + 앞코 물보라 ↔ 스노우 보더 = **하부광 없음**, 빛줄기는 흰빛~옅은 청록에 **가늘고 날카로운 서리·결정 질감**, 결정 반짝임, 시작은 **뒷바퀴 눈가루**.
- 레인 서퍼에서 실전 검증된 월드 잔류 PARTICLE 방식을 그대로 쓴다 → Game 코드 변경 없음 예상.
- 눈가루는 흰 눈이므로 ALPHA(`driving.snow_tire_spray`와 같은 방식, Game 적용 검증됨), 빛줄기·반짝임은 ADDITIVE.
- 교훈 적용: 텍스처 기반, 이동/잔류 파티클은 옅게 겹쳐 연속(rate×life ≥3), START가 LOOP 첫 발생까지 연결, 단일 주기 스프라이트 금지.

## 4. 최종 수치 (Studio 시안 승인 2026-10-02)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 뒷바퀴 접지(공용) ≈ (±84, +160). 전 레이어 PARTICLE·UNDER_VEHICLE, 색 곱 흰색.

| layer | 내용 |
|---|---|
| `start.powder_left` / `start.powder_right` CORE **ALPHA** | 눈가루 BURST 1, offset (∓125.0, +272.8)(뿌리가 뒷바퀴, 회전 ±20° 기준 계산), 회전 +20°/−20°(바깥 뒤), 방향 180° 속도 120, 수명 0.6s, 크기 150→210, 알파 0.95 → 0 |
| `start.glints` CORE ADDITIVE | 결정 BURST 8, offset (0, +170), 방향 180° spread 160°, 속도 150~350, 수명 0.6s, 크기 90→30, 회전 0~45° |
| `loop.trail_left` / `loop.trail_right` CORE ADDITIVE **월드 잔류** | 서리 빛줄기 18/s max **13**, offset (∓84, +200), 속도 0, 수명 **0.7s**, 크기 120→100, 알파 0.9 → 0, **색 곱 (0.7, 0.93, 1.0)** (Game 검토 후 변경, 원래 레인 서퍼 최종값 0.45s·max 9·흰색) |

START 0.5s / END 0.3s(빈 phase). 차량당 스프라이트 LOOP 최대 26(빛줄기 좌·우 13), 레이어 max 합 36. importance CORE 5. (LOOP 결정 반짝임은 Game 검토 후 제거 2026-10-02) Runtime v1.

## 4-1. 초기 수치안 (시안 출발점, 기록용)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 뒷바퀴 접지(공용) ≈ (±84, +160).

- `start.powder_left` / `start.powder_right` `fx.snow_boarder_powder_fan` ALPHA BURST 1, 뿌리가 뒷바퀴(∓84, +160)에 오게, 회전 ∓20°(바깥 뒤로), 수명 0.7, 크기 220 → 300, 알파 0.9 → 0.
- `start.glints` `fx.snow_boarder_ice_glint` ADDITIVE BURST 6, offset (0, +160), 방향 180° spread 160°, 속도 150~350, 수명 0.6, 크기 40 → 15, 무작위 회전.
- `loop.trail_left` / `loop.trail_right` `fx.snow_boarder_frost_trail` ADDITIVE `VEHICLE_FOLLOW_WORLD_TRAIL`, offset (∓84, +175), 16/s, max 7, 수명 0.45, 속도 0, 크기 70 → 60, 알파 0.85 → 0(레인 서퍼 최종값 기준, 겹침 연속선). START 시작 직후 끊김이 보이면 START에 같은 CONTINUOUS 이음 레이어 추가.
- `loop.glint_left` / `loop.glint_right` DETAIL `ice_glint` `VEHICLE_FOLLOW_WORLD_TRAIL`, offset (∓84, +190), 3/s, max 3, 수명 0.8, 크기 36 → 10, 알파 0.9 → 0, 무작위 회전.

Preset: `presets/examples/talent.snow_boarder.vfx.json`, preset_id `talent.snow_boarder`, `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]`.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-snow-boarder-gpt-art-request.md) — 3장.
`talent_snow_boarder_frost_trail.png`(32×128), `talent_snow_boarder_ice_glint.png`(32×32), `talent_snow_boarder_powder_fan.png`(128×160).

## 6. Game 지원

- 기존 PARTICLE·월드 잔류 범위, 계약·코드 변경 없음 예상. 인계 시: 눈 트랙 색 보정 위 가독성(ADDITIVE가 밝은 눈 화면에서 묻히는지), 눈 wake·바퀴 눈가루와 겹침, legacy `snow_frost` 억제·화면 효과 처리, 20초 동안 월드 잔류 입자 부하.

## 7. 시안 이력 (사용자 Studio 녹화 검토 2회)

1. 첫 시안: 눈가루 방향(바퀴 → 바깥 뒤) 맞음, 단 너무 크고 회색 덩어리처럼 둔함 / 결정 거의 안 보임 → 눈가루 220→300을 150→210·수명 0.6s·속도 120, 결정 시작 44→90(8개)·루프 40→80.
2. 눈가루 짧게 터짐, 결정 반짝임 보임, 시작→루프 빈틈 없음 → **승인**. 서리 빛줄기는 Studio 미리보기 차가 정지해 바퀴 위에 막대로 쌓여 보임 → 길이·굵기·밝기는 Game 녹화로 판단.

3. **Game 적용 후 검토(2026-10-02, 밤·눈 경기 녹화)**: 빛줄기는 연속 곡선으로 남고 다른 차와 구분됨. 단 흰 바퀴/스키 자국처럼 보여 "빛" 느낌 약함(텍스처 청록 가장자리가 게임 크기에서 소실), 꼬리 차 길이 절반으로 짧음, 결정 반짝임 안 보임 → 빛줄기 색 곱 옅은 얼음 청록·수명 0.45→0.7s(max 9→13), 결정 80→140·청록 색 곱(다음 검토에도 안 보이면 제거). 재적용 요청 `docs/handoffs/2026-10-02-snow-boarder-trail-tuning-codex.md`.

4. **재적용 검토(2026-10-02)**: 빛줄기 청록 서리 빛으로 보이고 꼬리 92.5→145px(약 1.57배, Codex 실측) → 승인 수준. LOOP 결정은 크기 140에서도 경기 크기에서 안 보임(Codex·Claude 동일 판단) → `loop.glint_left/right` 제거(시작 burst 결정은 유지). Codex 부하(20대 야간 눈, 6대 활성): 평균/P95 7.470/13.519 → 7.295/13.163ms, draw 405 → 463. 재적용 요청 `docs/handoffs/2026-10-02-snow-boarder-glint-removal-codex.md`.
   - 교훈: 게임 크기에서 작은 반짝임(표시 ≈4~14px)은 보이지 않는다 — 결정·스파크류는 분노의 추월 스파크(80, 밝은 색)처럼 크고 움직임이 있어야 읽힌다.
5. **결정 제거 적용 후 Claude 부하 측정(2026-10-02)**: NightVisionGameProbe, 20대 뉴욕 밤 눈, debug GL, 21~29s, 2회씩. 발동 없음 7.01/13.55·7.17/13.57ms, draw 273·269 / 6대 발동 7.69/13.71·7.33/13.51ms, draw 428·429(결정 제거 전 463). 발동 프레임 16.2·16.5ms, 종료 소진 정상.

## 8. 다음 작업1. Codex: [인계](../../handoffs/2026-10-02-snow-boarder-codex-handoff.md).
2. 사용자: 눈 경기 스노우 보더 발동 녹화 → Claude 검토(특히 빛줄기).