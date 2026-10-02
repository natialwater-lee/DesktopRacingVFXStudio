# 피트스톱 에이스 / Pit Stop Ace — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인, Studio 시안 승인 2026-10-02)

## 1. Game 정의·동작 (읽기 전용 확인)

- `race_ability_defs.json` → `pit_stop_ace`: trigger `pit_service_concurrent_count` 4, activation_chance 0.3, **`activation_mode: instant`, duration 0** — 지속 재능이 아님. visual `instant_fx_id`/`vehicle_fx_id` `pit_stop_ace_burst`, `instant_fx_duration_sec` 0.70.
- 발동(`RaceAbilityRuntimeController.gd` 666·688행): `car.complete_active_pit_service_immediately()` 성공 시 발동 → `trigger_race_ability_transient_fx(instant_fx_id, 0.7)`.
- **사용자 확인**: 발동 순간 현재 차량이 사라지고 **다음 차량으로 교체** → 효과는 **교체된 다음 차량**에 붙어야 한다. 차량 형태가 차종마다 다르다.

## 2. 시간 (사용자 결정 2026-10-02)

- 지속 시간이 없으므로 **고정 시간 재생**. 발동 영상이 4초이므로 영상이 끝난 뒤에도 확인 가능하게 **총 약 5.5초**.
- **플레이어·NPC 구분 없음**(사용자: 플레이어도 영상 위치에 따라 차가 보일 수 있다). NPC는 영상 없이 바로 나오므로 너무 길지 않게 — 5.5초 안에서 앞부분을 강하게, 뒤는 은은하게.
- 구현: `START_LOOP_END` — START 0.6s(강한 연출) + LOOP(은은, 길이 무관) + END 0.4s. **Game이 시작 후 5.1s에 LOOP 종료 지시**(END 0.4s 포함 총 5.5s). 고정 시간 값은 Game 데이터(`visual.instant_fx_duration_sec` 등)로 두어 조정 가능하게(Codex 판단). ONE_SHOT 사용 가능 여부도 사전 확인.

## 3. 참고 자료

- 컷인 `pitstopace.mp4`(4.0초) + 컨셉 이미지: 0~1s 네 바퀴 휠이 주황 테두리 + 파란 빛 고리로 달아오르고 스파크 → 1.4~2.5s 피트 노면 청록 출발 라인 → 2.9s~ 연기와 함께 급출발.

## 4. 합의한 연출 — "새 타이어, 즉시 출격"

차종마다 앞바퀴 위치가 달라 **뒷바퀴 공용 위치 (±84, +160)**(날씨 바퀴 효과에서 확정, 모든 차 폭을 가장 큰 차에 맞춤)에만 바퀴 효과를 둔다.

| 구간 | 연출 | 구현(예정) |
|---|---|---|
| START 0.6s | 차 전체를 감싸는 주황·파랑 정비 섬광 1회 + 뒷바퀴 두 곳에서 스파크 팍 | PARTICLE BURST(섬광) + BURST(스파크, `fx.furious_overtake_spark` 주황 색 곱) + 휠 고리 BURST(LOOP까지 연결) |
| LOOP(Game 지시까지, 약 4.5s) | ① 뒷바퀴 두 곳 빛나는 휠 고리(주황 테두리·파란 심)가 빠르게 회전 ② 차 양옆을 따라 청록 출발 라인이 뒤로 흐름 | PARTICLE(휠 고리, 각속도, 겹쳐 연속) + PARTICLE(청록 라인, 뒤로 이동) |
| END 0.4s | 자연 소진 | 빈 phase |

