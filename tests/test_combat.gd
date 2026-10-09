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
	await test_sheath_when_no_enemy()
	await _setup()
	await test_coop_scaling()
	await _setup_kind("dog")
	await test_dog_dies_in_cuts()
	await _setup_kind("dog")
	await test_grunt_parry_stagger()
	await _setup_kind("archer")
	await test_arrow_deflect()
	await _setup_kind("shield")
	await test_shield()
	await _setup()
	await test_attack_limit()
	await _setup_kind("liu")
	await test_boss_feint()
	await _setup_kind("liu")
	await test_boss_grab()
	await _setup_kind("liu")
	await test_boss_phases()
	await _setup()
	await test_boss_intro()
	await _setup()
	await test_combo_five()
	await _setup_kind("dog")
	await test_rising_launch()
	await _setup()
	await test_air_and_plunge()
	await _setup()
	await test_dash_attack()
	await _setup()
	await test_cancels_and_buffer()
	await _setup()
	await test_combo_flow()
	await _setup()
	await test_walk_and_run()
	await _setup()
	await test_run_jump()
	await _setup()
	await test_art_slots()
	await _setup()
	await test_issen()
	await _setup()
	await test_kuujin()
	await _setup()
	await test_kongo()
	await _setup()
	await test_houzan()
	await _setup()
	await test_kage()
	await _setup()
	await test_ukifune()
	await _setup()
	await test_mind_fudoshin()
	await _setup()
	await test_mind_zanshin()
	await _setup()
	await test_mind_ryuun()
	await _setup()
	await test_mind_ketsuon()
	await _setup()
	await test_mind_jiri()
	test_enemy_data()
	await _setup_kind("shinobi")
	await test_shinobi()
	await _setup_kind("sohei")
	await test_sohei()
	await _setup_kind("hakai")
	await test_hakai()
	await _setup_kind("jakko")
	await test_jakko()
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
	Game.practice = true   # 战斗测试都在练武场里跑
	Game.run = null
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().physics_frame
	p = main.players[0]
	p.stats["crit"] = 0.0   # 会心是随机的，测试里关掉免得伤害数对不上
	e = main.enemies[0]
	e.attack_cooldown = 9999.0   # 由测试控制出招
	e.rng.seed = 1
	p.global_position = Vector2(400, 300)
	e.global_position = Vector2(460, 300)
	p.facing = 1
	await _frames(5)


## 场上只留一个指定类型的敌人
func _setup_kind(kind: String) -> void:
	await _setup()
	for x in main.enemies:
		x.queue_free()
	main.enemies.clear()
	e = main.spawn_enemy(kind, Vector2(460, 300))
	e.attack_cooldown = 9999.0
	e.rng.seed = 1
	await _frames(5)
	e.global_position = Vector2(460, 300)
	e.velocity = Vector2.ZERO
	await _frames(2)


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


func test_sheath_when_no_enemy() -> void:
	print("平时收刀，敌人靠近拔刀")
	e.visible = false   # 先让敌人不在场
	p._fl_next = 999.0  # 不耍刀
	await _frames(240)
	_check(p.is_sheathed(), "附近没敌人时刀收在鞘里")
	e.visible = true
	await _frames(40)
	_check(not p.is_sheathed(), "敌人靠近时拔刀")


func _hold_enemy() -> void:
	e.state = Enemy.S.WINDUP
	e.move_key = "sweep"
	e.state_time = -10.0   # 一直前摇，不格挡也不出手


func test_stances() -> void:
	print("架势")
	await _tap("p1_stance")
	await _frames(2)
	_check(p.stance()["id"] == "iai", "按架势键切到拔刀式（实际 %s）" % p.stance()["id"])
	await _frames(60)
	_check(p.is_sheathed(), "拔刀式站着时刀在鞘里")
	_hold_enemy()
	await _tap("p1_attack")
	await _frames(20)
	_check(is_equal_approx(e.max_hp - e.hp, 30.0), "居合第一刀伤害 20×1.5 = 30（实际 %.1f）" % (e.max_hp - e.hp))
	_check(not p.is_sheathed(), "砍完刀在手上")
	await _frames(130)
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


func test_dog_dies_in_cuts() -> void:
	print("野狗：没有架势条，几刀砍死")
	_hold_enemy()
	e.move_key = "bite"
	e.global_position = Vector2(440, 300)
	for i in range(3):
		await _tap("p1_attack")
		await _frames(14)
		if e.state == Enemy.S.DYING:
			break
		e.global_position = Vector2(440, 300)
		_hold_enemy()
		e.move_key = "bite"
	await _frames(10)
	_check(e.state == Enemy.S.DYING or e.state == Enemy.S.DEAD, "三刀后倒下（状态 %d，hp %.0f）" % [e.state, e.hp])
	_check(not main.find_executable(p), "杂兵不进处决")


