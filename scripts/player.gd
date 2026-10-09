class_name Player
extends Fighter
## 主角：移动、二段跳、三段轻攻击、蓄力重攻击、格挡、弹反、闪身、处决。

enum S { FREE, CHARGE, ATTACK, GUARD, DODGE, HITSTUN, BROKEN, EXECUTE, DEAD }

const MOVE_SPEED := 190.0
const JUMP_VELOCITY := -520.0
const HEAVY_CHARGE_TIME := 0.6      # 长按 0.6 秒出重攻击
const DODGE_SPEED := 420.0
const DODGE_TIME := 0.22
const DODGE_INVUL := 0.2            # 闪身无敌 0.2 秒
const DODGE_COOLDOWN := 0.4
const HITSTUN_TIME := 0.25
const BROKEN_TIME := 1.2            # 架势满 → 破防僵直 1.2 秒
const EXECUTE_TIME := 0.55
const RESPAWN_TIME := 3.0
const GUARD_SPAM_GAP := 0.35        # 连按格挡间隔太短会缩小弹反窗口
const GUARD_SPAM_FACTOR := 0.4
const EXECUTE_RANGE := 80.0

# 轻攻击三段连击：伤害与架势伤害 1:1
const LIGHT := [
	{"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0, "reach": 33.0, "size": Vector2(51, 33), "height": 30.0, "heavy": false},
	{"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0, "reach": 33.0, "size": Vector2(51, 33), "height": 30.0, "heavy": false},
	{"windup": 0.10, "active": 0.10, "recover": 0.32, "dmg": 30.0, "posture": 30.0, "reach": 39.0, "size": Vector2(63, 39), "height": 30.0, "heavy": false},
]
# 重攻击：破敌人普通格挡，架势伤害 ×2
const HEAVY := {"windup": 0.12, "active": 0.10, "recover": 0.40, "dmg": 30.0, "posture": 60.0, "reach": 39.0, "size": Vector2(69, 45), "height": 30.0, "heavy": true}

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
var _squash := Vector2.ONE
var _idle_time := 0.0               # 站着不动多久了，用来触发闲置小动作
var _land_timer := 0.0
var _spin_time := -1.0              # 二段跳翻身
var _prev_facing := 1
var _ready_blend := 0.0             # 0 = 放松，1 = 戒备

static var POSES := {}


static func _build_poses() -> void:
	if not POSES.is_empty():
		return
	POSES["idle"] = Puppet.pose({})
	# 放松持刀：刀尖斜向下
	POSES["relaxed"] = Puppet.pose({"crouch": 1.2, "lean": 0.04, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.25, 0.6), "arm_b": Vector2(-0.12, 0.2), "sword": 0.55})
	# 戒备：敌人靠近时，双手持刀刀尖指向对方
	POSES["ready"] = Puppet.pose({"crouch": 2.8, "lean": 0.16, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.95, 1.55), "arm_b": Vector2(0.75, 1.45), "sword": 1.45})
	# 闲置小动作：甩刀（血振）
	POSES["chiburi_up"] = Puppet.pose({"crouch": 1.5, "lean": -0.05, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(1.9, 2.5), "arm_b": Vector2(-0.2, 0.3), "sword": 2.7})
	POSES["chiburi_down"] = Puppet.pose({"crouch": 2.5, "lean": 0.22, "foot_f": Vector2(6, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.9, 0.5), "arm_b": Vector2(-0.4, 0.1), "sword": 0.25})
	# 伸展、回头
	POSES["stretch"] = Puppet.pose({"crouch": 0.4, "lean": -0.16, "head": -0.25, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.3, 0.6), "arm_b": Vector2(2.7, 3.1), "sword": 0.5})
	POSES["look_back"] = Puppet.pose({"crouch": 1.4, "lean": -0.06, "head": -0.5, "foot_f": Vector2(5, 0), "foot_b": Vector2(-5, 0),
		"arm_f": Vector2(0.3, 0.7), "arm_b": Vector2(-0.3, 0.1), "sword": 0.6})
	POSES["land"] = Puppet.pose({"crouch": 6.5, "lean": 0.35, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.6, 1.0), "arm_b": Vector2(-0.8, -0.2), "sword": 0.9})
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
		look.cloth = Color("2f6b45")
		look.cloth_dark = Color("1c4630")
		look.cloth_light = Color("4f9a6a")
		look.hair = Color("3a2418")
		look.band = Color("e0b03a")
	scarf_color = look.band
	_pose = POSES["idle"].duplicate()
	for i in range(7):
		_scarf.append(global_position + Vector2(0, -45))
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
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= HITSTUN_TIME:
				_enter(S.FREE)
		S.BROKEN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
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
	velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
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
		velocity.x = facing * 105.0   # 出刀时向前踏一小步
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
	velocity.x = move_toward(velocity.x, dir * 60.0, 1300.0 * delta)
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
		velocity.x = dodge_dir * 90.0
		_enter(S.FREE)


