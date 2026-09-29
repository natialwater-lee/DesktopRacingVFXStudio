# 비·눈 타이어 VFX 교체 — Game 적용 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·검수 기록: Studio `docs/superpowers/specs/2026-09-30-weather-tire-vfx-design.md` (사전 확인 회신 반영 5장 포함).

## 0. 먼저 읽을 것

- 기존 `driving.rain_tire_spray` / `driving.snow_tire_spray`는 GPT 쪽 흐름으로 만든 package였다. 이번 교체본은 **Claude가 설계·preset 작성·package 생성**을 했다. ID는 같지만 구성이 완전히 다르다(Runtime v1 → **v2**, PARTICLE만 → **TEXTURED_SPRITE + PARTICLE**, `runtime_inputs` 없음 → **`speed_normalized`**). 기존 package 기준의 검사 기대값은 새 manifest 기준으로 바꿔야 한다.
- preset은 Claude가 생성 스크립트로 작성한 뒤 Studio 검증기·export를 통과했고, repo의 preset 파일은 package `source`와 byte 동일하게 맞췄다(Studio 직렬화 형식).
- 사전 확인 회신(2026-09-30)에 따라 **Game 연결 코드 수정은 필요 없다**는 전제로 만들었다. 실제 코드와 다르면 추측하지 말고 알려 달라.

## 1. 작업 ID / 버전

| ID | Package | Runtime | runtime_inputs | importance |
|---|---|---|---|---|
| `driving.rain_tire_spray` | 1 | **v2** | `speed_normalized` (0~1, default 0) | CORE 3 / DETAIL 1 |
| `driving.snow_tire_spray` | 1 | **v2** | `speed_normalized` (0~1, default 0) | CORE 3 / DETAIL 1 |

Game package catalog 변경 불필요(ID 기존 등록).

## 2. 전달물 (Studio 원본, byte 그대로 교체)

