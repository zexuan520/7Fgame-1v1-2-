class_name ArpgRoutes
extends RefCounted
## 加长的一层和分岔支线（三幕九层都用）：
##   加房间：在主路中段多插两列（一列三间：战 / 战 / 精英；一列两间：战 / 试炼或商人），一层从 8 间走到 10 间。
##   分岔支线：地图最下面多一条三间的小路，从主路分出去、走完再合回主路：
##     支线一 战斗（阵更凶，清完多给铜钱）→ 支线二 宝箱或试炼 → 支线三 秘处（每层一种，三样别处拿不到的东西选一样）。
## 节点上带 "branch"（支线 id）和 "bstep"（第几间，1~3）。ArpgState.remap 末尾调 expand，存档里的地图带着这些标记。

const ACTS := [1, 2, 3]            # 哪几幕用加长地图和支线
const EXTRA_ROWS := [
	[["fight", 2], ["elite", 1]],   # 一列三间（后面再随机挑）
	[["fight", 1], ["trial", 1]],
]

## 每层一条支线：名字、门口一句话、秘处的名字和摆设、三样奖励
const ROUTES := {
	# ---------- 第一幕 ----------
	"forest": {"name": "樱林小径", "desc": "落满花瓣的旧路，通到村后那棵老樱树", "nook": "老樱树下", "kit": "tree_dead",
		"lines": [["", "林子深处有一棵老樱树，树干上刻着两道身高线，一高一矮。"],
			["残刃", "……矮的那道是阿樱。她总踮着脚。", ArpgStory.C_HERO]],
		"rewards": [
			["树洞里的护身符", "这一局生命上限 +30", {"route_stats": {"hp": 30.0}}],
			["树下的木刀", "一件传说装备", {"gear": 4}],
			["在树下坐一会儿", "生命、药葫芦补满，再多一个药葫芦", {"heal": 1, "route_stats": {"gourds": 1.0}}]]},
	"grave": {"name": "守墓人小道", "desc": "坟间一条踩出来的小道，通到守墓人的屋", "nook": "守墓人的屋", "kit": "coffin",
		"lines": [["", "屋里只有一张床、一盏灯、一本名册。名册最后一页写着守墓人自己的名字，后面空着日子。"]],
		"rewards": [
			["守墓人的灯", "这一局多一次倒下再起", {"revive": 1}],
			["陪葬的刀", "一件传说装备", {"gear": 4}],
			["替他填上日子", "魂玉 +8，铜钱 +30", {"jade": 8, "coins": 30}]]},
	"temple": {"name": "后山竹径", "desc": "寺后的竹林小路，通到师父常去的竹亭", "nook": "竹亭", "kit": "lantern",
		"lines": [["", "竹亭里摆着一副没下完的棋。黑子少了一颗，被人攥走了。"],
			["残刃", "师父总让我执黑。……原来那颗在我这儿。", ArpgStory.C_HERO]],
		"rewards": [
			["竹影", "这一局会心率 +10%", {"route_stats": {"crit": 0.1}}],
			["师父的批注", "连选两个心法", {"boon": 2}],
			["一壶冷茶", "这一局攻击 +8%，回满生命", {"route_stats": {"atk": 0.08}, "heal": 1}]]},
	# ---------- 第二幕 ----------
	"well": {"name": "暗渠", "desc": "井壁后面的一条旧水渠，通到沉在水里的佛龛", "nook": "沉井佛龛", "kit": "shrine",
		"lines": [["", "水里半埋着一座小佛龛，佛像的手断了，掌心里卡着一串佛珠。"],
			["", "佛珠是枯荣的。四十年了，一颗都没少。"]],
		"rewards": [
			["枯荣的佛珠", "这一局多一次倒下再起", {"revive": 1}],
			["沉经", "连选两个心法", {"boon": 2}],
			["井底的寒铁片", "这一局攻击 +10%", {"route_stats": {"atk": 0.1}}]]},
	"vault": {"name": "殉葬道", "desc": "甲士俑坑后的窄道，通到铸灯匠的炉", "nook": "铸灯匠的炉", "kit": "candles",
		"lines": [["", "一座小炉，炉边倒着一具铸灯匠的骸骨，手里还握着锤子。炉膛里的火是他自己点的，不是灯火。"]],
		"rewards": [
			["烛铜甲片", "这一局生命上限 +40", {"route_stats": {"hp": 40.0}}],
			["铸灯匠的锤", "一件传说装备", {"gear": 4}],
			["炉底的铜", "铜钱 +60，魂玉 +4", {"coins": 60, "jade": 4}]]},
	"camp": {"name": "营后马道", "desc": "灰衣营后面的马道，通到一座废望楼", "nook": "废望楼", "kit": "banner",
		"lines": [["", "望楼上没有人。弩还架着，箭囊是满的，旁边压着一张换防的条子：“第三伍，阿七。”"]],
		"rewards": [
			["弩手的箭囊", "这一局会心率 +10%", {"route_stats": {"crit": 0.1}}],
			["灰衣军需", "铜钱 +50，生命、药葫芦补满", {"coins": 50, "heal": 1}],
			["军官的佩刀", "一件传说装备", {"gear": 4}]]},
	# ---------- 第三幕 ----------
	"liuxi": {"name": "后山小路", "desc": "放牛娃走的小路，绕过镇灯卫，通到山神庙", "nook": "山神庙", "kit": "shrine",
		"lines": [["", "小路尽头是一座塌了半边的山神庙。供桌上落满了灰，香炉里却插着三根新香。"],
			["", "有人比你先来过。是阿禾，还是阿七？"]],
		"rewards": [
			["山神的护符", "这一局生命上限 +40", {"route_stats": {"hp": 40.0}}],
			["庙后的山泉", "生命、药葫芦补满，再多一个药葫芦", {"heal": 1, "route_stats": {"gourds": 1.0}}],
			["香案下的刀", "一件传说装备", {"gear": 4}]]},
	"post": {"name": "废驿道", "desc": "雨里一条荒了的旧驿道，通到烽火台", "nook": "烽火台", "kit": "banner",
		"lines": [["", "烽火台上的柴早就湿透了。台下靠着一具驿卒的骸骨，怀里抱着一封没送出去的军报。"]],
		"rewards": [
			["烽燧的余火", "这一局会心率 +10%", {"route_stats": {"crit": 0.1}}],
			["驿卒的军报", "连选两个心法", {"boon": 2}],
			["驿卒的靴子", "这一局移动 +10%，铜钱 +40", {"route_stats": {"move": 0.1}, "coins": 40}]]},
	"palace": {"name": "冷宫夹道", "desc": "宫墙之间的窄道，通到没人记得的冷宫", "nook": "冷宫", "kit": "candles",
		"lines": [["", "冷宫里只有一盏灯，没点。灯下坐着一具宫女的骸骨，手里攥着一张纸。"],
			["宫女的遗书", "“我家在芦渡。灯车来的那天，我在河边洗衣裳。……我想回家。”"]],
		"rewards": [
			["那盏没点的灯", "这一局多一次倒下再起", {"revive": 1}],
			["冷宫里的旧甲", "一件传说装备", {"gear": 4}],
			["替她记着", "魂玉 +10，七村名录 +1", {"jade": 10, "village": 1}]]},
}


