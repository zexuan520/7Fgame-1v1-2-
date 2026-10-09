class_name Talents
extends RefCounted
## 天赋树：局外永久成长，在破庙拾骨婆那里用魂玉点亮，随时可以免费洗掉重点。
## 三棵树：修罗（攻）、不动（守）、行者（运）。每棵四层，每层三个节点；
## 往这棵树里投够 UNLOCK[层] 点才能点下一层；第四层“奥义”三选一，点了一个另外两个就锁上。
##
## 节点字段：id、name、desc（%s 换成每级数值）、max 最多几级、stats 每级加到 stats 表里的数值

const UNLOCK := [0, 3, 6, 10]            # 解锁第 1-4 层需要这棵树里已投入的点数
const COSTS := [3, 6, 10, 20]            # 每层每级的魂玉价格

const TREES := [
	{"id": "shura", "name": "修罗", "role": "攻", "color": Color("e05a48"), "tiers": [
		[
			{"id": "sharpen", "name": "磨刃", "desc": "攻击 +4%", "max": 3, "stats": {"atk": 0.04}},
			{"id": "break", "name": "破势", "desc": "架势伤害 +6%", "max": 3, "stats": {"pdmg": 0.06}},
			{"id": "keen", "name": "锐眼", "desc": "会心率 +3%", "max": 3, "stats": {"crit": 0.03}},
		], [
			{"id": "gather", "name": "蓄势", "desc": "重劈蓄力快 0.1 秒", "max": 2, "stats": {"charge": 0.1}},
			{"id": "thirst", "name": "嗜血", "desc": "处决后回复 10% 生命", "max": 1, "stats": {"exec_heal": 0.1}},
			{"id": "flurry", "name": "连斩", "desc": "五连第 4、5 刀伤害 +25%", "max": 1, "stats": {"combo_end": 0.25}},
		], [
			{"id": "vital", "name": "会心", "desc": "会心伤害 +25%", "max": 2, "stats": {"crit_dmg": 0.25}},
			{"id": "intent", "name": "刃意", "desc": "回旋斩少耗 5 刃意", "max": 2, "stats": {"art_cost": 5.0}},
			{"id": "press", "name": "追命", "desc": "敌人架势过半时伤害 +15%", "max": 1, "stats": {"pressure": 0.15}},
		], [
			{"id": "asura", "name": "修罗道", "desc": "生命低于 50% 时伤害 +30%", "max": 1, "ult": true, "stats": {"low_dmg": 0.3}},
			{"id": "ironcut", "name": "斩铁", "desc": "重劈和落雷斩伤害 +50%", "max": 1, "ult": true, "stats": {"heavy_dmg": 0.5}},
			{"id": "bloodblade", "name": "血刃", "desc": "命中回复伤害的 4% 生命", "max": 1, "ult": true, "stats": {"lifesteal": 0.04}},
		],
	]},
	{"id": "fudo", "name": "不动", "role": "守", "color": Color("6aa8f0"), "tiers": [
		[
			{"id": "vigor", "name": "体魄", "desc": "生命 +20", "max": 3, "stats": {"hp": 20.0}},
			{"id": "calm", "name": "定心", "desc": "架势上限 +10", "max": 3, "stats": {"max_posture": 10.0}},
			{"id": "hide", "name": "坚甲", "desc": "防御 +3", "max": 3, "stats": {"def": 3.0}},
		], [
			{"id": "mirror", "name": "明镜", "desc": "弹反窗口 +0.01 秒", "max": 2, "stats": {"parry": 0.01}},
			{"id": "gourd", "name": "药缘", "desc": "药罐 +1", "max": 2, "stats": {"gourds": 1}},
			{"id": "breath", "name": "回气", "desc": "架势回落快 15%", "max": 2, "stats": {"posture_rec": 0.15}},
		], [
			{"id": "wall", "name": "铁壁", "desc": "格挡时架势增长 -12%", "max": 2, "stats": {"block_posture": -0.12}},
			{"id": "elixir", "name": "灵药", "desc": "药罐回复量 +10%", "max": 2, "stats": {"gourd_heal": 0.1}},
			{"id": "shake", "name": "震刀", "desc": "弹反时敌人架势伤害 +30%", "max": 1, "stats": {"parry_posture": 0.3}},
		], [
			{"id": "undying", "name": "不死身", "desc": "每局倒下一次，以 50% 生命站起", "max": 1, "ult": true, "stats": {"revive": 1}},
			{"id": "vajra", "name": "金刚", "desc": "受到伤害 -20%", "max": 1, "ult": true, "stats": {"dmg_taken": -0.2}},
			{"id": "myoo", "name": "明王", "desc": "弹反回复 3% 生命、刃意 +5", "max": 1, "ult": true, "stats": {"parry_heal": 0.03, "parry_will": 5.0}},
		],
	]},
	{"id": "gyo", "name": "行者", "role": "运", "color": Color("6fc28a"), "tiers": [
		[
			{"id": "purse", "name": "盘缠", "desc": "开局铜钱 +15", "max": 3, "stats": {"start_coins": 15}},
			{"id": "haggle", "name": "识货", "desc": "商人价格 -8%", "max": 3, "stats": {"discount": 0.08}},
			{"id": "stride", "name": "疾行", "desc": "移速 +4%", "max": 2, "stats": {"move": 0.04}},
		], [
			{"id": "treasure", "name": "寻宝", "desc": "罐子和宝箱铜钱 +30%", "max": 2, "stats": {"loot": 0.3}},
			{"id": "appraise", "name": "鉴宝", "desc": "掉落的装备品质更好", "max": 2, "stats": {"luck": 1}},
			{"id": "spirit", "name": "聚灵", "desc": "魂玉获取 +15%", "max": 2, "stats": {"jade": 0.15}},
		], [
			{"id": "light", "name": "轻身", "desc": "闪身冷却 -10%", "max": 2, "stats": {"dodge_cd": -0.1}},
			{"id": "scavenge", "name": "拾遗", "desc": "敌人掉装备的几率 +5%", "max": 2, "stats": {"gear_drop": 0.05}},
			{"id": "omen", "name": "吉兆", "desc": "出发时随身带一件良品饰品", "max": 1, "stats": {"start_charm": 1}},
		], [
			{"id": "fate", "name": "随缘", "desc": "商人多摆一件货", "max": 1, "ult": true, "stats": {"shop_extra": 1}},
			{"id": "fortune", "name": "招财", "desc": "铜钱 +50%", "max": 1, "ult": true, "stats": {"coin": 0.5}},
			{"id": "homeward", "name": "归途", "desc": "身死时魂玉带回 60% → 80%", "max": 1, "ult": true, "stats": {"keep": 0.2}},
		],
	]},
]

