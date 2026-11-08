class_name Act3
extends RefCounted
## 第三幕“出山”的流程挂钩：ArpgMain 在几个地方调这里（出发、进房间、山门、头目前后、剧情效果、侧室）。
## 文本在 act3_story.gd，敌人在 act3_foe.gd，场景在 act3_arena.gd。
##
## 存档键：
##   arpg_last_end2      第二幕最后一次看到的结局（zhan / du / he），第三幕开场按它分三种
##   arpg_xiaoman_home   第二幕结局时小满跟着（第三幕柳溪村她带路）
##   arpg_ahe_home       阿禾送回山门（站在刀匠旁边）
##   arpg_villages       七村名录认到第几条（下标数组）
##   arpg_act3_runs      走过几次第三幕
##   arpg_act3_endings   看过的最终结局
##   arpg_side3          三种独有侧室各进过哪种

const PORTAL_POS := Vector3(-10.0, 0, -6.5)
const C_PORTAL := Color(1.0, 0.62, 0.35)
## 第三幕三层独有的侧室
const UNIQUE := {"liuxi": "hall", "post": "stable", "palace": "treasury"}

static var _jin: Follower


## 山门出现“出山”光门：第二幕看过任一结局（或测试参数 --act3）
static func open(main: ArpgMain) -> bool:
	return not (Game.save.get("arpg_act2_endings", {}) as Dictionary).is_empty() or main._args.has("act3")


## 第二幕最后一次结局（老存档没记的话，按看过的最好结局算）
static func last_end2() -> String:
	var e := String(Game.save.get("arpg_last_end2", ""))
	if e != "":
		return e
	var seen: Dictionary = Game.save.get("arpg_act2_endings", {})
	for k: String in ["he", "du", "zhan"]:
		if seen.has(k):
			return k
	return "zhan"


## 第二幕结局时记下来（ArpgMain._act2_ending 调）
static func on_act2_end(state: ArpgState, id: String) -> void:
	Game.save["arpg_last_end2"] = id
	if state.flags.has("xiaoman"):
		Game.save["arpg_xiaoman_home"] = true
	Game.write_save()


## 这一局的加成：带着石门的灯（攻击、气力）、喂过驿马（移动）
static func run_stats(st: ArpgState, stats: Dictionary) -> void:
	if st.flags.has("lamp_carried"):
		ArpgData.add_stats(stats, {"atk": 0.15, "energy": 0.2})
	if st.flags.has("stable_fed"):
		ArpgData.add_stats(stats, {"move": 0.12})


## 出发：把第一、二幕的选择带进来（剧情遭遇、头目对白用）
static func start_run(main: ArpgMain) -> void:
	var st := main.state
	for g: String in ArpgState.ACT1_GROUPS:
		var f := ArpgState.act1(g)
		if f != "":
			st.flags["a1_" + f] = true
	var e2 := last_end2()
	st.flags["a2_" + e2] = true
	if e2 == "he":
		st.flags["jin"] = true          # 合刃：烬全程跟着
	if bool(Game.save.get("arpg_xiaoman_home", false)):
		st.flags["xm_home"] = true
	# 阿禾：在山门见过刀匠，磨坊里见她；没见过刀匠、也没人带路，她来带路
	if not bool(Game.save.get("arpg_ahe_home", false)):
		if bool(Game.save.get("arpg_smith_met", false)):
			st.flags["ahe_mill"] = true
		elif not st.flags.has("a1_ronin_saved") and not st.flags.has("xm_home"):
			st.flags["guide_ahe"] = true
	Game.save["arpg_act3_runs"] = int(Game.save.get("arpg_act3_runs", 0)) + 1
	Game.write_save()
	ArpgAch.unlock("act3")


