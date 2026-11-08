class_name FinaleFoe
extends Act3Foe
## 终章隐藏头目 · 烛王（boss10）：烛国最后的王，把第八盏灯点在自己胸口，以国为薪。
##   一阶段：大剑连斩、跳劈、刀气；隔一阵叫两个烛国甲士；隔一阵“灯涌”——胸口的灯往外推两圈火浪（翻滚穿过去），
##          推完灯露在外面，他自己也站不稳：三秒内挨打伤害 +50%（这是打他的窗口）
##   半血“燃国”：七盏灯的回响轮着来（长明帝的光柱、焦明的天火、霍长风的幽骑列阵），灯涌更勤，叫人时多一个披火骨

const KING := {"name": "烛王", "model": "boss_king", "weapon": "sword2", "wlen": 56.0, "tint": Color(0.72, 0.56, 0.44), "mono": 0.45, "k": 2.15,
	"hp": 2500.0, "speed": 3.5, "detect": 40.0, "range": 3.4, "dmg": 30.0, "windup": 0.5, "attack": "boss", "poise": 180.0, "coins": 260, "boss": true,
	"rage": "第八灯·燃国", "rage_line": "烛国——都起来！", "head": "barbarian"}
const MINE := ["k_surge", "k_summon"]
const ECHOES := ["e_pillar", "f_rain", "h_rank"]
const EXPOSE_T := 3.0
const EXPOSE_K := 1.5
const C_LAMP := Color(1.0, 0.5, 0.22)

var _k_surge := 9.0          # 下一次灯涌
var _k_summon := 5.0         # 下一次叫甲士
var _k_echo := 3.0           # 二阶段：下一次回响
var _echo_i := -1
var _exposed := 0.0          # 灯露在外面的剩余时间
var _heart: OmniLight3D
var _heart_fx: Node3D


func setup_kind(k: String, hp_scale: float = 1.0, dmg_mult: float = 1.0) -> void:
	if k != "boss10":
		super.setup_kind(k, hp_scale, dmg_mult)
		return
	kind = k
	data = KING
	max_hp = float(data["hp"]) * hp_scale
	hp = max_hp
	dmg_scale = dmg_mult
	max_poise = float(data["poise"])
	poise = max_poise
	is_boss = true
	display_name = String(data["name"])


func _ready() -> void:
	super._ready()
	if kind != "boss10":
		return
	rig.set_rim(C_LAMP, 0.5)
	rig.set_glow(Color(0.2, 0.07, 0.02))
	# 胸口那盏灯：一团火 + 一盏灯光，跟着人走
	_heart = OmniLight3D.new()
	_heart.light_color = C_LAMP
	_heart.light_energy = 2.4
	_heart.omni_range = 7.5
	_heart.position = Vector3(0, 1.5, 0.35)
	add_child(_heart)
	if Vfx.I != null:
		_heart_fx = Vfx.I.sheet("spirit-flame", chest() + Vector3(0, 0.1, 0.3), 1.1, C_LAMP, 2.2, false, 1.0e6)
		if _heart_fx != null:
			_heart_fx.reparent(self)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if kind != "boss10" or not alive:
		return
	if _exposed > 0.0:
		_exposed -= delta
	if _heart != null:
		var beat := 0.5 + 0.5 * sin(_anim_t * (5.0 if _boss_phase == 0 else 8.0))
		_heart.light_energy = (2.0 + 1.2 * beat) * (2.0 if _exposed > 0.0 else 1.0)


func _hint_text() -> String:
	if kind == "boss10":
		return "烛王 · 灯涌之后他胸口的灯露出来，那时候砍最疼"
	return super._hint_text()


func _st_chase(dt: float) -> void:
	if kind != "boss10" or target == null:
		super._st_chase(dt)
		return
	var dist := _dist_to_target()
	_k_surge -= dt
	_k_summon -= dt
	if _boss_phase >= 1:
		_k_echo -= dt
	if _cool <= 0.0 and _retreat_t <= 0.0:
		if _k_surge <= 0.0 and _get_token():
			_k_surge = randf_range(13.0, 16.0) if _boss_phase == 0 else randf_range(9.0, 11.0)
			_begin_attack("k_surge")
			return
		if _k_summon <= 0.0 and get_tree().get_nodes_in_group("foes").size() < 7 and _get_token():
			_k_summon = randf_range(15.0, 18.0) if _boss_phase == 0 else randf_range(12.0, 14.0)
			_begin_attack("k_summon")
			return
		if _boss_phase >= 1 and _k_echo <= 0.0 and _get_token():
			_k_echo = randf_range(7.0, 9.0)
			_echo_i = (_echo_i + 1) % ECHOES.size()
			_begin_attack(String(ECHOES[_echo_i]))
			return
		if dist > 5.0 and randf() < dt * 1.2 and _get_token():
			_begin_attack("boss_leap" if randf() < 0.55 else "boss_wave")
			return
	# Act3Foe 按种类出招的那一段对 boss10 不起作用，最后落到 Foe 的追人、近身出手
	super._st_chase(dt)


