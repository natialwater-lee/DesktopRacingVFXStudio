# 비·눈 타이어 VFX 교체 — Codex 사전 확인 요청 (Studio → Codex)

2026-09-30 · 작성: Claude (Studio 담당) · 대상: Game Codex

## 0. 먼저 읽을 것

- 설계: Studio `docs/superpowers/specs/2026-09-30-weather-tire-vfx-design.md`.
- 이번에는 **Studio package 작업**이다(트랙 날씨와 달리). `driving.rain_tire_spray`, `driving.snow_tire_spray`의 **ID는 유지하고 내용만 교체**한다. Claude가 Studio에서 preset을 다시 만들고 package를 재생성해 전달한다.
- 이 요청은 Claude가 Game을 **읽기 전용으로 분석**해 작성했다. 코드 동작 서술은 실행 검증이 아니다. 기존 GPT 작업의 타이어 VFX 관례와 다를 수 있다.
- 변경 개요: 차량당 레이어를 비 2→2, 눈 4→2로 줄이고, 뒷바퀴 물보라/눈보라 **TEXTURED_SPRITE 1장(속도 modulation)** + 보조 PARTICLE 1개(DETAIL) 구성으로 바꾼다. **Runtime Definition v2 + `runtime_inputs: ["speed_normalized"]`**가 된다.

## 1. 구현 전 확인해 달라는 것

1. **속도 입력 전달**: `WeatherTireVfxIntegrationController.prepare()`가 `VFX_INPUT_RESOLVER_SCRIPT.resolve(package.runtime_definition.get_runtime_inputs(), {})`로 입력 없이 검증한다. `speed_normalized`를 요구하는 package가 여기서 거부되는지, 헤드라이트 연결(`HeadlightVfxIntegrationController`)처럼 차량별 `get_vfx_runtime_input_snapshot`으로 공급되게 바꾸는 범위는 어느 정도인지.
2. **v2 + 혼합 레이어**: 한 effect 안에 TEXTURED_SPRITE(speed·OSCILLATOR modulation, `modulation_pivot_local`, `modulation_clamps`)와 PARTICLE(modulation 없음)을 같이 쓰는 것이 현재 loader/preflight/renderer에서 문제없는지(슈퍼 부스터 선례 확인).
3. **`speed_normalized` 의미**: 값 범위(0~1의 기준 최고 속도), 일반 주행·코너·피트 진출입에서의 대략적인 값. 설계는 0.15→0.85에서 길이 0.45→1.0, 0.10→0.60에서 불투명도 0→1로 잡았다.
4. **LOD**: importance DETAIL 레이어를 부하 등급에 따라 빼는 처리가 현재 있는지(없어도 진행 가능, 사실만 알려 달라).
5. **교체 절차**: 같은 ID package를 교체할 때 기존 assets(`rain_tire_wake_*`, `snow_tire_mist_*`) 정리, catalog 변경 필요 여부, 트랙 날씨 작업에서 쓴 `WeatherTransitionProbe.gd`로 교체 전/후 전환 비용 비교 가능 여부.
6. **20대 상시 조건**: `is_weather_tire_visual_active()`(이동 중·정지 아님·피트 아님·억제 아님)를 유지하는 것을 전제로 한다. 추가로 속도 0 근처에서 효과를 멈추는 게임 쪽 조건이 이미 있는지.

## 2. 지금 하지 않을 것

- 아트 4장은 GPT 제작 중. Claude 검수·Studio 시안·사용자 승인 후 package를 전달한다. 그 전에는 package 교체·연결 수정을 시작하지 않아도 된다.
- 날씨 판정·트랙 날씨 표현(승인 완료)·재능 VFX·저장 데이터는 대상이 아니다.

## 3. 회신 형식

항목 1~6별로 가능 / 조건부(조건) / 불가(대안)와 예상 변경 파일만 짧게.
