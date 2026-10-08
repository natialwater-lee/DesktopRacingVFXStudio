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
## 8. 재작업 — "방어 전면 + 곡면 막" (2026-10-08, 방향 사용자 승인)

### 8-1. 사용자 판단

- 좌우 벽: 육각 무늬 직선 벽이 **자처럼 곧아 방어 에너지 벽으로 보이지 않음** → 교체.
- 뒤 U자 방어막: 뒤를 막는 성격이 분명하고 방어 성공 시 커지는 기믹이 독특하게 작동 → **유지·강화**. 다만 형태를 다시 잡고 **좌우로 더 넓게** 막아 뒤차를 견제하는 장치처럼 보이게.
- 방어 성공(`defense_impact`) 반응을 **좌우 효과에도 동시에** 적용.

### 8-2. 새 형태 (source px, 전방 −Y)

```
   ( ▓▓ )        좌우: 차에 붙어 시작(앞 x≈±125, y≈−215) → 뒤로 갈수록 벌어짐(x≈±235, y≈+200)
  (  ▓▓  )             가장자리 출렁이는 곡면 에너지 막, 앞→뒤 흐름(A/B 교대), 육각 무늬 없음
 (   ▓▓   )
╲___________╱    뒤: 얕고 넓은 호 "방어 전면", 양 끝 ±232에서 앞으로 휘어 좌우 막과 이어짐, 최저점 y≈+282
```

- 차 외곽 ±115 대비 뒤 전면 ±232 → 바로 뒤 차의 앞부분을 반투명하게 덮어 견제(의도).
- 좌우 막 끝과 뒤 전면 끝이 이어져 하나의 방어막 실루엣으로 읽히게 한다.

### 8-3. 레이어 계획 (Studio에서 수치 확정)

| 구간 | layer | 변경 |
|---|---|---|
| START | `start.wall_l/r` | 새 곡면 막 텍스처, 기존 펼침(불투명도·바깥 이동·길이) 유지 |
| | `start.shield_flash` | 새 방어 전면 텍스처, 크기 비율 조정 |
| LOOP | `loop.wall_{l,r}_{a,b}` | 새 텍스처, A/B 교대 유지 + **`defense_impact` 연결 신설**: 불투명도 ×1→약 1.8, 바깥쪽으로 폭 ×1→약 1.15(pivot 안쪽 앞) |
| | `loop.shield` | 새 방어 전면(scale ≈1.0), 일렁임 + 기존 `defense_impact` 부풂(폭·뒤 방향) 유지 |
| END | `end.*` | 새 텍스처로 교체, 페이드 동일 |

- 음수 scale은 schema에서 금지(`minimum 0.001`) → GPT는 **오른쪽 막만** 제작, 왼쪽은 Claude가 Godot `Image.flip_x()`로 생성(`_l` 파일).
- 입력·Runtime v2 동일 → Game 코드 변경 없이 package 교체(REPLACE_EXISTING) 예상.

### 8-4. 아트

요청: [GPT 아트 요청 v2](../../handoffs/2026-10-08-absolute-defense-v2-gpt-art-request.md) — 3장(오른쪽 막 A/B, 방어 전면). 기존 3장은 새 시안 승인 후 정리.

### 8-5. v2 Studio 시안 수치 (2026-10-08, 사용자 검토 전)

| layer | 값 |
|---|---|
| 곡면 막 `*.wall_{l,r}*` | 텍스처 `fx.absolute_defense_curtain_{l,r}_{a,b}`(192×480, 왼쪽 = 오른쪽 flip_x), 위치 (∓178, +25), scale 1.1(띠 앞 끝 ≈ x ±128·y −184, 뒤 끝 ≈ x ±215·y +236), END 파티클 크기 264 |
| LOOP 곡면 막 방어 성공 | pivot (안쪽 ±45, −160), `defense_impact` ⇒ 불투명도 ×1→1.8, 폭 ×1→1.2 |
| 뒤 방어 전면 `*.shield*` | 텍스처 `fx.absolute_defense_rear_front`(512×176), 위치 (0, +250), scale 1.05(밝은 끝 ≈ ±200·y +210, 최저 밝은 선 y≈+280), pivot (0, −48), 방어 성공 폭 ×1.25·뒤 ×1.6, 시작 섬광 269→317 |
| 그 외 | START 펼침·LOOP A/B 교대·일렁임·END 페이드 수치 유지 |

테스트 `tests/preview/test_absolute_defense_authoring.gd` 갱신(새 5개 텍스처, 곡면 막 defense_impact 반응·바깥 방향 pivot). preview 468 assertions 통과. 기존 `side_wall_a/b`·`rear_shield` 텍스처와 catalog 항목은 승인 후 정리.

### 8-6. v2.1 — 사용자 Studio 녹화 검토 1 반영 (2026-10-08)

- 사용자: 게임 크기에서 얇아 보일 수 있음 → 좌우 세로 길이 축소·가로 두께 증가, 리어 세로 두께 증가(곡선 조금 더 깊어져도 됨). 방어 성공이 아닐 때도 좌우는 좌우로, 리어는 상하로 웅웅거리듯 움직임.
- 텍스처 가공(GPT 원본 기준, Claude): 곡면 막 세로 ×0.85(192×480 → 192×408) 후 **각 줄을 띠 중심 기준 가로 ×1.4**(경로는 유지하고 띠만 두껍게. 단순 가로 확대는 휘는 폭까지 커져 앞 끝이 차 안으로 들어가고, 이동 복사 max 합성은 가로 줄무늬가 생겨 버림). 리어 세로 ×1.4(512×176 → 512×246).
- 배치: 곡면 막 (∓170, +20), scale 1.1, END 파티클 224, 방어 성공 pivot (안쪽 ±40, −140). 리어 (0, +242), scale 1.05.
- 숨쉬기: OSCILLATOR `shield.hum` 1.4Hz, 위상 108°(LOOP 시작 0.5s에 0). 곡면 막 `TRANSFORM_OFFSET_X` ADD ±10(좌우 대칭으로 바깥↔안), 리어 `TRANSFORM_OFFSET_Y` ADD ±10(뒤↔앞). 한 박자로 함께 움직여 이음새 유지, 방어 성공 부풂 방향과 일치.
- preview 469 assertions 통과(숨쉬기 검사 추가).

### 8-7. v2 확정·Game 적용 (2026-10-08)

- 사용자 Studio 녹화 검토 2에서 승인("스튜디오에서는 적절해 보임"). 좌우 막 끝과 뒤 전면 끝이 겹친 모서리가 조금 밝은 점은 방패 모서리로 보여 유지.
- 정리: 기존 `side_wall_a/b`·`rear_shield` 텍스처와 catalog·export 정책 항목 삭제. package REPLACE_EXISTING 재생성(텍스처 5장, Runtime v2). Studio preview 469 / export contract 70 통과.
- Game(Claude, 브랜치 `claude/absolute-defense-v2`, 커밋 `91d4710`, v0.2-35.30.47): package 파일 교체만, 코드 변경 없음. `AbsoluteDefenseVfxIntegrationTest` PASS(89, 좌우 막 부풂·숨쉬기 검사 추가). 부하(뉴욕·비·20대, 2회): 미발동 7.18·7.03ms → 6대 발동 7.27·7.38ms, draw +12~48, 발동 프레임 12.4·5.4ms. `AbsoluteDefenseGameProbe` 캡처로 방어 성공 장면 렌더 확인.
- **사용자 Game 최종 승인 2026-10-08.** 완료.
