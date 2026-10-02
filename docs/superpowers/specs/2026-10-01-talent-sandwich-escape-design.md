# 샌드위치 탈출 / Sandwich Escape — 연출 합의 및 설계

2026-10-01 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-10-01, Studio 시안 승인 2026-10-01)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `sandwich_escape`: trigger `rank_range_for_duration`(일반전 4~6위 / 그랑프리 8~12위에 8초), activation_chance 0.3, **duration 10초**, effect: 추월 ×1.2(추월 라인 확률 ×1.2), 최고 속도 ×1.1, 가속 ×1.1. legacy `gold_speed`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`) — 독주(`solo_run`)와 공유.
- **좌우에 차가 있는지는 발동과 무관**(사용자 확인 2026-10-01). 컷인의 "좌우에 끼인" 연출은 쓰지 않고 "중위권 정체를 뚫고 앞으로 치고 나가는 돌파"로 재구성.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"sandwich_escape": "talent.sandwich_escape"`, catalog 등록.

## 2. 참고 자료

- 컷인 `sanwichescape.mp4`(4.0초) + 컨셉 이미지. 차 앞쪽으로 틈을 가르며 뻗는 금빛 길, 차 뒤 금빛 빛줄기, 차체 가장자리 금빛 윤곽, 3.2s~ 빠져나감.
- 가져올 것: 앞으로 뻗는 금빛 길(정체성), 뒤로 뻗는 금빛 추진(시작 1회).
- 생략: 좌우 차·끼임·밀어내기, 배경·반사·카메라, 차체 윤곽선(차종마다 형태가 달라 일반화 불가).

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.4s | 차 뒤 금빛 추진 섬광 + 앞코에서 큰 금빛 화살(쉐브론)이 앞으로 쏘아짐. 루프용 화살이 미리 이어짐 | PARTICLE BURST ×2 + CONTINUOUS ×1(이음) |
| LOOP 10s(Game 소유) | ① 앞코에서 금빛 화살이 연속으로 앞으로 쏘아지며 옅어짐 ② 앞코 양쪽에서 앞으로 짧게 뻗는 금빛 길 두 줄이 일렁임 | PARTICLE ×1(화살) + ×2(길 좌·우) |
| END 0.3s | 새 발생 중단, 자연 소진 | 빈 phase |

- 전 레이어 ADDITIVE, `UNDER_VEHICLE`(앞으로 나가므로 차 가림 없음).
- 구분: 독주 = 차 둘레 뒤로 흐르는 금빛 리본 / 광합성 = 금빛이 모여드는 광선 + 연두 기운 / 나이트 비전 = 앞으로 넓게 퍼지는 청록 호 ↔ 샌드위치 탈출 = **앞으로 쏘아지는 좁고 뾰족한 금빛 화살 + 앞쪽 금빛 길 두 줄**, 하부 기운 없음. 차 뒤 빛줄기는 발동 순간 1회만(루프 뒤 빛줄기는 Game 검토 후 제거, 2026-10-02).
- 중위권이라 앞차가 가깝다 → 화살·길은 **차 한 대 길이 정도까지만** 뻗고 옅게 사라짐.
- 교훈: 텍스처 기반, 이동 파티클은 옅게 겹쳐 연속 흐름, START가 LOOP 첫 발생까지 연결.

## 4. 최종 수치 (사용자 승인 2026-10-01, Game 검토 후 루프 뒤 빛줄기 제거 2026-10-02)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 앞코 ≈ −240, 뒤끝 ≈ +235. 전 레이어 PARTICLE·ADDITIVE·UNDER_VEHICLE, 색 곱 흰색(텍스처 금빛 그대로). offset은 텍스처 기준점(화살 꼭짓점·길 밝은 끝·추진 뿌리)이 앞코/뒤끝에 오도록 크기에서 계산(생성 스크립트).

| layer | 내용 |
|---|---|
| `start.thrust` CORE | 추진 BURST 1, offset (0, +418.3), 방향 180° 속도 0, 수명 0.5s, 크기 220→260, 알파 1 → 0 |
| `start.chevron` CORE | 화살 BURST 1, offset (0, −172.0), 방향 0° 속도 700, 수명 0.6s, 크기 150→110, 알파 1 → 0 |
| `start.chevron_follow` CORE | 화살 CONTINUOUS 5/s max 2, offset (0, −181.1), 속도 600, 수명 0.75s, 크기 130→95, 알파 0.7 → 0 (첫 LOOP 화살 ≈0.69s까지 이음) |
| `loop.chevrons` CORE | 화살 CONTINUOUS 3.5/s max 3, offset (0, −185.6), 속도 600, 수명 0.75s(이동 450 ≈ 차 한 대), 크기 120→90, 알파 0.55 → 0 |
| `loop.path_left` / `loop.path_right` CORE | 길 CONTINUOUS 2.5/s max 3, offset (∓55, −348.3), 속도 120, 수명 1.0s, 크기 200→220, 알파 0.45 → 0 |
차량당 스프라이트: LOOP 정상 최대 9(화살 3 + 길 6), 레이어 max 합 13. START·LOOP 렌더러 각 3. importance CORE 6.

