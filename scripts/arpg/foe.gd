class_name Foe
extends Actor
## 敌人：状态机 巡逻 → 发现 → 追击 → 攻击前摇（红色预警）→ 攻击 → 硬直，挨打会僵直（重甲要先打掉韧性）。
## 攻击令牌：同时最多 MAX_TOKENS 个敌人在出招，其余的绕着主角游走，不会一拥而上。
## 种类在 TYPES 里：腐骨虫（小型快攻）、骷髅兵（近战）、赤甲武士（重攻击、跳劈落地扬尘）、幽魂术士（远程法阵）、头目。

signal dropped(pos: Vector3, coins: int, jade: int)

const MAX_TOKENS := 2
static var tokens := 0

const TYPES := {
	"crawler": {"name": "腐骨虫", "model": "skel_minion", "weapon": "", "wlen": 0.0, "tint": Color(0.85, 0.95, 0.8), "k": 0.72,
		"hp": 26.0, "speed": 5.4, "detect": 13.0, "range": 2.2, "dmg": 7.0, "windup": 0.42, "attack": "lunge", "poise": 0.0, "coins": 2},
	"skeleton": {"name": "骷髅兵", "model": "skel_warrior", "weapon": "skel_blade", "wlen": 30.0, "tint": Color(0.95, 0.95, 0.9), "k": 1.0,
		"hp": 55.0, "speed": 3.8, "detect": 12.0, "range": 2.1, "dmg": 11.0, "windup": 0.55, "attack": "slash", "poise": 0.0, "coins": 4},
	"samurai": {"name": "赤甲武士", "model": "knight", "weapon": "axe2", "wlen": 44.0, "tint": Color(1.25, 0.5, 0.45), "k": 1.25,
		"hp": 190.0, "speed": 3.2, "detect": 14.0, "range": 2.8, "dmg": 22.0, "windup": 0.75, "attack": "heavy", "poise": 45.0, "coins": 12},
	"mage": {"name": "幽魂术士", "model": "skel_mage", "weapon": "skel_staff", "wlen": 34.0, "tint": Color(0.85, 0.7, 1.15), "k": 1.0,
		"hp": 42.0, "speed": 3.4, "detect": 16.0, "range": 11.0, "dmg": 14.0, "windup": 0.7, "attack": "rune", "poise": 0.0, "coins": 6, "keep": 7.5},
	"boss": {"name": "夜樱剑鬼", "model": "barbarian", "weapon": "sword2", "wlen": 52.0, "tint": Color(0.78, 0.72, 0.9), "k": 1.55,
		"hp": 900.0, "speed": 3.6, "detect": 40.0, "range": 3.2, "dmg": 24.0, "windup": 0.6, "attack": "boss", "poise": 120.0, "coins": 60, "boss": true},
}

var kind := "skeleton"
var data: Dictionary
var state := "spawn"
var st_t := 0.0
var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _has_token := false
var _cool := 0.0
var _pose := {}
var _pose_prev := {}
var _blend := 1.0
var _phase := 0.0
var _anim_t := 0.0
var poise := 0.0
var max_poise := 0.0
var _atk := ""
var _atk_dir := Vector3.FORWARD
var _atk_target := Vector3.ZERO
var _leap_from := Vector3.ZERO
var _did_hit := false
var _strafe := 1.0
var _boss_phase := 0
var _combo_n := 0
var target: Hero
var is_boss := false
var dmg_scale := 1.0


func setup_kind(k: String, hp_scale: float = 1.0, dmg_mult: float = 1.0) -> void:
	kind = k
	data = TYPES[k]
	max_hp = float(data["hp"]) * hp_scale
	hp = max_hp
	dmg_scale = dmg_mult
	max_poise = float(data["poise"])
	poise = max_poise
	is_boss = bool(data.get("boss", false))
	display_name = String(data["name"])


func _ready() -> void:
	team = 1
	super._ready()
	if data.is_empty():
		setup_kind(kind)
	var k := float(data["k"])
	radius = 0.42 * k
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = 1.7 * k
	cs.shape = cap
	cs.position.y = 0.85 * k
	add_child(cs)
	rig = VoxActor.new()
	add_child(rig)
	rig.setup(String(data["model"]), String(data["weapon"]), float(data["wlen"]), data["tint"], k)
	rig.set_rim(Color(0.6, 0.85, 0.9) if not is_boss else Color(1.0, 0.6, 0.8), 0.3)
	_home = global_position
	_pose = Poses.idle(0.0)
	add_to_group("foes")
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_cool = randf_range(0.3, 1.2)
	# 出场：从地里冒出来
	rig.scale = Vector3(1, 0.01, 1)
	Vfx.I.dust(global_position, 1.0 * k, Color(0.35, 0.55, 0.55, 0.5))
	Vfx.I.ground(global_position, "magic_01", Color(0.4, 0.9, 1.0, 0.8) if not is_boss else Color(1.0, 0.4, 0.6, 0.9), 0.5, 2.5 * k, 0.6)


