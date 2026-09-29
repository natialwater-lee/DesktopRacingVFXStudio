# 물보라 띠(wake) + 공통 뒷바퀴 접점·자국 폭 + 비·눈 package 정리 — Game 구현 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (설계·리소스 검수) · 대상: Game Codex · 공통 인계 형식

설계: Studio `docs/superpowers/specs/2026-09-30-weather-wake-and-contacts-design.md`(7장 확정 사항이 최신).

## 0. 먼저 읽을 것

- 사전 확인 회신(항목 1~11)과 **사용자 추가 결정**을 반영했다.
- **사용자 결정(2026-09-30)**: 앞으로 모든 차량의 폭을 현재 가장 큰 차량과 거의 같게 맞추고 차량 형태도 최종본이 아니므로, **타이어 위치는 현재 가장 큰 차량 기준 공통값 하나**로 한다. 차량별 override는 쓰지 않는다. → 회신 1(차량 ID·이미지 대응)과 10(로컬 파티클이 override를 따르지 않음) 문제는 해소된다.
- 이전 접점 (±41, +117)은 Claude의 측정 오류였다(Codex 구현 결함 아님).
- 설계·수치는 Claude가 Game을 읽기 전용으로 분석하고 회신을 근거로 정했다. 실제 코드와 충돌하면 추측하지 말고 사용자에게 확인한다. 이전 GPT 흐름의 관례와 다를 수 있다.
- 이번 전달물(wake 텍스처 2장 + 비·눈 package)은 **wake 구현과 함께 한 번에 교체**한다. package만 먼저 바꾸면 물보라가 사라진 상태가 된다.

## 1. 공통 뒷바퀴 접점·타이어 폭

- 기준: 현재 가장 넓은 실제 바퀴를 가진 차량(오픈 휠 `car_f` 계열, 후방 외곽 ±120 source px)의 뒷바퀴.
- **접점 (±102, +160) source px(256×512, CENTER, +Y 후방), 타이어 폭 44 source px**(화면 ≈4px). 모든 차량 공통, `vehicle_overrides`는 비워 둔다.
- 사용처: 타이어 자국, wake 띠, 비·눈 package의 바퀴 파티클(고정 offset (±102, +172)로 같은 기준).

## 2. 타이어 자국 수정

- `data/ui/tire_marks.json`: `rear_contacts_source_px` → `[[-102,160],[102,160]]`, 새 키 `mark_width_source_px: 44`.
- 폭: 원본 44 × **실제 CarSprite 변환 배율** → 표시 폭, 사각형 폭 = 표시 폭 × 32/18(텍스처 띠 18/32px). 슬립 1.2배 유지. 기존 `width_multiplier`에 들어 있는 차량 배율(`race_object_scale`)과 **중복 적용 금지**(회신 2).
- `repeat_length_px` ≈20, 기존과 같은 월드 거리 단위로 명시.
- 색·알파·수명·발생 조건·감쇠는 그대로.

## 3. wake 레이어 (신규)

- 구조(회신 3·6·8): **별도 wake 관리 노드 + 날씨별 MultiMeshInstance2D 2개(비·눈)** + wake 셰이더. 연속 획·누적 거리 UV·링 버퍼는 자국 엔진 재사용, 수명·발생 조건은 자국과 분리. 월드 host 평면에서 **자국 다음, 차량 이전**.
- 발생(회신 4): `CarAgent._update_visual_effects()`의 코너·슬립 조기 반환 **앞**에서 독립 타이머. 조건: 날씨가 비·눈 + `is_weather_tire_visual_active()`. 바퀴별 **0.05s** 간격, 직선 포함.
- 인스턴스 데이터(회신 5): 시작 폭 = 인스턴스 변환. 표시 폭 = 타이어 폭 44 × 실제 CarSprite 배율, 사각형 폭 = 표시 폭 × **64/48**(wake 텍스처 64px 중 유효 폭 ≈48px, 양쪽 ≈8px는 부드러운 가장자리). custom data = 생성 시각·UV 시작·UV 길이·**생성 당시 speed_normalized**. 날씨별 수명·끝 폭 배율·색·알파는 재질 uniform.
- 표현:

| | 비 | 눈 |
|---|---|---|
| 텍스처 | `weather_rain_wake_strip.png` | `weather_snow_wake_strip.png` |
| 수명 | 0.5s | 0.7s |
| 폭 | 시작 = 타이어 폭 → 끝 ×3.5 (smoothstep) | 끝 ×3.0 |
| 알파 | 0.35 | 0.5 |
| 색 | (0.85, 0.90, 0.97) | (1.1, 1.1, 1.1) — 텍스처가 중립 회색 0.8대라 보정, 결과 1.0 초과분은 clamp |
| 페이드 | 생성 후 0.05s 페이드 인, 수명 끝 40% 페이드 아웃 | 같음 |
| 속도 | 알파 × smoothstep(0.15, 0.6, speed), 끝 폭 × lerp(0.6, 1.0, speed) | 같음 |

