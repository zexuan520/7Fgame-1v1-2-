#!/usr/bin/env bash
# 云端会话用：下载官方 Godot 4.7.2 到 /root/godot/godot4（只下一次），用来无界面跑测试、导出网页版。
set -euo pipefail
DEST=/root/godot
if [ -x "$DEST/godot4" ]; then echo "已有 $DEST/godot4"; exit 0; fi
mkdir -p "$DEST"
curl -sSLo "$DEST/godot.zip" https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -oq "$DEST/godot.zip" -d "$DEST"
mv "$DEST/Godot_v4.7.2-stable_linux.x86_64" "$DEST/godot4"
rm "$DEST/godot.zip"
chmod +x "$DEST/godot4"
echo "装好了：$DEST/godot4"
