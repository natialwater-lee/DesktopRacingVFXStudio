# 샌드위치 탈출 / Sandwich Escape — 루프 뒤 빛줄기 제거 재적용 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 이전 인계: `docs/handoffs/2026-10-01-sandwich-escape-codex-handoff.md`

## 0. 요약

- 사용자가 Game 적용 결과(실제 경기 녹화)를 보고 **루프 중 차량 뒤 이펙트가 너무 얇고 의미 없어 보인다**며 제거를 요청했다.
- Studio에서 `loop.rear_thrust`와 이를 이어 주던 `start.rear_follow`를 제거하고, 시작 섬광 `start.thrust` 수명을 0.6s → 0.5s로 되돌렸다. 발동 순간 차 뒤 섬광 1회는 유지한다.
- 앞쪽 화살·길은 변경 없음. 텍스처 3장 byte 동일. 계약·코드 변경 없음. package ID·버전 동일(`talent.sandwich_escape`, Package 1 / Runtime v1).

## 1. 교체할 전달물 (Studio `exports/packages/talent.sandwich_escape/`, REPLACE_EXISTING 재생성 — byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 | 변경 |
|---|---:|---|---|
| `manifest.json` | 2637 | 732a7ed40f19 | 변경 |
| `assets/talent_sandwich_escape_chevron.png` | 14007 | 7aee0a45d335 | 동일 |
| `assets/talent_sandwich_escape_path.png` | 11179 | 1c9067f85d18 | 동일 |
| `assets/talent_sandwich_escape_thrust.png` | 20878 | d4bd35a224b8 | 동일 |
| `runtime/vfx_runtime_definition_v1.json` | 10564 | b333bb18359c | 변경 |
| `source/talent.sandwich_escape.vfx.json` | 10067 | 21b7ba2d9a1e | 변경 |

## 2. 변경 후 구성

| 구간 | layer | 내용 |
|---|---|---|
| START 0.4s | `start.thrust` CORE | 추진 섬광 BURST 1, offset (0, +418.3), 수명 **0.5s**, 크기 220→260 |
| | `start.chevron` CORE | 화살 BURST 1 (변경 없음) |
| | `start.chevron_follow` CORE | 화살 CONTINUOUS 5/s max 2 (변경 없음) |
| LOOP 10s | `loop.chevrons` / `loop.path_left` / `loop.path_right` CORE | 변경 없음 |
| END 0.3s | (레이어 없음) | 변경 없음 |

차량당 스프라이트: LOOP 정상 최대 9(화살 3 + 길 6), START·LOOP 렌더러 각 3. importance CORE 6(DETAIL 없음).

## 3. Codex 요청 작업

1. 위 package 파일 교체(`res://assets/vfx/packages/talent.sandwich_escape/`), catalog 해시 등 package를 참조하는 기록이 있으면 갱신.
2. 이 package의 레이어 ID(`loop.rear_thrust`, `start.rear_follow`)를 직접 참조하는 Game 코드·테스트가 있으면 정리.
3. 기존 연결(`ABILITY_PRESET_IDS`, legacy `gold_speed` 억제 — 독주와 공유)은 그대로.

## 4. 확인 요청

1. 발동 → 루프 → 종료에서 차 뒤에는 발동 순간 섬광만 보이고 루프 중에는 아무것도 남지 않는지.
2. 앞쪽 화살·길이 이전 적용과 동일하게 보이는지.

## 5. 검증

- Claude 실행: Studio 검증기·export(REPLACE_EXISTING), repo preset = package `source` byte 동일, Studio 테스트 갱신 — preview 432 / export contract 70 / performance 61 assertions 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·테스트.

## 6. 다음 담당자

- **Codex**: 3 교체 → 4 확인 → 공통 인계 형식 보고.
- **사용자**: 재적용 후 녹화로 최종 확인.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
