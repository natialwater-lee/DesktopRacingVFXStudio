# wake·타이어 자국 2차 보정 — Codex 요청 (Studio → Codex)

2026-09-30 · 작성: Claude · 대상: Game Codex · 선행: 1차 보정(`2026-09-30-weather-wake-tuning-codex.md`) 적용 결과

**데이터 수치만** 바꾼다(코드 변경 없음). 사용자 녹화 피드백 + Claude 검토.

## 1. 변경 요청

| 대상 | 키 | 현재 → 요청 | 이유 |
|---|---|---|---|
| `tire_marks.json` | `rear_contacts_source_px` | [±92,160] → **[±84,160]** | 사용자: 바퀴 간격을 아주 조금 더 좁혀야 타이어 위치와 맞음(자국·wake 공통) |
| `weather_wake.json` snow | `start_width` | 2.0 → **1.7** | 사용자: 눈 폭이 조금 과함. 직선 밀집 구간에서 여러 대의 눈 띠가 겹쳐 차선 전체가 회색 카펫처럼 덮임 |
| 〃 | `end_width` | 4.5 → **3.6** | 〃 (화면 ≈7 → 14px, 비 6.5 → 16px보다 끝 폭이 약간 좁고 시작은 약간 굵음) |
| 〃 | `lifetime` | 0.28 → **0.36s** | 사용자: 눈은 비보다 가벼워 공중에 더 오래 날림 → 비(0.30s)보다 약간 길게. 직선 꼬리 ≈72px(비 ≈60px), 코너 ≈43px |
| 〃 | `alpha` | 0.6 → **0.55** | 폭은 줄지만 수명이 늘어 전체 양이 비슷해지므로 조금 낮춰 회색 카펫 현상 완화 |

비 wake, 맑음·폭염·비·눈 자국 색·알파·수명, 발생 조건은 그대로.

## 2. Studio package (Claude 완료, byte 그대로 교체)

바퀴 파티클 offset (±92, +172) → **(±84, +172)**. 나머지 동일.

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| rain `manifest.json` | 1720 | 7df87519eaca |
| rain `runtime/vfx_runtime_definition_v1.json` | 4188 | 378caa623695 |
| rain `source/driving.rain_tire_spray.vfx.json` | 3975 | 260800880502 |
| rain `assets/weather_rain_droplet.png` | 777 | 8885cceb3ba5 (변경 없음) |
| snow `manifest.json` | 1716 | c45312fc7f68 |
| snow `runtime/vfx_runtime_definition_v1.json` | 4188 | 9c4f21817fbe |
| snow `source/driving.snow_tire_spray.vfx.json` | 3975 | 954916c5bb6f |
| snow `assets/weather_snow_chunk.png` | 1530 | 3600f98305a6 (변경 없음) |

## 3. 검증·보고

- 데이터 반영 확인(자국·wake 접점 동일, 눈 wake 폭·수명·알파), package 교체 후 파티클 위치.
- 측정은 수명 증가분(눈 wake 동시 조각 수 약 +30%)만 짧게: 눈 wake CPU·용량 점유.
- 사용자 확인용 격리 실행(비·눈). 공통 인계 형식으로 짧게 보고.
- 변경하지 말 것: 자국 발생 조건, 날씨 판정, 트랙 날씨 표현, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