# ---------- 动作 ----------

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		_squash = Vector2(0.85, 1.15)
		main.spawn_dust(global_position, 0.0, 6)
	elif air_jumps > 0:
		main.spawn_dust(global_position, 0.0, 4)
		_spin_time = 0.0
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
				velocity.x = -facing * 135.0
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
		if feet.x > head.position.x - 9.0 and feet.x < head.end.x + 9.0 \
				and feet.y > head.position.y - 6.0 and feet.y < head.position.y + 15.0:
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
			velocity.x = -to_attacker * 165.0
		return "block"
	var dmg: float = info["dmg"]
	hp -= dmg
	flash(Color(1.0, 0.3, 0.3), 0.15)
	main.spawn_blood(global_position + Vector2(0, -28), -to_attacker, 10)
	velocity.x = -to_attacker * 210.0
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
	main.spawn_text(global_position + Vector2(0, -70), "破防", Color(1.0, 0.5, 0.2))


func _die() -> void:
	hp = 0.0
	_enter(S.DEAD)
	respawn_timer = RESPAWN_TIME
	main.spawn_text(global_position + Vector2(0, -70), "倒下", Color(0.9, 0.2, 0.2))


func respawn() -> void:
	hp = max_hp
	posture = 0.0
	global_position = spawn_pos
	velocity = Vector2.ZERO
	_enter(S.FREE)


# ---------- 美术 ----------

func _spawn_slash() -> void:
	var heavy: bool = attack["heavy"]
	var center := global_position + Vector2(facing * 9.0, -26.0)
	if heavy:
		main.spawn_slash(center, facing, 44.0, -2.4, 0.9, Color(1.0, 0.75, 0.4), 14.0)
		main.punch(0.04)
	elif combo_step == 0:
		main.spawn_slash(center, facing, 36.0, -2.2, 0.6, Color(0.75, 0.9, 1.0))
	elif combo_step == 1:
		main.spawn_slash(center, facing, 36.0, 0.9, -1.7, Color(0.75, 0.9, 1.0))
	else:
		main.spawn_streak(global_position + Vector2(facing * 6.0, -24.0), facing, 66.0, Color(0.75, 0.9, 1.0))


func _target_pose() -> Dictionary:
	var t := state_time
	match state:
		S.FREE:
			if not is_on_floor():
				if _spin_time >= 0.0:
					return Puppet.pose({"crouch": 5.0, "lean": 0.5, "foot_f": Vector2(4, -6), "foot_b": Vector2(-2, -5),
						"arm_f": Vector2(1.2, 2.2), "arm_b": Vector2(1.0, 2.0), "sword": 1.0})
				return POSES["jump"] if velocity.y < 0.0 else POSES["fall"]
			if _land_timer > 0.0:
				return POSES["land"]
			if absf(velocity.x) > 10.0:
				return _run_pose()
			return _idle_pose()
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


