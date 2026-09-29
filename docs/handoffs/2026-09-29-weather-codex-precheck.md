# 트랙 날씨 효과 개선 — Codex 사전 확인 요청 (Studio → Codex)

2026-09-29 · 작성: Claude (설계·리소스 검수) · 대상: Game Codex (구현)

## 0. 먼저 읽을 것

- 설계: Studio `docs/superpowers/specs/2026-09-29-weather-track-vfx-design.md` (현재 상태 분석, 연출, 구조·부하 예산).
- 이번 작업은 **Studio package가 아니다.** Game의 `WeatherVisualController.gd` + 날씨 셰이더 + `weather_defs.json`의 `visual_profiles`를 개선하는 Game 소유 작업이다. Studio 코드·package·계약은 바뀌지 않는다.
- 이 문서와 설계는 Claude가 Game을 **읽기 전용으로 분석**해 작성했다. 코드 동작·비용에 대한 서술은 실행 검증이 아니므로 Codex가 실제 코드·실행으로 판단해 달라. 기존 GPT 작업 관례와 형식이 다를 수 있다.
- 날씨 전환 끊김은 Codex가 별도로 조사 중인 것으로 안다. 아래 3번은 그 조사와 겹치면 조사 결과를 우선한다.

## 1. 구현 전 확인해 달라는 것 (수용 가능 여부 + 대안)

1. **트랙 스프라이트에 색보정 material 직접 적용**: `TrackController.track_sprite`(AnimatedSprite2D, 4fps 프레임 교체)와 `foreground_overlay`에 같은 ShaderMaterial을 걸어 필터 덮개를 없애는 방식이 다른 기능(타이어 자국 EffectLayer, 위젯 입력 알파 캐시, 트랙 프레임 교체, 다른 곳의 track_sprite material 사용)과 충돌하지 않는지.
2. **강수 층 순서**: 강수 덮개를 차량(depth sort z, 최대 ±4096)과 foreground overlay(z 3000) 위, UI 아래에 두는 것이 가능한지. 현재 z 2(상대)가 실제로 차량 아래에 그려지는지도 확인.
3. **전환 방식**: 컨트롤러·재질을 경기 내내 유지하고 uniform 보간(색보정 1.5초, 강수 강도 페이드)으로 전환하는 구조로 바꾸는 범위. 현재 `_configure_weather_visuals`의 삭제·재생성과 `_apply_live_weather`의 다른 처리(20대 컨텍스트, 타이어 VFX 재준비)와의 관계.
4. **셰이더 사전 준비**: SETUP에서 두 셰이더(grade, precipitation)를 한 번씩 그려 준비하는 방법. 기존 Static Ribbon 준비 경로와 합칠지 별도로 둘지.
5. **아지랑이 노이즈**: FastNoiseLite(seamless)로 128×128 2채널 PNG를 오프라인으로 구워 커밋하는 방식 수용 여부.
6. 개선 전 기준값 측정 가능 여부: 같은 fixture로 평상시 frame/draw call/viewport GPU, 날씨 전환 프레임(날씨 VFX vs 차량 컨텍스트·타이어 VFX 구분).

## 2. 지금 하지 않을 것

- 아트 PNG는 GPT가 제작 중이며 Claude 검수 후 Studio `exports/weather_track_v1/`로 전달한다. 그 전에는 구현을 시작하지 않아도 된다(구조 변경 선행은 Codex 판단).
- 날씨 판정·일정·주행 효과, 타이어 VFX package, 재능, 저장 데이터는 변경 대상이 아니다.

## 3. 회신 형식

항목 1~6별로 가능 / 조건부(조건) / 불가(대안)와 예상 변경 파일만 짧게. 결과를 반영해 Claude가 최종 인계(수치·파일·검증 기준)를 작성한다.
