extends Node
## 关卡和肉鸽流程自动测试（无界面运行）：
##   godot --headless --path . res://tests/test_run.tscn
## 验证岔路地图、平台和楼梯、砸罐子开宝箱、破庙出发、房间锁门和波次、掉钱、商人、土地庙、死亡带回 60% 魂玉、打败柳江远、
## 装备掉落和换装、武器手感、防具减伤、饰品、流血、商人卖装备、兵器架、拾骨婆天赋、旧存档供台退魂玉、
## 清房三选一（招式、心法、强化、铜钱、替换、双人各选各的、死了清空）、招式谱、奇遇、记忆碎片和忆境、NPC 和头目台词。

var main: Node
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.save_path = "user://test_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	_reset_save()
	test_map_generation()
	test_gear_rolls()
	await _setup()
	await test_hub_and_start()
	await test_fight_room()
	await test_platforms_and_loot()
	await test_gear_swap()
	await test_shop_and_rest()
	await test_death_returns_home()
	await _setup()
	await test_talents()
	await _setup()
	await test_rack()
	test_reward_rolls()
	await _setup()
	await test_codex()
	await _setup()
	await test_rewards()
	_reset_save()
	await _setup()
	await test_events()
	_reset_save()
	await _setup()
	await test_story()
	test_room_layouts()
	await _setup()
	await test_features()
	_reset_save()
	test_old_altar_refund()
	await _setup()
	await _setup()
	await test_boss_victory()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	print("")
	if failures == 0:
		print("全部测试通过")
	else:
		print("失败 %d 项" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _setup() -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	for a in InputMap.get_actions():
		Input.action_release(a)
	Engine.time_scale = 1.0
	Game.practice = false
	Game.run = null
	Game.last_result = {}
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(3)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		main._hitstop_until = 0
		main._slow_until = 0
		Engine.time_scale = 1.0


func _reset_save() -> void:
	Game.save["jade"] = 0
	Game.save["talents"] = {}
	Game.save["weapons"] = ["katana"]
	Game.save["start_weapon"] = "katana"
	Game.save["arts"] = []
	Game.save["memories"] = []
	Game.save["meets"] = {}
	Game.save["clears"] = 0
	Game.save["runs"] = 0


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  通过  ", name)
	else:
		print("  失败  ", name)
		failures += 1


func _p() -> Player:
	return main.players[0]


func _find(kind: String, key: String = "", value: Variant = null) -> Interactable:
	for it: Interactable in main.interactables:
		if it.kind == kind and (key == "" or it.data.get(key) == value):
			return it
	return null


## 按一下键（界面在 _process 里读）
func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)


## 等黑屏过渡做完
func _wait_fade() -> void:
	for i in range(120):
		await _frames(1)
		if main._fade_dir == 0:
			return


func _kill_all() -> void:
	for e: Enemy in main.enemies:
		if e.state == Enemy.S.DEAD or e.state == Enemy.S.DYING:
			continue
		e.aggro = true
		e.state = Enemy.S.IDLE
		if e.is_grunt():
			e._die()
		else:
			while e.lives > 0:
				e.execute_by(_p())


## 走进指定的房间（改掉下一列的房间再进门）
func _enter_room(key: String) -> void:
	var r: Run = Game.run
	var col: int = r.node()["next"][0]
	r.rows[r.row + 1][col]["type"] = "fight"
	r.rows[r.row + 1][col]["room"] = key
	main._go_next(col)
	await _wait_fade()
	main.waves = [main.waves[0]] if not main.waves.is_empty() else []
	_kill_all()
	await _frames(130)


func _gate(id: String) -> Dictionary:
	for g: Dictionary in main.features.gates:
		if g["id"] == id:
			return g
	return {}


## 每间房的机关都摆得通：门有开关、坑跳得过去、门和出口不挤在一起
func test_room_layouts() -> void:
	print("房间机关布局")
	var bad := []
	var long_rooms := 0
	for key: String in LevelData.ROOMS:
		var def: Dictionary = LevelData.ROOMS[key]
		var feats: Array = def.get("features", [])
		var w := float(def.get("width", 800.0))
		if w >= 1800.0:
			long_rooms += 1
		var ex := float(def.get("exit_x", w))
		var supports := []
		for f: Array in feats:
			if f[0] == "plank" or f[0] == "ledge":
				var pw := float(f[3]) if f.size() > 3 else 48.0
				supports.append([float(f[1]) - pw / 2.0, float(f[1]) + pw / 2.0])
		for f: Array in feats:
			match String(f[0]):
				"gate":
					var opener := false
					for o: Array in feats:
						if (o[0] == "lever" or o[0] == "lantern") and o[2] == f[2] and float(o[1]) < float(f[1]):
							opener = true
					if not opener:
						bad.append("%s 的门 %s 没有开关" % [key, f[2]])
					if ex - 70.0 - 2 * 100.0 - float(f[1]) < 50.0:
						bad.append("%s 的门离出口太近" % key)
				"pit":
					# 坑里的落脚点连起来，每一跳不超过 125（走着跳 83，跑着跳 138，二段跳更远）
					var pts := [[float(f[1]), float(f[1])]]
					for sp: Array in supports:
						if sp[0] > float(f[1]) and sp[1] < float(f[2]):
							pts.append(sp)
					pts.append([float(f[2]), float(f[2])])
					pts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
					for i in range(pts.size() - 1):
						if pts[i + 1][0] - pts[i][1] > 125.0:
							bad.append("%s 的坑 %d-%d 跳不过去" % [key, f[1], f[2]])
		for wv: Array in def.get("waves", []):
			for sp: Array in wv:
				for f: Array in feats:
					if f[0] == "pit" and float(sp[1]) > float(f[1]) - 20.0 and float(sp[1]) < float(f[2]) + 20.0 and sp.size() <= 2:
						bad.append("%s 的 %s 站在坑上" % [key, sp[0]])
	_check(bad.is_empty(), "机关都摆得通 %s" % str(bad))
	_check(long_rooms >= 8, "战斗和精英房间有两三屏长（%d 间）" % long_rooms)
	var moods := {}
	for key: String in LevelData.ROOMS:
		moods[LevelData.ROOMS[key].get("mood", "")] = true
	_check(moods.size() >= 6, "至少六种天色（%s）" % str(moods.keys()))


