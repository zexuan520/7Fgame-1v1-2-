class_name Hero
extends Actor
## 主角：八方向移动、翻滚（无敌帧 + 残影）、四段连招（数据在 combo）、输入缓冲 0.2 秒、
## 技能：突进斩（青色预警框 → 瞬移穿过路径）、光束斩（斜贯屏幕的光柱，全屏停顿，要满气）、终结技（引爆附近敌人的出血层数）、药葫芦。

signal energy_changed

@export var move_speed := 7.2
@export var accel := 60.0
@export var roll_time := 0.4
@export var roll_dist := 5.2
@export var roll_iframes := 0.26
@export var buffer_time := 0.2
@export var combo: Array[AttackStep] = []
## 技能冷却（秒）
@export var dash_cd := 3.5
@export var finish_cd := 5.0
@export var beam_cost := 100.0
@export var dash_len := 7.5
@export var dash_warn := 0.3

var index := 0
var state := "move"
var st_t := 0.0                 # 当前状态过了多久
var step_i := -1                # 当前连段（-1 没在攻击）
var _hit_set := {}              # 这一段已经打到的敌人
var _called := false            # 这一段已经弹过“N段!”
var _buf_action := ""
var _buf_t := 0.0
var _roll_dir := Vector3.ZERO
var _ghost_t := 0.0
var _phase := 0.0
var _move := Vector3.ZERO
var _pose := {}
var _pose_prev := {}
var _blend := 1.0
var _anim_t := 0.0
var _step_snd := 0.0
var _lunge_dir := Vector3.ZERO
var energy := 0.0
var max_energy := 100.0
var cd := {"dash": 0.0, "finish": 0.0}
var gourds := 3
var max_gourds := 3
var dmg_mult := 1.0
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var _combo_reset := 0.0
var hits_taken := 0           # 挨打次数（试炼“守”用）
var foot_ring: MeshInstance3D
var invincible := false          # 调试：不掉血
var dmg_total := 0.0             # 统计用：这一局一共挨了多少伤害
## 加成（apply_stats 从天赋、兵器、护甲、护符、心法算出来）
var crit_bonus := 0.0
var crit_mult := 1.8
var energy_mult := 1.0
var bleed_bonus := 0
var bleed_dmg := 1.0
var lifesteal := 0.0
var taken_mult := 1.0
var beam_mult := 1.0
var finish_mult := 1.0
var gourd_heal := 0.4
var revives := 0
var weapon_id := "sword"
var trail: BladeTrail
const BASE_HP := 120.0
const BASE_MOVE := 7.2
const BASE_DASH_CD := 3.5
const BASE_FINISH_CD := 5.0
const BASE_IFRAMES := 0.26


## 把一局的加成套到主角身上；fill_hp 时生命和药葫芦补满（开局用）
func apply_stats(st: Dictionary, wid: String, fill_hp: bool = false) -> void:
	var old_max := max_hp
	max_hp = BASE_HP + ArpgData.stat(st, "hp")
	if fill_hp:
		hp = max_hp
	else:
		hp = minf(hp + maxf(max_hp - old_max, 0.0), max_hp)
	var w := ArpgData.weapon(wid)
	if wid != weapon_id or combo.is_empty():
		weapon_id = wid
		combo = _weapon_combo(w)
		if rig != null:
			rig.set_weapon(String(w["model"]), float(w["len"]))
	dmg_mult = (1.0 + ArpgData.stat(st, "atk")) * float(w["dmg"])
	crit_bonus = ArpgData.stat(st, "crit")
	crit_mult = 1.8 + ArpgData.stat(st, "crit_dmg")
	energy_mult = 1.0 + ArpgData.stat(st, "energy")
	bleed_bonus = int(ArpgData.stat(st, "bleed"))
	bleed_dmg = 1.0 + ArpgData.stat(st, "bleed_dmg")
	lifesteal = ArpgData.stat(st, "lifesteal")
	taken_mult = maxf(0.3, 1.0 + ArpgData.stat(st, "dmg_taken"))
	beam_mult = 1.0 + ArpgData.stat(st, "beam")
	finish_mult = 1.0 + ArpgData.stat(st, "finish")
	gourd_heal = 0.4 + ArpgData.stat(st, "gourd_heal")
	move_speed = BASE_MOVE * (1.0 + ArpgData.stat(st, "move"))
	dash_cd = BASE_DASH_CD * maxf(0.3, 1.0 - ArpgData.stat(st, "dash_cd"))
	finish_cd = BASE_FINISH_CD * maxf(0.3, 1.0 - ArpgData.stat(st, "finish_cd"))
	roll_iframes = BASE_IFRAMES + ArpgData.stat(st, "iframes")
	var mg := 3 + int(ArpgData.stat(st, "gourds"))
	if fill_hp:
		gourds = mg
	else:
		gourds += maxi(mg - max_gourds, 0)
	max_gourds = mg
	if fill_hp:
		revives = int(ArpgData.stat(st, "revive"))