func _physics_process(delta: float) -> void:
	var dt := tick_common(delta)
	if not alive:
		return
	if dt <= 0.0:
		move_with_knock(Vector3.ZERO, 0.0)
		return
	st_t += dt
	_anim_t += dt
	_cool = maxf(_cool - dt, 0.0)
	if max_poise > 0.0 and state != "stagger":
		poise = minf(poise + max_poise * 0.12 * dt, max_poise)
	target = _pick_target()
	match state:
		"spawn":
			rig.scale = Vector3(1, minf(st_t / 0.45, 1.0), 1)
			move_with_knock(Vector3.ZERO, dt)
			_pose = Poses.idle(_anim_t)
			if st_t >= 0.45:
				rig.scale = Vector3.ONE
				_set_state("patrol")
		"patrol":
			_st_patrol(dt)
		"chase":
			_st_chase(dt)
		"windup":
			_st_windup(dt)
		"attack":
			_st_attack(dt)
		"recover":
			move_with_knock(Vector3.ZERO, dt)
			if st_t >= _recover_time():
				_release()
				_set_state("chase")
		"stagger":
			move_with_knock(Vector3.ZERO, dt)
			_pose = Poses.hurt(st_t / maxf(hit_stun, 0.2))
			if st_t >= maxf(hit_stun, 0.2):
				_set_state("chase")
	_apply_pose(dt)


func _pick_target() -> Hero:
	var best: Hero = null
	var bd := 1e9
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = hh
	return best


func _set_state(s: String) -> void:
	state = s
	st_t = 0.0
	_pose_prev = _pose
	_blend = 0.0


func _release() -> void:
	if _has_token:
		_has_token = false
		tokens = maxi(tokens - 1, 0)
	rig.set_glow(Color(0, 0, 0))


func _recover_time() -> float:
	match _atk:
		"heavy", "leap":
			return 0.9
		"boss_combo", "boss_leap", "boss_wave":
			return 0.6 if _boss_phase == 0 else 0.4
		"rune":
			return 0.5
	return 0.55


func _dist_to_target() -> float:
	if target == null:
		return 1e9
	return Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for f: Node in get_tree().get_nodes_in_group("foes"):
		if f == self:
			continue
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := global_position - a.global_position
		d.y = 0
		var l := d.length()
		var r := radius + a.radius + 0.5
		if l < r and l > 0.001:
			push += d / l * (r - l) / r
	return push


func _walk(v: Vector3, dt: float) -> void:
	var sp := v.length() / maxf(float(data["speed"]), 0.1)
	_phase += dt * (5.0 + 6.0 * sp)
	if v.length() > 0.2:
		face_to(facing.slerp(v.normalized(), 1.0 - exp(-10.0 * dt)) if facing.dot(v.normalized()) > -0.9 else v)
		_pose = Poses.run(_phase, clampf(sp, 0.0, 1.0) * 0.85)
	else:
		_pose = Poses.idle(_anim_t)
	move_with_knock(v + _separation() * 3.0, dt)


func _st_patrol(dt: float) -> void:
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.0, 2.5)
		var a := randf() * TAU
		_wander = (_home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 3.0) - global_position)
		_wander.y = 0
		if randf() < 0.4:
			_wander = Vector3.ZERO
	var v := Vector3.ZERO
	if _wander.length() > 0.5:
		v = _wander.normalized() * float(data["speed"]) * 0.35
		_wander -= v * dt
	_walk(v, dt)
	if target != null and _dist_to_target() < float(data["detect"]):
		_set_state("chase")
		# 发现主角：头上冒个“!”
		Feel.I.callout(head_top(), "!", Color(1.0, 0.35, 0.3), 0.9)