func test_grunt_parry_stagger() -> void:
	print("弹反野狗：直接僵直")
	e.global_position = Vector2(470, 300)
	e._start_move("bite")
	await _wait_windup_end(0, 0.05)
	await _tap("p1_guard")
	await _frames(14)
	_check(p.parry_count == 1, "弹反成功（%d）" % p.parry_count)
	_check(e.state == Enemy.S.STAGGER, "野狗被弹开僵直（状态 %d）" % e.state)


func test_arrow_deflect() -> void:
	print("弓手：格挡箭、弹反把箭打回去")
	e.global_position = Vector2(640, 300)
	await _frames(2)
	Input.action_press("p1_guard")
	await _frames(20)
	e._start_move("shot")
	await _frames(100)
	Input.action_release("p1_guard")
	_check(is_equal_approx(p.hp, p.max_hp), "按住格挡挡下箭（hp %.0f）" % p.hp)
	_check(p.posture > 0.0, "挡箭涨架势（%.1f）" % p.posture)
	await _frames(40)
	e.attack_cooldown = 9999.0
	e._retreat_t = 0.0
	e.global_position = Vector2(640, 300)
	e._start_move("shot")
	var arrow: Arrow = null
	for i in range(200):
		await _frames(1)
		for c in main.fx_root.get_children():
			if c is Arrow:
				arrow = c
		if arrow != null and is_instance_valid(arrow) and arrow.global_position.x - p.global_position.x < 30.0:
			break
	await _tap("p1_guard")
	await _frames(60)
	_check(is_equal_approx(p.hp, p.max_hp), "弹反没掉血（hp %.0f）" % p.hp)
	_check(e.hp < e.max_hp, "箭飞回去射中弓手（弓手 hp %.0f/%.0f）" % [e.hp, e.max_hp])


func test_shield() -> void:
	print("盾兵：正面轻攻击被挡，重击破盾")
	e.attack_cooldown = 9999.0
	await _tap("p1_attack")
	await _frames(20)
	_check(is_equal_approx(e.hp, e.max_hp), "轻攻击被盾挡住（hp %.0f）" % e.hp)
	await _frames(20)
	e.global_position = Vector2(460, 300)
	p.global_position = Vector2(400, 300)
	Input.action_press("p1_attack")
	await _frames(45)
	Input.action_release("p1_attack")
	await _frames(10)
	_check(e.state == Enemy.S.STAGGER, "重击破盾，盾兵僵直（状态 %d）" % e.state)
	_check(e.hp < e.max_hp, "破盾有伤害（hp %.0f）" % e.hp)
	# 从背后砍
	await _setup_kind("shield")
	e.facing = -1
	e.attack_cooldown = 9999.0
	p.global_position = Vector2(500, 300)
	p.facing = -1
	await _frames(2)
	e.facing = -1
	e.state = Enemy.S.WINDUP
	e.move_key = "bash"
	e.state_time = -10.0
	await _tap("p1_attack")
	await _frames(20)
	_check(e.hp < e.max_hp, "绕到背后能砍中（hp %.0f）" % e.hp)


func test_attack_limit() -> void:
	print("同时最多两个敌人出招")
	main.start_encounter(3)
	await _frames(2)
	for x: Enemy in main.enemies:
		x.global_position = Vector2(420 + randf() * 120.0, 300)
		x.attack_cooldown = 0.0
	p.invul_timer = 99.0
	var most := 0
	for i in range(400):
		await _frames(1)
		p.hp = p.max_hp
		p.invul_timer = 99.0
		var n := 0
		for x: Enemy in main.enemies:
			if x.is_attacking():
				n += 1
		most = maxi(most, n)
	_check(most == 2, "最多两个同时出招（实际最多 %d）" % most)


func test_boss_feint() -> void:
	print("柳江远：虚斩变突刺")
	e._start_move("feint")
	_check(not e._danger(), "起手像普通斩击，没有危")
	await _frames(40)
	_check(e.move_key == "thrust", "蓄到一半变成突刺（%s）" % e.move_key)
	_check(e._danger() or e.state != Enemy.S.WINDUP, "变招后亮危")


