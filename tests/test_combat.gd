extends Node
## 战斗规则自动测试（无界面运行）：
##   godot --headless --path . res://tests/test_combat.tscn
## 用模拟按键驱动主角，验证弹反、格挡、看破、跳过横扫、处决、重击、药罐、刃意招式、架势、双人加成。

var main: Node
var p: Player
var e: Enemy
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _setup()
	await test_parry_three_hits()
	await _setup()
	await test_block_builds_posture()
	await _setup()
	await test_unguarded_hit()
	await _setup()
	await test_mikiri_thrust()
	await _setup()
	await test_jump_over_sweep()
	await _setup()
	await test_posture_break_and_execute()
	await _setup()
	await test_heavy_attack()
	await _setup()
	await test_gourd()
	await _setup()
	await test_gourd_interrupted()
	await _setup()
	await test_art()
	await _setup()
	await test_stances()
	await _setup()
	await test_coop_scaling()
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
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	p = main.players[0]
	e = main.enemies[0]
	e.attack_cooldown = 9999.0   # 由测试控制出招
	e.rng.seed = 1
	p.global_position = Vector2(400, 300)
	e.global_position = Vector2(460, 300)
	p.facing = 1
	await _frames(5)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
		# 测试里不等真实时间，直接结束顿帧
		main._hitstop_until = 0
		main._slow_until = 0
		Engine.time_scale = 1.0


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  通过  ", name)
	else:
		print("  失败  ", name)
		failures += 1


## 等敌人第 hit 段进入前摇末尾（距离判定还剩 lead 秒）
func _wait_windup_end(hit: int, lead: float) -> void:
	for i in range(300):
		if e.state == Enemy.S.WINDUP and e.hit_index == hit:
			var w: float = e._hit_times()[0] * e._speed()
			if e.state_time >= w - lead:
				return
		await _frames(1)


func test_parry_three_hits() -> void:
	print("弹反三连斩")
	e._start_move("slash")
	for hit in range(3):
		await _wait_windup_end(hit, 0.06)
		await _tap("p1_guard")
		await _frames(12)
	_check(p.parry_count == 3, "三段都弹反成功（实际 %d）" % p.parry_count)
	_check(is_equal_approx(e.posture, 45.0), "敌人架势 +15×3 = 45（实际 %.1f）" % e.posture)
	_check(is_equal_approx(p.hp, p.max_hp), "主角没掉血")
	_check(is_equal_approx(p.posture, 22.5), "主角架势 +7.5×3 = 22.5（实际 %.1f）" % p.posture)


func test_block_builds_posture() -> void:
	print("按住格挡")
	Input.action_press("p1_guard")
	await _frames(20)   # 已过弹反窗口
	e._start_move("slash")
	await _frames(150)
	Input.action_release("p1_guard")
	_check(p.parry_count == 0, "没有弹反")
	_check(is_equal_approx(p.hp, p.max_hp), "格挡不掉血")
	_check(is_equal_approx(p.posture, 90.0), "三段格挡架势 +90（实际 %.1f）" % p.posture)


func test_unguarded_hit() -> void:
	print("不防御被砍")
	e._start_move("quick")
	await _frames(40)
	_check(is_equal_approx(p.hp, p.max_hp - 20.0), "掉 20 血（实际 %.1f）" % p.hp)


func test_mikiri_thrust() -> void:
	print("看破突刺")
	p.global_position = Vector2(370, 300)
	e._start_move("thrust")
	await _wait_windup_end(0, 0.02)
	Input.action_press("p1_right")
	await _tap("p1_dodge")
	await _frames(3)
	Input.action_release("p1_right")
	await _frames(10)
	_check(is_equal_approx(p.hp, p.max_hp), "没被刺中（hp %.1f）" % p.hp)
	_check(e.state == Enemy.S.STAGGER, "敌人被强制僵直（状态 %d）" % e.state)
	_check(e.posture >= 79.0, "敌人架势 +40%%（实际 %.1f）" % e.posture)


func test_jump_over_sweep() -> void:
	print("跳过下段横扫并踩头")
	e._start_move("sweep")
	await _wait_windup_end(0, 0.25)
	Input.action_press("p1_right")
	await _tap("p1_jump")
	var stomped := false
	for i in range(80):
		await _frames(1)
		if p.global_position.x >= e.global_position.x:
			Input.action_release("p1_right")
		if e.posture >= 59.0:
			stomped = true
			break
	Input.action_release("p1_right")
	_check(is_equal_approx(p.hp, p.max_hp), "没被横扫打中（hp %.1f）" % p.hp)
	_check(stomped, "踩头奖励架势 +30%%（实际 %.1f）" % e.posture)