## 进房间后（ArpgMain._enter_room 末尾调）
static func enter_room(main: ArpgMain, kind: String) -> void:
	var st := main.state
	if st.flags.has("jin"):
		ensure_jin(main)
	if kind != "start" or st.run.row != 0:
		return
	var fl := st.floor_i()
	if fl >= Act3Story.FLOOR_START.size():
		return
	var a := main._args
	if not a.has("demo") and not a.has("lineup") and not main._first_intro:
		var fs: Array = (Act3Story.FLOOR_START[fl] as Array).duplicate()
		if fl == 0:
			fs = (Act3Story.OPEN.get(last_end2(), Act3Story.OPEN["zhan"]) as Array) + fs
		main.get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if main.mode == "room" and main._menu == null:
				main._say(fs))
	var pr: Array = Act3Story.FIRST_PROP[fl]
	main._npc(String(pr[0]), Vector3(-4.5, 0, -2.5), {"kit": pr[1], "scale": 1.3}, func(n: ArpgNpc) -> void:
		var lines: Array = (pr[2] as Array).duplicate()
		if not n.used:
			n.used = true
			lines.append(["", "（魂玉 +%d）" % Act3Story.FIRST_PROP_JADE])
			for i in range(Act3Story.FIRST_PROP_JADE):
				main._loot(n.global_position + Vector3(0, 0, 1.0), "jade", 1)
			Game.sfx("memory")
		main._say(lines))


## 烬跟在身后（合刃，或者驿站约他同去）
static func ensure_jin(main: ArpgMain) -> void:
	if is_instance_valid(_jin) and not _jin.is_queued_for_deletion():
		return
	_jin = Follower.new()
	main.add_child(_jin)
	_jin.setup("jin", Color.WHITE, 1.0, "烬")
	_jin.hero = main.hero
	_jin.global_position = main.hero.global_position + Vector3(-1.5, 0, 1.5)


## 山门：出山光门、阿禾、七村名录碑
static func hub(main: ArpgMain) -> void:
	if open(main):
		var ar := main.arena
		ar.kit("post_lantern", PORTAL_POS + Vector3(-1.6, 0, -0.8), 0.0, 1.0, true)
		ar.kit("post_lantern", PORTAL_POS + Vector3(1.6, 0, -0.8), 0.0, 1.0, true)
		ar.spirit_fire(PORTAL_POS + Vector3(0, 1.2, -1.2), C_PORTAL, 1.2, 2.0, 7.0)
		main._make_secret_portal(PORTAL_POS, "act3", C_PORTAL)
	if bool(Game.save.get("arpg_ahe_home", false)):
		main._npc("阿禾", Vector3(11.0, 0, 3.5), {"model": "npc_he"}, func(_n: ArpgNpc) -> void:
			main._say(Act3Story.AHE_HUB))
	if not Act3Story.villages().is_empty():
		main._npc("七村名录 %d / %d" % [Act3Story.villages().size(), Act3Story.VILLAGES.size()], Vector3(-12.0, 0, -2.5),
			{"kit": "gravestone", "scale": 1.4}, func(_n: ArpgNpc) -> void: read_villages(main))


static func read_villages(main: ArpgMain) -> void:
	var lines := [["", "一块新立的石碑，刻着被点过灯的村子。"]]
	var got := Act3Story.villages()
	for i in range(Act3Story.VILLAGES.size()):
		if got.has(i):
			lines.append([String(Act3Story.VILLAGES[i][0]), String(Act3Story.VILLAGES[i][1]), Act3Story.C_VILLAGER])
	if got.size() < Act3Story.VILLAGES.size():
		lines.append(["", "（还有 %d 个村子没有认回来）" % (Act3Story.VILLAGES.size() - got.size())])
	main._say(lines)


## 认下一条村名，返回要说的话（都认齐了返回空）
static func village_lines() -> Array:
	var vi := Act3Story.take_village()
	if vi < 0:
		return []
	var v: Array = Act3Story.VILLAGES[vi]
	var out := [[String(v[0]), String(v[1]), Act3Story.C_VILLAGER],
		["", "（七村名录 %d / %d：%s）" % [Act3Story.villages().size(), Act3Story.VILLAGES.size(), String(v[0])]]]
	if Act3Story.villages_done():
		ArpgAch.unlock("villages")
		out.append(["", "七个村子的名字都认回来了。"])
	return out


