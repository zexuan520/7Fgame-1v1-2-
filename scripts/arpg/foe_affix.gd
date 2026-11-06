class_name FoeAffix
extends RefCounted
## 精英词缀：精英房的领头怪、深处的战斗房里偶尔一只小怪会带一两条词缀。
## 每条词缀一个字、一个颜色：头上血条旁挂着字，脚下一圈同色光环，描边也换成这个颜色，一眼看得出“这只不一样”。
## 每层的词缀池不同（见 FoeSquads 的 affix / ELITE_AFFIX），所以每层碰到的精英气质也不一样。

const DEFS := {
	"swift": {"name": "迅", "full": "迅捷", "desc": "更快，出手前摇更短，跑起来带残影", "color": Color(0.45, 0.95, 1.0)},
	"stout": {"name": "坚", "full": "铁骨", "desc": "块头更大，血厚，要多砍几下才破韧", "color": Color(0.82, 0.86, 0.95)},
	"frenzy": {"name": "狂", "full": "狂暴", "desc": "更疼，出手更勤", "color": Color(1.0, 0.28, 0.22)},
	"volatile": {"name": "爆", "full": "爆裂", "desc": "死后脚下亮橙圈，一会儿就炸，快离开", "color": Color(1.0, 0.6, 0.18)},
	"haunt": {"name": "魂", "full": "附魂", "desc": "死后飘出两只腐骨虫", "color": Color(0.5, 1.0, 0.65)},
	"warded": {"name": "罩", "full": "金罩", "desc": "身上一层金罩先挡伤害，打破了才见血", "color": Color(1.0, 0.85, 0.35)},
	"blazing": {"name": "焰", "full": "焚身", "desc": "走过的地方留下一滩火", "color": Color(1.0, 0.48, 0.12)},
	"miasma": {"name": "瘴", "full": "瘴毒", "desc": "走过的地方留下毒瘴", "color": Color(0.6, 1.0, 0.3)},
	"thunder": {"name": "雷", "full": "引雷", "desc": "隔一阵往你脚下引一道雷，看见白圈就挪", "color": Color(0.82, 0.8, 1.0)},
	# 轮回专用（ArpgCycle 抽，FoeSquads 的池里没有）
	"mend": {"name": "回", "full": "回春", "desc": "两秒没挨打就回血，别停手", "color": Color(0.4, 0.95, 0.85)},
}


## 生成时（还没进场景）改数值
static func apply(f: Foe, ids: Array) -> void:
	if ids.is_empty():
		return
	f.data = f.data.duplicate()
	f.affixes.assign(ids)
	# 带词缀的都硬一点、值钱一点
	f.max_hp *= 1.25
	f.data["coins"] = int(f.data["coins"]) + 2 + int(f.data["coins"]) / 2
	for id: String in ids:
		match id:
			"swift":
				f.data["speed"] = float(f.data["speed"]) * 1.35
				f.data["windup"] = float(f.data["windup"]) * 0.8
			"stout":
				f.max_hp *= 1.6
				f.data["k"] = float(f.data["k"]) * 1.15
				f.max_poise += 30.0
			"frenzy":
				f.dmg_scale *= 1.3
			"warded":
				f.ward_max = f.max_hp * 0.45
				f.ward = f.ward_max
	f.hp = f.max_hp
	f.poise = f.max_poise
	var tag := ""
	for id: String in ids:
		tag += String(DEFS[id]["name"])
	f.display_name = "%s · %s" % [tag, f.display_name]


## 主色：第一条词缀的颜色
static func color(f: Foe) -> Color:
	if f.affixes.is_empty():
		return Color(1, 1, 1)
	return DEFS[f.affixes[0]]["color"]


## 进场景后（rig 已建好）：描边、脚下光环
static func dress(f: Foe) -> void:
	if f.affixes.is_empty() or f.rig == null:
		return
	var c := color(f)
	f.rig.set_rim(c, 0.95)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.6 * float(f.data["k"])
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/lm_ring_b.png"))
	m.set_shader_parameter("color", Color(c, 0.85))
	m.set_shader_parameter("energy", 2.0)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation = Vector3(-PI / 2, 0, 0)
	ring.position.y = 0.05
	f.add_child(ring)
	f._affix_ring = ring
	if f.ward > 0.0:
		var sh := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2.ONE * 2.5 * float(f.data["k"])
		sh.mesh = sq
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/arpg/fx_add.gdshader")
		sm.set_shader_parameter("tex", load("res://assets/fx/lm_circle_a.png"))
		sm.set_shader_parameter("color", Color(1.0, 0.85, 0.4, 0.22))
		sm.set_shader_parameter("energy", 1.6)
		sm.set_shader_parameter("billboard", true)
		sh.material_override = sm
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.position.y = 0.95 * float(f.data["k"])
		f.add_child(sh)
		f._ward_fx = sh
	# 第一次见到某条词缀：头上冒一句说明（一次游戏里每条只冒一次）
	for id: String in f.affixes:
		if not Foe._seen.has("affix_" + id):
			Foe._seen["affix_" + id] = true
			var d: Dictionary = DEFS[id]
			Feel.I.callout(f.head_top() + Vector3(0, 0.7, 0), "词缀「%s」· %s" % [d["full"], d["desc"]], d["color"], 2.6)
			break