func _st_chase(dt: float) -> void:
	if target == null:
		_walk(Vector3.ZERO, dt)
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else facing
	var speed := float(data["speed"])
	var rng := float(data["range"])
	var v := Vector3.ZERO
	if kind == "mage":
		var keep := float(data.get("keep", 7.0))
		if dist < keep - 1.5:
			v = -dir * speed
		elif dist > keep + 2.0:
			v = dir * speed
		else:
			v = dir.cross(Vector3.UP) * _strafe * speed * 0.5
		if _cool <= 0.0 and dist < rng and _get_token():
			_begin_attack("rune")
			return
	else:
		if dist > rng * 0.85:
			# 没拿到令牌的敌人在外圈绕着走
			var circling := tokens >= MAX_TOKENS and not _has_token and dist < rng + 3.5
			if circling:
				v = (dir.cross(Vector3.UP) * _strafe * 0.8 + dir * 0.1) * speed * 0.6
			else:
				v = dir * speed
		elif _cool <= 0.0 and _get_token():
			_begin_attack(_choose_attack(dist))
			return
		else:
			v = dir.cross(Vector3.UP) * _strafe * speed * 0.35
		if kind == "samurai" and _cool <= 0.0 and dist > 4.0 and dist < 9.0 and randf() < dt * 0.8 and _get_token():
			_begin_attack("leap")
			return
		if is_boss and _cool <= 0.0 and dist > 5.0 and randf() < dt * 1.2 and _get_token():
			_begin_attack("boss_leap" if randf() < 0.5 else "boss_wave")
			return
	_walk(v, dt)
	face_to(facing.slerp(dir, 1.0 - exp(-8.0 * dt)))


func _get_token() -> bool:
	if _has_token:
		return true
	if is_boss:
		_has_token = true
		tokens += 1
		return true
	if tokens < MAX_TOKENS:
		tokens += 1
		_has_token = true
		return true
	return false


func _choose_attack(_dist: float) -> String:
	match kind:
		"crawler":
			return "lunge"
		"samurai":
			return "heavy"
		"boss":
			return "boss_combo"
	return "slash"


func _windup_time() -> float:
	var w := float(data["windup"])
	match _atk:
		"leap", "boss_leap":
			return 0.35
		"boss_combo":
			return 0.55 if _boss_phase == 0 else 0.4
		"boss_wave":
			return 0.7
	return w


func _begin_attack(kind_: String) -> void:
	_atk = kind_
	_did_hit = false
	_combo_n = 0
	_set_state("windup")
	_blend = 0.3
	if target != null:
		_atk_dir = (target.global_position - global_position)
		_atk_dir.y = 0
		_atk_dir = _atk_dir.normalized() if _atk_dir.length() > 0.01 else facing
		_atk_target = target.global_position
		face_to(_atk_dir)
	var wt := _windup_time()
	var red := Color(1.0, 0.15, 0.1, 0.55)
	match _atk:
		"slash", "boss_combo":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * (float(data["range"]) + 0.6), 2.6 * float(data["k"]), red, wt)
		"heavy":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.6, 2.2, red, wt)
		"lunge":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.2, 1.0, red, wt)
		"rune":
			Vfx.I.telegraph_circle(_atk_target, 1.7, Color(0.85, 0.25, 1.0, 0.6), wt + 0.55)
		"leap", "boss_leap":
			_atk_target = target.global_position + target.velocity * 0.25 if target != null else global_position
			Vfx.I.telegraph_circle(_atk_target, 2.4 if _atk == "leap" else 3.2, red, wt + 0.65)
		"boss_wave":
			for i in range(5):
				var a := -0.6 + 0.3 * i
				var d := _atk_dir.rotated(Vector3.UP, a)
				Vfx.I.telegraph_rect(global_position, global_position + d * 12.0, 1.1, red, wt)
	Game.sfx("danger", -8.0)


func _st_windup(dt: float) -> void:
	var wt := _windup_time()
	var k := clampf(st_t / wt, 0.0, 1.0)
	move_with_knock(Vector3.ZERO, dt)
	# 红色预警：身上越来越红地闪
	var pulse := 0.5 + 0.5 * sin(st_t * 28.0)
	rig.set_glow(Color(1.0, 0.1, 0.05) * (0.25 + 0.6 * k) * pulse)
	match _atk:
		"rune":
			_pose = Poses.cast(k, _anim_t)
		"leap", "boss_leap":
			_pose = Poses.dash_ready(k)
		"lunge":
			_pose = Poses.dash_ready(k)
		"heavy", "boss_wave":
			_pose = Poses.windup("enemy_v", k, st_t)
		_:
			_pose = Poses.windup("enemy_h", k, st_t)
	if st_t >= wt:
		rig.set_glow(Color(0, 0, 0))
		_leap_from = global_position
		_set_state("attack")
		_blend = 1.0
		if _atk in ["slash", "heavy", "boss_combo", "lunge"]:
			Game.sfx("slash_heavy" if _atk == "heavy" else "slash", -4.0, 0.1)