func test_boss_grab() -> void:
	print("柳江远：擒拿不能挡，要闪开")
	Input.action_press("p1_guard")
	await _frames(20)
	e._start_move("grab")
	await _frames(80)
	Input.action_release("p1_guard")
	_check(is_equal_approx(p.max_hp - p.hp, 56.0), "格挡没用，吃双倍伤害 56（实际 %.0f）" % (p.max_hp - p.hp))
	await _setup_kind("liu")
	e._start_move("grab")
	await _wait_windup_end(0, 0.05)
	Input.action_press("p1_left")
	await _tap("p1_dodge")
	await _frames(3)
	Input.action_release("p1_left")
	await _frames(40)
	_check(is_equal_approx(p.hp, p.max_hp), "往后闪开没被抓（hp %.0f）" % p.hp)


func test_boss_phases() -> void:
	print("柳江远：三个阶段")
	_check(e.lives == 3, "三管血（%d）" % e.lives)
	for ph in range(3):
		e.global_position = Vector2(440, 300)
		e.posture = e.max_posture - 1.0
		e.add_posture(5.0)
		_check(e.state == Enemy.S.BROKEN, "第 %d 阶段架势崩溃" % (ph + 1))
		await _tap("p1_attack")
		await _frames(100)
		e.attack_cooldown = 9999.0
		if ph < 2:
			_check(e.phase == ph + 1, "进入第 %d 阶段（phase %d）" % [ph + 2, e.phase])
			_check(e._speed() < 1.0, "出招变快（×%.2f）" % e._speed())
	_check(e.state == Enemy.S.DYING or e.state == Enemy.S.DEAD, "第三次处决后倒下（状态 %d）" % e.state)


func test_boss_intro() -> void:
	print("头目登场")
	main.start_encounter(4)
	await _frames(2)
	e = main.enemies[0]
	_check(e.state == Enemy.S.INTRO and not e.is_hittable(), "登场时不能被打")
	await _frames(int(Enemy.INTRO_TURN * 60.0) + 5)
	_check(main.hud._title_time > 0.0, "转身亮出名字")
	await _frames(int((Enemy.INTRO_END - Enemy.INTRO_TURN) * 60.0) + 5)
	_check(e.state != Enemy.S.INTRO and e.is_hittable(), "演完开打（状态 %d）" % e.state)


func test_combo_five() -> void:
	print("地面五连：横斩、上撩、竖劈、突刺、旋风斩")
	var seen: Array = []
	for i in range(140):
		_hold_enemy()
		e.global_position = Vector2(445, 300)
		e.posture = 0.0
		if i % 4 == 0:
			await _tap("p1_attack")
		else:
			await _frames(1)
		if p.state == Player.S.ATTACK and not seen.has(p.attack["id"]):
			seen.append(p.attack["id"])
	_check(seen == ["slash1", "slash2", "slash3", "slash4", "slash5"], "按住节奏连按出五段（%s）" % str(seen))


func test_rising_launch() -> void:
	print("升龙斩：人往上冲，杂兵被挑飞")
	_hold_enemy()
	e.move_key = "bite"
	e.global_position = Vector2(425, 300)
	Input.action_press("p1_down")
	await _tap("p1_attack")
	await _frames(2)
	Input.action_release("p1_down")
	var top := 999.0
	var etop := 999.0
	for i in range(30):
		await _frames(1)
		top = minf(top, p.global_position.y)
		etop = minf(etop, e.global_position.y)
	_check(p.attack.get("id") == "rising", "出的是升龙斩")
	_check(top < 270.0, "主角升空（最高 y %.0f）" % top)
	_check(etop < 285.0, "野狗被挑飞（最高 y %.0f）" % etop)


func test_air_and_plunge() -> void:
	print("空中斩两下，落雷斩落地震一圈")
	await _tap("p1_jump")
	await _frames(8)
	await _tap("p1_attack")
	await _frames(2)
	_check(p.attack.get("id") == "air1", "空中按攻击出空中斩")
	await _frames(10)
	Input.action_press("p1_down")
	await _tap("p1_attack")
	await _frames(30)
	Input.action_release("p1_down")
	_check(p.attack.get("id") == "plunge", "空中按下加攻击出落雷斩")
	_hold_enemy()
	await _frames(30)
	_check(e.hp < e.max_hp or e.state == Enemy.S.STAGGER, "落地震到旁边的浪人（hp %.0f）" % e.hp)


func test_dash_attack() -> void:
	print("闪身突刺")
	_hold_enemy()
	p.global_position = Vector2(340, 300)
	Input.action_press("p1_right")
	await _tap("p1_dodge")
	await _frames(5)
	Input.action_release("p1_right")
	await _tap("p1_attack")
	await _frames(2)
	_check(p.attack.get("id") == "dash", "闪身中按攻击出闪身突刺")
	await _frames(25)
	_check(e.hp < e.max_hp, "冲过去刺中（hp %.0f）" % e.hp)


