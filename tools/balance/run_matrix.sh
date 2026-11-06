#!/usr/bin/env bash
# 数值联调：并行跑多局机器人（每局一个进程、各用各的存档目录，互不干扰）。
# 用法：tools/balance/run_matrix.sh 矩阵文件 输出目录 [并行数=4] [每局超时秒=1500]
# 矩阵文件每行：名字|参数（# 开头是注释），例如
#   a1_sword|--act=1 --arms=sword --diff=1
# 每局都会加上 --demo=fight --mortal --tel --quitend --noach。跑完用 tools/balance/report.py 汇总。
set -uo pipefail
MATRIX=$1; OUT=$2; JOBS=${3:-4}; TMO=${4:-1500}
GODOT=${GODOT:-/root/godot/godot4}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$OUT"
run_one() {
	local name=$1; shift
	local home="$OUT/home_$name"
	rm -rf "$home"; mkdir -p "$home"
	XDG_DATA_HOME="$home" timeout "$TMO" stdbuf -oL -eL "$GODOT" --headless --fixed-fps 30 --path "$ROOT" -- \
		--demo=fight --mortal --tel --quitend --noach $@ > "$OUT/$name.log" 2>&1
	echo "done $name exit=$?"
}
export -f run_one
export OUT TMO GODOT ROOT
grep -v '^\s*#' "$MATRIX" | grep -v '^\s*$' | while IFS='|' read -r name args; do
	echo "$name $args"
done | xargs -P "$JOBS" -L 1 bash -c 'run_one "$@"' _
