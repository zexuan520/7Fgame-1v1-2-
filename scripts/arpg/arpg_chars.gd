class_name ArpgChars
extends RefCounted
## 局外成长：可选角色（山门“名册”选人）和奇物解锁（山门“奇物谱”）。
## 角色 = 招牌兵器 + 开局心法 + 天生被动（stats）+ 外观（ArpgArms.SKINS 的 id）。选人时把兵器架主手和衣箱换成他的，之后还能自己换。
## 解锁条件写成 {"ach": 成就 id}；奇物还能直接花魂玉开（price）。每局结束 check_unlocks() 看有没有新开的，写进结算“这局收获”。
## 想加一个角色 / 一件可解锁奇物：在 CHARS / RELIC_UNLOCK 里加一行。

const CHARS := [
	{"id": "canren", "name": "残刃", "title": "寂光的小徒弟", "weapon": "sword", "boon": "", "skin": "qing",
		"desc": "什么都会一点。没有天生的长处，也没有短处", "stats": {}, "unlock": {}},
	{"id": "aqi", "name": "阿七", "title": "灰衣营的逃兵", "weapon": "crossbow", "boon": "swift", "skin": "aqi",
		"desc": "连弩起手，开局带“轻身”。翻滚更远、翻滚后突进冷却 -0.4 秒，身子薄（生命 -15）",
		"stats": {"roll_far": 0.25, "roll_cd": 0.4, "hp": -15.0}, "unlock": {"ach": "boss1"}},
	{"id": "huiming", "name": "慧明", "title": "古寺守灯的和尚", "weapon": "staff", "boon": "iron", "skin": "mage",
		"desc": "齐眉棍起手，开局带“铁衣”。生命 +30，每清完一间房回 8% 生命，走得慢一点（移速 -6%）",
		"stats": {"hp": 30.0, "clear_heal": 0.08, "move": -0.06}, "unlock": {"ach": "boss2"}},
	{"id": "jin", "name": "烬", "title": "执灯使，你的师兄", "weapon": "greatsword", "boon": "ember", "skin": "ember",
		"desc": "斩马大剑起手，开局带“火种”。伤害 +12%、斩杀 15% 机会爆燃，代价是受伤 +10%",
		"stats": {"atk": 0.12, "kill_fire": 0.15, "taken_extra": 0.1}, "unlock": {"ach": "boss6"}},
]

## 要解锁的奇物：哪个成就开，或者花多少魂玉直接开
const RELIC_UNLOCK := {
	"guiyan": {"ach": "mikiri", "price": 20},
	"nifeng": {"ach": "mikiri_30", "price": 30},
	"manyue": {"ach": "set_any", "price": 25},
	"jinxin": {"ach": "set_pyre", "price": 25},
	"gudi": {"ach": "dual_any", "price": 25},
	"shuangling": {"ach": "swap_hit", "price": 20},
	"jianpu": {"ach": "lv_10", "price": 25},
	"zhenhun": {"ach": "boss1", "price": 20},
}


static func get_char(id: String) -> Dictionary:
	for c: Dictionary in CHARS:
		if c["id"] == id:
			return c
	return CHARS[0]


static func current() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--char="):
			return a.substr(7)   # 测试：直接用某个角色（不看解锁）
	var id := String(Game.save.get("arpg_char", "canren"))
	return id if char_open(id) else "canren"


static func char_open(id: String) -> bool:
	var c := get_char(id)
	if c["id"] != id:
		return false
	return _cond_ok(c.get("unlock", {}))


static func _cond_ok(u: Dictionary) -> bool:
	if u.has("ach") and not ArpgAch.has(String(u["ach"])):
		return false
	return true


static func cond_text(u: Dictionary) -> String:
	if u.has("ach"):
		var a := ArpgAch.info(String(u["ach"]))
		return "成就「%s」：%s" % [a[1], a[2]] if not a.is_empty() else ""
	return ""


## 选人：存档记下，兵器架主手换成他的招牌兵器（没有就送），衣箱换成他的外观
static func pick(id: String) -> void:
	var c := get_char(id)
	Game.save["arpg_char"] = id
	var owned: Array = Game.save.get("arpg_weapons", ["sword"])
	if not owned.has(c["weapon"]):
		owned.append(c["weapon"])
		Game.save["arpg_weapons"] = owned
	Game.save["arpg_weapon"] = c["weapon"]
	var skins: Array = Game.save.get("arpg_skins", ["qing"])
	if not skins.has(c["skin"]):
		skins.append(c["skin"])
		Game.save["arpg_skins"] = skins
	Game.save["arpg_skin"] = c["skin"]
	Game.write_save()


# ---------- 奇物解锁 ----------

static func relic_open_list() -> Array:
	return Game.save.get("arpg_relics_open", [])


static func open_relic(id: String) -> void:
	var l: Array = relic_open_list()
	if not l.has(id):
		l.append(id)
		Game.save["arpg_relics_open"] = l
		Game.write_save()


## 每局结束（或进山门时）看看有没有达成条件的新奇物、新角色；返回这次新开的说明文字
static func check_unlocks() -> Array:
	var out := []
	for rid: String in RELIC_UNLOCK:
		if not relic_open_list().has(rid) and _cond_ok(RELIC_UNLOCK[rid]):
			open_relic(rid)
			out.append("新奇物进掉落池：%s（%s）" % [ArpgRelics.get_relic(rid).get("name", rid), ArpgRelics.get_relic(rid).get("desc", "")])
	var seen: Array = Game.save.get("arpg_chars_seen", ["canren"])
	for c: Dictionary in CHARS:
		if not seen.has(c["id"]) and char_open(String(c["id"])):
			seen.append(c["id"])
			out.append("新角色可选：%s · %s（山门名册）" % [c["name"], c["title"]])
	Game.save["arpg_chars_seen"] = seen
	Game.write_save()
	return out


## 结算里“离下一个解锁还差什么”：挑一两条还没开的
static func next_goals() -> Array:
	var out := []
	for c: Dictionary in CHARS:
		if not char_open(String(c["id"])):
			out.append("角色 %s：%s" % [c["name"], cond_text(c["unlock"])])
			break
	for rid: String in RELIC_UNLOCK:
		if not relic_open_list().has(rid):
			out.append("奇物 %s：%s，或在奇物谱花 %d 魂玉" % [ArpgRelics.get_relic(rid).get("name", rid), cond_text(RELIC_UNLOCK[rid]), int(RELIC_UNLOCK[rid]["price"])])
			break
	return out
