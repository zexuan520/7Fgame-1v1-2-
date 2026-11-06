class_name Hero
extends Actor
## 主角：八方向移动、翻滚（无敌帧 + 残影）、四段连招（数据在 combo）、输入缓冲 0.2 秒、
## 技能：突进斩（青色预警框 → 瞬移穿过路径）、光束斩（斜贯屏幕的光柱，全屏停顿，要满气）、终结技（引爆附近敌人的出血层数）、药葫芦。

signal energy_changed
signal link_fired(id: String)

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
var cd := {"dash": 0.0, "finish": 0.0, "art": 0.0, "swap": 0.0, "swap_strike": 0.0, "item": 0.0}
var gourds := 3
var max_gourds := 3
var dmg_mult := 1.0
var _dash_from := Vector3.ZERO
var _dash_to := Vector3.ZERO
var _combo_reset := 0.0
var hits_taken := 0           # 挨打次数（试炼“守”用）
var drinks := 0               # 这一局喝了几口药葫芦（成就“滴药未沾”）
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
## 流派大成（ArpgData.SETS）
var set_shura := false
var set_blood := false
var set_wind := false
var set_light := false
var set_guard := false
var _wind_t := 0.0               # 御风：翻滚后必会心的剩余时间
var _guard_t := 0.0              # 金身：凝金光的计时
var golden := false              # 金身：现在有一层金光
const GUARD_EVERY := 10.0
## 技能分支（ArpgSkills.SKILLS）：分支 id → 级数；双修：id → true。都从 stats 表的 sk_ / duo_ 键读
var sk := {}
var duo := {}
var _link_from := ""             # 连携：上一招（dash / roll / beam / combo / finish）
var _link_age := 99.0            # 上一招放完过了多久
var _link_now := ""              # 这一招触发了哪个连携（放完清掉）
var _decoy_cd := 0.0             # 影遁：每 1.5 秒最多留一次影子
var _echo_t := 0.0               # 连闪：还能不等冷却再闪的剩余时间
var _echo_live := false          # 这一闪是连闪
var _dash_hits: Array = []       # 上一次突进斩斩到的敌人（瞬狱）
var _beam_hits: Array = []       # 上一次光束照到的敌人（焚血）
var _roll_cut := {}              # 这一次翻滚划过的敌人（踏风、血影）
var _mirror_t := 0.0             # 明镜：光束斩后受伤减免的剩余时间
var _dash_len_k := 1.0
var _beam_fast := false          # 天落：这次光束出手快一倍
var _rim_gold := false           # 不动明王生效时描边变金
## 秘技（新技能，ArpgSkills 里 id "art" 的四个分支）
var art_cd := 8.0
var art_hits: Array = []         # 这一次秘技打中的敌人（归一）
var _art_k := 1.0                # 风雷：秘技伤害 +50%
var _whirl_tick := 0.0
var _clone_t := 0.0              # 分身剩余时间
var _clone_atk := 0.0
var _clone_pos := Vector3.ZERO
var _clone_ghost := 0.0
var weapon_id := "sword"
var trail: BladeTrail
## 兵器多重化、装备机制、道具（ArpgArms）
var kit: ArpgState                 # 这一局的状态（换兵器、用道具要读）；山门里是 null
var buffs := {}                    # 道具给的临时效果：名字 → 剩余秒数（whet 磨刀石 / smoke 烟丸）
var edge := 0                      # 鸳鸯双刀的刀势层数
var _edge_t := 0.0
var _roll_crit := false            # 连弩：翻滚后第一箭必会心
var _swap_strike := false          # 这一刀是换刃斩
var _hit_n := 0                    # 雷殛套：命中计数
var _iron_t := 0.0                 # 不动套：反震冷却
var _item_id := ""                 # 正在用的道具
var thorns := 0.0
var hurt_energy := 0.0
var rage := 0.0
var roll_bolt := 0.0
var kill_heal := 0.0
var crit_bolt := 0.0
var fire_proc := 0.0
var set_iron := false
var set_oni := false
var set_thunder := false
var skin_id := ""
const BASE_ROLL_DIST := 5.2
const EDGE_MAX := 10
const SWAP_STRIKE_CD := 4.0
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
		combo = ArpgArms.combo(wid)
		edge = 0
		if state == "attack":
			_set_state("move")
		step_i = -1
		_equip_model()
	dmg_mult = (1.0 + ArpgData.stat(st, "atk")) * float(w["dmg"])
	crit_bonus = ArpgData.stat(st, "crit")
	crit_mult = 1.8 + ArpgData.stat(st, "crit_dmg")
	energy_mult = 1.0 + ArpgData.stat(st, "energy")
	bleed_bonus = int(ArpgData.stat(st, "bleed"))
	bleed_dmg = 1.0 + ArpgData.stat(st, "bleed_dmg")
	lifesteal = ArpgData.stat(st, "lifesteal")
	taken_mult = maxf(0.3, 1.0 + ArpgData.stat(st, "dmg_taken")) * (1.0 - ArpgData.stat(st, "easy"))   # 游历难度另乘
	beam_mult = 1.0 + ArpgData.stat(st, "beam")
	finish_mult = 1.0 + ArpgData.stat(st, "finish")
	gourd_heal = 0.4 + ArpgData.stat(st, "gourd_heal")
	move_speed = BASE_MOVE * (1.0 + ArpgData.stat(st, "move"))
	dash_cd = BASE_DASH_CD * maxf(0.3, 1.0 - ArpgData.stat(st, "dash_cd"))
	finish_cd = BASE_FINISH_CD * maxf(0.3, 1.0 - ArpgData.stat(st, "finish_cd"))
	roll_iframes = BASE_IFRAMES + ArpgData.stat(st, "iframes")
	roll_dist = BASE_ROLL_DIST * (1.0 + ArpgData.stat(st, "roll_far"))
	thorns = ArpgData.stat(st, "thorns")
	hurt_energy = ArpgData.stat(st, "hurt_energy")
	rage = ArpgData.stat(st, "rage")
	roll_bolt = ArpgData.stat(st, "roll_bolt")
	kill_heal = ArpgData.stat(st, "kill_heal")
	crit_bolt = ArpgData.stat(st, "crit_bolt")
	fire_proc = ArpgData.stat(st, "fire_proc")
	set_iron = ArpgData.stat(st, "set_iron") > 0.0
	set_oni = ArpgData.stat(st, "set_oni") > 0.0
	set_thunder = ArpgData.stat(st, "set_thunder") > 0.0
	var mg := 3 + int(ArpgData.stat(st, "gourds"))
	if fill_hp:
		gourds = mg
	else:
		gourds += maxi(mg - max_gourds, 0)
	max_gourds = mg
	if fill_hp:
		revives = int(ArpgData.stat(st, "revive"))
	set_shura = ArpgData.stat(st, "set_shura") > 0.0
	set_blood = ArpgData.stat(st, "set_blood") > 0.0
	set_wind = ArpgData.stat(st, "set_wind") > 0.0
	set_light = ArpgData.stat(st, "set_light") > 0.0
	set_guard = ArpgData.stat(st, "set_guard") > 0.0
	if not set_guard:
		golden = false
	sk.clear()
	duo.clear()
	for k: String in st:
		if k.begins_with("sk_"):
			sk[k.substr(3)] = int(st[k])
		elif k.begins_with("duo_"):
			duo[k.substr(4)] = true
	# 分支改冷却和消耗
	var ec := skr("echo")
	if ec >= 2:
		dash_cd *= 0.85 if ec == 2 else 0.7
	finish_cd *= 1.0 - 0.1 * skr("drink")
	if skr("lotus") >= 3:
		finish_cd *= 0.85
	beam_cost = 85.0 if skr("split") >= 3 else 100.0
	art_cd = float(ArpgSkills.ART_CD.get(art_id(), 8.0))


## 学的是哪一种秘技（没学返回 ""）
func art_id() -> String:
	return ArpgSkills.chosen_branch(sk, "art")


## 技能分支级数
func skr(id: String) -> int:
	return int(sk.get(id, 0))


## 出手伤害倍率：兵器、心法之外，双修“不动明王”血多时再 +20%
func power() -> float:
	if duo.has("budong") and hp > max_hp * 0.7:
		return dmg_mult * 1.2
	return dmg_mult


## 手里的模型：主手兵器，鸳鸯双刀左手再拿一把；刀光按兵器换色
func _equip_model() -> void:
	if rig == null:
		return
	var w := ArpgData.weapon(weapon_id)
	rig.set_weapon(String(w["model"]), float(w["len"]))
	rig.set_offhand(String(w.get("offhand", "")), float(w["len"]))
	_reset_trail()


func _reset_trail() -> void:
	if trail == null:
		return
	var tc := ArpgArms.trail(weapon_id)
	trail.set_colors(tc[0], tc[1])


