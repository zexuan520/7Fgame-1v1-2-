class_name ArpgUnlock
extends RefCounted
## 系统分局解锁（2026-11-10）：第一局只有心法和兵器，回山门一次开一批，内容一点不删。
##   第 1 次回山门后：奇物、装备（门上奖励、精英房和小怪掉装备）
##   第 2 次回山门后：魂派心法、诅咒（奇遇里背诅咒、诅咒祭坛）
##   第 3 次回山门或登顶过一次：全部打开（含每日挑战）
## 老存档（出发过 3 次以上或登顶过）一开始就全开；--demo / --allsys 测试也全开，--lockedsys 强制按第一局。

const STAGES := [
	{"runs": 1, "keys": ["relic", "gear"], "name": "奇物、装备", "desc": "战斗房门上会出现“奇物”“装备”奖励，精英和小怪开始掉装备"},
	{"runs": 2, "keys": ["soul", "curse"], "name": "魂派心法、诅咒", "desc": "心法里多出召唤向的“魂”派；奇遇里能背诅咒换好处"},
	{"runs": 3, "keys": ["daily"], "name": "每日挑战", "desc": "光门右边的告示牌：每天一局固定种子"},
]


static var force := false   # 章节试玩（标题按 K）：给评委看的，全开


static func all_open() -> bool:
	if force:
		return true
	var a := OS.get_cmdline_user_args()
	if a.has("--lockedsys"):
		return false
	if a.has("--allsys") or a.has("--chapter"):
		return true
	for s: String in a:
		if s.begins_with("--demo"):
			return true
	return int(Game.save.get("clears", 0)) > 0 or int(Game.save.get("runs", 0)) >= 3


static func open(key: String) -> bool:
	if all_open():
		return true
	var runs := int(Game.save.get("runs", 0))
	for st: Dictionary in STAGES:
		if (st["keys"] as Array).has(key):
			return runs >= int(st["runs"])
	return true


## 这次回山门新开了哪一批（没开新的返回空）；看过就记进存档，不再报
static func take_new() -> Dictionary:
	if OS.get_cmdline_user_args().has("--allsys"):
		return {}
	var runs := int(Game.save.get("runs", 0))
	var seen := int(Game.save.get("arpg_unlock_seen", 0))
	var out := {}
	for i in range(STAGES.size()):
		var st: Dictionary = STAGES[i]
		if i >= seen and runs >= int(st["runs"]):
			out = st
			Game.save["arpg_unlock_seen"] = i + 1
	return out


## 奇遇里有没有用到没开的系统（有就这局不出）
static func event_ok(ev: Dictionary) -> bool:
	if all_open():
		return true
	for op: Variant in ev.get("options", []):
		if not (op is Array) or (op as Array).size() < 2 or not ((op as Array)[1] is Dictionary):
			continue
		var fx: Dictionary = (op as Array)[1]
		for k: String in fx:
			if k in ["curse", "curses", "gamble_curse", "need_curse", "uncurse"] and not open("curse"):
				return false
			if k in ["relic", "relic_twice", "next_relic"] and not open("relic"):
				return false
			if k == "gear" and not open("gear"):
				return false
	return true
