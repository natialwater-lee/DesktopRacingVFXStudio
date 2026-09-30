# 광합성 / Photosynthesis — VFX 재제작 설계

> **최종 상태 (2026-09-30): Studio 시안 사용자 승인, package 재생성(Runtime v1), Codex 인계 작성.** 최종 구성은 3~5장의 초안과 다르다 — 최종: START(금빛 GLOW + 수렴 광선 + 기운 B 방출) / LOOP(전기 아크 기운 A·B를 서로 다른 주기로 번갈아 겹침 + 약 2.2초마다 금빛 흡수 광선) / END(빈 phase, 자연 소진). 폐기: 불꽃 테두리 기운(1차), 꼰 그물 기운(2차), 절차적 GLOW+RING 기운(도형처럼 보임), 옆 에너지 줄기. 최종 수치와 확인 항목은 [Codex 인계](../../handoffs/2026-09-30-photosynthesis-codex-handoff.md). 구 텍스처 3장과 중간 텍스처(aura 1·2차, vein)는 삭제.

2026-09-30 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 2026-09-30)

`docs/TALENT_VFX_GUIDELINES.md` 4장은 광합성을 "완료·수정하지 않는 기준 자료"로 두었으나, **사용자가 직접 교체를 요청**했으므로 최신 지시에 따라 재제작한다(지침 1장 우선순위 1).

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `photosynthesis`: trigger `condition_after_active_racer_time`(condition `heatwave`, 15초), activation_chance 0.3, **duration 20초**, effect: 폭염 환경 페널티 0, 부스트 게이지 회복 ×1.3. legacy `photosynthesis_green`은 package 소유 시 억제.
- 연결: `RaceAbilityVfxIntegrationController.ABILITY_PRESET_IDS` `"photosynthesis": "talent.photosynthesis"` (이미 있음) → **ID 유지, package 교체만**.
- 폭염 조건이므로 트랙은 따뜻한 색보정·아지랑이 상태(낮 위주, 야간 트랙에서도 드물게 발생).

## 2. 참고 자료와 현재 문제

- 컷인: `assets/videos/race_abilities/photosynthesis.mp4`(4.0초). 0.8~1.4s 태양에서 금빛 빛줄기가 차로 내려옴 → 1.4~2.0s 차체가 금빛으로 감싸였다가 연두빛으로 전환 → 2.0s~ 연두빛 에너지 줄기가 차체·바퀴를 타고 뒤로 흐르고 차 아래가 녹색으로 빛남.
- 현재 preset(사용자 녹화 검토): 잎사귀 초승달 2장이 차를 원으로 감싸고, 금빛 혜성 줄기가 옆·앞에서 제각각 각도로 들어오며, 가운데 소용돌이가 반복. **모든 레이어가 ALPHA 합성·OVER_VEHICLE·불투명도 0.3~0.4** → 발광하지 않고 탁하며 차를 덮음. LOOP 레이어 9개(파티클 최대 13).
- 컷인에는 잎이 없음. 핵심은 "금빛 햇빛 흡수 → 연두빛 에너지로 전환 → 차체를 타고 흐름".

## 3. 합의한 연출

| 구간 | 연출 | 구현 |
|---|---|---|
| START 0.6s | 차 아래 금빛 빛 번짐 + 금빛 방사 광선이 차 중심으로 수렴(흡수) → 약 0.3초 뒤 연두빛이 한 번 퍼짐(전환) | GLOW 1 + PARTICLE 2 |
| LOOP 20s(Game 소유) | ① 차 아래 연두빛 기운이 천천히 숨쉼 ② 양옆 가는 에너지 줄기가 앞→뒤로 흐름 ③ 약 2.2초마다 작은 금빛 광선이 차로 흡수 | TEXTURED_SPRITE 1 + PARTICLE 3 |
| END 0.4s | 새 줄기 없음, 기운이 옅어지며 소멸 | TEXTURED_SPRITE 1 |

- 빛은 전부 **ADDITIVE**. 넓은 빛은 `UNDER_VEHICLE`, 차 위에는 가는 줄기와 짧은 흡수 광선만(`OVER_VEHICLE`).
- 생략: 하늘·태양·구름·카메라·배경 차량, 잎사귀 고리.
- 다른 재능과 구분: 독주(금빛 리본, 뒤로 흐름) / 제로의 영역(청백) / 나이트 비전(청록 전방 스캔) ↔ 광합성(**금빛 수렴 + 연두 기운·줄기**).

## 4. 초기 수치안 (시안 출발점 — Game Canvas 100%에서 조정)

좌표: 차량 source px(256×512, CENTER, 전방 −Y), anchor `CENTER`, `VEHICLE_LOCAL`.

**START**
- `start.sun_pool` GLOW CORE, ADDITIVE, UNDER: 색 (1.0, 0.82, 0.35), radius 330, opacity 0.35, scale (0.9, 1.35), pulse_hz 0.
- `start.sun_rays` PARTICLE CORE, ADDITIVE, OVER: `fx.photosynthesis_sun_rays`, BURST 1, 속도 0, 수명 0.5, 크기 300 → 70(수렴), 알파 0.8 → 0, 회전 무작위, 각속도 40°/s.
- `start.green_release` PARTICLE CORE, ADDITIVE, UNDER: `fx.photosynthesis_energy_aura`, CONTINUOUS 3.3/s·max 1(첫 방출 ≈0.3s 지연을 의도적으로 사용), 수명 0.5, 크기 250 → 380, 알파 0.8 → 0.

