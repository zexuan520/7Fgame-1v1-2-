class_name Enemy
extends Fighter
## 敌人：数值、招式、AI 全部来自 EnemyData.TYPES，这里只有通用的状态机、受击和画法。
## 可弹反的招式出刀前刀尖闪光；危招（下段横扫要跳、突刺要看破、擒拿要闪开）身上亮红光。
## 杂兵没有架势条，血空直接倒下；精英和头目要打崩架势再处决，每处决一次扣一管血、进入下一阶段。

enum S { IDLE, WINDUP, ACTIVE, RECOVER, GUARD, FLINCH, STAGGER, BROKEN, REVIVE, DYING, DEAD, INTRO }

const COOP_HP_MULT := 1.6           # 双人时生命 ×1.6
const COOP_POSTURE_MULT := 1.4      # 双人时架势 ×1.4
const BROKEN_TIME := 2.0            # 架势满 → 处决窗口 2 秒
const INTRO_TURN := 4.2             # 头目登场：说完话转身拔刀
const INTRO_END := 5.2
const AGGRO_RANGE := 300.0          # 房间里站着的敌人，玩家走到这么近才动手
const BLEED_MAX := 5                # 流血最多叠 5 层
const BLEED_DPS := 3.0              # 每层每秒伤害
const BLEED_TIME := 3.0
const BLEED_BURST_DMG := 15.0       # 血音引爆：伤害
const BLEED_BURST_POSTURE := 40.0   # 血音引爆：架势伤害（至少架势上限的 30%）

var kind := "ronin"
var data: Dictionary = {}
var moves: Dictionary = {}
var state := S.IDLE
var lives := 1
var phase := 0
var phase2: bool:
	get: return phase >= 1
var coop := false
var spawn_pos := Vector2.ZERO
var move_key := ""
var hit_index := 0
var hit_targets: Array = []
var attack_cooldown := 1.0
var block_streak := 0
var stagger_time := 0.0
var target: Player = null
var rng := RandomNumberGenerator.new()
var _feinted := false
var _retreat_t := 0.0
var _intro_said := 0
var intro_lines: Array = []  # 这次登场说的话
var hp_mult := 1.0          # 层级系数（设计文档第 13 节）：第二层生命 ×1.4、伤害 ×1.2
var dmg_mult := 1.0
var _keep_jitter := 0.0     # 每个敌人想站的距离稍微错开，不会挤在一个点上
var aggro := true           # false 时站着不动，等玩家走近（房间里的第一波）
var perch := false          # 守在高处不走动（站在屋顶、望楼上的弓手）
var _jump_cd := 0.0
var bleed_stacks := 0
var bleed_time := 0.0
var _bleed_acc := 0.0
var _side := 1              # 包抄的一边（ai.flank 为 true 时有一半会绕到玩家另一边）

# 美术
var look := Puppet.Look.new()
var _pose: Dictionary = {}
var _clock := 0.0
var _fell := false
var _spring := Puppet.Spring.new()
var _stalk := 0.0           # 0 远处放松，1 近处戒备
var _fl_kind := ""          # 正在做的挑衅/耍刀动作（见 Flourish）
var _fl_t := 0.0
var _fl_wait := 1.5
var _fl_last := ""

static var POSES := {}


## 按类型建敌人：特殊画法的类型用子类
static func create(type_key: String) -> Enemy:
	var e: Enemy = Dog.new() if type_key == "dog" else Enemy.new()
	e.kind = type_key
	return e