## 兵器决定连招：伤害倍率在 dmg_mult 里，这里改快慢和攻击范围
func _weapon_combo(w: Dictionary) -> Array[AttackStep]:
	var c := AttackStep.default_combo()
	var sp := float(w.get("speed", 1.0))
	var rc := float(w.get("reach", 1.0))
	for s: AttackStep in c:
		s.startup /= sp
		s.active /= sp
		s.recovery /= sp
		s.cancel_at /= sp
		s.reach *= rc
		s.slash_radius *= rc
		if bool(w.get("heavy", false)):
			s.heavy = true
			s.knock *= 1.3
	return c


func _ready() -> void:
	team = 0
	super._ready()
	ArpgInput.setup()
	if combo.is_empty():
		combo = AttackStep.default_combo()
	max_hp = 120.0
	hp = max_hp
	radius = 0.45
	_ready_body()


## 复活/重开时重置状态
func reset_for_run() -> void:
	alive = true
	state = "move"
	step_i = -1
	energy = 0.0
	bleed = 0
	knock = Vector3.ZERO
	for k: String in cd:
		cd[k] = 0.0
	visible = true


func clear_buffer() -> void:
	_buf_action = ""
	_buf_t = 0.0


func _ready_body() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	rig = VoxActor.new()
	add_child(rig)
	rig.setup("rogue", "sword", 34.0, Color(1, 1, 1), 1.0)
	rig.set_rim(Color(0.45, 0.95, 1.0), 0.6)
	# 兜帽和披风换成深青蓝（原模型是绿的），和青绿场景拉开
	rig.mat.set_shader_parameter("swap_green", true)
	rig.mat.set_shader_parameter("swap_color", Vector3(0.24, 0.42, 0.72))
	_pose = Poses.idle(0.0)
	add_to_group("heroes")
	_make_foot_ring()
	trail = BladeTrail.new()
	trail.actor = self
	trail.rig = rig
	add_child(trail)
	trail.set_colors(Color(1, 1, 1), Color(0.35, 0.8, 1.0))


func _make_foot_ring() -> void:
	foot_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	foot_ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/foot_ring.gdshader")
	foot_ring.material_override = m
	foot_ring.rotation.x = -PI / 2
	foot_ring.position.y = 0.04
	foot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foot_ring)
	foot_ring.top_level = true


func _a(name: String) -> String:
	return ArpgInput.act(index, name)


func _pressed(name: String) -> bool:
	return Input.is_action_just_pressed(_a(name))


func input_dir() -> Vector3:
	var v := Vector2(Input.get_action_strength(_a("right")) - Input.get_action_strength(_a("left")),
		Input.get_action_strength(_a("down")) - Input.get_action_strength(_a("up")))
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.2:
		return Vector3.ZERO
	var axes: Array = CamRig.I.ground_axes() if CamRig.I != null else [Vector3(0, 0, -1), Vector3(1, 0, 0)]
	var up: Vector3 = axes[0]
	var right: Vector3 = axes[1]
	return right * v.x - up * v.y


func gain_energy(v: float) -> void:
	energy = minf(energy + v * energy_mult, max_energy)
	energy_changed.emit()


