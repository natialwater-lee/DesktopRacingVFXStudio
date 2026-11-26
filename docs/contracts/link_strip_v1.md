# LINK_STRIP v1 — 연결형 VFX 계약 (Studio ↔ Game)

- 작성: 2026-11-26 (이펙트툴 세션, 체인 바인드 ②). 상태: **Studio 구현 완료, Game ③ 구현**(2026-11-26, Game 브랜치 `claude/chain-bind-vfx`: `VfxLinkStripRuntimeRenderer`, 기하 `VfxLinkStripGeometry.gd`는 이 문서 2절 파일의 사본).
- 첫 사용: `talent.chain_bind`, `talent.chain_bind_break`. 설계: `docs/superpowers/specs/2026-11-26-talent-chain-bind-design.md`.
- 목적: 한 차(호스트)에 붙은 effect가 **다른 차(링크 대상)**까지 매 프레임 길이·방향이 바뀌는 띠를 그린다. 기존 레이어는 모두 차 한 대의 고정 좌표만 써서 이 표현이 불가능했다.

## 1. Preset 필드 (Schema v1 additive)

### 최상위 `link_target`
| 필드 | 값 |
|---|---|
| `source_anchor` | 호스트 차 Anchor(문서·요구 사항용. 실제 띠 시작점은 각 LINK_STRIP 레이어의 Anchor + offset) |
| `target_anchor` | 링크 대상 차의 Anchor |
| `target_offset` | 대상 Anchor에서 더한 source px (기본 [0, 0]) |

LINK_STRIP 또는 `link_point_t`를 쓰는 preset은 `link_target`이 **필수**이고, 반대로 선언만 있고 쓰지 않으면 거부한다.

### 레이어 타입 `LINK_STRIP`
- 공간: `VEHICLE_LOCAL`만. Anchor는 **정확히 1개**(시작점). `visual_bend` 불가.
- 시작점 = Anchor + transform offset(모듈레이션 반영). 끝점 = 링크 대상 점(아래 3절). transform rotation·scale.y는 쓰지 않는다. **scale.x = 폭 배율**.

| 파라미터 | 기본 | 뜻 |
|---|---|---|
| `texture_asset_ref` | (필수) | 텍스처. **U = 띠 길이 방향(+X), V = 폭 방향** |
| `texture_mode` | (필수) | `TILE`: 길이 방향 반복, 한 주기 = 폭 × (텍스처 너비 / 높이). `STRETCH`: 한 장을 띠 전체에 늘임 |
| `width_source_px` | (필수) | 띠 폭 |
| `opacity` | 1 | 0~1 |
| `color_rgba` | [1,1,1,1] | 색 곱 |
| `start_inset_source_px` / `end_inset_source_px` | 0 | 양 끝에서 직선 방향으로 당김 |
| `sag_source_px` | 0 | 가운데 처짐(아래 2절) |
| `shift_source_px` | [0,0] | 띠 전체 평행 이동(그림자 등) |
| `segments` | 8 | 곡선 분할 수 1~16 |
| `reveal_seconds` | 0 | phase 시작부터 이 시간 동안 시작점→끝점으로 뻗음(ease-out cubic) |
| `retract_seconds` | 0 | phase 시작부터 끝점 쪽부터 시작점으로 감겨 사라짐(선형) |
| `gap_seconds` | 0 | phase 시작부터 가운데 틈이 0→전체로 벌어짐(선형) |
| `gap_sag_source_px` | 0 | 틈이 벌어지는 만큼 더해지는 처짐 |

reveal / retract / gap은 **phase-local 시간**(렌더러가 phase 시작에 0부터 잼)이라 END·ONE_SHOT에서도 동작한다. Game은 ONE_SHOT을 받지 않으므로 끊김 package는 START_LOOP_END(START = 끊김, 빈 LOOP, END 0.05초)로 내보내고 Game이 START 뒤에 멈춘다.

### PARTICLE `link_point_t` (0~1, 선택)
`VEHICLE_LOCAL` PARTICLE만. 생성 순간의 발생 원점 = lerp(Anchor + offset, 링크 대상 점, t). 이후 입자는 기존 규칙(호스트 차 로컬)대로 움직인다. 링크 대상이 없으면 Anchor 위치.

