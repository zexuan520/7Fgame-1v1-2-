class_name Act3Foe
extends Foe
## 第三幕“出山”的敌人。第三幕里刷出来的怪都用这个类（没在 TYPES3 里的种类照旧走 Foe.TYPES）：
##   柳溪村：灯兵（被灰灯点起来的村民，倒下后有几成会再站起来一次）、稻草人（田里不动，走近才扑）、镇灯卫（盾 + 长枪）、纵火手（扔火罐）
##   官道驿站：驿卒（快，刺完就退、会闪）、冲骑（长枪，远了就直线冲锋）、镇魂铃 wardbell（摇铃，身边同伴几秒内减伤一半）
##   长明宫：金吾卫（金甲，先破韧，会跳劈）、提炉官（扔香炉）、宫灯魂（飘着，会瞬移到你身边施法）、续命司司主陆长庚（精英）
##   头目：火师焦明（火罐、火场一圈；半血整个村子烧起来、天上落火）、押灯将霍长风（三连刺、幽骑列阵冲锋；半血箭雨）、
##        长明帝（四盏护体灯：亮一盏少吃两成伤害、慢慢回血，砸灭一盏踉跄一下；金光扇、光柱、召金吾卫；半血宫人魂列阵）

const TYPES3 := {
	# ---------- 第七层 · 柳溪村 ----------
	"lampman": {"name": "灯兵", "model": "barbarian", "weapon": "skel_axe", "wlen": 30.0, "tint": Color(0.78, 0.8, 0.86), "mono": 0.85, "k": 0.95,
		"hp": 52.0, "speed": 4.2, "detect": 15.0, "range": 2.2, "dmg": 11.0, "windup": 0.5, "attack": "slash", "poise": 0.0, "coins": 3, "rise": 0.35,
		"hint": "灯兵 · 倒下了还可能再站起来"},
	"scarecrow": {"name": "稻草人", "model": "barbarian", "weapon": "staff", "wlen": 34.0, "tint": Color(1.25, 1.02, 0.6), "mono": 0.55, "k": 1.0,
		"hp": 64.0, "speed": 5.4, "detect": 16.0, "range": 2.5, "dmg": 13.0, "windup": 0.36, "attack": "lunge", "poise": 0.0, "coins": 4,
		"hint": "稻草人 · 别走太近"},
	"lampguard": {"name": "镇灯卫", "model": "knight", "weapon": "spear", "wlen": 58.0, "tint": Color(0.95, 0.78, 0.6), "mono": 0.7, "k": 1.1,
		"hp": 110.0, "speed": 3.5, "detect": 14.0, "range": 4.2, "dmg": 15.0, "windup": 0.6, "attack": "thrust", "poise": 20.0, "coins": 6,
		"offhand": "shield_f", "olen": 26.0, "guard": 5.0, "hint": "镇灯卫 · 盾挡正面，枪长，绕后"},
	"torcher": {"name": "纵火手", "model": "rogue", "weapon": "", "wlen": 0.0, "tint": Color(1.0, 0.68, 0.5), "mono": 0.8, "k": 0.95,
		"hp": 55.0, "speed": 4.0, "detect": 16.0, "range": 12.0, "dmg": 8.0, "windup": 0.75, "attack": "lob", "poise": 0.0, "coins": 4, "keep": 8.0, "elem": "fire",
		"hint": "纵火手 · 别站进橙圈"},
	# ---------- 第八层 · 官道驿站 ----------
	"courier": {"name": "驿卒", "model": "rogue", "weapon": "dagger", "wlen": 22.0, "tint": Color(0.82, 0.88, 1.0), "mono": 0.9, "k": 0.95,
		"hp": 58.0, "speed": 5.6, "detect": 16.0, "range": 2.6, "dmg": 12.0, "windup": 0.32, "attack": "lunge", "poise": 0.0, "coins": 4,
		"hitrun": true, "dodge": 0.3, "hint": "驿卒 · 刺完就跑，会闪"},
	"lancer": {"name": "冲骑", "model": "knight", "weapon": "spear", "wlen": 62.0, "tint": Color(0.85, 0.88, 1.05), "mono": 0.75, "k": 1.2,
		"hp": 135.0, "speed": 3.4, "detect": 16.0, "range": 4.4, "dmg": 18.0, "windup": 0.6, "attack": "thrust", "poise": 30.0, "coins": 7,
		"hint": "冲骑 · 隔远了会冲，引它撞墙"},
	"wardbell": {"name": "镇魂铃", "model": "mage", "weapon": "staff", "wlen": 34.0, "tint": Color(0.8, 0.9, 1.05), "mono": 0.7, "k": 1.0,
		"hp": 72.0, "speed": 3.4, "detect": 16.0, "range": 9.0, "dmg": 10.0, "windup": 0.8, "attack": "aura", "poise": 0.0, "coins": 6, "keep": 8.0,
		"aura": "ward", "offhand": "lantern_h", "olen": 26.0, "hint": "镇魂铃 · 先杀它，铃一响旁边的减伤一半"},
	"ghostrider": {"name": "幽骑", "model": "knight", "weapon": "spear", "wlen": 60.0, "tint": Color(0.7, 0.85, 1.35), "mono": 1.0, "phantom": true, "k": 1.15,
		"hp": 9999.0, "speed": 3.0, "detect": 40.0, "range": 2.6, "dmg": 16.0, "windup": 0.8, "attack": "charge", "poise": 999.0, "coins": 0},
	# ---------- 第九层 · 长明宫 ----------
	"goldguard": {"name": "金吾卫", "model": "knight", "weapon": "axe2", "wlen": 44.0, "tint": Color(1.35, 1.08, 0.55), "mono": 0.6, "k": 1.2,
		"hp": 165.0, "speed": 3.3, "detect": 14.0, "range": 2.8, "dmg": 20.0, "windup": 0.68, "attack": "heavy", "poise": 55.0, "coins": 9, "armor": 0.4,
		"hint": "金吾卫 · 金甲挡刀，先打破韧"},
	"censer": {"name": "提炉官", "model": "mage", "weapon": "lantern_h", "wlen": 30.0, "tint": Color(0.95, 0.55, 0.5), "mono": 0.7, "k": 1.0,
		"hp": 70.0, "speed": 3.2, "detect": 16.0, "range": 12.0, "dmg": 9.0, "windup": 0.8, "attack": "lob", "poise": 0.0, "coins": 5, "keep": 8.5, "elem": "fire",
		"hint": "提炉官 · 香炉落地就烧"},
	"palaceghost": {"name": "宫灯魂", "model": "rogue", "weapon": "", "wlen": 0.0, "tint": Color(1.25, 0.95, 1.1), "mono": 1.0, "k": 0.9,
		"hp": 48.0, "speed": 3.6, "detect": 18.0, "range": 10.0, "dmg": 13.0, "windup": 0.65, "attack": "rune", "poise": 0.0, "coins": 4, "keep": 7.0, "elem": "magic",
		"offhand": "lantern_h", "olen": 26.0, "hint": "宫灯魂 · 会闪到你身边，看脚下"},
	"courtghost": {"name": "宫人魂", "model": "rogue", "weapon": "sword", "wlen": 32.0, "tint": Color(1.4, 1.1, 0.75), "mono": 1.0, "phantom": true, "k": 1.0,
		"hp": 9999.0, "speed": 3.0, "detect": 40.0, "range": 2.6, "dmg": 16.0, "windup": 0.8, "attack": "charge", "poise": 999.0, "coins": 0},
	"chief": {"name": "司主陆长庚", "model": "mage", "weapon": "sword", "wlen": 34.0, "tint": Color(0.72, 0.72, 0.8), "mono": 0.8, "k": 1.15,
		"hp": 460.0, "speed": 4.4, "detect": 30.0, "range": 2.6, "dmg": 17.0, "windup": 0.45, "attack": "slash", "poise": 60.0, "coins": 25, "dodge": 0.25,
		"hint": "陆长庚 · 续命司司主"},
	"lampnode": {"name": "护体灯", "model": "skel_minion", "weapon": "", "wlen": 0.0, "tint": Color(1, 1, 1), "k": 1.3,
		"hp": 95.0, "speed": 0.0, "detect": 0.0, "range": 0.0, "dmg": 0.0, "windup": 1.0, "attack": "none", "poise": 999.0, "coins": 0,
		"hint": "护体灯 · 砸灭它，皇帝就护不住自己"},
	# ---------- 头目 ----------
	"boss7": {"name": "火师焦明", "model": "mage", "weapon": "staff", "wlen": 40.0, "tint": Color(1.2, 0.62, 0.45), "mono": 0.4, "k": 1.6,
		"hp": 1150.0, "speed": 3.7, "detect": 40.0, "range": 3.2, "dmg": 21.0, "windup": 0.55, "attack": "boss", "poise": 140.0, "coins": 130, "boss": true,
		"rage": "火师·燎原", "rage_line": "烧干净了，就不疼了。"},
	"boss8": {"name": "押灯将霍长风", "model": "knight", "weapon": "spear", "wlen": 66.0, "tint": Color(0.85, 0.86, 0.98), "mono": 0.5, "k": 1.9,
		"hp": 1250.0, "speed": 3.9, "detect": 40.0, "range": 4.6, "dmg": 22.0, "windup": 0.55, "attack": "boss", "poise": 160.0, "coins": 140, "boss": true,
		"rage": "押灯将·箭雨", "rage_line": "箭——放！"},
	"boss9": {"name": "长明帝", "model": "mage", "weapon": "staff", "wlen": 46.0, "tint": Color(1.3, 1.08, 0.62), "mono": 0.35, "k": 2.0,
		"hp": 1300.0, "speed": 3.1, "detect": 40.0, "range": 3.4, "dmg": 23.0, "windup": 0.6, "attack": "boss", "poise": 170.0, "coins": 200, "boss": true,
		"rage": "长明·燃寿", "rage_line": "朕……不想死。", "head": "barbarian"},
}

