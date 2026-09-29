# 날씨 VFX 작업 종료 — Codex 마무리 요청 (Studio → Codex)

2026-09-30 · 작성: Claude · 대상: Game Codex

## 0. 요약

사용자가 날씨 관련 작업 전체를 **최종 승인하고 종료**했다(2026-09-30, 2차 보정 적용본 녹화 기준). 추가 외형·수치 변경은 없다. Game 쪽 **기록과 정리만** 요청한다. commit은 사용자 승인 전 하지 않는다.

승인 범위:
- 트랙 날씨(비·눈·폭염 색보정·강수 z 4000·부드러운 전환·SETUP 렌더 준비·경기 전후 날씨 유지)
- 타이어 자국(MultiMesh, 공통 접점 (±84, +160), 폭 44, 속도 하한 0.7·슬립 알파 1.2, 날씨별 색·수명)
- 비·눈 wake(2차 보정값: 비 ×1.6→×4.0 / 0.30s / α0.45, 눈 ×1.7→×3.6 / 0.36s / α0.55)
- 비·눈 package(`driving.rain_tire_spray` / `driving.snow_tire_spray` Runtime v1, 바퀴 파티클 ±84)

## 1. 요청

1. `docs/WEATHER_TRACK_GAME_HANDOFF.md`에 **사용자 최종 시각 승인(2026-09-30)**과 위 최종값을 기록. "승인 대기" 문구를 정리.
2. **`VEHICLE_FOLLOW_WORLD_TRAIL` PARTICLE 엔진 지원(v0.2-35.30.18)은 유지**한다(현재 사용하는 package 없음). 향후 효과용 기능으로 지원 범위(PARTICLE·UNDER_VEHICLE·non-bent)와 "운영 package 미사용" 상태를 문서에 명시. 제거하지 않는다.
3. 미해결로 기록: 첫 눈 전환 주변 31.25ms 프레임 1회 관측 후 재현 안 됨, 원인 미확정(워밍업 추가·해결 완료로 표시하지 않음).
4. 중간 산출물 정리: 계측 임시 결과, 폐기된 표현(월드 puff, 판 package)의 캡처·로그 중 최종 근거가 아닌 것. 최종 근거(비교 JSON, 대표 캡처 몇 장, focused 로그)만 `ui-redesign-audit/weather_trail/` 등에 남김.
5. 사용하지 않게 된 Game 리소스 확인: 이전 package가 쓰던 `weather_rain_rear_spray` / `weather_snow_rear_roost` / `weather_spray_puff` / `weather_snow_puff`, 구 `rain_tire_wake_*` / `snow_tire_mist_*` 등이 Game에 남아 있으면 다른 참조가 없는 것만 제거.
6. commit은 사용자 승인 후. 공통 인계 형식으로 정리 결과만 짧게 보고.

## 2. Studio 쪽 완료 사항 (참고)

- 사용하지 않는 타이어 텍스처 10종(+`.import`)과 미리보기 카탈로그·export 정책 항목 삭제.
- 전달용 `exports/weather_track_v1`, `weather_trail_v1`, `weather_wake_v1` 삭제(Game의 byte 동일 사본 확인 후).
- 비·눈 타이어 Studio 테스트 6개를 새 구성 기준으로 재작성: preview 715 / export contract 70 / performance 61 assertions, 실패 0.
- Studio 변경은 commit하지 않음(사용자 결정).