func test_features() -> void:
	print("跑酷和解谜机关")
	main.interact(_find("door", "action", "start_run"), _p())
	await _wait_fade()
	await _enter_room("lane")
	var p := _p()
	var f: RoomFeatures = main.features
	_check(f.pits.size() == 2 and f.gates.size() == 1, "荒村小道有两个坑、一道寨门")
	_check(main.background is BgVillage and (main.background as BgVillage).mood == "dusk", "荒村小道是黄昏")
	# 掉坑
	p.invul_timer = 0.0
	p.global_position = Vector2(975, 299)
	await _frames(10)
	var hp := p.hp
	p.global_position = Vector2(1050, 260)
	await _frames(40)
	_check(p.hp < hp - p.max_hp * 0.1 and p.global_position.x < 1010.0 and p.global_position.y <= 301.0,
		"掉进坑里扣血，回到坑边（hp %.0f→%.0f x %.0f）" % [hp, p.hp, p.global_position.x])
	# 竹签
	await _frames(60)
	p.global_position = Vector2(1120, 299)
	await _frames(10)
	hp = p.hp
	p.global_position = Vector2(1170, 285)
	p.velocity = Vector2.ZERO
	await _frames(14)
	_check(p.hp < hp and p.velocity.y < 0.0, "踩到竹签扣血、被弹起来")
	# 烂木板
	await _frames(60)
	var pl: Dictionary = f.planks[0]
	p.global_position = Vector2(pl["x"], pl["top"] - 10.0)
	p.velocity = Vector2.ZERO
	await _frames(12)
	_check(p.is_on_floor() and absf(p.global_position.y - pl["top"]) < 3.0, "站上烂木板")
	await _frames(30)
	_check(pl["shape"].disabled, "站了半秒木板就塌了")
	await _frames(200)
	_check(not pl["shape"].disabled, "过几秒木板又搭好了")
	# 拉杆开门，过一会儿自己关上
	var g := _gate("a")
	p.global_position = Vector2(1700, 299)
	await _frames(5)
	Input.action_press("p1_right")
	await _frames(60)
	Input.action_release("p1_right")
	_check(p.global_position.x < g["x"] - 10.0, "门没开过不去（x %.0f）" % p.global_position.x)
	p.global_position = Vector2(1480, 299)
	p.facing = 1
	await _frames(5)
	await _attack()
	await _frames(5)
	_check(g["opened"] and g["shape"].disabled, "砍拉杆，门开了")
	await _frames(160)
	_check(not g["opened"] and not g["shape"].disabled, "限时门过了 2 秒多自己落下")
	# 敌人掉坑、走到坑边会停
	var dog: Enemy = main.spawn_enemy("dog", Vector2(1050, 250))
	dog.aggro = false
	await _frames(60)
	_check(dog.state == Enemy.S.DYING or dog.state == Enemy.S.DEAD, "野狗掉进坑里摔死")
	p.global_position = Vector2(880, 299)
	p.invul_timer = 99.0
	var dog2: Enemy = main.spawn_enemy("dog", Vector2(1130, 299))
	for i in range(120):
		await _frames(1)
		p.invul_timer = 99.0
	_check(dog2.state != Enemy.S.DYING and dog2.global_position.x > 1090.0, "野狗追到坑边停下（x %.0f）" % dog2.global_position.x)
	p.invul_timer = 0.0

	# 石灯笼
	await _enter_room("graves")
	f = main.features
	p = _p()
	_check((main.background as BgVillage).mood == "graves", "乱坟岗换了一套景")
	var ln: Dictionary = f.lanterns[0]
	f.hit(Rect2(ln["x"] - 5, ln["y"] - 30, 10, 20), p)
	_check(ln["lit"] > 0.0, "砍一刀点亮灯笼")
	await _frames(int(RoomFeatures.LANTERN_TIME * 60.0) + 10)
	_check(ln["lit"] <= 0.0 and not _gate("b")["opened"], "只点一盏，过一会儿灭了，门不开")
	for l2: Dictionary in f.lanterns:
		f.hit(Rect2(l2["x"] - 5, l2["y"] - 30, 10, 20), p)
		await _frames(30)
	_check(_gate("b")["opened"], "三盏同时亮着，门开了")
	await _frames(int(RoomFeatures.LANTERN_TIME * 60.0) + 10)
	_check(f.lanterns[0]["done"] and _gate("b")["opened"], "解开之后灯不再灭，门一直开着")

	# 裂墙密室
	await _enter_room("well")
	f = main.features
	p = _p()
	var cr: Dictionary = f.cracks[0]
	p.global_position = Vector2(cr["x"] - 30.0, 299)
	p.facing = 1
	await _frames(5)
	for i in range(RoomFeatures.CRACK_HP):
		await _attack()
		await _frames(25)
	_check(cr["broken"] and cr["shapes"][0].disabled, "砍三刀砸开裂墙")
	_check(_find("door").position.x < cr["x"], "出口门在裂墙左边，墙后面是密室")


## 轻攻击一下
func _attack() -> void:
	Input.action_press("p1_attack")
	await _frames(3)
	Input.action_release("p1_attack")
	await _frames(12)


func test_map_generation() -> void:
	print("岔路地图")
	var ok := true
	var crossing := false
	var branches := 0
	var fd := LevelData.floor_data(0)
	for s in range(300):
		var r := Run.create(0, s)
		if r.rows.size() != (fd["rows"] as Array).size() or r.rows[-1][0]["type"] != "boss" or r.rows[0][0]["type"] != "start":
			ok = false
		for i in range(r.rows.size() - 1):
			var reached := {}
			for j in range(r.rows[i].size()):
				var nxt: Array = r.rows[i][j]["next"]
				if nxt.is_empty() or nxt.size() > 3:
					ok = false
				if nxt.size() > 1:
					branches += 1
				for k: int in nxt:
					reached[k] = true
				# 线不交叉：后面的房间的最小出口不能小于前面房间的最大出口
				for j2 in range(j + 1, r.rows[i].size()):
					if (r.rows[i][j2]["next"] as Array).min() < nxt.max():
						crossing = true
			if reached.size() != r.rows[i + 1].size():
				ok = false
	_check(ok, "每个房间都有路进、有路出，起点在左、头目在最后")
	_check(not crossing, "路线不交叉")
	_check(branches > 300, "有岔路可选（%d 处）" % branches)


