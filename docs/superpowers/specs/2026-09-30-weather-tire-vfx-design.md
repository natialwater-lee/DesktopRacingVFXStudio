# 비·눈 차량 타이어 VFX 개선 — 설계

> **상태 (2026-09-30):** 이 문서의 v2 판(TEXTURED_SPRITE) 구성은 이후 폐기됨. 최종 구성은 `2026-09-30-weather-wake-and-contacts-design.md`(Runtime v1 바퀴 파티클 + Game wake 띠). 이 문서의 뒷바퀴 기준 (±41, +117)은 잘못된 값.

2026-09-30 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 연결: Codex · 승인: 사용자(권장안 전체 승인 2026-09-30)

## 0. 범위

- 대상 package: `driving.rain_tire_spray`, `driving.snow_tire_spray` (ID 유지, 내용 교체).
- Game 연결: `WeatherTireVfxIntegrationController.gd` (현재 모든 주행 차량에 상시, `is_weather_tire_visual_active()` = 이동 중·정지 아님·피트 아님·억제 아님).
- 제외: 트랙 날씨 표현(완료·승인), 타이어 자국, 날씨 판정.

## 1. 현재 문제

| | 비 (Rain Tire Wake) | 눈 (Snow Tire Mist) |
|---|---|---|
| 구성 | 앞코(y≈−148)에 128px 물보라 2장, 속도 2~9로 거의 정지, 알파 0.3→0.12 | 바퀴 4곳에서 가루 구름이 대각선 뒤로, 알파 0.24→0.11, 회색 |
| 보이는 모습 | 앞코 위 해파리/우산 모양 덩어리가 고정 → 스티커 느낌 | 차 옆 그림자·배기 연기처럼 보임, 튕겨내는 움직임 없음 |
| 차량당 부하 | LOOP 레이어 2, 스프라이트 최대 4 | LOOP 레이어 4, 스프라이트 최대 8 (START/END 각 4레이어) |
| 20대 | ≈80 | ≈160, 날씨 전환 시 레이어 생성 비용 최대(Codex 측정: 전환 비용 대부분이 타이어 VFX) |

리소스 판정: `rain_tire_wake_*`·`rain_tire_spray*`는 옆으로 퍼지는/대각선 물보라라 새 연출(뒷바퀴 뒤로 흩날림)과 구도가 맞지 않음. `snow_tire_mist_*`(125px 비표준)는 부드러운 가루뿐이고 덩어리 없음. → **4장 새로 제작**.

## 2. 연출 방향

차체에 빗방울이 튀는 표현은 실제 차량 크기(20~24px)에서 보이지 않으므로 생략(사용자 동의).

| | 비 | 눈 |
|---|---|---|
| 정체성 | 젖은 노면: 뒷바퀴 뒤로 가늘게 흩날리는 반투명 물보라 | 눈길: 뒷바퀴가 눈을 파내 뒤·옆으로 흰 가루와 덩어리를 튕김 |
| 색·질감 | 청회색 반투명, 결이 가는 안개 + 미세 물방울 | 거의 불투명한 흰색, 덩어리진 가루 |
| 움직임 | 물방울이 뒤로 빠르게 빠짐 | 덩어리가 옆·뒤로 부채꼴로 튀고 작아짐 |
| 속도 반응 | 빠를수록 길고 진하게, 거의 멈추면 사라짐 | 같음 |

## 3. 레이어 구성 (좌표: 차량 source px 256×512, CENTER, 전방 −Y. 뒷바퀴 ≈ (±41, +117))

수치는 Studio 시안 출발점이며 Game Canvas 100%에서 조정한다.

### 3-1. 비 `driving.rain_tire_spray`