func _st_attack(dt: float) -> void:
	match _atk:
		"slash", "boss_combo":
			var dur := 0.32
			var k := st_t / dur
			_pose = Poses.swing("enemy_h" if _combo_n % 2 == 0 else "h_lr", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(_atk_dir * (3.0 if k < 0.4 else 0.0), dt)
			if not _did_hit and k >= 0.25:
				_did_hit = true
				var base := Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 0.9 * float(data["k"]), 0))
				var a0 := deg_to_rad(110) if _combo_n % 2 == 0 else deg_to_rad(-110)
				Vfx.I.slash(base, float(data["range"]) * 0.95, a0, -a0, 0.2, Color(1.0, 0.85, 0.8), Color(1.0, 0.2, 0.15), 2.2)
				_melee_hit(float(data["range"]) + 0.3, 130.0, float(data["dmg"]), HitInfo.Weight.LIGHT if not is_boss else HitInfo.Weight.HEAVY)
			if k >= 1.0:
				if is_boss and _combo_n < (1 if _boss_phase == 0 else 2):
					_combo_n += 1
					_did_hit = false
					st_t = 0.0
					if target != null:
						_atk_dir = (target.global_position - global_position)
						_atk_dir.y = 0
						_atk_dir = _atk_dir.normalized()
						face_to(_atk_dir)
					return
				_end_attack()
		"heavy":
			var dur := 0.45
			var k := st_t / dur
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.35, 0, 1), clampf((k - 0.35) / 0.65, 0, 1))
			move_with_knock(_atk_dir * (4.0 if k < 0.35 else 0.0), dt)
			if not _did_hit and k >= 0.3:
				_did_hit = true
				var p := global_position + _atk_dir * 2.4
				Vfx.I.dust(p, 2.0)
				Vfx.I.shock_ring(p, Color(1.0, 0.5, 0.3), 0.5, 3.5, 0.3)
				Vfx.I.chips(p, Vector3.UP, Color(0.35, 0.33, 0.3), 12, 7.0, 0.12)
				CamRig.I.shake(1)
				Game.sfx("boom", -6.0)
				_area_hit(p, 1.9, float(data["dmg"]), HitInfo.Weight.HEAVY)
			if k >= 1.0:
				_end_attack()
		"lunge":
			var dur := 0.3
			var k := st_t / dur
			_pose = Poses.roll(k * 0.5)
			move_with_knock(_atk_dir * (11.0 * (1.0 - k)), dt)
			if not _did_hit and target != null and target.global_position.distance_to(global_position) < radius + target.radius + 0.6:
				_did_hit = true
				_hit_target(target, float(data["dmg"]), HitInfo.Weight.LIGHT)
			if k >= 1.0:
				_end_attack()
		"rune":
			var k := st_t / 0.55
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 1.0:
				_did_hit = true
				Vfx.I.pop(_atk_target + Vector3(0, 0.6, 0), "magic_05", Color(0.8, 0.3, 1.0), 1.0, 4.0, 0.35, true, 0.0, 3.0)
				Vfx.I.pop(_atk_target + Vector3(0, 0.6, 0), "twirl_01", Color(0.9, 0.5, 1.0), 0.6, 3.0, 0.3)
				Vfx.I.shock_ring(_atk_target, Color(0.8, 0.3, 1.0), 0.4, 3.6, 0.3)
				Game.sfx("flame", -4.0)
				_area_hit(_atk_target, 1.7, float(data["dmg"]), HitInfo.Weight.LIGHT)
				_end_attack()
		"leap", "boss_leap":
			var dur := 0.65
			var k := clampf(st_t / dur, 0.0, 1.0)
			var p := _leap_from.lerp(_atk_target, Poses.ease_in_out(k))
			global_position = Vector3(p.x, 0, p.z)
			rig.position.y = sin(k * PI) * (3.2 if _atk == "leap" else 4.5)
			_pose = Poses.leap(k)
			if k >= 1.0 and not _did_hit:
				_did_hit = true
				rig.position.y = 0
				var r := 2.4 if _atk == "leap" else 3.2
				Vfx.I.dust(global_position, r * 1.2, Color(0.55, 0.55, 0.5, 0.6))
				Vfx.I.shock_ring(global_position, Color(1.0, 0.45, 0.25), 0.5, r * 2.0, 0.35)
				Vfx.I.chips(global_position, Vector3.UP, Color(0.35, 0.33, 0.3), 18, 8.0, 0.13)
				Vfx.I.ground(global_position, "scorch_01", Color(0.05, 0.04, 0.04, 0.7), r * 1.6, r * 1.8, 1.5, false)
				CamRig.I.shake(2)
				Game.sfx("boom", -2.0)
				_area_hit(global_position, r, float(data["dmg"]) * 1.2, HitInfo.Weight.HEAVY)
			if st_t >= dur + 0.15:
				_end_attack()
		"boss_wave":
			var k := st_t / 0.4
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.35:
				_did_hit = true
				for i in range(5):
					var a := -0.6 + 0.3 * i
					var d := _atk_dir.rotated(Vector3.UP, a)
					_spawn_wave(d)
				CamRig.I.shake(1)
				Game.sfx("boom", -4.0)
			if k >= 1.0:
				_end_attack()


