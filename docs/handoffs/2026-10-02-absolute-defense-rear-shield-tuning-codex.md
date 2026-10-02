# 절대 방어 — 뒤 방어막 확대·밝기 조정 재적용 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 이전: `docs/handoffs/2026-10-02-absolute-defense-codex-handoff.md`

## 0. 요약

- 사용자 요청: Game 적용 후 **뒤쪽 방어막을 조금 더 크고 잘 보이게**.
- Studio 변경(뒤 방어막만): scale 1.0 → **1.2**(호 양 끝 ±130 → ±156, 양옆 벽 ±150과 이어져 차 뒤 U자), 위치 (0, +240) → **(0, +248)**, pivot (0, −40) → **(0, −48)**, 평소 opacity 0.55 → **0.75**, 일렁임 하한 ×0.7 → **×0.8**. 시작 섬광·종료 페이드 파티클도 같은 비율(크기 192→228 / 192, 종료 알파 0.5 → 0.7).
- `defense_impact` 변조(불투명도 ×1→2.2, 폭 ×1→1.3, 뒤로 ×1→1.65)·벽·입력 계약은 그대로. 텍스처 byte 동일. ID·버전 동일(Package 1 / Runtime v2).

## 1. 교체할 전달물 (Studio `exports/packages/talent.absolute_defense/`, REPLACE_EXISTING — byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 | 변경 |
|---|---:|---|---|
| `manifest.json` | 2728 | 6485c43fdf38 | 변경 |
| `assets/talent_absolute_defense_rear_shield.png` | 32051 | a02f49366085 | 동일 |
| `assets/talent_absolute_defense_side_wall_a.png` | 30003 | b86dfb7be4d8 | 동일 |
| `assets/talent_absolute_defense_side_wall_b.png` | 30246 | 13ee7002bc07 | 동일 |
| `runtime/vfx_runtime_definition_v2.json` | 21574 | 615e1024d1aa | 변경 |
| `source/talent.absolute_defense.vfx.json` | 19895 | 9c00b46a3291 | 변경 |

## 2. Codex 요청 작업

1. package 파일 교체, 해시 기록 갱신. 방어막 위치·크기를 고정해 둔 Game 테스트가 있으면 새 값으로 정리.
2. `defense_impact` 공급은 그대로.

## 3. 확인 요청

1. 뒤 방어막이 양옆 벽과 이어져 차 뒤를 감싸는지, 방어 성공 때 번쩍임이 그대로인지.
2. 커진 방어막(폭 ≈ ±156, 뒤로 ≈ +288)이 뒤차를 과하게 가리지 않는지.
3. **부하 측정은 하지 않아도 된다**(Claude 측정 — 이전 적용분: 6대 발동 +0.05ms, draw +29).

## 4. 다음 담당자

- **Codex**: 2 교체 → 3 확인 → 공통 인계 형식 보고.
- **사용자**: 재적용 후 외형 최종 확인.
- 변경하지 말 것: 재능 판정·방어 규칙, 다른 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
