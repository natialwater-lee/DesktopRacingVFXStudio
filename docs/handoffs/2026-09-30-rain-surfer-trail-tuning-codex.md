# 레인 서퍼 — 빛줄기 보정 package (Studio → Codex)

2026-09-30 · 작성: Claude · 대상: Game Codex · 선행: `2026-09-30-rain-surfer-codex-handoff.md`, Game `docs/RAIN_SURFER_GAME_HANDOFF.md`

## 1. 배경

Codex 실측(조각 전체 길이 9.8~11.1 화면 px, 직선 발생 간격 10.9~18.2px)과 사용자 경기 녹화 검토 결과: 하부 네온은 좋음, **빛줄기가 가늘고 옅으며 직선에서 끊긴 조각으로 보임**. 고정 배율 0.095 가정 대신 Codex 실측값으로 다시 계산했다.

## 2. 변경 (빛줄기 레이어 `loop.trail_left` / `loop.trail_right`만)

| 항목 | 이전 | 변경 |
|---|---|---|
| 크기(half extent, source px) | 70 → 60 | **120 → 100** (전체 길이 실측 환산 ≈17~19px → 14~16px, 심 굵기 ≈2배) |
| 발생 | 16/s | **18/s** (직선 간격 실측 환산 ≈9.7~16.2px → 조각 길이보다 짧음) |
| 수명 | 0.40s | **0.45s** (꼬리 ≈90px 직선) |
| max_particles | 7 | **9** |
| alpha_start | 0.85 | **1.0** |

그 외 레이어·리소스·ID·Runtime 버전 동일. 차량당 빛줄기 스프라이트 최대 14 → 18.

## 3. 전달물 (byte 그대로 교체, PNG 4장은 변경 없음)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 3046 | eebea8927556 |
| `runtime/vfx_runtime_definition_v1.json` | 10563 | a1225971a59a |
| `source/talent.rain_surfer.vfx.json` | 10148 | dc2a83a42d68 |

## 4. 확인 요청

- 직선·코너에서 조각 길이 대비 간격 재측정(연속 선으로 보이는지), 실제 조각 길이·굵기.
- 정지·저속 시 같은 자리에 겹친 조각(최대 9)의 밝기 — 이전 6개보다 밝아질 수 있음. 과하면 알려 달라(알파·수명 조정).
- 8대 동시 draw call·frame(빛줄기 스프라이트 +4/대).
- 공통 인계 형식으로 짧게 보고, 승인 없는 commit 금지.

검증: Studio 검증기·export·preview 테스트(418 assertions, 실패 0) 통과. Game 실행은 Claude 미실행.