## 自定义的出手：不走 Foe 里的预警和出招
const CUSTOM := ["ward", "f_lob", "f_ring", "f_rain", "h_thrust", "h_rank", "h_rain", "e_pillar", "e_summon", "e_rank"]

var _ward := 0.0              # 被镇魂铃护着：剩余时间（减伤一半，描边发青）
var _ward_rim := []
var _woke := false            # 稻草人：醒了没有
var _blink_cd := 3.0          # 宫灯魂、陆长庚：多久能再闪一次
var _t1 := 6.0                # 头目的招式计时（焦明落火 / 霍长风列阵 / 长明帝召人）
var _t2 := 8.0                # 头目二阶段的招式计时（霍长风箭雨 / 长明帝宫人魂）
var _pts: Array[Vector3] = [] # 这一招的落点（火罐、光柱、箭雨）
var _lit := 0                 # 长明帝：亮着的护体灯
var _lamps0 := 0
var _lamp_said := 0.0
var boss_ref: Act3Foe         # 护体灯：护着哪个皇帝
var _lamp_node: Node3D
var _lamp_light: OmniLight3D


func setup_kind(k: String, hp_scale: float = 1.0, dmg_mult: float = 1.0) -> void:
	if not TYPES3.has(k):
		super.setup_kind(k, hp_scale, dmg_mult)
		return
	kind = k
	data = TYPES3[k]
	max_hp = float(data["hp"]) * hp_scale
	hp = max_hp
	dmg_scale = dmg_mult
	max_poise = float(data["poise"])
	poise = max_poise
	is_boss = bool(data.get("boss", false))
	display_name = String(data["name"])
	guard = float(data.get("guard", 0.0))


