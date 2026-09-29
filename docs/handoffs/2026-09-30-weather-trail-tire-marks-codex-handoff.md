# 물보라 월드 잔류(B) + 타이어 자국 개선(C) — Game 구현 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (설계·리소스 검수) · 대상: Game Codex · 공통 인계 형식

설계와 확정 사항: Studio `docs/superpowers/specs/2026-09-30-weather-trail-and-tire-marks-design.md` (특히 **4-1 확정 사항**).

## 0. 먼저 읽을 것

- 이 인계는 사전 확인 회신(2026-09-30, 항목 1~12 조건부 수용)을 반영했다. 회신의 선결사항(월드 그리기 순서, 뒷바퀴 접점, 자국 용량 정책, 입자 단위)을 아래에서 확정한다.
- 설계·수치는 Claude가 Game을 **읽기 전용으로 분석**하고 회신을 근거로 정했다. 실제 코드와 충돌하면 추측하지 말고 사용자에게 확인한다. 이전 GPT 흐름의 관례와 다를 수 있다.
- **이번 Codex 작업은 두 가지 엔진 작업**이다. 아트 3장은 **검수 완료(2026-09-30)** — Studio `exports/weather_trail_v1/`: `tire_mark_strip.png`(7009B, sha256 776e355a7c20), `weather_spray_puff.png`(17932B, acf699cbe44b), `weather_snow_puff.png`(19599B, ec1eca5501e7). C는 `tire_mark_strip.png`를 byte 그대로 Game 리소스로 복사해 사용(import repeat 켜기, 위·아래 여백 없는 세로 반복 텍스처). 두 puff는 B 지원 후 Claude가 비·눈 package에 넣어 전달하므로 Game에 따로 복사하지 않아도 된다(B 검사용 임시 사용은 가능).
- 비·눈 package 갱신(월드 잔류 레이어 추가, 판 단축)은 **Claude가 Studio에서** 하고, Game의 B 지원이 끝난 뒤 package로 전달한다. 현재 적용된 v2 package는 그때까지 유지.

## 1. B — `VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE 지원

- 범위: PARTICLE 레이어에 한해 허용(다른 type은 계속 명시 거부). Runtime v2 유지, Loader 변경 불필요(회신 4). 지원 Game 버전을 결과 인계에 기록.
- **단위(중복 배율 금지)**: package의 PARTICLE `transform.offset`, 이미터 크기, `speed_*`, `acceleration`, `size_*`는 모두 **차량 source px(256×512)**. 생성 순간 1회 차량 유효 변환(위치·회전·게임 배율)으로 위치·속도 벡터·가속도 벡터·크기·회전을 월드 host 좌표로 변환한다. 이후 차량 변환·배율을 다시 곱하지 않는다. 방향 0°는 생성 순간의 차량 −Y.
- **그리기 순서**: 트랙 표면(색보정) → 타이어 자국 → **월드 잔류 조각** → 차량 → foreground 3000 → 트랙 강수 4000 → 이름표 4095 → HUD 4096. 월드 host는 TrackController 아래, 타이어 자국 레이어 바로 위.
- 수명: 효과 인스턴스가 월드 노드를 소유. STOP→END→DRAINING에서 월드 조각이 수명대로 소진된 뒤 `is_drained`. force clear·차량 제거·레이스 정리·트랙 교체 시 즉시 제거(회신 2).
- 같은 인스턴스에 `VEHICLE_LOCAL` 레이어와 혼합 가능(레이어별 host 분기, 수명 공동 관리 — 회신 3).
- 예상 파일(회신 1): `VfxRendererFactory.gd`, `VfxEffectInstance.gd`, `VfxRenderContext.gd`, `VfxService.gd`, 두 Particle renderer + 지원/거부·lifecycle 검사.

## 2. C — `TireMarkLayer` 재작성

### 2-1. 유지

- 발생 조건: 코너 구간 또는 슬립, 유효 속도 ≥ 코너 속도 × 0.55, 0.08s 간격, `runtime_suppress_tire_marks`(회신 11).
- 공개 메서드 이름·호환 호출(`add_tire_mark`, `clear_marks`, `get_mark_count`). 연결 조각에 필요한 차량 식별 정보는 인자 추가로(회신 6).
- 슬립 폭·알파 배율(`slip_tire_mark_*`).

### 2-2. 형태