`C:\GodotProjects\DesktopRacingVFXStudio\exports\packages\<ID>\`

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| rain `manifest.json` | 2189 | 2ddb9bb1e396 |
| rain `assets/weather_rain_rear_spray.png` | 34046 | 143805a35892 |
| rain `assets/weather_rain_droplet.png` | 777 | 8885cceb3ba5 |
| rain `runtime/vfx_runtime_definition_v2.json` | 10889 | 6fe0be0c9c57 |
| rain `source/driving.rain_tire_spray.vfx.json` | 10260 | 4e49dc724e7c |
| snow `manifest.json` | 2185 | 1620fc93e2ca |
| snow `assets/weather_snow_rear_roost.png` | 36483 | 58f811604353 |
| snow `assets/weather_snow_chunk.png` | 1530 | 3600f98305a6 |
| snow `runtime/vfx_runtime_definition_v2.json` | 10891 | c055eef4c39f |
| snow `source/driving.snow_tire_spray.vfx.json` | 10262 | 149915d2d68e |

- 기존 `runtime/vfx_runtime_definition_v1.json`, `assets/rain_tire_wake_*.png`, `assets/snow_tire_mist_*.png`(+`.import`)는 새 package에 없다. 다른 package·테스트 참조가 없는 것만 제거(회신 5 방침).
- 새 PNG의 `.import`는 Game에서 생성.

## 3. 변경 내용 요약

각 package 동일 구조 (좌표: 차량 source px 256×512, CENTER, 전방 −Y, 뒷바퀴 ≈ (±41, +117)):

| phase | layer | 내용 |
|---|---|---|
| START 0.3s | `start.rear_spray` / `start.rear_roost` TEXTURED_SPRITE CORE | 뒷바퀴 판, 불투명도 50%, 속도 길이·불투명도 modulation |
| LOOP | `loop.rear_spray` / `loop.rear_roost` TEXTURED_SPRITE CORE | 판 위쪽 끝을 뒷바퀴 축에 고정(`modulation_pivot_local` [0,−90]). `speed_normalized` 0.15→0.85 ⇒ 길이 ×0.45→1.0, 0.10→0.60 ⇒ 불투명도 ×0→1. OSCILLATOR(비 3.1Hz / 눈 2.3Hz): 폭 ×0.94~1.06, 회전 ±1.5°, 불투명도 ×0.85~1.0. `modulation_clamps`로 scale X/Y 제한 |
| | `loop.droplets` / `loop.chunks` PARTICLE DETAIL | 차 뒤끝(y +225) BOX 90×10. 비: 최대 3, 수명 0.30s, 뒤로 480~680. 눈: 최대 4, 수명 0.50s, 뒤·옆 ±55°로 220~340, 회전. `modulations`·`modulation_clamps` 빈 배열 |
| END 0.4s | `end.rear_spray` / `end.rear_roost` TEXTURED_SPRITE CORE | 판 불투명도 40%, 속도 modulation. 남은 파티클은 자연 소진 |

- 전 레이어 `ALPHA`, `UNDER_VEHICLE`, `VEHICLE_LOCAL`, anchor `CENTER` 1개.
- 앞코 물보라(비)와 앞바퀴 연기(눈)는 제거. 차체 빗방울 표현은 사용자 동의로 생략.

## 4. 기존 기능 재사용 / 계약 변경

- 새 renderer·schema·계약 변경 없음. TEXTURED_SPRITE modulation(헤드라이트·슈퍼 부스터), TEXTURED_SPRITE + PARTICLE 혼합(슈퍼 부스터) 선례 그대로.
- `runtime_inputs` 계약 형식은 헤드라이트 package와 같다(`name`/`value_type`/`minimum`/`maximum`/`default`).

## 5. 확인 요청 (처음 쓰는 구성·Studio 미검증 항목)

1. **날씨 타이어 package의 첫 v2·runtime input 사용**: `WeatherTireVfxIntegrationController.prepare()`의 `resolve(..., {})` → default 0.0, 이후 `VfxService`의 차량 snapshot 갱신으로 실제 속도가 들어오는지(회신 1 전제). 발진 직후 0.0 default 한 프레임 동안 판이 투명한 것은 의도와 같다.
2. **저속 잔여**: 판은 속도 0 근처에서 사라지지만 PARTICLE(최대 3~4)은 속도와 무관하게 남는다(PARTICLE modulation 미지원). 게임 활성 조건(이동 중·정지 아님·피트 아님)에서 눈에 띄는지.
3. **phase보다 긴 수명**: LOOP 파티클(최대 0.5s)이 END(0.4s) 이후에도 소진되는지, force clear/레이스 정리 시 즉시 제거되는지.
4. **첫 방출 지연**: CONTINUOUS 파티클은 누적기 0 시작이라 LOOP 진입 후 약 0.11~0.13s 뒤 첫 입자(판이 먼저 보이므로 문제 없음 예상).
5. **기존 효과와 겹침**: 기본 부스터·슈퍼 부스터 불꽃(차 뒤), 재능 VFX(차 아래), 야간 헤드라이트(전방) — 특히 **뒤쪽 불꽃과 물보라/눈보라 겹침 순서**가 자연스러운지. 트랙 날씨 강수(z 4000)는 위에 그려진다.
6. **판독성·차종**: 실제 경기 크기에서 Hyper 외 차종(뒷바퀴 위치가 다른 차)에서도 판이 뒷바퀴 뒤에서 시작하는 것으로 보이는지. 설계는 차체 위치 정확 일치에 의존하지 않도록 판 폭을 넉넉히 잡았다.
7. **부하**: DETAIL LOD 실행 처리 없음(회신 4) → 파티클 항상 생성. 차량당 LOOP 렌더러 2개(비 2→2, 눈 4→2), 스프라이트 최대 비 1+3 / 눈 1+4.

## 6. 검증

**Claude 실행**
- PNG 4장 수치 검수(크기·알파·여백·투명부 색·시작점), 게임 크기 정지 합성 모의.
- Studio 검증기(`VfxPresetPipeline.load_and_validate`)와 export 계획 통과, package 2개 `REPLACE_EXISTING` 생성, asset byte 동일·runtime input 형식 확인.
- 사용자 Studio 녹화 2회 검토(속도 슬라이더 0→1): 1차 파티클 가림 수정(y +130 → +225), 판 흔들림 보강 후 사용자 승인.

**Claude 미실행**: Studio 전체 회귀, Game 실행·테스트·성능 측정.

**Codex 요청**
- 교체 후 관련 focused 검사(기존 타이어 VFX 통합 검사 기대값 갱신 포함).
- 새 프로세스에서 `WeatherTransitionProbe.gd`로 **교체 전/후 비·눈 전환 비용**(최초·반복)과 평상시 frame/draw/viewport GPU 비교. 트랙 표현·차량 컨텍스트·타이어 VFX 구분.
- 사용자 확인용 격리 실행 방법(비·눈 경기, 20대).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-09-30).
- Game 실제 경기 외형: 미승인. Codex 적용 후 사용자가 확인.

## 8. 다음 담당자

- **Codex**: 2 교체·구 리소스 정리 → 5 확인 → 6 검사·측정 → 공통 인계 형식 보고. 외형 수정이 필요하면 package를 Game에서 고치지 말고 현상을 Studio(Claude)로.
- **사용자**: Game 경기 녹화로 최종 확인, Studio 변경분 커밋.
- 변경하지 말 것: 트랙 날씨 표현(승인 완료), 날씨 판정·timeline, 재능 VFX, 저장 데이터. 승인 없는 commit 금지.
