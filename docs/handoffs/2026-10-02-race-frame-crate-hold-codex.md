# 경기 프레임 저하 — 보관함 가득 참 + 대기 상자 매 프레임 재검사 (Claude 부하 분석 → Codex 수정 요청)

2026-10-02 · 분석: Claude (Game 소스 수정 없음, 측정 스크립트만 외부에서 실행) · 대상: Game Codex

## 0. 사용자 증상

- 오래 플레이한 세이브(누적 경기 1,493회)에서 경기 중 차량 주행 프레임이 확연히 낮다. 게임을 껐다 켜도 동일 → 실행 시간 누적(누수)이 아니라 **세이브 상태 의존**.
- 저장 초기화(새 세이브)로 시작하면 정상. 저사양 PC에서 확연, 고사양 PC에서도 약간 느껴짐.

## 1. 측정 방법

- 기존 `tests/vfx/manual/NightVisionGameProbe.gd`의 고정 경기(뉴욕, 20대, 날씨 none, 재능 발동 0, debug GL, 경기 21~29초 구간)를 그대로 쓰고, Claude 측정 스크립트(`%TEMP%` 외부 파일, `--script`로 실행)가 `ProbeManager`를 상속해 RaceManager 프레임 함수별 시간·`SaveService.get_profile()` 호출 수/비용·노드 수를 기록. 격리 APPDATA에 세이브만 바꿔 비교.
- 세이브: ① 새 세이브 ② 사용자 세이브 복사본(173KB, 아이템 140, 부품 102/100, 대기 상자 11) ③ ②에서 대기 상자만 비운 것.

## 2. 결과

| 세이브 | 프레임 평균 | RaceManager `_process` | `get_profile()` 호출/프레임 · 1회 비용 |
|---|---:|---:|---|
| ① 새 세이브 | **7.0ms** | 1.2ms | 2.0회 · 0.08ms |
| ② 사용자 세이브 | **36.5ms** (≈27fps) | 20.7ms | **15.2회 · 0.75ms**(= 8.4ms/프레임) |
| ③ ② − 대기 상자 | **7.3ms** | 2.5ms | 2.0회 · 0.71ms |

- GPU 시간은 모두 ≈0.05ms(CPU 병목). 노드 수 2,345 vs 2,585로 비슷, 처리 노드 종류 동일.
- ② 에서 RaceManager `set_process(false)` 시 프레임 35 → 6.95ms. 다른 노드(CarAgent 20, InventoryButtonSkin 등)를 꺼도 변화 없음.
- ② RaceManager 함수별(ms/프레임): **`_process_race_crate_hud` 15.3**(그 안 `_process_crate_auto_open` 9.4 + `_flush_race_crate_hud_refresh` 5.9), 그 외 전부 1ms 미만.

## 3. 원인

1. 사용자 세이브는 **부품 보관함이 가득 참(102/100)** → 대기 상자(부품 2·아이템 5·설계도 4)가 `blocked_by_capacity`로 열리지 못하고 남는다.
2. `_process_crate_auto_open`(매 프레임)이 타이머 0인 상자마다 `_is_crate_open_held_by_capacity` → `_get_crate_open_block_result` → `CrateService.can_open_crate_rewards(_save_service.get_profile(), …)`를 **매 프레임** 다시 계산한다. 용량 계산 안에서 `ResearchService._get_research_levels()`가 또 `get_profile()`을 부른다(호출 상위: `ResearchService.gd:334 _get_research_levels` 9.0회/프레임, `RaceManager.gd:22338 _is_crate_open_held_by_capacity` 3.5회/프레임).
3. `SaveService.get_profile()`은 매번 **`_profile.duplicate(true)`(전체 깊은 복사)** — 세이브가 커질수록 비싸다(새 세이브 0.08ms → 사용자 세이브 0.75ms, 고사양 기준. 저사양에서는 수 배).
4. `_flush_race_crate_hud_refresh`도 갱신마다 `_get_sorted_owned_crate_ids_from_counts`·`_get_shared_crate_storage_state`에서 `get_profile()` 깊은 복사 + 상자 카드별 보류 상태 재계산.
5. 대기 상자가 없으면(③) 이 경로가 빠져 정상. → "아이템·부품이 많이 쌓이면 프레임이 떨어진다"는 체감과 일치(보관함이 차서 상자가 막히는 순간부터 매 프레임 비용 발생).

## 4. 개선안 (Codex 수정 요청)

우선순위 순. 동작·규칙(상자 자동 열기 조건, 보관함 용량, 타이머 진행, 저장 시점)은 바꾸지 말 것.

1. **용량 막힘 상태 캐시**: 상자가 `blocked_by_capacity`로 보류되면 결과를 캐시하고, **보관함/용량이 바뀌는 이벤트**(아이템·부품·설계도 추가/판매/분해/합성, 연구 용량 레벨 변경, 상자 열기 성공, 세이브 로드)에서만 무효화. 이벤트 연결이 어려우면 최소 0.5~1초 간격 재검사. 보류 중 타이머는 지금처럼 0 유지.
2. **핫 경로에서 깊은 복사 제거**: `SaveService`에 읽기 전용 접근(예: 라이브 딕셔너리를 그대로 돌려주는 `peek_profile()` — 호출자는 수정 금지 — 또는 `get_crate_head(type)`, `get_owned_crate_counts()`, `get_research_level(id)`, `get_inventory_used_slots(type)` 같은 좁은 getter)을 두고, 매 프레임·HUD 갱신 경로(`_get_sorted_owned_crate_ids_from_counts`, `_get_shared_crate_storage_state`, `_get_crate_open_block_result`, `ResearchService._get_research_levels`, `RacerService` mastery 조회 `RacerService.gd:224~225`)에서 사용. 수정하는 호출자는 기존 `get_profile()` 유지.
3. **`_flush_race_crate_hud_refresh` 타이머 갱신**: 타이머 표시만 바뀌는 갱신(`CRATE_HUD_REFRESH_TIMER`)에서는 프로필 조회·보류 재계산 없이 텍스트만 갱신.
4. (참고) ③에서도 남는 `get_profile()` 2회/프레임(0.7ms×2)은 2번으로 같이 제거 — 세이브가 더 커지면 다시 문제가 된다.

예상: 사용자 세이브 경기 프레임 36.5 → 약 7ms(새 세이브 수준).

## 5. 검증 계획

- Codex: 기존 상자·보관함 테스트, 보관함 가득 참 → 아이템 판매/연구 업그레이드 시 대기 상자가 다음 판정에서 바로 열리는지, 보류 HUD 표시("Full") 유지, 저장/로드 후 타이머 유지. **부하 측정은 하지 않아도 된다**(Claude가 수행).
- Claude: 수정 후 같은 측정 스크립트로 ①②③ 재측정해 전후 비교 보고. 필요하면 저사양 흉내(CPU 코어 제한)도 측정.

## 6. 다음 담당자

- **Codex**: 4의 1~3(가능하면 4) 수정 → 공통 인계 형식 보고(변경 파일·테스트).
- **Claude**: 재측정. 이어서 팀·차고 UI 조작 지연(같은 `get_profile()` 깊은 복사 의심) 측정·분석.
- 변경하지 말 것: 상자·보관함·연구 규칙, 저장 데이터 형식, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
