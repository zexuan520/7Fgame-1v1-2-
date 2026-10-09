class_name GearData
extends RefCounted
## 装备表：武器、头甲、身甲、饰品，品质和词条，掉落时随机生成。
## 一件装备是一个字典：
##   {"slot": weapon/head/body/charm, "base": 底子 id, "q": 品质 0-4,
##    "affixes": [[词条 id, 数值], ...], "mech": [饰品机制 id, ...]}
## 身上的五个格子：weapon 主武器、head 头甲、body 身甲、charm1 / charm2 饰品。
## 数值最后由 totals() 和 Talents.apply() 汇总成一张 stats 表，Player 只读这张表。

const SLOTS := ["weapon", "head", "body", "charm1", "charm2"]
const SLOT_NAMES := {"weapon": "武器", "head": "头甲", "body": "身甲", "charm": "饰品", "charm1": "饰品", "charm2": "饰品"}

## 品质：词条数、基础数值倍率、颜色
const QUALITIES := [
	{"name": "凡品", "affixes": 0, "mult": 1.0, "color": Color("d8d4cc")},
	{"name": "良品", "affixes": 1, "mult": 1.1, "color": Color("6fc28a")},
	{"name": "精品", "affixes": 2, "mult": 1.25, "color": Color("6aa8f0")},
	{"name": "绝品", "affixes": 3, "mult": 1.4, "color": Color("b07cf0")},
	{"name": "传说", "affixes": 3, "mult": 1.6, "color": Color("f0b840")},
]

## 武器：dmg 单击伤害、posture 架势伤害、speed 前摇后摇倍率（小 = 快）、reach 判定框长度倍率、
## len 画出来的刀身长度、trait 特性（Player 里按 id 生效）
const WEAPONS := {
	"katana": {"name": "太刀", "dmg": 1.0, "posture": 1.0, "speed": 1.0, "reach": 1.0, "len": 24.0,
		"trait": "counter", "trait_name": "追击", "trait_desc": "弹反后 2 秒内，下一刀伤害 +60%",
		"legend": "断水"},
	"dual": {"name": "双短刃", "dmg": 0.62, "posture": 0.5, "speed": 0.68, "reach": 0.85, "len": 15.0,
		"trait": "bleed", "trait_name": "流血", "trait_desc": "每刀叠一层流血（最多 5 层，每层每秒 3 伤害），闪身冷却 -30%",
		"legend": "双燕"},
	"nodachi": {"name": "野太刀", "dmg": 1.7, "posture": 1.9, "speed": 1.4, "reach": 1.3, "len": 36.0,
		"trait": "armor", "trait_name": "霸体", "trait_desc": "蓄力和重劈时挨打不会被打断",
		"legend": "斩马"},
	"spear": {"name": "长枪", "dmg": 0.9, "posture": 0.8, "speed": 1.0, "reach": 1.5, "len": 40.0,
		"trait": "pierce", "trait_name": "破盾", "trait_desc": "攻击距离 +50%，突刺能破盾和格挡",
		"legend": "穿云"},
	"fist": {"name": "铁拳", "dmg": 0.72, "posture": 1.45, "speed": 0.85, "reach": 0.72, "len": 0.0,
		"trait": "crush", "trait_name": "崩架", "trait_desc": "架势伤害特化，弹反窗口 +0.03 秒",
		"legend": "金刚"},
}

## 防具：def 防御（受到伤害 × 60 / (60 + 防御)），weight 轻中重，extra 额外效果（不乘品质）
const ARMOR := {
	"hood": {"slot": "head", "name": "头巾", "weight": "轻", "def": 3.0, "extra": {"dodge_cd": -0.1}, "legend": "夜行巾"},
	"kasa": {"slot": "head", "name": "斗笠", "weight": "中", "def": 5.0, "extra": {}, "legend": "听雨笠"},
	"kabuto": {"slot": "head", "name": "铁盔", "weight": "重", "def": 8.0, "extra": {"move": -0.05}, "legend": "鬼兜"},
	"vest": {"slot": "body", "name": "短打", "weight": "轻", "def": 4.0, "extra": {"move": 0.05}, "legend": "疾风衣"},
	"leather": {"slot": "body", "name": "皮甲", "weight": "中", "def": 7.0, "extra": {}, "legend": "柳叶甲"},
	"plate": {"slot": "body", "name": "铁甲", "weight": "重", "def": 11.0, "extra": {"max_posture_pct": 0.2, "dodge_speed": -0.15}, "legend": "不动铠"},
}