## 换皮肤：换模型就整个人偶重建（兵器、刀光跟着挂回去）
func apply_skin(id: String) -> void:
	var sk := ArpgArms.skin(id)
	if skin_id == String(sk["id"]) and rig != null:
		return
	var old_model := String(ArpgArms.skin(skin_id).get("model", "")) if skin_id != "" else ""
	skin_id = String(sk["id"])
	if rig == null or old_model != String(sk["model"]):
		if rig != null:
			rig.queue_free()
		rig = VoxActor.new()
		add_child(rig)
		rig.setup(String(sk["model"]), "", 34.0, Color(1, 1, 1), float(sk.get("k", 1.0)))
		if trail != null:
			trail.rig = rig
		_equip_model()
	var rc: Color = sk.get("rim", Color(0.45, 0.95, 1.0))
	rig.set_rim(rc, 0.6)
	rig.mat.set_shader_parameter("swap_green", sk.has("swap"))
	if sk.has("swap"):
		var sc: Color = sk["swap"]
		rig.mat.set_shader_parameter("swap_color", Vector3(sc.r, sc.g, sc.b))
	var gl: Color = sk.get("glow", Color(0, 0, 0))
	rig.set_glow(gl)
	rig.apply(_pose if not _pose.is_empty() else Poses.idle(0.0))


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
	drinks = 0
	state = "move"
	step_i = -1
	energy = 0.0
	bleed = 0
	golden = false
	_guard_t = 0.0
	_wind_t = 0.0
	_link_from = ""
	_link_age = 99.0
	_echo_t = 0.0
	_mirror_t = 0.0
	_decoy_cd = 0.0
	_clone_t = 0.0
	buffs.clear()
	edge = 0
	_roll_crit = false
	_hit_n = 0
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
	# 皮肤（ArpgArms.SKINS）：默认“青衫”，兜帽和披风换成深青蓝（原模型是绿的），和青绿场景拉开
	_pose = Poses.idle(0.0)
	apply_skin(String(Game.save.get("arpg_skin", "qing")))
	add_to_group("heroes")
	_make_foot_ring()
	trail = BladeTrail.new()
	trail.actor = self
	trail.rig = rig
	add_child(trail)
	_reset_trail()


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
	_tick_sets(dt)
	_tick_skills(dt)
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
		"whirl":
			_st_whirl(dt)
		"quake":
			_st_quake(dt)
		"art_cast":
			_st_art_cast(dt)
		"item":
			_st_item(dt)
	_apply_pose(dt)


func _read_buffer(delta: float) -> void:
	for a: String in ["attack", "roll", "dash", "beam", "finish", "heal", "art", "swap", "item", "item_next"]:
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
	if state == "whirl" and rig != null:
		rig.rotation.y = 0.0     # 旋风转着被打断：人偶转回来
	if state == "quake" and rig != null:
		rig.position.y = 0.0
	state = s
	st_t = 0.0
	if trail != null:
		trail.active = s in ["attack", "finish", "dash"]
		if s == "finish":
			trail.set_colors(Color(1.0, 0.85, 0.8), Color(1.0, 0.15, 0.15))
			trail.life = 0.22
		elif s != "attack":
			_reset_trail()
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
				_echo_live = false
				_start_dash()
				return true
			if _echo_t > 0.0 and skr("echo") > 0:
				_echo_live = true
				_start_dash()
				return true
		"beam":
			if energy >= beam_cost - 0.01:
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
		"art":
			if art_id() == "":
				Feel.I.callout(head_top(), "还没学秘技（技能分支里点）", Color(0.85, 0.75, 0.6), 0.7)
			elif cd["art"] <= 0.0:
				_start_art()
				return true
		"swap":
			return swap_arms()
		"item":
			return _start_item()
		"item_next":
			if kit != null and kit.props.size() > 1:
				kit.prop_sel = (kit.prop_sel + 1) % kit.props.size()
				var it := ArpgArms.item(String(kit.props[kit.prop_sel]["id"]))
				Feel.I.callout(head_top(), "道具：%s" % it["name"], it["color"], 0.7)
				Game.sfx("coin", -10.0)
	return false


# ---------- 移动 ----------

func _leech(dmg: float) -> void:
	if lifesteal > 0.0 and alive:
		hp = minf(hp + dmg * lifesteal, max_hp)


func _st_move(dt: float) -> void:
	if _try_actions(["attack", "roll", "dash", "beam", "finish", "heal", "art", "swap", "item", "item_next"]):
		return
	var d := input_dir()
	var want := d * move_speed * (1.3 if buffs.has("smoke") else 1.0)
	_move = _move.move_toward(want, accel * dt)
	if d != Vector3.ZERO:
		# 按角度插值转身（Vector3.slerp 在两向量几乎平行时会报“轴未归一化”）
		var dn := d.normalized()
		if facing.dot(dn) > -0.9:
			var a := lerp_angle(atan2(facing.x, facing.z), atan2(dn.x, dn.z), 1.0 - exp(-18.0 * dt))
			face_to(Vector3(sin(a), 0, cos(a)))
		else:
			face_to(dn)
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
	_swap_strike = false
	if OS.get_cmdline_user_args().has("--armslog"):
		print("ARMS atk %s %d %s" % [weapon_id, i, s.label])
	Game.sfx("slash_heavy" if s.heavy else "slash", -2.0 if s.swing != "shoot" else -6.0, 0.1)
	# 拖尾：按兵器上色，重击更亮更长、回旋斩最长；连弩不拖尾
	trail.life = 0.3 if s.swing == "spin" else (0.2 if s.heavy else 0.15)
	var tc := ArpgArms.trail(weapon_id)
	trail.set_colors(tc[0], (tc[1] as Color).lightened(0.2) if s.heavy else tc[1])
	if s.swing == "shoot":
		trail.active = false
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
		if step_i == combo.size() - 1:
			_combo_branch()
		if s.fx != "":
			_weapon_fx(s)
	if t >= s.startup and t <= s.startup + s.active + dt and s.swing != "shoot":
		_do_hits(s)
	# 取消：翻滚随时可以；过了 cancel_at 可以接下一段或放技能
	if _take_buffer(["roll"]) == "roll":
		_start_roll()
		return
	if t >= s.cancel_at:
		if _try_actions(["attack", "dash", "beam", "finish", "art", "swap", "item"]):
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
		"thrust":
			var tc := ArpgArms.trail(weapon_id)
			var from := global_position + Vector3(0, 1.0, 0) + facing * 0.6
			Vfx.I.streaks(from, facing, tc[1], 3, s.reach, 0.14, 0.04, 0.16)
			Vfx.I.cut_line(from + facing * s.reach * 0.5, facing, s.reach + 0.6, tc[0], 0.16, 0.16, tc[1])
			Vfx.I.pop(global_position + facing * s.reach + Vector3(0, 1.0, 0), "spark_05", tc[1], 0.3, 1.4, 0.12)
		"shoot":
			Vfx.I.pop(global_position + facing * 0.9 + Vector3(0, 1.0, 0), "muzzle_02", Color(0.7, 1.0, 0.95), 0.3, 1.2, 0.1)
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
		if _strike(a, s, 1.0, false):
			landed = true
	if landed:
		_wind_t = 0.0
		if step_i == combo.size() - 1:
			_link_mark("combo")
		if _swap_strike:
			ArpgAch.unlock("swap_hit")
	if landed and not _called:
		_called = true
		var lbl := s.label if not _swap_strike else "换刃·%s" % String(ArpgData.weapon(weapon_id)["name"])
		Feel.I.callout(head_top() + Vector3(0.6, 0.3, 0), lbl, Color(0.75, 1.0, 1.0), 0.9 if step_i < combo.size() - 1 else 1.2)


