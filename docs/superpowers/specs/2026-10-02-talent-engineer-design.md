# 엔지니어 / Engineer — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인, Studio 시안 승인 2026-10-02)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `engineer`: trigger `normal_boost_count` 4회, activation_chance 0.3, **duration 15초**, effect: 부스터 게이지 소모 ×0.5, 일반 부스터 재사용 대기 ×0.5.
- legacy `engineer_pulse`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`; `RaceAbilityVisualController.gd` 110·171행).
- 의미: **차를 튜닝해 부스터를 효율적으로, 더 자주 쓴다.**
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"engineer": "talent.engineer"`, catalog 등록, legacy 차량·화면 효과 처리.

## 2. 참고 자료와 제약

- 컷인 `engineer.mp4`(4.0초) + 컨셉 이미지: 차체 투시(X-ray) — 파란 설계도 회로선이 차체를 따라 흐르고, 내부 엔진·배관이 주황으로 달아오름, 배기구에 빛나는 원형 노즐 + 부스터 불꽃.
- **제약(사용자 2026-10-02)**: 차종마다 형태·크기가 다름 → 차체 윤곽을 따르는 회로선은 일반화 불가. **차 모양과 무관하게 둘러싸는 요소**로 표현. 크기는 가장 큰 차량 기준(사용자: 향후 모든 차 폭을 가장 큰 차량에 거의 맞춤) — 작은 차는 살짝 여유 있게 감쌈.
- 실제 일반 부스터 = 차 뒤 짧은 빨간 불꽃 4개(`driving.standard_boost`, x ±22·±66, y +290~+377).

## 3. 합의한 연출 — "정비·진단 모드"

| 구간 | 연출 | 구현 |
|---|---|---|
| START ≈0.5s | 파란 진단 스캔선이 차 앞→뒤로 한 번 훑음 + 네 모서리 설계도 괄호가 바깥에서 조여 들어와 자리 잡음 | PARTICLE BURST(스캔선, 앞→뒤 이동) + PARTICLE BURST ×4(괄호, 크기 축소) |
| LOOP 15s | ① 네 모서리 파란 설계도 괄호(끝에 주황 점)가 숨 쉬듯 밝기 변화 ② **부스터 작동 중** 빨간 불꽃 4개 자리에 튜닝 노즐 고리(파랑 테두리·주황 핵) 점등 | TEXTURED_SPRITE ×4(괄호, OSCILLATOR 불투명도) + TEXTURED_SPRITE ×4(노즐, `boost_active` 불투명도·크기) |
| END 0.3s | 새 발생 중단, 자연 소진(TEXTURED_SPRITE는 phase 종료 시 사라짐 — 필요하면 END에 페이드 레이어) | 시안에서 결정 |

- 색: 파랑(0.3, 0.65, 1.0) 설계도 선 + 주황(1.0, 0.55, 0.15) 포인트(컷인 조합). 전 레이어 ADDITIVE.
- render plane: 스캔선은 차 위를 훑어야 하므로 **`OVER_VEHICLE`**(Schema enum 지원, Game `VfxRendererFactory`·`VfxVehicleHostAccess` z 20 지원, 광합성·독주·제로 존이 이미 사용 — 확인 2026-10-02). 괄호·노즐은 `UNDER_VEHICLE`(차 밖 모서리·뒤라 가림 없음).
- 구분: 나이트 비전 = 앞쪽으로 퍼지는 청록 호 / 에너지 전환 = 뒤 펜더 번개 + 청록 분출 ↔ 엔지니어 = **차 위를 앞→뒤로 훑는 직선 스캔 + 네 모서리 괄호 + 부스터 노즐 고리**(파랑+주황). 괄호·프레임 모양은 아직 다른 재능에 없음.
- 위험: 괄호가 UI(선택 표시)처럼 보일 수 있음 → 매끈한 선이 아닌 **빛나는 설계도 선 질감**(눈금·이중선)으로 요청.
- 교훈 적용: 선 굵기 4px 이상, 작은 반짝임 없음, 단일 주기 스프라이트 대신 연속 변조(OSCILLATOR), START→LOOP 연결.
- 부스터 연동: 에너지 전환에서 추가한 `boost_active` 재사용(Runtime v2). Game 공급은 에너지 전환 인계에서 구현 — **에너지 전환 적용 완료 후에만 동작**.