- 색: 휠 주황(1.0, 0.6, 0.2) + 파랑(0.3, 0.65, 1.0), 출발 라인 청록(0.2, 1.0, 0.85). 전 레이어 ADDITIVE·UNDER_VEHICLE.
- 구분: 엔지니어 노즐 고리 = 부스터 자리 4개·정지 ↔ 피트스톱 에이스 = **뒷바퀴 2개 회전 휠**. 윈드 레이서 흰 기류선 ↔ **청록 직선 출발 라인**. 스노우 보더 노면 잔류 ↔ 차에 붙어 흐르는 라인.
- 교훈 적용: 선 굵게, 작은 반짝임 없음, START→LOOP 연결, 길이 무관 LOOP.

## 5. Game 연동 (사전 확인 대상)

1. 효과를 **교체된 다음 차량**에 시작(발동 순간 차량 교체와의 순서, 교체 후 차량 참조 시점).
2. 고정 시간(5.5s) 재생 방식: START_LOOP_END + 5.1s 뒤 LOOP 종료 지시 권장, 또는 ONE_SHOT 지원 여부.
3. legacy `pit_stop_ace_burst`(0.7s transient) 억제.
- 사전 확인: `docs/handoffs/2026-10-02-pit-stop-ace-codex-precheck.md`.

## 6. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-pit-stop-ace-gpt-art-request.md) — 3장.
`talent_pit_stop_ace_wheel_ring.png`(128×128), `talent_pit_stop_ace_service_flash.png`(320×320), `talent_pit_stop_ace_launch_line.png`(48×256). 스파크는 `fx.furious_overtake_spark` 재사용.

## 7. 다음 작업

1. 사용자: GPT 아트 요청(컷인 캡처 첨부), Codex 사전 확인 전달.
2. Claude: PNG 검수 → 등록 → preset → Studio 시안.
3. 승인 → 테스트 → package → Codex 인계 → Claude 부하 측정.

## 8. 최종 수치·시안 이력 (Studio 시안 승인 2026-10-02)

- 최종 수치: 인계 문서 `docs/handoffs/2026-10-02-pit-stop-ace-codex-handoff.md` 3절(섬광 크기 280→350, 뒷바퀴 스파크 BURST 6, 휠 고리 OVER_VEHICLE 크기 68·900°/s·3.5/s max 3, 출발 라인 (∓128, +40) 6/s 속도 560 크기 170→150 알파 0.9).
- 이력: 1) 휠 고리가 차체(뒷바퀴는 차체 가장자리 아래)에 가려 안 보이고 출발 라인 약함 → 휠 고리 OVER_VEHICLE·48→68·알파 0.9, 라인 120→170·알파 0.9. 2) **승인**.
- Codex 사전 확인 회신 전 인계(사용자 진행 지시) — 교체 시점·고정 시간 방식은 인계 4절에서 Codex가 판단·보고.

## 9. Game 적용 후 Claude 부하 측정 (2026-10-02)

- Codex 적용(Game `docs/PIT_STOP_ACE_GAME_HANDOFF.md`): 교체된 다음 차량에 부착, 5.1s 발생 중단 → END 0.4s, 재진입·교체·제거·경기 종료 정리.
- 측정: Codex `PitStopAceGameProbe.PitManager` 고정 경기(실제 피트 정비 6대, 3대 동시 발동·교체) 위에 Claude 측정 스크립트(scratchpad `pit_load_probe.gd`)로 발동 전 3s vs 발동 후 5.5s 비교, 20대 debug GL. VFX 있음: 7.03/13.44 → 7.15/13.32ms, draw 253 → 284 / 6.94 → 7.34ms, draw 248 → 277. 발동 프레임(3대 동시 + 교체) 51~56ms.
- **튀는 프레임(70~95ms, 발동 후 2.7s·4.3~7s)은 VFX를 즉시 지운 비교 실행(`pit_load_probe_novfx.gd`)에서도 같은 시점·크기로 발생** → VFX 원인 아님(피트 출구·교체 차량 고정 경기 쪽). VFX 순수 비용: draw +27~33, 평균 프레임 +0.1ms 수준. 발동 프레임 55ms도 VFX 없이 56~60ms로 동일.