| phase | layer | type / importance | 내용 |
|---|---|---|---|
| START 0.3s | `start.rear_spray` | TEXTURED_SPRITE CORE | 물보라 판 불투명도 ×0.5 (같은 배치) |
| LOOP | `loop.rear_spray` | TEXTURED_SPRITE CORE | `fx.weather_rain_rear_spray`, 위쪽 끝이 뒷바퀴 축에 오도록 배치, scale ≈(3.0, 2.4)(폭 ≈384 / 길이 ≈460 source px), 기준 opacity 0.55, `ALPHA`, `UNDER_VEHICLE` |
| | `loop.droplets` | PARTICLE DETAIL | `fx.weather_rain_droplet`, BOX 이미터(뒷바퀴 축, 폭 90), 방향 180°±12°, 속도 500~700, 수명 0.28s, 발생 9/s, 최대 3, 크기 22→14, 알파 0.7→0 |
| END 0.4s | `end.rear_spray` | TEXTURED_SPRITE CORE | 불투명도 ×0.4. 남은 물방울은 자연 소진 |

### 3-2. 눈 `driving.snow_tire_spray`

| phase | layer | type / importance | 내용 |
|---|---|---|---|
| START 0.3s | `start.rear_roost` | TEXTURED_SPRITE CORE | 눈보라 판 ×0.5 |
| LOOP | `loop.rear_roost` | TEXTURED_SPRITE CORE | `fx.weather_snow_rear_roost`, 같은 배치 방식, scale ≈(3.6, 2.2)(아트 퍼짐이 좁아 3.2→3.6), 기준 opacity 0.75 |
| | `loop.chunks` | PARTICLE DETAIL | `fx.weather_snow_chunk`, BOX 이미터(뒷바퀴 축, 폭 90), 방향 180°±55°, 속도 150~260, 수명 0.45s, 발생 8/s, 최대 4, 크기 18→8, 알파 0.9→0, 회전 0~360, 각속도 90~240°/s |
| END 0.4s | `end.rear_roost` | TEXTURED_SPRITE CORE | ×0.4 |

### 3-3. modulation (Runtime Definition v2, 헤드라이트·슈퍼 부스터와 같은 기존 기능)

- `runtime_inputs`: `["speed_normalized"]`.
- 판 스프라이트(LOOP)마다:
  - `TRANSFORM_SCALE_Y` MULTIPLY ← `speed_normalized` LINEAR_RANGE 0.15→0.85 ⇒ 0.45→1.0 (빠를수록 길어짐). `modulation_pivot_local`은 텍스처 위쪽 가운데(뒷바퀴 축)로 두어 길이만 뒤로 늘어남.
  - `VISUAL_OPACITY_MULTIPLIER` MULTIPLY ← `speed_normalized` 0.10→0.60 ⇒ 0.0→1.0 (거의 멈추면 사라짐).
  - 일렁임 `PRESET_SOURCE` OSCILLATOR SINE (비 3.1Hz, 눈 2.3Hz): SCALE_X ×0.97~1.03, 불투명도 ×0.92~1.0.
  - `modulation_clamps`로 scale_y 범위 고정.
- PARTICLE은 Game에서 불투명도·배율 modulation을 받지 않는다(`supports_runtime_modulation` = bend만). 보조 파티클은 속도와 무관하게 일정 → 발생 수를 작게 유지.

### 3-4. 부하 (차량 1대)

| | 비 현재→개선 | 눈 현재→개선 |
|---|---|---|
| LOOP 레이어(렌더러 노드) | 2 → 2 | 4 → 2 |
| 스프라이트 최대 | 4 → 1 + 3 | 8 → 1 + 4 |
| START/END 레이어 | 2/2 → 1/1 | 4/4 → 1/1 |
| LOW LOD(DETAIL 제외 시) | — | 스프라이트 1장 |

매 프레임 CPU: 판 1장의 modulation 평가(헤드라이트 야간 20대와 같은 종류) + 파티클 풀 갱신. 날씨 전환·발진 때 생성 노드 수 감소.

## 4. 리소스