func _hint_text() -> String:
	return String(data.get("hint", super._hint_text()))


func _ready() -> void:
	super._ready()
	match kind:
		"lampman":
			rig.set_rim(Color(0.8, 0.85, 0.95), 0.55)
		"scarecrow":
			rig.set_rim(Color(1.0, 0.85, 0.4), 0.25)
		"torcher":
			rig.set_rim(Color(1.0, 0.55, 0.2), 0.5)
		"wardbell":
			rig.set_rim(Color(0.6, 0.85, 1.0), 0.6)
		"palaceghost":
			rig.set_rim(Color(1.0, 0.7, 0.85), 1.0)
			rig.set_glow(Color(0.12, 0.05, 0.08))
		"ghostrider":
			rig.set_rim(Color(0.5, 0.75, 1.0), 1.1)
			rig.set_glow(Color(0.04, 0.08, 0.18))
		"courtghost":
			rig.set_rim(Color(1.0, 0.75, 0.5), 1.1)
			rig.set_glow(Color(0.18, 0.1, 0.04))
		"goldguard":
			rig.set_rim(Color(1.0, 0.85, 0.4), 0.4)
		"censer":
			rig.set_rim(Color(1.0, 0.5, 0.35), 0.45)
		"lampnode":
			_build_lamp()
	if kind == "boss9":
		_t1 = 9.0
		_t2 = 4.0


# ---------- 每帧 ----------

func _physics_process(delta: float) -> void:
	if kind == "lampnode":
		_tick_lamp(delta)
		return
	if _ward > 0.0:
		_ward -= delta
		if _ward <= 0.0 and _ward_rim.size() == 2 and alive:
			rig.mat.set_shader_parameter("rim_color", _ward_rim[0])
			rig.mat.set_shader_parameter("rim_strength", _ward_rim[1])
	super._physics_process(delta)
	if not alive:
		return
	if kind == "palaceghost":
		rig.position.y = 0.3 + 0.12 * sin(_anim_t * 2.6)
	if kind == "boss9" and _lamps0 == 0 and state != "spawn":
		_spawn_lamps()


## 稻草人：站在田里一动不动，两手平伸。走近了（或者挨了一下）才扑上来
func _st_patrol(dt: float) -> void:
	if kind == "scarecrow" and not _woke:
		move_with_knock(Vector3.ZERO, dt)
		var p := Poses.idle(0.0, true)
		p["hand_r"] = Poses.dirv(-90, 5, 0.9)
		p["hand_l"] = Poses.dirv(90, 5, 0.9)
		p["blade"] = Vector3(0.1, 1.0, 0.0)
		p["bob"] = -0.2
		_pose = p
		if (target != null and _dist_to_target() < 4.5) or st_t > 25.0:
			_wake()
		return
	super._st_patrol(dt)


func _wake() -> void:
	if _woke or not alive:
		return
	_woke = true
	Feel.I.callout(head_top(), "！", Color(1.0, 0.75, 0.3), 0.9)
	Vfx.I.chips(chest(), Vector3.UP, Color(0.85, 0.72, 0.38), 12, 5.0, 0.08)
	Vfx.I.dust(global_position, 1.0, Color(0.6, 0.55, 0.4, 0.5))
	Game.sfx("slash", -8.0, 0.1, 0.8)
	_set_state("chase")
	if _get_token():
		_begin_attack("lunge")


