class_name Arts
extends RefCounted
## 局内构筑：主动招式和被动心法（设计文档第 3 节“局内循环”、第 7 节“技能与招式”）。
## 招式最多装 3 个，消耗刃意，用「招式键 + 方向」放：单按 / 按住左右 / 按住下 各对应一格；每个招式 3 级。
## 心法最多装 4 个，改变基础动作的规则，没有等级。
## 招式和心法只在这一局有效（存在 Run.builds 里），死了或回城就清空；
## 局外只决定哪些能出现在奖励里：破庙的招式谱用魂玉把它们加进掉落池（存档 Game.save["arts"]）。
##
## 加新招式：ARTS 里加一条（lv 是三个等级各自覆盖的数值），再在 Player 的 _art_<run>() 里写它怎么出手，
## run 字段决定用哪一段逻辑（几个招式可以共用一种，只是数值不同）。加新心法：MINDS 里加一条，
## stats 会加到 Player 的 stats 表里，再在用到的地方读这个数值。
##
## 招式字段：
##   name / short        名字 / 两个字的简称（界面格子里用）
##   school              流派：招式、格挡、重击、闪避、连击
##   cost                消耗刃意
##   unlock              在招式谱里加进掉落池要多少魂玉（0 = 一开始就在池子里）
##   run                 出手逻辑：spin 回旋 / iai 居合 / wave 刃气 / kongo 金刚 / quake 震地 / shadow 影步 / flurry 乱斩
##   windup/active/recover   前摇 / 出手 / 后摇（秒）
##   pose                [前摇姿势, 出手姿势]（Player.POSES 里的）
##   desc                一句话说明
##   lv                  三个等级的数值，覆盖在上面；每级的 desc 是这一级多了什么

const MAX_ARTS := 3
const MAX_MINDS := 4
## 三个招式格子：单按、按住左右、按住下
const SLOTS := ["neutral", "side", "down"]
const SLOT_NAMES := {"neutral": "单按", "side": "←→", "down": "↓"}
const LEVEL_NAMES := ["", "壹", "贰", "叁"]
## 每一局开局自带的招式（以前的刃意招式）
const STARTER := "whirl"

const SCHOOL_COLORS := {
	"招式": Color("e0b860"), "格挡": Color("6aa8f0"), "重击": Color("e07a48"),
	"闪避": Color("8ad0c0"), "连击": Color("d06a9a"),
}