func _physics_process(delta: float) -> void:
	var dt := tick_common(delta)
	for k: String in cd:
		cd[k] = maxf(float(cd[k]) - dt, 0.0)
	_update_ring()
	if not alive:
		return
	_read_buffer(delta)
	if dt <= 0.0:
		move_with_knock(Vector3.ZERO, 0.0)
		return
	st_t += dt
	_anim_t += dt
	_combo_reset = maxf(_combo_reset - dt, 0.0)
	match state:
		"move":
			_st_move(dt)
		"attack":
			_st_attack(dt)
		"roll":
			_st_roll(dt)
		"hurt":
			_st_hurt(dt)
		"dash_ready":
			_st_dash_ready(dt)
		"dash":
			_st_dash(dt)
		"beam":
			_st_beam(dt)
		"finish":
			_st_finish(dt)
		"heal":
			_st_heal(dt)
	_apply_pose(dt)


func _read_buffer(delta: float) -> void:
	for a: String in ["attack", "roll", "dash", "beam", "finish", "heal"]:
		if _pressed(a):
			_buf_action = a
			_buf_t = buffer_time
	if _buf_t > 0.0:
		_buf_t -= delta
		if _buf_t <= 0.0:
			_buf_action = ""


func _take_buffer(allowed: Array) -> String:
	if _buf_action != "" and _buf_action in allowed:
		var a := _buf_action
		_buf_action = ""
		_buf_t = 0.0
		return a
	return ""


func _set_state(s: String) -> void:
	state = s
	st_t = 0.0
	if trail != null:
		trail.active = s in ["attack", "finish", "dash"]
		if s == "finish":
			trail.set_colors(Color(1.0, 0.85, 0.8), Color(1.0, 0.15, 0.15))
			trail.life = 0.22
		elif s != "attack":
			trail.set_colors(Color(1, 1, 1), Color(0.35, 0.8, 1.0))
	_pose_prev = _pose
	_blend = 0.0


func _try_actions(allowed: Array) -> bool:
	var a := _take_buffer(allowed)
	match a:
		"attack":
			var nxt := 0
			if state == "attack" or (_combo_reset > 0.0 and step_i >= 0):
				nxt = (step_i + 1) % combo.size()
			_start_attack(nxt)
			return true
		"roll":
			_start_roll()
			return true
		"dash":
			if cd["dash"] <= 0.0:
				_start_dash()
				return true
		"beam":
			if energy >= beam_cost:
				_start_beam()
				return true
			Feel.I.callout(head_top(), "气力不足", Color(0.6, 0.8, 0.85), 0.7)
		"finish":
			if cd["finish"] <= 0.0:
				_start_finish()
				return true
		"heal":
			if gourds > 0 and hp < max_hp:
				_set_state("heal")
				return true
	return false


# ---------- 移动 ----------

func _leech(dmg: float) -> void:
	if lifesteal > 0.0 and alive:
		hp = minf(hp + dmg * lifesteal, max_hp)


func _st_move(dt: float) -> void:
	if _try_actions(["attack", "roll", "dash", "beam", "finish", "heal"]):
		return
	var d := input_dir()
	var want := d * move_speed
	_move = _move.move_toward(want, accel * dt)
	if d != Vector3.ZERO:
		face_to(facing.slerp(d, 1.0 - exp(-18.0 * dt)) if facing.dot(d) > -0.9 else d)
	move_with_knock(_move, dt)
	var sp := _move.length() / move_speed
	_phase += dt * (6.0 + 6.0 * sp) * (1.0 if sp > 0.05 else 0.0)
	if sp > 0.1:
		_target_pose(Poses.run(_phase, sp))
		_step_snd -= dt
		if _step_snd <= 0.0:
			_step_snd = 0.32
			Game.sfx("step", -14.0, 0.1)
	else:
		_target_pose(Poses.idle(_anim_t))
	if CamRig.I != null:
		CamRig.I.lead_dir = CamRig.I.lead_dir.lerp(_move / move_speed, 1.0 - exp(-3.0 * dt))


# ---------- 连招 ----------

