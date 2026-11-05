class_name ArpgTrial
extends Node
## 试炼房：同一个房间里连着过四道试，每道换一个维度，房间的光色也跟着变。
##   疾：一大群小怪，限时清完
##   守：地面不断冒出骨刺机关（红圈预警后顶出来，敌人也会被扎），这一试最多挨 GUARD_HITS 下
##   狂：混进带金边的精英（更硬、带霸体），这一试打出一定连击
##   乱：所有敌人变快、成群涌来，清完时生命不低于一半
## 每过一试得一枚“印”；印越多，最后的装备品质越高，铜钱、魂玉越多；四印全得多给一个心法选项。
## 挂在 Arena 底下，换房间时跟着房间一起释放。

const STAGES := [
	{"id": "swift", "name": "疾", "goal": "限时 %d 秒清完", "sun": Color(1.0, 0.95, 0.85), "fog": Color(0.35, 0.55, 0.55)},
	{"id": "guard", "name": "守", "goal": "躲开机关，最多挨 %d 下", "sun": Color(0.75, 1.0, 0.75), "fog": Color(0.3, 0.5, 0.35)},
	{"id": "fury", "name": "狂", "goal": "打出 %d 连击", "sun": Color(1.0, 0.6, 0.45), "fog": Color(0.55, 0.25, 0.2)},
	{"id": "chaos", "name": "乱", "goal": "清完时生命不低于一半", "sun": Color(0.8, 0.65, 1.0), "fog": Color(0.35, 0.25, 0.5)},
]
const SWIFT_TIME := 28.0
const FURY_COMBO := 20
## 守试允许挨几下（原来一下都不许，一整波法师+骷髅里太苛刻，机器人和试玩都几乎拿不到）
const GUARD_HITS := 2
const SEAL_COLOR := Color(1.0, 0.82, 0.35)

var main: ArpgMain
var floor_i := 0
var stage := -1
## 每一试的结果：0 没开始 / 1 进行中 / 2 得印 / 3 失手
var results: Array[int] = [0, 0, 0, 0]
var _t := 0.0
var _hits0 := 0
var _max_combo := 0
var _hz_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## 四试的敌人编成（每一试一波）
func make_waves() -> Array:
	var f := floor_i
	var small := "rogue" if f >= 1 else "skeleton"
	return [
		["crawler", 9 + f * 2, small, 3],
		["skeleton", 4 + f, "mage", 2],
		["samurai", 1 + mini(f, 1), small, 3, "crawler", 4],
		["crawler", 8, small, 3 + f, "mage", 1],
	]


func seals() -> int:
	return results.count(2)


## 一试开始（main 在刷这一波怪前调用）
func begin(i: int) -> void:
	stage = i
	results[i] = 1
	_t = 0.0
	_hits0 = main.hero.hits_taken
	_max_combo = 0
	_hz_t = 1.6
	var s: Dictionary = STAGES[i]
	main.hud.banner("第%s试 · %s" % [["一", "二", "三", "四"][i], s["name"]], goal_text(i), 2.0)
	Game.sfx("danger", -4.0)
	main.feel.screen_flash(Color(s["sun"], 0.35), 2.5)
	Vfx.I.shock_ring(main.hero.global_position, s["sun"], 0.5, 9.0, 0.6)
	# 房间换色：日光和雾慢慢转到这一试的颜色
	var tw := create_tween().set_parallel()
	tw.tween_property(main.sun, "light_color", s["sun"], 1.2)
	tw.tween_property(main.world_env.environment, "fog_light_color", s["fog"], 1.2)


func goal_text(i: int) -> String:
	var g := String(STAGES[i]["goal"])
	match String(STAGES[i]["id"]):
		"swift":
			return g % int(SWIFT_TIME)
		"fury":
			return g % FURY_COMBO
		"guard":
			return g % GUARD_HITS
	return g


## 一试的敌人全清（main 在刷下一波前调用），判这一试得不得印
func finish() -> void:
	if stage < 0 or results[stage] != 1:
		return
	var ok := false
	match String(STAGES[stage]["id"]):
		"swift":
			ok = _t <= SWIFT_TIME
		"guard":
			ok = main.hero.hits_taken - _hits0 <= GUARD_HITS
		"fury":
			ok = _max_combo >= FURY_COMBO
		"chaos":
			ok = main.hero.hp >= main.hero.max_hp * 0.5
	results[stage] = 2 if ok else 3
	if main._args.has("tel"):
		print("trial %s ok=%s t=%.1f combo=%d hits=%d hp=%d" % [STAGES[stage]["id"], ok, _t, _max_combo, main.hero.hits_taken - _hits0, int(main.hero.hp)])
	var p := main.hero.head_top() + Vector3(0, 0.5, 0)
	if ok:
		main.feel.callout(p, "得「%s」印" % STAGES[stage]["name"], SEAL_COLOR, 1.4)
		Game.sfx("reward", -4.0)
		Vfx.I.shock_ring(main.hero.global_position, SEAL_COLOR, 0.4, 5.0, 0.45)
	else:
		main.feel.callout(p, "「%s」印失手" % STAGES[stage]["name"], Color(0.6, 0.65, 0.7), 1.2)