func test_hub_and_start() -> void:
	print("破庙出发")
	_check(main.mode == "hub", "开局在破庙")
	var gate := _find("door", "action", "start_run")
	_check(gate != null and gate.enabled, "有出发的门")
	_check(_find("talent") != null and _find("rack") != null, "有拾骨婆和兵器架")
	_check(_p().gear["weapon"]["base"] == "katana", "默认带太刀出发")
	main.interact(gate, _p())
	await _wait_fade()
	_check(main.mode == "room" and Game.run != null and Game.run.row == 0, "进到第一间（%s）" % main.mode)
	_check(main.cleared and _find("door").enabled, "村口没有敌人，门开着")
	_check(_p().auto_respawn == false, "闯关时倒下不会自动复活")


func test_fight_room() -> void:
	print("战斗房间：锁门、波次、掉钱")
	var r: Run = Game.run
	var door := _find("door")
	main.interact(door, _p())
	await _wait_fade()
	_check(r.row == 1 and r.room_type() == "fight", "走进第二间战斗房（%s）" % r.room_key())
	_check(not main.cleared and not _find("door").enabled, "有敌人时门锁着")
	var asleep := true
	for e: Enemy in main.enemies:
		if e.aggro:
			asleep = false
	_check(asleep, "第一批敌人站着等玩家走近")
	main.interact(_find("door"), _p())
	await _wait_fade()
	_check(r.row == 1, "锁着的门进不去")
	var waves: int = main.waves.size()
	var first: int = main.enemies.size()
	_kill_all()
	await _frames(90)
	if waves > 1:
		_check(main.enemies.size() > first, "清完第一批，第二批冲进来")
		_kill_all()
		await _frames(90)
	_check(main.cleared and _find("door").enabled, "全部清完门打开")
	await _frames(120)
	_check(r.coins > 0 and r.kills >= first, "敌人掉的铜钱飞到身上（铜钱 %d，斩敌 %d）" % [r.coins, r.kills])
	_check(r.jade >= 1, "清场给魂玉（%d）" % r.jade)


func test_platforms_and_loot() -> void:
	print("平台、楼梯、罐子、宝箱")
	var r: Run = Game.run
	var col: int = r.node()["next"][0]
	r.rows[r.row + 1][col]["type"] = "fight"
	r.rows[r.row + 1][col]["room"] = "lane"
	main._go_next(col)
	await _wait_fade()
	var p := _p()
	# 从楼梯走上二楼
	p.global_position = Vector2(120, 299)
	Input.action_press("p1_right")
	await _frames(75)
	Input.action_release("p1_right")
	await _frames(10)
	_check(p.on_platform() and p.global_position.y < 240.0, "顺着楼梯走上二楼（x %.0f y %.0f）" % [p.global_position.x, p.global_position.y])
	# 下+跳 落回地面
	Input.action_press("p1_down")
	await _frames(2)
	Input.action_press("p1_jump")
	await _frames(2)
	Input.action_release("p1_jump")
	Input.action_release("p1_down")
	await _frames(40)
	_check(p.is_on_floor() and p.global_position.y > 295.0, "下+跳 从二楼落回地面（y %.0f）" % p.global_position.y)
	# 敌人会跳上平台追
	p.global_position = Vector2(330, 229)
	p.invul_timer = 99.0
	await _frames(10)
	var dog: Enemy = main.spawn_enemy("dog", Vector2(300, 300))
	var highest := 300.0
	for i in range(150):
		await _frames(1)
		p.invul_timer = 99.0
		highest = minf(highest, dog.global_position.y)
	_check(highest < 235.0, "野狗跳上二楼追人（最高 y %.0f）" % highest)
	# 砸罐子
	var coins := r.coins
	var jar: Breakable = null
	for b: Breakable in main.breakables:
		if b.kind == "barrel":
			jar = b
	jar.hit(jar.global_position.x - 10.0)
	await _frames(12)
	jar.hit(jar.global_position.x - 10.0)
	_check(jar.broken, "木桶砍两刀碎掉")
	p.global_position = jar.global_position
	await _frames(100)
	_check(r.coins > coins, "木桶里的铜钱飞到身上（%d → %d）" % [coins, r.coins])
	# 屋顶上的宝箱
	var chest := _find("chest")
	_check(chest != null and chest.global_position.y < 200.0, "宝箱放在屋顶上")
	coins = r.coins
	main.interact(chest, p)
	p.global_position = chest.global_position
	await _frames(100)
	_check(not chest.enabled and r.coins >= coins + 8, "打开宝箱拿到铜钱（+%d）" % (r.coins - coins))
	_kill_all()
	await _frames(90)
	_kill_all()
	await _frames(90)