## 等这一刀收完（回到 FREE）
func _wait_free() -> void:
	for i in range(10):
		if p.state != Player.S.FREE:
			break
		await _frames(1)
	for i in range(90):
		if p.state == Player.S.FREE:
			return
		await _frames(1)


func test_combo_flow() -> void:
	print("连段衔接")
	e.global_position = Vector2(700, 300)
	# 一刀收完稍停一下再按，接第二刀，不从第一刀重来
	await _tap("p1_attack")
	await _wait_free()
	await _frames(8)
	await _tap("p1_attack")
	await _frames(4)
	_check(p.state == Player.S.ATTACK and p.attack.get("id", "") == "slash2", "收刀后 0.15 秒内再按，接上撩（%s）" % p.attack.get("id", ""))
	await _wait_free()
	await _frames(40)
	await _tap("p1_attack")
	await _frames(4)
	_check(p.attack.get("id", "") == "slash1", "停太久就从横斩重新开始")
	# 后摇后半段按方向可以直接走开
	for i in range(60):
		if p.state == Player.S.ATTACK and p.attack_phase == 2:
			break
		await _frames(1)
	Input.action_press("p1_right")
	var left_at := -1.0
	for i in range(30):
		await _frames(1)
		if p.state == Player.S.FREE:
			left_at = p.state_time
			break
	await _frames(6)
	_check(p.state == Player.S.FREE and p.velocity.x > 60.0, "后摇里按方向就能走开（%.0f）" % p.velocity.x)
	Input.action_release("p1_right")
	await _frames(40)
	# 连段中按反方向：下一刀转身砍
	p.facing = 1
	await _tap("p1_attack")
	await _frames(3)
	Input.action_press("p1_left")
	await _tap("p1_attack")
	for i in range(40):
		await _frames(1)
		if p.attack.get("id", "") == "slash2":
			break
	Input.action_release("p1_left")
	_check(p.facing == -1 and p.attack.get("id", "") == "slash2", "连段中按反方向，第二刀转身砍")
	await _frames(60)
	# 跑着出刀带着冲劲
	p.global_position = Vector2(150, 300)
	p.facing = 1
	await _tap("p1_right")
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(25)
	await _tap("p1_attack")
	Input.action_release("p1_right")
	var top := 0.0
	for i in range(20):
		await _frames(1)
		if p.state == Player.S.ATTACK and p.attack_phase == 1:
			top = maxf(top, p.velocity.x)
	_check(top > 140.0, "跑着出刀往前冲（%.0f）" % top)


func test_cancels_and_buffer() -> void:
	print("攻击中随时格挡、闪身、跳，输入缓冲")
	e.global_position = Vector2(700, 300)
	# 轻攻击出刀那一下按格挡：马上进格挡
	await _tap("p1_attack")
	await _frames(3)
	var phase_ok := false
	for i in range(30):
		if p.state == Player.S.ATTACK and p.attack_phase == 1:
			phase_ok = true
			break
		await _frames(1)
	await _tap("p1_guard")
	await _frames(1)
	_check(phase_ok and p.state == Player.S.GUARD, "轻攻击出刀时按格挡，立刻格挡（状态 %d）" % p.state)
	Input.action_release("p1_guard")
	await _frames(30)
	# 后摇里按跳：直接跳起来
	await _tap("p1_attack")
	for i in range(40):
		if p.state == Player.S.ATTACK and p.attack_phase == 2:
			break
		await _frames(1)
	await _tap("p1_jump")
	await _frames(3)
	_check(p.velocity.y < 0.0 and not p.is_on_floor(), "攻击后摇按跳，直接起跳")
	await _frames(60)
	# 重劈出刀时按格挡：动作锁住，但这一下留在缓冲里，砍完马上格挡
	p._start_move("heavy")
	for i in range(30):
		if p.attack_phase == 1:
			break
		await _frames(1)
	Input.action_press("p1_guard")
	await _frames(1)
	_check(p.state == Player.S.ATTACK, "重劈出刀那一下不能被打断")
	var guarded := false
	for i in range(30):
		await _frames(1)
		if p.state == Player.S.GUARD:
			guarded = true
			break
	Input.action_release("p1_guard")
	_check(guarded, "提前按的格挡留在缓冲里，砍完马上接上")


func test_walk_and_run() -> void:
	print("走路和奔跑")
	e.global_position = Vector2(780, 300)
	p.global_position = Vector2(200, 300)
	Input.action_press("p1_right")
	await _frames(30)
	var walk := p.velocity.x
	Input.action_release("p1_right")
	await _frames(20)
	_check(absf(walk - Player.WALK_SPEED) < 1.0, "按住方向是走路（%.0f）" % walk)
	await _tap("p1_right")
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(30)
	var run := p.velocity.x
	_check(p.running and absf(run - Player.MOVE_SPEED) < 1.0, "双击方向键奔跑（%.0f）" % run)
	Input.action_release("p1_right")
	await _frames(3)
	_check(not p.running, "松开方向键就不跑了")


