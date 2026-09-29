# 비·눈 타이어 package — 월드 잔류 물보라(B) 적용본 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

선행: Game v0.2-35.30.18 (B 엔진 지원 + C 타이어 자국, `DesktopIdleRacing/docs/WEATHER_TRACK_GAME_HANDOFF.md`). 설계: Studio `docs/superpowers/specs/2026-09-30-weather-trail-and-tire-marks-design.md`.

## 0. 먼저 읽을 것

- Codex 인계의 "Claude next"대로, **B를 실제로 쓰는 비·눈 package**를 만들었다. ID 동일, 파일 교체.
- 월드 잔류 레이어는 합의 범위 그대로: **PARTICLE만, `UNDER_VEHICLE`, visual_bend 없음**, 값은 모두 **차량 source px**. Game이 생성 순간 1회 변환한다(중복 배율 금지).
- preset은 Claude가 스크립트로 수정한 뒤 Studio 검증기·export를 통과했고, repo preset은 package `source`와 byte 동일.
- **이 package는 Game v0.2-35.30.18 이상 필요**(이전 Game preflight는 월드 잔류 space를 거부).
- Studio preview는 차량이 이동하지 않아 꼬리 모양을 볼 수 없다. **외형 판단은 Game 실제 주행에서만** 가능하다(Studio에서 한 것은 검증·수치 계산뿐).

## 1. ID / 버전

| ID | Package | Runtime | runtime_inputs | 필요 Game |
|---|---|---|---|---|
| `driving.rain_tire_spray` | 1 | v2 | `speed_normalized` | ≥ 0.2-35.30.18 |
| `driving.snow_tire_spray` | 1 | v2 | `speed_normalized` | ≥ 0.2-35.30.18 |

## 2. 전달물 (Studio `exports/packages/<ID>/`, byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| rain `manifest.json` | 2609 | 7dcc5d95a078 |
| rain `assets/weather_rain_rear_spray.png` | 34046 | 143805a35892 (기존과 동일) |
| rain `assets/weather_rain_droplet.png` | 777 | 8885cceb3ba5 (기존과 동일) |
| rain `assets/weather_spray_puff.png` | 17932 | acf699cbe44b (**신규**) |
| rain `runtime/vfx_runtime_definition_v2.json` | 12796 | 1d7d003d6ac3 |
| rain `source/driving.rain_tire_spray.vfx.json` | 12077 | d076471f18d5 |
| snow `manifest.json` | 2602 | bd612c10aab2 |
| snow `assets/weather_snow_rear_roost.png` | 36483 | 58f811604353 (기존과 동일) |
| snow `assets/weather_snow_chunk.png` | 1530 | 3600f98305a6 (기존과 동일) |
| snow `assets/weather_snow_puff.png` | 19599 | ec1eca5501e7 (**신규**) |
| snow `runtime/vfx_runtime_definition_v2.json` | 12795 | 745f2faeb9ce |
| snow `source/driving.snow_tire_spray.vfx.json` | 12076 | 0fac6ca8d553 |

## 3. 변경점 (직전 package 대비)

| 레이어 | 비 | 눈 |
|---|---|---|
| 차에 붙은 판(START/LOOP/END) | 길이 scale_y 2.4 → **1.3**(뿌리 역할), 기준 불투명도 0.55 → **0.70**(START 0.35, END 0.28). 위치 = 뒷바퀴 축 +117 기준 재계산(offset y 234), clamp 갱신 | scale_y 2.2 → **1.2**, 불투명도 0.75 → **0.85**(0.425/0.34), offset y 225 |
| 보조 PARTICLE(VEHICLE_LOCAL) | 빗방울 그대로(최대 3) | 눈 덩어리 최대 4 → **3** |
| **신규 월드 잔류 PARTICLE** | `loop.spray_trail`: `fx.weather_spray_puff`, CORE, `VEHICLE_FOLLOW_WORLD_TRAIL`, offset (0,150), BOX 90×12, 발생 10/s, **최대 5, 수명 0.5s**, 크기 42→105(source, 긴 변의 절반), 알파 0.55→0, 방향 180°±70°, 속도 60~180, 회전 0~360, 각속도 −30~30°/s, 색 (0.9,0.95,1.0) | `loop.powder_trail`: `fx.weather_snow_puff`, 발생 9/s, **최대 6, 수명 0.7s**, 크기 45→125, 알파 0.7→0, 방향 180°±75°, 속도 60~200, 색 (1,1,1) |

- 수명 근거: Codex 측정 화면 속도 중앙값(직선 ≈200, 코너 ≈119 px/s) → 꼬리 길이 비 ≈100/60px, 눈 ≈140/85px(조각 흩어짐 전). 설계 초안(0.8/1.15s, 꼬리 160~230px = 차 3.5~5대)은 뒤차 가림 우려로 줄였다.
- 차량 1대 최대 스프라이트: 비 1+3+5 = 9, 눈 1+3+6 = 10 → 20대 약 180~200.

## 4. 확인 요청 (첫 운영 사용·미검증)

1. **월드 잔류 레이어 첫 운영 package**: 로드·preflight·실제 꼬리(직선에서 뒤로 늘어나고 코너에서 휘는지), 크기 곡선(화면 ≈8→20px)과 흩어짐.
2. **뒤차 가림·판독성**: 20대 밀집 코너에서 조각이 뒤차를 과하게 덮지 않는지. 넘치면 알파·최대 개수를 알려 달라(Studio에서 수정).
3. **저속·정지**: 조각 발생률은 속도와 무관 → 정지 직전 차 뒤에 조각 소수가 머묾(수용 전제). 피트 중에는 효과 자체 비활성.
4. **수명 > phase**: LOOP 조각(최대 0.7s)이 END(0.4s) 이후 월드에서 소진, STOP·차량 제거·트랙 교체 시 정리.
5. **기존 효과와 겹침**: C 타이어 자국(조각이 그 위), 부스터 불꽃·재능 VFX(차량 쪽), 트랙 강수(z 4000, 위). 그리는 순서가 합의대로인지.
6. **부하**: 교체 전(현재 v2)/후 비·눈 평상시 frame·draw·viewport GPU, 전환 시 타이어 VFX 비용.

## 5. 검증

- Claude 실행: 퍼프 2장 검수(4-2), Studio 검증기 통과, package 2개 `REPLACE_EXISTING` 생성, runtime에 월드 잔류 레이어 포함 확인, preset=source byte 동일.
- Claude 미실행: Studio 전체 회귀, Studio 움직임 미리보기(차량 이동 불가), Game 실행·측정.

## 6. 사용자 시각 승인

- 미승인. Codex 적용 후 격리 실행(`--track=newyork --sequence=none,rain,snow --seconds=12 --duration=36`)으로 사용자 확인. C(타이어 자국)도 같은 녹화에서 함께 확인.

## 7. 다음 담당자

- **Codex**: 2 교체(신규 PNG `.import` 생성) → 4 확인 → 측정 → 공통 인계 형식 보고. 외형 수정은 package를 Game에서 고치지 말고 수치·현상을 Studio로.
- **사용자**: 격리 화면 녹화 → Claude.
- 변경하지 말 것: 트랙 날씨 표현, 자국 발생 조건, 날씨 판정, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