func test_shop_and_rest() -> void:
	print("商人、土地庙")
	var r: Run = Game.run
	# 把下一间改成商人，直接走进去
	var col: int = r.node()["next"][0]
	r.rows[r.row + 1][col]["type"] = "shop"
	r.rows[r.row + 1][col]["room"] = "merchant"
	main._go_next(col)
	await _wait_fade()
	_check(r.room_type() == "shop" and main.cleared, "商人房间门开着")
	var item := _find("item")
	_check(item != null, "摊子上有货")
	r.coins = 0
	main.interact(item, _p())
	_check(item.enabled, "钱不够买不了")
	r.coins = 100
	var id: String = item.data["id"]
	var cost: int = LevelData.SHOP_ITEMS[id]["cost"]
	main.interact(item, _p())
	_check(not item.enabled and r.coins == 100 - cost, "买下 %s 花 %d 铜钱" % [LevelData.SHOP_ITEMS[id]["name"], cost])
	var gear_it := _find("gear")
	_check(gear_it != null and int(gear_it.data.get("price", 0)) > 0, "摊子上有一件装备卖")
	if gear_it != null:
		var price := int(gear_it.data["price"])
		var gitem: Dictionary = gear_it.data["item"]
		r.coins = price
		main.interact(gear_it, _p())
		_check(r.coins == 0 and _p().gear.values().has(gitem), "买下装备直接换上（%s %d 铜钱）" % [GearData.display_name(gitem), price])
		_check(r.shop_gear_list()[0] == null, "买过的装备从摊子上撤下")
	r.coins = 100
	main._apply_item("whetstone")
	main._apply_item("amulet")
	main._apply_item("gourd")
	var atk := float(_p().stats["atk"]) - _gear_atk(_p())
	_check(is_equal_approx(atk, 0.15 + (0.15 if id == "whetstone" else 0.0)), "磨刀石加攻击（+%.2f）" % atk)
	_check(_p().max_hp >= 230.0 and _p().max_gourds >= 4, "护符加生命上限、空药罐加药罐（%d / %d）" % [_p().max_hp, _p().max_gourds])

	col = r.node()["next"][0]
	r.rows[r.row + 1][col]["type"] = "rest"
	r.rows[r.row + 1][col]["room"] = "roadside_shrine"
	main._go_next(col)
	await _wait_fade()
	var shrine := _find("rest")
	_p().hp = 20.0
	_p().gourds = 0
	main.interact(shrine, _p())
	_check(_p().hp == _p().max_hp and _p().gourds == _p().max_gourds, "土地庙上香回满")
	_check(not shrine.enabled, "香只能上一次")


func test_death_returns_home() -> void:
	print("身死回破庙")
	var r: Run = Game.run
	r.jade = 10
	var before: int = Game.save["jade"]
	_p()._die()
	await _frames(int(main.DEATH_DELAY * 60.0) + 10)
	_check(main.dead_wait, "出结算画面")
	var ev := InputEventAction.new()
	ev.action = "p1_attack"
	ev.pressed = true
	main._unhandled_input(ev)
	await _wait_fade()
	_check(main.mode == "hub" and Game.run == null, "回到破庙")
	_check(int(Game.save["jade"]) == before + 6, "魂玉带回 60%%（10 → %d）" % (int(Game.save["jade"]) - before))
	_check(_p().is_alive() and _p().hp == _p().max_hp, "在破庙满血站起来")
	var cfg := ConfigFile.new()
	_check(cfg.load(Game.save_path) == OK and int(cfg.get_value("save", "jade", 0)) == int(Game.save["jade"]), "魂玉写进存档")


## 装备上的攻击词条（磨刀石测试里扣掉）
func _gear_atk(p: Player) -> float:
	return float(GearData.totals(p.gear)["atk"])


func test_gear_rolls() -> void:
	print("装备生成")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok := true
	var qualities := {}
	for k in range(400):
		var item := GearData.roll(rng, [1.0, 1.0, 1.0, 1.0, 1.0])
		var q := int(item["q"])
		qualities[q] = true
		var cats := {}
		for a: Array in item["affixes"]:
			cats[GearData.AFFIXES[a[0]]["cat"]] = true
		if (item["affixes"] as Array).size() != int(GearData.QUALITIES[q]["affixes"]) or cats.size() != (item["affixes"] as Array).size():
			ok = false
		if q == 4 and (item["mech"] as Array).size() < 1:
			ok = false
		if GearData.describe(item).is_empty() and item["slot"] != "charm":
			ok = false
	_check(ok, "词条数按品质来、同类词条不重复、传说带专属机制")
	_check(qualities.size() == 5, "五种品质都能出")
	var boss := GearData.roll(rng, GearData.weights_for("boss", 7, 0), "weapon")
	_check(int(boss["q"]) == 4 and boss["slot"] == "weapon", "头目掉传说武器（%s）" % GearData.display_name(boss))
	var w0: Array = GearData.weights_for("chest", 2, 0)
	var w2: Array = GearData.weights_for("chest", 2, 2)
	_check(float(w2[0]) < float(w0[0]) and float(w2[2]) > float(w0[2]), "鉴宝让高品质更容易出")


