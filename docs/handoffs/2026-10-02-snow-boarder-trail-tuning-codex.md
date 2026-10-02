# 스노우 보더 / Snow Boarder — 빛줄기·결정 조정 재적용 (Studio → Codex)

2026-10-02 · 작성: Claude (Studio 담당) · 대상: Game Codex · 이전 인계: `docs/handoffs/2026-10-02-snow-boarder-codex-handoff.md`

## 0. 요약

사용자·Claude가 Game 적용 녹화(밤·눈 경기)를 검토했다. 빛줄기가 연속 곡선으로 남는 것은 좋지만 ① 흰 바퀴/스키 자국처럼 보여 "빛나는 서리" 느낌이 약하고 ② 꼬리가 차 길이 절반 정도로 짧으며 ③ 얼음 결정 반짝임이 보이지 않았다. Studio에서 아래만 바꿔 package를 REPLACE_EXISTING으로 다시 만들었다. 텍스처 3장 byte 동일, 계약·코드 변경 없음, package ID·버전 동일(Package 1 / Runtime v1).

| layer | 이전 | 변경 |
|---|---|---|
| `loop.trail_left` / `_right` | 수명 0.45s, max 9, 색 곱 흰색 | **수명 0.7s, max 13, 색 곱 (0.7, 0.93, 1.0)** |
| `loop.glint_left` / `_right` | 크기 80→24, 색 곱 흰색 | **크기 140→40, 색 곱 (0.75, 0.95, 1.0)** |

START(눈가루·결정 burst)·END는 변경 없음. 차량당 스프라이트 LOOP 최대 24 → **32**(빛줄기 26 + 결정 6).

## 1. 교체할 전달물 (Studio `exports/packages/talent.snow_boarder/`, byte 그대로 교체)

| 파일 | byte | sha256 앞 12자 | 변경 |
|---|---:|---|---|
| `manifest.json` | 2628 | 551adfccbc70 | 변경 |
| `assets/talent_snow_boarder_frost_trail.png` | 8305 | 09df9a298fa8 | 동일 |
| `assets/talent_snow_boarder_ice_glint.png` | 759 | 34e05b94841a | 동일 |
| `assets/talent_snow_boarder_powder_fan.png` | 31454 | 272d93c6819a | 동일 |
| `runtime/vfx_runtime_definition_v1.json` | 12237 | c5f330d01929 | 변경 |
| `source/talent.snow_boarder.vfx.json` | 11865 | 40a16f1a3f81 | 변경 |

## 2. Codex 요청 작업

1. package 파일 교체(`res://assets/vfx/packages/talent.snow_boarder/`), package 해시를 참조하는 기록이 있으면 갱신.
2. 이 package의 수명·max 수치를 고정해 둔 Game 테스트·probe가 있으면 새 값으로 정리.

## 3. 확인 요청

1. **빛줄기 실측**: 직선·코너에서 꼬리 길이(px)·조각 간격, 연속선 유지 여부. 수명 0.7s로 꼬리가 약 1.5배가 되었는지.
2. **색**: 눈 트랙 위에서 흰 바퀴 자국과 구분되는 옅은 얼음 청록 빛으로 보이는지(밤·낮 각각 가능하면).
3. **결정 반짝임**: 크기 140에서 보이는지. 여전히 안 보이면 그대로 보고(Studio에서 제거 예정).
4. **발동 순간 눈가루**: 이전 녹화는 컷인에 가려 판단 못 함. 컷인 밖에서 보이는지.
5. **부하**: 빛줄기 max 9 → 13으로 늘었다. 20대 다수 동시 발동 frame·draw call 변화.

## 4. 검증

- Claude 실행: Studio 검증기·export(REPLACE_EXISTING), repo preset = package `source` byte 동일 — preview 436 / export contract 70 / performance 61 assertions 실패 0.
- Claude 미실행: Game 실행·테스트·성능.

## 5. 다음 담당자

- **Codex**: 2 교체 → 3 확인 → 공통 인계 형식 보고. 외형 수정은 Studio로.
- **사용자**: 재적용 후 눈 경기 녹화(가능하면 차 확대) → Claude.
- 변경하지 말 것: 재능 판정·확률·지속시간, 다른 재능·날씨 VFX, 저장 데이터, 관리 메뉴 조작성(방치형 원칙). 승인 없는 commit 금지.