static func enabled(st: ArpgState) -> bool:
	return ACTS.has(st.act) and ROUTES.has(st.zone())


## 把这一层的地图加长、加一条支线（只做一次：rows[0][0] 上记着）
static func expand(st: ArpgState) -> void:
	var run := st.run
	var rows: Array = run.rows
	if rows.is_empty() or bool(rows[0][0].get("expanded", false)) or not enabled(st):
		return
	rows[0][0]["expanded"] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = st.seed_value + run.floor_index * 307 + 11
	# 1) 主路中段多插两列（插在“歇脚”前面那几列之间）
	var at := maxi(rows.size() - 4, 2)
	for k in range(EXTRA_ROWS.size()):
		var types: Array = []
		for pair: Array in EXTRA_ROWS[k]:
			for i in range(int(pair[1])):
				types.append(String(pair[0]))
		if k == 1 and rng.randf() < 0.4:
			types[1] = "shop"
		_shuffle(types, rng)
		var row := []
		for t: String in types:
			row.append({"type": t, "room": "", "next": [], "visited": false})
		rows.insert(at + k, row)
	# 2) 重新连线（主路），已走过的第一间保持 visited
	for r: Array in rows:
		for nd: Dictionary in r:
			nd["next"] = []
	run._connect()
	# 3) 支线：从第 s 列最下面那间分出去，接下来三列各多一间，第四列合回最下面那间
	var s := rng.randi_range(1, rows.size() - 6)
	var rid := st.zone()
	var kinds := ["fight", "treasure" if rng.randf() < 0.5 else "trial", "nook"]
	for k in range(3):
		var r: Array = rows[s + 1 + k]
		r.append({"type": kinds[k], "room": "", "next": [], "visited": false, "branch": rid, "bstep": k + 1})
	(rows[s].back()["next"] as Array).append((rows[s + 1] as Array).size() - 1)
	for k in range(2):
		(rows[s + 1 + k].back()["next"] as Array).append((rows[s + 2 + k] as Array).size() - 1)
	# 合回去：第 s+4 列的主路最后一间（支线节点不在那一列）
	(rows[s + 3].back()["next"] as Array).append((rows[s + 4] as Array).size() - 1)


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


