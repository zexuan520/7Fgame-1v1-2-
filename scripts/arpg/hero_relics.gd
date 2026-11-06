class_name HeroRelics
extends Node3D
## 主角身上的奇物机制和魂火（Hero 的子节点）。数值在 stats 表里，这里只管“什么时候触发”：
##   Hero 在出刀、翻滚、挨打、突进、光束、喝药、换手时调这里的钩子；ArpgMain 在斩杀、出波、进房时调。
## 魂火：斩杀有几率收一团（soul_rate），绕身转，每 0.8 秒飞一团向最近的敌人；百鬼大成打中后不散，再飞下一个。

var hero: Hero
var has := {}                 # 身上的奇物：id → true（来自 stats 里的 r_<id>）
# 魂
var soul_rate := 0.0
var soul_max := 0
var soul_dmg := 0.0
var soul_wave := 0
var soul_heal := 0.0
var set_soul := false
var souls := 0
var _orbs: Array = []         # 绕身的魂火（MeshInstance3D）
var _orb_t := 0.0
var _fire_t := 0.0
# 奇物计时
var _bolt_t := 5.0            # 避雷针
var _bell_t := 10.0           # 镇魂钟
var _still := 0.0             # 铁桩：站定多久
var stance := false
var _stance_fx: MeshInstance3D
var tanlang := 0              # 贪狼牙：这间房斩杀数
var _eye_t := 0.0             # 鬼眼：翻滚后剩余时间
var _wind_up := 0.0           # 逆风：见切后的增伤剩余时间
var kill_heal_pct := 0.0
var beam_lock := 0.0          # 满溢：光束斩后多久不回气
var lock_t := 0.0
var bolt_dmg := 0.0           # 风暴眼
var fire_self := 0.0          # 野火

const SOUL_COLOR := Color(0.55, 1.0, 0.85)


func apply(st: Dictionary) -> void:
	has.clear()
	for k: String in st:
		if k.begins_with("r_") and float(st[k]) > 0.0:
			has[k.substr(2)] = true
	soul_rate = ArpgData.stat(st, "soul_rate")
	soul_wave = int(ArpgData.stat(st, "soul_wave"))
	soul_dmg = ArpgData.stat(st, "soul_dmg")
	soul_heal = ArpgData.stat(st, "soul_heal")
	set_soul = ArpgData.stat(st, "set_soul") > 0.0
	soul_max = 0 if (soul_rate <= 0.0 and soul_wave <= 0) else 3 + int(ArpgData.stat(st, "soul_max")) + (3 if set_soul else 0)
	souls = mini(souls, soul_max)
	kill_heal_pct = ArpgData.stat(st, "kill_heal_pct")
	beam_lock = ArpgData.stat(st, "beam_lock")
	bolt_dmg = ArpgData.stat(st, "bolt_dmg")
	fire_self = ArpgData.stat(st, "fire_self")
	if not has.has("tiezhuang"):
		stance = false
	_sync_orbs()


func mikiri_window() -> float:
	return 0.35 if has.has("nifeng") else Hero.MIKIRI_WINDOW


# ---------- 出刀 ----------

## 乘到这一刀伤害上的倍率
func strike_mult(crit: bool) -> float:
	var m := 1.0
	if has.has("duanxian") and not crit:
		m *= 0.8
	if stance:
		m *= 1.25
	if has.has("tanlang"):
		m *= 1.0 + minf(tanlang * 0.02, 0.4)
	if _wind_up > 0.0:
		m *= 1.4
	return m


func crit_add() -> float:
	return 0.35 if _eye_t > 0.0 else 0.0


## 连招最后一段打中（无名剑谱）
func on_finisher_landed() -> void:
	if has.has("jianpu") and float(hero.cd["dash"]) > 0.0:
		hero.cd["dash"] = float(hero.cd["dash"]) * 0.5
		Vfx.I.streaks(hero.chest(), hero.facing, Color(0.75, 1.0, 1.0), 3, 1.4, 0.16, 0.4, 0.1)


# ---------- 翻滚、见切、换手 ----------

func on_roll() -> void:
	if has.has("guiyan"):
		_eye_t = 1.5
	if has.has("lingying") and hero._decoy_cd <= 0.0:
		hero._leave_decoy()


func on_mikiri() -> void:
	if has.has("nifeng"):
		_wind_up = 3.0
		Feel.I.callout(hero.head_top() + Vector3(0.5, 0.6, 0), "逆风", Color(0.6, 1.0, 0.85), 0.9)


func on_swap() -> void:
	if has.has("shuangling"):
		hero._wind_t = maxf(hero._wind_t, 1.2)
		hero.bolt(hero.global_position, 18.0 * hero.dmg_mult, 0.5, false)


# ---------- 挨打 ----------

