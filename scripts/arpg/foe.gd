class_name Foe
extends Actor
## 敌人：状态机 巡逻 → 发现 → 追击 → 攻击前摇（红色预警）→ 攻击 → 硬直，挨打会僵直（重甲要先打掉韧性）。
## 攻击令牌：同时最多 MAX_TOKENS 个敌人在出招，其余的绕着主角游走，不会一拥而上。
## 种类在 TYPES 里：腐骨虫（小型快攻）、骷髅兵（近战）、骨刺客（快速突刺，打完就退开）、赤甲武士（重攻击、跳劈落地扬尘）、
## 幽魂术士（远程法阵）、骨弩手（远程弩箭，会躲着打）、冲阵骨（远距离直线冲锋，撞墙会晕）、爆骨鬼（贴脸自爆，先打死它反而炸到旁边的怪）、
## 盾骷髅（正面举盾挡刀，绕后或连砍破盾）、招魂巫（躲在后面招小鬼，打死它小鬼散架）、头目（夜樱剑鬼、百骨将会召唤小怪和地刺、寂光）。

## 头目进二阶段时头上冒的字
const RAGE_NAMES := {"boss": "剑鬼·狂", "boss3": "万骨·醒", "boss2": "残灯·燃"}

signal dropped(pos: Vector3, coins: int, jade: int)

const MAX_TOKENS := 2
static var tokens := 0

const TYPES := {
	"crawler": {"name": "腐骨虫", "model": "skel_minion", "weapon": "", "wlen": 0.0, "tint": Color(0.85, 0.95, 0.8), "k": 0.72,
		"hp": 26.0, "speed": 5.4, "detect": 13.0, "range": 2.2, "dmg": 7.0, "windup": 0.42, "attack": "lunge", "poise": 0.0, "coins": 1},
	"skeleton": {"name": "骷髅兵", "model": "skel_warrior", "weapon": "skel_blade", "wlen": 30.0, "tint": Color(0.95, 0.95, 0.9), "k": 1.0,
		"hp": 55.0, "speed": 3.8, "detect": 12.0, "range": 2.1, "dmg": 11.0, "windup": 0.55, "attack": "slash", "poise": 0.0, "coins": 3},
	"samurai": {"name": "赤甲武士", "model": "knight", "weapon": "axe2", "wlen": 44.0, "tint": Color(1.25, 0.5, 0.45), "k": 1.25,
		"hp": 190.0, "speed": 3.2, "detect": 14.0, "range": 2.8, "dmg": 22.0, "windup": 0.75, "attack": "heavy", "poise": 45.0, "coins": 9},
	"mage": {"name": "幽魂术士", "model": "skel_mage", "weapon": "skel_staff", "wlen": 34.0, "tint": Color(0.85, 0.7, 1.15), "k": 1.0,
		"hp": 42.0, "speed": 3.4, "detect": 16.0, "range": 11.0, "dmg": 14.0, "windup": 0.7, "attack": "rune", "poise": 0.0, "coins": 4, "keep": 7.5},
	"rogue": {"name": "骨刺客", "model": "skel_rogue", "weapon": "dagger", "wlen": 22.0, "tint": Color(0.8, 0.95, 0.85), "k": 0.95,
		"hp": 38.0, "speed": 5.0, "detect": 15.0, "range": 2.6, "dmg": 10.0, "windup": 0.32, "attack": "lunge", "poise": 0.0, "coins": 3},
	"archer": {"name": "骨弩手", "model": "skel_minion", "weapon": "crossbow", "wlen": 24.0, "tint": Color(0.95, 0.9, 0.8), "k": 0.95,
		"hp": 34.0, "speed": 3.6, "detect": 17.0, "range": 14.0, "dmg": 10.0, "windup": 0.65, "attack": "shot", "poise": 0.0, "coins": 3, "keep": 9.0},
	"charger": {"name": "冲阵骨", "model": "skel_warrior", "weapon": "skel_axe", "wlen": 38.0, "tint": Color(1.2, 0.72, 0.55), "k": 1.3,
		"hp": 120.0, "speed": 3.1, "detect": 16.0, "range": 2.6, "dmg": 18.0, "windup": 0.7, "attack": "charge", "poise": 30.0, "coins": 6},
	"bomber": {"name": "爆骨鬼", "model": "skel_minion", "weapon": "", "wlen": 0.0, "tint": Color(1.35, 0.8, 0.45), "k": 0.8,
		"hp": 20.0, "speed": 6.2, "detect": 16.0, "range": 2.3, "dmg": 20.0, "windup": 0.8, "attack": "blast", "poise": 0.0, "coins": 2},
	"shield": {"name": "盾骷髅", "model": "skel_warrior", "weapon": "skel_blade", "wlen": 28.0, "tint": Color(0.85, 0.9, 1.0), "k": 1.1,
		"hp": 70.0, "speed": 3.3, "detect": 12.0, "range": 2.2, "dmg": 12.0, "windup": 0.6, "attack": "slash", "poise": 0.0, "coins": 5,
		"offhand": "skel_shield", "olen": 24.0, "guard": 4.0},
	"summoner": {"name": "招魂巫", "model": "mage", "weapon": "staff", "wlen": 34.0, "tint": Color(0.75, 0.95, 0.8), "k": 1.0,
		"hp": 60.0, "speed": 3.2, "detect": 17.0, "range": 12.0, "dmg": 12.0, "windup": 0.7, "attack": "rune", "poise": 0.0, "coins": 6, "keep": 10.0},
	"boss3": {"name": "百骨将", "model": "skel_warrior", "weapon": "skel_axe", "wlen": 50.0, "tint": Color(0.9, 1.0, 0.85), "k": 2.0,
		"hp": 1100.0, "speed": 3.3, "detect": 40.0, "range": 3.4, "dmg": 22.0, "windup": 0.65, "attack": "boss", "poise": 140.0, "coins": 75, "boss": true},
	"boss": {"name": "夜樱剑鬼", "model": "barbarian", "weapon": "sword2", "wlen": 52.0, "tint": Color(0.78, 0.72, 0.9), "k": 1.55,
		"hp": 900.0, "speed": 3.6, "detect": 40.0, "range": 3.2, "dmg": 20.0, "windup": 0.6, "attack": "boss", "poise": 120.0, "coins": 60, "boss": true},
	"boss2": {"name": "寂光", "model": "knight", "weapon": "sword2", "wlen": 56.0, "tint": Color(0.85, 0.9, 1.05), "k": 1.6,
		"hp": 1150.0, "speed": 3.9, "detect": 40.0, "range": 3.4, "dmg": 24.0, "windup": 0.55, "attack": "boss", "poise": 160.0, "coins": 90, "boss": true},
}