static func route_of(nd: Dictionary) -> Dictionary:
	return ROUTES.get(String(nd.get("branch", "")), {})


## 分岔路卡片上的小字（支线的房间写“支线 · 后山小路 1/3”）
static func card_tag(nd: Dictionary) -> String:
	var rt := route_of(nd)
	if rt.is_empty():
		return "岔路"
	return "支线 · %s %d/3" % [rt["name"], int(nd.get("bstep", 1))]


static func card_desc(nd: Dictionary, base: String) -> String:
	var rt := route_of(nd)
	if rt.is_empty():
		return base
	if int(nd.get("bstep", 1)) == 1:
		return "%s。走完三间合回主路，尽头是%s" % [rt["desc"], rt["nook"]]
	return base


## 这一局从支线拿的加成（Act3.run_stats 调）
static func run_stats(st: ArpgState, stats: Dictionary) -> void:
	var rs: Dictionary = st.flags.get("route_stats", {})
	if not rs.is_empty():
		ArpgData.add_stats(stats, rs)


## 进房间（ArpgMain._enter_room 末尾调）：支线的房间报一下名字；秘处摆奖励
static func enter_room(main: ArpgMain, kind: String) -> void:
	var nd: Dictionary = main.state.run.node()
	var rt := route_of(nd)
	if rt.is_empty() and kind == "nook":
		rt = ROUTES.get(main.state.zone(), {})   # 测试 --room=nook 直接进
	if rt.is_empty():
		return
	var step := int(nd.get("bstep", 3))
	main.get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if main.mode == "room":
			main.hud.banner("支线 · %s" % rt["name"], "第 %d / 3 间%s" % [step, "　尽头是" + String(rt["nook"]) if step < 3 else ""], 2.0))
	if kind == "nook":
		main.hud.zone_name = "%s · %s" % [main.state.floor_name(), rt["nook"]]
		main.arena.spirit_fire(Vector3(0, 0.6, -2.5), Color(1.0, 0.75, 0.45), 1.4, 2.2, 8.0)
		main._npc(String(rt["nook"]), Vector3(0, 0, -1.5), {"kit": rt["kit"], "scale": 1.4}, func(n: ArpgNpc) -> void: _open_nook(main, n, rt))
		main._open_portal()


## 支线清场多给一把铜钱（支线第一间的战斗）
static func cleared(main: ArpgMain) -> void:
	var nd: Dictionary = main.state.run.node()
	if route_of(nd).is_empty():
		return
	for i in range(6):
		main._loot(main.hero.global_position + main.hero.facing * 1.2, "coin", 5)


static func _open_nook(main: ArpgMain, n: ArpgNpc, rt: Dictionary) -> void:
	if n.used:
		return
	var d := main._say(rt["lines"])
	d.finished.connect(func() -> void:
		var items := []
		for r: Array in rt["rewards"]:
			items.append({"title": r[0], "desc": r[1], "color": Color(1.0, 0.8, 0.5)})
		var m := main._open_menu(String(rt["nook"]), "支线的尽头。三样东西，只能带走一样。", items, "list", false)
		m.chosen.connect(func(i: int) -> void:
			n.used = true
			main._close_menu()
			ArpgAch.unlock("route_end")
			_mark_route(String(main.state.run.node().get("branch", main.state.zone())))
			var fx: Dictionary = (rt["rewards"][i][2] as Dictionary).duplicate(true)
			var st := main.state
			if fx.has("route_stats"):
				var rs: Dictionary = st.flags.get("route_stats", {})
				var add: Dictionary = fx["route_stats"]
				for k: String in add:
					rs[k] = float(rs.get(k, 0.0)) + float(add[k])
				st.flags["route_stats"] = rs
				fx.erase("route_stats")
			if fx.has("revive"):
				main.hero.revives += int(fx["revive"])
				fx.erase("revive")
				main.feel.callout(main.hero.head_top(), "多一次倒下再起", Color(1.0, 0.85, 0.5), 1.4)
			Game.sfx("reward", -3.0)
			main.vfx.sheet("soul-rise", n.global_position, 3.2, Color(1.0, 0.8, 0.5), 1.8)
			main._story_effect(fx, n)))


## 三条支线各走到过哪条（都走到：成就）
static func _mark_route(id: String) -> void:
	if id == "":
		return
	var got: Array = Game.save.get("arpg_routes", [])
	if not got.has(id):
		got.append(id)
		Game.save["arpg_routes"] = got
		Game.write_save()
	if got.size() >= ROUTES.size():
		ArpgAch.unlock("routes_all")