func _choose_attack(dist: float) -> String:
	if kind == "boss10":
		var r := randf()
		return "boss_combo" if r < 0.6 else ("boss_wave" if r < 0.8 else "boss_leap")
	return super._choose_attack(dist)


func _windup_time() -> float:
	match _atk:
		"k_surge":
			return 1.0 if _boss_phase == 0 else 0.8
		"k_summon":
			return 0.9
	return super._windup_time()


func _begin_attack(kind_: String) -> void:
	if not (kind_ in MINE):
		super._begin_attack(kind_)
		return
	_atk = kind_
	_did_hit = false
	_combo_n = 0
	_set_state("windup")
	_blend = 0.3
	var wt := _windup_time()
	if kind_ == "k_surge":
		Vfx.I.ground(global_position, "magic_01", Color(C_LAMP, 0.85), 0.5, 6.0, wt + 0.3)
		Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "灯涌 · 滚过去", Color(1.0, 0.6, 0.3), 1.2)
	else:
		Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.7, 0.4, 0.8), 0.5, 5.0, wt + 0.3)
		Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "列阵！", Color(1.0, 0.75, 0.45), 1.0)
	Game.sfx("danger", -8.0)


func _st_windup(dt: float) -> void:
	super._st_windup(dt)
	if state != "windup" or not (_atk in MINE):
		return
	var k := clampf(st_t / _windup_time(), 0.0, 1.0)
	_pose = Poses.cast(k, _anim_t) if _atk == "k_summon" else Poses.windup("enemy_v", k, st_t)
	rig.set_glow(C_LAMP * (0.25 + 0.7 * k))
	if _heart != null:
		_heart.light_energy = 2.0 + 5.0 * k


func _st_attack(dt: float) -> void:
	if not (_atk in MINE):
		super._st_attack(dt)
		return
	var k := st_t / 0.5
	_pose = Poses.cast(1.0, _anim_t)
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit:
		_did_hit = true
		if _atk == "k_surge":
			_surge()
		else:
			_call_guard()
	if k >= 1.0:
		if _atk == "k_surge":
			_expose()
		else:
			_end_attack()


## 灯涌：胸口的灯往外推两圈火浪（一阶段两圈、二阶段三圈），翻滚的无敌帧能穿过去
func _surge() -> void:
	var n := 2 if _boss_phase == 0 else 3
	for i in range(n):
		var t := TideRing.new()
		t.owner_foe = self
		t.damage = float(data["dmg"]) * 0.85 * dmg_scale
		t.color = C_LAMP
		t.elem = "fire"
		t.speed = 7.0 + i * 0.6
		t.max_r = 22.0
		t.delay = i * 0.75
		get_parent().add_child(t)
		t.global_position = Vector3(global_position.x, 0.0, global_position.z)
	Vfx.I.shock_ring(global_position, C_LAMP, 0.4, 4.0, 0.35)
	Vfx.I.explosion(chest(), 0.9)
	CamRig.I.shake(2)
	Game.sfx("boom", -3.0, 0.0, 0.8)


## 灯涌推完：灯露在外面，人站不稳
func _expose() -> void:
	_exposed = EXPOSE_T
	Feel.I.callout(head_top() + Vector3(0, 0.6, 0), "灯露出来了 · 砍！", Color(1.0, 0.85, 0.5), 1.4)
	Vfx.I.pop(chest(), "light_01", C_LAMP, 0.6, 3.0, 0.4)
	_release()
	rig.position.y = 0
	hit_stun = EXPOSE_T * 0.8
	_set_state("stagger")


## 叫烛国甲士（二阶段多一个披火骨）
func _call_guard() -> void:
	var main := get_parent()
	var ks := ["armored", "armored"] if _boss_phase == 0 else ["armored", "flameskel", "armored"]
	for i in range(ks.size()):
		var a := TAU * i / ks.size() + randf() * 0.6
		var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.8
		if main.has_method("_spawn_foe"):
			main._spawn_foe(String(ks[i]), p, i * 0.25)
	Game.sfx("boom", -6.0)


func take_hit(info: HitInfo) -> bool:
	if kind == "boss10" and _exposed > 0.0 and alive:
		info.damage *= EXPOSE_K
		Vfx.I.pop(chest() - info.dir * 0.4, "spark_05", Color(1.0, 0.85, 0.5), 0.45, 1.8, 0.14)
	return super.take_hit(info)


func _on_rage() -> void:
	if kind != "boss10":
		super._on_rage()
		return
	_k_echo = 2.0
	_k_surge = minf(_k_surge, 4.0)
	rig.set_glow(Color(0.35, 0.12, 0.03))


func _atk_elem() -> String:
	if _atk == "k_surge":
		return "fire"
	return super._atk_elem()


func fx_color() -> Color:
	if kind == "boss10":
		return C_LAMP
	return super.fx_color()


func die(impulse: Vector3) -> void:
	if kind == "boss10" and is_instance_valid(_heart_fx):
		_heart_fx.queue_free()
	super.die(impulse)