## 饰品机制（饰品本身的效果；传说品质的武器防具也会带一个）
const MECHS := {
	"jade_bead": {"name": "回春珠", "desc": "弹反成功回复 2% 生命", "stats": {"parry_heal": 0.02}},
	"asura_mask": {"name": "修罗面", "desc": "处决后 3 秒内，攻击无视格挡", "stats": {"exec_pierce": 3.0}},
	"blood_oath": {"name": "血誓符", "desc": "生命低于 30% 时刃意获取翻倍", "stats": {"low_will": 1.0}},
	"soul_gourd": {"name": "噬魂葫", "desc": "击杀敌人回复 3% 生命", "stats": {"kill_heal": 0.03}},
	"wind_bell": {"name": "风铃", "desc": "闪身后 1 秒内伤害 +30%", "stats": {"dodge_dmg": 0.3}},
	"lucky_cat": {"name": "招财猫", "desc": "铜钱 +40%", "stats": {"coin": 0.4}},
	"iron_bone": {"name": "铁骨牌", "desc": "格挡时自己架势增长 -30%", "stats": {"block_posture": -0.3}},
	"thunder_seal": {"name": "雷印", "desc": "会心率 +10%，会心伤害 +30%", "stats": {"crit": 0.1, "crit_dmg": 0.3}},
	"last_stand": {"name": "背水环", "desc": "生命低于 50% 时伤害 +25%", "stats": {"low_dmg": 0.25}},
	"still_water": {"name": "止水镜", "desc": "弹反窗口 +0.03 秒", "stats": {"parry": 0.03}},
}

## 词条：五类，同一件上同类不重复。range 是凡品到传说之间随机的范围
const AFFIXES := {
	"atk": {"cat": "攻击", "fmt": "攻击 +%d%%", "range": [5, 12], "pct": true},
	"hp": {"cat": "防御", "fmt": "生命 +%d", "range": [15, 40], "pct": false},
	"def": {"cat": "防御", "fmt": "防御 +%d", "range": [2, 6], "pct": false},
	"pdmg": {"cat": "架势", "fmt": "架势伤害 +%d%%", "range": [6, 15], "pct": true},
	"max_posture": {"cat": "架势", "fmt": "架势上限 +%d", "range": [10, 25], "pct": false},
	"will": {"cat": "刃意", "fmt": "刃意获取 +%d%%", "range": [10, 25], "pct": true},
	"crit": {"cat": "特殊", "fmt": "会心率 +%d%%", "range": [4, 10], "pct": true},
	"coin": {"cat": "特殊", "fmt": "铜钱 +%d%%", "range": [10, 25], "pct": true},
	"move": {"cat": "特殊", "fmt": "移速 +%d%%", "range": [4, 8], "pct": true},
}
const CATEGORIES := ["攻击", "防御", "架势", "刃意", "特殊"]

## 商人卖装备的价格（按品质）
const PRICES := [20, 35, 55, 80, 120]


## 一张空的 stats 表：所有数值的默认值
static func base_stats() -> Dictionary:
	return {
		"atk": 0.0, "pdmg": 0.0, "crit": 0.05, "crit_dmg": 0.5, "hp": 0.0, "max_posture": 0.0,
		"max_posture_pct": 0.0, "def": 0.0, "dmg_taken": 0.0, "move": 0.0, "dodge_cd": 0.0, "dodge_speed": 0.0,
		"parry": 0.0, "will": 0.0, "coin": 0.0, "block_posture": 0.0, "posture_rec": 0.0, "gourds": 0,
		"gourd_heal": 0.0, "charge": 0.0, "art_cost": 0.0, "combo_end": 0.0, "pressure": 0.0, "heavy_dmg": 0.0,
		"lifesteal": 0.0, "exec_heal": 0.0, "parry_posture": 0.0, "parry_heal": 0.0, "parry_will": 0.0,
		"revive": 0, "exec_pierce": 0.0, "low_will": 0.0, "kill_heal": 0.0, "dodge_dmg": 0.0, "low_dmg": 0.0,
		"low_dmg_line": 0.5, "parry_rebound": 0.0, "perfect_slow": 0.0, "bleed_burst": 0.0, "exec_will": 0.0,
	}