## 一刀（或一箭）落到一个敌人身上：会心、伤害加成、兵器特性、装备特效都在这里算。返回 true 表示真打中了
func _strike(a: Actor, s: AttackStep, k: float, force_crit: bool) -> bool:
	var to := a.global_position - global_position
	to.y = 0
	var crit := force_crit or randf() < s.crit_chance + crit_bonus or _wind_t > 0.0
	# 双刃短匕 · 背刺：敌人背对着你
	if weapon_id == "dagger" and to.length() > 0.1 and a.facing.dot(to.normalized()) > 0.3:
		crit = true
	var m := power() * k
	if buffs.has("whet"):
		m *= 1.35
	if rage > 0.0 and hp < max_hp * 0.5:
		m *= 1.0 + rage
	if set_oni and hp < max_hp * 0.4:
		m *= 1.3
	if weapon_id == "twin":
		m *= 1.0 + 0.04 * edge
	if weapon_id == "spear" and to.length() > 2.4:
		m *= 1.25
	if _swap_strike:
		m *= 1.3
	var dmg := s.damage * m * (crit_mult if crit else 1.0) * randf_range(0.92, 1.08)
	var info := HitInfo.make(self, a, dmg, HitInfo.Weight.HEAVY if s.heavy else HitInfo.Weight.LIGHT)
	info.crit = crit
	info.knock = s.knock * (1.35 if weapon_id == "staff" else 1.0)
	var bl := s.bleed + (1 if buffs.has("whet") else 0)
	info.bleed = bl + (bleed_bonus if bl > 0 else 0) + (2 if crit and duo.has("xueren") else 0)
	info.bleed_mult = bleed_dmg
	info.stun = 0.35 if s.heavy else 0.25
	if s.fx == "sweep":
		info.stun = 1.0
	if weapon_id == "hammer":
		info.stun *= 1.8
	info.gain = (6.0 if not s.heavy else 9.0) + (3.0 if weapon_id == "staff" else 0.0)
	if s.swing == "shoot":
		info.attacker = null    # 远程：主角不跟着顿帧
		info.dir = to.normalized() if to.length() > 0.1 else facing
	if not Feel.I.on_hit(info):
		return false
	if OS.get_cmdline_user_args().has("--armslog"):
		print("ARMS hit %s %s dmg=%.1f crit=%s edge=%d" % [weapon_id, s.label, info.damage, crit, edge])
	if s.swing == "shoot":
		gain_energy(info.gain)   # attacker 为空时 Feel 不给主角回气，这里补上
	_leech(info.damage)
	if set_oni and hp < max_hp * 0.4:
		hp = minf(hp + info.damage * 0.04, max_hp)
	if crit and set_shura:
		_shura_splash(a, info.damage)
	_check_blood(a)
	_on_landed(a, crit)
	return true


## 打中之后的装备、兵器特效：刀势、火纹玉、雷符坠、雷殛套
func _on_landed(a: Actor, crit: bool) -> void:
	if weapon_id == "twin":
		edge = mini(edge + 1, EDGE_MAX)
		_edge_t = 1.5
	if fire_proc > 0.0 and randf() < fire_proc and is_instance_valid(a):
		_fire_burst(a.chest())
	if crit and crit_bolt > 0.0 and randf() < crit_bolt and is_instance_valid(a):
		ArpgArms.lightning(self, a.global_position, 24.0 * dmg_mult, 0.4)
	if set_thunder:
		_hit_n += 1
		if _hit_n >= 5 and is_instance_valid(a):
			_hit_n = 0
			ArpgArms.lightning(self, a.global_position, 30.0 * dmg_mult, 0.6)


## 火纹玉：敌人身上炸开一团火（1.8 米内都烫到）
func _fire_burst(p: Vector3) -> void:
	Vfx.I.explosion(p, 0.5)
	Vfx.I.pop(p, "spark_05", Color(1.0, 0.6, 0.2), 0.4, 1.8, 0.2)
	Game.sfx("flame", -8.0, 0.1)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var b := f as Actor
		if b == null or not b.alive or b.chest().distance_to(p) > 1.8 + b.radius:
			continue
		var info := HitInfo.make(self, b, 10.0 * dmg_mult, HitInfo.Weight.LIGHT)
		info.attacker = null
		info.knock = 2.0
		info.stun = 0.1
		Feel.I.on_hit(info)


## 连弩的箭、飞镖打中敌人（HeroBolt 调用）
func bolt_hit(a: Actor, b: HeroBolt) -> bool:
	if b.step != null:
		return _strike(a, b.step, 1.0, b.crit)
	var info := HitInfo.make(self, a, b.damage * randf_range(0.92, 1.08), HitInfo.Weight.LIGHT)
	info.attacker = null
	info.dir = b.dir
	info.knock = 3.0
	info.bleed = b.bleed + (bleed_bonus if b.bleed > 0 else 0)
	info.bleed_mult = bleed_dmg
	if Feel.I.on_hit(info):
		_leech(info.damage)
		_check_blood(a)
		return true
	return false


## 兵器专属的招式效果（判定开始那一帧）：震地、穿刺、放箭
func _weapon_fx(s: AttackStep) -> void:
	match s.fx:
		"quake", "quake3":
			var c := global_position + facing * 1.6
			var rings := 3 if s.fx == "quake3" else 1
			for i in range(rings):
				var r := s.fx_r * (0.6 + 0.4 * i) if rings > 1 else s.fx_r
				get_tree().create_timer(0.12 * i).timeout.connect(_quake.bind(c, r, s, i))
		"pierce":
			# 破阵：一条直线上的敌人全扎穿
			var from := global_position
			var to := global_position + facing * s.fx_r
			var tc := ArpgArms.trail(weapon_id)
			Vfx.I.cut_line((from + to) * 0.5 + Vector3(0, 1.0, 0), facing, s.fx_r + 1.0, tc[0], 0.3, 0.3, tc[1])
			Vfx.I.streaks(from + Vector3(0, 1.0, 0), facing, tc[1], 6, s.fx_r, 0.2, 0.05, 0.2)
			CamRig.I.kick(facing, 0.2)
			var seg := to - from
			for f: Node in get_tree().get_nodes_in_group("foes"):
				var a := f as Actor
				if a == null or not a.alive or _hit_set.has(a):
					continue
				var t := clampf((a.global_position - from).dot(seg) / seg.length_squared(), 0.0, 1.0)
				if (a.global_position - (from + seg * t)).length() <= 0.75 + a.radius:
					_hit_set[a] = true
					_strike(a, s, 1.0, false)
		"bolt", "spread":
			var dir := facing
			var n := 1 if s.fx == "bolt" else 5
			for i in range(n):
				var b := HeroBolt.new()
				b.hero = self
				b.dir = dir.rotated(Vector3.UP, deg_to_rad(0.0 if n == 1 else -24.0 + 12.0 * i))
				b.step = s
				b.pierce = 1
				b.life = s.reach / b.speed
				b.crit = _roll_crit
				get_parent().add_child(b)
				b.global_position = global_position + Vector3(0, 1.05, 0) + b.dir * 0.7
			_roll_crit = false
			CamRig.I.kick(-facing, 0.08, 0.01)


func _quake(c: Vector3, r: float, s: AttackStep, i: int) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var g := Vector3(c.x, 0.0, c.z)
	Vfx.I.shock_ring(g, Color(1.0, 0.85, 0.6), 0.4, r, 0.35)
	Vfx.I.dust(g, r * 0.7, Color(0.55, 0.5, 0.45, 0.5))
	Vfx.I.ground(g, "scorch_01", Color(0.05, 0.04, 0.03, 0.6), r * 0.8, r * 1.0, 1.2, false)
	CamRig.I.shake(1 if i == 0 else 0)
	Game.sfx("boom", -8.0 - 2.0 * i, 0.1)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := a.global_position - g
		d.y = 0
		if d.length() > r + a.radius:
			continue
		# 震地波：主刀已经打中的不再吃第一圈，后面几圈谁都吃
		if i == 0 and _hit_set.has(a):
			continue
		var info := HitInfo.make(self, a, s.damage * 0.45 * dmg_mult, HitInfo.Weight.HEAVY)
		info.attacker = null
		info.dir = d.normalized() if d.length() > 0.1 else facing
		info.knock = 6.0
		info.stun = 0.5 * (1.8 if weapon_id == "hammer" else 1.0)
		if Feel.I.on_hit(info):
			_on_landed(a, false)


# ---------- 双兵器、道具 ----------

## Q：换到副手兵器。附近有敌人、换刃斩冷却好了，直接用新兵器打出它的收势一击
func swap_arms() -> bool:
	if kit == null or (kit.arms[1] as Dictionary).is_empty():
		Feel.I.callout(head_top(), "没有副兵器", Color(0.7, 0.8, 0.85), 0.7)
		return false
	if float(cd["swap"]) > 0.0:
		return false
	cd["swap"] = 0.35
	kit.swap_arms()
	if OS.get_cmdline_user_args().has("--armslog"):
		print("ARMS swap -> %s" % String(kit.arms[0]["base"]))
	apply_stats(kit.stats(), kit.weapon)
	Game.sfx("parry", -8.0, 0.15)
	Vfx.I.ghost(rig, ArpgArms.trail(weapon_id)[1], 0.25)
	var near := _auto_target(facing, 5.0)
	if near == null:
		near = _auto_target(-facing, 3.0)
	if near != null and float(cd["swap_strike"]) <= 0.0:
		cd["swap_strike"] = SWAP_STRIKE_CD
		_start_attack(combo.size() - 1)
		_swap_strike = true
		Vfx.I.shock_ring(global_position, ArpgArms.trail(weapon_id)[1], 0.3, 3.0, 0.3)
		Feel.I.slowmo(0.15, 0.4)
	else:
		Feel.I.callout(head_top(), String(ArpgData.weapon(weapon_id)["name"]), ArpgArms.trail(weapon_id)[1], 0.8)
		if state != "move":
			_set_state("move")
	return true