## 跳一下，返回起跳到落地走了多远；记下空中最慢的水平速度
var _air_min := 0.0
func _jump_distance() -> float:
	var x0 := p.global_position.x
	await _tap("p1_jump")
	_air_min = INF
	for i in range(90):
		await _frames(1)
		if p.is_on_floor() and i > 5:
			break
		_air_min = minf(_air_min, absf(p.velocity.x))
	return p.global_position.x - x0


func test_run_jump() -> void:
	print("跑着跳")
	e.global_position = Vector2(790, 300)
	p.global_position = Vector2(120, 300)
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(20)
	var walk := await _jump_distance()
	Input.action_release("p1_right")
	await _frames(20)
	p.global_position = Vector2(120, 300)
	await _frames(3)
	await _tap("p1_right")
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(20)
	var run := await _jump_distance()
	_check(run > walk * 1.5, "跑着跳比走着跳远（%.0f 对 %.0f）" % [run, walk])
	_check(_air_min >= Player.MOVE_SPEED - 1.0, "空中不减速（最慢 %.0f）" % _air_min)
	Input.action_release("p1_right")
	await _frames(10)
	_check(not p.running, "落地后松开方向键就不跑了")
	# 空中松开方向，靠惯性往前飘，不会一下停住
	p.global_position = Vector2(120, 300)
	await _frames(3)
	await _tap("p1_right")
	await _frames(3)
	Input.action_press("p1_right")
	await _frames(20)
	await _tap("p1_jump")
	await _frames(2)
	Input.action_release("p1_right")
	await _frames(12)
	_check(p.velocity.x > 150.0, "空中松开方向还带着惯性（%.0f）" % p.velocity.x)
	await _frames(60)


# ---------- 招式和心法（Arts） ----------

## 装上几个招式：arts 是三个格子 [[id, 等级] 或 null]
func _equip(arts: Array, minds: Array = []) -> void:
	var b := {"arts": [], "minds": minds.duplicate()}
	for s: Variant in arts:
		b["arts"].append(null if s == null else {"id": s[0], "lv": s[1]})
	p.build = b
	main._apply_player_stats(p, false)
	p.stats["crit"] = 0.0


## 按住一个方向再按 action（方向键先按一帧，等按完再松）
func _tap_with(action: String, held: String) -> void:
	Input.action_press(held)
	await _frames(1)
	await _tap(action)
	await _frames(1)
	Input.action_release(held)


## 敌人摆在出招前摇里不动（不会格挡、也不会真的砍下来）
func _freeze_windup() -> void:
	e.state = Enemy.S.WINDUP
	e.move_key = "sweep" if e.moves.has("sweep") else String(e.moves.keys()[0])
	e.state_time = -10.0


func test_art_slots() -> void:
	print("招式键 + 方向：三个格子")
	_equip([["whirl", 1], ["kuujin", 1], ["houzan", 1]])
	_freeze_windup()   # 敌人别还手
	p.will = 100.0
	await _tap("p1_art")
	await _frames(2)
	_check(p.state == Player.S.ART and p.art["id"] == "whirl", "单按放第一格（回旋斩）")
	await _frames(60)
	p.will = 100.0
	await _tap_with("p1_art", "p1_left")
	await _frames(2)
	_check(p.art["id"] == "kuujin" and p.facing == -1, "按住左放第二格（空刃斩），顺便转身")
	await _frames(40)
	p.will = 100.0
	await _tap_with("p1_art", "p1_down")
	await _frames(2)
	_check(p.art["id"] == "houzan", "按住下放第三格（崩山劲）")
	await _frames(60)
	_equip([["kuujin", 1], null, null])
	p.will = 100.0
	await _tap_with("p1_art", "p1_down")
	await _frames(2)
	_check(p.art["id"] == "kuujin", "那一格空着就放装着的那个")
	_check(is_equal_approx(p.will, 70.0), "空刃斩耗 30 刃意（剩 %.0f）" % p.will)
	await _frames(40)
	p.will = 20.0
	await _tap("p1_art")
	await _frames(2)
	_check(p.state != Player.S.ART, "刃意不够放不出来")


