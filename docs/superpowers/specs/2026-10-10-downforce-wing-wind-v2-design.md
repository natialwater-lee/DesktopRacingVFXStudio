# 다운포스 윙 바람(Downforce Wing Wind) v2 설계

2026-10-10. 사용자 요청: 윙 장비에 붙는 바람 VFX 개선 검토 → 제안 A+B+C 진행 승인(D 시작 연출·E 전개 시작은 보류).
대상: `equipment.downforce_wing.wind_streak` (ID 유지). Game 연결(`SuperBoosterVfxIntegrationController`의 장비 경로)은 그대로다.

## 1. 현재 상태와 문제 (2026-10-10 검토)

- 알파 PARTICLE 4개(좌우 main·fine), x ±220, 고속 바람 뒤 줄기와 같은 `fx.speed_wind_streak`. 런타임 입력 없음. START 2발, END 비어 있음.
- 윙은 ±305 폭(날개 끝 y −85~+40, 뒷날개 끝 y +160@x±100, +110@x±220, +40@x±300)인데 바람은 두 줄뿐이고 윙 모양과 무관하다. 날개 끝 와류가 없다.
- 고속 바람과 같은 텍스처·방향이라 속도 70% 이상에서 겹치면 구분이 안 된다.
- 입력이 없어 커브/속도와 무관하고, 파티클은 갑자기 나타난다.
- 게임 크기: 윙 약 55px, 차 23px. 선 폭은 2~3px.
- 윙은 급커브 직전에만 자동 발동(속도비 ≥0.55)하므로 활성 시간 대부분 `turn_rate_normalized`가 0이 아니다.

## 2. 구성 (A+B+C)

모든 연속 레이어는 LOOP **TEXTURED_SPRITE**(UNDER_VEHICLE, ALPHA, 청백 틴트가 아닌 텍스처 색 그대로). START에는 같은 소스를 쓰는 복사본을 둬서 LOOP로 이어질 때 튀지 않게 하고, END는 날개 끝 줄기 PARTICLE 2개로 꼬리를 남긴다.

| 그룹 | 레이어 | 텍스처 | x | 중요도 | 움직임 |
| --- | --- | --- | --- | --- | --- |
| A 날개 끝 줄기 | `tip_a_l/r` | **신규** `fx.downforce_tip_streak_a` | ∓300 | CORE | 날개 끝에 고정, 길이 호흡·투명도 깜박임·좌우 흔들림 |
| A | `tip_b_l/r` | **신규** `fx.downforce_tip_streak_b` | ∓296 | DETAIL | 같은 모양을 다른 주파수로 (A와 번갈아 보임) |
| B 뒷날개 끝 공기 막 | `sheet_1_l/r` | 재사용 `fx.speed_wind_flow_a` | ∓165 | DETAIL | 톱니 이동 + sin² 투명도(고속 바람 v2 옆선 방식), 꼬리 쪽 안쪽으로 30px 모임 |
| B | `sheet_2_l/r` | 재사용 `fx.speed_wind_flow_b` | ∓225 | EXTRA | 위와 같고 주파수만 다름 |

- 고속 바람 옆선(x ∓122/136)과 겹치지 않도록 B는 ±165/±225에 둔다. 고속 바람 뒤 줄기(x≈0)와도 겹치지 않는다.
- A 줄기는 날개 끝(±300, 뒷날개 끝 y≈+40)에서 뒤로 약 380px 뻗고 안쪽으로 5° 기운다. 머리 부분이 윙 밑에 일부 가려지고(UNDER_VEHICLE z −20 < 장비 z −10) 뒷날개 끝 바깥에서 나타난다.
- LOD: HIGH 8층, MEDIUM 6층(CORE+DETAIL), LOW 2층(CORE).

## 3. C 커브·속도 연동

런타임 입력: `turn_rate_normalized`, `speed_normalized` (VfxService가 선언된 입력만 공급, Game 변경 없음).

- 커브 바깥쪽 윙(우회전이면 왼쪽)이 더 세게 일한다. 왼쪽 레이어: 입력 −1 → +1을 투명도 ×0.85 → ×1.25, 길이(SCALE_Y) ×0.92 → ×1.12로 매핑. 오른쪽은 반대. 전체 범위 매핑이라 Studio 프리뷰(클램프 없음)와 Game(클램프)이 같다.
- 속도: `speed_normalized` 0 → 1을 투명도 ×0.6 → ×1.0 (윙 발동 하한 0.55에서 ×0.83).
- 한 번에 한 가지만 약하게: 커브 효과는 처음에 위 값으로 두고, 사용자 피드백으로 10~30% 단위 조정한다.

## 4. START / END

- START 0.16초: 모든 층의 복사본. A는 `LINEAR_PHASE`(6.25 Hz, 효과 시작 기준 0 → 1)로 0.16초 동안 0 → 1 페이드인해 LOOP 시작 값과 이어진다.
- END 0.16초: `end.tip_l/r` PARTICLE(날개 끝 줄기 텍스처, 수명 0.4초, 투명도 0.5 → 0, 뒤로 260px/s)로 꼬리를 남긴다. B 층은 LOOP 종료 때 사라진다(윙이 접히는 0.5초 동안 약한 층이라 허용).

## 5. 아트 (GPT 요청: `docs/handoffs/2026-10-10-downforce-wing-gpt-art-request.md`)

신규 2장: `downforce_tip_streak_a.png`, `downforce_tip_streak_b.png` (64×384). 수령 전에는 `speed_wind_flow_b`(180° 회전)를 임시로 쓴다. 수령 후 에셋 카탈로그·export 정책 등록, 임시 회전 제거.

## 6. 성능

LOOP 스프라이트 8 + START 복사 8(0.16초만) + END 파티클 2. 기존 파티클 4개(최대 10개) 대신 스프라이트로 바뀌어 연속 파티클 용량은 줄어든다.

## 7. 호환·테스트

- Runtime v2(modulation), `runtime_inputs`: `turn_rate_normalized`, `speed_normalized`. ID·카탈로그 변경 없음.
- Studio `test_downforce_wing_authoring.gd`: 기존 "고속 바람 파티클 값 동일" 검증을 새 구조에 맞게 압축 재작성한다. Game `DownforceWingVfxIntegrationTest.gd`: "LOOP 렌더러 4개" 기대 수정.
- 사용자 승인 전에는 이 preset의 단일 테스트와 캡처 1회만 실행한다.

## 8. 1차 검토 반영 (2026-10-10)

사용자 녹화(Studio 프리뷰)를 보고 조정했다. 날개 끝 줄기(A)는 의도대로 읽혔고, 공기 막(B)은 윙 밑에 가려져 긁힌 선처럼 보여 약했다.

- A: 아트 2장 적용(가로 ×1.5, 투명도 0.8/0.6). 안쪽 기울기 5° → 9°(머리가 날개 끝 x ±300에 오도록 중심 x ∓270/∓266).
- B: 바깥 줄(`sheet_2`) 삭제. `sheet_1`은 가로 0.8 → 1.12(×1.4), 투명도 0.5 → 0.6.
- LOD: HIGH 6층(CORE 2 + DETAIL 4), MEDIUM 6층, LOW 2층. START 복사 6층, END 파티클 2개.
- Studio 프리뷰는 속도 입력 0이면 속도 이득이 ×0.6이다. Game은 속도 55% 이상에서 ×0.83 이상이라 녹화보다 밝게 보인다. 밝기는 Game에서 확인한 뒤 조정한다.