- 용량(회신 7): 비·눈 **합산 1,024**, 가장 오래된 조각부터 덮어씀(날씨 전환 중 남은 이전 조각 포함). 진한 조각(α>0.3) 덮어쓰기 비율을 계측해 기록.
- 날씨 전환: 새 조각부터 새 날씨 MultiMesh, 기존 조각은 원래 재질로 소멸.
- 연결 끊기: 자국과 같은 규칙(발생 틈·피트·순간이동·거리 초과).
- 시각 시계: 자국과 같은 명시적 시각 시계(결과 화면에서도 소멸 진행, teardown 초기화).

## 4. 비·눈 package 교체 (Claude 완료)

`C:\GodotProjects\DesktopRacingVFXStudio\exports\packages\<ID>\`, byte 그대로 교체:

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| rain `manifest.json` | 1720 | cb990e0a54ce |
| rain `assets/weather_rain_droplet.png` | 777 | 8885cceb3ba5 |
| rain `runtime/vfx_runtime_definition_v1.json` | 4190 | eae4fbe2a050 |
| rain `source/driving.rain_tire_spray.vfx.json` | 3977 | 9a08d40f15e8 |
| snow `manifest.json` | 1716 | efdb294a3402 |
| snow `assets/weather_snow_chunk.png` | 1530 | 3600f98305a6 |
| snow `runtime/vfx_runtime_definition_v1.json` | 4190 | 6be21155eee7 |
| snow `source/driving.snow_tire_spray.vfx.json` | 3977 | f67b2def672a |

- **Runtime v2 → v1**(회신 9·10): `runtime_inputs` 없음, modulation 없음. 차 중앙 판(TEXTURED_SPRITE)·월드 잔류 puff 레이어 제거 → 이전 package의 `weather_*_rear_*`, `weather_*_puff` 리소스와 `vfx_runtime_definition_v2.json`은 새 package에 없음(다른 참조 없으면 정리).
- LOOP: 좌·우 뒷바퀴 VEHICLE_LOCAL PARTICLE 2개(CORE), offset (±102, +172), BOX 20×10, 각 최대 2.
  - 비: 빗방울, 방향 180°±8° 바깥쪽 기울기, 속도 480~680, 수명 0.3s, 발생 6/s.
  - 눈: 눈 덩어리, 180°±30° 바깥쪽, 속도 220~340, 수명 0.5s, 발생 5/s, 회전.
- **START 0.05s·END 0.3s, 레이어 0개**(양수 duration 조건 충족, BURST 없음). START 0.05s만큼 LOOP 시작이 늦는 것은 의도.
- 월드 잔류 PARTICLE Game 지원(v0.2-35.30.18)은 그대로 두되 이 package는 더 이상 사용하지 않는다.

## 5. wake 텍스처 (Claude 검수 완료)

Studio `exports/weather_wake_v1/` → Game 리소스로 byte 그대로 복사:

| 파일 | byte | sha256 앞 12자 | 측정 |
|---|---:|---|---|
| `weather_rain_wake_strip.png` 64×256 | 24092 | 1649878f87d8 | 알파 최대 0.70, 세로 이음매 0, 좌우 가장자리 투명, 가로 프로파일 가운데 0.69→양끝 0, 결 세로 방향 |
| `weather_snow_wake_strip.png` 64×256 | 29273 | aba41937d7bd | 알파 최대 0.85, 이음매 0, 입자감 있는 가루 결 |

MultiMeshInstance2D `texture_repeat` 사용(자국과 동일).

## 6. 확인·측정 (회신 11)

- 교체 전(현재: v2 판 + 월드 puff) / 후(v1 바퀴 파티클 + wake): 비·눈 평균/P95 frame, draw call, viewport GPU, wake 추가 CPU, 날씨 전환 시 타이어 VFX 동기 비용. **puff package와 wake가 동시에 발생하지 않도록** 교체 후에만 wake를 켜서 비교.
- focused: wake 발생(직선·코너), 날씨 전환 시 이전 조각 유지·소멸, 피트·정지·순간이동 끊기, 결과 화면 소멸, teardown, 용량 초과 덮어쓰기, 빈 START/END package 로드·재발동·강제 정리, 자국 폭·접점.
- 사용자 확인용 격리 실행(비·눈·맑음, 직선→코너, 20대).

## 7. 사용자 시각 승인

- 미승인. 이전 결과(얇은 자국, 둥근 덩어리)는 사용자가 거부. 이번 교체 후 격리 화면 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 2 자국 수정 → 3 wake 구현 → 4·5 전달물 교체 → 6 확인·측정 → 공통 인계 형식 보고(변경 파일, 전/후 수치, 덮어쓰기 비율).
- **사용자**: 격리 화면 녹화 → Claude.
- **Claude**: 녹화 검토 → wake·자국 수치 조정안(Game 데이터) 또는 package 수정.
- 변경하지 말 것: 자국 발생 조건, 날씨 판정·timeline, 트랙 날씨 표현, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
