# 광합성 / Photosynthesis — 재제작 package Game 적용 인계 (Studio → Codex)

2026-09-30 · 작성: Claude (Studio 담당) · 대상: Game Codex · 공통 인계 형식

설계·시안 이력: Studio `docs/superpowers/specs/2026-09-30-talent-photosynthesis-rework-design.md`.

## 0. 먼저 읽을 것

- 기존 `talent.photosynthesis`(P5.2, GPT 흐름 제작·Game 적용·당시 사용자 승인)는 **사용자 요청으로 전면 재제작**했다. 같은 ID지만 구성·리소스가 완전히 다르다. 기존 package 기준 검사 기대값(레이어 ID, 에셋, P5 계측 등)은 새 manifest 기준으로 바꿔야 한다.
- 연출 기획·preset 작성·package 생성은 Claude가 했다. preset은 생성 스크립트로 작성 후 Studio 검증기·export를 통과했고 repo preset은 package `source`와 byte 동일.
- 계약·코드 변경 없음을 전제로 만들었다(아래 4장). 실제 코드와 다르면 추측하지 말고 알려 달라.

## 1. ID / 버전

`photosynthesis` → `talent.photosynthesis` (연결 `ABILITY_PRESET_IDS` 기존 그대로). Package 1 / **Runtime v1**(기존 v2에서 내려감: modulation·runtime_inputs 없음) / Schema 1 / `RACE_TALENT` / `START_LOOP_END` / `VEHICLE_LOCAL` / anchor `CENTER`.

## 2. 전달물 (Studio `exports/packages/talent.photosynthesis/`, byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 |
|---|---:|---|
| `manifest.json` | 2670 | 874cc6b910ec |
| `assets/talent_photosynthesis_energy_aura_a.png` (192×320) | 75940 | 8548e52d53fa |
| `assets/talent_photosynthesis_energy_aura_b.png` (192×320) | 78081 | 80b34155be90 |
| `assets/talent_photosynthesis_sun_rays.png` (192×192) | 32674 | ce34d413d699 |
| `runtime/vfx_runtime_definition_v1.json` | 9746 | 8ce83543a028 |
| `source/talent.photosynthesis.vfx.json` | 9249 | 5d0f97187a0f |

기존 package의 `vfx_runtime_definition_v2.json`, `talent_photosynthesis_absorption_glow/solar_streak/leaf_arc.png`는 새 package에 없다(다른 참조 없으면 제거).

## 3. 연출 (좌표: 차량 source px 256×512, 전방 −Y, 전 레이어 ADDITIVE)

| 구간 | layer | 내용 |
|---|---|---|
| START 0.6s | `start.sun_pool` GLOW CORE, UNDER | 금빛 (1.0, 0.82, 0.35), radius 330, opacity 0.35, scale (0.9, 1.35), pulse_hz 0 |
| | `start.sun_rays` PARTICLE CORE, OVER | `sun_rays` BURST 1, 수명 0.5s, 크기 360 → 90(수렴), 알파 1 → 0, 무작위 회전 |
| | `start.green_release` PARTICLE CORE, UNDER | `energy_aura_b`, **CONTINUOUS 3.3/s·max 2 — 첫 방출이 약 0.3s 뒤인 점을 의도적으로 사용**(금빛 수렴 뒤 연두 전환), 수명 **1.4s(START보다 김)**, 크기 300 → 368, 알파 0.9 → 0 |
| LOOP (Game 소유 20s) | `loop.energy_aura_a` PARTICLE CORE, UNDER | `energy_aura_a`, 1.35/s, max 2, 수명 1.05s, 크기 340 → 372, 알파 0.75 → 0, 속도 0 |
| | `loop.energy_aura_b` PARTICLE CORE, UNDER | `energy_aura_b`, 1.1/s, max 2, 수명 1.25s, 같은 크기·알파. 두 주기가 달라 아크가 자리를 옮기며 일렁임 |
| | `loop.sun_charge` PARTICLE DETAIL, OVER | `sun_rays`, 0.45/s, max 1, 수명 0.5s, 크기 250 → 70, 알파 1 → 0 (약 2.2s마다 금빛 흡수) |
| END 0.4s | (레이어 없음) | 새 발생 중단, 남은 기운(최대 1.25s) 자연 소진 |

LOOP 스프라이트 최대 5(기존 최대 15), 렌더러 3(기존 9).

## 4. 기존 기능 재사용 / 계약

- GLOW(pulse_hz 0), PARTICLE POINT CONTINUOUS/BURST, ADDITIVE, UNDER/OVER_VEHICLE, 빈 END(양수 duration): 나이트 비전·날씨 package에서 Game 운영 확인된 범위. 새 renderer·계약 변경 없음.

## 5. 확인 요청 (Codex 체크리스트)

1. **phase보다 긴 수명**: `start.green_release` 1.4s > START 0.6s, LOOP 기운 1.05/1.25s가 빈 END(0.4s) 이후 소진되는지. STOP 뒤 `is_drained`, force clear·차량 제거·레이스 정리.
2. **첫 방출 지연**: LOOP 기운 첫 입자는 LOOP 시작 후 약 0.74s/0.91s. 그 사이는 START의 `green_release`(1.4s 수명)가 메운다 → 시작→루프 사이 기운이 끊기지 않는지.
3. **큰 ADDITIVE 파티클 중첩**: 기운 텍스처(약 40×66px 표시)가 최대 4장 겹친다. 폭염 트랙 색보정(따뜻한 틴트·아지랑이)과 밝은 모래·눈 배경에서 과하게 타지 않는지, 어두운 아스팔트에서 충분히 보이는지.
4. **기존 효과와 겹침**: 기본/슈퍼 부스터 불꽃, 타이어 자국, 고속 바람선, 다른 재능 VFX(동시 5~8대). legacy `photosynthesis_green` 억제 유지.
5. **차종**: 기운의 빈 가운데가 차체보다 작아 차 둘레로 약 8px 새어 나오는 구성. 폭이 다른 차종에서 어색하지 않은지.
6. **부하**: 교체 전/후 폭염·20대에서 5~8대 동시 발동 frame·draw call(파티클 렌더러 9 → 3 기대).

## 6. 검증

- Claude 실행: PNG 검수, Studio 검증기·export, package 1회 `REPLACE_EXISTING`, preset=source byte 동일, Studio 테스트 갱신(`test_photosynthesis_authoring.gd` 새 구성 기준, `test_main_scene_smoke.gd` 재능 4종) — preview 414 / export contract 70 / performance 61 assertions 실패 0. editor 묶음은 401 중 4 실패(모두 skeleton/schema 관련 기존 테스트로 이번 변경 파일과 무관 — src·schemas 미변경, 원인 미조사).
- Claude 미실행: Game 실행·테스트·성능, 실제 경기 판독성.
- 사용자 Studio 녹화 검토 7회(불꽃 테두리 → 꼰 그물 → 도형 글로우 → A/B 아크 기운 채택, 옆 줄기 제거, 속도 +35%).

## 7. 사용자 시각 승인

- Studio 시안: **승인**(2026-09-30).
- Game 실제 경기 외형: 미승인 — Codex 적용 후 사용자 확인.

## 8. 다음 담당자

- **Codex**: 2 교체·구 리소스 정리 → 5 확인 → 관련 검사 기대값 갱신 → 공통 인계 형식 보고. 외형 수정은 Game에서 package를 고치지 말고 Studio로.
- **사용자**: 폭염 경기 녹화로 최종 확인.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터. 승인 없는 commit 금지.
