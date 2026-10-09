class_name Enemy
extends Fighter
## 练手敌人「浪人」（精英）：两管血，四个招式，会格挡。
## 三连斩、快斩可以弹反；下段横扫（危）要跳起踩头；突刺（危）要朝它闪身「看破」。

enum S { IDLE, WINDUP, ACTIVE, RECOVER, GUARD, FLINCH, STAGGER, BROKEN, REVIVE, DYING, DEAD }

const BASE_HP := 300.0
const BASE_POSTURE := 200.0
const COOP_HP_MULT := 1.6           # 双人时生命 ×1.6
const COOP_POSTURE_MULT := 1.4      # 双人时架势 ×1.4
const LIVES := 2                    # 精英：处决一次扣一管
const WALK_SPEED := 105.0
const BROKEN_TIME := 2.0            # 架势满 → 处决窗口 2 秒
const GUARD_CHANCE := 0.4
const RESPAWN_TIME := 3.0

# 每段攻击的时间：前摇 / 判定 / 后摇（秒）
const MOVES := {
	"slash": {"name": "三连斩", "kind": "slash", "unblockable": false,
		"dmg": 25.0, "posture": 30.0, "reach": 39.0, "size": Vector2(66, 36), "height": 30.0, "lunge": 0.0,
		"hits": [[0.45, 0.10, 0.18], [0.28, 0.10, 0.18], [0.34, 0.12, 0.60]]},
	"quick": {"name": "快斩", "kind": "slash", "unblockable": false,
		"dmg": 20.0, "posture": 30.0, "reach": 39.0, "size": Vector2(63, 36), "height": 30.0, "lunge": 0.0,
		"hits": [[0.24, 0.10, 0.45]]},
	"sweep": {"name": "下段横扫", "kind": "sweep", "unblockable": true,
		"dmg": 35.0, "posture": 40.0, "reach": 45.0, "size": Vector2(96, 18), "height": 9.0, "lunge": 0.0,
		"hits": [[0.60, 0.16, 0.65]]},
	"thrust": {"name": "突刺", "kind": "thrust", "unblockable": true,
		"dmg": 40.0, "posture": 40.0, "reach": 33.0, "size": Vector2(60, 21), "height": 30.0, "lunge": 780.0,
		"hits": [[0.65, 0.20, 0.65]]},
}

var state := S.IDLE
var lives := LIVES
var phase2 := false
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

# 美术
var look := Puppet.Look.new()
var _pose: Dictionary = {}
var _clock := 0.0
var _stalk := 0.0           # 0 扛刀放松，1 压低戒备
var _fl_kind := ""          # 正在做的挑衅/耍刀动作（见 Flourish）
var _fl_t := 0.0
var _fl_wait := 1.5
var _fl_last := ""

