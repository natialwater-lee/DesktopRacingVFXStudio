# wake·타이어 자국 1차 보정 — Codex 요청 (Studio → Codex)

2026-09-30 · 작성: Claude · 대상: Game Codex · 선행: wake 적용 결과(`DesktopIdleRacing/docs/WEATHER_TRACK_GAME_HANDOFF.md`)

## 0. 요약

사용자 격리 녹화 검토(맑음·비·눈) 피드백과 Claude 확인 결과. 대부분 **데이터 수치**, 두 곳만 작은 코드 변경. 설계·수치는 Claude가 Game을 읽기 전용으로 분석해 정했다. 실제 코드와 다르면 알려 달라.

| # | 사용자 피드백 | 원인 / 판단 | 요청 |
|---|---|---|---|
| 1 | 차량마다 자국 진하기가 다른 것 같다 | **착각 아님.** `CarAgent._update_visual_effects`: 알파 = 기본 × `strength` × 슬립 배율, `strength = clamp(유효 속도 / 유효 최고속, 0.25, 1.0)` → 빠른 차일수록 진함(최대 4배 차이), 슬립 중인 차는 `slip_tire_mark_alpha_multiplier` **1.5배**. 같은 선에 여러 대가 겹치면 누적도 됨 | `strength` 하한 0.25 → **0.7**(0.7~1.0), 슬립 알파 배율 1.5 → **1.2**(폭 1.2배 유지). 속도·슬립 차이는 남기되 차량 간 편차를 줄임 |
| 2 | 자국·후방 효과 좌우 간격을 조금 좁혀야 타이어 위치와 맞는다 | ±102는 가장 넓은 오픈 휠 기준이라 대부분 차량에서 바깥쪽 | `rear_contacts_source_px` → **[[−92,160],[92,160]]** (자국·wake 공통). Studio package 바퀴 파티클도 ±92로 갱신(3장) |
| 3 | 후방 효과가 더 굵어야 물·눈이 바퀴 뒤로 튀는 느낌 | wake 시작 폭 = 타이어 폭(44)과 같아 자국과 구분 약함 | wake **시작 폭 배율** 새 키 `start_width`(타이어 폭 대비) 추가, `end_width`도 타이어 폭 대비로 명시(아래 표) |
| 4 | 눈 효과가 바퀴 자국과 굵기가 비슷해 구분이 안 된다 | 위 3 + **눈 자국 색이 연회색(0.78)으로 흰 wake와 같은 계열** | 눈 자국을 **어두운 젖은 줄**로 변경(아래 표), wake는 흰색 유지 → 색·폭 모두 구분 |
| 5 | 후방 효과 길이를 짧게, 특히 눈은 너무 길어 비현실적 | 꼬리 길이 ≈ 속도 × 수명. 직선 200px/s × 0.5/0.7s = 100/140px(차 2~3대) | 수명 비 0.5 → **0.30s**, 눈 0.7 → **0.28s** → 직선 ≈60/56px, 코너 ≈36/33px(차 약 1.2~1.3대) |

## 1. `data/ui/weather_wake.json`

| 키 | 비 (현재 → 요청) | 눈 (현재 → 요청) |
|---|---|---|
| `start_width` (신규, 타이어 폭 배율) | 1.0 → **1.6** | 1.0 → **2.0** |
| `end_width` (타이어 폭 배율로 의미 명시) | 3.5 → **4.0** | 3.0 → **4.5** |
| `lifetime` | 0.5 → **0.30** | 0.7 → **0.28** |
| `alpha` | 0.35 → **0.45** | 0.5 → **0.6** |
| `color` | 유지 (0.85, 0.90, 0.97) | 유지 (1.1, 1.1, 1.1) |

- 화면 폭(타이어 44 source ≈4px 기준): 비 ≈6.5 → 16px, 눈 ≈8 → 18px. 수명이 짧아진 만큼 알파를 조금 올렸다.
- 페이드 인 0.05s·끝 40% 페이드 아웃·속도 반응(알파 smoothstep 0.15~0.6, 끝 폭 × lerp 0.6~1.0)은 유지. `start_width`에도 같은 속도 배율을 적용할지는 Codex 판단(권장: 시작 폭은 고정).
- 수명 단축으로 동시 조각 수가 줄어 용량(1,024)은 여유.

## 2. `data/ui/tire_marks.json` / 코드

- `rear_contacts_source_px` → `[[-92,160],[92,160]]`. `mark_width_source_px` 44 유지.
- `weather.snow`: color (0.78, 0.80, 0.84) → **(0.10, 0.11, 0.13)**, alpha 0.28 → **0.30**, lifetime 5.0 유지. (다져진 눈 아래 드러난 젖은 노면)
- 코드(`CarAgent.gd`): `strength` 하한 0.25 → **0.7**(데이터 키로 빼도 됨), `slip_tire_mark_alpha_multiplier` 1.5 → **1.2**. 맑음·폭염·비 색·알파는 유지.

## 3. Studio package 갱신 (Claude 완료, byte 그대로 교체)

바퀴 파티클 offset만 (±102, +172) → **(±92, +172)**. 나머지 동일.

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| rain `manifest.json` | 1720 | dba4571888c9 |
| rain `runtime/vfx_runtime_definition_v1.json` | 4188 | a81f4e48d2bb |
| rain `source/driving.rain_tire_spray.vfx.json` | 3975 | 7a0cea67ccb9 |
| rain `assets/weather_rain_droplet.png` | 777 | 8885cceb3ba5 (변경 없음) |
| snow `manifest.json` | 1716 | 3120fca75948 |
| snow `runtime/vfx_runtime_definition_v1.json` | 4188 | ba62b489902a |
| snow `source/driving.snow_tire_spray.vfx.json` | 3975 | 6cbc3ae194f2 |
| snow `assets/weather_snow_chunk.png` | 1530 | 3600f98305a6 (변경 없음) |

## 4. 첫 눈 전환 31.25ms 프레임

- 동기 처리 1.30ms 외 지연 원인 미확정으로 보고됨. Claude 추정(미검증): 눈 wake MultiMesh 재질·셰이더의 **첫 사용 시 준비 비용**(GL Compatibility). 트랙 날씨의 SETUP 실제 렌더 준비(`WeatherVisualPreparation`)처럼 wake 두 재질(비·눈)과 자국 셰이더도 SETUP에서 실제 가시 픽셀로 준비하는지 확인해 달라. 원인이 다르면 측정 결과만 알려 달라.

## 5. 검증·보고

- focused: 자국 알파 계산(하한·슬립), 공통 접점, wake 시작/끝 폭·수명, 눈 자국 색, package 교체 후 파티클 위치.
- 측정: 비·눈 wake CPU·draw call(변화 예상 작음), 첫 비/눈 전환 프레임(4 반영 시).
- 사용자 확인용 격리 실행(맑음·비·눈, 20대). 공통 인계 형식으로 보고.
- 변경하지 말 것: 자국 발생 조건(코너·슬립·0.08s), 날씨 판정, 트랙 날씨 표현, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