static func _build_poses() -> void:
	if not POSES.is_empty():
		return
	Player._build_poses()
	for k in Player.POSES:
		POSES[k] = Player.POSES[k]
	POSES["sweep_prep"] = Puppet.pose({"crouch": 8.0, "lean": 0.4, "arm_f": Vector2(-1.0, -0.8), "arm_b": Vector2(0.6, 1.0),
		"sword": -1.4, "foot_f": Vector2(7, 0), "foot_b": Vector2(-8, 0)})
	POSES["sweep_cut"] = Puppet.pose({"crouch": 8.0, "lean": 0.5, "arm_f": Vector2(1.5, 1.6), "arm_b": Vector2(-0.6, -0.4),
		"sword": 1.75, "foot_f": Vector2(9, 0), "foot_b": Vector2(-8, 0)})
	# 浪人：远处刀扛在肩上，近处压低身体刀尖低垂
	POSES["shoulder"] = Puppet.pose({"crouch": 0.8, "lean": -0.04, "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.75, 3.0), "arm_b": Vector2(-0.15, 0.15), "sword": 4.1, "head": 0.05})
	POSES["stalk"] = Puppet.pose({"crouch": 3.2, "lean": 0.26, "foot_f": Vector2(7, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.7, 1.15), "arm_b": Vector2(0.5, 1.1), "sword": 0.95, "head": -0.12})
	var tp: Dictionary = Player.POSES["raise3"].duplicate()
	tp["lean"] = -0.3
	tp["crouch"] = 4.0
	POSES["thrust_prep"] = tp
	POSES["hop"] = Puppet.pose({"crouch": 1.0, "lean": -0.22, "foot_f": Vector2(5, -6), "foot_b": Vector2(-6, -3),
		"arm_f": Vector2(0.9, 1.3), "arm_b": Vector2(1.2, 1.6), "sword": 1.1, "head": -0.1})

	# 弓手（前手握弓，后手拉弦）
	POSES["bow_idle"] = Puppet.pose({"crouch": 0.6, "lean": 0.02, "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.25, 0.55), "arm_b": Vector2(-0.15, 0.2), "head": 0.05})
	POSES["bow_ready"] = Puppet.pose({"crouch": 1.8, "lean": 0.08, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.9, 1.15), "arm_b": Vector2(0.6, 1.4), "head": -0.05})
	POSES["bow_draw"] = Puppet.pose({"crouch": 2.2, "lean": -0.06, "foot_f": Vector2(8, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(1.55, 1.57), "arm_b": Vector2(1.9, -1.4), "head": 0.0})
	POSES["bow_loose"] = Puppet.pose({"crouch": 2.2, "lean": -0.1, "foot_f": Vector2(8, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(1.6, 1.6), "arm_b": Vector2(1.3, -0.4), "head": -0.05})
	POSES["kick_prep"] = Puppet.pose({"crouch": 1.0, "lean": -0.15, "foot_f": Vector2(5, -9), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.9, 1.1), "arm_b": Vector2(0.4, 0.9)})
	POSES["kick"] = Puppet.pose({"crouch": 1.0, "lean": -0.35, "foot_f": Vector2(17, -13), "foot_b": Vector2(-5, 0),
		"arm_f": Vector2(0.6, 0.9), "arm_b": Vector2(-0.4, 0.2)})

	# 盾兵（后手持盾挡在身前，前手握长枪）
	POSES["shield_stance"] = Puppet.pose({"crouch": 2.6, "lean": 0.16, "foot_f": Vector2(7, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.5, 1.25), "arm_b": Vector2(1.25, 1.6), "sword": 1.45, "head": -0.05})
	POSES["bash_prep"] = Puppet.pose({"crouch": 3.0, "lean": -0.12, "foot_f": Vector2(5, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(0.3, 1.0), "arm_b": Vector2(0.8, 1.2), "sword": 1.3})
	POSES["bash"] = Puppet.pose({"crouch": 2.0, "lean": 0.4, "foot_f": Vector2(12, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(0.5, 1.2), "arm_b": Vector2(1.6, 1.6), "sword": 1.4})
	POSES["spear_prep"] = Puppet.pose({"crouch": 3.2, "lean": -0.08, "foot_f": Vector2(6, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(0.1, 0.6), "arm_b": Vector2(1.2, 1.5), "sword": 1.6})
	POSES["spear"] = Puppet.pose({"crouch": 2.4, "lean": 0.32, "foot_f": Vector2(12, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(1.5, 1.6), "arm_b": Vector2(1.1, 1.4), "sword": 1.57})

	# 柳江远：平时刀尖斜指地面，像在河边站着
	POSES["liu_calm"] = Puppet.pose({"crouch": 0.6, "lean": 0.0, "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.2, 0.45), "arm_b": Vector2(-0.1, 0.1), "sword": 0.6, "head": 0.08})
	POSES["grab_prep"] = Puppet.pose({"crouch": 4.5, "lean": 0.3, "foot_f": Vector2(7, 0), "foot_b": Vector2(-9, 0),
		"arm_f": Vector2(0.3, 0.1), "arm_b": Vector2(2.3, 1.9), "sword": -0.5, "head": -0.1})
	POSES["grab_reach"] = Puppet.pose({"crouch": 5.0, "lean": 0.6, "foot_f": Vector2(13, 0), "foot_b": Vector2(-10, 0),
		"arm_f": Vector2(0.2, 0.0), "arm_b": Vector2(1.65, 1.6), "sword": -0.7, "head": -0.2})


func _ready() -> void:
	_build_poses()
	data = EnemyData.get_type(kind)
	moves = data["moves"]
	lives = (data["phases"] as Array).size()
	var lk: Dictionary = data["look"]
	for k: String in lk:
		if k in look:
			look.set(k, lk[k])
	_pose = POSES[_idle_keys()[0]].duplicate()
	_spring.reset(_pose)
	body_size = data["body"]
	setup_body()
	posture_recover_rate = 25.0
	spawn_pos = global_position
	_apply_stats(true)
	rng.randomize()
	_keep_jitter = rng.randf_range(0.0, 36.0)
	_side = -1 if (data["ai"] as Dictionary).get("flank", false) and rng.randf() < 0.5 else 1


func rank() -> String:
	return data["rank"]


func is_grunt() -> bool:
	return data["rank"] == "grunt"


func display_name() -> String:
	return data["name"]


func _apply_stats(full: bool) -> void:
	var hp_ratio := 1.0 if full else hp / max_hp
	var posture_ratio := 0.0 if full else posture / max_posture
	max_hp = float(data["hp"]) * hp_mult * (COOP_HP_MULT if coop else 1.0)
	max_posture = float(data["posture"]) * (COOP_POSTURE_MULT if coop else 1.0)
	hp = max_hp * hp_ratio
	posture = max_posture * posture_ratio


func set_coop(value: bool) -> void:
	if coop == value:
		return
	coop = value
	_apply_stats(false)


func reset() -> void:
	lives = (data["phases"] as Array).size()
	phase = 0
	global_position = spawn_pos
	velocity = Vector2.ZERO
	attack_cooldown = 1.0
	block_streak = 0
	visible = true
	_apply_stats(true)
	_enter(S.IDLE)


## 头目登场：背对玩家站着，说两句话再转身
## 头目登场；meets 是第几次见面（按次数换台词，见 Story.intro_for），练武场是 0
func start_intro(meets: int = 0) -> void:
	facing = 1
	_intro_said = 0
	intro_lines = Story.intro_for(data, meets)
	_enter(S.INTRO)


func is_hittable() -> bool:
	return state != S.DYING and state != S.DEAD and state != S.REVIVE and state != S.INTRO


func is_attacking() -> bool:
	return state == S.WINDUP or state == S.ACTIVE or state == S.RECOVER


func _enter(s: S) -> void:
	state = s
	state_time = 0.0
	if s == S.DYING:
		_fell = false
		if main != null and main.has_method("on_enemy_killed"):
			main.on_enemy_killed(self)


func _phase_data() -> Dictionary:
	var phases: Array = data["phases"]
	return phases[mini(phase, phases.size() - 1)]


## AI 参数：当前阶段有就用阶段的，没有就用 ai 里的
func _ai(key: String, default: Variant = null) -> Variant:
	var pd := _phase_data()
	if pd.has(key):
		return pd[key]
	return (data["ai"] as Dictionary).get(key, default)


func _speed() -> float:
	return float(_phase_data().get("speed", 1.0))


func _move() -> Dictionary:
	return moves[move_key]


func _hit_times() -> Array:
	var hits: Array = _move()["hits"]
	return hits[hit_index]


func _physics_process(delta: float) -> void:
	state_time += delta
	_tick_bleed(delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	attack_cooldown -= delta
	if state != S.BROKEN and state != S.DYING and state != S.DEAD:
		tick_posture(delta)

	match state:
		S.IDLE: _state_idle(delta)
		S.WINDUP: _state_windup(delta)
		S.ACTIVE: _state_active(delta)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			if state_time >= _hit_times()[2] * _speed():
				_next_hit()
		S.GUARD:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= 0.5:
				_enter(S.IDLE)
		S.FLINCH:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= 0.18:
				_enter(S.IDLE)
		S.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= stagger_time:
				attack_cooldown = 0.3
				_enter(S.IDLE)
		S.BROKEN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= BROKEN_TIME:
				# 没抓住处决机会：架势回落到一半，敌人恢复行动
				posture = max_posture * 0.5
				hp = maxf(hp, max_hp * 0.1)
				attack_cooldown = 0.2
				_enter(S.IDLE)
		S.REVIVE:
			velocity.x = 0.0
			if state_time >= 1.2:
				_next_phase()
		S.DYING:
			velocity.x = 0.0
			if state_time >= 1.9:
				visible = false
				_enter(S.DEAD)
		S.INTRO: _state_intro(delta)

	if state != S.DEAD and state != S.DYING:
		_separate(delta)
	if state == S.IDLE and is_on_floor() and velocity.x != 0.0 and main.has_method("is_gap") \
			and main.is_gap(global_position.x + signf(velocity.x) * 18.0):
		velocity.x = 0.0   # 走到坑边停下（被打飞、被弹开还是会掉下去）
	apply_gravity(delta)
	move_and_slide()
	_clock += delta
	var near := target != null and absf(target.global_position.x - global_position.x) < 200.0
	_stalk = move_toward(_stalk, 1.0 if near else 0.0, delta * 2.5)
	_update_flourish(delta)
	var sp := _spring_params()
	_pose = _spring.step(_target_pose(), sp.x, sp.y, delta)
	queue_redraw()


func _next_phase() -> void:
	hp = max_hp
	posture = 0.0
	phase += 1
	attack_cooldown = 0.4
	var aura: Color = _phase_data().get("aura", Color(1, 1, 1))
	var line: Variant = _phase_data().get("line")
	if line is Array:
		main.hud.say(line[0], line[1])
		main.flash_screen(aura, 0.3)
		main.spawn_ring(global_position + Vector2(0, -30), aura, 60.0)
		main.shake(4.0)
	elif line is String:
		main.spawn_text(global_position + Vector2(0, -84), line, Color(1.0, 0.4, 0.3))
	_enter(S.IDLE)


## 敌人之间轻轻推开，不要叠成一团
func _separate(delta: float) -> void:
	for o: Enemy in main.get_enemies():
		if o == self or not o.visible or o.state == S.DEAD or o.state == S.DYING:
			continue
		var dx := global_position.x - o.global_position.x
		if absf(dx) < (body_size.x + o.body_size.x) * 0.5 + 4.0:
			var dir := signf(dx) if dx != 0.0 else (1.0 if get_instance_id() > o.get_instance_id() else -1.0)
			global_position.x += dir * 40.0 * delta


## 弹簧松紧（频率 Hz，阻尼）：蓄力慢、出刀快而甩、收招带惯性
func _spring_params() -> Vector2:
	if _fl_kind != "":
		return Vector2(9.0, 0.95)
	match state:
		S.WINDUP: return Vector2(7.0, 0.85)
		S.ACTIVE: return Vector2(12.0, 0.5)
		S.RECOVER: return Vector2(5.0, 0.75)
		S.GUARD: return Vector2(10.0, 0.7)
		S.FLINCH, S.STAGGER: return Vector2(9.0, 0.45)
		S.IDLE: return Vector2(7.0, 0.9) if absf(velocity.x) > 5.0 else Vector2(4.0, 0.8)
		S.INTRO: return Vector2(3.5, 0.9)
	return Vector2(5.0, 0.8)


# ---------- AI ----------

func _state_idle(delta: float) -> void:
	if data.get("passive", false):
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	target = main.visible_player(global_position)   # 躲在烟幕里的看不见
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	if not aggro:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if absf(target.global_position.x - global_position.x) < AGGRO_RANGE:
			wake()
		else:
			facing = 1 if target.global_position.x >= global_position.x else -1
			return
	var dx := target.global_position.x - global_position.x
	var dist := absf(dx)
	var speed: float = data["speed"]
	_jump_cd -= delta
	var dy := target.global_position.y - global_position.y
	var level := absf(dy) < 36.0 or not target.is_on_floor()
	if not level and not perch and is_on_floor():
		_chase_level(dx, dy, speed, delta)
		return
	if perch:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _side < 0 and not perch and attack_cooldown > 0.0 and dist < 160.0 and _retreat_t <= 0.0:
		# 包抄：从玩家身边窜过去，绕到另一边
		var goal := target.global_position.x + signf(-dx if dx != 0.0 else 1.0) * -90.0
		if goal < 30.0 or goal > float(main.arena_w) - 30.0:
			_side = 1   # 那边是墙，绕不过去
		elif absf(goal - global_position.x) > 12.0:
			velocity.x = move_toward(velocity.x, signf(goal - global_position.x) * speed * 1.2, 1500.0 * delta)
			facing = 1 if velocity.x >= 0.0 else -1
			return
		else:
			_side = 1
	facing = 1 if dx >= 0.0 else -1
	var accel := 900.0 if speed < 150.0 else 1500.0

	if _retreat_t > 0.0 and not perch:
		# 打完就跑：往后跳开拉距离（野狗、弓手）
		_retreat_t -= delta
		velocity.x = move_toward(velocity.x, -facing * speed, accel * 1.5 * delta)
		return

	var my_turn: bool = main.can_attack(self)
	if attack_cooldown <= 0.0 and is_on_floor() and my_turn and (level or perch):
		if dist < float(_ai("attack_range")):
			_start_move(_pick(_ai("picks")))
			return
		for f: Array in _ai("far", []):
			if dist >= float(f[2]) and dist <= float(f[3]) and rng.randf() < float(f[1]) * delta:
				_start_move(f[0])
				return
	var keep: Array = _ai("keep", [45.0, 81.0])
	var near_d: float = float(keep[0]) + _keep_jitter * 0.5
	var far_d: float = float(keep[1]) + _keep_jitter
	if not my_turn:
		# 已经有两个人在砍了：在外圈转，等机会
		near_d = maxf(near_d, 110.0)
		far_d = maxf(far_d, 150.0)
	var want := 0.0
	if dist > far_d:
		want = facing * speed
	elif dist < near_d:
		want = -facing * speed * 0.7
	if perch:
		want = 0.0
	velocity.x = move_toward(velocity.x, want, accel * delta)


## 玩家不在同一层：在下面就走到平台边掉下去（正上方时直接穿下去），在上面就走到下方跳上去
func _chase_level(dx: float, dy: float, speed: float, delta: float) -> void:
	facing = 1 if dx >= 0.0 else -1
	if dy > 0.0:
		if absf(dx) < 40.0:
			drop_through()
		velocity.x = move_toward(velocity.x, signf(dx) * speed, 1500.0 * delta)
		return
	if absf(dx) < 110.0 and _jump_cd <= 0.0:
		# 起跳高度刚好够到玩家脚下那一层
		_jump_cd = 1.4 + rng.randf() * 0.6
		velocity.y = -minf(sqrt(2.0 * GRAVITY * (-dy + 20.0)), 720.0)
		velocity.x = signf(dx) * clampf(absf(dx) * 2.4, 60.0, speed * 1.5)
		main.spawn_dust(global_position, 0.0, 6)
		return
	var want := signf(dx) * speed if absf(dx) > 30.0 else 0.0
	velocity.x = move_toward(velocity.x, want, 1500.0 * delta)


func _pick(options: Array) -> String:
	var total := 0
	for o: Array in options:
		total += int(o[1])
	var roll := rng.randi_range(1, total)
	for o: Array in options:
		roll -= int(o[1])
		if roll <= 0:
			return o[0]
	return options[0][0]


func _start_move(key: String) -> void:
	move_key = key
	hit_index = 0
	_feinted = false
	if moves[key].get("unblockable", false):
		Game.sfx("danger")   # 危
	if target == null:
		target = main.visible_player(global_position)
	if target != null:
		facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(S.WINDUP)


func _state_windup(delta: float) -> void:
	var m := _move()
	if m["kind"] == "thrust" and state_time < 0.25:
		velocity.x = -facing * 60.0   # 后撤蓄力
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	var windup: float = _hit_times()[0] * _speed()
	if m.has("feint") and not _feinted and state_time >= windup * float(m["feint"]["at"]):
		# 假动作：举刀举到一半突然换招
		_feinted = true
		move_key = m["feint"]["into"]
		if moves[move_key].get("unblockable", false):
			Game.sfx("danger")
		hit_index = 0
		state_time = 0.0
		main.spawn_dust(global_position, float(-facing), 4)
		return
	if state_time >= windup:
		hit_targets.clear()
		_enter(S.ACTIVE)
		_on_active_start()


func _on_active_start() -> void:
	var m := _move()
	if m.has("hop"):
		velocity.y = float(m["hop"])
	_spawn_fx()


func _state_active(_delta: float) -> void:
	var m := _move()
	var lunge: float = m["lunge"]
	velocity.x = facing * lunge if lunge != 0.0 else facing * 45.0
	if not m.get("nohit", false):
		var size: Vector2 = m["size"]
		var r := front_rect(m["reach"], size, m["height"])
		for p: Player in main.get_players():
			if p in hit_targets or not p.is_alive():
				continue
			if r.intersects(p.body_rect()):
				hit_targets.append(p)
				var info := m
				if dmg_mult != 1.0:
					info = m.duplicate()
					info["dmg"] = float(m["dmg"]) * dmg_mult
				var result := p.receive_enemy_hit(info, self)
				_on_attack_result(result, p)
				if state != S.ACTIVE:
					return
	if state_time >= _hit_times()[1]:
		_enter(S.RECOVER)


func _next_hit() -> void:
	var m := _move()
	var hits: Array = m["hits"]
	if hit_index + 1 < hits.size():
		hit_index += 1
		target = main.visible_player(global_position)
		if target != null:
			facing = 1 if target.global_position.x >= global_position.x else -1
		_enter(S.WINDUP)
	elif m.has("then"):
		_start_move(m["then"])
	else:
		attack_cooldown = rng.randf_range(0.5, 1.2) * _speed()
		_retreat_t = float(_ai("retreat", 0.0))
		if (data["ai"] as Dictionary).get("flank", false) and rng.randf() < 0.35:
			_side = -1
		_enter(S.IDLE)


func _stagger(t: float) -> void:
	if state == S.BROKEN or state == S.DYING or state == S.DEAD:
		return
	stagger_time = t
	_enter(S.STAGGER)


func _on_attack_result(result: String, p: Player) -> void:
	var m := _move()
	var p_amount: float = m["posture"]
	var mid := (global_position + p.global_position) / 2.0 + Vector2(0, -33)
	match result:
		"parry":
			# 弹反：敌人受到该招架势值 50% 的反震；杂兵直接被弹开僵直
			main.spawn_impact(mid, Color(1.0, 0.82, 0.35), 1.7, true, p.facing)
			main.spawn_burst(mid, 1.5)
			main.spawn_spark(mid, Color(1.0, 0.9, 0.4), 14)
			main.spawn_ring(mid, Color(1.0, 0.95, 0.6), 40.0)
			main.spawn_text(mid + Vector2(0, -16), "弹反", Color(1.0, 0.9, 0.4))
			main.flash_screen(Color(1.0, 0.95, 0.8), 0.18)
			main.hitstop(0.11)
			main.shake(4.0)
			main.punch(0.05)
			velocity.x = -facing * 120.0
			if is_grunt():
				velocity.x = -facing * 200.0
				_stagger(0.7)
			else:
				# 心法“不动心”：反震 50% → 80%
				add_posture(p_amount * (0.5 + float(p.stats["parry_rebound"])) * (1.0 + float(p.stats["parry_posture"])))
		"block":
			main.spawn_impact(mid, Color(0.75, 0.85, 1.0), 0.7, false, p.facing)
			main.spawn_burst(mid, 0.6)
			main.hitstop(0.04)
		"hit":
			main.spawn_impact(p.global_position + Vector2(0, -30), Color(1.0, 0.35, 0.25), 0.9, false, facing)
			main.hitstop(0.06)
			main.shake(3.0)
			if m["kind"] == "grab":
				# 被抓住：摔在地上
				main.spawn_text(p.global_position + Vector2(0, -70), "擒拿", Color(1.0, 0.3, 0.2))
				main.spawn_dust(p.global_position, 0.0, 12)
				main.flash_screen(Color(0.6, 0.0, 0.0), 0.3)
				main.hitstop(0.1)
				main.shake(5.0)
				velocity.x = 0.0
				_enter(S.RECOVER)
		"mikiri":
			main.spawn_text(global_position + Vector2(0, -84), "看破", Color(0.6, 1.0, 0.8))
			main.spawn_spark(global_position + Vector2(0, -30), Color(0.6, 1.0, 0.8), 12)
			main.hitstop(0.1)
			main.shake(4.0)
			main.punch(0.06)
			if not is_grunt():
				add_posture(max_posture * 0.4)
			_stagger(0.9)


# ---------- 受击 ----------

## 醒过来开始打（附近站着的同伴一起醒）
func wake() -> void:
	if aggro:
		return
	aggro = true
	attack_cooldown = maxf(attack_cooldown, 0.5)
	for o: Enemy in main.get_enemies():
		if o != self and not o.aggro and absf(o.global_position.x - global_position.x) < 220.0:
			o.wake()


## 玩家攻击命中时调用。返回 hit / blocked / guardbreak / none
func receive_player_hit(atk: Dictionary, p: Player) -> String:
	if not is_hittable() or state == S.BROKEN:
		return "none"
	wake()
	var hit := p.strike(atk, self)
	var dmg: float = hit["dmg"]
	var p_amount: float = hit["posture"]
	var heavy: bool = hit["heavy"]
	var from_front := (p.global_position.x >= global_position.x) == (facing == 1)
	var mid := (global_position + p.global_position) / 2.0 + Vector2(0, -33)

	# 盾兵：正面的轻攻击全挡，出招和僵直时才有破绽
	if data.get("shield", false) and from_front and state != S.ACTIVE and state != S.RECOVER and state != S.STAGGER:
		if heavy:
			main.spawn_text(global_position + Vector2(0, -80), "破盾", Color(1.0, 0.6, 0.2))
			Game.sfx("guard_break")
			main.spawn_impact(mid, Color(1.0, 0.6, 0.25), 1.5, false, p.facing)
			main.hitstop(0.09)
			main.shake(4.0)
			_take_damage(dmg * 0.5, p_amount)
			p.on_hit_landed(self, hit)
			velocity.x = -facing * 160.0
			_stagger(1.1)
			return "guardbreak"
		main.spawn_impact(mid + Vector2(-facing * 6.0, 0), Color(0.95, 0.85, 0.6), 0.7, false, p.facing)
		Game.sfx("block", -4.0)
		main.hitstop(0.03)
		velocity.x = -facing * 40.0
		block_streak += 1
		if block_streak >= 3 and state == S.IDLE:
			block_streak = 0
			target = p
			_start_move("bash")   # 挡了三下就用盾顶回去
		return "blocked"

	var guard_chance: float = float(data["guard"])
	if phase >= 1 and guard_chance > 0.0:
		guard_chance += 0.15
	var can_guard := from_front and (state == S.IDLE or state == S.GUARD or state == S.FLINCH)
	if can_guard and (state == S.GUARD or rng.randf() < guard_chance):
		if heavy:
			# 重攻击破防
			main.spawn_text(global_position + Vector2(0, -84), "破招", Color(1.0, 0.6, 0.2))
			Game.sfx("guard_break")
			main.spawn_impact(mid, Color(1.0, 0.6, 0.25), 1.5, false, p.facing)
			main.shake(4.0)
			_take_damage(dmg, p_amount)
			p.on_hit_landed(self, hit)
			_stagger(0.5)
			return "guardbreak"
		main.spawn_impact(mid, Color(0.8, 0.88, 1.0), 0.75, false, p.facing)
		Game.sfx("block", -4.0)
		main.hitstop(0.03)
		add_posture(p_amount * 0.5)
		if state == S.BROKEN:
			return "hit"
		_enter(S.GUARD)
		block_streak += 1
		if block_streak >= 3:
			# 连续被打三下格挡后立刻反击，逼玩家等待和弹反
			block_streak = 0
			target = p
			_start_move("quick" if moves.has("quick") else moves.keys()[0])
		return "blocked"

	block_streak = 0
	# 砍中：敌人整个闪白，刀口炸开一团光，血往刀的方向喷，顿一下
	var cut := Vector2(global_position.x - signf(global_position.x - p.global_position.x) * 6.0, global_position.y - body_size.y * 0.55)
	main.spawn_impact(cut, Color(1.0, 0.8, 0.45), 1.3 if heavy else 0.95, false, p.facing)
	main.spawn_blood(cut, float(p.facing), 16 if heavy else 11)
	if heavy:
		main.spawn_burst(cut, 1.0)
	Game.sfx("hit_heavy" if heavy else "hit")
	main.hitstop(0.09 if heavy else 0.05)
	main.shake(4.5 if heavy else 2.5)
	if heavy:
		main.punch(0.03)
	_take_damage(dmg, p_amount)
	p.on_hit_landed(self, hit)
	if state == S.IDLE or state == S.GUARD or (is_grunt() and state == S.WINDUP):
		# 杂兵挨刀会被打断出招
		velocity.x = -facing * (140.0 if is_grunt() else 90.0)
		_enter(S.FLINCH)
	return "hit"


## 双短刃、浮舟渡打的流血：叠层，每层每秒 3 点伤害，3 秒没再被砍就止住。
## 心法“血音”：叠满 5 层时引爆，造成一大截架势伤害
func add_bleed(p: Player = null) -> void:
	bleed_stacks = mini(bleed_stacks + 1, BLEED_MAX)
	bleed_time = BLEED_TIME
	if p != null and bleed_stacks >= BLEED_MAX and float(p.stats["bleed_burst"]) > 0.0 and is_hittable():
		bleed_stacks = 0
		var at := global_position + Vector2(0, -body_size.y * 0.55)
		main.spawn_text(at + Vector2(0, -30), "血音", Color(1.0, 0.25, 0.3), 14)
		main.spawn_blood(at, 1.0, 14)
		main.spawn_blood(at, -1.0, 14)
		main.spawn_ring(at, Color(1.0, 0.25, 0.3), 30.0)
		main.hitstop(0.06)
		_take_damage(BLEED_BURST_DMG, maxf(BLEED_BURST_POSTURE, max_posture * 0.3))


func _tick_bleed(delta: float) -> void:
	if bleed_stacks <= 0:
		return
	if state == S.DYING or state == S.DEAD or state == S.BROKEN:
		bleed_stacks = 0
		return
	bleed_time -= delta
	_bleed_acc += delta
	if _bleed_acc >= 0.5:
		_bleed_acc -= 0.5
		hp = maxf(0.0, hp - BLEED_DPS * 0.5 * bleed_stacks)
		main.spawn_blood(global_position + Vector2(0, -body_size.y * 0.5), 0.0, 2 + bleed_stacks)
		if hp <= 0.0:
			bleed_stacks = 0
			if is_grunt():
				_die()
			else:
				_break()
			return
	if bleed_time <= 0.0:
		bleed_stacks = 0


func _take_damage(dmg: float, p_amount: float) -> void:
	hp = maxf(0.0, hp - dmg)
	flash(Color(1, 1, 1), 0.11)
	if hp <= 0.0:
		if is_grunt():
			_die()
		else:
			_break()   # 生命归零也会给出处决机会
		return
	add_posture(p_amount)


func on_stomped(_p: Player) -> void:
	var sweeping: bool = move_key != "" and moves.has(move_key) and _move()["kind"] == "sweep" \
		and (state == S.WINDUP or state == S.ACTIVE or state == S.RECOVER)
	if sweeping or data.get("stomp_stagger", false):
		main.spawn_text(global_position + Vector2(0, -body_size.y - 28.0), "踩踏", Color(0.6, 1.0, 0.8))
		main.hitstop(0.06)
		if not is_grunt():
			add_posture(max_posture * 0.3)
		_stagger(0.5)
	else:
		add_posture(8.0)


func _on_posture_full() -> void:
	_break()


func _break() -> void:
	if state == S.BROKEN or state == S.DYING or state == S.DEAD or state == S.REVIVE:
		return
	if is_grunt():
		# 杂兵没有处决：架势满了只是踉跄一下
		posture = 0.0
		_stagger(0.8)
		return
	posture = max_posture
	main.spawn_text(global_position + Vector2(0, -88), "架势崩溃", Color(1.0, 0.25, 0.2))
	Game.sfx("posture_break")
	main.shake(3.0)
	_enter(S.BROKEN)


## 杂兵血空：直接倒下
func _die() -> void:
	lives = 0
	hp = 0.0
	main.spawn_text(global_position + Vector2(0, -body_size.y - 24.0), "斩", Color(1.0, 0.2, 0.15), 18)
	main.spawn_blood(global_position + Vector2(0, -body_size.y * 0.6), float(-facing), 16)
	main.hitstop(0.05)
	main.shake(3.0)
	velocity.x = -facing * 120.0
	_enter(S.DYING)


func execute_by(p: Player) -> void:
	lives -= 1
	Game.sfx("execute")
	main.spawn_text(global_position + Vector2(0, -88), "处决", Color(1.0, 0.1, 0.1), 22)
	main.spawn_spark(global_position + Vector2(0, -30), Color(1.0, 0.1, 0.1), 24)
	main.spawn_impact(global_position + Vector2(0, -32), Color(1.0, 0.3, 0.2), 2.2, true, p.facing)
	main.spawn_blood(global_position + Vector2(0, -33), float(p.facing), 24)
	main.flash_screen(Color(0.85, 0.0, 0.0), 0.45)
	main.hitstop(0.18)
	main.slowmo(0.3, 0.6)
	main.punch(0.12)
	main.shake(6.0)
	velocity.x = p.facing * 120.0
	if lives > 0:
		_enter(S.REVIVE)
	else:
		hp = 0.0
		if data.has("death_line"):
			main.hud.say(data["death_line"][0], data["death_line"][1])
		_enter(S.DYING)


func _state_intro(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	# 有人走近了就不等他说完
	var p: Player = main.nearest_player(global_position)
	if p != null and absf(p.global_position.x - global_position.x) < 90.0 and state_time < INTRO_TURN:
		state_time = INTRO_TURN
	var lines: Array = intro_lines
	var at := [0.5, 2.3]
	if _intro_said < lines.size() and _intro_said < at.size() and state_time >= at[_intro_said] and state_time < INTRO_TURN:
		var line: Array = lines[_intro_said]
		main.hud.say(line[0], line[1], 1.8)
		_intro_said += 1
	if state_time >= INTRO_TURN and _intro_said < 99:
		_intro_said = 99
		if p != null:
			facing = 1 if p.global_position.x >= global_position.x else -1
		main.hud.title_card(display_name(), String(data.get("title_sub", "第一层 · 山脚荒村")))
		Game.sfx("boss")
		main.shake(2.0)
		main.spawn_dust(global_position, 0.0, 10)
	if state_time >= INTRO_END:
		attack_cooldown = 0.6
		_enter(S.IDLE)


# ---------- 美术 ----------

func _spawn_fx() -> void:
	var red := Color(1.0, 0.35, 0.25)
	var white := Color(1.0, 0.9, 0.85)
	var center := global_position + Vector2(facing * 10.0, -29.0)
	match String(_move().get("fx", "slash")):
		"sweep":
			main.spawn_slash(global_position + Vector2(facing * 12.0, -9.0), facing, 46.0, -0.6, 0.35, red, 9.0)
			main.spawn_dust(global_position + Vector2(facing * 30.0, 0), float(facing), 10)
		"streak":
			main.spawn_streak(global_position + Vector2(facing * 9.0, -27.0), facing, 78.0, red)
			main.spawn_dust(global_position, float(-facing), 8)
		"iai":
			main.spawn_streak(global_position + Vector2(facing * 4.0, -30.0), facing, 120.0, Color(0.7, 0.9, 1.0))
			main.spawn_slash(center, facing, 54.0, -0.5, 0.5, Color(0.8, 0.95, 1.0), 9.0)
			main.spawn_dust(global_position, float(-facing), 10)
			main.shake(2.0)
		"bite":
			main.spawn_dust(global_position, float(-facing), 4)
		"arrow":
			var info: Dictionary = _move()["arrow"]
			var a := Arrow.new()
			a.main = main
			a.facing = facing
			# 朝玩家身体瞄，高处往下射、低处往上射（角度有上限）
			var dir := Vector2(facing, 0.0)
			if target != null:
				var to := target.global_position + Vector2(0, -26) - (global_position + Vector2(facing * 14.0, -34.0))
				if signf(to.x) == float(facing):
					dir = to.normalized()
					dir.y = clampf(dir.y, -0.6, 0.6)
					dir = dir.normalized()
			a.velocity = dir * float(info["speed"])
			a.dmg = float(info["dmg"]) * dmg_mult
			a.posture = info["posture"]
			a.star = info.get("style", "") == "star"
			Game.sfx("throw" if a.star else "bow")
			a.position = global_position + Vector2(facing * 14.0, -34.0)
			main.fx_root.add_child(a)
		"slash":
			if hit_index % 2 == 1:
				main.spawn_slash(center, facing, 42.0, 0.9, -1.7, white)
			else:
				main.spawn_slash(center, facing, 42.0, -2.2, 0.6, white)


## 当前这一段的 [蓄力姿势, 出手姿势]
func _move_keys() -> Array:
	var m := _move()
	if not m.has("poses"):
		return ["raise1", "cut1"]
	var poses: Array = m["poses"]
	return poses[mini(hit_index, poses.size() - 1)]


func _idle_keys() -> Array:
	return data.get("idle", ["stalk", "stalk"])


func _ready_pose() -> Dictionary:
	return POSES[_idle_keys()[1]]


func _target_pose() -> Dictionary:
	var p := _target_pose_raw()
	if data["prop"] == "bow":
		p = p.duplicate()
		p["sheathed"] = 1.0   # 弓手不带刀
	return p


func _target_pose_raw() -> Dictionary:
	var t := state_time
	match state:
		S.IDLE:
			return _idle_pose()
		S.WINDUP:
			var keys := _move_keys()
			var windup: float = _hit_times()[0] * _speed()
			return Puppet.lerp_pose(_ready_pose(), POSES[keys[0]], t / maxf(windup * 0.6, 0.01))
		S.ACTIVE:
			var keys := _move_keys()
			var active: float = _hit_times()[1]
			return Puppet.lerp_pose(POSES[keys[0]], POSES[keys[1]], t / maxf(active * 0.6, 0.01))
		S.RECOVER:
			var keys := _move_keys()
			var recover: float = _hit_times()[2] * _speed()
			return Puppet.lerp_pose(POSES[keys[1]], _ready_pose(), pow(t / recover, 2.0))
		S.GUARD:
			return POSES["guard"]
		S.FLINCH, S.STAGGER:
			return POSES["hit"]
		S.DYING:
			return POSES["kneel"]
		S.BROKEN, S.DEAD:
			var bp: Dictionary = POSES["broken"].duplicate()
			bp["lean"] = 0.7 + sin(_clock * 3.0) * 0.1
			return bp
		S.REVIVE:
			return Puppet.lerp_pose(POSES["broken"], _ready_pose(), (t - 0.6) / 0.6)
		S.INTRO:
			var calm: Dictionary = POSES[_idle_keys()[0]]
			if t < INTRO_TURN:
				return Puppet.breathe(calm, _clock * 0.7, 1.0)
			return Puppet.lerp_pose(calm, _ready_pose(), (t - INTRO_TURN) / 0.5)
	return _ready_pose()


## 浪人走着走着会扛刀敲肩、转刀、压斗笠、勾手挑衅；一出招就打断
func _update_flourish(delta: float) -> void:
	if state != S.IDLE or not data.get("flourish", false):
		_fl_kind = ""
		return
	if _fl_kind == "":
		_fl_wait -= delta
		if _fl_wait <= 0.0:
			_fl_kind = Flourish.pick(Flourish.ENEMY_NEAR if _stalk > 0.5 else Flourish.ENEMY_FAR, _fl_last)
			_fl_last = _fl_kind
			_fl_t = 0.0
		return
	_fl_t += delta
	if _fl_t >= Flourish.duration(_fl_kind):
		_fl_kind = ""
		_fl_wait = rng.randf_range(1.5, 3.5)


func _base_pose() -> Dictionary:
	var keys := _idle_keys()
	return Puppet.lerp_pose(POSES[keys[0]], POSES[keys[1]], _stalk)


## 待机/走动：远处放松，近处压低身体横移
func _idle_pose() -> Dictionary:
	var p := _move_pose()
	if _fl_kind != "":
		return Flourish.overlay(p, Flourish.sample(_fl_kind, _fl_t, _base_pose()))
	return p


func _move_pose() -> Dictionary:
	var base := _base_pose()
	var speed := absf(velocity.x)
	var walk: float = data["speed"]
	if speed < 5.0:
		return Puppet.breathe(base, _clock * 0.85, 1.2 - _stalk * 0.5)
	var k := clampf(speed / walk, 0.0, 1.0)
	var back := signf(velocity.x) != float(facing)
	var ph := _clock * (7.0 + 3.0 * _stalk) * (-1.0 if back else 1.0)
	var stride := lerpf(5.0, 4.0, _stalk) * k
	var w := base.duplicate()
	w["foot_f"] = Vector2(float(base["foot_f"].x) * 0.4 + stride * sin(ph), -maxf(0.0, 2.2 * cos(ph)) * k)
	w["foot_b"] = Vector2(float(base["foot_b"].x) * 0.4 - stride * sin(ph), -maxf(0.0, -2.2 * cos(ph)) * k)
	# 每一步身体上下起伏、左右晃，扛着的刀跟着颠
	w["crouch"] = float(base["crouch"]) + absf(sin(ph)) * 0.9 * k
	w["lean"] = float(base["lean"]) + sin(ph * 2.0) * 0.03 + (-0.18 if back else 0.0)
	w["head"] = float(base["head"]) - sin(ph * 2.0) * 0.04
	w["sword"] = float(base["sword"]) + sin(ph * 2.0 + 0.5) * lerpf(0.12, 0.04, _stalk)
	if data["prop"] != "shield":
		var ab: Vector2 = base["arm_b"]
		w["arm_b"] = ab + Vector2(-sin(ph) * 0.35 * (1.0 - _stalk), 0.0)
	return w


func _danger() -> bool:
	return state == S.WINDUP and move_key != "" and bool(_move()["unblockable"])


func _draw() -> void:
	var top := Puppet.head_top(look) - 6.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var danger := _danger()
	var tint := _tint()
	var pulse := 0.5 + 0.5 * sin(state_time * 30.0)
	var aura: Color = _phase_data().get("aura", Color(0, 0, 0, 0))
	look.eye_glow = Color(aura, 1.0) if aura.a > 0.0 else Color(0, 0, 0, 0)

	if state == S.DYING:
		# 跪地一会儿，再往前扑倒，最后慢慢消失
		var x := clampf((state_time - 0.6) / 0.4, 0.0, 1.0)
		var k := Player._ease_out_bounce(x)
		var rot := facing * PI / 2.0 * k
		var pivot := Vector2(facing * 9.0, 0)
		if x >= 1.0 and not _fell:
			_fell = true
			main.spawn_dust(global_position + Vector2(facing * 30.0, 0), 0.0, 12)
			main.shake(2.0)
		var fade := 1.0 - clampf((state_time - 1.3) / 0.6, 0.0, 1.0)
		Puppet.draw(self, _pose, look, facing, pivot - pivot.rotated(rot), Color(0.15, 0.15, 0.2, 0.4 * k), fade, rot)
		return
	if state == S.DEAD:
		return

	if aura.a > 0.0:
		# 后面的阶段：身上冒出气
		for i in range(6):
			var x := sin(_clock * 5.0 + i * 1.7) * 10.0
			var y := -fmod(_clock * 40.0 + i * 13.0, 60.0)
			draw_rect(Rect2(x - 1, y, 2, 2), Color(aura, 0.7 * (1.0 + y / 60.0)))
	# 危招时身后亮起红光
	if danger:
		draw_circle(Vector2(0, -30), 24.0 + pulse * 4.0, Color(1, 0.1, 0.05, 0.12))
	var rim := Color(1.0, 0.4, 0.3, 0.7) if danger else Color(0.5, 0.62, 0.9, 0.5)
	if data["prop"] == "bow":
		_draw_bow(tint, true)
	Puppet.draw_lit(self, _pose, look, facing, rim, Vector2.ZERO, tint, 1.0, 0.0, Vector2.ONE, velocity.x)
	if data["prop"] == "bow":
		_draw_bow(tint, false)
	elif data["prop"] == "shield":
		_draw_shield(tint)

	_draw_overlay(top, danger)


func _tint() -> Color:
	var pulse := 0.5 + 0.5 * sin(state_time * 30.0)
	if flash_timer > 0.0:
		return Color(flash_color, 1.0)
	if _danger():
		return Color(1.0, 0.1, 0.05, 0.2 + 0.3 * pulse)
	if state == S.BROKEN or state == S.REVIVE:
		return Color(0.2, 0.2, 0.25, 0.35)
	return Color(0, 0, 0, 0)


## 角色本身之外的提示：危字、出手闪光、处决点、架势条/血条
func _draw_overlay(top: float, danger: bool) -> void:
	if danger:
		_draw_label("危", Vector2(0, top - 10), Color(1, 0.2, 0.1), 24)
	elif state == S.WINDUP and (not _move().get("nohit", false) or _move().get("fx") == "arrow"):
		# 可弹反的招式：出手前闪光
		var windup_t: float = _hit_times()[0]
		if state_time >= windup_t * _speed() - 0.12:
			_draw_glint(_glint_pos())
	if state == S.BROKEN:
		var bp := 0.5 + 0.5 * sin(state_time * 12.0)
		draw_circle(Vector2(0, -36), 7.0 + bp * 3.0, Color(1, 0.05, 0.05, 0.25))
		draw_circle(Vector2(0, -36), 4.5 + bp * 1.5, Color(0, 0, 0, 0.7))
		draw_circle(Vector2(0, -36), 3.5 + bp * 1.5, Color(0.9, 0.02, 0.02))
		_draw_label("按攻击键处决", Vector2(0, top - 12), Color(1, 0.4, 0.4), 12)

	if is_grunt():
		if hp < max_hp:
			_draw_small_hp(Vector2(0, top + 2), 26.0)
	elif posture > 0.5:
		draw_posture_bar(Vector2(0, top), 64.0, posture / max_posture)

	if Game.show_hitboxes:
		var w := body_size.x
		var h := body_size.y
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ACTIVE and not _move().get("nohit", false):
			var m := _move()
			var size: Vector2 = m["size"]
			draw_rect(to_local_rect(front_rect(m["reach"], size, m["height"])), Color(1, 0, 0, 0.8), false)


func _glint_pos() -> Vector2:
	if data["prop"] == "bow":
		return _hand(true) + Vector2(facing * 6.0, 0)
	return Puppet.sword_tip(_pose, look, facing)


func _draw_glint(tip: Vector2) -> void:
	draw_circle(tip, 4.0, Color(1, 1, 1, 0.35))
	draw_circle(tip, 2.0, Color(1, 1, 1))
	draw_line(tip - Vector2(8, 0), tip + Vector2(8, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(tip - Vector2(0, 8), tip + Vector2(0, 8), Color(1, 1, 1, 0.9), 1.0)


func _draw_small_hp(c: Vector2, width: float) -> void:
	var at := (c - Vector2(width / 2.0, 0)).round()
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(width + 2, 4)), Color(0.02, 0.02, 0.04, 0.85))
	draw_rect(Rect2(at, Vector2(roundf(width * hp / max_hp), 2)), Color("c42a2a"))


## 手的位置（本地坐标）
func _hand(front: bool) -> Vector2:
	var j := Puppet.solve(_pose)
	var h: Vector2 = j["hand_f"] if front else j["hand_b"]
	return Vector2(h.x * facing, h.y) * look.scale


## 弓：前手握弓背，弦拉到后手。behind 为 true 时只画身体后面的弦
func _draw_bow(tint: Color, behind: bool) -> void:
	var hf := _hand(true)
	var hb := _hand(false)
	var arm: Vector2 = _pose["arm_f"]
	var dir := Vector2(sin(arm.y) * facing, cos(arm.y))     # 前臂方向
	var axis := Vector2(-dir.y, dir.x)                       # 弓身方向
	var half := 14.0
	var top := hf + axis * half - dir * 3.0
	var bot := hf - axis * half - dir * 3.0
	var drawing: bool = state == S.WINDUP and _move().get("fx") == "arrow"
	var nock := hb if drawing else (top + bot) / 2.0
	var wood := Color("5a3a22")
	var string_col := Color(0.85, 0.82, 0.75, 0.9)
	if tint.a >= 1.0:
		wood = Color(tint, 1.0)
		string_col = wood
	if behind:
		draw_line(top, nock, string_col, 1.0)
		draw_line(nock, bot, string_col, 1.0)
		return
	var pts := PackedVector2Array()
	for i in range(9):
		var s := -1.0 + i / 4.0
		pts.append(hf + axis * half * s + dir * (2.5 * (1.0 - s * s) - 3.0))
	draw_polyline(pts, Color(0.05, 0.03, 0.03), 3.0)
	draw_polyline(pts, wood, 1.5)
	if drawing:
		# 搭在弦上的箭
		var tip := hf + dir * 8.0
		draw_line(nock, tip, Color("c9b08a"), 1.0)
		draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), Color(0.9, 0.9, 0.95))


## 木盾：后手拿着挡在身前
func _draw_shield(tint: Color) -> void:
	var h := _hand(false) + Vector2(facing * 4.0, -2.0)
	var r := Rect2(h - Vector2(6, 15), Vector2(12, 28))
	var wood := Color("6b4a2e")
	var dark := Color("43301f")
	var iron := Color("8a8f99")
	if tint.a >= 1.0:
		wood = Color(tint, 1.0)
		dark = wood
		iron = wood
	elif tint.a > 0.0:
		wood = wood.lerp(Color(tint, 1.0), tint.a)
	draw_rect(r.grow(1), Color(0.03, 0.02, 0.04))
	draw_rect(r, wood)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), wood.lightened(0.25))
	for i in range(1, 3):
		var x := r.position.x + r.size.x * i / 3.0
		draw_line(Vector2(x, r.position.y + 1), Vector2(x, r.end.y), dark, 1.0)
	draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(r.size.x, 2)), iron)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 7), Vector2(r.size.x, 2)), iron)
	draw_circle(r.get_center(), 1.5, iron.lightened(0.3))


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var tw := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := (pos - Vector2(tw / 2.0, 0)).round()
	draw_string_outline(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.9))
	draw_string(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
