# 팀·차고 UI 조작 지연 — 세이브 전체 깊은 복사 반복 (Claude 부하 분석 → Codex 수정 요청)

2026-10-02 · 분석: Claude (Game 소스 수정 없음, 측정 스크립트만 외부에서 실행) · 대상: Game Codex
관련: `docs/handoffs/2026-10-02-race-frame-crate-hold-codex.md`(경기 프레임, 같은 근본 원인)

## 0. 사용자 증상

오래 플레이한 세이브에서 부품 선택·장착, 팀 > 라인업의 재능·스킬 버튼 등 **메뉴 이동·항목 선택 전반이 느리다.** 새 세이브에서는 빠르다. 저사양 PC에서 확연.

## 1. 측정 방법

- 경기 진행 중(방치형 — 실제 사용 상황) 고정 경기(뉴욕 20대, `NightVisionGameProbe.ProbeManager` 재사용)에서 Claude 측정 스크립트가 UI 핸들러를 직접 호출. 조작별 3회 중앙값: **동기 처리 시간**, 그 후 2프레임까지 시간, `SaveService.get_profile()` 호출 수·비용·호출 위치.
- 세이브: ① 새 세이브(부품 0) ② 사용자 세이브(부품 102·아이템 140, 프로필 175KB, 대기 상자 있음) ③ ②에서 대기 상자만 비움(경기 프레임 부하 제외). 고사양 PC(Ryzen 7 9800X3D), debug.

## 2. 결과 (동기 처리 ms · get_profile 호출 수)

| 조작 | ① 새 세이브 | ③ 사용자 세이브(상자 제외) | ② 사용자 세이브 |
|---|---:|---:|---:|
| 차고 슬롯 선택(엔진) `_on_garage_slot_selected` | 73 · 54 | **424 · 427** | 424 · 485 |
| 차고 부품 선택 `_on_garage_part_selected` | – | 69 · 47 | 73 · 101 |
| 장착+해제 `_on_garage_equip_pressed`/`_unequip` | – | **510 · 505** | 524 · 567 |
| 부품 보관함 열기 `_open_parts_inventory_popup` | 39 · 8 | **323 · 307** | 349 · 362 |
| 팀 열기 `_open_entry_setup_popup` | 28 · 136 | **113 · 196** | 131 · 267 |
| 라인업 스킬 버튼 `_on_skill_button_pressed(0)` | 55 · 197 | **203 · 207** | 213 · 244 |
| 라인업 마스터리·재능·능력치 버튼 | 5~14 | 15~22 | 16~26 |

- `get_profile()` 1회 = **0.55ms**(사용자 세이브, 고사양) vs 0.03ms(새 세이브). 위 조작 시간의 **약 55%가 깊은 복사**(예: 슬롯 선택 424ms 중 236ms). 나머지는 카드 UI 재구성.
- ②는 경기 프레임 자체가 35ms라 조작 후 화면 반영까지 추가로 느리다(상자 건 수정 시 해소).
- 저사양 PC에서는 같은 조작이 수 배(체감 0.5~1.5초 이상)로 늘어날 것으로 본다.

## 3. 원인 — 호출 위치 (③ 기준, 조작 1회당 호출 수)

| 조작 | 상위 호출 위치 |
|---|---|
| 슬롯 선택 / 장착·해제 | `RaceManager.gd:14570 _get_racer_equipped_parts` **228~247회** ← `_get_pending_part_records()`(14628)가 **부품 카드마다**(12166, 14319, 14676 ×2, 14713, 14749, 14769) 호출되고, 그 안에서 플레이어 라인업 레이서마다 `_get_racer_equipped_parts` → `get_profile()`. 부품 수 × 레이서 수 × 프로필 크기. 그 외 `_find_owned_part_by_instance_id`(12881) 47~70회, `_get_owned_racer_level`(14534)·`_get_owned_vehicle`(14485)·`_get_player_racer_progress_info`(14541)·`_get_player_entry_rows`(14436) 각 30~37회 |
| 부품 보관함 열기 | `_get_racer_equipped_parts` **306회**(부품 102 × 3, 같은 `_get_pending_part_records` 경로) |
| 팀 열기 | `VehicleService.gd:935 _get_profile` 97회, `SkillService.gd:572 _get_profile` 85회 |
| 라인업 스킬 버튼 | `SkillService.gd:572 _get_profile` **213회**(스킬 노드마다 조회: 185/214/249/396/432/473행) |

공통 근본 원인: `SaveService.get_profile()`이 매번 `_profile.duplicate(true)`(175KB 전체 깊은 복사)이고, 읽기만 하는 조회가 루프 안에서 반복 호출된다.

## 4. 개선안 (Codex 수정 요청)

동작·표시·저장 형식은 바꾸지 말 것. 우선순위 순.

1. **읽기 전용 프로필 접근 도입**(경기 프레임 요청서 4-2와 동일): `SaveService`에 복사 없는 읽기 전용 접근(예: `peek_profile()` — 호출자 수정 금지를 주석·테스트로 명시) 또는 좁은 getter(`get_racer_equipped_parts(racer_id)`, `get_owned_part(instance_id)`, `get_racer_level(id)`, `get_owned_vehicle(id)`, `get_skill_levels(racer_id)` 등). 수정 목적 호출자는 기존 `get_profile()` 유지.
2. **조작 1회 = 프로필 조회 1회**: 핸들러(`_on_garage_slot_selected`, 장착/해제, `_open_parts_inventory_popup`, 팀 열기, 스킬 팝업) 시작 시 프로필 스냅샷을 한 번 얻어 하위 함수에 넘기거나, 프레임 단위 캐시(같은 `save_revision` 동안 재사용, 저장/변경 시 무효화).
3. **`_get_pending_part_records()` 1회 계산**: 카드마다 다시 계산하지 말고 갱신 1회당 한 번 계산해 카드 생성 루프에서 재사용(현재 카드 1장당 최대 6회 호출 경로).
4. **`_find_owned_part_by_instance_id`**: instance_id → part 인덱스 딕셔너리를 갱신 1회당 한 번 만들어 조회(현재 매번 복사 + 선형 탐색 + 결과 깊은 복사).
5. **SkillService·VehicleService**: 노드/차량마다 `_get_profile()` 대신 호출 단위로 한 번 받은 프로필을 재사용.
6. (2단계, 측정 후 판단) 슬롯 선택·장착 시 부품 카드 전체 재생성 대신 변경 카드만 갱신 — 1~5 적용 후 남는 시간(현재 약 185ms)을 Claude가 다시 측정해 필요성 판단.

예상: 1~5로 각 조작 시간 약 절반 이하(슬롯 선택 424 → 약 190ms 이하, 스킬 버튼 203 → 약 90ms 이하), 깊은 복사 비용은 세이브 크기와 무관해짐.

## 5. 검증 계획

- Codex: 차고 장착/해제/대기(Pending) 표시, 부품 보관함, 팀·라인업·스킬 팝업 기존 테스트, 읽기 전용 접근으로 받은 딕셔너리를 수정하는 호출자가 없는지 확인(가능하면 debug에서 read-only 검증). **부하 측정은 하지 않아도 된다.**
- Claude: 수정 후 같은 스크립트로 ①②③ 재측정·전후 비교 보고, 6번 필요성 판단.

## 6. 다음 담당자

- **Codex**: 경기 프레임 요청서와 함께 1~5 수정(1번은 공통) → 공통 인계 형식 보고.
- **Claude**: 재측정.
- 변경하지 말 것: 부품·스킬·라인업 규칙, 저장 데이터 형식, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