## 2. 기하 (`src/preview/rendering/vfx_link_strip_geometry.gd` — Game은 이 파일을 그대로 옮긴다)
1. S = 시작점, E = 끝점(호스트 source px). |E−S| ≤ 1이면 그리지 않는다.
2. inset 적용: A = S + dir·start_inset, B = E − dir·end_inset. 남은 길이 ≤ 1이면 그리지 않는다. 그 뒤 A, B에 `shift_source_px`를 더한다.
3. 처짐 방향 n = dir의 수직 (−dir.y, dir.x)에서 **호스트 뒤쪽(+Y)을 향하는 쪽**. y≈0이면 +X 쪽.
4. 점 P(u) = lerp(A, B, u) + n · sag · 4u(1−u). sag = `sag_source_px` + `LINK_SAG_OFFSET` 모듈레이션 + gap_sag × gap 진행.
5. 보이는 구간: high = min(reveal, 1 − retract). gap g > 0이면 [0, min(0.5−g/2, high)]와 [0.5+g/2, high] 두 줄. 각 구간을 ceil(segments × 구간 길이)로 나눈 polyline.
6. 렌더러: 한 줄 = Line2D 하나. `texture_repeat` 켬, joint ROUND, 블렌드는 레이어 blend_mode. 매 프레임 점 위치만 갱신(노드 생성·할당 없음).

## 3. 링크 대상 공급 (Game ③ 구현 사항)
- `VfxService.start_vehicle_effect(host, preset, inputs, {"link_target_car": target})`. `link_target`이 있는 effect는 **대상 차 없이 시작하지 않는다**(명시적 실패, 0 길이 대체 금지).
- 매 틱 끝점 = 대상 차의 `target_anchor` 월드 위치 + `target_offset`(대상 CarSprite 변환 적용) → **호스트 CarSprite `global_transform`의 역변환**으로 호스트 source px. 비균일 배율은 거부(충격파 `effect_radius`와 같은 기준).
- 대상 노드가 해제되거나 무효가 되면 effect를 강제 정리한다.

## 4. 모듈레이션
- 대상 타깃: `VISUAL_OPACITY_MULTIPLIER`, `TRANSFORM_SCALE_X`(폭), 새 `LINK_SAG_OFFSET`(ADD, LINK_STRIP 전용, 기본 0). 순서·clamp 규칙은 Runtime Modulation v1 그대로.
- 새 runtime 입력:
  - `link_distance_ratio` 0~2, 기본 0: 링크 대상과의 실제 거리 / 재능 거리(체인 바인드 D). 보간 없음.
  - `link_lock_pulse` 0~1, 기본 0: 사건형. 속도 맞춤이 시작될 때 1, 0.4초에 걸쳐 선형으로 0. 같은 차에서 1초 안에 다시 켜지지 않는다. `defense_impact`와 같은 방식.

## 5. package
- `uses_link`(LINK_STRIP 또는 `link_point_t`)인 preset은 **Runtime Definition v3** + `required_capabilities: ["LINK_TARGET_V1"]`, 본문은 v2 형식(modulation 포함). 최상위 `link_target`, 레이어 `link_point_t`를 싣는다.
- 링크 없는 짝 package(`talent.chain_bind_shackle`)는 기존 v2.
- manifest `required_vehicle_anchors`에 `source_anchor`·`target_anchor`가 포함된다.
- `LINK_TARGET_V1`을 모르는 소비자는 package를 거부한다. Studio reader(`vfx_runtime_definition_reader.gd`)는 capability를 넘겨받은 경우에만 읽는다.

## 6. Studio preview
- 링크 preset을 열면 대상 차(청색 틴트)와 "LINK TARGET" 줄이 나타난다: Fwd/Side 슬라이더(source px), Auto(0.7D↔1.45D 왕복), Lock 버튼, 비율 표시.
- `link_distance_ratio`는 앞쪽 거리 / 681 source px(D = 55 월드 px ÷ 0.08075, 기획 값 11-26. 처음엔 30 = 372였음)로 자동 계산. Auto에서 비율이 1을 넘는 순간 lock pulse.
- preview는 한 번에 preset 하나만 재생한다. 짝 package(족쇄)는 따로 열어 본다.

## 7. 검증
- `tests/preview/test_chain_bind_authoring.gd`: 아트, 3 preset, 링크 규칙 거부 3종, 기하, 렌더러, export v3 왕복·구 reader 거부.
- Game 지원·부하·사용자 경기 내 승인은 ③에서 따로 기록한다.