func test_gear_swap() -> void:
	print("装备：捡起来换上")
	var p := _p()
	var rng := RandomNumberGenerator.new()
	var dummy: Enemy = main.spawn_enemy("ronin", Vector2(900, 300))
	dummy.aggro = false
	var base_atk := p.strike(Moves.get_move("slash1"), dummy)
	_check(is_equal_approx(float(base_atk["posture"]), 20.0), "太刀横斩架势伤害 20")
	_clear_gear()
	var nodachi := GearData.make("weapon", "nodachi", 2, rng)
	var it: Interactable = main._drop_gear(nodachi, p.global_position)
	_check(it != null and _find("gear") == it, "装备掉在地上")
	await _frames(2)
	_check(main.focus_gear.has(1), "站在跟前显示对比卡")
	main.interact(it, p)
	_check(p.gear["weapon"] == nodachi and p.look.weapon == "nodachi", "换上野太刀")
	var old := _find("gear")
	_check(old != null and old.data["item"]["base"] == "katana", "原来的太刀放回地上")
	_check((Game.save["weapons"] as Array).has("nodachi"), "野太刀挂上破庙兵器架")
	var atk := p._weapon_scaled(Moves.get_move("slash1"))
	_check(is_equal_approx(float(atk["dmg"]), 20.0 * 1.7 * 1.25) and float(atk["windup"]) > 0.07, "野太刀伤害 ×%.2f、出手更慢" % (float(atk["dmg"]) / 20.0))
	# 防具减伤
	p._enter(Player.S.FREE)
	p.invul_timer = 0.0
	p.hp = p.max_hp
	var hp0 := p.hp
	p.gear["body"] = GearData.make("body", "plate", 0, rng)
	main._apply_player_stats(p, false)
	p.receive_enemy_hit({"dmg": 71.0, "posture": 0.0, "unblockable": true, "kind": "slash"}, main.enemies[-1])
	var d := float(p.stats["def"])
	_check(d >= 11.0 and is_equal_approx(hp0 - p.hp, 71.0 * 60.0 / (60.0 + d)), "铁甲防御 %d：71 伤害只掉 %.1f" % [d, hp0 - p.hp])
	_check(is_equal_approx(p.max_posture, (100.0 + float(p.stats["max_posture"])) * 1.2), "铁甲架势上限 +20%%（%d）" % p.max_posture)
	p.hp = p.max_hp
	p._enter(Player.S.FREE)
	# 饰品：两格先填空的，满了换差的
	var c1 := GearData.make("charm", "jade_bead", 3, rng)
	var c2 := GearData.make("charm", "lucky_cat", 0, rng)
	p.gear["charm1"] = c1
	_check(GearData.target_slot(p.gear, c2) == "charm2", "第二个饰品放进空格")
	p.gear["charm2"] = c2
	_check(GearData.target_slot(p.gear, GearData.make("charm", "wind_bell", 1, rng)) == "charm2", "两格都满时换掉差的那件")
	main._apply_player_stats(p, false)
	_check(float(p.stats["parry_heal"]) == 0.02 and float(p.stats["coin"]) >= 0.4, "饰品机制算进数值")
	# 双短刃流血
	var e: Enemy = main.enemies[-1]
	e.hp = e.max_hp
	e.add_bleed()
	e.add_bleed()
	await _frames(62)
	_check(e.max_hp - e.hp >= 5.9 and e.max_hp - e.hp <= 9.1, "流血两层一秒掉 %.1f" % (e.max_hp - e.hp))
	e.queue_free()
	main.enemies.erase(e)
	p.gear = Game.run.loadout(1)
	p.gear["weapon"] = GearData.starter("katana")
	p.gear["body"] = null
	p.gear["charm1"] = null
	p.gear["charm2"] = null
	_clear_gear()
	main._apply_player_stats(p, false)


func _clear_gear() -> void:
	for x: Interactable in main.interactables.duplicate():
		if x.kind == "gear":
			main.interactables.erase(x)
			x.queue_free()


func test_talents() -> void:
	print("拾骨婆的天赋")
	var p := _p()
	var it := _find("talent")
	main.interact(it, p)
	_check(main.menu_player == p and p.frozen, "打开天赋界面，人站住不动")
	Game.save["jade"] = 20
	_check(Talents.why_not(1, 1, 0) != "", "第二层没投够点数点不了")
	_check(Talents.learn(1, 0, 0), "点亮 体魄")
	_check(int(Game.save["jade"]) == 17 and Talents.rank("vigor") == 1, "花 3 魂玉")
	Game.save["jade"] = 0
	_check(Talents.why_not(1, 0, 0) == "魂玉不够", "魂玉不够点不了")
	main.close_talents()
	_check(p.max_hp == 220.0 and not p.frozen, "离开后生命 +20（%d）" % p.max_hp)
	# 奥义三选一
	Game.save["jade"] = 1000
	for k in range(3):
		Talents.learn(1, 0, 1)
		Talents.learn(1, 0, 2)
	for k in range(2):
		Talents.learn(1, 1, 0)
		Talents.learn(1, 1, 1)
	_check(Talents.why_not(1, 3, 0) == "", "投够 10 点解锁奥义（已投 %d）" % Talents.spent_in(Talents.TREES[1]))
	Talents.learn(1, 3, 0)
	_check(Talents.why_not(1, 3, 1) == "奥义只能选一个", "奥义只能选一个")
	main._apply_player_stats(p, true)
	_check(p.max_gourds == 5 and int(p.stats["revive"]) == 1, "药缘 +2 药罐、不死身")
	var spent := Talents.jade_spent()
	var before := int(Game.save["jade"])
	_check(Talents.reset() == spent and int(Game.save["jade"]) == before + spent and Talents.rank("vigor") == 0, "洗髓退回全部魂玉（%d）" % spent)
	# 不死身：闯关时倒下一次站起来
	Game.save["talents"] = {"vigor": 3, "calm": 3, "hide": 3, "undying": 1}
	main.interact(_find("door", "action", "start_run"), p)
	await _wait_fade()
	_check(p.revives == 1, "出发时带一次不死身")
	p.hp = 1.0
	p.receive_enemy_hit({"dmg": 50.0, "posture": 0.0, "unblockable": true, "kind": "slash"}, p)
	_check(p.is_alive() and is_equal_approx(p.hp, p.max_hp * 0.5) and p.revives == 0, "倒下以一半生命站起来")
	# 行者：开局铜钱、商人打折、死亡多带回魂玉
	Game.save["talents"] = {"purse": 2, "haggle": 3, "homeward": 1}
	_check(main.shop_price(100) == 76, "识货三级 -24%%（%d）" % main.shop_price(100))
	_check(is_equal_approx(main.death_keep(), 0.8), "归途：带回 80%")
	Game.save["talents"] = {}
	Game.save["jade"] = 0


func test_rack() -> void:
	print("兵器架")
	Game.save["weapons"] = ["katana", "spear"]
	Game.save["start_weapon"] = "katana"
	var rack := _find("rack")
	main.interact(rack, _p())
	_check(Game.save["start_weapon"] == "spear" and _p().gear["weapon"]["base"] == "spear", "换成长枪出发")
	_check(_p().look.weapon == "spear" and not _p().look.saya, "长枪背在背上，没有刀鞘")
	var atk := _p()._weapon_scaled(Moves.get_move("slash4"))
	_check(atk.get("pierce", false) and float(atk["size"].x) > 66.0 * 1.4, "长枪突刺破盾、距离更远")
	main.interact(_find("door", "action", "start_run"), _p())
	await _wait_fade()
	_check(Game.run.loadout(1)["weapon"]["base"] == "spear", "出发带的是长枪")
	Game.run = null
	Game.save["weapons"] = ["katana"]
	Game.save["start_weapon"] = "katana"