static var POSES := {}


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
	# 远处：刀扛在肩上，身体放松
	POSES["shoulder"] = Puppet.pose({"crouch": 0.8, "lean": -0.04, "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.75, 3.0), "arm_b": Vector2(-0.15, 0.15), "sword": 4.1, "head": 0.05})
	# 近处：压低身体，刀尖低垂，伺机出手
	POSES["stalk"] = Puppet.pose({"crouch": 3.2, "lean": 0.26, "foot_f": Vector2(7, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.7, 1.15), "arm_b": Vector2(0.5, 1.1), "sword": 0.95, "head": -0.12})
	var tp: Dictionary = Player.POSES["raise3"].duplicate()
	tp["lean"] = -0.3
	tp["crouch"] = 4.0
	POSES["thrust_prep"] = tp


func _ready() -> void:
	_build_poses()
	look.scale = 1.12
	look.hat = true
	look.cape = true
	look.cloth = Color("6e2a2a")
	look.cloth_dark = Color("461a1d")
	look.cloth_light = Color("9a4438")
	look.collar = Color("b8ab96")
	look.pants = Color("2f2c36")
	look.pants_dark = Color("1d1b22")
	look.pants_light = Color("4a4656")
	look.hair = Color("2a1a14")
	look.belt = Color("6d6247")
	look.cape_color = Color("3b2e2b")
	look.sword_len = 28.0
	look.width = 1.15
	_pose = POSES["shoulder"].duplicate()
	body_size = Vector2(30, 56)
	setup_body()
	posture_recover_rate = 25.0
	spawn_pos = global_position
	_apply_stats(true)


func _apply_stats(full: bool) -> void:
	var hp_ratio := 1.0 if full else hp / max_hp
	var posture_ratio := 0.0 if full else posture / max_posture
	max_hp = BASE_HP * (COOP_HP_MULT if coop else 1.0)
	max_posture = BASE_POSTURE * (COOP_POSTURE_MULT if coop else 1.0)
	hp = max_hp * hp_ratio
	posture = max_posture * posture_ratio


func set_coop(value: bool) -> void:
	if coop == value:
		return
	coop = value
	_apply_stats(false)


func reset() -> void:
	lives = LIVES
	phase2 = false
	global_position = spawn_pos
	velocity = Vector2.ZERO
	attack_cooldown = 1.0
	block_streak = 0
	visible = true
	_apply_stats(true)
	_enter(S.IDLE)


func is_hittable() -> bool:
	return state != S.DYING and state != S.DEAD and state != S.REVIVE


func _enter(s: S) -> void:
	state = s
	state_time = 0.0


func _speed() -> float:
	return 0.85 if phase2 else 1.0   # 第二管血出招更快


func _move() -> Dictionary:
	return MOVES[move_key]


func _hit_times() -> Array:
	var hits: Array = _move()["hits"]
	return hits[hit_index]


func _physics_process(delta: float) -> void:
	state_time += delta
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
				hp = max_hp
				posture = 0.0
				phase2 = true
				attack_cooldown = 0.4
				main.spawn_text(global_position + Vector2(0, -84), "第二管血", Color(1.0, 0.4, 0.3))
				_enter(S.IDLE)
		S.DYING:
			velocity.x = 0.0
			if state_time >= 1.0:
				visible = false
				_enter(S.DEAD)
		S.DEAD:
			if state_time >= RESPAWN_TIME:
				reset()

	apply_gravity(delta)
	move_and_slide()
	_clock += delta
	var near := target != null and absf(target.global_position.x - global_position.x) < 200.0
	_stalk = move_toward(_stalk, 1.0 if near else 0.0, delta * 2.5)
	_update_flourish(delta)
	var rate := 50.0 if state == S.ACTIVE else 18.0
	_pose = Puppet.lerp_pose(_pose, _target_pose(), 1.0 - exp(-rate * delta))
	queue_redraw()


# ---------- AI ----------

func _state_idle(delta: float) -> void:
	target = main.nearest_player(global_position)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		return
	var dx := target.global_position.x - global_position.x
	facing = 1 if dx >= 0.0 else -1
	var dist := absf(dx)

	if attack_cooldown <= 0.0 and is_on_floor():
		if dist < 93.0:
			_start_move(_pick([["slash", 45], ["sweep", 20], ["quick", 15], ["thrust", 20]]))
			return
		if dist < 240.0 and rng.randf() < 0.012:
			_start_move("thrust")   # 中距离偶尔突刺
			return
	var want := 0.0
	if dist > 81.0:
		want = facing * WALK_SPEED
	elif dist < 45.0:
		want = -facing * WALK_SPEED * 0.7
	velocity.x = move_toward(velocity.x, want, 900.0 * delta)


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
	if target != null:
		facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(S.WINDUP)


func _state_windup(delta: float) -> void:
	if move_key == "thrust" and state_time < 0.25:
		velocity.x = -facing * 60.0   # 后撤蓄力
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if state_time >= _hit_times()[0] * _speed():
		hit_targets.clear()
		_enter(S.ACTIVE)
		_spawn_slash()


func _state_active(_delta: float) -> void:
	var m := _move()
	var lunge: float = m["lunge"]
	velocity.x = facing * lunge if lunge > 0.0 else facing * 45.0
	var size: Vector2 = m["size"]
	var r := front_rect(m["reach"], size, m["height"])
	for p: Player in main.get_players():
		if p in hit_targets or not p.is_alive():
			continue
		if r.intersects(p.body_rect()):
			hit_targets.append(p)
			var result := p.receive_enemy_hit(m, self)
			_on_attack_result(result, p)
			if state != S.ACTIVE:
				return
	if state_time >= _hit_times()[1]:
		_enter(S.RECOVER)


func _next_hit() -> void:
	var hits: Array = _move()["hits"]
	if hit_index + 1 < hits.size():
		hit_index += 1
		target = main.nearest_player(global_position)
		if target != null:
			facing = 1 if target.global_position.x >= global_position.x else -1
		_enter(S.WINDUP)
	else:
		attack_cooldown = rng.randf_range(0.5, 1.2) * _speed()
		_enter(S.IDLE)


func _on_attack_result(result: String, p: Player) -> void:
	var m := _move()
	var p_amount: float = m["posture"]
	var mid := (global_position + p.global_position) / 2.0 + Vector2(0, -33)
	match result:
		"parry":
			# 弹反：敌人受到该招架势值 50% 的反震
			main.spawn_spark(mid, Color(1.0, 0.9, 0.4), 14)
			main.spawn_ring(mid, Color(1.0, 0.95, 0.6))
			main.spawn_text(mid + Vector2(0, -16), "弹反", Color(1.0, 0.9, 0.4))
			main.hitstop(0.07)
			main.shake(3.0)
			main.punch(0.03)
			velocity.x = -facing * 120.0
			add_posture(p_amount * 0.5)
		"block":
			main.spawn_spark(mid, Color(0.7, 0.8, 1.0), 6)
		"hit":
			main.spawn_spark(mid, Color(0.9, 0.15, 0.15), 8)
			main.shake(2.0)
		"mikiri":
			main.spawn_text(global_position + Vector2(0, -84), "看破", Color(0.6, 1.0, 0.8))
			main.spawn_spark(global_position + Vector2(0, -30), Color(0.6, 1.0, 0.8), 12)
			main.hitstop(0.1)
			main.shake(4.0)
			main.punch(0.06)
			add_posture(max_posture * 0.4)
			if state != S.BROKEN:
				stagger_time = 0.9
				_enter(S.STAGGER)


# ---------- 受击 ----------

## 玩家攻击命中时调用。返回 hit / blocked / guardbreak / none
func receive_player_hit(atk: Dictionary, p: Player) -> String:
	if not is_hittable() or state == S.BROKEN:
		return "none"
	var dmg: float = atk["dmg"]
	var p_amount: float = atk["posture"]
	var heavy: bool = atk["heavy"]
	var from_front := (p.global_position.x >= global_position.x) == (facing == 1)
	var mid := (global_position + p.global_position) / 2.0 + Vector2(0, -33)
	var guard_chance := GUARD_CHANCE + (0.15 if phase2 else 0.0)
	var can_guard := from_front and (state == S.IDLE or state == S.GUARD or state == S.FLINCH)

	if can_guard and (state == S.GUARD or rng.randf() < guard_chance):
		if heavy:
			# 重攻击破防
			main.spawn_text(global_position + Vector2(0, -84), "破招", Color(1.0, 0.6, 0.2))
			main.spawn_spark(mid, Color(1.0, 0.6, 0.2), 12)
			main.shake(3.0)
			_take_damage(dmg, p_amount)
			if state != S.BROKEN:
				stagger_time = 0.5
				_enter(S.STAGGER)
			return "guardbreak"
		main.spawn_spark(mid, Color(0.8, 0.85, 1.0), 6)
		add_posture(p_amount * 0.5)
		if state == S.BROKEN:
			return "hit"
		_enter(S.GUARD)
		block_streak += 1
		if block_streak >= 3:
			# 连续被打三下格挡后立刻反击，逼玩家等待和弹反
			block_streak = 0
			target = p
			_start_move("quick")
		return "blocked"

	block_streak = 0
	main.spawn_spark(mid, Color(0.95, 0.2, 0.2), 8 if not heavy else 12)
	main.spawn_blood(global_position + Vector2(0, -33), float(p.facing), 12 if heavy else 8)
	_take_damage(dmg, p_amount)
	if state == S.IDLE or state == S.GUARD:
		velocity.x = -facing * 90.0
		_enter(S.FLINCH)
	return "hit"


func _take_damage(dmg: float, p_amount: float) -> void:
	hp = maxf(0.0, hp - dmg)
	flash(Color(1, 1, 1), 0.08)
	if hp <= 0.0:
		_break()   # 生命归零也会给出处决机会
		return
	add_posture(p_amount)


func on_stomped(_p: Player) -> void:
	if move_key == "sweep" and (state == S.WINDUP or state == S.ACTIVE or state == S.RECOVER):
		main.spawn_text(global_position + Vector2(0, -84), "踩踏", Color(0.6, 1.0, 0.8))
		main.hitstop(0.06)
		add_posture(max_posture * 0.3)
		if state != S.BROKEN:
			stagger_time = 0.5
			_enter(S.STAGGER)
	else:
		add_posture(8.0)


func _on_posture_full() -> void:
	_break()


func _break() -> void:
	if state == S.BROKEN or state == S.DYING or state == S.DEAD or state == S.REVIVE:
		return
	posture = max_posture
	main.spawn_text(global_position + Vector2(0, -88), "架势崩溃", Color(1.0, 0.25, 0.2))
	main.shake(3.0)
	_enter(S.BROKEN)


func execute_by(p: Player) -> void:
	lives -= 1
	main.spawn_text(global_position + Vector2(0, -88), "处决", Color(1.0, 0.1, 0.1), 22)
	main.spawn_spark(global_position + Vector2(0, -30), Color(1.0, 0.1, 0.1), 24)
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
		_enter(S.DYING)


# ---------- 美术 ----------

func _spawn_slash() -> void:
	var red := Color(1.0, 0.35, 0.25)
	var center := global_position + Vector2(facing * 10.0, -29.0)
	match move_key:
		"sweep":
			main.spawn_slash(global_position + Vector2(facing * 12.0, -9.0), facing, 46.0, -0.6, 0.35, red, 9.0)
			main.spawn_dust(global_position + Vector2(facing * 30.0, 0), float(facing), 10)
		"thrust":
			main.spawn_streak(global_position + Vector2(facing * 9.0, -27.0), facing, 78.0, red)
			main.spawn_dust(global_position, float(-facing), 8)
		_:
			if hit_index == 1:
				main.spawn_slash(center, facing, 42.0, 0.9, -1.7, Color(1.0, 0.9, 0.85))
			else:
				main.spawn_slash(center, facing, 42.0, -2.2, 0.6, Color(1.0, 0.9, 0.85))


func _move_keys() -> Array:
	match move_key:
		"sweep": return ["sweep_prep", "sweep_cut"]
		"thrust": return ["thrust_prep", "cut3"]
		_: return ["raise2", "cut2"] if hit_index == 1 else ["raise1", "cut1"]


func _target_pose() -> Dictionary:
	var t := state_time
	match state:
		S.IDLE:
			return _idle_pose()
		S.WINDUP:
			var keys := _move_keys()
			var windup: float = _hit_times()[0] * _speed()
			return Puppet.lerp_pose(POSES["stalk"], POSES[keys[0]], t / maxf(windup * 0.6, 0.01))
		S.ACTIVE:
			var keys := _move_keys()
			var active: float = _hit_times()[1]
			return Puppet.lerp_pose(POSES[keys[0]], POSES[keys[1]], t / maxf(active * 0.6, 0.01))
		S.RECOVER:
			var keys := _move_keys()
			var recover: float = _hit_times()[2] * _speed()
			return Puppet.lerp_pose(POSES[keys[1]], POSES["stalk"], pow(t / recover, 2.0))
		S.GUARD:
			return POSES["guard"]
		S.FLINCH, S.STAGGER:
			return POSES["hit"]
		S.BROKEN, S.DYING, S.DEAD:
			var bp: Dictionary = POSES["broken"].duplicate()
			bp["lean"] = 0.7 + sin(_clock * 3.0) * 0.1
			return bp
		S.REVIVE:
			return Puppet.lerp_pose(POSES["broken"], POSES["stalk"], (t - 0.6) / 0.6)
	return POSES["stalk"]


## 走着走着会扛刀敲肩、转刀、压斗笠、勾手挑衅；一出招就打断
func _update_flourish(delta: float) -> void:
	if state != S.IDLE:
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


## 待机/走动：远处扛刀晃着走，近处压低身体横移
func _idle_pose() -> Dictionary:
	var p := _move_pose()
	if _fl_kind != "":
		var base := Puppet.lerp_pose(POSES["shoulder"], POSES["stalk"], _stalk)
		return Flourish.overlay(p, Flourish.sample(_fl_kind, _fl_t, base))
	return p


func _move_pose() -> Dictionary:
	var base := Puppet.lerp_pose(POSES["shoulder"], POSES["stalk"], _stalk)
	var speed := absf(velocity.x)
	if speed < 5.0:
		return Puppet.breathe(base, _clock * 0.85, 1.2 - _stalk * 0.5)
	var k := clampf(speed / WALK_SPEED, 0.0, 1.0)
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
	var ab: Vector2 = base["arm_b"]
	w["arm_b"] = ab + Vector2(-sin(ph) * 0.35 * (1.0 - _stalk), 0.0)
	return w


func _draw() -> void:
	var top := Puppet.head_top(look) - 6.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var danger := state == S.WINDUP and move_key != "" and bool(_move()["unblockable"])
	var tint := Color(0, 0, 0, 0)
	var pulse := 0.5 + 0.5 * sin(state_time * 30.0)
	if flash_timer > 0.0:
		tint = Color(flash_color, 1.0)
	elif danger:
		tint = Color(1.0, 0.1, 0.05, 0.2 + 0.3 * pulse)
	elif state == S.BROKEN or state == S.REVIVE:
		tint = Color(0.2, 0.2, 0.25, 0.35)
	look.eye_glow = Color(1.0, 0.2, 0.1) if phase2 else Color(0, 0, 0, 0)

	if state == S.DYING:
		var k := clampf(state_time / 0.6, 0.0, 1.0)
		Puppet.draw(self, _pose, look, facing, Vector2(-facing * 9.0 * k, -4.0 * k), Color(0.15, 0.15, 0.2, 0.5),
			1.0 - clampf(state_time - 0.5, 0.0, 1.0) * 2.0, -facing * PI / 2.0 * k)
		return
	if state == S.DEAD:
		return

	if phase2:
		# 第二管血：身上冒出红色的气
		for i in range(5):
			var x := sin(_clock * 5.0 + i * 1.7) * 10.0
			var y := -fmod(_clock * 40.0 + i * 13.0, 60.0)
			draw_rect(Rect2(x - 1, y, 2, 2), Color(1, 0.25, 0.1, 0.7 * (1.0 + y / 60.0)))
	# 危招时身后亮起红光
	if danger:
		draw_circle(Vector2(0, -30), 24.0 + pulse * 4.0, Color(1, 0.1, 0.05, 0.12))
	var rim := Color(1.0, 0.4, 0.3, 0.7) if danger else Color(0.5, 0.62, 0.9, 0.5)
	Puppet.draw_lit(self, _pose, look, facing, rim, Vector2.ZERO, tint, 1.0, 0.0, Vector2.ONE, velocity.x)

	if danger:
		_draw_label("危", Vector2(0, top - 10), Color(1, 0.2, 0.1), 24)
	elif state == S.WINDUP:
		# 可弹反的招式：出刀前刀尖闪光
		var windup_t: float = _hit_times()[0]
		if state_time >= windup_t * _speed() - 0.12:
			var tip := Puppet.sword_tip(_pose, look, facing)
			draw_circle(tip, 4.0, Color(1, 1, 1, 0.35))
			draw_circle(tip, 2.0, Color(1, 1, 1))
			draw_line(tip - Vector2(8, 0), tip + Vector2(8, 0), Color(1, 1, 1, 0.9), 1.0)
			draw_line(tip - Vector2(0, 8), tip + Vector2(0, 8), Color(1, 1, 1, 0.9), 1.0)
	if state == S.BROKEN:
		# 处决点
		var bp := 0.5 + 0.5 * sin(state_time * 12.0)
		draw_circle(Vector2(0, -36), 7.0 + bp * 3.0, Color(1, 0.05, 0.05, 0.25))
		draw_circle(Vector2(0, -36), 4.5 + bp * 1.5, Color(0, 0, 0, 0.7))
		draw_circle(Vector2(0, -36), 3.5 + bp * 1.5, Color(0.9, 0.02, 0.02))
		_draw_label("按攻击键处决", Vector2(0, top - 12), Color(1, 0.4, 0.4), 12)

	if posture > 0.5:
		draw_posture_bar(Vector2(0, top), 64.0, posture / max_posture)

	if Game.show_hitboxes:
		var w := body_size.x
		var h := body_size.y
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ACTIVE:
			var m := _move()
			var size: Vector2 = m["size"]
			draw_rect(to_local_rect(front_rect(m["reach"], size, m["height"])), Color(1, 0, 0, 0.8), false)


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var tw := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := (pos - Vector2(tw / 2.0, 0)).round()
	draw_string_outline(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.9))
	draw_string(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