func _run_pose() -> Dictionary:
	var ph := clock * 14.0
	var s := sin(ph)
	var c := cos(ph)
	return Puppet.pose({
		"crouch": 2.2 + absf(s) * 1.6, "lean": 0.34 + absf(s) * 0.04, "head": -0.1,
		"foot_f": Vector2(6.5 * s, -maxf(0.0, 4.5 * c)),
		"foot_b": Vector2(-6.5 * s, -maxf(0.0, -4.5 * c)),
		"arm_f": Vector2(-0.5 + 0.25 * s, 0.1), "sword": -1.0 + 0.15 * s,   # 刀拖在身后
		"arm_b": Vector2(0.9 * -s, 1.2 + 0.4 * -s),
	})


func _idle_pose() -> Dictionary:
	# 敌人靠近时进入戒备，远离时放松
	var base := Puppet.lerp_pose(POSES["relaxed"], POSES["ready"], _ready_blend)
	var p := Puppet.breathe(base, clock, 1.0 - _ready_blend * 0.4)
	# 站久了做闲置小动作：甩刀、伸展、回头，轮流来
	if _ready_blend < 0.1 and _idle_time > 3.0:
		var cycle := fmod(_idle_time - 3.0, 5.0)
		var which := int((_idle_time - 3.0) / 5.0) % 3
		var r: Dictionary = POSES["relaxed"]
		var track: Array
		match which:
			0: track = [[0.0, r], [0.35, POSES["chiburi_up"]], [0.5, POSES["chiburi_down"]], [1.0, POSES["chiburi_down"]], [1.5, r]]
			1: track = [[0.0, r], [0.6, POSES["stretch"]], [1.3, POSES["stretch"]], [1.9, r]]
			_: track = [[0.0, r], [0.4, POSES["look_back"]], [1.6, POSES["look_back"]], [2.0, r]]
		var last: float = track[track.size() - 1][0]
		if cycle < last:
			return Puppet.breathe(Puppet.sample(track, cycle), clock, 0.6)
	return p


func _update_art(delta: float) -> void:
	# 待机时间、落地缓冲、翻身、戒备程度
	if state == S.FREE and is_on_floor() and absf(velocity.x) < 10.0:
		_idle_time += delta
	else:
		_idle_time = 0.0
	_land_timer = maxf(0.0, _land_timer - delta)
	if _spin_time >= 0.0:
		_spin_time += delta
		if _spin_time > 0.32 or is_on_floor():
			_spin_time = -1.0
	var near: Enemy = main.nearest_enemy(global_position, 170.0)
	var want := 1.0 if near != null and near.is_hittable() else 0.0
	_ready_blend = move_toward(_ready_blend, want, delta * 3.0)
	if want > 0.0:
		_idle_time = 0.0
	if facing != _prev_facing:
		_squash = Vector2(0.82, 1.08)   # 转身
		_prev_facing = facing

	# 姿势平滑过渡；出刀那一下要快
	var rate := 60.0 if state == S.ATTACK or state == S.EXECUTE else 22.0
	_pose = Puppet.lerp_pose(_pose, _target_pose(), 1.0 - exp(-rate * delta))
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))

	# 落地扬尘和压扁
	if is_on_floor() and not _was_on_floor:
		main.spawn_dust(global_position, 0.0, 6)
		_squash = Vector2(1.18, 0.84)
		if state == S.FREE:
			_land_timer = 0.1
	_was_on_floor = is_on_floor()

	# 闪身残影
	_ghost_timer -= delta
	if state == S.DODGE and _ghost_timer <= 0.0:
		_ghost_timer = 0.04
		main.spawn_ghost(global_position, _pose.duplicate(), look, facing, color)

	# 头带飘带：每一节跟随前一节，受风和速度影响
	var j := Puppet.solve(_pose)
	var head: Vector2 = j["head"]
	var anchor := global_position + Vector2((head.x - 5.0) * facing, head.y - 2.0) * look.scale
	_scarf[0] = anchor
	for i in range(1, _scarf.size()):
		var wave := sin(clock * 10.0 - i * 0.9) * 1.4
		var target := _scarf[i - 1] + Vector2(-facing * 3.6 - velocity.x * 0.012, 0.7 + wave - velocity.y * 0.006)
		_scarf[i] = _scarf[i].lerp(target, 1.0 - exp(-32.0 * delta))
		if _scarf[i].distance_to(_scarf[i - 1]) > 4.5:
			_scarf[i] = _scarf[i - 1] + (_scarf[i] - _scarf[i - 1]).normalized() * 4.5