func _st_chase(dt: float) -> void:
	if target == null:
		super._st_chase(dt)
		return
	var dist := _dist_to_target()
	if kind in ["palaceghost", "chief"]:
		_blink_cd -= dt
	if is_boss:
		_t1 -= dt
		if _boss_phase >= 1:
			_t2 -= dt
	if _cool <= 0.0 and _retreat_t <= 0.0:
		match kind:
			"lancer":
				if dist > 5.5 and dist < 14.0 and randf() < dt * 1.3 and _get_token():
					_begin_attack("charge")
					return
			"goldguard":
				if dist > 4.0 and dist < 9.0 and randf() < dt * 0.8 and _get_token():
					_begin_attack("leap")
					return
			"palaceghost":
				if _blink_cd <= 0.0 and dist > 4.5 and _get_token():
					_blink_cd = randf_range(5.0, 7.0)
					_blink(randf_range(3.0, 4.0))
					_begin_attack("rune")
					return
			"chief":
				if _blink_cd <= 0.0 and dist > 3.5 and _get_token():
					_blink_cd = randf_range(4.5, 6.5)
					_blink(2.6)
					_begin_attack("lunge")
					return
			"boss7":
				if _boss_phase >= 1 and _t1 <= 0.0 and _get_token():
					_t1 = randf_range(6.5, 8.5)
					_begin_attack("f_rain")
					return
				if dist > 4.5 and randf() < dt * 1.5 and _get_token():
					_begin_attack("f_lob" if randf() < 0.55 else "f_ring")
					return
				if dist < 3.5 and randf() < dt * 0.25 and _get_token():
					_begin_attack("f_ring")
					return
			"boss8":
				if _t1 <= 0.0 and _get_token():
					_t1 = randf_range(11.0, 13.0) if _boss_phase == 0 else randf_range(8.0, 10.0)
					_begin_attack("h_rank")
					return
				if _boss_phase >= 1 and _t2 <= 0.0 and _get_token():
					_t2 = randf_range(7.0, 9.0)
					_begin_attack("h_rain")
					return
				if dist > 5.5 and randf() < dt * 1.4 and _get_token():
					_begin_attack("boss_leap" if randf() < 0.5 else "h_thrust")
					return
			"boss9":
				if _t1 <= 0.0 and get_tree().get_nodes_in_group("foes").size() < 9 and _get_token():
					_t1 = randf_range(13.0, 16.0)
					_begin_attack("e_summon")
					return
				if _boss_phase >= 1 and _t2 <= 0.0 and _get_token():
					_t2 = randf_range(8.0, 10.0)
					_begin_attack("e_rank")
					return
				if dist > 4.5 and randf() < dt * 1.5 and _get_token():
					_begin_attack("e_pillar" if randf() < 0.6 else "boss_wave")
					return
	super._st_chase(dt)


## 瞬移到主角身边（宫灯魂：身侧几步；陆长庚：身后）
func _blink(r: float) -> void:
	var from := global_position
	var p := target.global_position
	var d := -target.facing if kind == "chief" else Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
	var to := p + d.normalized() * r
	var ar: Variant = get_parent().get("arena") if get_parent() != null else null
	if ar != null:
		var half: Vector2 = (ar.size as Vector2) * 0.5 - Vector2(1.5, 1.5)
		to.x = clampf(to.x, -half.x, half.x)
		to.z = clampf(to.z, -half.y, half.y)
	var col := Color(1.0, 0.7, 0.85) if kind == "palaceghost" else Color(0.6, 0.6, 0.75)
	Vfx.I.sheet("soul-rise", from, 2.2, Color(col, 0.8), 1.6, false, 0.0, 2.0)
	Vfx.I.shock_ring(from, col, 0.2, 2.0, 0.25)
	global_position = Vector3(to.x, 0, to.z)
	Vfx.I.sheet("spawn-cast", global_position, 2.4, Color(col, 0.9), 1.6, false, 0.0, 2.2)
	Game.sfx("dash", -8.0, 0.1, 1.2)
	face_to(p - global_position)


func _choose_attack(dist: float) -> String:
	match kind:
		"lampguard":
			return "bash" if guard > 0.0 and dist < 2.4 and randf() < 0.5 else "thrust"
		"lancer":
			return "thrust"
		"courier", "scarecrow":
			return "lunge"
		"goldguard":
			return "heavy"
		"chief":
			return "lunge" if randf() < 0.35 else "slash"
		"boss7":
			return "boss_combo" if randf() < 0.7 else "lunge"
		"boss8":
			return "h_thrust" if randf() < 0.55 else "boss_combo"
		"boss9":
			return "boss_combo" if randf() < 0.55 else "boss_wave"
	return super._choose_attack(dist)


func _windup_time() -> float:
	match _atk:
		"ward":
			return 0.8
		"f_lob":
			return 0.7
		"f_ring":
			return 0.75 if _boss_phase == 0 else 0.6
		"f_rain", "h_rain":
			return 0.6
		"h_thrust":
			return 0.5 if _boss_phase == 0 else 0.4
		"h_rank", "e_rank":
			return 0.7
		"e_pillar":
			return 0.8 if _boss_phase == 0 else 0.65
		"e_summon":
			return 0.9
	return super._windup_time()


