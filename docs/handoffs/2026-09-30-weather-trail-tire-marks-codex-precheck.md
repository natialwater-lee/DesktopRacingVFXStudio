# 물보라 월드 잔류(B) + 타이어 자국 개선(C) — Codex 사전 확인 요청 (Studio → Codex)

2026-09-30 · 작성: Claude (설계·리소스 검수, Studio) · 대상: Game Codex

## 0. 먼저 읽을 것

- 설계: Studio `docs/superpowers/specs/2026-09-30-weather-trail-and-tire-marks-design.md`.
- 사용자 요구: (1) 폭우·폭설에서 차 뒤 물보라·눈보라가 자연스럽게 **월드에 남아** 주행선을 따라 휘며 사라질 것, (2) Codex가 만든 **코너 타이어 자국**의 품질 향상 + 부하 감소 + 날씨별 표현. 두 작업을 함께 진행한다.
- 이 요청과 설계는 Claude가 Game을 **읽기 전용으로 분석**해 작성했다. 코드 동작·비용 서술은 실행 검증이 아니다. 이전 GPT 흐름의 관례와 다를 수 있으니 실제 코드 기준으로 판단해 달라.
- 방금 적용된 비·눈 타이어 package(`driving.rain_tire_spray`/`driving.snow_tire_spray`, Runtime v2)는 이 작업이 끝날 때까지 **그대로 유지**한다.
- 아직 구현·아트 제작 전이다. Game 확장이 포함되므로 수용 범위를 먼저 확인한다.

## 1. B — `VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE 지원

Studio 계약에는 이미 정의되어 있다(생성 순간 차량 변환으로 월드 좌표를 한 번 캡처, 이후 차량을 따라가지 않음 — `VFX_EXPORT_PACKAGE_V1.md` 좌표 절, Studio preview `vfx_particle_layer_renderer.gd`). Game은 `VfxRendererFactory.preflight_layer`에서 `unsupported_space_mode`로 거부한다.

1. PARTICLE에 한해 이 space를 지원하는 범위: loader/preflight 허용, 월드 컨테이너(트랙 아래·타이어 자국 위·차량 아래) 위치, 기존 CPU 호환 백엔드(스프라이트 풀) 재사용 가능 여부, 생성 시 위치·방향·속도·회전의 월드 변환, 게임 배율.
2. 수명 관리: 효과 STOP 후 월드에 남은 조각 소진(`is_drained`), force clear·레이스 정리·차량 제거 시 즉시 제거, 트랙 교체.
3. 같은 effect 안에 `VEHICLE_LOCAL` 레이어(판·보조 파티클)와 월드 잔류 PARTICLE을 섞는 것.
4. Runtime Definition 버전·capability 표시가 필요한지(계약상 새 의미가 아니라 기존 space의 구현이지만, 미지원 Game이 조용히 무시하지 않도록 거부/허용 구분 방법).
5. 차량 실제 이동 속도(월드 px/s)의 일반 주행·코너 대략 값 — 조각 수명(비 0.7~0.9s, 눈 1.0~1.3s)이 만드는 꼬리 길이를 정하기 위해.

## 2. C — `TireMarkLayer` 재작성

현재(읽기 전용 확인): 자국 1개 = 차량 **중심** ± 8px 직선 2개(`draw_line` AA), 시간 감쇠 없이 240개 FIFO, `add_tire_mark`마다 `queue_redraw`로 전체 재생성.

6. MultiMeshInstance2D 1개(텍스처 사각형, 인스턴스 변환·색·custom data=생성 시각/강도) + 셰이더 감쇠로 바꾸는 방식 수용 여부. 공개 API(`add_tire_mark`, `clear_marks`, `get_mark_count`) 유지 가능 여부.
7. 뒷바퀴 두 위치에서 **직전 기록 위치 → 현재 위치**를 잇는 연속 조각으로 그리기: 차종별 뒷바퀴 축·좌우 간격 값 출처(차량 데이터/스프라이트 폭), 바퀴별 직전 위치 보관 위치(차량 측 또는 레이어의 차량 ID 맵), 레인 변경·슬립 회전 오프셋(`_tire_slip_visual_rotation_offset_deg` 등)과의 관계.
8. 시간 기준: 셰이더 감쇠에 쓸 시계(경기 시계 vs 실제 시간), 일시정지·배속·결과 화면에서의 동작. 트랙 날씨 lifecycle(결과 화면 유지)과 일관되게.
9. 날씨별 색·수명: 자국 생성 시점 날씨로 고정(이미 남은 자국은 원래 표현으로 소멸). 날씨 ID 전달 경로.
10. 인스턴스 상한(설계 초안 1024~2048)과 현재 대비 부하 측정 방법(코너 구간 20대, `WeatherTransitionProbe.gd`/기존 계측 재사용).
11. 발생 조건(코너·슬립·속도·0.08s·억제 플래그)은 **유지**. 바꿀 필요가 보이면 이유만 알려 달라.

## 3. Studio 쪽 한계

12. Studio preview는 차량 회전만 있고 이동이 없어 월드 잔류를 판단하기 어렵다. **Game 격리 진입점**(날씨·트랙 고정, 20대, 코너 포함)으로 최종 외형을 보는 방식이 가능한지.

## 4. 지금 하지 않을 것

- 구현 착수, package 교체, 아트 제작. 날씨 판정·트랙 날씨 표현·재능 VFX·저장 데이터 변경.

## 5. 회신 형식

항목 1~12별로 가능 / 조건부(조건) / 불가(대안)와 예상 변경 파일만 짧게. 회신을 반영해 Claude가 수치·아트 요청·최종 인계를 작성한다.