## 局外（不进 Player 的 stats 表）的数值默认值
const RUN_DEFAULTS := {"start_coins": 0, "discount": 0.0, "loot": 0.0, "luck": 0, "jade": 0.0,
	"gear_drop": 0.0, "start_charm": 0, "shop_extra": 0, "keep": 0.0}


static func levels() -> Dictionary:
	return Game.save["talents"]


static func rank(id: String) -> int:
	return int(levels().get(id, 0))


static func node(id: String) -> Dictionary:
	for t: Dictionary in TREES:
		for tier: Array in t["tiers"]:
			for n: Dictionary in tier:
				if n["id"] == id:
					return n
	return {}


static func spent_in(tree: Dictionary) -> int:
	var n := 0
	for tier: Array in tree["tiers"]:
		for nd: Dictionary in tier:
			n += rank(nd["id"])
	return n


static func jade_spent() -> int:
	var total := 0
	for t: Dictionary in TREES:
		for i in range((t["tiers"] as Array).size()):
			for nd: Dictionary in t["tiers"][i]:
				total += rank(nd["id"]) * int(COSTS[i])
	return total


## 能不能再点一级：返回 "" 表示可以，否则是原因
static func why_not(tree_i: int, tier_i: int, node_i: int) -> String:
	var t: Dictionary = TREES[tree_i]
	var nd: Dictionary = t["tiers"][tier_i][node_i]
	if rank(nd["id"]) >= int(nd["max"]):
		return "已满"
	if spent_in(t) < int(UNLOCK[tier_i]):
		return "%s 投入 %d 点后解锁" % [t["name"], UNLOCK[tier_i]]
	if nd.get("ult", false):
		for other: Dictionary in t["tiers"][tier_i]:
			if other["id"] != nd["id"] and rank(other["id"]) > 0:
				return "奥义只能选一个"
	if int(Game.save["jade"]) < int(COSTS[tier_i]):
		return "魂玉不够"
	return ""


static func learn(tree_i: int, tier_i: int, node_i: int) -> bool:
	if why_not(tree_i, tier_i, node_i) != "":
		return false
	var nd: Dictionary = TREES[tree_i]["tiers"][tier_i][node_i]
	Game.save["jade"] = int(Game.save["jade"]) - int(COSTS[tier_i])
	levels()[nd["id"]] = rank(nd["id"]) + 1
	Game.write_save()
	return true


## 洗髓：全部退回魂玉
static func reset() -> int:
	var back := jade_spent()
	Game.save["jade"] = int(Game.save["jade"]) + back
	Game.save["talents"] = {}
	Game.write_save()
	return back


## 把天赋加到 Player 的 stats 表里
static func apply(s: Dictionary) -> void:
	for id: String in levels():
		var nd := node(id)
		if nd.is_empty():
			continue
		var r := rank(id)
		for k: String in nd["stats"]:
			if RUN_DEFAULTS.has(k):
				continue
			if s.get(k) is int:
				s[k] = int(s[k]) + int(nd["stats"][k]) * r
			else:
				s[k] = float(s.get(k, 0.0)) + float(nd["stats"][k]) * r


## 局外数值（开局铜钱、商人折扣、魂玉加成……）
static func run_value(k: String) -> Variant:
	var v: Variant = RUN_DEFAULTS[k]
	for id: String in levels():
		var nd := node(id)
		if nd.is_empty() or not (nd["stats"] as Dictionary).has(k):
			continue
		if v is int:
			v = int(v) + int(nd["stats"][k]) * rank(id)
		else:
			v = float(v) + float(nd["stats"][k]) * rank(id)
	return v