func _start_attack(i: int) -> void:
	step_i = i
	_hit_set.clear()
	_called = false
	_set_state("attack")
	_blend = 0.4
	# 朝向：有方向键按方向键，没有就自动对准前方最近的敌人
	var d := input_dir()
	var tgt := _auto_target(d if d != Vector3.ZERO else facing, 5.5)
	if tgt != null:
		face_to(tgt.global_position - global_position)
	elif d != Vector3.ZERO:
		face_to(d)
	_lunge_dir = facing
	var s: AttackStep = combo[i]
	Game.sfx("slash_heavy" if s.heavy else "slash", -2.0, 0.1)
	# 拖尾：轻击青白、重击更亮更长、回旋斩最长
	trail.life = 0.3 if s.swing == "spin" else (0.2 if s.heavy else 0.15)
	trail.set_colors(Color(1, 1, 1), Color(0.45, 0.95, 1.0) if s.heavy else Color(0.35, 0.78, 1.0))
	_move = Vector3.ZERO


func _auto_target(dir: Vector3, rng: float) -> Actor:
	var best: Actor = null
	var best_s := 999.0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var to := a.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > rng:
			continue
		var ang := dir.angle_to(to) if dist > 0.01 else 0.0
		if ang > 1.2:
			continue
		var score := dist + ang * 2.0
		if score < best_s:
			best_s = score
			best = a
	return best


func _st_attack(dt: float) -> void:
	var s: AttackStep = combo[step_i]
	var t := st_t
	var su := clampf(t / s.startup, 0.0, 1.0)
	var ac := clampf((t - s.startup) / s.active, 0.0, 1.0) if t > s.startup else 0.0
	var rc := clampf((t - s.startup - s.active) / s.recovery, 0.0, 1.0) if t > s.startup + s.active else 0.0
	# 前冲：前摇到判定结束之间走完 lunge，前面贴着敌人就不再往前
	var lunge_v := Vector3.ZERO
	if t < s.startup + s.active:
		var near := _nearest_ahead(1.1)
		if not near:
			lunge_v = _lunge_dir * s.lunge / (s.startup + s.active)
	move_with_knock(lunge_v, dt)
	_target_pose(Poses.swing(s.swing, su, ac, rc))
	# 判定开始的那一帧放刀光
	if t >= s.startup and t - dt < s.startup:
		_spawn_slash(s)
		if s.heavy:
			CamRig.I.punch_zoom(0.25, 0.08)
	if t >= s.startup and t <= s.startup + s.active + dt:
		_do_hits(s)
	# 取消：翻滚随时可以；过了 cancel_at 可以接下一段或放技能
	if _take_buffer(["roll"]) == "roll":
		_start_roll()
		return
	if t >= s.cancel_at:
		if _try_actions(["attack", "dash", "beam", "finish"]):
			return
	if t >= s.total():
		step_i = step_i if step_i < combo.size() - 1 else -1
		_combo_reset = 0.35
		_set_state("move")
		_blend = 0.3


func _nearest_ahead(dist: float) -> bool:
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var to := a.global_position - global_position
		to.y = 0
		if to.length() < dist + a.radius and to.normalized().dot(_lunge_dir) > 0.3:
			return true
	return false


func _spawn_slash(s: AttackStep) -> void:
	var base := Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 0.95, 0))
	var core := Color(1.0, 1.0, 1.0)
	var edge := Color(0.35, 0.78, 1.0)
	match s.swing:
		"h_rl":
			var xf := base * Transform3D(Basis(Vector3(0, 0, 1), s.slash_tilt), Vector3.ZERO)
			Vfx.I.slash(xf, s.slash_radius, deg_to_rad(110), deg_to_rad(-110), 0.2, core, edge, 3.0)
		"h_lr":
			var xf := base * Transform3D(Basis(Vector3(0, 0, 1), s.slash_tilt), Vector3.ZERO)
			Vfx.I.slash(xf, s.slash_radius, deg_to_rad(-110), deg_to_rad(110), 0.2, core, edge, 3.0)
		"v_down":
			# 竖着的刀光：扇环平面立起来（绕前后轴转 90°）
			var xf := base * Transform3D(Basis(Vector3(0, 0, 1), PI / 2) * Basis(Vector3.UP, 0.0), Vector3(0.0, 0.2, 0))
			Vfx.I.slash(xf, s.slash_radius, deg_to_rad(-60), deg_to_rad(110), 0.22, core, Color(0.4, 0.9, 1.0), 3.6)
			Vfx.I.shock_ring(global_position + facing * 1.6, Color(0.5, 0.9, 1.0), 0.3, 2.2, 0.25)
		"spin":
			var xf := base * Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0))
			Vfx.I.slash(xf, s.slash_radius, deg_to_rad(90), deg_to_rad(90) - TAU, 0.3, core, Color(0.3, 0.75, 1.0), 3.4, 0.55)
			Vfx.I.slash(xf, s.slash_radius * 0.8, deg_to_rad(-90), deg_to_rad(-90) - TAU * 0.8, 0.28, core, Color(0.6, 1.0, 1.0), 2.0, 0.6)