static func quality(item: Dictionary) -> Dictionary:
	return QUALITIES[int(item["q"])]


static func color(item: Dictionary) -> Color:
	return quality(item)["color"]


static func base(item: Dictionary) -> Dictionary:
	match String(item["slot"]):
		"weapon": return WEAPONS[item["base"]]
		"charm": return MECHS[item["base"]]
	return ARMOR[item["base"]]


static func display_name(item: Dictionary) -> String:
	var b := base(item)
	if int(item["q"]) == 4 and b.has("legend"):
		return String(b["legend"])
	return String(b["name"])


## 装备在背包格子里比较好坏用的分数：品质为主，词条多的略好
static func score(item: Variant) -> float:
	if item == null:
		return -1.0
	return float(item["q"]) * 10.0 + (item["affixes"] as Array).size() + (item["mech"] as Array).size() * 2.0


## 卡片上一行行的说明
static func describe(item: Dictionary) -> Array:
	var lines := []
	var q := quality(item)
	var b := base(item)
	var m := float(q["mult"])
	match String(item["slot"]):
		"weapon":
			lines.append("伤害 %d%%  架势 %d%%  出手%s" % [roundi(b["dmg"] * m * 100.0), roundi(b["posture"] * m * 100.0),
				_speed_word(float(b["speed"]))])
			lines.append("%s：%s" % [b["trait_name"], b["trait_desc"]])
		"head", "body":
			var extra := _extra_text(b["extra"])
			lines.append("%s · 防御 %d%s" % [b["weight"], roundi(float(b["def"]) * m), ("  " + extra) if extra != "" else ""])
	for a: Array in item["affixes"]:
		lines.append(affix_text(a))
	for id: String in item["mech"]:
		var mech: Dictionary = MECHS[id]
		lines.append("%s：%s" % [mech["name"], mech["desc"]] if String(item["slot"]) != "charm" or id != item["base"] else String(mech["desc"]))
	return lines


static func affix_text(a: Array) -> String:
	return String(AFFIXES[a[0]]["fmt"]) % int(a[1])


static func _speed_word(s: float) -> String:
	if s < 0.8:
		return "快"
	if s > 1.2:
		return "慢"
	return "中"


static func _extra_text(extra: Dictionary) -> String:
	var parts := []
	for k: String in extra:
		var v := float(extra[k])
		match k:
			"dodge_cd": parts.append("闪身冷却 %d%%" % roundi(v * 100.0))
			"move": parts.append("移速 %+d%%" % roundi(v * 100.0))
			"max_posture_pct": parts.append("架势上限 +%d%%" % roundi(v * 100.0))
			"dodge_speed": parts.append("闪身距离 %d%%" % roundi(v * 100.0))
	return "  ".join(parts)


# ---------- 生成 ----------

static func make(slot: String, base_id: String, q: int, rng: RandomNumberGenerator) -> Dictionary:
	var item := {"slot": slot, "base": base_id, "q": q, "affixes": [], "mech": []}
	if slot == "charm":
		item["mech"].append(base_id)
	var n: int = QUALITIES[q]["affixes"]
	var cats := CATEGORIES.duplicate()
	for i in range(n):
		var cat: String = cats[rng.randi_range(0, cats.size() - 1)]
		cats.erase(cat)
		var pool := []
		for id: String in AFFIXES:
			if AFFIXES[id]["cat"] == cat:
				pool.append(id)
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var r: Array = AFFIXES[id]["range"]
		# 品质越高，数值越靠上限
		var t := clampf(rng.randf() * 0.7 + q * 0.08, 0.0, 1.0)
		item["affixes"].append([id, roundi(lerpf(float(r[0]), float(r[1]), t))])
	if q == 4:
		# 传说：多一个专属机制
		var mechs := MECHS.keys()
		mechs.erase(base_id)
		item["mech"].append(mechs[rng.randi_range(0, mechs.size() - 1)])
	return item


## 商人重铸：底子和品质不变，词条（传说的专属机制也算）重抽一遍，尽量和原来不一样
static func reforge(item: Dictionary, rng: RandomNumberGenerator) -> void:
	var old := str(item["affixes"]) + str(item["mech"])
	for i in range(8):
		var fresh := make(item["slot"], item["base"], int(item["q"]), rng)
		item["affixes"] = fresh["affixes"]
		item["mech"] = fresh["mech"]
		if str(item["affixes"]) + str(item["mech"]) != old:
			return


