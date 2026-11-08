#!/usr/bin/env bash
# 云端（Linux）导出网页版，和 build-web.cmd 做的事一样：导出 index.*、复制 landing.html、复制配乐到 music/。
# 用法：bash tools/build_web.sh [输出目录，默认 dist]；要先装好 4.7.2 的 web_nothreads 导出模板。
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-dist}"
GODOT="${GODOT_BIN:-/root/godot/godot4}"
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release Web "$OUT/index.html"
for f in index.html index.js index.wasm index.pck; do [ -f "$OUT/$f" ] || { echo "缺 $f"; exit 1; }; done
[ -f landing.html ] && cp landing.html "$OUT/landing.html"
mkdir -p "$OUT/music" && cp assets/music/*.ogg "$OUT/music/"
du -sh "$OUT"/index.pck "$OUT/music"
