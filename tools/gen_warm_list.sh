#!/usr/bin/env bash
# 生成后台预拼清单 assets/voxel/warm_list.json：把各幕各层的几种房间、山门、标题都进一遍（--warmrec），
# 记下每个区域用到的开源件、自己画的件和角色模型，汇总起来。改了场景摆设以后重跑一遍（几分钟）。
# 清单过时也不会出错：没列到的件进房间时照常现拼。
set -euo pipefail
cd "$(dirname "$0")/.."
G=${GODOT:-/root/godot/godot4}
OUT=$(mktemp -d)
jobs=()
jobs+=("title|")
jobs+=("hub|--hub")
for act in 1 2 3; do
	for fl in 0 1 2; do
		for room in fight fight elite shop treasure trial boss; do
			jobs+=("a${act}f${fl}${room}$RANDOM|--act=$act --floor=$fl --room=$room")
		done
	done
done
jobs+=("finale|--act=3 --floor=2 --room=boss --finale")
jobs+=("tutorial|--room=tutorial")
printf '%s\n' "${jobs[@]}" | xargs -P "${JOBS:-4}" -I{} bash -c '
	name="${1%%|*}"; args="${1#*|}"
	timeout 120 "$0" --headless --path . -- --warmrec="$2/$name.json" --noach --nocloud $args > "$2/$name.log" 2>&1 || echo "失败 $name"
' "$G" {} "$OUT"
python3 - "$OUT" <<'PY'
import json, glob, sys, os
zones = {}
models = []
for p in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    d = json.load(open(p))
    z = zones.setdefault(d["zone"], {"kit": [], "grids": []})
    for k in d["kit"]:
        if k not in z["kit"]:
            z["kit"].append(k)
    have = {g[1]: g for g in z["grids"]}
    for g in d["grids"]:
        if g[1] in have:
            for m in g[4]:
                if m not in have[g[1]][4]:
                    have[g[1]][4].append(m)
        else:
            z["grids"].append(g)
            have[g[1]] = g
    for m in d["models"]:
        if m not in models:
            models.append(m)
# 模型放前面，兵器放后面
models.sort(key=lambda m: 0 if m[0] == "model" else 1)
out = {"note": "tools/gen_warm_list.sh 生成，VoxelWarm 按这个提前拼网格", "zones": zones, "models": models}
json.dump(out, open("assets/voxel/warm_list.json", "w"), ensure_ascii=False, indent=1)
print("区域", {k: (len(v["kit"]), len(v["grids"])) for k, v in zones.items()}, "模型/兵器", len(models))
PY
rm -rf "$OUT"
