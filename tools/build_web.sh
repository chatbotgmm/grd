#!/usr/bin/env bash
# 웹 빌드: export/web/에 index.html·index.js·index.wasm·index.pck를 만든다(단일 스레드라 서버에 특별한 헤더가 필요 없음).
# 처음 한 번 고도 「내보내기 틀」이 있어야 해요: 편집기 메뉴 편집기 → 내보내기 템플릿 관리 → 받기
#   (또는 Godot_v4.7.2-stable_export_templates.tpz에서 web_nothreads_release.zip·web_nothreads_debug.zip·version.txt를
#    ~/.local/share/godot/export_templates/4.7.2.stable/ 에 넣기)
# 사용(이 저장소 맨 위에서): GODOT=<고도 실행 파일> bash tools/build_web.sh
# 서버에 올릴 때: .wasm·.pck는 크니(약 39MB·32MB) gzip/brotli 압축을 켜 두면 받는 양이 크게 줄어요(.wasm은 약 1/4).
set -euo pipefail
GODOT="${GODOT:?고도 실행 파일 경로를 GODOT에 넣어 주세요}"
cd "$(dirname "$0")/.."
mkdir -p export/web
"$GODOT" --headless --path . --export-release "Web" export/web/index.html
ls -la export/web
echo "확인: (cd export/web && python3 -m http.server 8788) 뒤 브라우저에서 http://localhost:8788"
