# 바람의 레이서 / Wind Racer — 연출 합의 및 설계

> **최종 상태 (2026-10-01): Game 적용·사용자 확인 완료.** 최종 수치는 초안(4장)과 다르다 — START 다발 수명 0.9/1.0s(루프까지 연결), LOOP 다발 알파 0.45·3.2/2.7 per s·max 4·수명 1.0/1.2s(튐 방지 겹침), 전 레이어 색 곱 (0.75, 0.9, 1.0). 최종값은 [Codex 인계](../../handoffs/2026-10-01-wind-racer-codex-handoff.md). legacy `wind_flow` 억제, `blue_focus` 화면 효과 유지.

2026-10-01 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-10-01)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `wind_racer`: trigger `cumulative_slipstream_seconds` 5초, activation_chance 0.3, **duration 15초**, effect: `slipstream_speed_multiplier` 2.0. legacy `visual_profile_id`/`vehicle_fx_id` = `wind_flow`, `player_screen_fx_id` = `blue_focus`.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"wind_racer": "talent.wind_racer"`, catalog 등록.
- 함께 보일 수 있는 기존 효과: `driving.high_speed_wind`(고속 바람선 package), 부스터 불꽃, 날씨 효과. 슬립스트림 중 발동이므로 앞차 바로 뒤 밀집 상황이 많다.

## 2. 참고 자료

- 컷인 `windracer.mp4`(4.0초) + 컨셉 이미지. 1.4~2.0s 앞차 뒤에서 나온 파란 공기 흐름이 내 차로 이어짐 → 2.6s~ 청백색 바람 줄기 여러 가닥이 차체를 감싸며 뒤로 흐름.
- 가져올 것: 차를 감싸고 앞→뒤로 흐르는 청백색 바람 결(유선형 줄기 다발), 뒤로 모여 빠지는 꼬리.
- 생략·변경: 배경·번개·조명·카메라. 앞차와 이어지는 공기 통로는 생략(차량 1대 부착 효과, 밀집 시 복잡).

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.5s | 큰 바람 결이 앞코에서 갈라져 차를 한 번 휩쓸고 뒤로 빠짐(돌풍) | PARTICLE BURST(결 다발 A·B 각 1) |
| LOOP 15s(Game 소유) | ① 차 양옆을 감싸는 바람 결 다발 A·B가 앞→뒤로 계속 흐름 ② 차 뒤로 모여 빠지는 바람 꼬리 | PARTICLE ×2(다발, 이동) + PARTICLE ×1(꼬리) |
| END 0.4s | 새 발생 중단, 남은 결이 뒤로 흘러 소멸 | 빈 phase |

- 전 레이어 ADDITIVE. 다발은 `UNDER_VEHICLE`(차 둘레로 보임), 꼬리 `UNDER_VEHICLE`.
- 다른 파란 계열과 구분: 레인 서퍼 = 하부 진한 파란 네온 + 길에 남는 빛줄기 / 나이트 비전 = 전방 청록 스캔 / 제로의 영역 = 청백 집중광 ↔ 바람의 레이서 = **옅은 청백색, 하부광 없음, 빠르게 뒤로 흐르는 결**.
- 교훈 적용: 절차적 도형 금지(텍스처), 가는 선은 굵게, 주기적 단일 스프라이트 대신 연속 흐름, 변형 2장 교대.

## 4. 초기 수치안 (시안 출발점)

좌표: 차량 source px(256×512, CENTER, 전방 −Y).

- `start.gust_a` / `start.gust_b` PARTICLE CORE ADDITIVE UNDER: `fx.wind_racer_flow_a` / `_b`, BURST 1, offset (0, −120), 방향 180° 속도 650, 수명 0.45, 크기 300 → 420, 알파 1 → 0.
- `loop.flow_a` PARTICLE CORE ADDITIVE UNDER: `fx.wind_racer_flow_a`, offset (0, −70), CONTINUOUS 2.4/s, max 2, 방향 180° 속도 260, 수명 0.75(이동 ≈195 source px), 크기 330 → 360, 알파 0.8 → 0.
- `loop.flow_b`: `fx.wind_racer_flow_b`, 1.9/s, max 2, 속도 300, 수명 0.85, 같은 크기·알파.
- `loop.tail` PARTICLE CORE ADDITIVE UNDER: `fx.wind_racer_tail`, offset (0, +230), 방향 180°±4° 속도 420~520, 수명 0.4, 발생 5/s, max 3, 크기 130 → 170, 알파 0.7 → 0.

Preset: `presets/examples/talent.wind_racer.vfx.json`, preset_id `talent.wind_racer`, `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]` → Runtime v1 예상. 차량당 스프라이트 최대 7, 렌더러 3.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-01-wind-racer-gpt-art-request.md) — 3장.
`talent_wind_racer_flow_a.png` / `_b.png`(192×320), `talent_wind_racer_tail.png`(128×192).

## 6. Game 지원 판단

- PARTICLE ADDITIVE, BURST/CONTINUOUS, VEHICLE_LOCAL, 빈 END: 운영 확인된 범위. 계약·코드 변경 없음.
- 인계 시 확인 요청: `driving.high_speed_wind`와 동시 표시 시 구분, legacy `wind_flow` 억제·`blue_focus` 화면 효과 처리, 앞차 바로 뒤 밀집 시 판독성, START/END보다 긴 수명·첫 방출 지연.

## 7. 다음 작업

1. 사용자: GPT에 아트 요청(컷인 캡처 첨부).
2. Claude: PNG 검수 → 등록 → preset → Game Canvas 100% 시안.
3. 사용자 승인 → 테스트 추가 → package → Codex 인계.
