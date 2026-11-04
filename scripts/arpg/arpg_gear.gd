class_name ArpgGear
extends RefCounted
## 掉落的装备：护甲 / 护符，五档品质（凡、良、精、珍、传），品质越高基础属性越高、随机词条越多。
## 一件装备是个字典：{"slot", "base", "rarity", "affixes": [[属性, 数值], ...], "name"}
## 合成：行囊里三件同品质的装备 → 一件高一档的（部位随机取三件里多的那种）。

const RARITY_NAMES := ["凡", "良", "精", "珍", "传"]
const RARITY_COLORS := [Color(0.82, 0.82, 0.78), Color(0.5, 0.95, 0.55), Color(0.45, 0.7, 1.0), Color(0.8, 0.5, 1.0), Color(1.0, 0.75, 0.3)]
const BAG_MAX := 10

## 随机词条：[属性, 最小, 最大, 文字（%s 填数值）]
const AFFIXES := [
	["atk", 0.04, 0.1, "伤害 +%d%%"],
	["crit", 0.03, 0.07, "会心率 +%d%%"],
	["crit_dmg", 0.12, 0.3, "会心伤害 +%d%%"],
	["hp", 8.0, 22.0, "生命 +%d"],
	["dmg_taken", -0.07, -0.03, "受伤 %d%%"],
	["lifesteal", 0.01, 0.025, "吸血 %s%%"],
	["energy", 0.1, 0.25, "气力获取 +%d%%"],
	["dash_cd", 0.08, 0.18, "突进冷却 -%d%%"],
	["bleed_dmg", 0.12, 0.3, "出血伤害 +%d%%"],
	["move", 0.03, 0.07, "移速 +%d%%"],
	["coin", 0.1, 0.25, "铜钱 +%d%%"],
]


## 随机一件装备；rarity < 0 时按 luck 掷品质（luck 越高越容易出好东西）
static func roll(rng: RandomNumberGenerator, rarity: int = -1, luck: float = 0.0, slot: String = "") -> Dictionary:
	if rarity < 0:
		var r := rng.randf() + luck
		rarity = 0
		for th: float in [0.45, 0.75, 0.92, 0.985]:
			if r > th:
				rarity += 1
	rarity = clampi(rarity, 0, 4)
	if slot == "":
		slot = "armor" if rng.randf() < 0.5 else "charm"
	var pool: Array = ArpgData.ARMORS if slot == "armor" else ArpgData.CHARMS
	var base: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var affixes := []
	var used := {}
	for i in range(rarity):
		var a: Array = AFFIXES[rng.randi_range(0, AFFIXES.size() - 1)]
		if used.has(a[0]):
			continue
		used[a[0]] = true
		affixes.append([a[0], snappedf(rng.randf_range(float(a[1]), float(a[2])), 0.001)])
	return {"slot": slot, "base": base["id"], "rarity": rarity, "affixes": affixes,
		"name": "%s·%s" % [RARITY_NAMES[rarity], base["name"]]}


## 这件装备给的全部属性：基础属性 ×(1 + 0.3×品质) + 词条
static func stats(item: Dictionary) -> Dictionary:
	var st := {}
	if item.is_empty():
		return st
	var base := ArpgData.gear(String(item["base"]))
	var k := 1.0 + 0.3 * int(item["rarity"])
	for s: String in base.get("stats", {}):
		st[s] = float(base["stats"][s]) * k
	for a: Array in item["affixes"]:
		st[a[0]] = float(st.get(a[0], 0.0)) + float(a[1])
	return st


static func color(item: Dictionary) -> Color:
	return RARITY_COLORS[clampi(int(item.get("rarity", 0)), 0, 4)]


## 一行说明：基础效果 + 词条
static func describe(item: Dictionary) -> String:
	var base := ArpgData.gear(String(item["base"]))
	var parts: Array[String] = [String(base.get("desc", ""))]
	if int(item["rarity"]) > 0:
		parts[0] += "（×%.1f）" % (1.0 + 0.3 * int(item["rarity"]))
	for a: Array in item["affixes"]:
		for d: Array in AFFIXES:
			if d[0] == a[0]:
				var v := float(a[1]) * (1.0 if a[0] == "hp" else 100.0)
				parts.append(String(d[3]) % (("%.1f" % v) if a[0] == "lifesteal" else int(round(v))))
	return "，".join(parts)


## 能合成的品质（行囊里同品质够三件、且不是最高档）
static func craftable(bag: Array) -> Array:
	var n := {}
	for it: Dictionary in bag:
		var r := int(it["rarity"])
		n[r] = int(n.get(r, 0)) + 1
	var out := []
	for r: int in n:
		if int(n[r]) >= 3 and r < 4:
			out.append(r)
	out.sort()
	return out


## 用掉三件 rarity 品质的，返回新的一件（同时从 bag 里删掉用掉的）
static func craft(bag: Array, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	var used := []
	var slots := {"armor": 0, "charm": 0}
	for it: Dictionary in bag:
		if int(it["rarity"]) == rarity and used.size() < 3:
			used.append(it)
			slots[it["slot"]] = int(slots[it["slot"]]) + 1
	for it: Dictionary in used:
		bag.erase(it)
	var slot := "armor" if int(slots["armor"]) >= int(slots["charm"]) else "charm"
	return roll(rng, rarity + 1, 0.0, slot)
