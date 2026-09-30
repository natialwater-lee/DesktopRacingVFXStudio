# 레인 서퍼 / Rain Surfer — 연출 합의 및 설계

> **최종 상태 (2026-09-30): Game 적용·사용자 최종 승인 완료.** 최종 구성은 4장 초안과 다르다 — START 0.6s(앞코 뱃머리 물보라 1회: splash 텍스처 180° 회전, offset (25, −41), 수명 0.75s + 네온 점등) / LOOP(네온 A·B 교대 + 월드 잔류 빛줄기 좌·우 x ±84: 18/s, max 9, 수명 0.45s, 크기 120 → 100, 알파 1 → 0) / END 빈 phase. 유지 중 옆 물보라는 제거(주기적 단일 스프라이트가 부자연스러움). 빛줄기 수치는 Codex 실측(조각 길이 16~19px, 직선 간격 9.5~14.5px)으로 확정. 알려진 점: 정지 시 빛줄기 조각이 겹쳐 작은 밝은 덩어리(수용). 인계: `docs/handoffs/2026-09-30-rain-surfer-codex-handoff.md`, `2026-09-30-rain-surfer-trail-tuning-codex.md`.

2026-09-30 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-09-30)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `rain_surfer`: trigger `weather_after_active_racer_time`(weather `rain`, 15초), activation_chance 0.3, **duration 20초**, effect: 빗길 페이스 ×1.10. legacy `visual_profile_id`/`vehicle_fx_id`/`player_screen_fx_id` = `rain_cool`.
- 발동 중 항상 비: 트랙 강수(z 4000), 색보정(어둡고 차가움), 모든 주행 차량의 회색 물보라 wake(바퀴 폭 ×1.6 → ×4.0, 0.30s)와 바퀴 빗방울 파티클, 어두운 젖은 타이어 자국이 동시에 있음. 레인 서퍼는 이것들과 구별되어야 함.
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"rain_surfer": "talent.rain_surfer"`, package catalog 등록.

## 2. 참고 자료

- 컷인 `rainsufer.mp4`(4.0초) + 컨셉 이미지. 0.8~2.6s 차 양옆으로 큰 물보라 날개 → 1.4s~ 차 아래 파란 네온빛, 바퀴에서 파란 빛줄기가 노면을 따라 뒤로 길게 → 3.2s~ 코너에서도 빛줄기가 주행선을 따라 휘어 남음.
- 가져올 것: ① 양옆 물보라 날개(발동) ② 파란 네온 하부광 ③ 바퀴 뒤 파란 빛줄기(정체성).
- 생략·변경: 가로등·배경·노면 반사·카메라. 물보라 날개는 옆 차를 가리므로 발동 1회 크게, 유지 중에는 작게 가끔.

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.5s | 양옆 흰 물보라 날개 1회 + 차 아래 파란빛 점등 | PARTICLE(BURST) 좌·우 + 네온 PARTICLE |
| LOOP 20s(Game 소유) | ① 차 아래 파란 네온빛 A/B 번갈아 일렁임 ② 두 뒷바퀴에서 파란 빛줄기 조각이 **지나간 자리에 남아** 선을 이룸(코너에서 휨) ③ 약 1.5초마다 양옆 작은 물보라 | PARTICLE ×2(네온) + **월드 잔류 PARTICLE ×2**(빛줄기) + PARTICLE ×2(작은 물보라, DETAIL) |
| END 0.4s | 새 발생 중단, 남은 빛줄기·네온 자연 소진 | 빈 phase |

- 빛은 ADDITIVE, 물보라는 ALPHA. 네온·빛줄기 `UNDER_VEHICLE`, 물보라 `UNDER_VEHICLE`(차 옆으로 나가므로 가림 없음).
- 구분: 일반 빗길 wake = 회색·넓게 퍼지는 띠 / 레인 서퍼 = 파랗게 빛나는 가는 두 줄 + 하부 네온.
- 광합성 교훈 적용: 빛은 절차적 GLOW/RING이 아니라 텍스처, 하부광은 변형 2장 교대.

## 4. 초기 수치안 (시안 출발점)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 공통 뒷바퀴 접점 (±84, +160).

- `start.splash_left/right` PARTICLE CORE ALPHA: `fx.rain_surfer_splash_wing`, BURST 1, offset (∓95, −20), 회전 좌 270° / 우 90°(텍스처 위쪽 = 바깥), 방향 좌 270° / 우 90°, 속도 120~160, 수명 0.45, 크기 120 → 210, 알파 0.9 → 0.
- `start.neon_on` PARTICLE CORE ADDITIVE UNDER: `fx.rain_surfer_neon_a`, CONTINUOUS 5/s·max 2(첫 방출 0.2s), 수명 1.2, 크기 300 → 360, 알파 0.9 → 0.
- `loop.neon_a` / `loop.neon_b` PARTICLE CORE ADDITIVE UNDER: 발생 1.3 / 1.05 /s, max 2, 수명 1.1 / 1.3, 크기 340 → 368, 알파 0.7 → 0.
- `loop.trail_left/right` PARTICLE CORE ADDITIVE UNDER, **`VEHICLE_FOLLOW_WORLD_TRAIL`**: `fx.rain_surfer_light_trail`, offset (∓84, +175), POINT, 발생 16/s, max 7, 수명 0.4, 속도 0, 회전 0(생성 순간 차량 방향 캡처), 크기 70 → 60, 알파 0.85 → 0. 직선 200px/s 기준 조각 간격 ≈12px·조각 길이 ≈13px → 연속 선, 꼬리 ≈80px.
- `loop.splash_left/right` PARTICLE DETAIL ALPHA: splash_wing, 발생 0.65/s·max 1, 수명 0.35, 크기 70 → 120, 알파 0.6 → 0, offset (∓95, +40).

Preset: `presets/examples/talent.rain_surfer.vfx.json`, preset_id `talent.rain_surfer`, `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]` → Runtime v1 예상.
부하: 차량당 스프라이트 최대 네온 4 + 빛줄기 14 + 물보라 2 = 20, 렌더러 6. 8대 동시 ≈160. 과하면 빛줄기 발생 12/s·max 5로 축소, 또는 차량 부착 짧은 꼬리로 대체(코너 휨 포기).

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-09-30-rain-surfer-gpt-art-request.md) — 4장.
`talent_rain_surfer_splash_wing.png`(160×128), `talent_rain_surfer_neon_a.png` / `_b.png`(192×320), `talent_rain_surfer_light_trail.png`(32×128).

## 6. Game 지원 판단

- PARTICLE ADDITIVE/ALPHA, BURST/CONTINUOUS, 빈 END: 운영 확인됨.
- `VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE: Game v0.2-35.30.18에서 엔진 지원(PARTICLE·UNDER_VEHICLE·non-bent), **운영 package 첫 사용** → 인계 시 명시. 월드 host는 자국 위·차량 아래.
- 인계 시 확인 요청: legacy `rain_cool`(차량 fx 억제, `player_screen_fx_id` 화면 효과 유지 여부), 비 wake·자국·강수와의 겹침, 8대 동시 부하, 빛줄기가 월드 host에서 ADDITIVE로 그려지는지.

## 7. 다음 작업

1. 사용자: GPT에 아트 요청(컷인 캡처 첨부).
2. Claude: PNG 검수 → 등록 → preset → Game Canvas 100% 시안(Studio preview는 차량이 이동하지 않아 빛줄기 꼬리는 Game에서만 판단 가능).
3. 사용자 승인 → 테스트 추가/갱신 → package → Codex 인계.