var kind := "skeleton"
var data: Dictionary
var state := "spawn"
var st_t := 0.0
var _home := Vector3.ZERO
var detect_mult := 1.0          # 发现主角的距离倍数（大房间的波次怪调大）
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
var _summon_t := 6.0                 # 百骨将：多久召一次小怪
var _spikes: Array[Vector3] = []     # 百骨将：地刺落点
var _retreat_t := 0.0                # 骨刺客：刺完往后退
var target: Hero
var is_boss := false
var guard := 0.0                     # 盾骷髅：举着盾还能挡几下（挡满就破盾）
var _guard_down := 0.0               # 破盾后多久举不起来
var no_loot := false                 # 被召唤出来的小鬼不掉钱
var _minions: Array[Foe] = []        # 招魂巫招出来的
var _summon_cd := 2.5
var _exploded := false               # 爆骨鬼已经炸过
var _aim: Array[Vector3] = []        # 骨弩手这一轮射哪几个方向
## 每种新敌人第一次出现时头上冒一句提示（一次游戏里只冒一次）
static var _seen := {}
const HINTS := {"archer": "骨弩手 · 躲开红线", "charger": "冲阵骨 · 引它撞墙", "bomber": "爆骨鬼 · 先下手",
	"shield": "盾骷髅 · 绕后或连砍破盾", "summoner": "招魂巫 · 先杀它"}