func test_issen() -> void:
	print("一心：居合斩开一大片")
	_equip([["issen", 1], null, null])
	e.global_position = Vector2(520, 300)   # 离 120，普通刀够不着
	_freeze_windup()
	p.will = 100.0
	await _tap("p1_art")
	await _frames(50)
	_check(is_equal_approx(p.will, 50.0), "耗 50 刃意")
	_check(is_equal_approx(e.max_hp - e.hp, 55.0), "120 外也砍中，55 伤害（实际 %.1f）" % (e.max_hp - e.hp))
	_check(is_equal_approx(e.posture, 50.0), "架势 +50（实际 %.1f）" % e.posture)
	await _frames(40)
	_check(p.state == Player.S.FREE, "收刀回到平常")
	# 三级：收刀前再补一刀
	await _setup()
	_equip([["issen", 3], null, null])
	_freeze_windup()
	p.will = 100.0
	await _tap("p1_art")
	await _frames(70)
	_check(is_equal_approx(e.max_hp - e.hp, 180.0) or e.state == Enemy.S.BROKEN, "三级砍两刀 90×2（实际 %.1f）" % (e.max_hp - e.hp))


func test_kuujin() -> void:
	print("空刃斩：刃气飞出去打断前摇")
	_equip([["kuujin", 1], null, null])
	e.global_position = Vector2(640, 300)
	_freeze_windup()
	p.will = 100.0
	await _tap("p1_art")
	await _frames(50)
	_check(is_equal_approx(e.max_hp - e.hp, 16.0), "240 外打中，16 伤害（实际 %.1f）" % (e.max_hp - e.hp))
	_check(e.state == Enemy.S.STAGGER, "敌人前摇被打断（状态 %d）" % e.state)
	# 三级连挥两道，穿透
	await _setup()
	_equip([["kuujin", 3], null, null])
	e.global_position = Vector2(600, 300)
	_freeze_windup()
	var e2: Enemy = main.spawn_enemy("dog", Vector2(520, 300))
	e2.attack_cooldown = 9999.0
	p.will = 100.0
	await _tap("p1_art")
	await _frames(50)
	_check(e.max_hp - e.hp >= 48.0 - 0.1, "两道都打中后面的敌人（%.1f）" % (e.max_hp - e.hp))
	_check(e2.hp < e2.max_hp, "前面的野狗也挨了（穿透）")


func test_kongo() -> void:
	print("金刚没：格挡都算弹反")
	_equip([["kongo", 3], null, null])
	p.will = 100.0
	await _tap("p1_art")
	await _frames(20)
	_check(p._kongo_t > 2.8, "金刚没生效（剩 %.1f 秒）" % p._kongo_t)
	Input.action_press("p1_guard")
	await _frames(20)   # 早就过了普通弹反窗口
	e._start_move("slash")
	await _frames(150)
	Input.action_release("p1_guard")
	_check(p.parry_count == 3, "按住格挡，三段全变弹反（%d）" % p.parry_count)
	_check(is_equal_approx(e.posture, 45.0), "敌人吃到弹反反震（%.1f）" % e.posture)
	p._kongo_t = 0.0
	Input.action_press("p1_guard")
	await _frames(20)
	e._start_move("quick")
	await _frames(60)
	Input.action_release("p1_guard")
	_check(p.parry_count == 3, "时间过了按住格挡就只是格挡")


func test_houzan() -> void:
	print("崩山劲：空中砸下来震地")
	_equip([["houzan", 1], null, null])
	_freeze_windup()
	p.velocity.y = -450.0
	await _frames(12)
	_check(not p.is_on_floor(), "先跳起来")
	p.will = 100.0
	await _tap("p1_art")
	await _frames(60)
	_check(p.is_on_floor(), "砸到地上")
	_check(is_equal_approx(e.posture, 60.0), "架势 +60（实际 %.1f）" % e.posture)
	_check(is_equal_approx(e.max_hp - e.hp, 18.0), "18 伤害（实际 %.1f）" % (e.max_hp - e.hp))


func test_kage() -> void:
	print("影步：瞬移到背后，下一刀必会心")
	_equip([["kage", 1], null, null])
	e.global_position = Vector2(560, 300)
	e.facing = -1
	_freeze_windup()
	p.will = 100.0
	await _tap("p1_art")
	await _frames(6)
	_check(p.global_position.x > e.global_position.x and p.facing == -1, "站到敌人背后，转过来对着它（x %.0f）" % p.global_position.x)
	_check(p._sure_crit_t > 0.0, "下一刀必会心")
	var hit: Dictionary = p.strike(Moves.get_move("slash1"), e)
	_check(hit["crit"] and is_equal_approx(float(hit["dmg"]), 30.0), "这一刀会心 20×1.5 = %.0f" % float(hit["dmg"]))
	hit = p.strike(Moves.get_move("slash1"), e)
	_check(not hit["crit"], "只管一刀")