func _do_hits(s: AttackStep) -> void:
	var landed := false
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _hit_set.has(a):
			continue
		var to := a.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > s.reach + a.radius:
			continue
		if s.arc < 359.0 and dist > 0.3:
			var ang := rad_to_deg(facing.angle_to(to))
			if ang > s.arc * 0.5:
				continue
		_hit_set[a] = true
		var crit := randf() < s.crit_chance + crit_bonus
		var dmg := s.damage * dmg_mult * (crit_mult if crit else 1.0) * randf_range(0.92, 1.08)
		var info := HitInfo.make(self, a, dmg, HitInfo.Weight.HEAVY if s.heavy else HitInfo.Weight.LIGHT)
		info.crit = crit
		info.knock = s.knock
		info.bleed = s.bleed + (bleed_bonus if s.bleed > 0 else 0)
		info.bleed_mult = bleed_dmg
		info.stun = 0.35 if s.heavy else 0.25
		info.gain = 6.0 if not s.heavy else 9.0
		if Feel.I.on_hit(info):
			landed = true
			_leech(info.damage)
	if landed and not _called:
		_called = true
		Feel.I.callout(head_top() + Vector3(0.6, 0.3, 0), s.label, Color(0.75, 1.0, 1.0), 0.9 if step_i < 3 else 1.2)


# ---------- 翻滚 ----------

func _start_roll() -> void:
	var d := input_dir()
	if d == Vector3.ZERO:
		d = facing
	_roll_dir = d.normalized()
	face_to(_roll_dir)
	_set_state("roll")
	_blend = 0.6
	iframes = roll_iframes
	_ghost_t = 0.0
	step_i = -1
	Game.sfx("dodge", -3.0)
	Vfx.I.dust(global_position, 0.8, Color(0.5, 0.6, 0.6, 0.35))


func _st_roll(dt: float) -> void:
	var k := st_t / roll_time
	var sp := roll_dist / roll_time * (1.3 - 0.6 * k)
	move_with_knock(_roll_dir * sp, dt)
	_target_pose(Poses.roll(k))
	_ghost_t -= dt
	if _ghost_t <= 0.0 and k < 0.8:
		_ghost_t = 0.05
		Vfx.I.ghost(rig, Color(0.3, 0.85, 1.0), 0.28)
	if k > 0.7 and _try_actions(["attack", "dash"]):
		return
	if k >= 1.0:
		_set_state("move")
		_move = _roll_dir * move_speed * 0.7
		_blend = 0.5


# ---------- 受击 ----------

func take_hit(info: HitInfo) -> bool:
	info.damage *= taken_mult
	if invincible:
		info.damage = 0.0
	if state == "dash":
		return false
	var ok := super.take_hit(info)
	if ok:
		dmg_total += info.damage
		hits_taken += 1
	if ok and alive:
		Feel.I.hurt_pulse(0.7)
		Game.sfx("hurt", -2.0)
		if info.weight >= 1 or state in ["move", "heal"]:
			step_i = -1
			_set_state("hurt")
			_blend = 0.8
		iframes = 0.35
	return ok


func _st_hurt(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.hurt(st_t / 0.32))
	if st_t > 0.18 and _take_buffer(["roll"]) == "roll":
		_start_roll()
		return
	if st_t >= 0.32:
		_set_state("move")


