class_name ArpgSkills
extends RefCounted
## 悟道（局内等级）、技能分支、连携、双修。
##   悟道：斩敌得“悟”（按敌人的铜钱值算），攒满升一重，每重得 1 点天赋点。点数用在技能分支上，一局结束清零。
##   技能分支：连招第四段 / 翻滚 / 突进斩 / 光束斩 / 血爆 各有两条分支，同一招只能走一条（先点的那条锁定），每条三级。
##   连携：放完一招后在一小段时间里接另一招，触发额外效果（金色横幅 + 专属特效）。
##   双修：两个相邻流派的心法各有 2 个，得到一个组合效果（和三个同流派的“大成”不冲突）。
## 分支和双修都写成 stats 表里的键（sk_<分支 id> = 级数、duo_<id> = 1），Hero.apply_stats 读出来。

## 悟道：从第 1 重开始，升到下一重要 need(重数) 点悟
const MAX_LEVEL := 20


static func need(level: int) -> int:
	return 16 + 10 * level


## 五招，每招两支。ranks 是每一级的说明（点到第几级就生效到第几级）
const SKILLS := [
	{"id": "combo", "name": "收势", "full": "连招第四段", "glyph": "斩", "color": Color(0.55, 0.9, 1.0), "branches": [
		{"id": "wave", "name": "破风", "brief": "第四段挥出一道飞行剑气，穿透一条直线",
			"ranks": ["剑气伤害 18，飞 9 米", "伤害 26，飞 11 米", "伤害 34，飞 13 米，命中叠 2 层出血"]},
		{"id": "vortex", "name": "回风", "brief": "第四段把身边的敌人卷到面前，再补一刀",
			"ranks": ["卷入 4.5 米内，补 8 伤害", "卷入 5.5 米内，补 12 伤害", "卷入 6.5 米内，补 16 伤害，回 10 气力"]},
	]},
	{"id": "roll", "name": "翻滚", "full": "翻滚", "glyph": "滚", "color": Color(0.75, 0.55, 1.0), "branches": [
		{"id": "decoy", "name": "影遁", "brief": "翻滚起点留一道影子，片刻后炸开（每 1.5 秒最多一次）",
			"ranks": ["炸 14 伤害，半径 2.6 米", "炸 20 伤害，半径 3 米", "炸 26 伤害，半径 3.4 米，敌人愣住"]},
		{"id": "slice", "name": "踏风", "brief": "翻滚穿过敌人时顺手划一刀，叠 1 层出血",
			"ranks": ["每个敌人 8 伤害", "每个敌人 12 伤害", "每个敌人 16 伤害，每划中一个回 6 气力"]},
	]},
	{"id": "dash", "name": "突进斩", "full": "突进斩", "glyph": "突", "color": Color(1.0, 0.92, 0.45), "branches": [
		{"id": "thunder", "name": "雷切", "brief": "突进后片刻，路径上落雷再斩一次",
			"ranks": ["落雷 50% 伤害", "落雷 75% 伤害", "落雷 100% 伤害，敌人麻痹 1 秒"]},
		{"id": "echo", "name": "连闪", "brief": "突进斩之后 1.5 秒内可以不等冷却再闪一次",
			"ranks": ["多闪一次", "多闪一次，冷却 -15%", "多闪一次，冷却 -30%，第二闪伤害 +40%"]},
	]},
	{"id": "beam", "name": "光束斩", "full": "光束斩", "glyph": "光", "color": Color(0.6, 1.0, 1.0), "branches": [
		{"id": "split", "name": "裂空", "brief": "光束一分为三，扇形斩出",
			"ranks": ["两侧光束 45% 伤害", "两侧 60% 伤害", "两侧 75% 伤害，满气只要 85"]},
		{"id": "burn", "name": "长明", "brief": "光束在地上烧出一道光痕，站在上面的敌人持续挨烫",
			"ranks": ["光痕 3 秒，每 0.5 秒 6 伤害", "4 秒，每次 9 伤害", "5 秒，每次 12 伤害，叠出血"]},
	]},
	{"id": "finish", "name": "血爆", "full": "终结技", "glyph": "终", "color": Color(1.0, 0.35, 0.35), "branches": [
		{"id": "lotus", "name": "血莲", "brief": "每个被引爆的敌人把血溅给 3.5 米内的其他敌人",
			"ranks": ["溅 2 层出血", "溅 3 层出血", "溅 4 层出血，冷却 -15%"]},
		{"id": "drink", "name": "饮血", "brief": "每引爆一层出血回复生命，冷却更短",
			"ranks": ["每层回 1 生命，冷却 -10%", "每层回 1.5，冷却 -20%", "每层回 2，冷却 -30%"]},
	]},
	# 新技能：秘技（O 键 / 触屏“秘” / 手柄十字键右）。四选一，一局只能学一种
	{"id": "art", "name": "秘技", "full": "秘技", "glyph": "秘", "color": Color(1.0, 0.7, 0.35), "new": true, "branches": [
		{"id": "whirl", "name": "旋风", "brief": "原地化作一阵刀旋风，转的时候还能走，周围的敌人被连砍",
			"ranks": ["转 1.4 秒，每下 6 伤害，冷却 9 秒", "每下 8 伤害，转 1.7 秒", "每下 10 伤害，转 2 秒，把敌人往里吸"]},
		{"id": "disc", "name": "飞轮", "brief": "掷出一枚回旋飞刃，飞出去再飞回来，往返都伤人",
			"ranks": ["每趟 16 伤害，冷却 6 秒", "每趟 22 伤害，飞得更远", "每趟 28 伤害，一次掷两枚"]},
		{"id": "quake", "name": "震岳", "brief": "跃起砸地，震飞一圈敌人并让他们愣住",
			"ranks": ["半径 4 米，30 伤害，冷却 8 秒", "半径 4.5 米，40 伤害", "半径 5 米，50 伤害，地上裂出火缝"]},
		{"id": "clone", "name": "分身", "brief": "召出一道影分身跟在身边，自己找最近的敌人出刀",
			"ranks": ["留 6 秒，每刀 8 伤害，冷却 14 秒", "留 8 秒，每刀 11 伤害", "留 10 秒，每刀 14 伤害，刀刀叠出血"]},
	]},
]