## R：用当前道具（短暂掏东西的动作，0.15 秒时生效）
func _start_item() -> bool:
	if kit == null or kit.props.is_empty() or float(cd["item"]) > 0.0:
		if kit != null and kit.props.is_empty():
			Feel.I.callout(head_top(), "没有道具", Color(0.7, 0.8, 0.85), 0.7)
		return false
	_item_id = String(kit.props[clampi(kit.prop_sel, 0, kit.props.size() - 1)]["id"])
	cd["item"] = 0.5
	_set_state("item")
	_blend = 0.6
	return true


func _st_item(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.cast(clampf(st_t / 0.15, 0, 1), st_t))
	if st_t >= 0.15 and st_t - dt < 0.15:
		if OS.get_cmdline_user_args().has("--armslog"):
			print("ARMS item %s" % _item_id)
		if ArpgArms.use_item(self, _item_id) and kit != null:
			kit.use_item(_item_id)
			ArpgAch.add("prop_use")
	if st_t > 0.2 and _take_buffer(["roll"]) == "roll":
		_start_roll()
		return
	if st_t >= 0.32:
		_set_state("move")


func buff(id: String, t: float) -> void:
	buffs[id] = maxf(float(buffs.get(id, 0.0)), t)


func auto_target(dir: Vector3, rng: float) -> Actor:
	return _auto_target(dir, rng)


# ---------- 流派大成 ----------

## 修罗场：会心的余劲斩到身边的其他敌人
func _shura_splash(src: Actor, dmg: float) -> void:
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var b := f as Actor
		if b == null or b == src or not b.alive or b.global_position.distance_to(src.global_position) > 2.8:
			continue
		var info := HitInfo.make(self, b, dmg * 0.4, HitInfo.Weight.LIGHT)
		info.attacker = null
		info.dir = (b.global_position - src.global_position).normalized()
		info.knock = 3.0
		Vfx.I.cut_line(b.chest(), info.dir + Vector3(0, 0.6, 0), 2.2, Color(1, 0.9, 0.85), 0.2, 0.18, Color(1.0, 0.35, 0.3))
		Feel.I.on_hit(info)


## 血涌：出血叠到 6 层自己炸开
func _check_blood(a: Actor) -> void:
	if not set_blood or not is_instance_valid(a) or not a.alive or a.bleed < 6:
		return
	var stacks := a.bleed
	a.bleed = 0
	var c := a.chest()
	Vfx.I.explosion(c, 0.9)
	Vfx.I.streaks(c, Vector3.UP, Color(1.0, 0.2, 0.2), 6, 2.0, 0.22, PI, 0.18)
	Game.sfx("execute", -6.0)
	Feel.I.callout(a.head_top(), "血涌", Color(1.0, 0.3, 0.3), 0.9)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var b := f as Actor
		if b == null or not b.alive or b.global_position.distance_to(a.global_position) > 2.6:
			continue
		var info := HitInfo.make(self, b, (10.0 + 9.0 * stacks) * dmg_mult * (1.0 if b == a else 0.6), HitInfo.Weight.HEAVY)
		info.attacker = null
		info.knock = 5.0
		Feel.I.on_hit(info)


## 金身：每 10 秒凝一层金光（在 _physics_process 里调用）
func _tick_sets(dt: float) -> void:
	_wind_t = maxf(_wind_t - dt, 0.0)
	_iron_t = maxf(_iron_t - dt, 0.0)
	for k: String in buffs.keys():
		buffs[k] = float(buffs[k]) - dt
		if float(buffs[k]) <= 0.0:
			buffs.erase(k)
	if edge > 0:
		_edge_t -= dt
		if _edge_t <= 0.0:
			edge = 0
	if set_guard and not golden and alive:
		_guard_t += dt
		if _guard_t >= GUARD_EVERY:
			_guard_t = 0.0
			golden = true
			Vfx.I.shock_ring(global_position, Color(1.0, 0.85, 0.4), 0.3, 2.5, 0.4)
			Feel.I.callout(head_top(), "金身", Color(1.0, 0.85, 0.45), 0.8)


# ---------- 技能分支、连携、双修（ArpgSkills） ----------

## 去掉已经删掉或倒下的
func _alive(arr: Array) -> Array:
	var out := []
	for x: Variant in arr:
		if is_instance_valid(x) and (x as Actor).alive:
			out.append(x)
	return out


func _tick_skills(dt: float) -> void:
	_link_age += dt
	_decoy_cd = maxf(_decoy_cd - dt, 0.0)
	_echo_t = maxf(_echo_t - dt, 0.0)
	_mirror_t = maxf(_mirror_t - dt, 0.0)
	if _clone_t > 0.0:
		_tick_clone(dt)
	# 不动明王：血多时描边变金
	var g := duo.has("budong") and hp > max_hp * 0.7
	if g != _rim_gold and rig != null:
		_rim_gold = g
		rig.set_rim(Color(1.0, 0.82, 0.4) if g else Color(0.45, 0.95, 1.0), 0.9 if g else 0.6)


## 放完一招：记下来，下一招在窗口内接上就是连携
func _link_mark(skill: String) -> void:
	_link_from = skill
	_link_age = 0.0


## 现在放 to 能不能连携（不消耗），返回 LINKS 里那一条或空
func _link_peek(to: String) -> Dictionary:
	if _link_from == "":
		return {}
	for l: Dictionary in ArpgSkills.LINKS:
		if l["from"] == _link_from and l["to"] == to and _link_age <= float(l["win"]):
			return l
	return {}


## HUD 用：这一招现在接上去会触发连携吗（返回颜色，不会时 a = 0）
func link_glow(to: String) -> Color:
	var l := _link_peek(to)
	if l.is_empty():
		return Color(0, 0, 0, 0)
	if to == "dash" and cd["dash"] > 0.0 and _echo_t <= 0.0:
		return Color(0, 0, 0, 0)
	if to == "finish" and cd["finish"] > 0.0:
		return Color(0, 0, 0, 0)
	if to == "beam" and energy < beam_cost - 0.01:
		return Color(0, 0, 0, 0)
	return l["color"]


func _link_take(l: Dictionary) -> void:
	_link_from = ""
	_link_now = String(l["id"])
	var c: Color = l["color"]
	# 连携：金字横条 + 本色闪屏 + 一小下停顿，脚下两圈本色冲击
	Feel.I.pause_world(0.06)
	Feel.I.screen_flash(Color(c, 0.3), 3.0)
	Feel.I.callout(head_top() + Vector3(0, 0.6, 0), "连携 · " + String(l["name"]), c.lightened(0.25), 1.5)
	Vfx.I.shock_ring(global_position, c, 0.4, 4.5, 0.4)
	Vfx.I.shock_ring(global_position, Color(1, 0.95, 0.8), 0.2, 2.6, 0.3)
	Vfx.I.sheet("rune-cast", global_position, 3.4, c, 2.0, true, 0.0, 1.6)
	if Hud3D.I != null:
		Hud3D.I.link_flash(String(l["name"]), String(l["desc"]).get_slice("：", 0), c)
	Game.sfx("crit", -2.0)
	link_fired.emit(_link_now)


## 突进斩的颜色：连闪紫、血步红、雷切金、平时青
func _dash_color() -> Color:
	if _link_now == "xuebu":
		return SkillFx.BLOOD
	if _echo_live or _link_now == "canyue":
		return SkillFx.SHADOW
	if skr("thunder") > 0:
		return SkillFx.THUNDER
	return Color(0.35, 0.95, 1.0)


## 连招第四段：破风（飞行剑气）/ 回风（卷人）
func _combo_branch() -> void:
	var wr := skr("wave")
	if wr > 0:
		var w := HeroWave.new()
		w.hero = self
		w.dir = facing
		w.range_m = 7.0 + 2.0 * wr
		w.damage = (10.0 + 8.0 * wr) * power()
		w.bleed = 2 if wr >= 3 else 0
		get_parent().add_child(w)
		w.global_position = global_position + facing * 0.8
		Vfx.I.streaks(chest() + facing * 0.6, facing, Color(0.6, 1.0, 1.0), 6, 3.0, 0.2, 0.2, 0.14)
		Game.sfx("art", -6.0, 0.1, 1.2)
	var vr := skr("vortex")
	if vr > 0:
		var rr := 3.5 + vr
		var c := Color(0.45, 1.0, 0.85)
		SkillFx.ring_in(global_position, c, rr)
		var pulled := 0
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Foe
			if a == null or not a.alive:
				continue
			var to := global_position + facing * 1.2 - a.global_position
			to.y = 0
			var d := to.length()
			if d > rr + a.radius or d < 0.2:
				continue
			var info := HitInfo.make(self, a, (4.0 + 4.0 * vr) * power(), HitInfo.Weight.LIGHT)
			info.attacker = null
			info.dir = to.normalized()
			info.knock = 0.0 if a.is_boss else clampf(d - 0.8, 0.0, 6.0) * 10.0   # 击退衰减很快，速度 ≈ 距离 × 10 正好拉到面前
			info.hitstop = 0.03
			Vfx.I.streaks(a.chest(), to, c, 3, d * 0.8, 0.22, 0.15, 0.1)
			if Feel.I.on_hit(info):
				pulled += 1
		if pulled > 0:
			Feel.I.callout(head_top() + Vector3(0.6, 0.2, 0), "回风", c, 1.0)
			if vr >= 3:
				gain_energy(10.0)
		Game.sfx("dodge", -2.0, 0.1, 0.7)