var _trail: BladeTrail
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
	guard = float(data.get("guard", 0.0))


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
	if data.has("offhand"):
		rig.set_offhand(String(data["offhand"]), float(data.get("olen", 22.0)))
	match kind:
		"bomber":
			rig.set_rim(Color(1.0, 0.55, 0.2), 0.9)
		"summoner":
			rig.set_rim(Color(0.5, 1.0, 0.6), 0.6)
		"charger":
			rig.set_rim(Color(1.0, 0.5, 0.3), 0.5)
	# 精英和头目出刀带拖尾（颜色同时也是“危险”提示）
	if max_poise > 0.0 and rig.weapon != null:
		_trail = BladeTrail.new()
		_trail.actor = self
		_trail.rig = rig
		_trail.life = 0.2 if is_boss else 0.15
		_trail.width_k = 0.75
		add_child(_trail)
		var fc := fx_color()
		_trail.set_colors(Color(1, 0.95, 0.9), fc)
	_home = global_position
	_pose = Poses.idle(0.0)
	add_to_group("foes")
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_cool = randf_range(0.3, 1.2)
	# 出场：从地里冒出来
	rig.scale = Vector3(1, 0.01, 1)
	Vfx.I.dust(global_position, 1.0 * k, Color(0.35, 0.55, 0.55, 0.5))
	Vfx.I.ground(global_position, "magic_01", Color(0.4, 0.9, 1.0, 0.8) if not is_boss else Color(1.0, 0.4, 0.6, 0.9), 0.5, 2.5 * k, 0.6)
	# pixelfx 法阵光柱：小怪青色、头目樱粉
	Vfx.I.sheet("rune-cast" if is_boss else "spawn-cast", global_position, 3.4 * maxf(k, 0.8), Color(1, 1, 1, 0.9), 1.5, false, 0.0, 1.6 if is_boss else 2.6)


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
	if _guard_down > 0.0:
		_guard_down -= dt
		if _guard_down <= 0.0:
			guard = float(data.get("guard", 0.0))
			if rig.offhand != null:
				rig.offhand.visible = true
	if kind == "bomber" and state != "windup":
		# 爆骨鬼身上一直一明一暗地烧着
		rig.set_glow(Color(1.0, 0.45, 0.1) * (0.25 + 0.2 * sin(_anim_t * 9.0)))
	match state:
		"spawn":
			rig.scale = Vector3(1, minf(st_t / 0.45, 1.0), 1)
			move_with_knock(Vector3.ZERO, dt)
			_pose = Poses.idle(_anim_t)
			if st_t >= 0.45:
				rig.scale = Vector3.ONE
				_set_state("patrol")
				if HINTS.has(kind) and not _seen.has(kind):
					_seen[kind] = true
					Feel.I.callout(head_top() + Vector3(0, 0.3, 0), String(HINTS[kind]), Color(1.0, 0.9, 0.6), 2.2)
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
	if _trail != null:
		_trail.active = s == "attack"
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
		"rune", "shot", "volley", "summon_s":
			return 0.45
		"charge":
			return 0.6
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
		if guard > 0.0 and target != null:
			# 盾骷髅不跟着脚转身，盾一直慢慢对着主角（所以绕到侧后面就能砍）
			var td := target.global_position - global_position
			face_to(facing.slerp(td.normalized(), 1.0 - exp(-2.5 * dt)))
		else:
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
	if target != null and _dist_to_target() < float(data["detect"]) * detect_mult:
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
	if kind == "boss3":
		_summon_t -= dt
		if _summon_t <= 0.0 and _cool <= 0.0 and get_tree().get_nodes_in_group("foes").size() < 7:
			_summon_t = 11.0 if _boss_phase == 0 else 7.5
			_get_token()
			_begin_attack("boss_summon")
			return
	if _retreat_t > 0.0:
		# 骨刺客刺完一下就斜着退开，再找机会
		_retreat_t -= dt
		_walk((-dir + dir.cross(Vector3.UP) * _strafe * 0.7).normalized() * speed * 0.9, dt)
		face_to(facing.slerp(dir, 1.0 - exp(-8.0 * dt)))
		return
	if kind == "bomber":
		# 爆骨鬼不排队，直接冲上来，贴脸就点火
		if dist < rng:
			_begin_attack("blast")
			return
		_walk(dir * speed, dt)
		return
	if kind == "summoner":
		_summon_cd -= dt
		_minions = _minions.filter(func(m: Foe) -> bool: return is_instance_valid(m) and m.alive)
		if _summon_cd <= 0.0 and _cool <= 0.0 and _minions.size() < 3 and get_tree().get_nodes_in_group("foes").size() < 10:
			_summon_cd = randf_range(7.0, 9.0)
			_begin_attack("summon_s")
			return
	if data.has("keep"):
		var keep := float(data.get("keep", 7.0))
		if dist < keep - 1.5:
			v = -dir * speed
		elif dist > keep + 2.0:
			v = dir * speed
		else:
			v = dir.cross(Vector3.UP) * _strafe * speed * 0.5
		if _cool <= 0.0 and dist < rng and _get_token():
			if kind == "archer":
				_begin_attack("volley" if randf() < 0.3 else "shot")
			else:
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
		if kind == "charger" and _cool <= 0.0 and dist > 4.5 and dist < 13.0 and randf() < dt * 1.5 and _get_token():
			_begin_attack("charge")
			return
		if kind == "samurai" and _cool <= 0.0 and dist > 4.0 and dist < 9.0 and randf() < dt * 0.8 and _get_token():
			_begin_attack("leap")
			return
		if is_boss and _cool <= 0.0 and dist > 5.0 and randf() < dt * 1.2 and _get_token():
			if kind == "boss3":
				_begin_attack("boss_spikes" if randf() < 0.6 else "boss_leap")
			else:
				_begin_attack("boss_leap" if randf() < 0.5 else "boss_wave")
			return
	_walk(v, dt)
	face_to(facing.slerp(dir, 1.0 - exp((-2.5 if guard > 0.0 else -8.0) * dt)))


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
		"rogue":
			return "lunge"
		"charger":
			return "heavy"
		"shield":
			return "bash" if guard > 0.0 and randf() < 0.4 else "slash"
		"boss", "boss2":
			return "boss_combo"
		"boss3":
			return "boss_spikes" if randf() < 0.25 else "boss_combo"
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
		"boss_summon":
			return 0.9
		"boss_spikes":
			return 0.75 if _boss_phase == 0 else 0.6
		"charge":
			return 0.8
		"volley":
			return w + 0.2
		"summon_s":
			return 0.9
		"bash":
			return 0.45
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
			# 法阵在落点慢慢亮起，光柱刚好在出手那一下打下来
			Vfx.I.sheet("rune-cast", _atk_target, 3.0, Color(0.9, 0.7, 1.0, 0.95), 1.6, false, 0.0, 2.0 / (wt + 0.55))
		"leap", "boss_leap":
			_atk_target = target.global_position + target.velocity * 0.25 if target != null else global_position
			Vfx.I.telegraph_circle(_atk_target, 2.4 if _atk == "leap" else 3.2, red, wt + 0.65)
		"boss_wave":
			for i in range(5):
				var a := -0.6 + 0.3 * i
				var d := _atk_dir.rotated(Vector3.UP, a)
				Vfx.I.telegraph_rect(global_position, global_position + d * 12.0, 1.1, red, wt)
		"boss_spikes":
			# 骨刺从地下顶出来：一排朝主角，加几根落在主角身边
			_spikes.clear()
			var n := 5 if _boss_phase == 0 else 7
			for i in range(n):
				_spikes.append(global_position + _atk_dir * (2.5 + i * 1.8))
			if target != null:
				for i in range(2 + _boss_phase * 2):
					var a := randf() * TAU
					_spikes.append(target.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5))
			for s in _spikes:
				Vfx.I.telegraph_circle(s, 1.2, Color(0.75, 1.0, 0.6, 0.6), wt)
		"boss_summon":
			Vfx.I.ground(global_position, "magic_01", Color(0.5, 1.0, 0.6, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "起来！", Color(0.7, 1.0, 0.7), 1.0)
		"shot", "volley":
			# 红线是箭的路线：开弓前就定了方向，横着一步就能躲
			_aim.clear()
			var lead := target.velocity * 0.15 if target != null else Vector3.ZERO
			var ad := (_atk_target + lead - global_position)
			ad.y = 0
			ad = ad.normalized() if ad.length() > 0.01 else facing
			for a in ([0.0] if _atk == "shot" else [-0.28, 0.0, 0.28]):
				var d := ad.rotated(Vector3.UP, a)
				_aim.append(d)
				Vfx.I.telegraph_rect(global_position, global_position + d * 15.0, 0.45, Color(1.0, 0.3, 0.1, 0.5), wt)
			_atk_dir = ad
			face_to(ad)
		"charge":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 15.0, 1.9, red, wt)
			Feel.I.callout(head_top(), "冲!", Color(1.0, 0.5, 0.3), 0.8)
		"blast":
			Vfx.I.telegraph_circle(global_position, 2.8, Color(1.0, 0.5, 0.1, 0.65), wt)
			Game.sfx("flame", -6.0, 0.1, 1.4)
		"summon_s":
			Vfx.I.ground(global_position, "magic_01", Color(0.5, 1.0, 0.6, 0.8), 0.5, 4.0, wt + 0.3)
			Vfx.I.sheet("spawn-cast", global_position, 3.0, Color(0.6, 1.0, 0.7, 0.9), 1.6, false, 0.0, 1.6)
		"bash":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.0, 1.8, red, wt)
	Game.sfx("danger", -8.0)