func die(impulse: Vector3) -> void:
	if revives > 0:
		revives -= 1
		hp = max_hp * 0.5
		iframes = 2.0
		Feel.I.callout(head_top(), "不死身!", Color(1.0, 0.85, 0.4), 1.4)
		Feel.I.screen_flash(Color(1.0, 0.85, 0.4, 0.5), 2.0)
		Vfx.I.shock_ring(global_position, Color(1.0, 0.8, 0.4), 0.5, 6.0, 0.5)
		return
	super.die(impulse)
	state = "dead"
	Game.sfx("death")
	rig.shatter(get_parent(), impulse)
	Vfx.I.impact_flash(chest(), 3.0, Color(1.0, 0.4, 0.4))
	foot_ring.visible = false


# ---------- 突进斩 ----------

func _start_dash() -> void:
	var d := input_dir()
	var tgt := _auto_target(d if d != Vector3.ZERO else facing, dash_len + 1.0)
	if tgt != null and d == Vector3.ZERO:
		d = tgt.global_position - global_position
	if d == Vector3.ZERO:
		d = facing
	d.y = 0
	face_to(d)
	_dash_from = global_position
	# 路径碰到墙就提前停
	var len := dash_len
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 0.6, 0) + facing * dash_len, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		len = maxf((hit["position"] as Vector3 - (global_position + Vector3(0, 0.6, 0))).length() - radius - 0.2, 0.5)
	_dash_to = global_position + facing * len
	_set_state("dash_ready")
	_blend = 0.5
	cd["dash"] = dash_cd
	Vfx.I.telegraph_rect(_dash_from, _dash_to, 1.6, Color(0.3, 0.95, 1.0, 0.55), dash_warn + 0.05)
	Game.sfx("art", -4.0)


func _st_dash_ready(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.dash_ready(st_t / dash_warn))
	if st_t >= dash_warn:
		_do_dash()


func _do_dash() -> void:
	# 瞬移：路上每隔一段留残影，路径上所有敌人挨刀
	var steps := 7
	for i in range(steps):
		var p := _dash_from.lerp(_dash_to, float(i) / steps)
		global_position = p
		_apply_pose(0.0)
		Vfx.I.ghost(rig, Color(0.35, 0.95, 1.0), 0.18 + 0.03 * i)
	global_position = _dash_to
	var seg := _dash_to - _dash_from
	var n := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var t := clampf((a.global_position - _dash_from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		var closest := _dash_from + seg * t
		if (a.global_position - closest).length() <= 0.8 + a.radius:
			var info := HitInfo.make(self, a, 22.0 * dmg_mult * randf_range(0.95, 1.1), HitInfo.Weight.HEAVY)
			info.dir = (a.global_position - closest).normalized() if (a.global_position - closest).length() > 0.1 else facing
			info.knock = 7.0
			info.bleed = 2 + bleed_bonus
			info.bleed_mult = bleed_dmg
			info.gain = 8.0
			info.crit = randf() < 0.2
			info.attacker = null    # 瞬移后主角不停顿，只让敌人停
			if Feel.I.on_hit(info):
				gain_energy(8.0)
				_leech(info.damage)
			n += 1
	Game.sfx("slash_heavy", 0.0)
	var base := Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 0.9, 0))
	Vfx.I.slash(base, 2.6, deg_to_rad(-130), deg_to_rad(110), 0.22, Color(1, 1, 1), Color(0.3, 0.95, 1.0), 3.5)
	Vfx.I.dust(global_position, 1.2, Color(0.5, 0.7, 0.7, 0.4))
	CamRig.I.shake(1 if n > 0 else 0)
	# 居合：路径上留一道横贯的斩线和一串地面刀痕，砍中了就慢一下
	var mid := (_dash_from + _dash_to) * 0.5 + Vector3(0, 0.9, 0)
	Vfx.I.cut_line(mid, seg, seg.length() + 2.5, Color(1, 1, 1), 0.38, 0.32, Color(0.3, 0.95, 1.0))
	var marks := int(seg.length() / 1.8)
	for i in range(marks):
		Vfx.I.scar(_dash_from.lerp(_dash_to, (i + 0.5) / marks), seg, 1.3, 1.2)
	CamRig.I.kick(facing, 0.22)
	if n > 0:
		Feel.I.slowmo(0.35, 0.22)
		Feel.I.callout(head_top() + Vector3(0.6, 0.3, 0), "突进斩!", Color(0.55, 1.0, 1.0), 1.1)
	_set_state("dash")
	_blend = 1.0


