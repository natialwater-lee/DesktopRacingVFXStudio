# 경기 프레임 — 상자 보류 수정 후 Claude 재측정 + 남은 1건 (Claude → Codex)

2026-10-02 · 측정: Claude · 입력: Game `docs/RACE_CRATE_HOLD_GAME_HANDOFF.md`, Studio `docs/handoffs/2026-10-02-race-frame-crate-hold-codex.md`

## 1. 재측정 (같은 조건: 뉴욕 20대, 날씨 none, 재능 0, debug GL, 경기 21~29초, 고사양 PC, 격리 APPDATA, 세이브 복사본 새로 생성)

| 세이브 | 수정 전 | 수정 후 | `_process_race_crate_hud` | `get_profile()`/프레임 |
|---|---:|---:|---:|---:|
| ① 새 세이브 | 7.0ms | **7.1ms** | – | 0.00 |
| ② 사용자 세이브(대기 상자 11, 부품 102/100) | 36.5ms | **8.7ms / 8.6ms**(2회) | 15.3 → **2.2ms** | 15.2 → **0.01~0.02** |
| ③ ② − 대기 상자 | 7.3ms | **7.2ms** | – | 0.00 |

- 수정 효과 확인: ② 프레임 **약 4.2배 개선**, 깊은 복사 사실상 제거, 보류 판정 캐시 정상 동작.

## 2. 남은 1건 — 연구 보정치 매 프레임 재계산 (② 기준 프레임당 2.2ms)

- `_process_crate_auto_open` → 대기 상자 head마다 `_get_crate_auto_open_seconds()`(22182)를 프레임당 2회 호출(타이머가 없을 때 + `max_seconds`) → `_get_team_research_crate_modifier` → `_get_team_research_modifiers()`(→ `ResearchService.get_team_research_modifiers()`)가 **연구 보정치 전체를 매번 다시 계산**. 1회 0.73ms × 프레임당 3회 = **2.2ms**.
- 대기 상자가 있는 동안 계속 발생(새 세이브·상자 없음에서는 0). 고사양 2.2ms → 저사양에서는 수 ms.

### 요청

1. `ResearchService.get_team_research_modifiers()` 결과를 `SaveService.get_profile_read_revision()`(이번에 추가된 조회 세대) 기준으로 캐시(연구 레벨·관련 정의가 바뀌면 무효화). 반환 시 호출자 수정 위험이 있으면 기존처럼 복사하되, 계산만 1회로.
2. 또는 최소한 `_process_crate_auto_open`에서 프레임당 `_get_crate_auto_open_seconds()`를 1회만 계산해 head 루프에서 재사용.
3. 같은 `_get_team_research_modifiers()`를 쓰는 다른 경로(RaceManager 내 12곳)도 1번 캐시로 함께 혜택.

예상: ② 8.7 → 약 7ms(새 세이브 수준). 규칙·표시·저장 형식 변경 없음. **부하 측정은 Claude가 한다.**

## 3. 다음

- Codex: UI 지연 요청서(`2026-10-02-ui-latency-get-profile-codex.md`) 작업과 함께 2의 1(또는 2) 적용 → 공통 인계 형식 보고.
- Claude: 완료 후 경기 프레임·UI 조작 지연 함께 재측정.

## 4. 연구 보정치 캐시 적용 후 최종 재측정 (2026-10-02)

| 세이브 | 최초 | 상자 보류 수정 후 | 연구 캐시 후 |
|---|---:|---:|---:|
| ① 새 세이브 | 7.0ms | 7.1ms | **6.94ms** |
| ② 사용자 세이브 | 36.5ms | 8.7ms | **7.02 / 7.05ms**(2회) |
| ③ ② − 대기 상자 | 7.3ms | 7.2ms | **7.12ms** |

- ② `_process_race_crate_hud` 15.3 → 2.2 → **0.09ms/프레임**, RaceManager `_process` 20.7 → **1.1ms**(새 세이브 1.0ms와 동일). 경기 프레임 저하 건 **해결**(세이브 크기와 무관).