const ARTS := {
	"whirl": {"name": "回旋斩", "short": "回旋", "school": "招式", "cost": 40.0, "unlock": 0, "run": "spin",
		"windup": 0.14, "active": 0.42, "recover": 0.3, "pose": ["art_prep", "art_spin"],
		"size": Vector2(120, 46), "heavy": true,
		"desc": "原地转圈前后都砍，能破格挡，转的时候不吃伤害",
		"lv": [
			{"ticks": 2, "dmg": 22.0, "posture": 40.0, "desc": "转两圈，每圈 22 伤害、40 架势"},
			{"ticks": 3, "active": 0.6, "dmg": 22.0, "posture": 40.0, "desc": "转三圈"},
			{"ticks": 3, "active": 0.6, "dmg": 30.0, "posture": 52.0, "size": Vector2(140, 50), "desc": "转三圈，每圈 30 伤害、52 架势，范围更大"},
		]},
	"issen": {"name": "一心", "short": "一心", "school": "招式", "cost": 50.0, "unlock": 20, "run": "iai",
		"windup": 0.42, "active": 0.1, "recover": 0.4, "pose": ["st_iai", "iai_cut"],
		"reach": 64.0, "height": 28.0, "heavy": true, "lunge": 280.0,
		"desc": "纳刀蓄势，一记居合斩开身前一大片，能破格挡",
		"lv": [
			{"dmg": 55.0, "posture": 50.0, "size": Vector2(150, 56), "desc": "55 伤害、50 架势"},
			{"dmg": 75.0, "posture": 65.0, "size": Vector2(170, 60), "desc": "75 伤害、65 架势，范围更大"},
			{"dmg": 90.0, "posture": 75.0, "size": Vector2(170, 60), "second": true, "desc": "90 伤害、75 架势，收刀前再补一刀"},
		]},
	"kuujin": {"name": "空刃斩", "short": "空刃", "school": "招式", "cost": 30.0, "unlock": 0, "run": "wave",
		"windup": 0.12, "active": 0.05, "recover": 0.25, "pose": ["raise1", "cut1"],
		"speed": 430.0, "life": 0.85, "heavy": false,
		"desc": "挥出一道刃气往前飞，打中正在出招的敌人会打断它",
		"lv": [
			{"dmg": 16.0, "posture": 20.0, "count": 1, "pierce": false, "desc": "16 伤害、20 架势"},
			{"dmg": 20.0, "posture": 26.0, "count": 1, "pierce": true, "desc": "刃气穿过敌人，一路打下去"},
			{"dmg": 24.0, "posture": 32.0, "count": 2, "pierce": true, "desc": "连挥两道，24 伤害、32 架势"},
		]},
	"kongo": {"name": "金刚没", "short": "金刚", "school": "格挡", "cost": 40.0, "unlock": 0, "run": "kongo",
		"windup": 0.12, "active": 0.0, "recover": 0.08, "pose": ["guard", "parry"],
		"desc": "一段时间内所有格挡都算弹反（危字攻击照样挡不住）",
		"lv": [
			{"time": 2.0, "desc": "持续 2 秒"},
			{"time": 2.6, "desc": "持续 2.6 秒"},
			{"time": 3.2, "parry_will": 6.0, "desc": "持续 3.2 秒，期间每次弹反刃意再 +6"},
		]},
	"houzan": {"name": "崩山劲", "short": "崩山", "school": "重击", "cost": 35.0, "unlock": 0, "run": "quake",
		"windup": 0.24, "active": 0.05, "recover": 0.4, "pose": ["plunge_raise", "plunge_land"],
		"height": 20.0, "heavy": true,
		"desc": "刀往下戳进地面，震开一圈，大量架势伤害；空中放会先砸下来",
		"lv": [
			{"dmg": 18.0, "posture": 60.0, "size": Vector2(140, 40), "desc": "18 伤害、60 架势"},
			{"dmg": 24.0, "posture": 80.0, "size": Vector2(160, 44), "desc": "24 伤害、80 架势，范围更大"},
			{"dmg": 30.0, "posture": 100.0, "size": Vector2(190, 48), "desc": "30 伤害、100 架势，范围再大"},
		]},
	"kage": {"name": "影步", "short": "影步", "school": "闪避", "cost": 25.0, "unlock": 15, "run": "shadow",
		"windup": 0.06, "active": 0.05, "recover": 0.14, "pose": ["dodge", "raise3"],
		"desc": "瞬移到最近的敌人背后，下一刀必定会心",
		"lv": [
			{"range": 240.0, "crit_time": 3.0, "crit_bonus": 0.0, "desc": "距离 240，3 秒内下一刀必会心"},
			{"range": 300.0, "crit_time": 4.0, "crit_bonus": 0.0, "desc": "距离 300，4 秒内下一刀必会心"},
			{"range": 360.0, "crit_time": 4.0, "crit_bonus": 0.5, "desc": "距离 360，那一刀会心伤害再 +50%"},
		]},
	"ukifune": {"name": "浮舟渡打", "short": "浮舟", "school": "连击", "cost": 45.0, "unlock": 15, "run": "flurry",
		"windup": 0.1, "active": 0.63, "recover": 0.3, "pose": ["raise2", "cut2"],
		"hits": 7, "reach": 30.0, "size": Vector2(66, 40), "height": 28.0, "heavy": false,
		"desc": "往前七段连斩，每一刀都叠一层流血",
		"lv": [
			{"dmg": 7.0, "posture": 7.0, "bleed": 1, "desc": "每段 7 伤害、7 架势"},
			{"dmg": 9.0, "posture": 9.0, "bleed": 1, "desc": "每段 9 伤害、9 架势"},
			{"dmg": 11.0, "posture": 11.0, "bleed": 2, "desc": "每段 11 伤害、11 架势，每刀叠两层流血"},
		]},
}

