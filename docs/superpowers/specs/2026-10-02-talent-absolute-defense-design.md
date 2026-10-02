# 절대 방어 / Absolute Defense — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인 + 방어 성공 연동 선택 사항 개발 승인 2026-10-02, Studio 시안 검토 후 package 진행)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `absolute_defense`: trigger `rank_at_or_better_for_duration`(3위 이내 8초), activation_chance 0.3, **duration 12초**, effect: 방어 ×1.5, 방어 라인 선택 확률 ×3, 코너 속도 ×1.1.
- legacy `blue_shield`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`).
- 의미: **상위권에서 뒤차의 추월을 막아 내는 방어벽.**
- 방어 성공 신호: `CarAgent.race_ability_defense_succeeded(car, rear_car)`(`CarAgent.gd` 8·4797행) → `RaceAbilityRuntimeController._on_car_defense_succeeded`(229행).
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"absolute_defense": "talent.absolute_defense"`, catalog, legacy 처리, `defense_impact` 입력 공급(4절).

## 2. 참고 자료

- 컷인 `absolutedefense.mp4`(4.0초) + 컨셉 이미지: 0~1.3s 차체 전체가 파란 에너지 막으로 빛남 → 1.6s~ 차 양옆에 반투명 파란 에너지 벽(패널)이 솟고 노면에 파란 차선 빛줄기, 옆 차들이 벽에 막힘.
- 가져올 것: 양옆 반투명 에너지 벽, 막아 내는 느낌. 생략: 차체 윤곽 발광(차종마다 형태 다름), 노면 차선 빛줄기(다른 재능 빛줄기와 혼동).

## 3. 합의한 연출 — "방어벽 전개"

| 구간 | 연출 | 구현(예정) |
|---|---|---|
| START ≈0.5s | 양옆 에너지 벽이 바깥으로 펼쳐지며 세워짐 + 차 뒤 둥근 방어막 1회 번쩍 | TEXTURED_SPRITE(벽, LINEAR_PHASE로 펼침·페이드인) + PARTICLE BURST(방어막 섬광) |
| LOOP 12s | ① 차 양옆 반투명 에너지 벽 2장, 육각·물결 무늬가 뒤로 흐름(A/B 교대) ② 차 뒤 둥근 방어막이 은은하게 일렁임 ③ **방어 성공 순간 방어막이 "팅" 번쩍**(`defense_impact`) | PARTICLE(벽 A/B 교대) 또는 TEXTURED_SPRITE+OSCILLATOR, TEXTURED_SPRITE(방어막, OSCILLATOR 일렁임 + `defense_impact` 불투명도·크기) |
| END ≈0.4s | 벽·방어막 서서히 사라짐 | PARTICLE 복사본 페이드(엔지니어 방식) |

- 색: 하늘빛 청록(0.35, 0.8, 1.0), 가장자리 흰빛. 전 레이어 ADDITIVE, UNDER_VEHICLE(벽·방어막이 차 밖).
- 구분: 엔지니어 = 네 모서리 **가는 꺾쇠 선** + 스캔 ↔ 절대 방어 = 옆면 **속이 채워진 반투명 벽** + 뒤 **둥근 막**. 레인 서퍼 = 차 밑 하부광 ↔ 차 **밖** 양옆·뒤. 노면 잔류 없음.
- 크기: 가장 큰 차 기준(외곽 ≈ x ±115, y −245~+240). 벽은 차 옆 바깥(x ≈ ±150), 얇게(옆 차 가림 최소).
- 교훈 적용: 가장자리 굵고 밝게, 작은 반짝임 없음, TEXTURED_SPRITE 변조로 부드러운 펼침·일렁임, END 페이드 별도.

## 4. 방어 성공 연동 (선택 사항 — 사용자 개발 승인 2026-10-02)

- 새 런타임 입력 **`defense_impact`**: number 0~1, 기본 0. 의미: 해당 차량이 유효 방어에 성공한 순간 **1로 설정, 이후 0.5s에 걸쳐 선형으로 0까지 감소**(연속 성공 시 다시 1). 효과 시작 시 0, 레이스 일시정지 중 값 유지, 효과 종료 시 갱신 중단.
- 신호원: `CarAgent.race_ability_defense_succeeded`(재능 판정용 신호와 같은 "유효 방어"). 감쇠는 이 입력을 선언한 effect만 계산.
- Studio: schema `x_vfx_runtime_inputs.defense_impact`, 문서, 미리보기 슬라이더 + **Hit 버튼**(1 → 0.5s 감소)(Claude, 2026-10-02).
- 사용처: 뒤 방어막 TEXTURED_SPRITE `VISUAL_OPACITY_MULTIPLIER`·`TRANSFORM_SCALE_X/Y`.
- (나중 확장 후보, 이번 범위 아님) 막은 차가 왼쪽/오른쪽 어느 쪽이었는지에 따라 해당 벽이 번쩍 — `rear_car` 상대 위치로 계산 가능.
- 사전 확인: `docs/handoffs/2026-10-02-absolute-defense-impact-input-codex-precheck.md`.
- **Codex 회신(2026-10-02, 읽기 전용)**: 구현 가능. 신호 `CarAgent.gd` 4766행 추월 차단 판정 성공 → `race_ability_defense_succeeded`(재능 카운터와 같은 유일한 운영 신호, 물리 충돌 아님). 권장: `defense_impact`를 선언한 `VfxEffectInstance`가 신호를 직접 구독, 감쇠는 snapshot 갱신과 독립적으로 `advance()`에서 VFX 시간 0.5s 선형. 일시정지 유지, END 진입 시 수신·감쇠 중단, 차량 제거·강제 정리 시 구독 해제. 정지한 앞차는 신호가 날 여지 → 수신부에서 준비·정지·완주·피트 상태 거름(방어 판정은 그대로). 같은 프레임 여러 성공은 1회 재설정. 입력 사용 effect만 감쇠. Studio 문서(`docs/VFX_SCHEMA_V1.md`)에 위 규칙 반영(2026-10-02).

