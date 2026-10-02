# 하위권의 반란 / Underdog Revolt — 연출 합의 및 설계

2026-10-02 · 설계·Studio 제작·리소스 검수: Claude · 아트: GPT · Game 적용: Codex · 승인: 사용자(방향 승인, Studio 시안 승인 2026-10-02)

## 1. Game 정의 (읽기 전용 확인)

- `race_ability_defs.json` → `underdog_revolt`: trigger `rank_at_or_worse_for_duration`(일반 8위 이하 / 그랑프리 16위 이하 8초), activation_chance 0.3, duration 12초(밸런스 가변), effect: 최고 속도·가속·코너·브레이크 ×1.08.
- legacy `red_breakthrough`(`vehicle_fx_id`·`visual_profile_id`·`player_screen_fx_id`) — **분노의 추월과 공유**.
- 의미: **뒤처진 차가 전 능력을 끌어올려 치고 올라간다.**
- 연결 필요(Codex): `ABILITY_PRESET_IDS`에 `"underdog_revolt": "talent.underdog_revolt"`, catalog, legacy 억제(분노의 추월과 공유 — 이 재능만 억제되는지 확인, 독주·샌드위치 탈출 `gold_speed` 공유 처리와 같은 방식).

## 2. 참고 자료

- 컷인 `underdogrevolt.mp4`(4.0초) + 컨셉 이미지: 1.0s 차 둘레 붉게 달아오름·배기 불꽃 → 1.4s~ 붉은 빛줄기가 차 양옆을 따라 앞으로 뻗음(끝 화살촉), 불티.
- 생략: 차 둘레를 감싸는 붉은 막(분노의 추월 균열 오라와 혼동), 배기 불꽃(일반 부스터와 겹침), 앞쪽 화살(샌드위치 탈출 금빛 화살과 혼동).

## 3. 합의한 연출 — "불길처럼 치고 오른다"

| 구간 | 연출 | 구현(예정) |
|---|---|---|
| START ≈0.6s | 차 뒤에서 불티가 확 피어오름 + 붉은 불꽃 줄기 두 개가 차 양옆을 따라 뒤→앞으로 한 번 쏘아짐 | PARTICLE BURST(불티 덩어리) + BURST(불꽃 줄기 좌·우, 앞으로 이동) |
| LOOP 12s(가변) | ① 차 양옆 붉은 주황 불꽃 줄기가 뒤→앞으로 계속 흐름(옅게 겹쳐 연속) ② 차 뒤쪽 작은 불티가 드문드문 튀며 떠오름 | PARTICLE(줄기 좌·우, 방향 0°) + PARTICLE(불티, `fx.furious_overtake_spark` 주황 색 곱, DETAIL) |
| END 0.3s | 자연 소진 | 빈 phase |

- 색: 붉은 주황(1.0, 0.4, 0.15), 불꽃 심 노랑(1.0, 0.85, 0.4). 분노의 추월 진홍(색 곱 1.0, 0.45, 0.4)보다 주황 쪽. 전 레이어 ADDITIVE·UNDER_VEHICLE.
- 구분: 분노의 추월 = 차를 **감싸는** 진홍 균열 + 차 뒤 빛줄기 / 윈드 레이서 = 흰 기류선 **앞→뒤** / 샌드위치 탈출 = 앞코 **앞쪽** 금빛 화살 ↔ 하위권의 반란 = 차 **옆**을 따라 **뒤→앞**으로 흐르는 붉은 주황 불꽃 + 뒤쪽 불티.
- 교훈 적용: 텍스처 기반, 이동 파티클은 옅게 겹쳐 연속(rate×life ≥3, 알파 ≤0.6), START→LOOP 연결, 길이 무관 LOOP, 작은 반짝임 대신 충분히 큰 불티.

## 4. 아트 리소스

요청: [GPT 아트 요청](../../handoffs/2026-10-02-underdog-revolt-gpt-art-request.md) — 2장.
`talent_underdog_revolt_flame_streak.png`(64×320), `talent_underdog_revolt_ember_burst.png`(256×256). 작은 불티는 `fx.furious_overtake_spark` 재사용.

## 5. 다음 작업

1. 사용자: GPT 아트 요청(컷인 캡처 첨부).
2. Claude: PNG 검수 → 등록 → preset → Studio 시안.
3. 승인 → 테스트 → package → Codex 인계 → Claude 부하 측정.

## 6. 최종 수치·시안 이력 (Studio 시안 승인 2026-10-02)

- 최종 수치: 인계 `docs/handoffs/2026-10-02-underdog-revolt-codex-handoff.md` 3절.
- 이력: 1) 줄기가 차체에 바짝 붙고 짧고 옅어 옆구리 불꽃처럼 보임, 불티 덩어리 작음 → 줄기 x ±132→±150, 크기 150→210, 알파 0.6→0.8, 수명 0.6→0.75s(4/s), 불티 덩어리 190→260. 2) **승인**.