## 心法：stats 加到 Player 的 stats 表里（见 GearData.base_stats）
const MINDS := {
	"fudoshin": {"name": "不动心", "short": "不动", "school": "格挡", "unlock": 0,
		"desc": "弹反给敌人的架势反震 50% → 80%", "stats": {"parry_rebound": 0.3}},
	"zanshin": {"name": "残心", "short": "残心", "school": "招式", "unlock": 0,
		"desc": "生命低于 50% 时伤害 +30%，药罐回复 -30%", "stats": {"low_dmg": 0.3, "gourd_heal": -0.3}},
	"ryuun": {"name": "流云", "short": "流云", "school": "闪避", "unlock": 12,
		"desc": "完美闪避（敌人砍到之前一瞬间闪身）放慢时间 0.5 秒，刃意 +8", "stats": {"perfect_slow": 0.5}},
	"ketsuon": {"name": "血音", "short": "血音", "school": "连击", "unlock": 12,
		"desc": "流血叠满 5 层时引爆：大量架势伤害", "stats": {"bleed_burst": 1.0}},
	"jiri": {"name": "持离", "short": "持离", "school": "重击", "unlock": 0,
		"desc": "处决后刃意立刻充满", "stats": {"exec_will": 1.0}},
}

## 三选一奖励
const REWARD_WEIGHTS := {"art": 4, "mind": 3, "up": 3, "coin": 2}
const REWARD_COINS := {"fight": 15, "elite": 40}     # 选铜钱给多少（每往后一列 +2）
const ELITE_ART_LEVEL := 2                           # 精英房给的新招式直接是 2 级


static func art(id: String, lv: int = 1) -> Dictionary:
	var a: Dictionary = ARTS[id].duplicate()
	var levels: Array = a["lv"]
	var l: Dictionary = levels[clampi(lv, 1, levels.size()) - 1]
	for k: String in l:
		if k != "desc":
			a[k] = l[k]
	a["id"] = id
	a["level"] = clampi(lv, 1, levels.size())
	a.erase("lv")
	return a


static func max_level(id: String) -> int:
	return (ARTS[id]["lv"] as Array).size()


static func level_desc(id: String, lv: int) -> String:
	return String(ARTS[id]["lv"][clampi(lv, 1, max_level(id)) - 1]["desc"])


static func entry(kind: String, id: String) -> Dictionary:
	return ARTS[id] if kind == "art" else MINDS[id]


# ---------- 一个玩家这一局的构筑 ----------

## {"arts": [三个格子，每格 {"id", "lv"} 或 null], "minds": [心法 id, ...]}
static func new_build() -> Dictionary:
	return {"arts": [{"id": STARTER, "lv": 1}, null, null], "minds": []}


static func has_art(build: Dictionary, id: String) -> bool:
	return art_slot(build, id) >= 0


static func art_slot(build: Dictionary, id: String) -> int:
	var slots: Array = build["arts"]
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["id"] == id:
			return i
	return -1


static func art_count(build: Dictionary) -> int:
	var n := 0
	for s: Variant in build["arts"]:
		if s != null:
			n += 1
	return n


## 把心法的数值加到 stats 表里
static func apply_minds(s: Dictionary, build: Dictionary) -> void:
	for id: String in build["minds"]:
		var st: Dictionary = MINDS[id]["stats"]
		for k: String in st:
			s[k] = float(s.get(k, 0.0)) + float(st[k])


# ---------- 局外：掉落池（招式谱） ----------

static func in_pool(kind: String, id: String) -> bool:
	if kind == "art" and id == STARTER:
		return true
	if int(entry(kind, id)["unlock"]) == 0:
		return true
	return (Game.save["arts"] as Array).has(id)


## 招式谱：用魂玉把一个招式或心法加进掉落池。返回 "" 表示成功，否则是原因
static func unlock(kind: String, id: String) -> String:
	if in_pool(kind, id):
		return "已经在谱上了"
	var cost := int(entry(kind, id)["unlock"])
	if int(Game.save["jade"]) < cost:
		return "魂玉不够"
	Game.save["jade"] = int(Game.save["jade"]) - cost
	(Game.save["arts"] as Array).append(id)
	Game.write_save()
	return ""


