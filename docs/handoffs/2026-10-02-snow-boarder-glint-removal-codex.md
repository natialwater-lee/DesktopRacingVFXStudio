# 스노우 보더 / Snow Boarder — LOOP 결정 반짝임 제거 재적용 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 이전: `docs/handoffs/2026-10-02-snow-boarder-trail-tuning-codex.md`

## 0. 요약

- 조정 적용 결과 확인: 빛줄기 청록·꼬리 145px(약 1.57배) 좋음. 사용자 녹화에서도 얼음빛 궤적으로 읽힌다. 빛줄기 수치는 그대로 확정.
- LOOP 결정 반짝임은 크기 140에서도 일반 경기 크기에서 보이지 않음(Codex 보고·Claude 녹화 확인 일치) → 합의대로 **`loop.glint_left` / `loop.glint_right` 제거**. 시작 burst 결정(`start.glints`)은 유지.
- 텍스처 3장 byte 동일(`ice_glint`는 `start.glints`가 계속 사용). 계약·코드 변경 없음, package ID·버전 동일(Package 1 / Runtime v1).
- 이전 보고의 낮 경기 종료 단계 native crash: 사용자가 같은 시점에 게임을 별도로 실행해 생긴 것으로 판단 — 추가 조사 불필요(사용자 확인).

## 1. 교체할 전달물 (Studio `exports/packages/talent.snow_boarder/`, byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 | 변경 |
|---|---:|---|---|
| `manifest.json` | 2624 | 22d62224c787 | 변경 |
| `assets/talent_snow_boarder_frost_trail.png` | 8305 | 09df9a298fa8 | 동일 |
| `assets/talent_snow_boarder_ice_glint.png` | 759 | 34e05b94841a | 동일 |
| `assets/talent_snow_boarder_powder_fan.png` | 31454 | 272d93c6819a | 동일 |
| `runtime/vfx_runtime_definition_v1.json` | 8905 | 53ed1c586ec8 | 변경 |
| `source/talent.snow_boarder.vfx.json` | 8529 | 024c5692d1ce | 변경 |

## 2. 변경 후 구성

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.powder_left` / `_right` (ALPHA), `start.glints` | 변경 없음 |
| LOOP 20s | `loop.trail_left` / `_right` (월드 잔류) | 변경 없음: 18/s max 13, 수명 0.7s, 크기 120→100, 색 곱 (0.7, 0.93, 1.0) |
| END 0.3s | (레이어 없음) | 변경 없음 |

차량당 스프라이트 LOOP 최대 32 → **26**. importance CORE 5(DETAIL 없음).

## 3. Codex 요청 작업

1. package 파일 교체, 해시 기록 갱신.
2. `loop.glint_left` / `loop.glint_right`를 참조하는 Game 테스트·probe가 있으면 정리.

## 4. 확인 요청

1. LOOP에서 빛줄기만 남고 결정이 나오지 않는지, 빛줄기 외형이 직전 적용과 동일한지.
2. **부하 측정은 하지 않아도 된다.** 2026-10-02부터 부하 체크는 Claude가 기존 `tests/vfx/manual/NightVisionGameProbe.gd`를 격리 APPDATA로 실행해 직접 한다(사용자 결정, Game 소스는 수정하지 않음). Codex는 적용·연결·외형 확인에 집중해 달라. probe 파일을 바꾸거나 옮기면 보고만 해 달라.

## 5. 검증

- Claude 실행: Studio 검증기·export(REPLACE_EXISTING), repo preset = package `source` byte 동일, Studio 테스트 갱신 — preview 436 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·테스트·성능.

## 6. 다음 담당자

- **Codex**: 3 교체 → 4 확인 → 공통 인계 형식 보고.
- **사용자**: 최종 외형 승인.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