## 秘技冷却（秒）
const ART_CD := {"whirl": 9.0, "disc": 6.0, "quake": 8.0, "clone": 14.0}

## 连携：放完 from 之后 win 秒内放 to
const LINKS := [
	{"id": "shunyu", "name": "瞬狱", "from": "dash", "to": "finish", "win": 1.6, "color": Color(1.0, 0.25, 0.25),
		"desc": "突进斩 → 血爆：突进路上斩过的敌人先叠 3 层出血再一起引爆，血爆范围变大"},
	{"id": "canyue", "name": "残月", "from": "roll", "to": "dash", "win": 1.1, "color": Color(0.8, 0.65, 1.0),
		"desc": "翻滚 → 突进斩：突进远四成，落地斩出一轮满月，周围的敌人都挨刀"},
	{"id": "fenxue", "name": "焚血", "from": "beam", "to": "finish", "win": 2.2, "color": Color(1.0, 0.6, 0.25),
		"desc": "光束斩 → 血爆：被光束照到的敌人不出血也能引爆（算 3 层）"},
	{"id": "tianluo", "name": "天落", "from": "combo", "to": "beam", "win": 1.2, "color": Color(1.0, 0.95, 0.6),
		"desc": "连招第四段 → 光束斩：出手快一倍，光束更宽、伤害 +30%，天上落下光柱"},
	{"id": "xuebu", "name": "血步", "from": "finish", "to": "dash", "win": 1.6, "color": Color(0.95, 0.15, 0.3),
		"desc": "血爆 → 突进斩：突进伤害 +50%，叠 3 层出血，返还一半冷却"},
	{"id": "fenglei", "name": "风雷", "from": "dash", "to": "art", "win": 1.6, "color": Color(1.0, 0.9, 0.4),
		"desc": "突进斩 → 秘技：秘技伤害 +50%，身边劈下三道雷"},
	{"id": "guiyi", "name": "归一", "from": "art", "to": "finish", "win": 2.0, "color": Color(1.0, 0.55, 0.3),
		"desc": "秘技 → 血爆：被秘技打中的敌人不出血也能引爆（算 4 层）"},
]