# ---------- 三选一 ----------

## 抽三个奖励：新招式、心法、招式强化、铜钱。精英房：新招式直接 2 级，铜钱给得多，
## 而且只要还有别的可选就不出铜钱
static func roll_choices(rng: RandomNumberGenerator, build: Dictionary, room_type: String, row: int) -> Array:
	var elite := room_type == "elite"
	var cands := []
	for id: String in ARTS:
		if in_pool("art", id) and not has_art(build, id):
			cands.append({"kind": "art", "id": id, "lv": ELITE_ART_LEVEL if elite else 1})
	for id: String in MINDS:
		if in_pool("mind", id) and not (build["minds"] as Array).has(id):
			cands.append({"kind": "mind", "id": id})
	for s: Variant in build["arts"]:
		if s != null and int(s["lv"]) < max_level(s["id"]):
			cands.append({"kind": "up", "id": s["id"], "lv": int(s["lv"]) + 1})
	var out := []
	while out.size() < 3 and not cands.is_empty():
		var total := 0
		for c: Dictionary in cands:
			total += int(REWARD_WEIGHTS[c["kind"]])
		var roll := rng.randi_range(1, total)
		for i in range(cands.size()):
			roll -= int(REWARD_WEIGHTS[cands[i]["kind"]])
			if roll <= 0:
				out.append(cands.pop_at(i))
				break
	# 战斗房：第三个有一半是铜钱；不够三个也拿铜钱补
	var coin := {"kind": "coin", "amount": int(REWARD_COINS["elite" if elite else "fight"]) + row * 2}
	if not elite and out.size() == 3 and rng.randf() < 0.5:
		out[2] = coin
	if out.size() < 3:
		out.append(coin)
	return out


## 选了的这一项要不要先替换掉一个（格子满了）
static func needs_replace(build: Dictionary, choice: Dictionary) -> bool:
	match String(choice["kind"]):
		"art": return art_count(build) >= MAX_ARTS
		"mind": return (build["minds"] as Array).size() >= MAX_MINDS
	return false


## 把选中的奖励装上。replace 是格子满了时换掉第几个（招式是格子序号，心法是第几个）
static func take(build: Dictionary, choice: Dictionary, replace: int = -1) -> void:
	match String(choice["kind"]):
		"art":
			var slots: Array = build["arts"]
			var i := replace if replace >= 0 else slots.find(null)
			slots[i] = {"id": choice["id"], "lv": int(choice["lv"])}
		"mind":
			var minds: Array = build["minds"]
			if replace >= 0 and replace < minds.size():
				minds[replace] = choice["id"]
			else:
				minds.append(choice["id"])
		"up":
			var s: Dictionary = build["arts"][art_slot(build, choice["id"])]
			s["lv"] = mini(int(s["lv"]) + 1, max_level(choice["id"]))


## 奖励卡片上的字：[标签, 名字, 说明]
static func describe(choice: Dictionary) -> Array:
	match String(choice["kind"]):
		"art":
			var a: Dictionary = ARTS[choice["id"]]
			return ["新招式", "%s · %s" % [a["name"], LEVEL_NAMES[int(choice["lv"])]],
				"%s · 刃意 %d。%s（%s）" % [a["school"], int(a["cost"]), a["desc"], level_desc(choice["id"], int(choice["lv"]))]]
		"mind":
			var m: Dictionary = MINDS[choice["id"]]
			return ["心法", m["name"], "%s · %s" % [m["school"], m["desc"]]]
		"up":
			var a2: Dictionary = ARTS[choice["id"]]
			return ["强化", "%s → %s" % [a2["name"], LEVEL_NAMES[int(choice["lv"])]], level_desc(choice["id"], int(choice["lv"]))]
	return ["铜钱", "%d 铜钱" % int(choice["amount"]), "两人共用的钱袋"]


static func color(choice: Dictionary) -> Color:
	match String(choice["kind"]):
		"art", "up": return SCHOOL_COLORS[ARTS[choice["id"]]["school"]]
		"mind": return SCHOOL_COLORS[MINDS[choice["id"]]["school"]]
	return Color("d89a48")
