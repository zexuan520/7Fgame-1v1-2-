extends Node
## 关卡和肉鸽流程自动测试（无界面运行）：
##   godot --headless --path . res://tests/test_run.tscn
## 验证岔路地图、平台和楼梯、砸罐子开宝箱、破庙出发、房间锁门和波次、掉钱、商人、土地庙、死亡带回 60% 魂玉、打败柳江远、供台。

var main: Node
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.save_path = "user://test_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	test_map_generation()
	await _setup()
	await test_hub_and_start()
	await test_fight_room()
	await test_platforms_and_loot()
	await test_shop_and_rest()
	await test_death_returns_home()
	await _setup()
	await test_altar()
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
	_check(_find("altar") != null, "有供台")
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
	_check(not chest.enabled and r.coins >= coins + 12, "打开宝箱拿到铜钱（+%d）" % (r.coins - coins))
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
	r.coins = 100
	main._apply_item("whetstone")
	main._apply_item("amulet")
	main._apply_item("gourd")
	_check(is_equal_approx(_p().dmg_mult, 1.15 + (0.15 if id == "whetstone" else 0.0)), "磨刀石加攻击（×%.2f）" % _p().dmg_mult)
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


func test_altar() -> void:
	print("破庙供台")
	Game.save["jade"] = 20
	Game.save["altar"] = {}
	var it := _find("altar", "id", "vigor")
	main.interact(it, _p())
	_check(Game.altar_level("vigor") == 1 and int(Game.save["jade"]) == 15, "供奉 5 魂玉，体魄升一级")
	_check(_p().max_hp == 220.0, "初始生命 +20（%d）" % _p().max_hp)
	Game.save["jade"] = 0
	main.interact(it, _p())
	_check(Game.altar_level("vigor") == 1, "魂玉不够供不了")
	Game.save["altar"] = {}


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
	var got := r.jade
	main.interact(home, _p())
	await _wait_fade()
	_check(main.mode == "hub" and int(Game.save["jade"]) == before + got, "通关魂玉全部带回（+%d）" % (int(Game.save["jade"]) - before))
	_check(int(Game.save["clears"]) >= 1, "记一次通关")
