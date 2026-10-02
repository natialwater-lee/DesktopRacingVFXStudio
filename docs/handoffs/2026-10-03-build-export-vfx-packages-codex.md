# 빌드(export)에 VFX package 원본 파일이 빠질 위험 — 확인·수정 요청 (Claude → Codex)

2026-10-03 · 확인: Claude (Game 읽기 전용) · 대상: Game Codex

## 0. 배경

사용자: 다음에 낮은 사양 PC에서 **빌드로** 실행해 최적화를 다시 볼 예정 — 지금 작업들이 빌드에 모두 포함되는지 질문.

## 1. 확인한 사실 (읽기 전용)

- `export_presets.cfg` preset.0 "Windows Desktop": `export_filter="all_resources"`, `include_filter`는 `main.tscn, data/*.json, data/**/*.json, *.csv, **/*.csv, …, assets/vfx/packages/talent.solo_run.curve_flow_candidate/**/*.json, …/manifest.json, …/assets/*.png, *.mp4, addons/gde_gozen/…`.
- `scripts/vfx/VfxPackageLoader.gd`는 package 파일을 **`FileAccess.get_file_as_bytes`로 원본 바이트를 읽고 sha256을 검사**한다(245·877·881행).
- 현재 `res://assets/vfx/packages/` 아래 package 25개(재능 16, 주행·장비 9). 이 중 include_filter에 원본(json·png)이 명시된 것은 `talent.solo_run.curve_flow_candidate`뿐.
- Godot export의 `all_resources`는 PNG를 **import된 형태(.ctex)** 로만 넣고 원본 `.png` 바이트는 넣지 않으며, import 대상이 아닌 `.json`은 include_filter에 없으면 넣지 않는다(일반 동작 — 이 프로젝트의 실제 결과는 미확인).
- → **빌드에서 `manifest.json`·`runtime/*.json`·`source/*.json`·원본 PNG가 빠져 package 로딩이 실패하고 VFX가 legacy로 대체되거나 표시되지 않을 위험.** 날씨 타일(`exports/weather_*`에서 도입된 텍스처)·기타 원본 바이트를 읽는 자원도 같은지 확인 필요.
- 최근 빌드 산출물: `builds/windows/DesktopIdleRacing_0.2.35.30.9.*`(이후 VFX 작업 다수 반영 전).

## 2. Codex 요청 작업

1. 임시 경로로 test export(예: `%TEMP%`)를 만들어 **실제 pck에 package 원본 파일이 들어가는지** 확인(Godot `--export-pack`/`--export-release` 결과의 파일 목록 또는 빌드 실행 로그의 package 로딩 결과).
2. 빠져 있으면 `include_filter`에 `assets/vfx/packages/**`(json·png 원본 포함) 추가. 원본 바이트를 읽는 다른 자원(날씨·tire mark·wake 등)도 같은 방식으로 점검.
3. 빌드 실행에서 package 로딩 실패가 없는지(로그), 재능 VFX·날씨·부스터가 에디터 실행과 같게 보이는지 확인.
4. 이번 세션 성능 변경(상자 보류 캐시, UI 읽기 스냅샷, 차고 카드 재사용·점진 미리보기, SETUP 그림자 준비·조기 UI 표시)은 코드라 export에 포함됨 — 빌드에서도 SETUP 준비가 동작하는지(필요 자원이 pck에 있는지) 함께 확인.

## 3. 다음

- Codex: 1~3 확인·수정 → 공통 인계 형식 보고(빌드 산출물 commit 금지, 승인 없는 commit 금지).
- 사용자: 이후 저사양 PC에서 빌드 실행 → 시작 시간·경기 프레임 체감 → Claude가 측정 스크립트로 비교 가능한 범위 안내.