func _draw() -> void:
	var top := Puppet.head_top(look)
	# 影子
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tint := Color(0, 0, 0, 0)
	if flash_timer > 0.0:
		tint = Color(flash_color, 1.0)
	elif state == S.BROKEN:
		tint = Color(0.2, 0.2, 0.25, 0.35)
	var alpha := 0.6 if state == S.DODGE else 1.0

	# 头带飘带画在身体后面
	if _scarf.size() > 1 and state != S.DEAD:
		var pts := PackedVector2Array()
		for pt in _scarf:
			pts.append(pt - global_position)
		draw_polyline(pts, Color(0.03, 0.03, 0.06, alpha), 4.0)
		draw_polyline(pts, Color(scarf_color, alpha), 2.0)
		draw_polyline(pts.slice(0, 3), Color(scarf_color.lightened(0.3), alpha), 1.0)

	var rim := Color(0.5, 0.62, 0.9, 0.5)
	if state == S.DEAD:
		Puppet.draw(self, _pose, look, facing, Vector2(-facing * 6.0, -4.0), Color(0.15, 0.15, 0.2, 0.45), 1.0, -facing * PI / 2.0)
	else:
		var spin := 0.0
		var spin_off := Vector2.ZERO
		if _spin_time >= 0.0:
			spin = facing * TAU * clampf(_spin_time / 0.32, 0.0, 1.0)
			# 绕身体中心翻转
			var pivot := Vector2(0, -26)
			spin_off = pivot - pivot.rotated(spin)
		Puppet.draw_lit(self, _pose, look, facing, rim, spin_off, tint, alpha, spin, _squash, velocity.x)

	# 弹反窗口内刀身发光
	if state == S.GUARD and parry_timer > 0.0:
		var tip := Puppet.sword_tip(_pose, look, facing)
		draw_circle(tip, 3.5, Color(1.0, 0.95, 0.6, 0.5))
		draw_circle(tip, 2.0, Color(1.0, 1.0, 0.85))
	if state == S.CHARGE:
		var ratio := clampf(charge_time / HEAVY_CHARGE_TIME, 0.0, 1.0)
		var full := ratio >= 1.0
		draw_rect(Rect2(-14, 5, 28, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, 5, 28 * ratio, 3), Color(1, 1, 1) if full else Color(1.0, 0.6, 0.2))
	if state == S.BROKEN:
		_draw_label("破防", Vector2(0, top - 14), Color(1.0, 0.5, 0.2), 12)

	# 头顶：编号和架势条
	_draw_label("%dP" % index, Vector2(0, top - 7), color.lightened(0.3), 12)
	if posture > 0.5 and state != S.DEAD:
		draw_posture_bar(Vector2(0, top - 4), 34.0, posture / max_posture)

	if Game.show_hitboxes:
		var w := body_size.x
		var h := body_size.y
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ATTACK and attack_phase == 1:
			var size: Vector2 = attack["size"]
			draw_rect(to_local_rect(front_rect(attack["reach"], size, attack["height"])), Color(1, 0, 0, 0.6), false)


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var w := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := (pos - Vector2(w / 2.0, 0)).round()
	draw_string_outline(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.9))
	draw_string(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