## 双修：两个流派的心法各 2 个
const DUALS := [
	{"id": "xueren", "name": "血刃", "a": "修罗", "b": "血", "desc": "会心命中多叠 2 层出血"},
	{"id": "xueying", "name": "血影", "a": "血", "b": "风", "desc": "翻滚穿过的敌人叠 2 层出血"},
	{"id": "liuguang", "name": "流光", "a": "风", "b": "光", "desc": "每次翻滚回 6 气力"},
	{"id": "mingjing", "name": "明镜", "a": "光", "b": "守", "desc": "光束斩之后 4 秒受伤 -40%"},
	{"id": "budong", "name": "不动明王", "a": "守", "b": "修罗", "desc": "生命高于七成时伤害 +20%"},
]
const DUAL_NEED := 2


static func skill(id: String) -> Dictionary:
	for s: Dictionary in SKILLS:
		if s["id"] == id:
			return s
	return {}


static func branch(bid: String) -> Dictionary:
	for s: Dictionary in SKILLS:
		for b: Dictionary in s["branches"]:
			if b["id"] == bid:
				return b.merged({"skill": s["id"], "skill_name": s["name"], "color": s["color"]})
	return {}


static func link(id: String) -> Dictionary:
	for l: Dictionary in LINKS:
		if l["id"] == id:
			return l
	return {}


## 这一招现在走的是哪一支（没点返回 ""）
static func chosen_branch(ranks: Dictionary, skill_id: String) -> String:
	for b: Dictionary in skill(skill_id)["branches"]:
		if int(ranks.get(b["id"], 0)) > 0:
			return String(b["id"])
	return ""


## 能不能再点一级："" 表示可以，否则是原因
static func why_not(ranks: Dictionary, points: int, bid: String) -> String:
	var b := branch(bid)
	var r := int(ranks.get(bid, 0))
	if r >= (b["ranks"] as Array).size():
		return "已满"
	var cb := chosen_branch(ranks, String(b["skill"]))
	if cb != "" and cb != bid:
		return "已走「%s」" % branch(cb)["name"]
	if points <= 0:
		return "没有天赋点"
	return ""


## 还有没有能点的
static func any_open(ranks: Dictionary, points: int) -> bool:
	if points <= 0:
		return false
	for s: Dictionary in SKILLS:
		for b: Dictionary in s["branches"]:
			if why_not(ranks, points, String(b["id"])) == "":
				return true
	return false


## 这些心法凑成了哪些双修
static func duals_of(boons: Array) -> Array:
	var sc := ArpgData.school_counts(boons)
	var out := []
	for d: Dictionary in DUALS:
		if int(sc.get(d["a"], 0)) >= DUAL_NEED and int(sc.get(d["b"], 0)) >= DUAL_NEED:
			out.append(String(d["id"]))
	return out


static func dual(id: String) -> Dictionary:
	for d: Dictionary in DUALS:
		if d["id"] == id:
			return d
	return {}


## 写进 stats 表
static func add_stats(st: Dictionary, ranks: Dictionary, boons: Array) -> void:
	for k: String in ranks:
		if int(ranks[k]) > 0:
			st["sk_" + k] = float(ranks[k])
	for d: String in duals_of(boons):
		st["duo_" + d] = 1.0