func _begin_attack(kind_: String) -> void:
	if kind == "wardbell" and kind_ == "aura":
		kind_ = "ward"
	if not (kind_ in CUSTOM):
		super._begin_attack(kind_)
		return
	_atk = kind_
	_did_hit = false
	_combo_n = 0
	_set_state("windup")
	_blend = 0.3
	if target != null:
		_atk_dir = target.global_position - global_position
		_atk_dir.y = 0
		_atk_dir = _atk_dir.normalized() if _atk_dir.length() > 0.01 else facing
		_atk_target = target.global_position
		face_to(_atk_dir)
	var wt := _windup_time()
	var fire: Color = Vfx.DANGER["fire"]
	var gold: Color = Vfx.DANGER["holy"]
	_pts.clear()
	var tp := target.global_position if target != null else global_position
	tp.y = 0.0
	match _atk:
		"ward":
			Vfx.I.ground(global_position, "magic_01", Vfx.DANGER["summon"], 0.5, AURA_R * 2.0, wt + 0.3)
			Feel.I.callout(head_top(), "铃——", Color(0.7, 0.9, 1.0), 0.8)
		"f_lob":
			# 三个火罐：一个砸主角脚下，两个落在旁边
			_pts.append(tp + (target.velocity * 0.3 if target != null else Vector3.ZERO))
			for i in range(2 + _boss_phase):
				var a := randf() * TAU
				_pts.append(tp + Vector3(cos(a), 0, sin(a)) * randf_range(2.2, 3.8))
			for q in _pts:
				Vfx.I.telegraph_circle(Vector3(q.x, 0, q.z), 1.8, fire, wt + FoeLob.FLIGHT)
			Feel.I.callout(head_top(), "火罐!", Color(1.0, 0.6, 0.3), 0.8)
		"f_ring":
			# 火场一圈：围着主角烧一圈，只留一个口子
			var n := 10
			var gap := randi() % n
			for i in range(n):
				if i == gap or i == (gap + 1) % n:
					continue
				var a := TAU * i / n
				_pts.append(tp + Vector3(cos(a), 0, sin(a)) * 4.2)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "围!", Color(1.0, 0.55, 0.25), 1.0)
			Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.5, 0.15, 0.8), 0.5, 4.0, wt + 0.3)
		"f_rain":
			_pts.append(tp)
			for i in range(5 + _boss_phase):
				var a := randf() * TAU
				_pts.append(tp + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.5))
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "天火!", Color(1.0, 0.5, 0.2), 1.0)
		"h_thrust":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * (float(data["range"]) + 1.0), 1.0, Vfx.DANGER["melee"], wt)
		"h_rank":
			Vfx.I.ground(global_position, "magic_01", Color(0.5, 0.75, 1.0, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "幽骑——冲!", Color(0.65, 0.85, 1.0), 1.2)
		"h_rain":
			_pts.append(tp + (target.velocity * 0.4 if target != null else Vector3.ZERO))
			for i in range(8):
				var a := TAU * i / 8.0 + randf() * 0.4
				_pts.append(tp + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 6.0))
			for q in _pts:
				Vfx.I.telegraph_circle(Vector3(q.x, 0, q.z), 1.4, Vfx.DANGER["shot"], wt + 1.0)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "放箭!", Color(1.0, 0.45, 0.35), 1.0)
		"e_pillar":
			var n := 4 if _boss_phase == 0 else 6
			for i in range(n):
				_pts.append(global_position + _atk_dir * (2.6 + i * 2.0))
			for i in range(2 + _boss_phase * 2):
				var a := randf() * TAU
				_pts.append(tp + Vector3(cos(a), 0, sin(a)) * randf_range(1.2, 3.5))
			for q in _pts:
				Vfx.I.telegraph_circle(Vector3(q.x, 0, q.z), 1.3, gold, wt)
		"e_summon":
			Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.85, 0.4, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "护驾!", Color(1.0, 0.85, 0.45), 1.0)
		"e_rank":
			Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.75, 0.45, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "宫里的人，都过来。", Color(1.0, 0.85, 0.6), 1.2)
	Game.sfx("danger", -8.0)


func _st_windup(dt: float) -> void:
	super._st_windup(dt)
	if state != "windup" or not (_atk in CUSTOM):
		return
	var k := clampf(st_t / _windup_time(), 0.0, 1.0)
	match _atk:
		"h_thrust":
			_pose = _aim_pose(k * 0.5)
			_pose["lean"] = -0.15 * k
		"h_rank", "h_rain":
			_pose = Poses.windup("enemy_v", k, st_t)
		_:
			_pose = Poses.cast(k, _anim_t)
	if _atk == "ward":
		rig.set_glow(Color(0.4, 0.75, 1.0) * (0.25 + 0.6 * k))
	elif _atk.begins_with("f_"):
		rig.set_glow(Color(1.0, 0.45, 0.1) * (0.25 + 0.6 * k))
	elif _atk.begins_with("e_"):
		rig.set_glow(Color(1.0, 0.8, 0.3) * (0.25 + 0.6 * k))