## 4-1. 초기 수치안 (시안 출발점, 기록용)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 앞코 ≈ −240, 뒤끝 ≈ +235.

- `start.thrust` `fx.sandwich_escape_thrust` BURST 1, offset (0, +330)(텍스처 뿌리가 뒤끝에 오게 — 검수 후 보정), 수명 0.5, 크기 220 → 280, 알파 1 → 0.
- `start.chevron` `fx.sandwich_escape_chevron` BURST 1, offset (0, −250), 방향 0° 속도 700, 수명 0.6, 크기 150 → 110, 알파 1 → 0.
- `loop.chevrons` `chevron` CONTINUOUS 3.5/s, max 3, offset (0, −250), 방향 0° 속도 600, 수명 0.75(이동 ≈450 source ≈ 차 한 대), 크기 120 → 90, 알파 0.55 → 0.
- `loop.path_left` / `loop.path_right` `fx.sandwich_escape_path` CONTINUOUS 2.5/s, max 3, offset (∓55, −330), 방향 0° 속도 120, 수명 1.0, 크기 200 → 220, 알파 0.45 → 0(옅게 겹쳐 일렁임).

Preset: `presets/examples/talent.sandwich_escape.vfx.json`, preset_id `talent.sandwich_escape`, `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]` → Runtime v1 예상. 차량당 스프라이트 최대 9, LOOP 렌더러 3.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-01-sandwich-escape-gpt-art-request.md) — 3장.
`talent_sandwich_escape_chevron.png`(128×96), `talent_sandwich_escape_path.png`(48×192), `talent_sandwich_escape_thrust.png`(96×192).

## 6. Game 지원

- 기존 PARTICLE 범위, 계약·코드 변경 없음. 인계 시: 앞차 가림, 부스터 불꽃·독주 리본(같은 금빛 계열)과의 구분, legacy `gold_speed` 억제·화면 효과 처리, START/END보다 긴 수명·첫 방출 지연.

## 7. 시안 이력 (사용자 Studio 녹화 검토 4회)

1. 첫 시안: 화살 흐름·거리(차 길이 약 0.8배)·시작 추진 위치 양호. 시작 화살 소멸 후 첫 루프 화살까지 약 0.15s 빈 구간 → `start.chevron_follow` 추가.
2. 빈 구간 해소 확인. 사용자 질문 "뒤쪽 라인은 루프에서 안 쓰나" → 최고 속도·가속 효과에 맞춰 옅은 루프 뒤 빛줄기 추가(사용자 동의, 권장안).
3. 루프 뒤 빛줄기 일렁임 정상, 단 시작 섬광 소멸 후 0.1s 꺼짐 + 합산 밝기가 앞쪽과 비슷 → `start.rear_follow` 추가, 시작 섬광 수명 0.5→0.6s, 루프 알파 0.35→0.28.
4. 뒤쪽 끊김 없음, 앞쪽 주·뒤쪽 보조 균형 확인 → **승인**.
5. **Game 적용 후 사용자 검토(2026-10-02)**: 실제 경기 크기에서 루프 뒤 빛줄기가 너무 얇고 의미 없어 보임 → `loop.rear_thrust`·`start.rear_follow` 제거, 시작 섬광 수명 0.5s로 복귀. package REPLACE_EXISTING 재생성, 재적용 요청 `docs/handoffs/2026-10-02-sandwich-escape-rear-loop-removal-codex.md`.
   - 교훈: Studio 확대 화면에서 은은한 보조로 보이던 가는 빛줄기는 게임 크기에서 의미를 잃는다 — 보조 레이어는 게임 크기 기준으로 판단.

## 8. 다음 작업

1. Codex: [인계](../../handoffs/2026-10-01-sandwich-escape-codex-handoff.md) — package 도입·연결·확인.
2. 사용자: 샌드위치 탈출 발동 경기 녹화 → Claude 검토.