## 影遁：翻滚起点留一道紫色影子，0.5 秒后炸开
func _leave_decoy() -> void:
	var r := skr("decoy")
	_decoy_cd = 1.5
	var p := global_position
	Vfx.I.ghost(rig, SkillFx.SHADOW, 0.55)
	Vfx.I.ground(p, "lm_circle_a", Color(SkillFx.SHADOW, 0.7), 1.0, 2.0 + 0.4 * r, 0.5, true, 0.2)
	var tw := get_tree().create_timer(0.5, false)
	tw.timeout.connect(func() -> void:
		if not is_inside_tree() or Vfx.I == null:
			return
		var rad := 2.2 + 0.4 * r
		Vfx.I.sheet("dark-explosion", p, 2.6 + 0.4 * r, Color(0.85, 0.6, 1.0), 2.2, false, 0.0, 1.5)
		Vfx.I.shock_ring(p, SkillFx.SHADOW, 0.4, rad * 2.0, 0.35)
		Vfx.I.streaks(p + Vector3(0, 0.8, 0), Vector3.UP, SkillFx.SHADOW, 6, 2.0, 0.22, PI, 0.14)
		Game.sfx("boom", -10.0, 0.1, 1.3)
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Foe
			if a == null or not a.alive or a.global_position.distance_to(p) > rad + a.radius:
				continue
			var info := HitInfo.make(self, a, (8.0 + 6.0 * r) * power(), HitInfo.Weight.HEAVY)
			info.attacker = null
			info.dir = (a.global_position - p).normalized()
			info.knock = 6.0
			if Feel.I.on_hit(info):
				on_skill_hit(a, info)
				if r >= 3:
					a.freeze(0.6 if not a.is_boss else 0.15))


## 踏风 / 血影：翻滚穿过的敌人
func _roll_through() -> void:
	var r := skr("slice")
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _roll_cut.has(a):
			continue
		var d := a.global_position - global_position
		d.y = 0
		if d.length() > radius + a.radius + 0.5:
			continue
		_roll_cut[a] = true
		var bl := 2 if duo.has("xueying") else 0
		if r > 0:
			var info := HitInfo.make(self, a, (4.0 + 4.0 * r) * power(), HitInfo.Weight.LIGHT)
			info.attacker = null
			info.dir = _roll_dir
			info.knock = 2.0
			info.bleed = 1 + bl
			info.bleed_mult = bleed_dmg
			info.hitstop = 0.03
			Vfx.I.cut_line(a.chest(), _roll_dir + Vector3(0, 0.5, 0), 2.4, Color(1, 1, 1), 0.18, 0.16, Color(0.45, 1.0, 0.85))
			if Feel.I.on_hit(info):
				on_skill_hit(a, info)
				if r >= 3:
					gain_energy(6.0)
		elif bl > 0:
			a.add_bleed(bl, bleed_dmg)
			Vfx.I.streaks(a.chest(), _roll_dir, SkillFx.BLOOD, 3, 1.4, 0.18, 0.4, 0.1)
			Feel.I.callout(a.head_top(), "血影", SkillFx.BLOOD, 0.6)


## 突进斩之后：雷切落雷、连闪开窗、残月满月、记连携
func _after_dash(seg: Vector3) -> void:
	var from := _dash_from
	var to := _dash_to
	if _link_now == "canyue":
		var rad := 3.2
		SkillFx.full_moon(to, rad)
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a == null or not a.alive or a.global_position.distance_to(to) > rad + a.radius:
				continue
			var info := HitInfo.make(self, a, 20.0 * power(), HitInfo.Weight.HEAVY)
			info.attacker = null
			info.dir = (a.global_position - to).normalized()
			info.knock = 8.0
			info.bleed = 1
			if Feel.I.on_hit(info):
				on_skill_hit(a, info)
	if _link_now == "xuebu":
		var mid := (from + to) * 0.5 + Vector3(0, 0.9, 0)
		Vfx.I.cut_line(mid, seg, seg.length() + 3.0, Color(1, 0.85, 0.85), 0.45, 0.4, SkillFx.BLOOD)
		for i in range(4):
			Vfx.I.pop(from.lerp(to, randf()) + Vector3(0, 0.9, 0), "magic_05", Color(1.0, 0.15, 0.2), 0.6, 2.2, 0.4)
	var tr := skr("thunder")
	if tr > 0:
		var dmg := 22.0 * power() * (0.25 + 0.25 * tr)
		get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
			if not is_inside_tree() or Vfx.I == null:
				return
			var n := maxi(int(seg.length() / 2.2), 2)
			for i in range(n + 1):
				SkillFx.bolt(from.lerp(to, float(i) / n))
			CamRig.I.shake(1, 1.0)
			Game.sfx("boom", -4.0, 0.1, 1.4)
			var s2 := to - from
			for f: Node in get_tree().get_nodes_in_group("foes"):
				var a := f as Foe
				if a == null or not a.alive:
					continue
				var k := clampf((a.global_position - from).dot(s2) / maxf(s2.length_squared(), 0.001), 0.0, 1.0)
				if (a.global_position - (from + s2 * k)).length() > 1.3 + a.radius:
					continue
				var info := HitInfo.make(self, a, dmg * randf_range(0.95, 1.1), HitInfo.Weight.HEAVY)
				info.attacker = null
				info.dir = Vector3.UP.cross(s2).normalized()
				info.knock = 3.0
				if Feel.I.on_hit(info):
					on_skill_hit(a, info)
					if tr >= 3:
						a.freeze(1.0 if not a.is_boss else 0.3)
						Vfx.I.sheet("stunned", a.head_top(), 1.0, SkillFx.THUNDER, 2.0, false, 1.0)
			Feel.I.callout(to + Vector3(0, 2.6, 0), "雷切", SkillFx.THUNDER, 1.0))
	if skr("echo") > 0 and not _echo_live:
		_echo_t = 1.5
		Vfx.I.ghost(rig, SkillFx.SHADOW, 0.8)
	_echo_live = false
	_link_mark("dash")


## 光束斩分支：裂空（两侧再斩两道）/ 长明（地上留光痕）；天落的天降光柱
func _beam_branch(dir: Vector3, gp: Vector3, bk: float) -> void:
	var sr := skr("split")
	if sr > 0:
		for sgn: float in [-1.0, 1.0]:
			var d2 := dir.rotated(Vector3.UP, sgn * 0.4)
			var f2 := global_position - d2 * 1.0 + Vector3(0, 1.0, 0)
			var t2 := global_position + d2 * 17.0 + Vector3(0, 0.3, 0)
			Vfx.I.beam(f2, t2, 1.5, 0.5)
			Vfx.I.shock_ring(gp + d2 * 15.0, SkillFx.LIGHT, 0.4, 3.5, 0.4)
			_beam_line(f2, t2, 1.1, 60.0 * power() * beam_mult * bk * (0.3 + 0.15 * sr))
	var br := skr("burn")
	if br > 0:
		var b := HeroBurn.new()
		b.hero = self
		b.from = gp + dir * 0.5
		b.to = gp + dir * 18.0
		b.life = 2.0 + br
		b.damage = (3.0 + 3.0 * br) * power()
		b.bleed = 1 if br >= 3 else 0
		get_parent().add_child(b)
		b.global_position = gp
	if _beam_fast:
		for i in range(5):
			var p := gp + dir * (3.0 + i * 3.6)
			get_tree().create_timer(0.05 * i, false).timeout.connect(func() -> void:
				if is_inside_tree():
					SkillFx.pillar(p, 12.0, 1.6, 0.45))


## 血爆每炸一个敌人：连携的额外特效
func _finish_link_fx(a: Actor) -> void:
	if _link_now == "shunyu":
		var c := a.chest()
		Vfx.I.cut_line(c, Vector3(1, 0.7, 0.3), 4.5, Color(1, 0.9, 0.9), 0.35, 0.3, SkillFx.BLOOD)
		Vfx.I.cut_line(c, Vector3(-1, 0.7, -0.3), 4.5, Color(1, 0.9, 0.9), 0.35, 0.3, SkillFx.BLOOD)
	elif _link_now == "fenxue" or _link_now == "guiyi":
		Vfx.I.sheet("spirit-flame", a.global_position, 2.4, Color(1.0, 0.65, 0.25), 2.4, false, 1.0)
		Vfx.I.streaks(a.chest(), Vector3.UP, Color(1.0, 0.75, 0.3), 5, 2.6, 0.3, 0.5, 0.14)