## 剧情效果里第三幕自己的几项（ArpgMain._story_effect 末尾调）
static func story_effect(main: ArpgMain, fx: Dictionary) -> void:
	var st := main.state
	var lines := []
	if fx.get("talk", "") == "chief":
		lines.append_array(Act3Story.CHIEF_TALK)
	if fx.has("village"):
		lines.append_array(village_lines())
	if fx.has("whet"):
		st.whet += int(fx["whet"])
		main.hero.apply_stats(st.stats(), st.weapon)
		main.feel.callout(main.hero.head_top(), "磨刀 · 伤害 +%d%%" % int(round(ArpgState.WHET_ATK * 100 * st.whet)), Color(1.0, 0.75, 0.4), 1.1)
	if fx.has("jin"):
		st.flags["jin"] = true
		ArpgAch.unlock("jin_along")
		ensure_jin(main)
	if fx.get("save", "") == "arpg_ahe_home":
		ArpgAch.unlock("ahe_home")
		lines.append_array(Act3Story.AHE_HOME)
		lines.append(["", "（阿禾回山门了，以后在刀匠身边）"])
	if not lines.is_empty():
		main.get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if main.mode == "room":
				main._say(lines))


# ---------- 头目 ----------

static func boss_pre(key: String) -> Array:
	return Act3Story.BOSS_PRE.get(key, [])


static func boss_pre_flags(key: String) -> Dictionary:
	return Act3Story.BOSS_PRE_FLAGS.get(key, {})


static func boss_post(key: String) -> Array:
	if key == "boss10":
		return Finale.POST
	return Act3Story.BOSS_POST.get(key, [])


## 头目登场对话说完：约了烬的，终战多一次倒下再起
static func boss_intro_done(main: ArpgMain, key: String) -> void:
	if key in ["boss9", "boss10"] and main.state.flags.has("jin_along"):
		main.hero.revives += 1
		main.feel.callout(main.hero.head_top(), "烬在你身后 · 多一次倒下再起", Act3Story.C_JIN, 1.6)


## 头目战后的选择
static func boss_choice(main: ArpgMain, key: String) -> void:
	match key:
		"boss7":
			_choice(main, "火师焦明", "柳溪村的人围了过来，看着你，也看着他。", Act3Story.JIAO_CHOICE, Act3Story.C_JIAO,
				[Act3Story.JIAO_TO_VILLAGE, Act3Story.JIAO_BY_HAND], "溪水那头，官道上有车辙往北去")
		"boss8":
			_choice(main, "灯车", "油布下面，灰白的灯火安安静静地烧着。", Act3Story.LAMP_CHOICE, Act3Story.C_HUO,
				[Act3Story.LAMP_BROKEN, Act3Story.LAMP_TAKEN], "三百里外，王都的灯亮着")
		"boss9":
			# 看过真结局：龙椅底下有心跳，可以下去打隐藏头目烛王（Finale）
			if not Finale.after_emperor(main):
				final_choice(main)