- **뒷바퀴 접점**: 차량 source 캔버스 기준 **(±41, +117) px**(= ±0.16 × 폭, +0.23 × 높이). 비·눈 타이어 package의 판 기준점과 같다. 차종별 보정은 선택적 설정 override(없으면 공통값). `REAR_CENTER (0,220)` 사용 안 함. 실제 CarSprite 변환(슬립 회전 포함)으로 월드 접점 계산(회신 7).
- **연속 획**: 바퀴별로 레이어가 보관한 직전 접점 → 현재 접점을 잇는 조각 1개(바퀴당). 폭 = 현재 2px × width_multiplier 기준(화면에서 약 2~3px), 텍스처 V 좌표는 누적 거리로 이어 붙임.
- **획 끊기**: 발생 조건이 꺼진 뒤 다시 켜질 때, 피트 진입·출구, 순간이동, 직전 접점과 거리 > 예상 조각 길이 × 3.

### 2-3. 날씨별 (생성 시점 날씨로 슬롯에 고정 — 회신 9)

| 날씨 | 색 RGB | 알파(× strength × slip) | 수명 | 비고 |
|---|---|---:|---:|---|
| 맑음 | 0.04, 0.035, 0.03 | 0.35 | 6s | 고무 |
| 폭염 | 0.04, 0.035, 0.03 | 0.45 | 7s | 진한 고무 |
| 비 | 0.02, 0.03, 0.05 | 0.30 | 3s | 텍스처 결(RGB)을 약한 밝은 광택(+0.15)으로 더해 번들거림 |
| 눈 | 0.78, 0.80, 0.84 | 0.28 | 5s | 진눈깨비 |

- 감쇠: 수명의 마지막 40% 구간에서 α → 0(smoothstep).
- 값은 데이터로 조정 가능하게(위치는 Codex 판단, 예: `weather_defs.json`의 새 키).

### 2-4. 렌더링·용량·시계

- **MultiMeshInstance2D 1개** + 자국 셰이더. 인스턴스: 변환(조각 시작~끝, 폭), 색, custom data(생성 시각, 수명, 강도). 추가는 링 버퍼 1칸 갱신.
- **용량 2,048**. 가득 차면 가장 오래된 조각부터 덮어씀. probe에서 "α > 0.3인 조각을 덮어쓴 비율"을 기록하고 5%를 넘으면 **수명을 줄여** 맞춘다(용량 증가 대신). 이 결과를 인계에 기록.
- **감쇠 시계**: 명시적 시각 효과 누적 시계 uniform 1개(회신 8). 배속·일시정지 정책은 경기와 동일, 결과 화면에서도 계속 감쇠, 실제 teardown에서 초기화. 트랙 날씨 표현의 결과 화면 유지 규칙과 일관.
- `clear_marks()`·트랙 교체·레이스 정리: `visible_instance_count = 0` + 직전 접점 맵 초기화.
- 텍스처: 도착 전 임시(흰 사각형 + 가장자리 α)로 구현. 최종 `tire_mark_strip.png`(32×128, 세로 반복, 흰색 기반 α)는 import repeat 켜기.

## 3. 측정·확인 (회신 5·10·12)

- 기존 probe에서 `visual_delta_px`로 **직선·코너 차량 화면 속도(px/s)** 측정 → 결과 인계에 기록(Claude가 월드 잔류 조각 수명·크기 확정에 사용).
- 전/후 같은 조건(20대, 코너 포함, 맑음·비·눈): 평균/P95 frame, 자국 CPU(추가·그리기), draw call, viewport GPU, 자국 점유·덮어쓰기 수.
- focused: 획 끊기 사례(비발생 틈·피트·순간이동), 날씨 전환 중 기존 자국 색 유지, 결과 화면 감쇠 지속, teardown 초기화, B의 지원/거부·소진·강제 정리·혼합 레이어.
- 사용자 확인용 격리 실행: 고정 트랙·맑음/비/눈·20대(직선→코너, 저속·피트 포함). Studio preview(차량 정지)와 구분.

## 4. 사용자 시각 승인

- 미승인. B는 Claude의 package 갱신 후, C는 Codex 구현 후 격리 화면 녹화로 확인.

## 5. 다음 담당자

- **Codex**: 1·2 구현 → 3 측정·검사 → 결과 인계(변경 파일, 지원 Game 버전, 차량 화면 속도, 전/후 수치, 덮어쓰기 비율).
- **Claude**: GPT 3장 검수 → `exports/weather_trail_v1/` 전달, B 지원 확인 후 비·눈 package 갱신(REPLACE).
- **사용자**: GPT에 아트 요청 전달, 격리 화면 녹화.
- 변경하지 말 것: 자국 발생 조건, 날씨 판정·timeline, 트랙 날씨 표현, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