## 给这一试的敌人加料：狂试的赤甲武士成精英，乱试的全体加速
func mod_foe(f: Foe) -> void:
	match String(STAGES[maxi(stage, 0)]["id"]):
		"fury":
			if f.kind == "samurai":
				f.max_hp *= 1.6
				f.hp = f.max_hp
				f.max_poise *= 1.5
				f.poise = f.max_poise
				f.display_name = "精英 · " + f.display_name
				f.set_meta("trial_elite", true)
		"chaos":
			f.data = f.data.duplicate()
			f.data["speed"] = float(f.data["speed"]) * 1.35
			f.set_meta("trial_haste", true)


## 敌人进场景后（rig 已建好）再上描边颜色
func dress_foe(f: Foe) -> void:
	if f.rig == null:
		return
	if f.has_meta("trial_elite"):
		f.rig.set_rim(SEAL_COLOR, 0.8)
	elif f.has_meta("trial_haste"):
		f.rig.set_rim(Color(0.75, 0.55, 1.0), 0.55)


func tick(dt: float) -> void:
	if stage < 0 or results[stage] != 1:
		return
	if main.feel.world_pause > 0.0:
		return
	_t += dt
	_max_combo = maxi(_max_combo, main.feel.combo)
	if String(STAGES[stage]["id"]) == "guard":
		_hz_t -= dt
		if _hz_t <= 0.0:
			_hz_t = 1.7 if Arena.lod >= 1 else 2.3
			_spikes()
	main.hud.wave_text = "第%s试 · %s　%s" % [["一", "二", "三", "四"][stage], STAGES[stage]["name"], _status()]


func _status() -> String:
	match String(STAGES[stage]["id"]):
		"swift":
			var left := SWIFT_TIME - _t
			return "剩 %d 秒" % int(ceil(left)) if left > 0.0 else "已超时"
		"guard":
			return "未挨打" if main.hero.hits_taken == _hits0 else "挨打了"
		"fury":
			return "连击 %d / %d" % [mini(_max_combo, FURY_COMBO), FURY_COMBO] if _max_combo < FURY_COMBO else "连击已够"
		"chaos":
			return "生命 %d%%" % int(main.hero.hp / main.hero.max_hp * 100.0)
	return ""


## 守试机关：一根落在主角脚下，几根散在房间里；红圈 0.9 秒后骨刺顶出来，主角和敌人都会被扎
func _spikes() -> void:
	var pts: Array[Vector3] = [main.hero.global_position + main.hero.velocity * 0.35]
	var n := 3 if Arena.lod >= 1 else 2
	var half := main.arena.size * 0.5 - Vector2(2.5, 2.5)
	for i in range(n):
		var a := _rng.randf() * TAU
		var q := main.hero.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 7.0)
		q.x = clampf(q.x, -half.x, half.x)
		q.z = clampf(q.z, -half.y, half.y)
		pts.append(q)
	for p in pts:
		p.y = 0.0
		Vfx.I.telegraph_circle(p, 1.3, Color(1.0, 0.35, 0.2, 0.65), 0.9)
	get_tree().create_timer(0.9, false).timeout.connect(_spikes_hit.bind(pts))


func _spikes_hit(pts: Array[Vector3]) -> void:
	if not is_instance_valid(main) or main.mode != "room" or results[stage] != 1:
		return
	var dmg := 12.0 + floor_i * 4.0
	for p in pts:
		Vfx.I.chips(p, Vector3.UP, Color(0.9, 0.88, 0.8), 6 if Arena.lod >= 1 else 3, 9.0, 0.12)
		Vfx.I.shock_ring(p, Color(1.0, 0.5, 0.3), 0.2, 2.6, 0.25)
		if Arena.lod >= 1:
			Vfx.I.streaks(p, Vector3.UP, Color(1.0, 0.8, 0.6), 3, 2.4, 0.22, 0.25, 0.2)
		for h: Node in get_tree().get_nodes_in_group("heroes"):
			_stab(h as Actor, p, dmg)
		for f: Node in get_tree().get_nodes_in_group("foes"):
			_stab(f as Actor, p, dmg * 2.5)
	main.cam_rig.shake(1)
	Game.sfx("death", -8.0)


func _stab(a: Actor, p: Vector3, dmg: float) -> void:
	if a == null or not a.alive:
		return
	var d := a.global_position - p
	d.y = 0
	if d.length() > 1.3 + a.radius:
		return
	var info := HitInfo.make(null, a, dmg, HitInfo.Weight.LIGHT)
	info.dir = d.normalized() if d.length() > 0.05 else Vector3.FORWARD
	info.point = a.chest()
	info.knock = 7.0
	main.feel.on_hit(info)


## 清房奖励：按得印数给
func reward() -> Dictionary:
	var n := seals()
	return {"rarity": [1, 2, 2, 3, 4][n], "coins": 10 + n * 15, "jade": n, "boons": 4 if n == 4 else 3}
