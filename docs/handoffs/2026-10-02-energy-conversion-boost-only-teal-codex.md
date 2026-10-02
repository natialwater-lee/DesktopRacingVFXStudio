# 에너지 전환 — 청록 표현을 부스터 때만 (상시 줄기 제거) 재적용 + Claude 부하 측정 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 이전: `docs/handoffs/2026-10-02-energy-conversion-codex-handoff.md`, Game `docs/ENERGY_CONVERSION_GAME_HANDOFF.md`

## 0. 요약

- 사용자 요청: 재능 효과가 "부스터 게이지 회복·부스터 성능 상승"이므로 **차 뒤 청록 표현은 부스터가 나올 때만** 보이게.
- Studio에서 부스터와 무관하게 나오던 옅은 청록 줄기 **`loop.release_trickle`(PARTICLE) 제거**. 부스터 연동 `loop.boost_release`(TEXTURED_SPRITE, `boost_active`)는 그대로 — 이제 LOOP 중 청록은 부스터 때만 보인다.
- 발동 순간 1회 `start.release_flash`(청록 섬광 0.8s)는 "흡수 → 변환" 발동 연출로 유지.
- 텍스처 4장 byte 동일, 계약·코드 변경 없음, ID·버전 동일(Package 1 / Runtime v2 / `runtime_inputs: ["boost_active"]`).

## 1. 교체할 전달물 (Studio `exports/packages/talent.energy_conversion/`, REPLACE_EXISTING — byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 | 변경 |
|---|---:|---|---|
| `manifest.json` | 3172 | a3fec4450c41 | 변경 |
| `assets/talent_energy_conversion_rear_arc_a.png` | 43398 | 931d63ee6a93 | 동일 |
| `assets/talent_energy_conversion_rear_arc_b.png` | 55473 | 993802015247 | 동일 |
| `assets/talent_energy_conversion_release.png` | 24040 | 726e5a189424 | 동일 |
| `assets/talent_energy_conversion_swirl.png` | 147139 | 607f993d0609 | 동일 |
| `runtime/vfx_runtime_definition_v2.json` | 12226 | f86c69907189 | 변경 |
| `source/talent.energy_conversion.vfx.json` | 10760 | 2600b6b36f47 | 변경 |

LOOP 레이어: `loop.arc_a`, `loop.arc_b`, `loop.boost_release`(3개). 차량당 스프라이트 LOOP 최대 5.

## 2. Codex 요청 작업

1. package 파일 교체, 해시 기록 갱신.
2. `loop.release_trickle`을 참조하는 Game 테스트·probe가 있으면 정리.
3. `boost_active` 공급·보간은 그대로.

## 3. 확인 요청

1. 발동 중 부스터를 쓰지 않을 때 차 뒤 청록이 보이지 않는지(발동 순간 섬광 제외), 부스터 때 청록 분출이 0.08s에 켜지고 종료 후 0.3s에 꺼지는지.
2. **부하 측정은 하지 않아도 된다**(아래 Claude 측정).

## 4. Claude 부하 측정 (적용된 이전 package 기준, 2026-10-02)

- 방법: Claude 측정 스크립트(외부 파일, Game 수정 없음)가 `NightVisionGameProbe.ProbeManager`를 재사용해 20대 뉴욕·날씨 none 고정 경기에서 **20초에 방어 성공 5회 조건을 강제**(30% 시드로 6대 동시 발동), 21~29초 측정, debug GL, 고사양 PC. Codex 기본 probe는 방어 조건을 채우지 못해 발동 0회였다.
- 결과(2회씩): 발동 없음 6.95/13.49ms·6.95/13.51ms, draw 221·224 → **6대 발동 7.05/13.47ms·7.07/13.49ms, draw 258·262**. 발동 순간 프레임 8.3·15.0ms(튐 없음). 측정 구간에 일반 부스터 작동 프레임 다수(차량·프레임 합계 약 4,000) — 부스터 연동 포함.
- 판단: 부하 문제 없음. 상시 줄기 제거로 소폭 더 줄어든다.

## 5. 다음 담당자

- **Codex**: 2 교체 → 3 확인 → 공통 인계 형식 보고.
- **사용자**: 재적용 후 발동 + 부스터 장면 외형 최종 확인.
- 변경하지 말 것: 재능 판정·확률·지속시간, 부스터 규칙, 다른 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.

## 6. 재적용 후 Claude 부하 재측정 (2026-10-02)

Codex 재적용 완료(Game `docs/ENERGY_CONVERSION_GAME_HANDOFF.md`). 같은 방법(방어 조건 강제, 6대 발동): 발동 없음 7.23/13.56ms·draw 232 → 6대 발동 7.02/13.53ms·draw 249, 6.95/13.50ms·draw 238. 발동 순간 14.3·14.8ms. 이전(상시 줄기 포함) draw 258~262 대비 감소, 프레임 차이는 측정 오차 수준. 남은 것: 사용자 실제 경기 외형 확인.