## 血爆之后：血莲溅血 / 饮血回血；瞬狱在突进路上补一道大斩线
func _finish_branch(blasted: Array, stacks: int) -> void:
	if _link_now == "shunyu":
		var seg := _dash_to - _dash_from
		if seg.length() > 0.5:
			Vfx.I.cut_line((_dash_from + _dash_to) * 0.5 + Vector3(0, 0.9, 0), seg, seg.length() + 4.0, Color(1, 0.85, 0.85), 0.5, 0.45, SkillFx.BLOOD)
	var lr := skr("lotus")
	if lr > 0 and not blasted.is_empty():
		var spread := 0
		for b: Actor in _alive(blasted):
			SkillFx.lotus(b.chest(), 1.8 + 0.2 * lr)
			for f: Node in get_tree().get_nodes_in_group("foes"):
				var a := f as Actor
				if a == null or not a.alive or blasted.has(a) or a.global_position.distance_to(b.global_position) > 3.5:
					continue
				a.add_bleed(1 + lr, bleed_dmg)
				Vfx.I.streaks(b.chest(), a.chest() - b.chest(), SkillFx.BLOOD, 2, a.global_position.distance_to(b.global_position), 0.25, 0.1, 0.12)
				spread += 1
		if spread > 0:
			Feel.I.callout(head_top() + Vector3(-0.6, 0.2, 0), "血莲 ×%d" % spread, SkillFx.BLOOD, 1.0)
	var dr := skr("drink")
	if dr > 0 and stacks > 0:
		var heal := minf(stacks * (0.5 + 0.5 * dr), max_hp * 0.25)
		for b: Variant in blasted:
			if is_instance_valid(b):
				SkillFx.drain((b as Actor).chest(), self, Color(1.0, 0.25, 0.3), 3)
		get_tree().create_timer(0.4, false).timeout.connect(func() -> void:
			if not is_inside_tree() or not alive:
				return
			hp = minf(hp + heal, max_hp)
			Feel.I.number(head_top(), "+%d" % int(heal), Color(1.0, 0.5, 0.55), 1.0)
			Vfx.I.pop(chest(), "magic_03", Color(1.0, 0.3, 0.35), 0.5, 2.2, 0.4))


## 技能命中之后的通用处理：吸血、修罗场、血涌
func on_skill_hit(a: Actor, info: HitInfo) -> void:
	_leech(info.damage)
	if info.crit and set_shura:
		_shura_splash(a, info.damage)
	_check_blood(a)


# ---------- 秘技 ----------

func _start_art() -> void:
	cd["art"] = art_cd
	_link_now = ""
	var lk := _link_peek("art")
	if not lk.is_empty():
		_link_take(lk)
	_art_k = 1.5 if _link_now == "fenglei" else 1.0
	art_hits.clear()
	var d := input_dir()
	var tgt := _auto_target(d if d != Vector3.ZERO else facing, 9.0)
	if tgt != null:
		face_to(tgt.global_position - global_position)
	elif d != Vector3.ZERO:
		face_to(d)
	if _link_now == "fenglei":
		# 风雷：身边劈下三道雷
		for i in range(3):
			var a := TAU * i / 3.0 + randf()
			var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.0)
			SkillFx.bolt(p)
			_aoe(p, 1.8, 15.0 * power(), 4.0, HitInfo.Weight.HEAVY)
	var r := skr(art_id())
	match art_id():
		"whirl":
			_whirl_tick = 0.0
			_set_state("whirl")
			Game.sfx("dodge", 0.0, 0.1, 0.6)
			Vfx.I.shock_ring(global_position, Color(1.0, 0.75, 0.4), 0.3, 4.0, 0.3)
		"disc":
			var n := 2 if r >= 3 else 1
			for i in range(n):
				var dk := HeroDisc.new()
				dk.hero = self
				dk.dir = facing.rotated(Vector3.UP, 0.0 if n == 1 else (0.28 if i == 0 else -0.28))
				dk.range_m = 9.0 + (2.0 if r >= 2 else 0.0)
				dk.damage = (10.0 + 6.0 * r) * power() * _art_k
				get_parent().add_child(dk)
				dk.global_position = global_position + facing * 0.6
			Game.sfx("slash_heavy", -2.0, 0.1, 1.3)
			Vfx.I.streaks(chest() + facing * 0.5, facing, Color(1.0, 0.8, 0.45), 5, 2.4, 0.2, 0.25, 0.12)
			_set_state("art_cast")
			_link_mark("art")
		"quake":
			iframes = maxf(iframes, 0.4)
			_set_state("quake")
			Game.sfx("art", -2.0)
		"clone":
			_clone_t = 4.0 + 2.0 * r
			_clone_atk = 0.3
			_clone_pos = global_position - facing * 1.4 + facing.cross(Vector3.UP) * 1.2
			Vfx.I.sheet("spawn-cast", _clone_pos, 3.4, Color(0.75, 0.55, 1.0), 2.0)
			Vfx.I.shock_ring(_clone_pos, SkillFx.SHADOW, 0.3, 3.0, 0.4)
			Feel.I.callout(head_top(), "分身", SkillFx.SHADOW, 1.0)
			Game.sfx("art", -4.0, 0.1, 1.2)
			_set_state("art_cast")
			_link_mark("art")


## 一圈范围伤害（秘技用），打中的记进 art_hits
func _aoe(p: Vector3, rad: float, dmg: float, kn: float, w: int, bleed_n: int = 0) -> int:
	var n := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := a.global_position - p
		d.y = 0
		if d.length() > rad + a.radius:
			continue
		var info := HitInfo.make(self, a, dmg * randf_range(0.95, 1.08), w)
		info.attacker = null
		info.dir = d.normalized() if d.length() > 0.1 else facing
		info.knock = kn
		info.bleed = bleed_n
		info.bleed_mult = bleed_dmg
		if w == HitInfo.Weight.LIGHT:
			info.hitstop = 0.03
		if Feel.I.on_hit(info):
			on_skill_hit(a, info)
			if not art_hits.has(a):
				art_hits.append(a)
			n += 1
	return n


## 旋风：边转边走，每 0.2 秒砍一圈
func _st_whirl(dt: float) -> void:
	var r := skr("whirl")
	var dur := 1.1 + 0.3 * r
	var d := input_dir()
	move_with_knock(d * move_speed * 0.65, dt)
	if rig != null:
		rig.rotation.y += dt * 22.0
	_target_pose(Poses.swing("spin", 1.0, 0.5, 0.0))
	_whirl_tick -= dt
	if _whirl_tick <= 0.0:
		_whirl_tick = 0.2
		var rad := 2.8
		var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), global_position + Vector3(0, 0.8, 0))
		Vfx.I.slash(xf, rad, 0.0, -TAU * 0.8, 0.2, Color(1, 1, 1), Color(1.0, 0.72, 0.35), 3.2, 0.6)
		Vfx.I.dust(global_position, 1.4, Color(0.6, 0.55, 0.45, 0.35))
		if r >= 3:
			for f: Node in get_tree().get_nodes_in_group("foes"):
				var a := f as Foe
				if a != null and a.alive and not a.is_boss and a.global_position.distance_to(global_position) < 5.0:
					var to := global_position - a.global_position
					to.y = 0
					a.knock = to.normalized() * 6.0
		_aoe(global_position, rad, (4.0 + 2.0 * r) * power() * _art_k, 1.5, HitInfo.Weight.LIGHT)
		Game.sfx("slash", -8.0, 0.15, 1.2)
	if _take_buffer(["roll"]) == "roll":
		_link_mark("art")
		_start_roll()
		return
	if st_t >= dur:
		_link_mark("art")
		_set_state("move")


## 震岳：跃起 0.3 秒后砸地
func _st_quake(dt: float) -> void:
	move_with_knock(facing * 3.0 if st_t < 0.3 else Vector3.ZERO, dt)
	var k := st_t / 0.6
	if rig != null:
		rig.position.y = sin(clampf(st_t / 0.3, 0.0, 1.0) * PI * 0.5) * 1.6 if st_t < 0.3 else 0.0
	_target_pose(Poses.swing("v_down", clampf(k / 0.5, 0, 1), clampf((k - 0.5) / 0.2, 0, 1), clampf((k - 0.7) / 0.3, 0, 1)))
	if st_t >= 0.3 and st_t - dt < 0.3:
		_slam()
	if st_t >= 0.6:
		_set_state("move")