static func _choice(main: ArpgMain, title: String, sub: String, opts: Array, col: Color, after: Array, floor_sub: String) -> void:
	var items := []
	for o: Array in opts:
		items.append({"title": o[0], "desc": o[1], "color": col})
	var m := main._open_menu(title, sub, items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		main._close_menu()
		var fx: Dictionary = opts[i][2]
		var st := main.state
		if fx.has("flag"):
			st.flags[String(fx["flag"])] = true
		if fx.has("jade"):
			st.add_jade(int(fx["jade"]))
			main.feel.callout(main.hero.head_top(), "魂玉 +%d" % int(fx["jade"]), Color(0.55, 1.0, 0.85), 1.2)
		main.hero.apply_stats(st.stats(), st.weapon)
		var lines: Array = (after[i] as Array).duplicate()
		if fx.has("village"):
			lines.append_array(village_lines())
		var d := main._say(lines)
		d.finished.connect(func() -> void:
			st.add_jade(6)
			if fx.has("boon"):
				# 多选一次心法，然后照常过层
				var offer := st.roll_boons(3, main._rng)
				var its := []
				for b: Dictionary in offer:
					its.append({"title": b["name"], "desc": b["desc"], "tag": main._school_tag(String(b["school"])), "color": ArpgData.SCHOOL_COLORS.get(b["school"], ArpgMenu.TEAL)})
				var mm := main._open_menu("心法", "三选一", its, "cards", false)
				mm.chosen.connect(func(j: int) -> void:
					main._take_boon(String(offer[j]["id"]))
					main._close_menu()
					main._act2_floor_done(floor_sub))
			else:
				main._act2_floor_done(floor_sub)))


## 全作最终结局：灯尽、守灯总能选；归途要第二幕合刃 + 七村名录七条齐
static func final_choice(main: ArpgMain) -> void:
	var a2: Dictionary = Game.save.get("arpg_act2_endings", {})
	var true_ok := a2.has("he") and Act3Story.villages_done()
	var opts := [["douse", "灯尽", "熄灭全部的灯。皇帝化作灰，七村的魂都走了", true],
		["keep", "守灯", "留在宫里做第二个守灯人。不点新的，也不灭旧的", true],
		["true", "归途", "（隐藏）用合起来的刀，一盏一盏念着村名斩断灯芯" if true_ok else Act3Story.TRUE_NEED, true_ok]]
	var items := []
	for o: Array in opts:
		items.append({"title": o[1], "desc": o[2], "enabled": o[3], "color": (Color(1.0, 0.85, 0.5) if o[0] == "true" else Act3Story.C_EMPEROR) if o[3] else Color(0.5, 0.5, 0.55)})
	var m := main._open_menu("长明灯", "殿里的灯一排一排亮着，每一盏里都有人。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var id: String = opts[i][0]
		main._close_menu()
		var e: Dictionary = Act3Story.ENDINGS3[id]
		var seen: Dictionary = Game.save.get("arpg_act3_endings", {})
		seen[id] = true
		Game.save["arpg_act3_endings"] = seen
		Game.write_save()
		ArpgAch.unlock("end3_" + id)
		main.state.add_jade(40 if id == "true" else 20)
		var lines: Array = (e["lines"] as Array).duplicate()
		lines.append(["", "（第三幕 · 出山　完）"])
		var d := main._say(lines)
		d.finished.connect(func() -> void:
			main.hud.banner(String(e["title"]), "残刃归途", 4.5)
			Game.sfx("reward")
			main.get_tree().create_timer(3.0).timeout.connect(func() -> void: main._game_over(true, String(e["title"])))))


# ---------- 侧室 ----------

## 遗骸侧室里的旧事（第三幕三层）
const LORE := {
	"liuxi": [
		[["", "屋里供着一排牌位，最新的一块还没上漆。香炉里插着三根没点的香。"], ["牌位背面", "“柳溪村里正 陈守田。庚子年冬，献灯。”字是用指甲刻的。"]],
		[["", "织机上还挂着一匹没织完的布，梭子掉在地上。"], ["", "布上织了一半的图案，是一盏灯。你在织机底下摸到几枚魂玉。"]],
	],
	"post": [
		[["", "驿丞的铺盖卷还在，枕头底下压着一封家信。"], ["驿丞的信", "“灯车又过去了。车上的人不哭也不闹，只是一直往南看。儿啊，别来京城。”"]],
		[["", "墙上贴着一张告示，雨水洇得只剩半张。"], ["告示", "“奉旨：各驿见灯车即让道。私窥者，斩。”下面有人用炭写了两个字：“石门”。"]],
	],
	"palace": [
		[["", "一间小小的偏殿，墙上挂满了画像，都是同一个人，从年轻画到老。"], ["", "最后一张没有画脸，只画了四盏灯。你在画轴里摸到几枚魂玉。"]],
		[["", "太监的值房，桌上一本起居注。"], ["起居注", "“上夜不寐，独坐灯前。问左右：今年点的是哪一村？左右不敢对。”"]],
	],
}


