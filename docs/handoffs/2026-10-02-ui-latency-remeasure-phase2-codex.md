# 팀·차고 UI 지연 — 스냅샷 수정 후 Claude 재측정 + 2단계 요청 (Claude → Codex)

2026-10-02 · 측정: Claude · 입력: Game `docs/UI_READ_SNAPSHOT_GAME_HANDOFF.md`, Studio `docs/handoffs/2026-10-02-ui-latency-get-profile-codex.md`

## 1. 재측정 (같은 조건: 경기 진행 중 뉴욕 20대, 핸들러 직접 호출 3회 중앙값, 고사양 PC, debug GL, 세이브 복사본 새로 생성)

동기 처리 ms. ③ = 사용자 세이브에서 대기 상자만 비운 것(경기 프레임 부하 제외, UI 비용만), ② = 사용자 세이브 그대로.

| 조작 | ① 새 세이브 | ③ 수정 전 → 후 | ② 수정 전 → 후 | `get_profile()` 호출(③) 전 → 후 |
|---|---:|---:|---:|---:|
| 차고 슬롯 선택(엔진) | 74 | 424 → **109** | 424 → **129** | 427 → 7 |
| 차고 부품 선택 | – | 69 → **36** | 73 → **50** | 47 → 3 |
| 장착+해제 | – | 510 → **151** | 524 → **174** | 505 → 22 |
| 부품 보관함 열기 | 41 | 323 → **98** | 349 → **107** | 307 → 1 |
| 팀 열기 | 28 | 113 → **47** | 131 → **53** | 196 → 35 |
| 라인업 스킬 버튼 | 51 | 203 → **66** | 213 → **67** | 207 → 19 |
| 라인업 마스터리·재능·능력치 | 6~15 | 15~22 → 15~19 | 16~26 → 16~21 | – |

- **스냅샷 수정으로 주요 조작 2.4~4배 단축 확인.** 스냅샷 생성 비용은 최대 1.8ms(첫 생성)로 무시 가능.
- 남은 시간은 대부분 **UI 재구성** 비용(아래). 저사양 PC에서는 여전히 수백 ms로 느껴질 수 있다.
- 차고 **첫 열기**(동기): ① 268ms / ③ 329ms / ② 431ms — 이전 측정은 중앙값만 기록해 전후 비교 불가, 2단계 대상으로 기록.

## 2. 남은 비용 분해 (③, 함수 포함 시간 ms/조작)

| 조작 | 주요 비용 |
|---|---|
| 슬롯 선택 109 | `_refresh_garage_popup_contents` 109 중 **`_refresh_garage_racer_selector` 48**(레이서가 바뀌지 않았는데 매번 재구성), **`_refresh_garage_preview_detail` 32**, `_apply_ui_fonts` 14(×3, 팝업 전체 트리 순회), 부품 카드 생성 `_garage_part_visual`+`_create_garage_part_card` 19(33+28장 매번 새로 생성) |
| 부품 선택 36 | `_refresh_garage_preview_detail` 33, `_apply_ui_fonts` 6 |
| 장착+해제 151 | `_refresh_garage_popup` 105(위와 동일 구성) + `_refresh_garage_preview_detail` 63(×2) + `_refresh_garage_part_selection_visuals` 34 + `_apply_ui_fonts` 20(×4) + `_update_progress_info_display` 13 |
| 부품 보관함 열기 98 | `_refresh_parts_inventory_popup` 111 중 `_apply_ui_fonts` 25 |

남은 `get_profile()`(깊은 복사, ③ 1회 ≈0.6ms): 팀 열기 35회(`EntrySetupPopup.gd:2680 _get_racer_level` 17, `RaceAbilityService.gd:184 get_slot_status` 9, `ProgressionService.gd:291` 4), 스킬 버튼 19회(`_get_racer_level` 13, `EntrySetupPopup.gd:4595 _get_racer_progress` 4), 장착+해제 22회(`VehicleService.gd:228 get_player_team_souvenir_stat_bonuses` 8, `ProgressionService.gd:291` 8), 슬롯 선택 7회(souvenir 6).

## 3. 2단계 요청 (우선순위 순, 동작·표시·규칙·저장 형식 변경 없음)

1. **레이서 선택기 재구성 생략**: `_refresh_garage_racer_selector()`를 레이서·로드아웃 목록이나 선택이 바뀔 때만 재구성(슬롯 선택·부품 선택·장착/해제에서는 선택 표시만 갱신). 예상 −45ms/조작.
2. **`_apply_ui_fonts` 범위 축소**: 갱신마다 팝업 전체 트리를 다시 순회하지 말고 새로 만든 노드(카드·라벨)에만 적용, 또는 갱신 1회당 1번만. 예상 −14~25ms.
3. **`_refresh_garage_preview_detail` 중복 제거**: 장착/해제 한 번에 2회 + 선택 표시 갱신에서 또 호출 → 갱신 1회당 1번. 내부 비용(약 32ms)도 확인(같은 상세를 다시 그리는지, 무거운 노드 재생성이 있는지).
4. **부품 카드 재사용**: 슬롯 선택·장착/해제 시 장착 슬롯 카드·후보 카드(33+28장)를 매번 새로 만들지 말고 instance_id 기준으로 재사용·변경 카드만 갱신(1단계 요청서 6번).
5. **남은 깊은 복사 제거**: 위 호출 위치를 1단계와 같은 UI 스냅샷으로 전환.
6. (조사) **차고 첫 열기 270~430ms**: 첫 생성 시 무엇이 비싼지(씬 인스턴스·카드·미리보기 이미지 로드) 확인 후 필요하면 미리 만들기 또는 지연 생성.

예상: 슬롯 선택·장착 등 주요 조작 약 30~60ms 수준. **부하 측정은 Claude가 한다.**

## 4. 다음

- Codex: 1~5 적용(6은 조사 결과 보고) → 공통 인계 형식 보고. 진행 중인 연구 보정치 캐시(`2026-10-02-race-frame-crate-hold-remeasure.md`)와 함께 해도 된다.
- Claude: 완료 후 경기 프레임·UI 함께 재측정.
- 변경하지 말 것: 부품·스킬·라인업 규칙, 저장 데이터 형식, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