func _st_windup(dt: float) -> void:
	var wt := _windup_time()
	var k := clampf(st_t / wt, 0.0, 1.0)
	move_with_knock(Vector3.ZERO, dt)
	# 红色预警：身上越来越红地闪
	var pulse := 0.5 + 0.5 * sin(st_t * (28.0 if _atk != "blast" else 20.0 + 50.0 * k))
	rig.set_glow((Color(1.0, 0.1, 0.05) if _atk != "blast" else Color(1.0, 0.55, 0.1) * 1.6) * (0.25 + 0.6 * k) * pulse)
	match _atk:
		"rune", "boss_summon", "summon_s":
			_pose = Poses.cast(k, _anim_t)
		"shot", "volley":
			_pose = _aim_pose(k)
		"charge":
			_pose = Poses.dash_ready(k)
			if randf() < dt * 8.0:
				Vfx.I.dust(global_position - _atk_dir * 0.6, 0.6, Color(0.5, 0.45, 0.4, 0.5))
		"blast":
			_pose = Poses.hurt(0.4 + 0.3 * sin(st_t * 30.0))
			# 越涨越大、越闪越快
			var sw := 1.0 + 0.35 * k + 0.05 * sin(st_t * (20.0 + 40.0 * k))
			rig.scale = Vector3(sw, sw, sw)
		"bash":
			_pose = Poses.windup("enemy_h", k, st_t)
		"boss_spikes":
			_pose = Poses.windup("enemy_v", k, st_t)
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
		if _atk in ["slash", "heavy", "boss_combo", "lunge", "bash"]:
			Game.sfx("slash_heavy" if _atk == "heavy" else "slash", -4.0, 0.1)
		elif _atk in ["shot", "volley"]:
			Game.sfx("bow", -4.0, 0.1)


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
				Vfx.I.slash(base, float(data["range"]) * 0.95, a0, -a0, 0.2 if not is_boss else 0.26, Color(1.0, 0.85, 0.8),
					Color(1.0, 0.2, 0.15) if not is_boss else fx_color(), 2.2 if not is_boss else 3.0)
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
				Vfx.I.sheet("ground-slam", global_position, r * 1.5, Color(1.0, 0.9, 0.85), 1.4, false, 0.0, 1.5)
				if is_boss:
					# 头目落地：一圈本色的放射线 + 第二道冲击环，镜头往下一砸
					for i in range(8):
						Vfx.I.streaks(global_position + Vector3(0, 0.4, 0), Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)), fx_color(), 1, r * 1.3, 0.25, 0.05, 0.2)
					Vfx.I.shock_ring(global_position, fx_color(), 0.3, r * 3.2, 0.5)
					CamRig.I.kick(Vector3(0, 0, 1), 0.3, 0.015)
				CamRig.I.shake(2)
				Game.sfx("boom", -2.0)
				_area_hit(global_position, r, float(data["dmg"]) * 1.2, HitInfo.Weight.HEAVY)
			if st_t >= dur + 0.15:
				_end_attack()
		"boss_spikes":
			var k := st_t / 0.45
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.3, 0, 1), clampf((k - 0.3) / 0.7, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.25:
				_did_hit = true
				for s in _spikes:
					Vfx.I.chips(s, Vector3.UP, Color(0.9, 0.9, 0.8), 8, 9.0, 0.12)
					Vfx.I.shock_ring(s, Color(0.7, 1.0, 0.6), 0.2, 2.4, 0.25)
					Vfx.I.streaks(s, Vector3.UP, Color(0.8, 1.0, 0.7), 3, 2.4, 0.22, 0.25, 0.2)
					_area_hit(s, 1.2, float(data["dmg"]) * 0.9, HitInfo.Weight.LIGHT)
				CamRig.I.shake(1)
				Game.sfx("death", -6.0)
			if k >= 1.0:
				_end_attack()
		"boss_summon":
			var k := st_t / 0.5
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var main := get_parent()
				var n := 3 if _boss_phase == 0 else 4
				for i in range(n):
					var a := TAU * i / n + randf() * 0.5
					var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.0
					if main.has_method("_spawn_foe"):
						main._spawn_foe("crawler" if i % 2 == 0 or _boss_phase == 0 else "rogue", p, i * 0.15)
				Game.sfx("boom", -6.0)
			if k >= 1.0:
				_end_attack()
		"shot", "volley":
			var k := st_t / 0.3
			_pose = _aim_pose(1.0 - k * 0.4)
			move_with_knock(-_atk_dir * 2.0 * (1.0 - k), dt)
			if not _did_hit:
				_did_hit = true
				for d in _aim:
					_shoot(d)
			if k >= 1.0:
				_end_attack()
		"charge":
			var dur := 1.05
			var k := st_t / dur
			_phase += dt * 16.0
			_pose = Poses.run(_phase, 1.0)
			_pose["lean"] = 0.5
			move_with_knock(_atk_dir * 16.0 * (1.0 - k * 0.3), dt)
			if Vfx.I.lod > 0 and randf() < dt * 20.0:
				Vfx.I.dust(global_position, 0.7, Color(0.5, 0.45, 0.4, 0.45))
			if not _did_hit:
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh != null and hh.alive and hh.global_position.distance_to(global_position) < radius + hh.radius + 0.5:
						_did_hit = true
						_hit_target(hh, float(data["dmg"]), HitInfo.Weight.HEAVY)
			# 撞到墙、柱子：自己晕一会儿（这时候是白打的机会）
			if st_t > 0.1 and get_slide_collision_count() > 0 and get_real_velocity().length() < 6.0:
				Vfx.I.dust(global_position + _atk_dir * 0.8, 1.6)
				Vfx.I.chips(global_position + _atk_dir * 0.8 + Vector3(0, 1, 0), -_atk_dir + Vector3.UP, Color(0.45, 0.42, 0.38), 12, 7.0, 0.12)
				Vfx.I.shock_ring(global_position + _atk_dir * 0.8, Color(1.0, 0.7, 0.4), 0.3, 2.6, 0.3)
				CamRig.I.shake(1)
				Game.sfx("boom", -5.0)
				Feel.I.callout(head_top(), "撞墙!", Color(1.0, 0.85, 0.4), 1.0)
				_end_attack()
				_release()
				hit_stun = 2.8
				Vfx.I.sheet("stunned", head_top() - Vector3(0, 0.3, 0), 1.0, Color(1, 1, 1), 1.6, false, 1.4)
				_set_state("stagger")
				return
			if k >= 1.0:
				_end_attack()
		"blast":
			_explode(true)
			return
		"summon_s":
			var k := st_t / 0.5
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var n := 2
				var fl := 0
				var main := get_parent()
				var stt: Variant = main.get("state") if main != null else null
				if stt != null:
					fl = stt.floor_i()
				for i in range(n):
					var a := TAU * i / n + randf() * 0.8
					var p := global_position + Vector3(cos(a), 0, sin(a)) * 2.2
					var mk := "bomber" if fl >= 2 and i == 1 else "crawler"
					var m := _summon(mk, p)
					if m != null:
						_minions.append(m)
				Game.sfx("boom", -8.0, 0.1, 1.3)
			if k >= 1.0:
				_end_attack()
		"bash":
			var dur := 0.28
			var k := st_t / dur
			_pose = Poses.swing("enemy_h", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			_pose["hand_l"] = Poses.dirv(0, 10, 0.95)
			_pose["shield"] = Vector3(0.6, 1.0, 0.0)
			move_with_knock(_atk_dir * 8.0 * (1.0 - k), dt)
			if not _did_hit and k >= 0.3:
				_did_hit = true
				Vfx.I.shock_ring(global_position + _atk_dir * 1.4 + Vector3(0, 0.1, 0), Color(0.8, 0.9, 1.0), 0.3, 2.2, 0.2)
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh == null or not hh.alive:
						continue
					var to := hh.global_position - global_position
					to.y = 0
					if to.length() < 2.2 + hh.radius and rad_to_deg(_atk_dir.angle_to(to)) < 60.0:
						var info := HitInfo.make(self, hh, float(data["dmg"]) * 0.8 * dmg_scale, HitInfo.Weight.LIGHT)
						info.knock = 13.0
						Feel.I.on_hit(info)
				Game.sfx("block", -4.0)
			if k >= 1.0:
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


## 骨弩手端弩瞄准：两手往前平举，弩身朝前（k 越大端得越稳）
func _aim_pose(k: float) -> Dictionary:
	var e := Poses.ease_out(k)
	return {"lean": 0.05, "twist": -0.15 * e, "bob": -0.8,
		"hand_r": Poses.dirv(-5, lerpf(-40, 5, e), 0.85), "blade": Poses.dirv(0, lerpf(-30, 0, e)),
		"hand_l": Poses.dirv(15, lerpf(-50, 5, e), 0.75), "foot_r": Vector3(-1.5, 0, 0.8), "foot_l": Vector3(2.0, 0, -0.8)}


func _shoot(d: Vector3) -> void:
	var s := FoeShot.new()
	s.dir = d
	s.owner_foe = self
	s.damage = float(data["dmg"]) * dmg_scale
	get_parent().add_child(s)
	s.global_position = global_position + d * 0.8 + Vector3(0, 1.0 * float(data["k"]), 0)
	Vfx.I.pop(s.global_position, "muzzle_02", Color(1.0, 0.6, 0.3), 0.4, 1.4, 0.12)


## 招魂巫招小鬼：直接在身边生出来（不经过波次，不掉钱，巫死了跟着散架）
func _summon(k: String, p: Vector3) -> Foe:
	var f := Foe.new()
	f.setup_kind(k, max_hp / float(data["hp"]) * 0.8, dmg_scale)
	f.no_loot = true
	get_parent().add_child(f)
	f.global_position = p
	if target != null:
		f.face_to(target.global_position - p)
	f.detect_mult = 2.0
	var main := get_parent()
	if main.has_method("_on_drop"):
		f.dropped.connect(main._on_drop.bind(k))
	return f


## 爆骨鬼炸开：hurt_hero 时（自己点火）也伤主角；被打死的残爆只伤旁边的怪
func _explode(hurt_hero: bool) -> void:
	if _exploded:
		return
	_exploded = true
	var p := global_position
	var r := 2.8 if hurt_hero else 2.4
	Vfx.I.explosion(p + Vector3(0, 0.6, 0), 0.9)
	Vfx.I.shock_ring(p, Color(1.0, 0.6, 0.2), 0.4, r * 2.0, 0.3)
	if Vfx.I.lod > 0:
		Vfx.I.sheet("dark-explosion", p, r * 1.6, Color(1.0, 0.75, 0.5), 1.8)
	CamRig.I.shake(2 if hurt_hero else 1)
	Game.sfx("boom", -2.0 if hurt_hero else -5.0)
	if hurt_hero:
		_area_hit(p, r, float(data["dmg"]), HitInfo.Weight.HEAVY)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or ff == self or not ff.alive:
			continue
		var d := ff.global_position - p
		d.y = 0
		if d.length() > r + ff.radius:
			continue
		var info := HitInfo.make(null, ff, (40.0 if not ff.is_boss else 25.0), HitInfo.Weight.HEAVY)
		info.dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		info.point = ff.chest()
		info.knock = 9.0
		Feel.I.on_hit(info)
	if alive:
		hp = 0.0
		die(Vector3.UP * 4.0)


func _end_attack() -> void:
	_cool = randf_range(0.9, 1.8) if not is_boss else randf_range(0.6, 1.2) * (1.0 if _boss_phase == 0 else 0.6)
	if kind == "rogue":
		_retreat_t = 0.7
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
	# 盾骷髅：正面来的刀挡掉大半，挡满几下就破盾；绕到侧后面、或者大招，直接打进去
	var blocked := false
	if guard > 0.0 and alive and iframes <= 0.0 and info.weight < HitInfo.Weight.ULT and state != "stagger":
		var from := -info.dir
		from.y = 0
		if from.length() > 0.01 and facing.dot(from.normalized()) > 0.3:
			blocked = true
			guard -= 2.0 if info.weight == HitInfo.Weight.HEAVY else 1.0
			if guard <= 0.0:
				guard = 0.0
				_guard_down = 4.0
				if rig.offhand != null:
					rig.offhand.visible = false
					Vfx.I.chips(chest(), info.dir + Vector3.UP, Color(0.6, 0.62, 0.66), 14, 7.0, 0.12)
				Feel.I.callout(head_top(), "破盾!", Color(1.0, 0.85, 0.4), 1.0)
				Game.sfx("guard_break", -3.0)
				info.damage *= 0.5
				info.stun = maxf(info.stun, 1.0)
				blocked = false
			else:
				info.damage *= 0.15
				info.knock *= 0.3
				Vfx.I.pop(chest() - info.dir * 0.4, "spark_05", Color(0.8, 0.9, 1.0), 0.4, 1.8, 0.14)
				Feel.I.callout(head_top(), "格", Color(0.75, 0.85, 1.0), 0.5)
				Game.sfx("block", -5.0)
	var ok := super.take_hit(info)
	if ok and blocked:
		knock *= 0.3
		return ok
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
		rig.scale = Vector3.ONE
		hit_stun = info.stun * (0.6 if is_boss else 1.0)
		if max_poise > 0.0:
			# 重甲被打断：头上冒星星
			Vfx.I.sheet("stunned", head_top() - Vector3(0, 0.3, 0), 1.0, Color(1, 1, 1), 1.6, false, maxf(hit_stun, 0.9))
		_set_state("stagger")
		_blend = 1.0
		if is_boss:
			knock *= 0.3
	else:
		knock *= 0.15
	if is_boss and _boss_phase == 0 and hp < max_hp * 0.5:
		_boss_phase = 1
		rig.set_rim(fx_color(), 0.9)
		Feel.I.callout(head_top() + Vector3(0, 0.6, 0), String(RAGE_NAMES.get(kind, "狂")), Color(1.0, 0.4, 0.55), 1.5)
		Feel.I.screen_flash(Color(fx_color(), 0.4), 2.0)
		# 进入狂暴：慢镜头一下，本色冲击环一圈圈推开
		Feel.I.slowmo(0.3, 0.6)
		for j in range(3):
			Vfx.I.shock_ring(global_position, fx_color() if j != 1 else Color(1, 1, 1), 0.4, 5.0 + j * 2.5, 0.45 + j * 0.2)
		Vfx.I.streaks(chest(), Vector3.UP, fx_color(), 10, 3.5, 0.4, PI, 0.22)
		CamRig.I.shake(2, 1.2)
		Game.sfx("boss_kill", -6.0, 0.0, 1.3)
		data = data.duplicate()
		data["speed"] = float(data["speed"]) * 1.25
	return ok


## 这个敌人的特效主色：头目各有一套（夜樱粉、百骨将骨青、寂光金），精英橙红，小怪暖黄
func fx_color() -> Color:
	match kind:
		"boss":
			return Color(1.0, 0.45, 0.7)
		"boss3":
			return Color(0.75, 1.0, 0.7)
		"boss2":
			return Color(1.0, 0.82, 0.4)
	return Color(1.0, 0.5, 0.3) if max_poise > 0.0 else Color(1.0, 0.85, 0.4)


func die(impulse: Vector3) -> void:
	super.die(impulse)
	_release()
	remove_from_group("foes")
	if _trail != null:
		_trail.active = false
	Feel.I.on_kill(self, impulse)
	Game.sfx("death", -4.0)
	if kind == "bomber" and not _exploded:
		# 爆骨鬼被打死：短暂一下后残爆，炸旁边的怪，不伤主角
		get_tree().create_timer(0.18).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_explode(false))
	for m in _minions:
		if is_instance_valid(m) and m.alive:
			m.die(Vector3.UP * 2.0)
	if is_boss:
		# 头目倒下，召出来的小怪跟着散架
		for f: Node in get_tree().get_nodes_in_group("foes"):
			if f != self and f is Foe and (f as Foe).alive:
				(f as Foe).die(Vector3.UP * 2.0)
	Vfx.I.impact_flash(chest(), 2.5 if not is_boss else 6.0)
	Vfx.I.chips(chest(), impulse, Color(0.85, 0.85, 0.78), 10, 6.0)
	CamRig.I.shake(1 if not is_boss else 2)
	rig.shatter(get_parent(), impulse)
	var jade := 3 if is_boss else (1 if randf() < 0.25 and not no_loot else 0)
	if jade > 0:
		# 掉魂玉的敌人飘出一缕魂
		Vfx.I.sheet("soul-rise", global_position, 3.0 if not is_boss else 5.0, Color(0.7, 1.0, 0.95, 0.9), 1.6, false, 0.0, 1.3)
	dropped.emit(global_position, 0 if no_loot else int(data["coins"]), jade)
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