## 第三幕独有的侧室：祠堂（上香回血或得心法）、马厩（喂驿马跑得快 / 翻鞍袋）、内库（金、御用装备、未点的宫灯三选一）
static func side_content(sr: SideRoom, mid: Vector3) -> ArpgNpc:
	var main := sr.main
	var ar := sr.arena
	match sr.kind:
		"hall":
			for i in range(5):
				ar.kit("candles", sr.at(0.88, 0.2 + i * 0.15), 0.0, 0.8, false)
			ar.spirit_fire(sr.at(0.9, 0.5) + Vector3(0, 0.6, 0), Color(1.0, 0.75, 0.45), 0.8, 1.4, 5.0)
			return main._npc(sr.display_name(), mid, {"kit": "shrine", "scale": 1.3}, func(n: ArpgNpc) -> void: _use_hall(sr, n))
		"stable":
			var hz: VoxelGrid = ar._cached("a3_horse", Act3._horse)
			ar.voxel_piece(hz, sr.at(0.82, 0.4), 0.12, null, Vector3(1.6, 2, 0.8), false, 0.0)
			if ar is Arena3:
				ar.voxel_piece(ar._cached("haystack", (ar as Arena3)._haystack), sr.at(0.86, 0.78), 0.12, null, Vector3(1.4, 2, 1.4))
			return main._npc("驿马", sr.at(0.6, 0.4), {"kit": "", "scale": 1.0}, func(n: ArpgNpc) -> void: _use_stable(sr, n))
		"treasury":
			for i in range(4):
				ar.kit("box" if i % 2 == 0 else "crates", sr.at(0.88, 0.2 + i * 0.2), 0.0, 1.0, true)
			for i in range(3):
				sr._coin_pile(sr.at(randf_range(0.3, 0.8), randf_range(0.25, 0.75)))
			return main._npc(sr.display_name(), mid, {"kit": "box", "scale": 1.5}, func(n: ArpgNpc) -> void: _use_treasury(sr, n))
	return null


## 一匹体素驿马（马厩用）
static func _horse() -> VoxelGrid:
	var g := VoxelGrid.new(377)
	var c := Color(0.42, 0.28, 0.18)
	var dark := Color(0.18, 0.12, 0.08)
	for lx: int in [-5, 4]:
		for lz: int in [-2, 1]:
			g.box(Vector3i(lx, 0, lz), Vector3i(lx + 1, 6, lz + 1), c * 0.85, 0.05)
			g.box(Vector3i(lx, 0, lz), Vector3i(lx + 1, 0, lz + 1), dark, 0.0)
	g.box(Vector3i(-6, 6, -2), Vector3i(6, 10, 2), c, 0.08)
	g.box(Vector3i(5, 9, -1), Vector3i(7, 14, 1), c, 0.06)
	g.box(Vector3i(7, 12, -1), Vector3i(11, 15, 1), c, 0.06)
	g.box(Vector3i(10, 12, -1), Vector3i(11, 13, 1), dark, 0.0)
	g.box(Vector3i(4, 14, 0), Vector3i(7, 15, 0), dark, 0.0)
	g.box(Vector3i(-8, 5, 0), Vector3i(-7, 9, 0), dark, 0.05)
	g.box(Vector3i(-2, 10, -2), Vector3i(2, 11, 2), Color(0.55, 0.2, 0.15), 0.05)   # 鞍
	return g