## 乘到挨打伤害上的倍率
func taken_mult() -> float:
	var m := 1.0
	if stance:
		m *= 0.8
	if has.has("manyue") and hero.energy >= hero.max_energy - 0.01:
		m *= 0.65
	return m


func on_hurt(info: HitInfo) -> void:
	_still = 0.0
	if has.has("jinggu") and info.attacker != null and is_instance_valid(info.attacker) and info.attacker.alive and info.attacker.team != hero.team:
		info.attacker.add_bleed(4 + hero.bleed_bonus, hero.bleed_dmg)


# ---------- 突进、光束、喝药、火 ----------

func on_dash_hit(a: Actor) -> void:
	if has.has("leigu") and is_instance_valid(a):
		var p := a.global_position
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(hero) and hero.alive:
				hero.bolt(p, 20.0 * hero.dmg_mult, 0.4))


func on_beam(from: Vector3, to: Vector3, width: float, dmg: float) -> float:
	if has.has("sanzhe"):
		var dir := to - from
		for ang: float in [-0.42, 0.42]:
			var to2 := from + dir.rotated(Vector3.UP, ang)
			Vfx.I.beam(from, to2, 1.8, 0.5)
			hero._beam_line(from, to2, width, dmg * 0.65)
		dmg *= 0.65
	if beam_lock > 0.0:
		lock_t = beam_lock
	if hero.duo.has("mingdeng") and soul_max > 0:
		add_souls(3)
		_fire_t = 0.0
		for i in range(souls):
			get_tree().create_timer(0.06 * i).timeout.connect(_launch)
	return dmg


func energy_locked() -> bool:
	return lock_t > 0.0


func on_heal_start() -> void:
	if has.has("huoyou"):
		for i in range(3):
			var p := hero.global_position + Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * 1.8 + Vector3(0, 0.9, 0)
			get_tree().create_timer(0.08 * i).timeout.connect(func() -> void:
				if is_instance_valid(hero):
					hero._fire_burst(p, 1.2))


func on_fire_burst(p: Vector3, r: float) -> void:
	if fire_self > 0.0 and hero.alive and hero.chest().distance_to(p) < r + 0.4 and hero.iframes <= 0.0:
		hero.hp = maxf(1.0, hero.hp - fire_self)


# ---------- 斩杀、出波、进房（ArpgMain 调） ----------

func on_kill(f: Actor, pos: Vector3, rng: RandomNumberGenerator) -> void:
	if not hero.alive:
		return
	if kill_heal_pct > 0.0:
		hero.hp = minf(hero.hp + hero.max_hp * kill_heal_pct, hero.max_hp)
	if has.has("tanlang"):
		tanlang += 1
	if has.has("chuanxue") and f != null and f.bleed > 0:
		var best: Actor = null
		var bd := 8.0
		for o: Node in get_tree().get_nodes_in_group("foes"):
			var a := o as Actor
			if a == null or not a.alive or a == f:
				continue
			var d := a.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = a
		if best != null:
			best.add_bleed(f.bleed, hero.bleed_dmg)
			Vfx.I.beam(pos + Vector3(0, 0.9, 0), best.chest(), 0.18, 0.25)
	if soul_max > 0 and rng.randf() < soul_rate:
		add_souls(1, pos + Vector3(0, 1.0, 0))


func on_wave() -> void:
	if soul_wave > 0:
		add_souls(soul_wave)


func on_room() -> void:
	tanlang = 0
	_still = 0.0
	stance = false


# ---------- 魂火 ----------

func add_souls(n: int, from: Vector3 = Vector3.INF) -> void:
	if soul_max <= 0:
		return
	var before := souls
	souls = mini(souls + n, soul_max)
	if souls > before:
		if from != Vector3.INF:
			Vfx.I.beam(from, hero.chest(), 0.14, 0.25)
		Vfx.I.pop(hero.chest(), "flare_01", SOUL_COLOR, 0.4, 1.4, 0.25, true, 0.0, 2.0)
		Game.sfx("ghost", -16.0, 0.2, 1.4)
	_sync_orbs()


func _sync_orbs() -> void:
	if Vfx.I == null:
		return
	while _orbs.size() < souls:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.5, 1.5)
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Vfx.I._mat(mi, true, "flare_01", SOUL_COLOR, true, 4.0)
		add_child(mi)
		_orbs.append(mi)
	while _orbs.size() > souls:
		var mi: MeshInstance3D = _orbs.pop_back()
		mi.queue_free()


func _nearest(from: Vector3, maxd: float, skip: Array = []) -> Actor:
	var best: Actor = null
	var bd := maxd
	for o: Node in get_tree().get_nodes_in_group("foes"):
		var a := o as Actor
		if a == null or not a.alive or skip.has(a):
			continue
		var d := a.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = a
	return best


