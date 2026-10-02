# 피트스톱 에이스 — 교체 차량 부착 + 고정 시간 재생 사전 확인 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 설계: Studio `docs/superpowers/specs/2026-10-02-talent-pit-stop-ace-design.md`

## 0. 배경

피트스톱 에이스는 즉시 발동형(지속 0)이고, 발동 순간 **현재 차량이 사라지고 다음 차량으로 교체된다**(사용자). 새 VFX package는 **교체된 다음 차량**에 붙어 **고정 시간(총 약 5.5초)** 재생해야 한다. 플레이어·NPC 구분 없이 같은 시간(사용자 결정). **이번 요청은 사전 확인이며, 구현은 package 인계 때 요청한다.**

## 1. 제안

- package `talent.pit_stop_ace`: `START_LOOP_END` — START 0.6s(정비 섬광·스파크), LOOP(뒷바퀴 회전 휠 고리 + 청록 출발 라인, 길이 무관), END 0.4s.
- Game: 교체된 차량에 시작 → **시작 후 5.1s에 LOOP 종료 지시** → END 0.4s 자연 소진(총 5.5s). 시간 값은 Game 데이터에서 조정 가능하게(예: `visual` 필드).
- 바퀴 효과는 뒷바퀴 공용 위치 (±84, +160) source px만 사용(차종별 앞바퀴 위치 차이 회피).

## 2. Claude 확인 사항 (읽기 전용)

- `RaceAbilityRuntimeController.gd` 666행: `complete_active_pit_service_immediately()` 성공 시 발동, 688행: `trigger_race_ability_transient_fx(instant_fx_id, 0.7)`.

## 3. Codex 확인 요청

1. **차량 교체 순서**: `complete_active_pit_service_immediately()`와 다음 차량 교체가 어디서·언제 일어나는지, 교체된 차량(CarAgent 또는 같은 CarAgent의 외형/로드아웃 교체)을 VFX 시작 시점에 참조하는 방법. 교체가 같은 프레임인지 지연되는지.
2. **고정 시간 재생**: START_LOOP_END + 시작 후 5.1s 종료 지시 방식 vs `ONE_SHOT` lifecycle(Studio schema 지원, Game 지원 여부 미확인) 중 권장안. 즉시형 재능에 VfxService effect를 시간 제한으로 붙이는 기존 경로.
3. 그 사이 차량이 다시 피트에 들어가거나 레이스가 끝나는 경우 정리.
4. legacy `pit_stop_ace_burst`(0.7s transient) 억제 방법.
5. 같은 차량에 다른 재능 효과가 이미 붙어 있을 때(교체 후 새 레이서의 재능) 겹침.

## 4. 다음

- Codex: 3 확인 결과를 공통 인계 형식으로 보고(코드 변경 없이 확인만).
- Claude: 결과 반영 → 시안 → package 인계. 부하 측정은 Claude.
- 변경하지 말 것: 피트·교체 규칙, 재능 판정, 다른 VFX, 저장 데이터. 승인 없는 commit 금지.