func _st_attack(dt: float) -> void:
	if not (_atk in CUSTOM):
		super._st_attack(dt)
		return
	match _atk:
		"ward":
			var k := st_t / 0.45
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				_do_ward()
			if k >= 1.0:
				_end_attack()
		"f_lob":
			var k := st_t / 0.35
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				for q in _pts:
					var j := FoeLob.new()
					j.from = global_position + _atk_dir * 0.6 + Vector3(0, 2.4, 0)
					j.to = Vector3(q.x, 0, q.z)
					j.damage = float(data["dmg"]) * 0.45 * dmg_scale
					get_parent().add_child(j)
				Game.sfx("flame", -5.0)
			if k >= 1.0:
				_end_attack()
		"f_ring", "f_rain":
			var k := st_t / 0.45
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var ring := _atk == "f_ring"
				for q in _pts:
					var fp := FirePool.new()
					fp.radius = 1.25 if ring else 1.5
					fp.damage = float(data["dmg"]) * 0.3 * dmg_scale
					fp.life = 4.5 if ring else 3.2
					fp.warn = 0.9 if ring else 1.0
					get_parent().add_child(fp)
					fp.global_position = Vector3(q.x, 0, q.z)
					if not ring:
						Vfx.I.streaks(Vector3(q.x, 7.0, q.z), Vector3.DOWN, Color(1.0, 0.55, 0.2), 2, 6.5, 0.35, 0.1, 0.9)
				CamRig.I.shake(1)
				Game.sfx("flame", -3.0)
			if k >= 1.0:
				_end_attack()
		"h_thrust":
			var dur := 0.24
			var k := st_t / dur
			_pose = _aim_pose(1.0)
			_pose["lean"] = 0.35
			move_with_knock(_atk_dir * (8.0 * (1.0 - k)), dt)
			if not _did_hit and k >= 0.2:
				_did_hit = true
				var reach := float(data["range"]) + 0.8
				Vfx.I.streaks(global_position + _atk_dir * 0.8 + Vector3(0, 1.4, 0), _atk_dir, Color(0.85, 0.92, 1.0), 4, reach, 0.14, 0.05, 0.12)
				Vfx.I.pop(global_position + _atk_dir * reach + Vector3(0, 1.4, 0), "spark_05", fx_color(), 0.35, 1.6, 0.12)
				Game.sfx("slash", -4.0, 0.1, 1.2)
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh == null or not hh.alive:
						continue
					var to := hh.global_position - global_position
					to.y = 0
					var t := to.dot(_atk_dir)
					if t > -0.3 and t < reach + hh.radius and (to - _atk_dir * t).length() < 0.6 + hh.radius:
						_hit_target(hh, float(data["dmg"]) * 0.8, HitInfo.Weight.LIGHT)
			if k >= 1.0:
				if _combo_n < 2:
					_combo_n += 1
					_did_hit = false
					st_t = 0.0
					if target != null:
						_atk_dir = target.global_position - global_position
						_atk_dir.y = 0
						_atk_dir = _atk_dir.normalized() if _atk_dir.length() > 0.01 else facing
						face_to(_atk_dir)
					Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * (float(data["range"]) + 1.0), 0.9, Vfx.DANGER["melee"], 0.1)
					return
				_end_attack()
		"h_rank", "e_rank":
			_st_rank3(dt)
		"h_rain":
			var k := st_t / 0.4
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var pts := _pts.duplicate()
				get_tree().create_timer(1.0).timeout.connect(_rain_land.bind(pts))
				Game.sfx("bow", -2.0, 0.1, 0.8)
				for i in range(6):
					Vfx.I.streaks(global_position + Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2)), Vector3.UP, Color(0.9, 0.9, 1.0), 1, 6.0, 0.3, 0.1, 0.1)
			if k >= 1.0:
				_end_attack()
		"e_pillar":
			var k := st_t / 0.45
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.2:
				_did_hit = true
				for q in _pts:
					var s := Vector3(q.x, 0, q.z)
					Vfx.I.streaks(s, Vector3.UP, Color(1.0, 0.9, 0.55), 5, 4.5, 0.25, 0.15, 0.22)
					Vfx.I.shock_ring(s, Color(1.0, 0.85, 0.4), 0.2, 2.6, 0.3)
					Vfx.I.pop(s + Vector3(0, 0.8, 0), "light_01", Color(1.0, 0.85, 0.5), 0.6, 3.0, 0.3)
					_area_hit(s, 1.3, float(data["dmg"]) * 0.9, HitInfo.Weight.LIGHT)
				CamRig.I.shake(1)
				Game.sfx("boom", -5.0, 0.0, 1.3)
			if k >= 1.0:
				_end_attack()
		"e_summon":
			var k := st_t / 0.5
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var main := get_parent()
				var ks := ["goldguard", "palaceghost"] if _boss_phase == 0 else ["goldguard", "palaceghost", "censer"]
				for i in range(ks.size()):
					var a := TAU * i / ks.size() + randf() * 0.5
					var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.5
					if main.has_method("_spawn_foe"):
						main._spawn_foe(String(ks[i]), p, i * 0.2)
				Game.sfx("boom", -6.0)
			if k >= 1.0:
				_end_attack()


## 箭雨落下：每个红圈里扎下一把箭
func _rain_land(pts: Array[Vector3]) -> void:
	if not alive or not is_inside_tree():
		return
	for q in pts:
		var s := Vector3(q.x, 0, q.z)
		Vfx.I.streaks(s + Vector3(0, 6.0, 0), Vector3(0.15, -1, 0.1).normalized(), Color(0.9, 0.9, 0.95), 4, 6.0, 0.18, 0.12, 0.08)
		Vfx.I.chips(s, Vector3.UP, Color(0.45, 0.42, 0.38), 6, 4.0, 0.08)
		_area_hit(s, 1.4, float(data["dmg"]) * 0.75, HitInfo.Weight.LIGHT)
	CamRig.I.shake(1)
	Game.sfx("slash_heavy", -6.0, 0.1, 1.3)


## 幽骑 / 宫人魂列阵：排成一排从房间一头冲到另一头
func _st_rank3(dt: float) -> void:
	var k := st_t / 0.45
	_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit:
		_did_hit = true
		var main := get_parent()
		var ar: Variant = main.get("arena") if main != null else null
		var half := Vector2(20.0, 15.0)
		if ar != null:
			half = (ar.size as Vector2) * 0.5 - Vector2(2.0, 2.0)
		var hp_ := target.global_position if target != null else Vector3.ZERO
		var from_side := randf() < 0.5
		var court := _atk == "e_rank"
		var n := (4 if _boss_phase == 0 else 5) if not court else 4
		for i in range(n):
			var off := (i - (n - 1) * 0.5) * (2.8 if not court else 3.2)
			var p: Vector3
			var d: Vector3
			if from_side:
				var sx := -1.0 if hp_.x > 0.0 else 1.0
				p = Vector3(sx * half.x, 0, clampf(hp_.z + off, -half.y, half.y))
				d = Vector3(-sx, 0, 0)
			else:
				p = Vector3(clampf(hp_.x + off, -half.x, half.x), 0, -half.y)
				d = Vector3(0, 0, 1)
			var f := Act3Foe.new()
			f.setup_kind("courtghost" if court else "ghostrider", 1.0, dmg_scale)
			f.charge_dir = d
			f.no_loot = true
			main.add_child(f)
			f.global_position = p
			f.face_to(d)
		Game.sfx("boss", -6.0)
		CamRig.I.shake(1)
	if k >= 1.0:
		_end_attack()