func _st_dash(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.swing("h_rl", 1.0, 1.0, clampf(st_t / 0.3, 0, 1)))
	if st_t > 0.12 and _try_actions(["attack", "roll", "finish", "beam"]):
		return
	if st_t >= 0.3:
		_set_state("move")


# ---------- 光束斩 ----------

func _start_beam() -> void:
	energy = 0.0
	energy_changed.emit()
	var tgt := _auto_target(input_dir() if input_dir() != Vector3.ZERO else facing, 14.0)
	if tgt != null:
		face_to(tgt.global_position - global_position)
	_set_state("beam")
	_blend = 0.5
	iframes = 1.0
	Vfx.I.sheet("charge-up", chest() - Vector3(0, 0.6, 0) + facing * 0.4, 2.0, Color(0.8, 1.0, 1.0), 2.0, false, 0.0, 2.2)
	CamRig.I.punch_zoom(0.6, 0.55)
	Game.sfx("art", 0.0)


func _st_beam(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	var dur := 0.75
	var k := st_t / dur
	_target_pose(Poses.beam_cast(k))
	if k >= 0.6 and (st_t - dt) / dur < 0.6:
		_fire_beam()
	if k >= 1.0:
		_set_state("move")


func _fire_beam() -> void:
	# 斜贯屏幕：从主角身后斜着穿过前方，长 22 米
	var dir := (facing + Vector3(0.0, 0.0, 0.0)).normalized()
	var from := global_position - dir * 3.0 + Vector3(0, 1.0, 0)
	var to := global_position + dir * 20.0 + Vector3(0, 0.3, 0)
	Feel.I.pause_world(0.15)
	Feel.I.screen_flash(Color(0.85, 1.0, 1.0, 0.75), 3.0)
	Vfx.I.beam(from, to, 2.4, 0.6)
	Vfx.I.impact_flash(global_position + Vector3(0, 1, 0), 4.0, Color(0.6, 1, 1))
	CamRig.I.shake(2, 1.2)
	CamRig.I.kick(-dir, 0.35, 0.02)       # 后坐：镜头往身后一顿
	Game.sfx("boom", 0.0)
	# 地上烧出一道焦痕，尽头炸开一圈
	var gp := Vector3(global_position.x, 0, global_position.z)
	for i in range(0, 9 if Vfx.I.lod > 0 else 4):
		var q := gp + dir * (1.5 + i * (2.2 if Vfx.I.lod > 0 else 4.4))
		Vfx.I.ground(q, "scorch_01", Color(0.03, 0.06, 0.08, 0.6), 2.0, 2.4, 1.8, false)
		Vfx.I.ground(q, "lm_circle_a", Color(0.4, 0.95, 1.0, 0.7), 1.2, 3.0, 0.45, true)
	Vfx.I.shock_ring(gp + dir * 18.0, Color(0.5, 1.0, 1.0), 0.5, 5.0, 0.45)
	Vfx.I.streaks(global_position + Vector3(0, 1, 0) + dir * 2.0, dir, Color(0.6, 1.0, 1.0), 8, 4.0, 0.3, 0.25, 0.25)
	var seg := to - from
	seg.y = 0
	var f2 := Vector3(from.x, 0, from.z)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var t := clampf((a.global_position - f2).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest := f2 + seg * t
		if (a.global_position - closest).length() <= 1.5 + a.radius:
			var info := HitInfo.make(self, a, 60.0 * dmg_mult * beam_mult * randf_range(0.95, 1.1), HitInfo.Weight.ULT)
			info.dir = dir
			info.knock = 12.0
			info.bleed = 1
			info.crit = true
			info.attacker = null
			Feel.I.on_hit(info)
	Feel.I.callout(head_top() + Vector3(0.6, 0.5, 0), "光束斩!", Color(0.85, 1.0, 1.0), 1.4)


# ---------- 终结技 ----------

func _start_finish() -> void:
	var any := false
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a != null and a.alive and a.bleed > 0 and a.global_position.distance_to(global_position) < 7.5:
			any = true
	if not any:
		Feel.I.callout(head_top(), "没有出血的敌人", Color(0.85, 0.6, 0.6), 0.7)
		return
	cd["finish"] = finish_cd
	_set_state("finish")
	_blend = 0.5
	iframes = 0.4


func _st_finish(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	var k := st_t / 0.45
	_target_pose(Poses.swing("v_down", clampf(k / 0.5, 0, 1), clampf((k - 0.5) / 0.2, 0, 1), clampf((k - 0.7) / 0.3, 0, 1)))
	if k >= 0.6 and (st_t - dt) / 0.45 < 0.6:
		_detonate()
	if k >= 1.0:
		_set_state("move")


func _detonate() -> void:
	var n := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or a.bleed <= 0:
			continue
		if a.global_position.distance_to(global_position) > 7.5:
			continue
		var stacks := a.bleed
		a.bleed = 0
		var info := HitInfo.make(self, a, (14.0 + 16.0 * stacks) * dmg_mult * finish_mult, HitInfo.Weight.ULT)
		info.crit = stacks >= 3
		info.knock = 8.0
		info.attacker = null
		info.hitstop = 0.12
		Vfx.I.explosion(a.chest(), 0.7 + 0.15 * stacks)
		Vfx.I.cut_line(a.chest(), Vector3(randf_range(-1, 1), 1.2, randf_range(-1, 1)), 3.5 + 0.4 * stacks, Color(1, 0.9, 0.9), 0.3, 0.3, Color(1.0, 0.1, 0.1))
		Vfx.I.streaks(a.chest(), Vector3.UP, Color(1.0, 0.25, 0.2), 6, 2.2, 0.25, PI, 0.18)
		Vfx.I.sheet("dark-explosion", a.global_position, 4.2 + 0.35 * stacks, Color(1, 1, 1), 1.8, false, 0.0, 1.6)
		Feel.I.on_hit(info)
		n += 1
	CamRig.I.shake(2, 1.3)
	CamRig.I.punch_zoom(0.5, 0.3)
	Feel.I.screen_flash(Color(0.9, 0.1, 0.1, 0.35), 3.0)
	if n > 0:
		Feel.I.slowmo(0.3, 0.35)
	Game.sfx("execute", 0.0)
	Feel.I.callout(head_top() + Vector3(0.6, 0.5, 0), "血爆 ×%d" % n, Color(1.0, 0.35, 0.35), 1.3)


# ---------- 药葫芦 ----------

func _st_heal(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.cast(clampf(st_t / 0.3, 0, 1), st_t))
	if st_t >= 0.5 and st_t - dt < 0.5:
		gourds -= 1
		hp = minf(hp + max_hp * gourd_heal, max_hp)
		Game.sfx("drink", -2.0)
		Vfx.I.pop(chest(), "magic_03", Color(0.4, 1.0, 0.6), 0.5, 2.5, 0.5)
		Feel.I.number(head_top(), "+%d" % int(max_hp * gourd_heal), Color(0.5, 1.0, 0.6), 1.0)
	if _take_buffer(["roll"]) == "roll":
		_start_roll()
		return
	if st_t >= 0.7:
		_set_state("move")


# ---------- 姿势 ----------

func _target_pose(p: Dictionary) -> void:
	_pose = p


func _apply_pose(dt: float) -> void:
	_blend = minf(_blend + dt * 10.0, 1.0)
	var p := _pose
	if _blend < 1.0 and not _pose_prev.is_empty():
		p = Poses.blend(_pose_prev, _pose, Poses.ease_in_out(_blend))
	rig.apply(p)


func _update_ring() -> void:
	if foot_ring == null:
		return
	foot_ring.global_position = global_position + Vector3(0, 0.04, 0)
	var m: ShaderMaterial = foot_ring.material_override
	m.set_shader_parameter("dash", 1.0 - float(cd["dash"]) / dash_cd)
	m.set_shader_parameter("finish", 1.0 - float(cd["finish"]) / finish_cd)
	m.set_shader_parameter("energy", energy / max_energy)