## 4. 최종 수치 (Studio 시안 승인 2026-10-02)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 상자 = 가장 큰 차 기준 꼭짓점 (±128, ±258). TEXTURED_SPRITE 크기 = 텍스처 px × scale. 전 레이어 ADDITIVE.

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.scan` OVER_VEHICLE | 스캔선 TEXTURED_SPRITE, scale (1.05, 1.8)(굵게), opacity 1.0, `bracket.intro` LINEAR_PHASE 1.9Hz 0→0.95 ⇒ y −258→+258(앞→뒤 1회) |
| | `start.bracket_fl/fr/rr/rl` | 꺾쇠 TEXTURED_SPRITE, 회전 0/90/180/270°, 중심 (∓87·±85, ∓215·±217)(꼭짓점 텍셀 (23,21)이 상자 꼭짓점에 오게 계산), opacity 0.85, intro ⇒ 불투명도 ×0→1.05, 바깥 46px → 0 조여 들어옴 |
| LOOP 15s | `loop.scan` OVER_VEHICLE | 스캔선 TEXTURED_SPRITE, 같은 크기, opacity 0.8, `scan.sweep` OSCILLATOR 0.28Hz(한 방향 ≈1.8s) ⇒ y −258↔+258 앞뒤 왕복. 위상 39.6° = START 끝(0.5s)에 뒤끝(+258)에서 이어받음 |
| | `loop.bracket_*` | 꺾쇠 4개 같은 위치, `bracket.pulse` OSCILLATOR 0.6Hz(위상 90°) ⇒ 불투명도 ×0.55~1.0 |
| | `loop.nozzle_1~4` UNDER_VEHICLE | 노즐 고리 TEXTURED_SPRITE (−66·−22·22·66, +252)(일반 부스터 불꽃 뿌리), scale 0.7, `boost_active` 0→1 ⇒ 불투명도 ×0→1, 크기 ×0.7→1.0 |
| END 0.45s | `end.bracket_*` | 꺾쇠 PARTICLE BURST(같은 위치·회전, 크기 64 = scale 1), 수명 0.45s, 알파 0.85→0 — LOOP 스프라이트가 끊기지 않고 사라지게 |

`runtime_inputs: ["boost_active"]` → **Runtime v2**. importance CORE 18. 스프라이트 LOOP 최대 9(스캔 1 + 꺾쇠 4 + 노즐 4).

## 4-1. 초기 수치안 (시안 출발점, 기록용)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 가장 큰 차 기준 외곽 ≈ x ±115, y −245 ~ +240 → 괄호 꼭짓점 ≈ (±128, ±258).

- `start.scan` `fx.engineer_scan_line` BURST 1, offset (0, −280), 방향 180° 속도 1000, 수명 0.55(앞→뒤 ≈550), 크기 150 → 150(폭 ≈ 차 폭), 알파 1 → 0.3.
- `start.bracket_fl/fr/rl/rr` `fx.engineer_corner_bracket` BURST 1, 꼭짓점 위치, 회전 0/90/270/180°, 수명 0.6, 크기 90 → 60(조여 들어옴), 알파 1 → 0.
- `loop.bracket_*` TEXTURED_SPRITE ×4, 같은 위치·회전, opacity 0.8, OSCILLATOR SINE 0.6Hz → 불투명도 ×0.55~1.0.
- `loop.nozzle_1~4` TEXTURED_SPRITE `fx.engineer_nozzle_ring`, (±22·±66, +262), opacity 1.0, `boost_active` 0→1 ⇒ 불투명도 ×0→1, 크기 ×0.7→1.0.

Preset: `presets/examples/talent.engineer.vfx.json`, `talent.engineer`, `RACE_TALENT`, `START_LOOP_END`, `runtime_inputs: ["boost_active"]`.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-engineer-gpt-art-request.md) — 3장.
`talent_engineer_scan_line.png`(256×64), `talent_engineer_corner_bracket.png`(128×128), `talent_engineer_nozzle_ring.png`(64×64).

## 6. 시안 이력 (사용자 Studio 녹화 검토 3회, 일반 부스터 겹침 비교용 preset 사용 후 삭제)

1. 시작 스캔·꺾쇠 조임 의도대로, 꺾쇠가 UI처럼 보이지 않음. 사용자: 루프가 밋밋 → 루프 스캔 추가(파티클 1.25s 주기).
2. 사용자: 스캔 시작 위치가 상자와 안 맞음, 작은 차에서 안 보일 것, 조금 덜 잦게 → 스캔을 굵기 조절 가능한 TEXTURED_SPRITE(scale Y 1.8)로 바꾸고 상자 범위(±258)만 앞뒤 왕복(0.28Hz), START 끝에서 LOOP가 뒤끝에서 이어받게 위상 계산.
3. **승인**. 부스터 시 노즐 고리 점등 확인.
4. **Game 적용(2026-10-02, Codex: `TRANSFORM_OFFSET_X/Y` ADD 지원 추가, Game `docs/ENGINEER_GAME_HANDOFF.md`)**. Claude 부하(부스터 4회 조건 강제, 20대 뉴욕, 6대 발동, 2회): 발동 없음 6.95·7.02ms / draw 220·218 → 6대 7.04·7.13ms / draw 245·240, 발동 순간 15ms. 사용자 경기 녹화 확대: 꺾쇠·스캔선이 게임 크기에서 보임.

## 7. 다음 작업

1. Codex: [인계](../../handoffs/2026-10-02-engineer-codex-handoff.md).
2. Claude: 적용 후 부하 측정(`normal_boost_count` 조건 강제 probe).
3. 사용자: 발동 + 부스터 경기 녹화 → Claude 검토(꺾쇠·스캔 굵기).