func _slam() -> void:
	var r := skr("quake")
	var rad := 3.5 + 0.5 * r
	var p := global_position
	if rig != null:
		rig.position.y = 0.0
	Vfx.I.sheet("ground-slam", p, rad * 1.1, Color(1.0, 0.85, 0.6), 2.0, true)
	Vfx.I.shock_ring(p, Color(1.0, 0.75, 0.4), 0.5, rad * 2.2, 0.4)
	Vfx.I.shock_ring(p, Color(1, 1, 1), 0.3, rad * 1.4, 0.25)
	Vfx.I.dust(p, rad * 0.8, Color(0.55, 0.5, 0.42, 0.6))
	for i in range(8):
		var a := TAU * i / 8.0
		Vfx.I.scar(p + Vector3(cos(a), 0, sin(a)) * rad * 0.55, Vector3(cos(a), 0, sin(a)), 1.8, 2.0)
	Vfx.I.chips(p + Vector3(0, 0.3, 0), Vector3.UP, Color(0.45, 0.4, 0.35), 18, 9.0, 0.14)
	CamRig.I.shake(2, 1.3)
	CamRig.I.punch_zoom(0.4, 0.2)
	Game.sfx("boom", 0.0, 0.1, 0.8)
	var n := _aoe(p, rad, (10.0 + 10.0 * r) * power() * _art_k, 11.0, HitInfo.Weight.ULT)
	for a: Actor in _alive(art_hits):
		var fo := a as Foe
		if fo != null:
			fo.freeze(0.8 if not fo.is_boss else 0.2)
	if n > 0:
		Feel.I.slowmo(0.35, 0.25)
		Feel.I.callout(head_top() + Vector3(0.6, 0.3, 0), "震岳!", Color(1.0, 0.8, 0.45), 1.3)
	if r >= 3:
		# 火缝：四道裂开的火光
		for i in range(4):
			var a := TAU * i / 4.0 + PI / 4
			var dir := Vector3(cos(a), 0, sin(a))
			var b := HeroBurn.new()
			b.hero = self
			b.from = p + dir * 0.8
			b.to = p + dir * (rad + 1.0)
			b.life = 2.5
			b.damage = 5.0 * power()
			b.tint = Color(1.0, 0.5, 0.2)
			b.blob = 0.55
			b.width = 0.9
			get_parent().add_child(b)
			b.global_position = p
	_link_mark("art")


func _st_art_cast(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.cast(clampf(st_t / 0.15, 0, 1), st_t))
	if st_t > 0.12 and _try_actions(["attack", "roll", "dash", "beam", "finish"]):
		return
	if st_t >= 0.25:
		_set_state("move")


## 分身：一道紫色影子跟在身边（拷贝主角当下的样子），隔一会儿瞬到最近的敌人身边砍一刀
func _tick_clone(dt: float) -> void:
	_clone_t -= dt
	var r := skr("clone")
	var home := global_position - facing * 1.4 + facing.cross(Vector3.UP) * 1.2
	_clone_pos = _clone_pos.lerp(home, 1.0 - exp(-4.0 * dt))
	_clone_ghost -= dt
	if _clone_ghost <= 0.0:
		_clone_ghost = 0.07 if Vfx.I.lod > 0 else 0.14
		SkillFx.ghost_at(rig, _clone_pos - global_position, SkillFx.SHADOW, 0.16)
	_clone_atk -= dt
	if _clone_atk <= 0.0:
		_clone_atk = 0.65
		var best: Actor = null
		var bd := 7.0
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a != null and a.alive and a.global_position.distance_to(_clone_pos) < bd:
				bd = a.global_position.distance_to(_clone_pos)
				best = a
		if best != null:
			var to := best.global_position - _clone_pos
			to.y = 0
			var from := _clone_pos
			_clone_pos = best.global_position - to.normalized() * 1.0
			Vfx.I.cut_line((from + _clone_pos) * 0.5 + Vector3(0, 0.9, 0), to, to.length() + 1.0, Color(1, 0.95, 1), 0.2, 0.16, SkillFx.SHADOW)
			var xf := Transform3D(Basis(Vector3.UP, atan2(to.x, to.z) + PI), _clone_pos + Vector3(0, 0.9, 0))
			Vfx.I.slash(xf, 2.2, deg_to_rad(-100), deg_to_rad(100), 0.18, Color(1, 1, 1), SkillFx.SHADOW, 3.0)
			var info := HitInfo.make(self, best, (5.0 + 3.0 * r) * power() * randf_range(0.95, 1.08), HitInfo.Weight.LIGHT)
			info.attacker = null
			info.dir = to.normalized()
			info.knock = 3.0
			info.bleed = 1 if r >= 3 else 0
			info.bleed_mult = bleed_dmg
			if Feel.I.on_hit(info):
				on_skill_hit(best, info)
				if not art_hits.has(best):
					art_hits.append(best)
	if _clone_t <= 0.0:
		Vfx.I.sheet("dark-explosion", _clone_pos, 2.2, Color(0.8, 0.6, 1.0), 1.8)


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
	_roll_cut.clear()
	_link_mark("roll")
	if duo.has("liuguang"):
		gain_energy(6.0)
		Vfx.I.streaks(chest(), Vector3.UP, SkillFx.LIGHT, 3, 1.2, 0.2, 0.5, 0.1)
	if skr("decoy") > 0 and _decoy_cd <= 0.0:
		_leave_decoy()
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
		Vfx.I.ghost(rig, Color(0.3, 0.85, 1.0) if skr("slice") == 0 else Color(0.45, 1.0, 0.85), 0.28)
	if skr("slice") > 0 or duo.has("xueying"):
		_roll_through()
	if k > 0.7 and _try_actions(["attack", "dash", "art", "swap"]):
		return
	if k >= 1.0:
		if set_wind:
			_wind_t = 1.2
			cd["dash"] = maxf(cd["dash"] - 0.8, 0.0)
		if weapon_id == "crossbow":
			_roll_crit = true
		if roll_bolt > 0.0:
			_roll_thunder()
		_set_state("move")
		_move = _roll_dir * move_speed * 0.7
		_blend = 0.5


## 雷纹靴：翻滚落地放一圈雷
func _roll_thunder() -> void:
	Vfx.I.shock_ring(global_position, Color(0.6, 0.85, 1.0), 0.3, 2.6, 0.3)
	Vfx.I.streaks(global_position + Vector3(0, 0.4, 0), Vector3.UP, Color(0.7, 0.9, 1.0), 6, 1.6, 0.15, PI, 0.12)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or a.global_position.distance_to(global_position) > 2.6 + a.radius:
			continue
		var info := HitInfo.make(self, a, roll_bolt * dmg_mult, HitInfo.Weight.LIGHT)
		info.attacker = null
		info.knock = 3.0
		info.stun = 0.3
		Feel.I.on_hit(info)


# ---------- 受击 ----------

func take_hit(info: HitInfo) -> bool:
	info.damage *= taken_mult
	if _mirror_t > 0.0:
		info.damage *= 0.6   # 双修·明镜
	if invincible:
		info.damage = 0.0
	if state == "dash":
		return false
	if golden and iframes <= 0.0 and alive and info.damage > 0.0:
		# 金身挡掉这一下
		golden = false
		_guard_t = 0.0
		iframes = 0.4
		Vfx.I.shock_ring(global_position, Color(1.0, 0.85, 0.4), 0.5, 3.5, 0.35)
		Vfx.I.impact_flash(chest(), 2.0, Color(1.0, 0.85, 0.4))
		Feel.I.callout(head_top(), "挡", Color(1.0, 0.85, 0.45), 0.8)
		Game.sfx("parry", -2.0)
		return false
	var armored := weapon_id == "greatsword" and state == "attack"
	if armored:
		info.damage *= 0.85
	var ok := super.take_hit(info)
	if ok:
		dmg_total += info.damage
		hits_taken += 1
		_on_hurt(info)
		if OS.get_cmdline_user_args().has("--hitlog"):
			print("HIT %s %.1f hp=%.0f" % [info.attacker.get("kind") if info.attacker != null else "?", info.damage, hp])
	if ok and alive:
		Feel.I.hurt_pulse(0.7)
		Game.sfx("hurt", -2.0)
		if (info.weight >= 1 or state in ["move", "heal"]) and not armored:
			step_i = -1
			_set_state("hurt")
			_blend = 0.8
		iframes = 0.35
	return ok