# ---------- 镇魂铃 ----------

func _do_ward() -> void:
	_auras += 1
	var col := Color(0.55, 0.85, 1.0)
	Vfx.I.shock_ring(global_position, col, 0.5, AURA_R * 2.0, 0.5)
	Vfx.I.sheet("spawn-cast", global_position, 2.6, Color(col, 0.9), 1.6, false, 0.0, 1.6)
	Game.sfx("block", -4.0, 0.0, 1.6)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var ff := f as Act3Foe
		if ff == null or ff == self or not ff.alive or ff.data.has("phantom") or ff.data.has("aura") or ff.kind == "lampnode":
			continue
		if ff.global_position.distance_to(global_position) > AURA_R:
			continue
		Vfx.I.streaks(chest(), (ff.chest() - chest()).normalized(), col, 1, ff.chest().distance_to(chest()), 0.25, 0.0, 0.1)
		ff.warded(5.0)


## 被镇魂铃护着：几秒内受到的伤害减半
func warded(t: float) -> void:
	if _ward <= 0.0:
		_ward_rim = [rig.mat.get_shader_parameter("rim_color"), rig.mat.get_shader_parameter("rim_strength")]
	_ward = t
	rig.set_rim(Color(0.45, 0.8, 1.0), 1.0)
	Feel.I.callout(head_top(), "护", Color(0.6, 0.85, 1.0), 0.6)


# ---------- 长明帝的护体灯 ----------

func _spawn_lamps() -> void:
	var main := get_parent()
	if main == null:
		return
	var st: Variant = main.get("state")
	var n := 4
	if st != null and (st.flags as Dictionary).has("lamp_carried"):
		n = 3   # 第五盏灯在你身上：皇帝闻到了，护体灯少一盏
	var ar: Variant = main.get("arena")
	var half := Vector2(22.0, 16.0)
	if ar != null:
		half = (ar.size as Vector2) * 0.5
	var spots := [Vector3(-half.x * 0.55, 0, -half.y * 0.45), Vector3(half.x * 0.55, 0, -half.y * 0.45),
		Vector3(-half.x * 0.55, 0, half.y * 0.3), Vector3(half.x * 0.55, 0, half.y * 0.3)]
	var hs := max_hp / float(data["hp"])
	for i in range(n):
		var f := Act3Foe.new()
		f.setup_kind("lampnode", hs, 1.0)
		f.no_loot = true
		f.boss_ref = self
		f.position = spots[i]   # 先定位置再进场景：灯火特效在 _ready 里按位置摆
		main.add_child(f)
	_lamps0 = n
	_lit = n
	rig.set_glow(Color(0.25, 0.2, 0.05))
	Feel.I.callout(head_top() + Vector3(0, 0.5, 0), "护体灯 %d 盏" % n, Color(1.0, 0.85, 0.45), 1.6)


func _lamp_out() -> void:
	if not alive:
		return
	_lit = maxi(_lit - 1, 0)
	Feel.I.callout(head_top() + Vector3(0, 0.5, 0), "灯灭 · 剩 %d 盏" % _lit, Color(1.0, 0.8, 0.4), 1.4)
	Vfx.I.shock_ring(global_position, Color(1.0, 0.85, 0.4), 0.4, 6.0, 0.5)
	Game.sfx("posture_break", -3.0)
	rig.set_glow(Color(0.25, 0.2, 0.05) * (_lit / 4.0))
	# 踉跄一下：白打的机会
	_release()
	rig.position.y = 0
	hit_stun = 1.6
	_set_state("stagger")
	if _lit == 0 and _lamps0 >= 4:
		ArpgAch.unlock("lamps4")


func _build_lamp() -> void:
	rig.visible = false
	_set_state("post")
	_lamp_node = Node3D.new()
	add_child(_lamp_node)
	var piece := VoxelKit.get_piece("post_lantern")
	if not piece.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = piece["mesh"]
		mi.material_override = VoxActor.toon_material()
		mi.scale = Vector3.ONE * Arena.PX * 1.7
		_lamp_node.add_child(mi)
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color(1.0, 0.82, 0.4)
	_lamp_light.light_energy = 2.6
	_lamp_light.omni_range = 7.0
	_lamp_light.position = Vector3(0, 2.6, 0)
	_lamp_node.add_child(_lamp_light)
	if Vfx.I != null:
		var fl := Vfx.I.sheet("spirit-flame", global_position + Vector3(0, 2.3, 0), 1.2, Color(1.0, 0.85, 0.45), 2.0, false, 1.0e6)
		fl.reparent(_lamp_node)
	Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.8, 0.35, 0.5), 2.2, 2.8, 1.0e6).reparent(_lamp_node)


