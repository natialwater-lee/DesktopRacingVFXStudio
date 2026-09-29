# 물보라 띠(wake) + 뒷바퀴 접점·자국 굵기 수정 — Codex 사전 확인 요청 (Studio → Codex)

2026-09-30 · 작성: Claude (설계·리소스 검수) · 대상: Game Codex

## 0. 먼저 읽을 것

- 설계: Studio `docs/superpowers/specs/2026-09-30-weather-wake-and-contacts-design.md`.
- 사용자 피드백(2026-09-30 격리 녹화 검토): ① 타이어 자국이 실제 타이어 폭보다 너무 얇다, ② 차 중앙에서 뒤로 **둥근 덩어리**가 떨어지는 느낌 — 비·눈에서 그렇게 생기지 않는다.
- **근본 원인은 Claude가 정한 뒷바퀴 접점 (±41, +117)이 틀린 것**이다(예전 preset 값을 스프라이트 확인 없이 사용). 12종 스프라이트로 다시 측정한 값을 설계 2장에 넣었다. Codex 구현 자체의 결함이 아니다.
- 이번 요청은 Claude가 Game을 **읽기 전용으로 분석**해 작성했다. 실제 코드와 충돌하면 추측하지 말고 알려 달라. 이전 GPT 흐름의 관례와 다를 수 있다.
- 현재 적용된 월드 잔류 package와 타이어 자국은 새 버전이 준비될 때까지 그대로 둔다.

## 1. 타이어 자국 수정 (데이터 중심)

1. `rear_contacts_source_px` 기본값 (±41,117) → **(±88,155)**, `vehicle_overrides`에 12종 값(설계 2장 표). override 키를 무엇으로 할지(스프라이트 ID `car_a`…`car_l` 권장, 실제 차량 식별 방식에 맞게).
2. 새 키 `mark_width_source_px` 36(car_f 44, override 가능). 사각형 폭 = 표시 폭 × 32/18(텍스처 띠 18/32px), `repeat_length_px` ≈20. 현재 폭 계산(`2 × width_multiplier`)과 슬립 폭 배율의 관계.

## 2. 물보라 띠(wake) — 자국 엔진 재사용

3. C의 MultiMesh 리본 엔진(연속 획·누적 거리 UV·셰이더 감쇠)을 **두 번째 레이어(물보라 띠)**로 재사용하는 범위: 별도 MultiMeshInstance2D + 셰이더(폭 증가·페이드 인/아웃) 또는 같은 레이어의 타입 분기 중 권장안.
4. 발생: 날씨 비·눈 + `is_weather_tire_visual_active()`일 때 **직선 포함 상시**, 바퀴별 0.05s 간격. 자국 발생(코너·슬립·0.08s)과 독립. 호출 위치(차량 측 `_update_visual_effects` 근처)와 비용.
5. 셰이더 폭 증가: 인스턴스 custom data(생성 시각·수명·시작 폭·끝 배율)로 수명에 따라 가로 폭 ×3~3.5 smoothstep, 알파 0.05s 페이드 인 + 끝 40% 페이드 아웃. `speed_normalized`를 생성 시점 값으로 슬롯에 저장해 알파·끝 폭에 반영(설계 4장 표).
6. 그리는 순서 트랙 → 자국 → **물보라 띠** → 차량(기존 월드 host 평면)에서 가능한지.
7. 용량: 20대 × 2바퀴 × (0.5~0.7s / 0.05s) ≈ 400~560 → 링 버퍼 용량 제안(예: 1,024)과 초과 정책.
8. 날씨 전환 시: 새 조각부터 새 날씨 색·텍스처, 이미 깔린 조각은 원래 표현으로 소멸(자국과 동일). 비↔눈 두 텍스처를 한 MultiMesh로 처리할지(텍스처 배열/아틀라스) 날씨별 인스턴스 2개로 할지.

## 3. Studio package 정리 관련

9. 두 package에서 월드 잔류 puff 레이어와 차 중앙 판을 빼고, 두 뒷바퀴 접점의 작은 VEHICLE_LOCAL 파티클(좌·우 레이어)만 남길 예정. **START/END phase에 레이어가 0개**인 package를 Game이 허용하는지(불가하면 짧은 BURST 1회로 채움).
10. 파티클만 남으면 `speed_normalized` 입력·modulation이 없어진다 → Runtime v1로 내려가도 기존 연결(`WeatherTireVfxIntegrationController`)에 문제가 없는지.

## 4. 측정

11. 현재(월드 조각) 대비 교체 후: 비·눈 평균/P95 frame, draw call, viewport GPU, 띠 추가 CPU. 기존 `WeatherTransitionProbe.gd` 재사용.

## 5. 회신 형식

항목 1~11별로 가능 / 조건부(조건) / 불가(대안)와 예상 변경 파일만 짧게.