요청: [GPT 아트 요청](../../handoffs/2026-09-30-weather-tire-gpt-art-request.md). 4장:
`weather_rain_rear_spray.png`(128×192), `weather_snow_rear_roost.png`(128×192), `weather_rain_droplet.png`(24×48), `weather_snow_chunk.png`(32×32).
등록 logical ID: `fx.weather_rain_rear_spray`, `fx.weather_snow_rear_roost`, `fx.weather_rain_droplet`, `fx.weather_snow_chunk`. 기존 `fx.rain_tire_*`, `fx.snow_tire_mist_*`는 새 package에서 참조하지 않음(카탈로그 정리는 Game 교체 확인 후).

### 4-1. 검수 결과 (2026-09-30, Claude) — 4장 승인

| 파일 | 측정 | 판정 |
|---|---|---|
| rain_rear_spray 128×192 | 시작점 (52,9)/(81,9), 알파 최대 0.80, 여백 2px 이상, 투명부 RGB = 청회색 | 승인. 두 물줄기가 갈라져 뒤로 흩날림, 게임 크기에서 판독 |
| snow_rear_roost 128×192 | 시작점 (51,6)/(76,6), 알파 최대 0.90, 퍼짐 ≈39°(요청 60~70°보다 좁음) | 승인. 폭은 preset scale_x 3.0→3.6으로 보정 |
| rain_droplet 24×48 | 6×40 범위, 머리 아래, 알파 0.90 | 승인 |
| snow_chunk 32×32 | 22×22 범위, 알파 0.95 | 승인 |

참고: 두 판의 밀도 최대가 시작점이 아니라 중간(세로 3~5/8 구간)에 있으나, 게임 크기 모의에서 뒷바퀴에서 뻗는 물줄기로 읽혀 수용.

## 5. Game 쪽 필요 사항 — Codex 사전 확인 회신 반영(2026-09-30)

- **연결 수정 불필요**: `resolve(..., {})`는 누락 입력에 계약 `default`를 쓰고, `VfxService`가 차량 snapshot을 매 갱신 전달한다(헤드라이트와 같음). 설계의 "연결 수정 필요" 가정은 틀렸음 → 정정.
- v2 TEXTURED_SPRITE + PARTICLE 혼합: 슈퍼 부스터 선례, loader·renderer 확장 불필요. PARTICLE은 `modulations`·`modulation_clamps` 빈 배열.
- `speed_normalized` = `clamp(현재 유효 속도 / 현재 유효 최고속, 0, 1)`(타이어·날씨·재능 보정 포함). 구간별 실측 없음 → 매핑은 실제 경기에서 보정.
- DETAIL LOD 실행 처리 없음 → 보조 파티클도 항상 생성(발생 수를 작게 유지한 이유).
- 같은 ID 교체 가능, Game catalog 변경 불필요. 구 리소스는 다른 참조 없는 것만 제거. 비교는 새 프로세스 + `WeatherTransitionProbe.gd`.
- 저속 조건: 게임에 속도 임계값 없음 → **START/END 판에도 같은 속도 불투명도 매핑을 적용**(Studio 결정). 보조 파티클은 저속에서도 남을 수 있음(개수 작아 수용).

## 5-1. 시안 보정·승인 (2026-09-30)

- 1차 녹화: 파티클이 y +130에서 생겨 차 밑에 가려짐 → y +225, 비 크기 26·알파 0.85, 눈 속도 220~340·수명 0.5. 판 흔들림 보강(폭 ±6%, 회전 ±1.5°, 불투명도 0.85~1.0).
- 2차 녹화 후 사용자 승인 → package 2개 `REPLACE_EXISTING` 재생성(Runtime v2). preset 파일은 package source와 byte 동일하게 정렬. 인계: [Codex 인계](../../handoffs/2026-09-30-weather-tire-codex-handoff.md).
- 남은 사항(수용): 속도 0 근처에서 파티클 소수 잔존, 눈 덩어리가 약간 회색·가운데 쪽.

## 6. 진행 순서

1. (이 문서) 설계 + GPT 요청 + Codex 사전 확인 요청.
2. 사용자: GPT·Codex에 전달(병렬).
3. Claude: PNG 검수 → Studio 등록·preset 재작성 → Game Canvas 100% 시안.
4. 사용자 시각 승인 → package 재생성(REPLACE) → Codex 인계.
