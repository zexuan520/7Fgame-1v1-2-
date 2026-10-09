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


func _ready() -> void:
	setup_body()
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
	elif air_jumps > 0:
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


# ---------- 绘制（原型阶段只用色块） ----------

func _draw() -> void:
	var w := body_size.x
	var h := body_size.y
	var body_col := color
	match state:
		S.DEAD: body_col = Color(0.3, 0.3, 0.3, 0.5)
		S.BROKEN: body_col = color.darkened(0.5)
		S.DODGE: body_col = Color(color, 0.45)
	if flash_timer > 0.0:
		body_col = flash_color
	var crouch := 8.0 if state == S.DEAD else 0.0
	draw_rect(Rect2(-w / 2.0, -h + crouch, w, h - crouch), body_col)
	# 头巾和眼睛，表示朝向
	draw_rect(Rect2(-w / 2.0, -h + crouch, w, 5), body_col.darkened(0.35))
	draw_rect(Rect2(facing * 4.0 - 1.5, -h + 8 + crouch, 3, 3), Color(0.05, 0.05, 0.08))

	_draw_blade()

	if state == S.GUARD:
		var gcol := Color(1.0, 0.95, 0.4) if parry_timer > 0.0 else Color(0.6, 0.85, 1.0, 0.8)
		draw_rect(Rect2(facing * (w / 2.0 + 3.0) - 1.5, -h - 2, 3, h), gcol)
	if state == S.CHARGE:
		var ratio := clampf(charge_time / HEAVY_CHARGE_TIME, 0.0, 1.0)
		draw_rect(Rect2(-12, 4, 24, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-12, 4, 24 * ratio, 3), Color(1.0, 0.6, 0.2))
	if state == S.BROKEN:
		_draw_label("破防", Vector2(0, -h - 20), Color(1.0, 0.5, 0.2), 11)

	# 头顶：编号和架势条
	_draw_label("%dP" % index, Vector2(0, -h - 12), color.lightened(0.3), 9)
	if posture > 0.5 and state != S.DEAD:
		draw_posture_bar(Vector2(0, -h - 6), 30.0, posture / max_posture)

	if Game.show_hitboxes:
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ATTACK and attack_phase == 1:
			var size: Vector2 = attack["size"]
			draw_rect(to_local_rect(front_rect(attack["reach"], size, attack["height"])), Color(1, 0, 0, 0.6), false)


func _draw_blade() -> void:
	var hand := Vector2(facing * 6.0, -18.0)
	var blade_col := Color(0.92, 0.92, 0.98)
	if state == S.ATTACK:
		var heavy: bool = attack["heavy"]
		var length := 30.0 if heavy else 24.0
		if attack_phase == 0:
			draw_line(hand, hand + Vector2(-facing * 8.0, -length), blade_col, 2.0)
		elif attack_phase == 1:
			var size: Vector2 = attack["size"]
			var r := to_local_rect(front_rect(attack["reach"], size, attack["height"]))
			draw_rect(r, Color(1, 1, 1, 0.35))
			draw_line(hand, hand + Vector2(facing * length, -2.0), blade_col, 3.0 if heavy else 2.0)
		else:
			draw_line(hand, hand + Vector2(facing * length * 0.8, 10.0), blade_col, 2.0)
	elif state == S.GUARD:
		draw_line(hand + Vector2(facing * 2.0, 6.0), hand + Vector2(facing * 6.0, -18.0), blade_col, 2.0)
	elif state == S.CHARGE:
		draw_line(hand, hand + Vector2(-facing * 14.0, -18.0), Color(1.0, 0.75, 0.4), 2.0)
	elif state != S.DEAD:
		draw_line(hand, hand + Vector2(facing * 14.0, 12.0), blade_col.darkened(0.2), 2.0)


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var w := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(Game.font, pos - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
