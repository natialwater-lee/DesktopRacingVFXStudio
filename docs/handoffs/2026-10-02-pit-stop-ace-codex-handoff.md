# 피트스톱 에이스 / Pit Stop Ace — Game 적용 인계 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-10-02-talent-pit-stop-ace-design.md`. 사전 확인 요청: `docs/handoffs/2026-10-02-pit-stop-ace-codex-precheck.md` — **회신 전에 package를 인계한다(사용자 진행 지시).** 사전 확인 항목(교체 시점, 고정 시간 방식, 정리)은 아래 4절에서 구현과 함께 판단·보고해 달라.

## 0. 먼저 읽을 것

- 새 재능 package `talent.pit_stop_ace`. 연출·preset·package는 Claude(생성 스크립트 → Studio 검증기·export, repo preset = package `source` byte 동일).
- **즉시 발동형(지속 0)** 이고 발동 순간 현재 차량이 사라지고 **다음 차량으로 교체된다**(사용자) → 효과는 **교체된 다음 차량**에 붙어야 한다.
- **고정 시간 재생, 플레이어·NPC 구분 없음**(사용자 결정): 총 약 **5.5초** = START 0.6s + LOOP(Game이 시작 후 **5.1s**에 종료 지시) + END 0.4s. 시간 값은 Game 데이터에서 조정 가능하게.
- 바퀴 효과는 **뒷바퀴 공용 위치 (±84, +160) source px**만 사용(차종마다 앞바퀴 위치 다름 — 사용자 지시 "차량 형태가 다름 참고").
- 스파크는 분노의 추월 텍스처 재사용(package 안 사본, byte 동일). 계약·입력 변경 없음, Runtime v1.

## 1. ID / 버전

`pit_stop_ace` → **`talent.pit_stop_ace`** (신규). Package 1 / Runtime v1 / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER` / runtime_inputs 없음.
Game 정의(읽기 전용 확인): 동시 피트 정비 4건 시 30%, `activation_mode: instant`, 발동 시 `complete_active_pit_service_immediately()`(`RaceAbilityRuntimeController.gd` 666행), legacy `pit_stop_ace_burst` 0.7s transient(688행).

## 2. 전달물 (Studio `exports/packages/talent.pit_stop_ace/`, byte 그대로 도입)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 3092 | 8c29be25f5a5 |
| `assets/talent_furious_overtake_spark.png` (32×32) | 1082 | 869f6adcc994 |
| `assets/talent_pit_stop_ace_launch_line.png` (48×256) | 12108 | c34a38fabc9f |
| `assets/talent_pit_stop_ace_service_flash.png` (320×320) | 148972 | d6f436ce9a76 |
| `assets/talent_pit_stop_ace_wheel_ring.png` (128×128) | 31609 | 9b53ee704d3d |
| `runtime/vfx_runtime_definition_v1.json` | 15332 | c479de8ce320 |
| `source/talent.pit_stop_ace.vfx.json` | 14718 | 36e9506b8012 |

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y. 전 레이어 ADDITIVE PARTICLE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.6s | `start.service_flash` UNDER | 정비 섬광 BURST, (0, 0), 수명 0.7s, 크기 280→350(빈 타원이 가장 큰 차 둘레) |
| | `start.sparks_l/r` UNDER | 뒷바퀴(∓84, +160) 주황 스파크 BURST 6, 뒤쪽 200°, 수명 0.55s |
| | `start.wheel_l/r` **OVER_VEHICLE** | 휠 고리 BURST, 뒷바퀴, 회전 900°/s, 수명 0.95s(첫 LOOP 고리까지), 크기 88→68 |
| LOOP (Game 종료 지시까지) | `loop.wheel_l/r` **OVER_VEHICLE** | 휠 고리 3.5/s max 3, 수명 0.8s, 크기 68(지름 ≈136), 회전 900°/s, 알파 0.9 — 바퀴 위 빛나는 림 |
| | `loop.launch_line_l/r` UNDER | 청록 출발 라인 (∓128, +40)에서 6/s max 3, 방향 180° 속도 560, 수명 0.45s, 크기 170→150, 알파 0.9 |
| END 0.4s | (빈) | 자연 소진 |

LOOP 스프라이트 최대 12. importance CORE 9.

## 4. Codex 요청 작업 (사전 확인 항목 포함)

1. package 도입(`res://assets/vfx/packages/talent.pit_stop_ace/`), catalog 등록. `ABILITY_PRESET_IDS`에 `"pit_stop_ace": "talent.pit_stop_ace"`.
2. **교체된 다음 차량에 시작**: `complete_active_pit_service_immediately()`와 다음 차량 교체 순서를 확인하고, 교체 후 차량(새 CarAgent 또는 같은 CarAgent의 외형/로드아웃 교체)에 effect를 시작. 교체가 지연되면 교체 완료 시점에 시작.
3. **고정 시간**: 시작 후 5.1s에 LOOP 종료 지시 → END 0.4s 자연 소진(총 5.5s). 값은 Game 데이터(예: `visual.instant_fx_duration_sec` 재사용 또는 새 필드). ONE_SHOT 대신 이 방식 권장(Game ONE_SHOT 지원 미확인) — 다른 방식이 낫다면 보고.
4. 그 사이 피트 재진입·차량 제거·레이스 종료 시 강제 정리. 교체된 차량의 다른 재능 효과와 공존.
5. legacy `pit_stop_ace_burst`(0.7s transient) 억제.

## 5. 확인 요청 (부하 측정은 하지 않아도 된다 — Claude가 측정)

1. 교체된 차량에 효과가 붙는지(이전 차량에 남지 않는지), 플레이어·NPC 모두 총 약 5.5s.
2. **차종별 뒷바퀴 정렬**: 휠 고리(뒷바퀴 공용 위치)가 스포츠·GT·포뮬러 등에서 바퀴와 크게 어긋나지 않는지(OVER_VEHICLE이라 어긋나면 눈에 띔). 어긋나면 수치 보고 → Studio에서 조정.
3. 피트 출구·저속 구간에서 출발 라인 모습, 다른 차·부스터 불꽃과 겹침.

## 6. 검증

- Claude 실행: PNG 3장 육안·섬광 빈 타원 측정, Studio 검증기·export(FAIL_IF_EXISTS), Studio 테스트 `tests/preview/test_pit_stop_ace_authoring.gd`·`test_main_scene_smoke.gd` 재능 행 15개 — preview 459 / contract 204 / export contract 70 / performance 61 실패 0, editor 401 중 4 실패(기존, 무관).
- Claude 미실행: Game 실행·교체 연결·부하, 실제 경기 외형.
- 사용자 Studio 녹화 검토 2회(휠 고리가 차체에 가려 안 보임 → OVER_VEHICLE·크기 68, 출발 라인 강화).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-10-02). Game 실제 외형: 미승인 — 적용 후 사용자 녹화로 확인.

## 8. 다음 담당자

- **Codex**: 4 → 5 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **Claude**: 적용 후 부하 측정.
- 변경하지 말 것: 피트·교체 규칙, 재능 판정, 다른 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