static func _done(sr: SideRoom) -> void:
	sr.stage = "done"
	sr._count()
	var got: Array = Game.save.get("arpg_side3", [])
	if not got.has(sr.kind):
		got.append(sr.kind)
		Game.save["arpg_side3"] = got
		Game.write_save()
	if got.size() >= UNIQUE.size():
		ArpgAch.unlock("side_act3")
	sr._update_label()


static func _use_hall(sr: SideRoom, n: ArpgNpc) -> void:
	if n.used:
		return
	var main := sr.main
	var items := [
		{"title": "上一炷香", "desc": "回复 40% 生命，药葫芦 +1"},
		{"title": "磕三个头", "desc": "替柳溪村的人记着：选一个心法"},
		{"title": "离开", "desc": ""},
	]
	var m := main._open_menu(sr.display_name(), "一排排牌位，有的还没上漆。", items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		main._close_menu()
		if i == 2:
			return
		n.used = true
		_done(sr)
		Game.sfx("memory")
		main.vfx.sheet("soul-rise", n.global_position, 3.2, Color(1.0, 0.8, 0.5), 1.8)
		if i == 0:
			main._heal(0.4)
			if main.hero.gourds < main.hero.max_gourds:
				main.hero.gourds += 1
			main.hud.banner("香火", "回复生命，药葫芦 +1", 1.6)
		else:
			main.get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if main._menu == null:
					main._offer_boons_then(1)))


static func _use_stable(sr: SideRoom, n: ArpgNpc) -> void:
	if n.used:
		return
	var main := sr.main
	var st := main.state
	var cost := st.price(15)
	var items := [
		{"title": "喂草料（%d 文）" % cost, "desc": "驿马蹭了蹭你：这一局移动 +12%", "enabled": st.coins >= cost},
		{"title": "翻鞍袋", "desc": "驿卒落下的铜钱：铜钱 +30"},
		{"title": "离开", "desc": ""},
	]
	var m := main._open_menu(sr.display_name(), "一匹瘦马拴在槽边，饿得直刨地。", items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		main._close_menu()
		if i == 2 or (i == 0 and st.coins < cost):
			return
		n.used = true
		_done(sr)
		if i == 0:
			st.coins -= cost
			st.flags["stable_fed"] = true
			main.hero.apply_stats(st.stats(), st.weapon)
			main.feel.callout(main.hero.head_top(), "驿马 · 移动 +12%", Color(0.75, 0.9, 1.0), 1.2)
			Game.sfx("reward", -4.0)
		else:
			for j in range(6):
				main._loot(n.global_position + Vector3(0, 0, 1.0), "coin", 5)
			Game.sfx("coin", -2.0))


static func _use_treasury(sr: SideRoom, n: ArpgNpc) -> void:
	if n.used:
		return
	var main := sr.main
	var items := [
		{"title": "一箱金子", "desc": "铜钱 +80"},
		{"title": "御用的甲胄", "desc": "一件上品装备"},
		{"title": "一盏未点的宫灯", "desc": "灯里没有人：选一个心法"},
	]
	var m := main._open_menu(sr.display_name(), "只能拿一样。门口的金吾卫随时会回来。", items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		main._close_menu()
		n.used = true
		_done(sr)
		Game.sfx("reward", -3.0)
		if i == 0:
			for j in range(10):
				main._loot(n.global_position + Vector3(0, 0, 1.2), "coin", 8)
		elif i == 1:
			main._drop_gear(n.global_position + Vector3(0, 0, 1.5), 3, 0.2)
		else:
			main.vfx.sheet("soul-rise", n.global_position, 3.0, Color(1.0, 0.9, 0.55), 1.8)
			main.get_tree().create_timer(0.5).timeout.connect(func() -> void:
				if main._menu == null:
					main._offer_boons_then(1)))


## 遗骸侧室里的七村名录（第三幕三层，一次一条）
static func side_finds(lines: Array) -> void:
	if Act3Story.villages_done():
		return
	var tail: Array = lines.pop_back()
	lines.append_array(village_lines())
	lines.append(tail)