func test_ukifune() -> void:
	print("浮舟渡打：七段连斩叠流血")
	_equip([["ukifune", 1], null, null])
	_freeze_windup()
	p.will = 100.0
	await _tap("p1_art")
	await _frames(50)
	_check(e.max_hp - e.hp >= 49.0, "七段每段 7 伤害（%.1f）" % (e.max_hp - e.hp))
	_check(e.bleed_stacks == 5, "流血叠满 5 层（%d）" % e.bleed_stacks)


func test_mind_fudoshin() -> void:
	print("心法·不动心：弹反反震 80%")
	_equip([["whirl", 1], null, null], ["fudoshin"])
	e._start_move("slash")
	for hit in range(3):
		await _wait_windup_end(hit, 0.06)
		await _tap("p1_guard")
		await _frames(12)
	_check(p.parry_count == 3, "三段都弹反")
	_check(is_equal_approx(e.posture, 72.0), "敌人架势 +24×3 = 72（实际 %.1f）" % e.posture)


func test_mind_zanshin() -> void:
	print("心法·残心：残血伤害高，药少回")
	_equip([["whirl", 1], null, null], ["zanshin"])
	var full: float = p.strike(Moves.get_move("slash1"), e)["dmg"]
	p.hp = p.max_hp * 0.4
	var low: float = p.strike(Moves.get_move("slash1"), e)["dmg"]
	_check(is_equal_approx(full, 20.0) and is_equal_approx(low, 26.0), "满血 %.0f，半血以下 %.0f（+30%%）" % [full, low])
	await _tap("p1_heal")
	await _frames(70)
	_check(is_equal_approx(p.hp, p.max_hp * 0.68), "药罐只回 28%%（%.0f）" % p.hp)


func test_mind_ryuun() -> void:
	print("心法·流云：完美闪避放慢时间")
	_equip([["whirl", 1], null, null], ["ryuun"])
	e._start_move("quick")
	await _wait_windup_end(0, 0.03)
	Input.action_press("p1_right")
	await _tap("p1_dodge")
	Input.action_release("p1_right")
	await _frames(1)
	var slowed: bool = main._slow_until > 0
	await _frames(20)
	_check(p.perfect_dodges == 1 or slowed, "完美闪避（%d）" % p.perfect_dodges)
	_check(is_equal_approx(p.hp, p.max_hp), "没被砍中")
	_check(is_equal_approx(p.will, 8.0), "刃意 +8（%.0f）" % p.will)
	# 没有流云：不算
	await _setup()
	e._start_move("quick")
	await _wait_windup_end(0, 0.03)
	Input.action_press("p1_right")
	await _tap("p1_dodge")
	Input.action_release("p1_right")
	await _frames(20)
	_check(p.perfect_dodges == 0, "没装流云不放慢")


func test_mind_ketsuon() -> void:
	print("心法·血音：流血叠满引爆")
	_equip([["whirl", 1], null, null], ["ketsuon"])
	for i in range(4):
		e.add_bleed(p)
	_check(e.bleed_stacks == 4 and is_equal_approx(e.posture, 0.0), "四层不引爆")
	e.add_bleed(p)
	_check(e.bleed_stacks == 0, "第五层引爆，流血清空")
	_check(e.posture >= 40.0 and is_equal_approx(e.max_hp - e.hp, 15.0), "架势 +%.0f、伤害 %.0f" % [e.posture, e.max_hp - e.hp])


func test_mind_jiri() -> void:
	print("心法·持离：处决后刃意充满")
	_equip([["whirl", 1], null, null], ["jiri"])
	p.will = 0.0
	e._break()
	await _frames(2)
	await _tap("p1_attack")
	await _frames(5)
	_check(e.lives < (e.data["phases"] as Array).size(), "处决成功")
	_check(is_equal_approx(p.will, Player.MAX_WILL), "刃意充满（%.0f）" % p.will)


# ---------- 第二层的敌人 ----------

## 敌人表自查：出招表、变招、接招都指向有的招式，用到的姿势都有
func test_enemy_data() -> void:
	print("敌人数据表自查")
	Enemy._build_poses()
	var bad := []
	for key: String in EnemyData.TYPES:
		var t: Dictionary = EnemyData.TYPES[key]
		var moves: Dictionary = t["moves"]
		var refs := []
		var ai: Dictionary = t["ai"]
		for pk: Array in ai.get("picks", []):
			refs.append(pk[0])
		for f: Array in ai.get("far", []):
			refs.append(f[0])
		for ph: Dictionary in t["phases"]:
			for pk: Array in ph.get("picks", []):
				refs.append(pk[0])
			for f: Array in ph.get("far", []):
				refs.append(f[0])
		for mk: String in moves:
			var m: Dictionary = moves[mk]
			if m.has("feint"):
				refs.append(m["feint"]["into"])
			if m.has("then"):
				refs.append(m["then"])
			for ps: Array in m.get("poses", []):
				for pose: String in ps:
					if not Enemy.POSES.has(pose):
						bad.append("%s.%s 的姿势 %s" % [key, mk, pose])
		for r: String in refs:
			if not moves.has(r):
				bad.append("%s 没有招式 %s" % [key, r])
		for pose: String in t.get("idle", []):
			if not Enemy.POSES.has(pose):
				bad.append("%s 的待机姿势 %s" % [key, pose])
	_check(bad.is_empty(), "招式和姿势都对得上 %s" % str(bad))