## 5-0. 최종 수치 (Studio 시안 2026-10-02)

좌표: 차량 source px(256×512, CENTER, 전방 −Y). 전 레이어 ADDITIVE·UNDER_VEHICLE. TEXTURED_SPRITE 크기 = 텍스처 px × scale.

| 구간 | layer | 내용 |
|---|---|---|
| START 0.5s | `start.wall_l` / `start.wall_r` | 벽 A, (∓150, 0), scale 1.3(≈83×416), opacity 0.75, `wall.intro` LINEAR_PHASE 1.9Hz ⇒ 불투명도 ×0→1, 안쪽 35px에서 바깥으로, 길이 ×0.45→1 |
| | `start.shield_flash` | 방어막 PARTICLE BURST, (0, +240), 수명 0.7s, 크기 160→190 |
| LOOP 12s | `loop.wall_{l,r}_{a,b}` | 벽 A·B 같은 위치, `wall.flow` OSCILLATOR 0.45Hz(위상 9° = 0.5s에 A 최대) ⇒ A ×0.35~1.0 / B 역위상 — 무늬 흐름 |
| | `loop.shield` | 방어막 (0, +248), **scale 1.2**, pivot (0, −48)(호의 현), opacity 0.75, `shield.shimmer` 0.9Hz ⇒ ×0.8~1.0, **`defense_impact` 0→1 ⇒ 불투명도 ×1→2.2, 폭 ×1→1.3, 뒤로 ×1→1.65** |
| END 0.45s | `end.wall_l/r`, `end.shield` | PARTICLE 복사본(같은 위치·크기), 알파 0.7/0.5 → 0 |

`runtime_inputs: ["defense_impact"]` → Runtime v2. importance CORE 11. 스프라이트 LOOP 최대 5.

## 5. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-absolute-defense-gpt-art-request.md) — 3장.
`talent_absolute_defense_side_wall_a.png` / `_b.png`(64×320), `talent_absolute_defense_rear_shield.png`(320×128).

## 6. 시안 이력 (사용자 Studio 녹화 검토 2회)

1. 벽 펼침·무늬 흐름·방어막·종료 의도대로, 엔지니어와 구분됨. Hit 번쩍임이 게임 크기에서 약할 수 있음 → 방어막 부풂 뒤 1.35→1.65, 폭 1.18→1.3.
2. 번쩍임 강화 확인. Codex 사전 확인 회신 반영 후 package 진행.
3. **Game 적용 확인(2026-10-02, 사용자 녹화)**: 2위 주행 중 플레이어 차 양옆 벽 보임. 방어 성공 번쩍임은 전체 화면 녹화로는 구분 불가. Claude 부하(발동 직접 시도 강제, 20대 뉴욕, 6대 발동, 2회): 발동 없음 7.08·6.99ms / draw 215·223 → 6대 7.13·7.03ms / draw 249·247, 발동 순간 10.7·4.5ms.
4. 사용자 요청(2026-10-02): 뒤 방어막을 조금 더 크고 잘 보이게 → scale 1.2(양 끝 ±156, 벽과 이어져 U자), (0, +248), pivot (0, −48), opacity 0.75, 일렁임 하한 0.8, 시작·종료 파티클 동일 비율. REPLACE_EXISTING 재생성, 재적용 요청 `docs/handoffs/2026-10-02-absolute-defense-rear-shield-tuning-codex.md`.
- 참고: 벽 색은 GPT 이미지 특성상 흰빛이 강한 옅은 청록(다른 파랑 재능과 구분되는 장점). TEXTURED_SPRITE는 색 곱이 없어 색 변경은 이미지 재요청 필요.

## 7. 다음 작업

1. Codex: [인계](../../handoffs/2026-10-02-absolute-defense-codex-handoff.md) — package·연결·`defense_impact` 공급.
2. Claude: 적용 후 부하 측정(순위 조건 강제 probe).
3. 사용자: 발동 + 방어 성공 장면 녹화 → Claude 검토.