class_name Player
extends Fighter
## 主角：移动、二段跳、三段轻攻击、蓄力重攻击、格挡、弹反、闪身、处决。

enum S { FREE, CHARGE, ATTACK, GUARD, DODGE, HITSTUN, BROKEN, EXECUTE, DEAD }

const MOVE_SPEED := 140.0
const JUMP_VELOCITY := -340.0
const HEAVY_CHARGE_TIME := 0.6      # 长按 0.6 秒出重攻击
const DODGE_SPEED := 300.0
const DODGE_TIME := 0.22
const DODGE_INVUL := 0.2            # 闪身无敌 0.2 秒
const DODGE_COOLDOWN := 0.4
const HITSTUN_TIME := 0.25
const BROKEN_TIME := 1.2            # 架势满 → 破防僵直 1.2 秒
const EXECUTE_TIME := 0.55
const RESPAWN_TIME := 3.0
const GUARD_SPAM_GAP := 0.35        # 连按格挡间隔太短会缩小弹反窗口
const GUARD_SPAM_FACTOR := 0.4
const EXECUTE_RANGE := 56.0

# 轻攻击三段连击：伤害与架势伤害 1:1
const LIGHT := [
	{"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0, "reach": 22.0, "size": Vector2(34, 22), "height": 20.0, "heavy": false},
	{"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0, "reach": 22.0, "size": Vector2(34, 22), "height": 20.0, "heavy": false},
	{"windup": 0.10, "active": 0.10, "recover": 0.32, "dmg": 30.0, "posture": 30.0, "reach": 26.0, "size": Vector2(42, 26), "height": 20.0, "heavy": false},
]
# 重攻击：破敌人普通格挡，架势伤害 ×2
const HEAVY := {"windup": 0.12, "active": 0.10, "recover": 0.40, "dmg": 30.0, "posture": 60.0, "reach": 26.0, "size": Vector2(46, 30), "height": 20.0, "heavy": true}

var index := 1
var prefix := "p1_"
var color := Color(0.35, 0.75, 0.95)
var spawn_pos := Vector2.ZERO

var state := S.FREE
var air_jumps := 1
var combo_step := 0
var combo_queued := false
var attack: Dictionary = {}
var attack_phase := 0               # 0 前摇 1 判定 2 后摇
var hit_targets: Array = []
var charge_time := 0.0
var parry_timer := 0.0
var last_guard_press := -10.0
var dodge_dir := 1
var dodge_cooldown := 0.0
var invul_timer := 0.0
var respawn_timer := 0.0
var clock := 0.0
var parry_count := 0                # 统计，用于界面显示

# 美术
var look := Puppet.Look.new()
var scarf_color := Color("c0392b")
var _pose: Dictionary = {}          # 当前画出来的姿势（平滑过渡）
var _scarf: Array[Vector2] = []     # 围巾各节的世界坐标
var _was_on_floor := true
var _ghost_timer := 0.0

static var POSES := {}


static func _build_poses() -> void:
	if not POSES.is_empty():
		return
	POSES["idle"] = Puppet.pose({})
	POSES["guard"] = Puppet.pose({"crouch": 2.5, "lean": 0.15, "foot_f": Vector2(5, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.1, 2.4), "arm_b": Vector2(0.7, 1.9), "sword": 2.75})
	POSES["parry"] = Puppet.pose({"crouch": 3.0, "lean": 0.3, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.5, 2.6), "arm_b": Vector2(0.9, 2.0), "sword": 2.45})
	# 轻攻击三段：每段一个举刀姿势和一个出刀姿势
	POSES["raise1"] = Puppet.pose({"lean": -0.1, "arm_f": Vector2(2.7, 3.0), "arm_b": Vector2(2.4, 2.8), "sword": 3.7,
		"foot_f": Vector2(5, 0), "foot_b": Vector2(-5, 0)})
	POSES["cut1"] = Puppet.pose({"lean": 0.4, "crouch": 3.0, "foot_f": Vector2(8, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.3, 1.5), "arm_b": Vector2(1.0, 1.4), "sword": 1.75})
	POSES["raise2"] = Puppet.pose({"lean": 0.25, "crouch": 3.0, "arm_f": Vector2(0.2, 0.5), "arm_b": Vector2(0.2, 0.4),
		"sword": 0.4, "foot_f": Vector2(6, 0), "foot_b": Vector2(-5, 0)})
	POSES["cut2"] = Puppet.pose({"lean": -0.05, "arm_f": Vector2(2.4, 2.8), "arm_b": Vector2(2.0, 2.4), "sword": 2.9,
		"foot_f": Vector2(7, 0), "foot_b": Vector2(-5, 0)})
	POSES["raise3"] = Puppet.pose({"lean": -0.15, "crouch": 3.0, "arm_f": Vector2(-0.6, 1.2), "arm_b": Vector2(-0.4, 0.6),
		"sword": 1.57, "foot_f": Vector2(4, 0), "foot_b": Vector2(-7, 0)})
	POSES["cut3"] = Puppet.pose({"lean": 0.45, "crouch": 4.0, "arm_f": Vector2(1.5, 1.57), "arm_b": Vector2(-0.6, -0.3),
		"sword": 1.57, "foot_f": Vector2(10, 0), "foot_b": Vector2(-7, 0)})
	POSES["charge"] = Puppet.pose({"crouch": 5.0, "lean": -0.15, "arm_f": Vector2(3.0, 3.4), "arm_b": Vector2(2.8, 3.2),
		"sword": 4.0, "foot_f": Vector2(6, 0), "foot_b": Vector2(-7, 0)})
	POSES["smash"] = Puppet.pose({"crouch": 5.0, "lean": 0.55, "arm_f": Vector2(1.1, 0.9), "arm_b": Vector2(0.9, 0.8),
		"sword": 1.0, "foot_f": Vector2(9, 0), "foot_b": Vector2(-7, 0)})
	POSES["dodge"] = Puppet.pose({"crouch": 6.0, "lean": 0.7, "foot_f": Vector2(6, -2), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(-0.6, -0.3), "arm_b": Vector2(-0.9, -0.6), "sword": -0.8})
	POSES["backstep"] = Puppet.pose({"crouch": 5.0, "lean": -0.3, "foot_f": Vector2(5, -1), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.9, 1.8), "sword": 2.2})
	POSES["hit"] = Puppet.pose({"lean": -0.45, "head": -0.3, "crouch": 2.0, "arm_f": Vector2(0.3, 0.0), "sword": 0.6,
		"arm_b": Vector2(-0.8, -0.4), "foot_f": Vector2(6, 0), "foot_b": Vector2(-4, 0)})
	POSES["broken"] = Puppet.pose({"crouch": 6.0, "lean": 0.7, "head": 0.4, "arm_f": Vector2(0.1, 0.0), "sword": 0.25,
		"arm_b": Vector2(0.1, 0.0), "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0)})
	POSES["jump"] = Puppet.pose({"crouch": 0.0, "foot_f": Vector2(4, -5), "foot_b": Vector2(-3, -3),
		"arm_f": Vector2(1.8, 2.2), "sword": 2.3, "arm_b": Vector2(-1.2, -0.8), "lean": 0.05})
	POSES["fall"] = Puppet.pose({"crouch": 0.0, "foot_f": Vector2(3, -1), "foot_b": Vector2(-4, -2),
		"arm_f": Vector2(1.2, 1.9), "sword": 2.0, "arm_b": Vector2(-1.8, -1.4), "lean": 0.0})


func _ready() -> void:
	_build_poses()
	setup_body()
	if index == 2:
		look.cloth = Color("2f6b3f")
		look.cloth_dark = Color("1f4a2b")
		look.hair = Color("3a2418")
		scarf_color = Color("e0b03a")
	_pose = POSES["idle"].duplicate()
	for i in range(6):
		_scarf.append(global_position + Vector2(0, -25))
	max_hp = 200.0
	hp = max_hp
	max_posture = 100.0
	posture_recover_rate = 30.0
	spawn_pos = global_position


func is_alive() -> bool:
	return state != S.DEAD


func _pressed(action: String) -> bool:
	return Input.is_action_just_pressed(prefix + action)


func _held(action: String) -> bool:
	return Input.is_action_pressed(prefix + action)


func _enter(s: S) -> void:
	state = s
	state_time = 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	state_time += delta
	parry_timer = maxf(0.0, parry_timer - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invul_timer = maxf(0.0, invul_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	if state != S.DEAD and state != S.BROKEN:
		tick_posture(delta)
	if is_on_floor():
		air_jumps = 1

	match state:
		S.FREE: _state_free(delta)
		S.CHARGE: _state_charge(delta)
		S.ATTACK: _state_attack(delta)
		S.GUARD: _state_guard(delta)
		S.DODGE: _state_dodge(delta)
		S.HITSTUN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_time >= HITSTUN_TIME:
				_enter(S.FREE)
		S.BROKEN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_time >= BROKEN_TIME:
				posture = 0.0
				_enter(S.FREE)
		S.EXECUTE:
			velocity.x = 0.0
			if state_time >= EXECUTE_TIME:
				_enter(S.FREE)
		S.DEAD:
			velocity.x = 0.0
			respawn_timer -= delta
			if respawn_timer <= 0.0:
				respawn()

	if state != S.DODGE:
		apply_gravity(delta)
	_check_stomp()
	move_and_slide()
	_update_art(delta)
	queue_redraw()


# ---------- 各状态 ----------

func _state_free(_delta: float) -> void:
	var dir := Input.get_axis(prefix + "left", prefix + "right")
	velocity.x = dir * MOVE_SPEED
	if absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1
	if _pressed("jump"):
		_try_jump()
	if _pressed("guard"):
		_start_guard()
	elif _pressed("dodge") and dodge_cooldown <= 0.0:
		_start_dodge(dir)
	elif _pressed("attack"):
		_attack_pressed()


func _state_charge(delta: float) -> void:
	charge_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _pressed("guard"):
		_start_guard()
	elif _pressed("dodge") and dodge_cooldown <= 0.0:
		_start_dodge(Input.get_axis(prefix + "left", prefix + "right"))
	elif charge_time >= HEAVY_CHARGE_TIME:
		_start_attack(HEAVY, 0)
	elif not _held("attack"):
		_start_attack(LIGHT[0], 0)


func _state_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _pressed("attack"):
		combo_queued = true
	# 格挡和闪身可以取消攻击（前摇和后摇时）
	if attack_phase != 1:
		if _pressed("guard"):
			_start_guard()
			return
		if _pressed("dodge") and dodge_cooldown <= 0.0:
			_start_dodge(Input.get_axis(prefix + "left", prefix + "right"))
			return

	var windup: float = attack["windup"]
	var active: float = attack["active"]
	var recover: float = attack["recover"]
	if attack_phase == 0 and state_time >= windup:
		attack_phase = 1
		state_time = 0.0
		hit_targets.clear()
		velocity.x = facing * 70.0   # 出刀时向前踏一小步
		_spawn_slash()
	if attack_phase == 1:
		_check_attack_hits()
		if state_time >= active:
			attack_phase = 2
			state_time = 0.0
	if attack_phase == 2:
		var is_heavy: bool = attack["heavy"]
		if combo_queued and state_time >= 0.04:
			var target: Enemy = main.find_executable(self)
			if target != null:
				_start_execute(target)
			elif not is_heavy and combo_step < LIGHT.size() - 1:
				_start_attack(LIGHT[combo_step + 1], combo_step + 1)
			else:
				combo_queued = false
		elif state_time >= recover:
			combo_step = 0
			_enter(S.FREE)


func _state_guard(delta: float) -> void:
	# 格挡时可以慢慢移动、转身
	var dir := Input.get_axis(prefix + "left", prefix + "right")
	velocity.x = move_toward(velocity.x, dir * 40.0, 900.0 * delta)
	if absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1
	if _pressed("guard"):
		_arm_parry()
	if _pressed("attack"):
		_attack_pressed()
		return
	if _pressed("dodge") and dodge_cooldown <= 0.0:
		_start_dodge(dir)
		return
	if _pressed("jump"):
		_enter(S.FREE)
		_try_jump()
		return
	# 松开格挡后，弹反窗口结束才真正退出格挡
	if not _held("guard") and parry_timer <= 0.0:
		_enter(S.FREE)


func _state_dodge(_delta: float) -> void:
	velocity.x = dodge_dir * DODGE_SPEED
	velocity.y = 0.0   # 空中闪身保持高度
	if state_time >= DODGE_TIME:
		velocity.x = dodge_dir * 60.0
		_enter(S.FREE)


# ---------- 动作 ----------

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		main.spawn_dust(global_position, 0.0, 6)
	elif air_jumps > 0:
		main.spawn_dust(global_position, 0.0, 4)
		air_jumps -= 1
		velocity.y = JUMP_VELOCITY * 0.9


func _attack_pressed() -> void:
	var target: Enemy = main.find_executable(self)
	if target != null:
		_start_execute(target)
		return
	charge_time = 0.0
	_enter(S.CHARGE)


func _start_attack(data: Dictionary, step: int) -> void:
	attack = data
	combo_step = step
	combo_queued = false
	attack_phase = 0
	hit_targets.clear()
	_enter(S.ATTACK)


func _start_guard() -> void:
	_enter(S.GUARD)
	_arm_parry()


func _arm_parry() -> void:
	var window := Game.parry_window()
	if clock - last_guard_press < GUARD_SPAM_GAP:
		window *= GUARD_SPAM_FACTOR   # 乱按惩罚
	last_guard_press = clock
	parry_timer = window


func _start_dodge(dir: float) -> void:
	if absf(dir) > 0.1:
		dodge_dir = 1 if dir > 0.0 else -1
	else:
		dodge_dir = -facing   # 不按方向时向后撤步
	dodge_cooldown = DODGE_COOLDOWN + DODGE_TIME
	invul_timer = DODGE_INVUL
	_enter(S.DODGE)
	if is_on_floor():
		main.spawn_dust(global_position, -dodge_dir, 6)


func _start_execute(target: Enemy) -> void:
	facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(S.EXECUTE)
	target.execute_by(self)


func _check_attack_hits() -> void:
	var size: Vector2 = attack["size"]
	var r := front_rect(attack["reach"], size, attack["height"])
	for e: Enemy in main.get_enemies():
		if e in hit_targets or not e.is_hittable():
			continue
		if r.intersects(e.body_rect()):
			hit_targets.append(e)
			var result := e.receive_player_hit(attack, self)
			if result == "blocked":
				velocity.x = -facing * 90.0
			elif result == "guardbreak":
				main.hitstop(0.06)


## 下落时踩到敌人头上：可以再跳一次；敌人正在下段横扫时奖励架势
func _check_stomp() -> void:
	if velocity.y <= 0.0 or state == S.DEAD:
		return
	for e: Enemy in main.get_enemies():
		if not e.is_hittable():
			continue
		var head := e.body_rect()
		var feet := global_position
		if feet.x > head.position.x - 6.0 and feet.x < head.end.x + 6.0 \
				and feet.y > head.position.y - 4.0 and feet.y < head.position.y + 10.0:
			velocity.y = JUMP_VELOCITY * 0.85
			air_jumps = 1
			e.on_stomped(self)
			return


# ---------- 受击 ----------

## 敌人攻击命中判定框时调用。返回 parry / block / hit / miss / mikiri
func receive_enemy_hit(info: Dictionary, attacker: Fighter) -> String:
	if state == S.DEAD or state == S.EXECUTE:
		return "miss"
	var to_attacker := 1 if attacker.global_position.x >= global_position.x else -1
	var kind: String = info["kind"]
	if invul_timer > 0.0:
		if kind == "thrust" and state == S.DODGE and dodge_dir == -attacker.facing:
			return "mikiri"   # 看破：迎着突刺方向闪身
		return "miss"
	if kind == "sweep" and not is_on_floor():
		return "miss"         # 跳过下段横扫
	var p: float = info["posture"]
	var unblockable: bool = info["unblockable"]
	if not unblockable and state == S.GUARD and facing == to_attacker:
		if parry_timer > 0.0:
			parry_timer = 0.0
			parry_count += 1
			flash(Color(1.0, 0.95, 0.5), 0.15)
			add_posture(p * 0.25)
			return "parry"
		add_posture(p)
		if state != S.BROKEN:
			velocity.x = -to_attacker * 110.0
		return "block"
	var dmg: float = info["dmg"]
	hp -= dmg
	flash(Color(1.0, 0.3, 0.3), 0.15)
	main.spawn_blood(global_position + Vector2(0, -18), -to_attacker, 10)
	velocity.x = -to_attacker * 140.0
	if hp <= 0.0:
		_die()
		return "hit"
	add_posture(p * 0.5)
	if state != S.BROKEN:
		_enter(S.HITSTUN)
	return "hit"


func _on_posture_full() -> void:
	if state == S.DEAD:
		return
	_enter(S.BROKEN)
	parry_timer = 0.0
	main.spawn_text(global_position + Vector2(0, -50), "破防", Color(1.0, 0.5, 0.2))


func _die() -> void:
	hp = 0.0
	_enter(S.DEAD)
	respawn_timer = RESPAWN_TIME
	main.spawn_text(global_position + Vector2(0, -50), "倒下", Color(0.9, 0.2, 0.2))


func respawn() -> void:
	hp = max_hp
	posture = 0.0
	global_position = spawn_pos
	velocity = Vector2.ZERO
	_enter(S.FREE)


# ---------- 美术 ----------

func _spawn_slash() -> void:
	var heavy: bool = attack["heavy"]
	var center := global_position + Vector2(facing * 6.0, -16.0)
	if heavy:
		main.spawn_slash(center, facing, 28.0, -2.4, 0.9, Color(1.0, 0.8, 0.5), 10.0)
	elif combo_step == 0:
		main.spawn_slash(center, facing, 24.0, -2.2, 0.6)
	elif combo_step == 1:
		main.spawn_slash(center, facing, 24.0, 0.9, -1.7)
	else:
		main.spawn_streak(global_position + Vector2(facing * 4.0, -15.0), facing, 44.0)


func _target_pose() -> Dictionary:
	var t := state_time
	match state:
		S.FREE:
			if not is_on_floor():
				return POSES["jump"] if velocity.y < 0.0 else POSES["fall"]
			if absf(velocity.x) > 10.0:
				var ph := clock * 13.0
				return Puppet.pose({
					"crouch": 2.0 + absf(sin(ph)) * 1.2, "lean": 0.3,
					"foot_f": Vector2(5.0 * sin(ph), -maxf(0.0, 3.0 * cos(ph))),
					"foot_b": Vector2(-5.0 * sin(ph), -maxf(0.0, -3.0 * cos(ph))),
					"arm_f": Vector2(-0.3 + 0.2 * sin(ph), 0.2), "sword": -0.7,
					"arm_b": Vector2(0.4 * sin(ph + PI), 0.9),
				})
			var idle: Dictionary = POSES["idle"].duplicate()
			idle["crouch"] = 1.0 + sin(clock * 3.0) * 0.6
			return idle
		S.CHARGE:
			var cp: Dictionary = Puppet.lerp_pose(POSES["idle"], POSES["charge"], charge_time / 0.25)
			if charge_time >= HEAVY_CHARGE_TIME - 0.1:
				cp["dx"] = sin(clock * 90.0) * 0.8   # 蓄满时抖动
			return cp
		S.ATTACK:
			var heavy: bool = attack["heavy"]
			var keys: Array = ["charge", "smash"] if heavy else [["raise1", "cut1"], ["raise2", "cut2"], ["raise3", "cut3"]][combo_step]
			var windup: float = attack["windup"]
			var active: float = attack["active"]
			var recover: float = attack["recover"]
			if attack_phase == 0:
				return POSES[keys[0]]
			if attack_phase == 1:
				return Puppet.lerp_pose(POSES[keys[0]], POSES[keys[1]], t / (active * 0.6))
			return Puppet.lerp_pose(POSES[keys[1]], POSES["idle"], pow(t / recover, 2.0))
		S.GUARD:
			return POSES["parry"] if parry_timer > 0.0 else POSES["guard"]
		S.DODGE:
			return POSES["dodge"] if dodge_dir == facing else POSES["backstep"]
		S.HITSTUN:
			return POSES["hit"]
		S.BROKEN, S.DEAD:
			var bp: Dictionary = POSES["broken"].duplicate()
			bp["lean"] = 0.7 + sin(clock * 4.0) * 0.08
			return bp
		S.EXECUTE:
			return POSES["raise3"] if t < 0.12 else POSES["cut3"]
	return POSES["idle"]


func _update_art(delta: float) -> void:
	# 姿势平滑过渡；出刀那一下要快
	var rate := 60.0 if state == S.ATTACK or state == S.EXECUTE else 22.0
	_pose = Puppet.lerp_pose(_pose, _target_pose(), 1.0 - exp(-rate * delta))

	# 落地扬尘
	if is_on_floor() and not _was_on_floor:
		main.spawn_dust(global_position, 0.0, 5)
	_was_on_floor = is_on_floor()

	# 闪身残影
	_ghost_timer -= delta
	if state == S.DODGE and _ghost_timer <= 0.0:
		_ghost_timer = 0.045
		main.spawn_ghost(global_position, _pose.duplicate(), look, facing, color)

	# 围巾：每一节跟随前一节，受风和重力影响
	var j := Puppet.solve(_pose)
	var neck: Vector2 = j["neck"]
	var anchor := global_position + Vector2(neck.x * facing, neck.y) + Vector2(-facing * 1.0, 1.0)
	_scarf[0] = anchor
	for i in range(1, _scarf.size()):
		var wave := sin(clock * 9.0 - i * 0.9) * 1.2
		var target := _scarf[i - 1] + Vector2(-facing * 3.2 - velocity.x * 0.012, 0.9 + wave)
		_scarf[i] = _scarf[i].lerp(target, 1.0 - exp(-30.0 * delta))
		if _scarf[i].distance_to(_scarf[i - 1]) > 4.0:
			_scarf[i] = _scarf[i - 1] + (_scarf[i] - _scarf[i - 1]).normalized() * 4.0


func _draw() -> void:
	# 影子
	draw_rect(Rect2(-8, -1, 16, 2), Color(0, 0, 0, 0.35))

	var tint := Color(0, 0, 0, 0)
	if flash_timer > 0.0:
		tint = Color(flash_color, 0.85)
	elif state == S.BROKEN:
		tint = Color(0.2, 0.2, 0.25, 0.35)
	var alpha := 0.55 if state == S.DODGE else 1.0

	# 围巾画在身体后面
	if _scarf.size() > 1 and state != S.DEAD:
		var pts := PackedVector2Array()
		for pt in _scarf:
			pts.append(pt - global_position)
		draw_polyline(pts, Color(0.05, 0.05, 0.08, alpha), 4.0)
		draw_polyline(pts, Color(scarf_color, alpha), 2.0)

	if state == S.DEAD:
		Puppet.draw(self, _pose, look, facing, Vector2(-facing * 4.0, -3.0), Color(0.2, 0.2, 0.25, 0.4), 1.0, -facing * PI / 2.0)
	else:
		Puppet.draw(self, _pose, look, facing, Vector2.ZERO, tint, alpha)

	# 弹反窗口内刀身发光
	if state == S.GUARD and parry_timer > 0.0:
		var tip := Puppet.sword_tip(_pose, look, facing)
		draw_circle(tip, 2.5, Color(1.0, 0.95, 0.5, 0.9))
	if state == S.CHARGE:
		var ratio := clampf(charge_time / HEAVY_CHARGE_TIME, 0.0, 1.0)
		draw_rect(Rect2(-12, 4, 24, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-12, 4, 24 * ratio, 3), Color(1.0, 0.6, 0.2) if ratio < 1.0 else Color(1, 1, 1))
	if state == S.BROKEN:
		_draw_label("破防", Vector2(0, -44), Color(1.0, 0.5, 0.2), 11)

	# 头顶：编号和架势条
	_draw_label("%dP" % index, Vector2(0, -38), color.lightened(0.3), 9)
	if posture > 0.5 and state != S.DEAD:
		draw_posture_bar(Vector2(0, -35), 30.0, posture / max_posture)

	if Game.show_hitboxes:
		var w := body_size.x
		var h := body_size.y
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ATTACK and attack_phase == 1:
			var size: Vector2 = attack["size"]
			draw_rect(to_local_rect(front_rect(attack["reach"], size, attack["height"])), Color(1, 0, 0, 0.6), false)


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var w := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(Game.font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.8))
	draw_string(Game.font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