## 挨打后的装备效果：荆棘甲反弹、灵纹袍回气、不动套反震
func _on_hurt(info: HitInfo) -> void:
	if hurt_energy > 0.0:
		gain_energy(hurt_energy / maxf(energy_mult, 0.01))
	var src := info.attacker
	if thorns > 0.0 and src != null and is_instance_valid(src) and src != self and src.alive and src.global_position.distance_to(global_position) < 3.5:
		var r := HitInfo.make(self, src, info.damage / maxf(taken_mult, 0.3) * thorns, HitInfo.Weight.LIGHT)
		r.attacker = null
		r.knock = 4.0
		Vfx.I.chips(src.chest(), Vector3.UP, Color(0.6, 0.8, 0.5), 6, 5.0, 0.07)
		Feel.I.on_hit(r)
	if set_iron and _iron_t <= 0.0 and alive:
		_iron_t = 1.0
		Vfx.I.shock_ring(global_position, Color(0.6, 0.75, 1.0), 0.4, 3.2, 0.35)
		Feel.I.callout(head_top(), "不动", Color(0.6, 0.75, 1.0), 0.6)
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a == null or not a.alive or a.global_position.distance_to(global_position) > 3.2 + a.radius:
				continue
			var hi := HitInfo.make(self, a, 25.0 * dmg_mult, HitInfo.Weight.HEAVY)
			hi.attacker = null
			hi.knock = 9.0
			Feel.I.on_hit(hi)


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
	# 连携：翻滚 → 突进斩（残月，远四成）；血爆 → 突进斩（血步）
	_link_now = ""
	var lk := _link_peek("dash")
	if not lk.is_empty():
		_link_take(lk)
	_dash_len_k = 1.4 if _link_now == "canyue" else 1.0
	# 路径碰到墙就提前停
	var len := dash_len * _dash_len_k
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 0.6, 0) + facing * len, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		len = maxf((hit["position"] as Vector3 - (global_position + Vector3(0, 0.6, 0))).length() - radius - 0.2, 0.5)
	_dash_to = global_position + facing * len
	_set_state("dash_ready")
	_blend = 0.5
	if _echo_live:
		_echo_t = 0.0      # 连闪这一下不进冷却
	else:
		cd["dash"] = dash_cd
	if _link_now == "xuebu":
		cd["dash"] = dash_cd * 0.5
	Vfx.I.telegraph_rect(_dash_from, _dash_to, 1.6, Color(_dash_color(), 0.55), dash_warn + 0.05)
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
		Vfx.I.ghost(rig, _dash_color(), 0.18 + 0.03 * i)
	global_position = _dash_to
	var seg := _dash_to - _dash_from
	var n := 0
	_dash_hits.clear()
	var dk := 1.0
	if _link_now == "xuebu":
		dk = 1.5
	if _echo_live and skr("echo") >= 3:
		dk *= 1.4
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var t := clampf((a.global_position - _dash_from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		var closest := _dash_from + seg * t
		if (a.global_position - closest).length() <= 0.8 + a.radius:
			# 会心原来只是看着亮（伤害没乘），现在和连招一样吃会心率和会心伤害
			var crit := randf() < 0.2 + crit_bonus or _wind_t > 0.0
			var info := HitInfo.make(self, a, 22.0 * power() * dk * (crit_mult if crit else 1.0) * randf_range(0.95, 1.1), HitInfo.Weight.HEAVY)
			info.dir = (a.global_position - closest).normalized() if (a.global_position - closest).length() > 0.1 else facing
			info.knock = 7.0
			info.bleed = 2 + bleed_bonus + (3 if _link_now == "xuebu" else 0) + (2 if crit and duo.has("xueren") else 0)
			info.bleed_mult = bleed_dmg
			info.gain = 8.0
			info.crit = crit
			info.attacker = null    # 瞬移后主角不停顿，只让敌人停
			if Feel.I.on_hit(info):
				gain_energy(8.0)
				on_skill_hit(a, info)
			_dash_hits.append(a)
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
		Feel.I.callout(head_top() + Vector3(0.6, 0.3, 0), "连闪!" if _echo_live else "突进斩!", _dash_color().lightened(0.3), 1.1)
	_wind_t = 0.0
	_after_dash(seg)
	_set_state("dash")
	_blend = 1.0


func _st_dash(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.swing("h_rl", 1.0, 1.0, clampf(st_t / 0.3, 0, 1)))
	if st_t > 0.12 and _try_actions(["attack", "roll", "finish", "beam", "art"]):
		return
	if st_t >= 0.3:
		_set_state("move")


# ---------- 光束斩 ----------

func _start_beam() -> void:
	energy = clampf(energy - beam_cost + (max_energy * 0.4 if set_light else 0.0), 0.0, max_energy)   # 天光：返还 40%
	energy_changed.emit()
	_link_now = ""
	var lk := _link_peek("beam")
	if not lk.is_empty():
		_link_take(lk)
	_beam_fast = _link_now == "tianluo"
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
	var dur := 0.75 if not _beam_fast else 0.38
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
	var wide := 1.6 if _beam_fast else 1.0
	Vfx.I.beam(from, to, 2.4 * wide, 0.6)
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
	_beam_hits.clear()
	var bk := 1.3 if _beam_fast else 1.0
	_beam_line(from, to, 1.5 * wide, 60.0 * power() * beam_mult * bk)
	_beam_branch(dir, gp, bk)
	_link_mark("beam")
	if duo.has("mingjing"):
		_mirror_t = 4.0
		Vfx.I.shock_ring(gp, Color(0.7, 1.0, 0.9), 0.4, 3.6, 0.45)
		Feel.I.callout(head_top(), "明镜", Color(0.7, 1.0, 0.9), 0.8)
	Feel.I.callout(head_top() + Vector3(0.6, 0.5, 0), "光束斩!", Color(0.85, 1.0, 1.0), 1.4)


## 一道光束的判定：from → to 的线段，半宽 half_w
func _beam_line(from: Vector3, to: Vector3, half_w: float, dmg: float) -> void:
	var dir := (to - from).normalized()
	var seg := to - from
	seg.y = 0
	var f2 := Vector3(from.x, 0, from.z)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _beam_hits.has(a):
			continue
		var t := clampf((a.global_position - f2).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest := f2 + seg * t
		if (a.global_position - closest).length() <= half_w + a.radius:
			var info := HitInfo.make(self, a, dmg * randf_range(0.95, 1.1), HitInfo.Weight.ULT)
			info.dir = Vector3(dir.x, 0, dir.z).normalized()
			info.knock = 12.0
			info.bleed = 3 if set_light else 1
			info.crit = true
			info.attacker = null
			_beam_hits.append(a)
			if Feel.I.on_hit(info):
				_check_blood(a)


# ---------- 终结技 ----------

func _start_finish() -> void:
	var lk := _link_peek("finish")
	var r := _finish_r(String(lk.get("id", "")))
	var any := false
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a != null and a.alive and a.bleed > 0 and a.global_position.distance_to(global_position) < r:
			any = true
	# 瞬狱 / 焚血：突进斩斩过的、光束照到的敌人不出血也能炸
	var lid := String(lk.get("id", ""))
	var pre := _alive(_dash_hits if lid == "shunyu" else (_beam_hits if lid == "fenxue" else (art_hits if lid == "guiyi" else [])))
	for a: Actor in pre:
		if a.global_position.distance_to(global_position) < r:
			any = true
	if not any:
		Feel.I.callout(head_top(), "没有出血的敌人", Color(0.85, 0.6, 0.6), 0.7)
		return
	_link_now = ""
	if not lk.is_empty():
		_link_take(lk)
		for a: Actor in pre:
			a.add_bleed(4 if lid == "guiyi" else 3, bleed_dmg)
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


## 血爆的范围（瞬狱大四成）
func _finish_r(link_id: String) -> float:
	return 10.5 if link_id == "shunyu" else 7.5


func _detonate() -> void:
	var n := 0
	var total := 0
	var r := _finish_r(_link_now)
	var blasted := []
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or a.bleed <= 0:
			continue
		if a.global_position.distance_to(global_position) > r:
			continue
		var stacks := a.bleed
		a.bleed = 0
		total += stacks
		blasted.append(a)
		_finish_link_fx(a)
		var info := HitInfo.make(self, a, (14.0 + 16.0 * stacks) * power() * finish_mult, HitInfo.Weight.ULT)
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
	_finish_branch(blasted, total)
	if n > 0:
		_link_mark("finish")
	_link_now = ""
	if n >= 5:
		ArpgAch.unlock("burst_5")
	Game.sfx("execute", 0.0)
	Feel.I.callout(head_top() + Vector3(0.6, 0.5, 0), "血爆 ×%d" % n, Color(1.0, 0.35, 0.35), 1.3)


# ---------- 药葫芦 ----------

func _st_heal(dt: float) -> void:
	move_with_knock(Vector3.ZERO, dt)
	_target_pose(Poses.cast(clampf(st_t / 0.3, 0, 1), st_t))
	if st_t >= 0.5 and st_t - dt < 0.5:
		gourds -= 1
		drinks += 1
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
	if rig.offhand != null:
		# 鸳鸯双刀：左手那把和右手镜像着挥
		var b: Vector3 = p.get("blade", Poses.dirv(-5, -25))
		p = p.duplicate()
		p["shield"] = Vector3(b.x, b.y, -b.z)
	rig.apply(p)


func _update_ring() -> void:
	if foot_ring == null:
		return
	foot_ring.global_position = global_position + Vector3(0, 0.04, 0)
	var m: ShaderMaterial = foot_ring.material_override
	m.set_shader_parameter("dash", 1.0 - float(cd["dash"]) / dash_cd)
	m.set_shader_parameter("finish", 1.0 - float(cd["finish"]) / finish_cd)
	m.set_shader_parameter("energy", minf(energy / beam_cost, 1.0))