**LOOP**
- `loop.energy_aura` TEXTURED_SPRITE CORE, ADDITIVE, UNDER: `fx.photosynthesis_energy_aura`, scale (2.2, 2.2), opacity 0.8. OSCILLATOR `photo.breath` SINE 0.7Hz → scale X/Y ×0.97~1.03, 불투명도 ×0.75~1.0.
- `loop.vein_left` / `loop.vein_right` PARTICLE CORE, ADDITIVE, OVER: `fx.photosynthesis_energy_vein`, BOX 20×60 이미터 offset (∓105, −150), 방향 180°±6°, 속도 520~680, 수명 0.55, 발생 3.2/s, max 2, 크기 60 → 44, 알파 0.9 → 0.
- `loop.sun_charge` PARTICLE DETAIL, ADDITIVE, OVER: `fx.photosynthesis_sun_rays`, CONTINUOUS 0.45/s·max 1, 수명 0.5, 크기 170 → 50, 알파 0.6 → 0, offset (0, −30).

**END**
- `end.energy_aura` TEXTURED_SPRITE CORE: 같은 배치, opacity 0.35.

Preset: `presets/examples/talent.photosynthesis.vfx.json`(교체), preset_id `talent.photosynthesis`, category `RACE_TALENT`, `START_LOOP_END`, runtime_inputs `[]`, OSCILLATOR modulation → Runtime Definition v2(현재 package도 v2).

부하: LOOP 레이어 9 → 4, 스프라이트 최대 13+2 → 1 + 4 + 1 = 6.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-09-30-photosynthesis-gpt-art-request.md) — 3장.
- `talent_photosynthesis_energy_aura.png` 192×320 → `fx.photosynthesis_energy_aura`
- `talent_photosynthesis_energy_vein.png` 32×128 → `fx.photosynthesis_energy_vein`
- `talent_photosynthesis_sun_rays.png` 192×192 → `fx.photosynthesis_sun_rays`

기존 3장(`absorption_glow`, `solar_streak`, `leaf_arc`)은 새 preset에서 쓰지 않는다. 품질은 괜찮으나 잎·소용돌이·혜성 구도가 컷인과 다르고 ALPHA 합성 기준으로 만들어졌다. 교체 승인 후 Studio·Game에서 정리.

### 5-1. 검수 결과 (2026-09-30, Claude) — 3장 승인, Studio 등록 완료

| 파일 | 측정 | 판정 |
|---|---|---|
| energy_aura 192×320 | 알파 최대 0.85, 여백 4px 이상, 투명부 RGB 라임, 가운데 빈 영역 ≈96×178px(요청 100×210보다 세로가 짧음) | 승인. scale 2.2에서 빈 영역(≈211×392 source)이 차체(256×512)보다 작아 고리 안쪽은 차에 가려지고 바깥 약 8px가 보임 — 의도와 일치 |
| energy_vein 32×128 | 줄기 x 13~19(7px), 길이 100px, 머리 아래, 알파 최대 0.90 | 승인. 매우 가늘어 초안 크기(60)로는 게임 크기에서 거의 안 보임 → preset 크기 100 → 78로 상향 |
| sun_rays 192×192 | 곧은 금빛 광선 약 20가닥, 작은 핵, 알파 최대 0.90 | 승인. 광선이 가늘어 초안 크기로는 약함 → START 360 → 90, 충전 200 → 60, 알파 1.0 / 0.8로 상향 |

GPT 메모: 컷인 영상이 첨부되지 않아 글 설명만으로 제작됨. 가산 합성 강도는 Studio 시안에서 확인.
시안 preset: 4장 수치에서 위 보정만 적용(줄기·광선 크기·알파). Studio 검증기·export 계획 통과. 기존 `tests/preview/test_photosynthesis_authoring.gd`는 구 preset 기준이라 **현재 실패 상태** — 사용자 시각 승인 후 새 구성으로 갱신한다.

## 6. Game 지원 판단

- GLOW(pulse_hz 0), PARTICLE(POINT/BOX, ADDITIVE), TEXTURED_SPRITE + OSCILLATOR modulation: 나이트 비전·헤드라이트·슈퍼 부스터에서 Game 운영 확인된 기능. 계약·코드 변경 없음.
- 인계 시 명시할 것(Codex 체크리스트): ADDITIVE TEXTURED_SPRITE의 운영 첫 사용 여부, START의 CONTINUOUS 첫 방출 지연을 의도적으로 쓰는 점, START/END보다 긴 파티클 수명, 폭염 트랙 색보정·아지랑이와의 겹침, Studio 미검증 항목.
- 기존 Studio 테스트 `tests/preview/test_photosynthesis_authoring.gd`는 현재 preset을 정확 값으로 검사하므로 새 preset 확정 후 함께 갱신한다.

## 7. 다음 작업

1. 사용자: GPT에 아트 요청 전달.
2. Claude: PNG 검수 → asset 등록 → preset 교체 → Game Canvas 100% 시안.
3. 사용자 시각 승인 → 테스트 갱신 → package `REPLACE_EXISTING` → Codex 인계.