## 随机一件装备。slot 为空时随机部位；weights 是五种品质的权重
static func roll(rng: RandomNumberGenerator, weights: Array, slot: String = "") -> Dictionary:
	if slot == "":
		var r := rng.randf()
		slot = "weapon" if r < 0.3 else ("head" if r < 0.5 else ("body" if r < 0.7 else "charm"))
	var q := _pick_quality(rng, weights)
	var ids: Array
	match slot:
		"weapon": ids = WEAPONS.keys()
		"charm": ids = MECHS.keys()
		_:
			ids = []
			for id: String in ARMOR:
				if ARMOR[id]["slot"] == slot:
					ids.append(id)
	return make(slot, ids[rng.randi_range(0, ids.size() - 1)], q, rng)


static func _pick_quality(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var x := rng.randf() * total
	for i in range(weights.size()):
		x -= float(weights[i])
		if x <= 0.0:
			return i
	return 0


## 各种来源的品质权重：凡 良 精 绝 传。luck 是行者“鉴宝”的等级，每级把权重往高品质挪
static func weights_for(source: String, row: int, luck: int) -> Array:
	var w: Array
	match source:
		"boss": w = [0.0, 0.0, 0.0, 0.0, 1.0]
		"elite": w = [0.0, 0.0, 5.0, 3.0, 1.0]
		"chest": w = [3.0, 4.0, 2.0 + row * 0.4, maxf(0.0, row - 2.0) * 0.5, 0.0]
		"shop": w = [2.0, 4.0, 3.0, 1.0, 0.0]
		_: w = [5.0, 3.0, 1.0 + row * 0.2, 0.0, 0.0]
	for i in range(luck):
		for k in range(w.size() - 1, 0, -1):
			w[k] = float(w[k]) + float(w[k - 1]) * 0.25
		w[0] = float(w[0]) * 0.6
	return w


## 出发时的初始武器
static func starter(base_id: String) -> Dictionary:
	return {"slot": "weapon", "base": base_id, "q": 0, "affixes": [], "mech": []}


static func empty_loadout(weapon_id: String = "katana") -> Dictionary:
	return {"weapon": starter(weapon_id), "head": null, "body": null, "charm1": null, "charm2": null}


## 这件装备放进身上哪一格：饰品先放空格，两格都满时换掉差的那件
static func target_slot(gear: Dictionary, item: Dictionary) -> String:
	var slot: String = item["slot"]
	if slot != "charm":
		return slot
	if gear["charm1"] == null:
		return "charm1"
	if gear["charm2"] == null:
		return "charm2"
	return "charm1" if score(gear["charm1"]) <= score(gear["charm2"]) else "charm2"


# ---------- 汇总 ----------

## 把身上的装备加到 stats 表里，返回武器数值（伤害、速度等已乘品质）
static func totals(gear: Dictionary) -> Dictionary:
	var s := base_stats()
	for slot: String in SLOTS:
		var item: Variant = gear.get(slot)
		if item == null:
			continue
		var m := float(QUALITIES[int(item["q"])]["mult"])
		match String(item["slot"]):
			"head", "body":
				var b: Dictionary = ARMOR[item["base"]]
				s["def"] = float(s["def"]) + float(b["def"]) * m
				_add(s, b["extra"])
		for a: Array in item["affixes"]:
			var spec: Dictionary = AFFIXES[a[0]]
			var v := float(a[1]) / (100.0 if spec["pct"] else 1.0)
			s[a[0]] = float(s[a[0]]) + v
		for id: String in item["mech"]:
			_add(s, MECHS[id]["stats"])
	return s


static func weapon_stats(item: Dictionary) -> Dictionary:
	var b: Dictionary = WEAPONS[item["base"]]
	var m := float(QUALITIES[int(item["q"])]["mult"])
	var w := b.duplicate()
	w["id"] = item["base"]
	w["dmg"] = float(b["dmg"]) * m
	w["posture"] = float(b["posture"]) * m
	return w


static func _add(s: Dictionary, extra: Dictionary) -> void:
	for k: String in extra:
		if s.get(k) is int:
			s[k] = int(s[k]) + int(extra[k])
		else:
			s[k] = float(s.get(k, 0.0)) + float(extra[k])