func _launch() -> void:
	if souls <= 0 or not is_instance_valid(hero) or not hero.alive:
		return
	var tgt := _nearest(hero.global_position, 11.0)
	if tgt == null:
		return
	souls -= 1
	var start: Vector3 = hero.chest() + Vector3(0, 0.6, 0)
	if not _orbs.is_empty():
		start = (_orbs.back() as MeshInstance3D).global_position
	_sync_orbs()
	var sf := SoulFire.new()
	sf.owner_relics = self
	sf.target = tgt
	sf.hops = 3 if set_soul else 1
	sf.damage = 14.0 * hero.dmg_mult * (1.0 + soul_dmg) * (1.5 if set_soul else 1.0)
	get_tree().current_scene.add_child(sf)
	sf.global_position = start


## 魂火打中一个敌人（SoulFire 调）
func soul_hit(a: Actor, dmg: float, from_dir: Vector3) -> bool:
	var info := HitInfo.make(hero, a, dmg * randf_range(0.92, 1.08), HitInfo.Weight.LIGHT)
	info.attacker = null
	info.dir = from_dir
	info.knock = 2.5
	info.stun = 0.15
	if hero.duo.has("xuepo"):
		info.bleed = 2 + hero.bleed_bonus
		info.bleed_mult = hero.bleed_dmg
	if not Feel.I.on_hit(info):
		return false
	if soul_heal > 0.0:
		hero.hp = minf(hero.hp + soul_heal, hero.max_hp)
	if has.has("gudi") and randf() < 0.25:
		hero.bolt(a.global_position, 20.0 * hero.dmg_mult, 0.4)
	hero._check_blood(a)
	return true


# ---------- 每帧 ----------

func _physics_process(dt: float) -> void:
	if hero == null or not hero.alive or Feel.I == null or Feel.I.world_pause > 0.0:
		return
	_eye_t = maxf(_eye_t - dt, 0.0)
	_wind_up = maxf(_wind_up - dt, 0.0)
	lock_t = maxf(lock_t - dt, 0.0)
	var fighting := not get_tree().get_nodes_in_group("foes").is_empty()
	# 铁桩：没按方向、不在翻滚突进里，站够 0.5 秒
	if has.has("tiezhuang"):
		if hero.input_dir() == Vector3.ZERO and hero.state in ["move", "attack", "art_cast"] and fighting:
			_still += dt
		else:
			_still = 0.0
		var now := _still >= 0.5
		if now != stance:
			stance = now
			if stance:
				Vfx.I.shock_ring(hero.global_position, Color(1.0, 0.8, 0.4), 0.3, 2.4, 0.3)
				Feel.I.callout(hero.head_top(), "扎桩", Color(1.0, 0.82, 0.45), 0.7)
		if stance and Engine.get_physics_frames() % 20 == 0:
			Vfx.I.ground(hero.global_position, "lm_circle_a", Color(1.0, 0.75, 0.35, 0.45), 1.4, 1.8, 0.4, true)
	if fighting and has.has("bilei"):
		_bolt_t -= dt
		if _bolt_t <= 0.0:
			var t := _nearest(hero.global_position, 12.0)
			if t != null:
				_bolt_t = 5.0
				hero.bolt(t.global_position, 26.0 * hero.dmg_mult, 0.5)
	if fighting and has.has("zhenhun"):
		_bell_t -= dt
		if _bell_t <= 0.0:
			_bell_t = 10.0
			_bell()
	# 魂火：绕身转，隔一会儿飞一团
	_orb_t += dt
	for i in range(_orbs.size()):
		var ang := _orb_t * 2.4 + TAU * i / maxf(_orbs.size(), 1)
		(_orbs[i] as MeshInstance3D).global_position = hero.global_position + Vector3(cos(ang) * 1.1, 1.5 + sin(_orb_t * 3.0 + i) * 0.15, sin(ang) * 1.1)
	if souls > 0 and fighting:
		_fire_t -= dt
		if _fire_t <= 0.0:
			_fire_t = 0.8
			_launch()


func _bell() -> void:
	var p := hero.global_position
	Vfx.I.shock_ring(p, Color(1.0, 0.85, 0.4), 0.5, 7.0, 0.5)
	Vfx.I.sheet("parry", p + Vector3(0, 0.15, 0), 3.4, Color(1.0, 0.9, 0.6), 1.6, false, 0.0, 1.0)
	Game.sfx("gong", -8.0, 0.05)
	for o: Node in get_tree().get_nodes_in_group("foes"):
		var a := o as Foe
		if a == null or not a.alive or a.global_position.distance_to(p) > 3.6:
			continue
		var d := a.global_position - p
		d.y = 0
		a.knock = d.normalized() * (9.0 if not a.is_boss else 2.0)
		a.freeze(0.8 if not a.is_boss else 0.2)