func test_old_altar_refund() -> void:
	print("旧存档：供台换成天赋，魂玉退回")
	var cfg := ConfigFile.new()
	cfg.set_value("save", "jade", 3)
	cfg.set_value("save", "altar", {"vigor": 2, "purse": 1})
	cfg.save(Game.save_path)
	Game.load_save()
	_check(int(Game.save["jade"]) == 3 + 5 + 10 + 4, "供奉过的 19 魂玉退回来（%d）" % Game.save["jade"])
	var again := ConfigFile.new()
	again.load(Game.save_path)
	_check(not again.has_section_key("save", "altar"), "存档里不再有供台")
	_reset_save()
	Game.write_save()


func test_boss_victory() -> void:
	print("打败柳江远，通关回破庙")
	main.interact(_find("door", "action", "start_run"), _p())
	await _wait_fade()
	var r: Run = Game.run
	r.row = r.rows.size() - 2
	r.col = 0
	main._go_next(0)
	await _wait_fade()
	_check(r.room_type() == "boss" and main.enemies.size() == 1 and main.enemies[0].kind == "liu", "最后一间是柳江远")
	_check(main.enemies[0].state == Enemy.S.INTRO, "柳江远先演登场")
	_check(_find("door") == null, "头目房间没有出口")
	r.jade = 4
	var before: int = Game.save["jade"]
	_kill_all()
	await _frames(200)
	var home := _find("door", "action", "victory")
	_check(home != null and home.visible and home.enabled, "打完出现回破庙的门")
	_check(r.jade >= 4 + 15, "头目掉魂玉（%d）" % r.jade)
	var drop := _find("gear")
	_check(drop != null and int(drop.data["item"]["q"]) == 4, "头目掉一件传说装备（%s）" % (GearData.display_name(drop.data["item"]) if drop != null else "无"))
	var got := r.jade
	main.interact(home, _p())
	await _wait_fade()
	_check(main.mode == "hub" and int(Game.save["jade"]) == before + got, "通关魂玉全部带回（+%d）" % (int(Game.save["jade"]) - before))
	_check(int(Game.save["clears"]) >= 1, "记一次通关")
	_check(int(Game.save["meets"].get("liu", 0)) == 1, "记一次见到柳江远")
	_check(Story.has("liu_0"), "第一次打败柳江远，想起他的第一段身世")


# ---------- 招式和心法 ----------