func _tick_lamp(delta: float) -> void:
	var dt := tick_common(delta)
	if not alive or dt <= 0.0:
		return
	_anim_t += dt
	st_t += dt
	if _lamp_light != null:
		_lamp_light.light_energy = 2.3 + 0.4 * sin(_anim_t * 7.0) + 0.2 * sin(_anim_t * 17.0)
	if st_t > 0.6 and not _seen.has(kind):
		_seen[kind] = true
		Feel.I.callout(head_top() + Vector3(0, 1.4, 0), _hint_text(), Color(1.0, 0.9, 0.6), 2.4)
	# 灯亮着：皇帝慢慢回血（每盏每秒 0.4%），金线连过去
	if is_instance_valid(boss_ref) and boss_ref.alive:
		boss_ref.hp = minf(boss_ref.max_hp, boss_ref.hp + boss_ref.max_hp * 0.0015 * dt)
		if int(_anim_t * 0.7) != int((_anim_t - dt) * 0.7):
			var a := global_position + Vector3(0, 2.4, 0)
			Vfx.I.streaks(a, (boss_ref.chest() - a).normalized(), Color(1.0, 0.85, 0.45), 1, a.distance_to(boss_ref.chest()), 0.3, 0.0, 0.08)


# ---------- 挨打、倒下 ----------

func take_hit(info: HitInfo) -> bool:
	if not alive:
		return false
	if kind == "scarecrow" and not _woke and state != "spawn":
		_wake()
	if _ward > 0.0:
		info.damage *= 0.5
		Vfx.I.pop(chest() - info.dir * 0.4, "spark_05", Color(0.6, 0.85, 1.0), 0.35, 1.5, 0.12)
	if kind == "boss9" and _lit > 0 and info.weight < HitInfo.Weight.ULT:
		info.damage *= 1.0 - 0.15 * _lit
		Vfx.I.pop(chest() - info.dir * 0.5, "spark_05", Color(1.0, 0.85, 0.45), 0.45, 1.8, 0.14)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _lamp_said > 4.0:
			_lamp_said = now
			Feel.I.callout(head_top(), "灯护着他 · 先砸灯", Color(1.0, 0.85, 0.45), 1.2)
	var ph := _boss_phase
	var ok := super.take_hit(info)
	if ok and is_boss and ph == 0 and _boss_phase >= 1:
		_on_rage()
	return ok


func _on_rage() -> void:
	match kind:
		"boss7":
			# 半血：整个村子烧起来，之后隔一阵天上落火
			_t1 = 2.0
			var ar: Variant = get_parent().get("arena") if get_parent() != null else null
			if ar != null and ar.has_method("ignite"):
				ar.ignite()
		"boss8":
			_t2 = 2.0
		"boss9":
			_t2 = 2.5


## 属性：火师的火罐、火圈、天火算火，长明帝的光柱算佛光
func _atk_elem() -> String:
	if _atk.begins_with("f_"):
		return "fire"
	if _atk == "e_pillar":
		return "holy"
	return super._atk_elem()


func fx_color() -> Color:
	match kind:
		"boss7":
			return Color(1.0, 0.48, 0.18)
		"boss8":
			return Color(0.6, 0.78, 1.0)
		"boss9":
			return Color(1.0, 0.85, 0.35)
	return super.fx_color()


func die(impulse: Vector3) -> void:
	var main := get_parent()
	var p := global_position
	super.die(impulse)
	match kind:
		"lampnode":
			if is_instance_valid(_lamp_node):
				_lamp_node.queue_free()
			Vfx.I.explosion(p + Vector3(0, 1.6, 0), 0.7)
			Vfx.I.shock_ring(p, Color(1.0, 0.85, 0.4), 0.4, 4.0, 0.4)
			Vfx.I.chips(p + Vector3(0, 1.5, 0), Vector3.UP, Color(1.0, 0.8, 0.4), 16, 6.0, 0.1)
			if is_instance_valid(boss_ref):
				boss_ref._lamp_out()
		"wardbell":
			if _auras == 0 and not no_loot:
				ArpgAch.unlock("bell_cut")
		"lampman":
			_maybe_rise(main, p)


## 灯兵倒下：有几成会被灰灯再点起来一次（吹灭了柳溪村的灰纸灯，这一局就不会）
func _maybe_rise(main: Node, p: Vector3) -> void:
	if has_meta("risen") or no_loot or main == null or randf() >= float(data.get("rise", 0.0)):
		return
	var st: Variant = main.get("state")
	if st != null and (st.flags as Dictionary).has("lamps_blown"):
		return
	if get_tree().get_nodes_in_group("foes").is_empty():
		return   # 最后一个了：不再起来（别在清场以后又冒出来）
	var ar: Variant = main.get("arena")
	var hs := max_hp / float(data["hp"])
	var ds := dmg_scale
	Vfx.I.ground(p, "magic_01", Color(0.8, 0.85, 0.95, 0.6), 1.2, 2.0, 2.4)
	Feel.I.callout(p + Vector3(0, 1.8, 0), "灯又亮了", Color(0.85, 0.88, 0.95), 1.0)
	get_tree().create_timer(2.2).timeout.connect(Act3Foe._rise.bind(main, ar, p, hs, ds))


static func _rise(main: Node, ar: Variant, p: Vector3, hs: float, ds: float) -> void:
	if not is_instance_valid(main) or ar == null or not is_instance_valid(ar) or main.get("arena") != ar or main.get("mode") != "room":
		return
	if main.get_tree().get_nodes_in_group("foes").is_empty():
		return
	var f := Act3Foe.new()
	f.setup_kind("lampman", hs * 0.5, ds)
	f.no_loot = true
	f.set_meta("risen", true)
	main.add_child(f)
	f.global_position = p
	f.detect_mult = 2.0
	if main.has_method("_on_drop"):
		f.dropped.connect(main._on_drop.bind("lampman"))