func _spawn_wave(d: Vector3) -> void:
	var w := BossWave.new()
	w.dir = d
	w.owner_foe = self
	w.damage = float(data["dmg"]) * 0.8 * dmg_scale
	get_parent().add_child(w)
	w.global_position = global_position + d * 1.0 + Vector3(0, 0.7, 0)


func _end_attack() -> void:
	_cool = randf_range(0.9, 1.8) if not is_boss else randf_range(0.3, 0.8) * (1.0 if _boss_phase == 0 else 0.6)
	rig.position.y = 0
	_set_state("recover")
	_blend = 0.3


func _melee_hit(reach: float, arc_deg: float, dmg: float, w: int) -> void:
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var to := hh.global_position - global_position
		to.y = 0
		if to.length() > reach + hh.radius:
			continue
		if rad_to_deg(_atk_dir.angle_to(to)) > arc_deg * 0.5:
			continue
		_hit_target(hh, dmg, w)


func _area_hit(p: Vector3, r: float, dmg: float, w: int) -> void:
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position - p
		d.y = 0
		if d.length() <= r + hh.radius:
			_hit_target(hh, dmg, w)


func _hit_target(hh: Hero, dmg: float, w: int) -> void:
	var info := HitInfo.make(self, hh, dmg * dmg_scale * randf_range(0.9, 1.1), w)
	info.knock = 6.0 if w == HitInfo.Weight.LIGHT else 10.0
	Feel.I.on_hit(info)


func take_hit(info: HitInfo) -> bool:
	if state == "spawn" and st_t < 0.2:
		return false
	var ok := super.take_hit(info)
	if not ok or not alive:
		return ok
	# 韧性：重甲要先打掉韧性才会僵直；正在跳劈的不打断
	var interrupt := true
	if max_poise > 0.0:
		poise -= info.damage * (1.6 if info.weight >= 1 else 1.0)
		interrupt = poise <= 0.0
		if interrupt:
			poise = max_poise
			Feel.I.callout(head_top(), "破韧!", Color(1.0, 0.85, 0.4), 1.0)
			Game.sfx("posture_break", -3.0)
	if state == "attack" and _atk in ["leap", "boss_leap"]:
		interrupt = false
	if interrupt:
		_release()
		rig.position.y = 0
		hit_stun = info.stun * (0.6 if is_boss else 1.0)
		_set_state("stagger")
		_blend = 1.0
		if is_boss:
			knock *= 0.3
	else:
		knock *= 0.15
	if is_boss and _boss_phase == 0 and hp < max_hp * 0.5:
		_boss_phase = 1
		rig.set_rim(Color(1.0, 0.3, 0.5), 0.9)
		Feel.I.callout(head_top() + Vector3(0, 0.6, 0), "剑鬼·狂", Color(1.0, 0.4, 0.55), 1.5)
		Feel.I.screen_flash(Color(1.0, 0.3, 0.5, 0.35), 2.0)
		data = data.duplicate()
		data["speed"] = float(data["speed"]) * 1.25
	return ok


func die(impulse: Vector3) -> void:
	super.die(impulse)
	_release()
	remove_from_group("foes")
	Game.sfx("death", -4.0)
	Vfx.I.impact_flash(chest(), 2.5 if not is_boss else 6.0)
	Vfx.I.chips(chest(), impulse, Color(0.85, 0.85, 0.78), 10, 6.0)
	CamRig.I.shake(1 if not is_boss else 2)
	rig.shatter(get_parent(), impulse)
	dropped.emit(global_position, int(data["coins"]), 3 if is_boss else (1 if randf() < 0.25 else 0))
	collision_layer = 0
	remove_from_group("foes")
	queue_free_later()


func queue_free_later() -> void:
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _apply_pose(dt: float) -> void:
	_blend = minf(_blend + dt * 10.0, 1.0)
	var p := _pose
	if _blend < 1.0 and not _pose_prev.is_empty():
		p = Poses.blend(_pose_prev, _pose, Poses.ease_in_out(_blend))
	rig.apply(p)