func test_reward_rolls() -> void:
	print("三选一抽奖励")
	Game.save["arts"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var b := Arts.new_build()
	var seen := {}
	var coins := 0
	var ok := true
	for i in range(300):
		var cs := Arts.roll_choices(rng, b, "fight", 2)
		var keys := {}
		for c: Dictionary in cs:
			var k := "%s:%s" % [c["kind"], c.get("id", "")]
			if keys.has(k):
				ok = false
			keys[k] = true
			seen[c.get("id", "coin")] = true
			if c["kind"] == "coin":
				coins += 1
				ok = ok and int(c["amount"]) == 19
		ok = ok and cs.size() == 3
	_check(ok, "每次三个，不重复；铜钱 15 + 每列 2")
	_check(not (seen.has("issen") or seen.has("kage") or seen.has("ukifune") or seen.has("ryuun") or seen.has("ketsuon")),
		"没加进招式谱的不会出现")
	_check(seen.has("kuujin") and seen.has("kongo") and seen.has("houzan") and seen.has("fudoshin") and seen.has("whirl"),
		"谱上的招式、心法、回旋斩强化都会出现")
	_check(coins > 0, "战斗房有时给铜钱（%d 次）" % coins)
	var elite_ok := true
	for i in range(300):
		for c: Dictionary in Arts.roll_choices(rng, b, "elite", 2):
			if c["kind"] == "coin" or (c["kind"] == "art" and int(c["lv"]) != 2):
				elite_ok = false
	_check(elite_ok, "精英房：新招式直接 2 级，不给铜钱")
	# 能拿的都拿完了：拿铜钱补
	var full := {"arts": [{"id": "whirl", "lv": 3}, {"id": "kuujin", "lv": 3}, {"id": "houzan", "lv": 3}],
		"minds": ["fudoshin", "zanshin", "jiri"]}
	var cs2 := Arts.roll_choices(rng, full, "fight", 0)
	_check(cs2.size() == 2 and cs2[-1]["kind"] == "coin", "选项不够三个用一份铜钱补（%s）" % str(cs2.map(func(c: Dictionary) -> String: return c["kind"])))
	_check(Arts.needs_replace(full, {"kind": "art", "id": "kongo", "lv": 1}), "招式满三个要替换")
	_check(not Arts.needs_replace(full, {"kind": "mind", "id": "ryuun"}), "心法三个还能装")


func test_codex() -> void:
	print("招式谱：用魂玉加进掉落池")
	Game.save["arts"] = []
	Game.save["jade"] = 30
	var it := _find("codex")
	_check(it != null, "破庙里有招式谱")
	main.interact(it, _p())
	_check(main.codex_player == _p() and _p().frozen, "打开招式谱，人站住")
	await _press("p1_down")
	_check(main.codex_ids(0)[main.codex_cursor.y] == "issen", "往下一格是一心")
	await _press("p1_attack")
	_check(Arts.in_pool("art", "issen") and int(Game.save["jade"]) == 10, "花 20 魂玉把一心加进掉落池（剩 %d）" % int(Game.save["jade"]))
	await _press("p1_right")
	await _press("p1_down")
	_check(main.codex_ids(1)[main.codex_cursor.y] == "ryuun", "换到心法列：流云")
	await _press("p1_attack")
	_check(not Arts.in_pool("mind", "ryuun") and main.hud.menu_note == "魂玉不够", "魂玉不够加不了")
	await _press("p1_guard")
	_check(main.codex_player == null and not _p().frozen, "格挡离开")
	var cfg := ConfigFile.new()
	_check(cfg.load(Game.save_path) == OK and (cfg.get_value("save", "arts", []) as Array).has("issen"), "写进存档")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen := false
	for i in range(300):
		for c: Dictionary in Arts.roll_choices(rng, Arts.new_build(), "fight", 0):
			if c.get("id", "") == "issen":
				seen = true
	_check(seen, "加进去以后奖励里会出现一心")
	Game.save["arts"] = []


## 设定三选一的三个选项（测试里不靠随机）
func _offer(type: String, choices: Array) -> void:
	main.open_rewards(type)
	for idx: int in main.rewards:
		main.rewards[idx]["choices"] = choices.duplicate(true)
	await _frames(1)   # 弹出的那一帧按键不算


func test_rewards() -> void:
	print("清房三选一")
	Game.save["arts"] = []
	var p := _p()
	main.interact(_find("door", "action", "start_run"), p)
	await _wait_fade()
	var r: Run = Game.run
	_check(p.build == r.build(1) and Arts.art_count(p.build) == 1 and p.build["arts"][0]["id"] == "whirl", "出发只带回旋斩")
	await _enter_room("lane")
	_check(main.rewards.has(1) and (main.rewards[1]["choices"] as Array).size() == 3, "清完战斗房弹出三选一")
	_check(p.frozen, "选的时候人站住")
	var three := [{"kind": "art", "id": "kuujin", "lv": 1}, {"kind": "mind", "id": "fudoshin"}, {"kind": "coin", "amount": 15}]
	await _offer("fight", three)
	await _press("p1_attack")
	_check(main.rewards.is_empty() and not p.frozen, "按攻击选定，界面关掉")
	_check(p.build["arts"][1] != null and p.build["arts"][1]["id"] == "kuujin", "空刃斩装进第二格（←→）")
	await _offer("fight", three)
	await _press("p1_right")
	await _press("p1_attack")
	_check(p.build["minds"] == ["fudoshin"] and is_equal_approx(float(p.stats["parry_rebound"]), 0.3), "心法装上，数值生效")
	var before := r.coins
	await _offer("fight", three)
	await _press("p1_left")
	await _press("p1_attack")
	_check(r.coins == before + 15, "选铜钱进钱袋（%d → %d）" % [before, r.coins])
	await _offer("fight", [{"kind": "up", "id": "kuujin", "lv": 2}])
	await _press("p1_attack")
	_check(int(p.build["arts"][1]["lv"]) == 2, "强化空刃斩到 2 级")
	# 格子满了：先选换掉哪个，格挡能退回去
	p.build["arts"][2] = {"id": "houzan", "lv": 1}
	await _offer("elite", [{"kind": "art", "id": "kongo", "lv": 2}])
	await _press("p1_attack")
	_check(main.rewards.has(1) and int(main.rewards[1]["replace"]) == 0, "三格满了，先选换掉哪个")
	await _press("p1_guard")
	_check(int(main.rewards[1]["replace"]) == -1, "格挡退回选卡")
	await _press("p1_attack")
	await _press("p1_right")
	await _press("p1_attack")
	_check(p.build["arts"][1]["id"] == "kongo" and int(p.build["arts"][1]["lv"]) == 2, "换掉第二格，精英给 2 级金刚没")
	# 双人各选各的
	var p2: Player = main._spawn_player(2)
	await _frames(2)
	_check(p2.build == r.build(2) and p2.build != p.build, "2P 有自己的招式")
	await _offer("fight", [{"kind": "mind", "id": "zanshin"}, {"kind": "mind", "id": "fudoshin"}, {"kind": "coin", "amount": 15}])
	_check(main.rewards.size() == 2, "两个人各有一份")
	await _press("p1_attack")
	_check(not main.rewards.has(1) and main.rewards.has(2) and not p.frozen and p2.frozen, "1P 选完能动，2P 还在选")
	await _press("p2_right")
	await _press("p2_attack")
	_check(main.rewards.is_empty() and p2.build["minds"] == ["fudoshin"] and p2.build["arts"][1] == null, "2P 选了心法，招式还是自己的")
	_check(p.build["minds"] == ["fudoshin", "zanshin"], "1P 选的残心只给 1P")
	main._remove_player(2)
	# 精英房清完也弹
	var col: int = r.node()["next"][0]
	r.rows[r.row + 1][col]["type"] = "elite"
	r.rows[r.row + 1][col]["room"] = "shrine_ronin"
	main._go_next(col)
	await _wait_fade()
	main.waves = [main.waves[0]]
	_kill_all()
	await _frames(130)
	_check(main.rewards.has(1) and main.rewards[1]["type"] == "elite", "精英房清完弹出精英奖励")
	main._close_rewards()
	# 死了清空
	p._die()
	await _frames(int(main.DEATH_DELAY * 60.0) + 10)
	var ev := InputEventAction.new()
	ev.action = "p1_attack"
	ev.pressed = true
	main._unhandled_input(ev)
	await _wait_fade()
	_check(main.mode == "hub" and Arts.art_count(p.build) == 1 and (p.build["minds"] as Array).is_empty(), "回破庙后招式心法清空")
	_check(is_equal_approx(float(p.stats["parry_rebound"]), 0.0), "心法数值也没了")


# ---------- 奇遇和剧情 ----------

## 下一间换成指定奇遇的奇遇房，走进去
func _enter_event(eid: String) -> void:
	var r: Run = Game.run
	var col: int = r.node()["next"][0]
	var nd: Dictionary = r.rows[r.row + 1][col]
	nd["type"] = "event"
	nd["room"] = "mountain_fork"
	nd["event"] = eid
	main._go_next(col)
	await _wait_fade()
	await _frames(5)


func test_events() -> void:
	print("奇遇")
	var with_event := 0
	var dup := false
	for i in range(200):
		var rr := Run.create(0, i)
		var evs := []
		for row: Array in rr.rows:
			for nd: Dictionary in row:
				if nd["type"] == "event":
					evs.append(nd["event"])
		if not evs.is_empty():
			with_event += 1
		for e: String in evs:
			if evs.count(e) > 1:
				dup = true
	_check(with_event > 100, "多数地图上有奇遇房（%d/200）" % with_event)
	_check(not dup, "一局里奇遇不重复")
	var p := _p()
	main.interact(_find("door", "action", "start_run"), p)
	await _wait_fade()
	var r: Run = Game.run
	# 血祭石：扣 25% 生命，只给招式的三选一
	await _enter_event("blood_altar")
	var it := _find("event")
	_check(it != null and it.enabled and main.cleared and _find("door").enabled, "奇遇房中间摆着血祭石，门开着")
	main.interact(it, p)
	_check(main.event_player == p and p.frozen, "打开奇遇，人站住")
	await _press("p1_attack")
	_check(main.event_player == null and is_equal_approx(p.hp, p.max_hp * 0.75), "割掌献血扣 25%% 生命（%.0f）" % p.hp)
	var all_art := true
	for c: Dictionary in main.rewards.get(1, {}).get("choices", []):
		if c["kind"] != "art" and c["kind"] != "coin":
			all_art = false
	_check(main.rewards.has(1) and all_art and main.rewards[1]["type"] == "event", "弹出只有招式的三选一")
	await _press("p1_attack")
	_check(Arts.art_count(p.build) == 2, "拿到一个新招式")
	_check(not it.enabled and r.events_done.has(r.room_id()), "选过了就不能再选")
	main.interact(it, p)
	_check(main.event_player == null, "再按下打不开")
	# 赌客：铜钱不够押不了，离开不算选过
	await _enter_event("gambler")
	r.coins = 5
	it = _find("event")
	_check(it != null and it.label == "" and it.sub == "路边赌客", "赌客是个人站着")
	main.interact(it, p)
	await _press("p1_attack")
	_check(main.event_player == p and main.hud.menu_note == "铜钱不够", "铜钱不够押不了")
	await _press("p1_guard")
	_check(main.event_player == null and it.enabled, "离开不算选过，回头还能来")
	# 无名坟：挖坟有埋伏，门锁上，打完才开
	await _enter_event("grave_mound")
	it = _find("event")
	main.interact(it, p)
	await _press("p1_down")
	await _press("p1_attack")
	await _frames(3)
	_check(main.enemies.size() == 3 and not main.cleared and not _find("door").enabled, "挖坟冒出三个敌人，门锁上")
	_kill_all()
	await _frames(120)
	_check(main.cleared and _find("door").enabled, "打完门开了")
	_check(r.jade >= 5, "坟里的魂玉到手（%d）" % r.jade)
	# 受伤的浪人：分他一罐药，换一片记忆
	await _enter_event("wounded_ronin")
	var gourds := p.gourds
	main.interact(_find("event"), p)
	await _press("p1_attack")
	_check(p.gourds == gourds - 1 and Story.has("blade_0"), "分一罐药，拿到第一片记忆")
	# 碎铜镜：刃意清空、扣 10% 生命，再拿一片记忆
	await _enter_event("mirror")
	p.will = 60.0
	var hp := p.hp
	main.interact(_find("event"), p)
	await _press("p1_attack")
	_check(p.will == 0.0 and is_equal_approx(p.hp, hp - p.max_hp * 0.1) and Story.has("blade_1"), "照镜子：刃意清空、扣血，又想起一片")
	# 选项文字
	_check(Events.describe(Events.get_event("gambler")["options"][0]) == "铜钱 -15  →  铜钱 +40（50% 成功）", "选项说明：%s" % Events.describe(Events.get_event("gambler")["options"][0]))


func test_story() -> void:
	print("记忆碎片和剧情")
	_check(Story.next_fragment() == "blade_0", "第一片是“断刃”")
	var got := Story.collect("blade_0")
	_check(got == ["断刃", 1, 3] and Story.next_fragment() == "blade_1", "拿到一片，下一片接着给同一段")
	_check(Story.collect("blade_0").is_empty(), "拿过的不重复记")
	Story.collect("blade_1")
	Story.collect("blade_2")
	_check(Story.next_fragment() == "five_0", "一段拼完给下一段")
	_check(Story.boss_fragment("liu", 1) == "liu_0" and Story.boss_fragment("liu", 4) == "", "柳江远的身世按打败次数给")
	var cfg := ConfigFile.new()
	_check(cfg.load(Game.save_path) == OK and (cfg.get_value("save", "memories", []) as Array).size() == 3, "写进存档")
	# 忆境
	var it := _find("memory")
	_check(it != null, "破庙里有忆境")
	main.interact(it, _p())
	_check(main.memory_player == _p() and _p().frozen, "打开忆境")
	await _press("p1_down")
	_check(main.memory_cursor == 1, "往下选下一段")
	await _press("p1_guard")
	_check(main.memory_player == null and not _p().frozen, "格挡离开")
	# NPC 台词随轮回变化
	var mem: Array = Game.save["memories"]
	Game.save["memories"] = []
	Game.save["runs"] = 0
	var base := ["老话"]
	_check(Story.npc_lines("granny", base) == base, "第一次来只说老话")
	Game.save["runs"] = 3
	var lines := Story.npc_lines("granny", base)
	_check(lines.size() == 2 and lines[0] != "老话", "出发三次后先说新的（%s）" % lines[0])
	Game.save["memories"] = mem
	# 头目见面次数换台词
	var liu: Dictionary = EnemyData.TYPES["liu"]
	_check(Story.intro_for(liu, 1) == liu["intro"] and Story.intro_for(liu, 2) == liu["intro"], "头两次是原来的登场台词")
	_check(Story.intro_for(liu, 3) == liu["intro_meets"][3] and Story.intro_for(liu, 4) == liu["intro_meets"][3], "第三、四次换一套")
	_check(Story.intro_for(liu, 7) == liu["intro_meets"][5], "第五次以后再换")
	# 精英掉记忆
	main.grant_memory(Story.next_fragment(), Vector2(300, 200))
	_check(Story.has("five_0"), "掉落的记忆碎片记下来")
	Game.save["runs"] = 0