## 每帧：残影、留火留瘴、引雷、光环转动
static func tick(f: Foe, dt: float) -> void:
	if f._affix_ring != null:
		f._affix_ring.rotation.y += dt * 1.6
		var s := 1.0 + 0.06 * sin(f._anim_t * 5.0)
		f._affix_ring.scale = Vector3(s, s, s)
	if f._ward_fx != null:
		# 金罩：面朝镜头的一团淡金光，随罩子剩多少变淡
		var mm := f._ward_fx.material_override as ShaderMaterial
		mm.set_shader_parameter("color", Color(1.0, 0.85, 0.4, 0.12 + 0.2 * f.ward / maxf(f.ward_max, 1.0)))
	if f.affixes.has("mend"):
		_mend(f, dt)
	f._affix_t -= dt
	if f._affix_t > 0.0:
		return
	for id: String in f.affixes:
		match id:
			"swift":
				if f.velocity.length() > 2.0 and Vfx.I.lod > 0:
					Vfx.I.ghost(f.rig, DEFS["swift"]["color"], 0.28)
					f._affix_t = 0.14
					return
			"blazing", "miasma":
				if f.velocity.length() > 1.0 and f.state in ["chase", "recover"]:
					var fp := FirePool.new()
					fp.elem = "fire" if id == "blazing" else "poison"
					fp.radius = 1.1
					fp.damage = 4.0 * f.dmg_scale
					fp.life = 3.2
					fp.warn = 0.35
					f.get_parent().add_child(fp)
					fp.global_position = Vector3(f.global_position.x, 0, f.global_position.z)
					f._affix_t = 2.4
					return
			"thunder":
				if f.target != null and f.state in ["chase", "patrol"] and f.global_position.distance_to(f.target.global_position) < 15.0:
					thunder(f.get_parent(), f.target.global_position + f.target.velocity * 0.3, 1.6, 12.0 * f.dmg_scale, 1.0)
					Feel.I.callout(f.head_top(), "雷!", DEFS["thunder"]["color"], 0.7)
					f.rig.flash(0.2, Color(0.85, 0.85, 1.0))
					f._affix_t = randf_range(5.0, 6.5)
					return
	f._affix_t = 0.5


## 回春：两秒没掉血，每秒回 4% 生命（头目 1.5%），一挨打就停
static func _mend(f: Foe, dt: float) -> void:
	var last := float(f.get_meta("mend_hp", f.hp))
	var quiet := float(f.get_meta("mend_quiet", 0.0)) + dt
	if f.hp < last - 0.01:
		quiet = 0.0
	if quiet > 2.0 and f.hp < f.max_hp:
		f.hp = minf(f.max_hp, f.hp + f.max_hp * (0.015 if f.is_boss else 0.04) * dt)
		var fx := float(f.get_meta("mend_fx", 0.0)) - dt
		if fx <= 0.0:
			fx = 0.9
			Feel.I.callout(f.head_top(), "回", DEFS["mend"]["color"], 0.5)
		f.set_meta("mend_fx", fx)
	f.set_meta("mend_quiet", quiet)
	f.set_meta("mend_hp", f.hp)


## 金罩挡伤害：直接从 info.damage 里扣
static func absorb(f: Foe, info: HitInfo) -> void:
	if f.ward <= 0.0:
		return
	var take := minf(f.ward, info.damage)
	f.ward -= take
	info.damage -= take
	info.knock *= 0.4
	Vfx.I.pop(f.chest() - info.dir * 0.5, "spark_05", Color(1.0, 0.85, 0.4), 0.4, 1.8, 0.14)
	if f.ward <= 0.0:
		f.ward = 0.0
		Feel.I.callout(f.head_top(), "破罩!", Color(1.0, 0.85, 0.4), 1.0)
		Vfx.I.shock_ring(f.global_position, Color(1.0, 0.85, 0.4), 0.5, 4.0, 0.35)
		Vfx.I.streaks(f.chest(), Vector3.UP, Color(1.0, 0.85, 0.4), 8, 2.2, 0.25, PI, 0.14)
		Game.sfx("guard_break", -4.0)
		info.stun = maxf(info.stun, 0.6)
		if f._ward_fx != null:
			f._ward_fx.queue_free()
			f._ward_fx = null