func test_posture_break_and_execute() -> void:
	print("架势崩溃与处决")
	e.posture = e.max_posture - 5.0
	e.state = Enemy.S.WINDUP   # 出招中不会格挡
	e.move_key = "slash"
	e.hit_index = 0
	e.state_time = 0.0
	await _tap("p1_attack")
	await _frames(15)
	_check(e.state == Enemy.S.BROKEN, "敌人架势崩溃（状态 %d）" % e.state)
	await _frames(25)
	await _tap("p1_attack")
	await _frames(2)
	_check(e.lives == 1, "处决扣一管血（剩 %d）" % e.lives)
	_check(p.will >= 35.0, "处决攒刃意 +35（实际 %.0f）" % p.will)
	await _frames(90)
	_check(e.phase2 and is_equal_approx(e.hp, e.max_hp) and e.posture == 0.0, "进入第二管血，生命回满")


func test_heavy_attack() -> void:
	print("长按重击")
	e.state = Enemy.S.WINDUP
	e.move_key = "sweep"
	e.state_time = -10.0   # 让敌人保持前摇，不会出手
	Input.action_press("p1_attack")
	await _frames(45)
	Input.action_release("p1_attack")
	await _frames(20)
	_check(is_equal_approx(e.hp, e.max_hp - 30.0), "重击伤害 30（实际 %.1f）" % (e.max_hp - e.hp))
	_check(is_equal_approx(e.posture, 60.0), "重击架势伤害 ×2 = 60（实际 %.1f）" % e.posture)


func test_gourd() -> void:
	print("药罐")
	p.hp = 50.0
	await _tap("p1_heal")
	await _frames(70)
	_check(is_equal_approx(p.hp, 130.0), "回 40%% 生命 = +80（实际 %.1f）" % p.hp)
	_check(p.gourds == Player.MAX_GOURDS - 1, "用掉一个药罐（剩 %d）" % p.gourds)


func test_gourd_interrupted() -> void:
	print("喝药被打断")
	p.hp = 100.0
	await _tap("p1_heal")
	e._start_move("quick")
	await _frames(70)
	_check(is_equal_approx(p.hp, 80.0), "被砍中，这口药没喝到（hp %.1f）" % p.hp)
	_check(p.gourds == Player.MAX_GOURDS - 1, "药罐照样用掉（剩 %d）" % p.gourds)


func test_art() -> void:
	print("刃意招式·回旋斩")
	await _tap("p1_art")
	await _frames(5)
	_check(p.state != Player.S.ART, "刃意不足时放不出来")
	p.will = 50.0
	e.state = Enemy.S.WINDUP
	e.move_key = "sweep"
	e.state_time = -10.0
	await _tap("p1_art")
	await _frames(60)
	_check(is_equal_approx(p.will, 10.0), "消耗 40 刃意（剩 %.0f）" % p.will)
	_check(is_equal_approx(e.posture, 80.0), "两圈各一次判定，架势 +40×2 = 80（实际 %.1f）" % e.posture)
	_check(is_equal_approx(e.max_hp - e.hp, 44.0), "伤害 22×2 = 44（实际 %.1f）" % (e.max_hp - e.hp))


func _hold_enemy() -> void:
	e.state = Enemy.S.WINDUP
	e.move_key = "sweep"
	e.state_time = -10.0   # 一直前摇，不格挡也不出手


func test_stances() -> void:
	print("架势")
	await _tap("p1_stance")
	await _frames(2)
	_check(p.stance()["id"] == "iai", "按架势键切到拔刀式（实际 %s）" % p.stance()["id"])
	await _frames(30)
	_check(p.is_sheathed(), "拔刀式站着时刀在鞘里")
	_hold_enemy()
	await _tap("p1_attack")
	await _frames(20)
	_check(is_equal_approx(e.max_hp - e.hp, 30.0), "居合第一刀伤害 20×1.5 = 30（实际 %.1f）" % (e.max_hp - e.hp))
	_check(not p.is_sheathed(), "砍完刀在手上")
	await _frames(90)
	_check(p.is_sheathed(), "过一会儿收刀入鞘")

	await _setup()
	p.stance_index = 2   # 上段
	_hold_enemy()
	await _tap("p1_attack")
	await _frames(25)
	_check(is_equal_approx(e.posture, 32.0), "上段第一刀架势 20×1.6 = 32（实际 %.1f）" % e.posture)

	await _setup()
	p.stance_index = 3   # 下段
	await _tap("p1_guard")
	await _frames(1)
	_check(is_equal_approx(p.parry_timer, Game.PARRY_WINDOW + 0.04 - 1.0 / 60.0) or p.parry_timer > Game.PARRY_WINDOW,
		"下段弹反窗口加长（%.3f 秒）" % p.parry_timer)
	for i in range(Stance.LIST.size()):
		_check(Player.POSES.has("st_" + str(Stance.LIST[i]["id"])), "架势「%s」有姿势" % Stance.LIST[i]["name"])


func test_coop_scaling() -> void:
	print("双人加成")
	main._spawn_player(2)
	await _frames(2)
	_check(is_equal_approx(e.max_hp, 480.0), "敌人生命 ×1.6 = 480")
	_check(is_equal_approx(e.max_posture, 280.0), "敌人架势 ×1.4 = 280")
	main._remove_player(2)
	await _frames(2)
	_check(is_equal_approx(e.max_hp, 300.0), "2P 退出后恢复")