func test_shinobi() -> void:
	print("忍者：手里剑能挡、能弹回去")
	e.global_position = Vector2(640, 300)
	await _frames(2)
	Input.action_press("p1_guard")
	await _frames(20)
	e._start_move("shuriken")
	var star := false
	for i in range(60):
		await _frames(1)
		for c in main.fx_root.get_children():
			if c is Arrow and c.star and not star:
				star = true
				_freeze_windup()   # 扔完就让忍者定住，别冲上来砍
	await _frames(40)
	Input.action_release("p1_guard")
	_check(star, "扔出来的是手里剑")
	_check(is_equal_approx(p.hp, p.max_hp) and p.posture > 0.0, "按住格挡挡下（架势 %.0f）" % p.posture)
	await _frames(30)
	e.attack_cooldown = 9999.0
	e._retreat_t = 0.0
	e.global_position = Vector2(640, 300)
	e._start_move("shuriken")
	var arrow: Arrow = null
	for i in range(200):
		await _frames(1)
		for c in main.fx_root.get_children():
			if c is Arrow:
				if arrow == null:
					_freeze_windup()
				arrow = c
		# 手里剑比箭快，提前一点按（弹反窗口里它能飞 57 像素）
		if arrow != null and is_instance_valid(arrow) and arrow.global_position.x - p.global_position.x < 45.0:
			break
	await _tap("p1_guard")
	await _frames(8)
	_check(arrow != null and is_instance_valid(arrow) and arrow.deflected_by == p and arrow.velocity.x > 0.0,
		"弹反把手里剑打回去")
	_check(is_equal_approx(p.hp, p.max_hp), "弹反没掉血")
	# 疾斩冲过来砍
	await _setup_kind("shinobi")
	e.global_position = Vector2(520, 300)
	e._start_move("dash_cut")
	await _frames(50)
	_check(p.hp < p.max_hp, "疾斩远远冲过来砍中（hp %.0f）" % p.hp)


func test_sohei() -> void:
	print("僧兵：扫堂棍要跳")
	e._start_move("staff_sweep")
	await _wait_windup_end(0, 0.12)
	await _tap("p1_jump")
	await _frames(40)
	_check(is_equal_approx(p.hp, p.max_hp), "跳过扫堂棍（hp %.0f）" % p.hp)
	await _setup_kind("sohei")
	e._start_move("staff_combo")
	await _frames(90)
	_check(is_equal_approx(p.max_hp - p.hp, 32.0), "棍二连不挡吃两下 16×2（%.0f）" % (p.max_hp - p.hp))


func test_hakai() -> void:
	print("破戒僧：迟砸")
	_check(e.max_posture == 210.0 and e.lives == 2, "精英两管血，架势 210")
	e._start_move("slam")
	await _frames(40)
	_check(e.state == Enemy.S.WINDUP, "举过头顶停很久")
	await _wait_windup_end(0, 0.06)
	await _tap("p1_guard")
	await _frames(30)
	_check(p.parry_count == 1, "看准了弹反（%d）" % p.parry_count)


func test_jakko() -> void:
	print("禅刃 · 寂光：变招和静")
	e._start_move("feint_sweep")
	_check(not e._danger(), "起手像禅三连，没有危")
	await _frames(30)
	_check(e.move_key == "sweep", "半路变成扫腿（%s）" % e.move_key)
	await _setup_kind("jakko")
	e._start_move("feint_grab")
	await _frames(30)
	_check(e.move_key == "grab", "也可能变成擒拿（%s）" % e.move_key)
	await _setup_kind("jakko")
	e._start_move("still")
	await _frames(40)
	_check(e.move_key == "still" and e.state == Enemy.S.WINDUP, "静：站着不动")
	await _frames(25)
	_check(e.move_key == "quick", "然后突然快斩（%s）" % e.move_key)
	_check((e.data["phases"] as Array).size() == 3 and e.data["title_sub"] == "第二层 · 竹林古寺", "三个阶段，登场写第二层")