## 死的时候：爆裂、附魂
static func on_death(f: Foe) -> void:
	if f._affix_ring != null:
		f._affix_ring.queue_free()
		f._affix_ring = null
	if f._ward_fx != null:
		f._ward_fx.queue_free()
		f._ward_fx = null
	var main := f.get_parent()
	var p := Vector3(f.global_position.x, 0, f.global_position.z)
	for id: String in f.affixes:
		match id:
			"volatile":
				var dmg := 18.0 * f.dmg_scale
				Vfx.I.telegraph_circle(p, 2.6, Vfx.DANGER["fire"], 0.85)
				Feel.I.callout(p + Vector3(0, 1.6, 0), "要炸了!", DEFS["volatile"]["color"], 0.9)
				Game.sfx("flame", -6.0, 0.1, 1.4)
				f.get_tree().create_timer(0.85).timeout.connect(func() -> void: FoeAffix._burst(main, p, 2.6, dmg))
			"haunt":
				Vfx.I.sheet("soul-rise", p, 2.6, Color(0.6, 1.0, 0.7, 0.9), 1.6)
				for i in range(2):
					var a := TAU * i / 2.0 + randf()
					var m := f._summon("crawler", p + Vector3(cos(a), 0, sin(a)) * 1.2)
					if m != null:
						m.rig.set_rim(DEFS["haunt"]["color"], 0.7)


## 爆裂：伤主角也伤旁边的怪
static func _burst(main: Node, p: Vector3, r: float, dmg: float) -> void:
	if not is_instance_valid(main) or main.get("mode") != "room":
		return
	Vfx.I.explosion(p + Vector3(0, 0.6, 0), 0.9)
	Vfx.I.shock_ring(p, DEFS["volatile"]["color"], 0.4, r * 2.0, 0.3)
	CamRig.I.shake(1)
	Game.sfx("boom", -3.0)
	for h: Node in main.get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position - p
		d.y = 0
		if d.length() <= r + hh.radius:
			var info := HitInfo.make(null, hh, dmg, HitInfo.Weight.HEAVY)
			info.src = "affix"
			info.dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
			info.point = hh.chest()
			info.knock = 10.0
			info.elem = "fire"
			Feel.I.on_hit(info)
	for f: Node in main.get_tree().get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or not ff.alive:
			continue
		var d2 := ff.global_position - p
		d2.y = 0
		if d2.length() <= r + ff.radius:
			var fi := HitInfo.make(null, ff, 30.0, HitInfo.Weight.HEAVY)
			fi.dir = d2.normalized() if d2.length() > 0.01 else Vector3.FORWARD
			fi.point = ff.chest()
			Feel.I.on_hit(fi)


## 引雷：落点先亮一圈白紫预警，到点劈下来（词缀“雷”和古寺的天雷都用这个）
static func thunder(main: Node, at: Vector3, r: float, dmg: float, warn: float) -> void:
	var p := Vector3(at.x, 0, at.z)
	Vfx.I.telegraph_circle(p, r, Vfx.DANGER["thunder"], warn)
	main.get_tree().create_timer(warn).timeout.connect(func() -> void: FoeAffix._strike(main, p, r, dmg))


static func _strike(main: Node, p: Vector3, r: float, dmg: float) -> void:
	if not is_instance_valid(main) or main.get("mode") != "room":
		return
	var c: Color = DEFS["thunder"]["color"]
	# 一道从天上劈下来的白光：几条竖着的光线 + 落点白闪 + 一圈冲击
	Vfx.I.streaks(p + Vector3(0, 7.0, 0), Vector3.DOWN, Color(0.95, 0.95, 1.0), 3, 7.5, 0.16, 0.12, 0.3)
	Vfx.I.streaks(p + Vector3(0, 0.3, 0), Vector3.UP, c, 6, 2.0, 0.2, PI, 0.12)
	Vfx.I.impact_flash(p + Vector3(0, 0.8, 0), 3.5, Color(0.85, 0.85, 1.0))
	Vfx.I.shock_ring(p, c, 0.3, r * 2.4, 0.3)
	Vfx.I.ground(p, "scorch_01", Color(0.05, 0.05, 0.08, 0.7), r * 1.4, r * 1.6, 1.4, false)
	CamRig.I.shake(1)
	Game.sfx("boom", -5.0, 0.1, 1.5)
	for h: Node in main.get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position - p
		d.y = 0
		if d.length() <= r + hh.radius:
			var info := HitInfo.make(null, hh, dmg, HitInfo.Weight.LIGHT)
			info.src = "affix"
			info.dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
			info.point = hh.chest()
			info.knock = 5.0
			info.elem = "thunder"
			Feel.I.on_hit(info)
