# 작업 규칙 (Claude)

- 대화·중간 진행 메모·커밋 메시지는 모두 **한국어**로.
- 이 저장소는 갈매미맨 랜덤 디펜스의 **고도(Godot 4.7) 판**이에요. 웹 판 원본은 서버 저장소(`chatbotgmm/server`, `galmaegiman-confirmed/public/defense`)에 있어요.
- 밸런스 수치는 웹 판 `engine.js` 한 곳에서만 고치고 `node tools/export_data.mjs`로 `data/game_data.json`을 다시 뽑아요(이 JSON을 손으로 고치지 않기).
- 규칙(`scripts/engine/engine.gd`)을 고치면 `tools/compare.sh`로 웹 판과 같은 결과인지 확인해요(모두 같아야 커밋).
- 위치 계산에 `Vector2`(32비트)를 쓰지 않아요 — 웹 판과 결과가 갈라져요(README 참고).
- **빌드(웹·앱 내보내기) 전에 디자인 검토를 꼭 해요**: `scripts/test/shot.gd`로 가로 915×412·1280×720 캡처 → 한 장씩 직접 보고(글자 읽힘·겹침·잘림·같은 요소 모양·색 규칙: 서버 저장소 `galmaegiman-confirmed/docs/UI-COLOR.md`) → 고친 뒤 다시 찍어 확인 → 보고할 때 「검토에서 찾아 고친 것」을 적어요.
