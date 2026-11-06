class_name RoomHazard
extends Node3D
## 房间机关：有的“阵”会带一种环境机关，打怪的同时隔一阵在主角身边冒出来（先亮预警，再生效）。
## miasma 瘴林起瘴（绿）、bones 冢下骨刺（骨白）、bell 寺钟声浪（金环，翻滚穿过）、
## geyser 地宫涌泉（青）、molten 灯冢滴铜汁（橙）、arrows 营地箭雨（橙红小圈）。
## 只在波次进行中生效，清场就停。伤害按层数涨，不高，主要是逼人挪位置。

const NAMES := {"miasma": "林子里起瘴了", "bones": "地下有骨头在顶", "bell": "寺里的钟自己响了",
	"geyser": "脚下的水在翻", "molten": "顶上在滴铜汁", "arrows": "望楼上有弩手"}

var kind := ""
var main: Node
var dmg := 10.0
var _t := 4.0
var _hinted := false


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	if main == null or not is_instance_valid(main) or main.get("mode") != "room":
		return
	if bool(main.get("_room_done")) or int(main.get("wave_i")) < 0:
		return
	var hero: Hero = main.get("hero")
	if hero == null or not hero.alive:
		return
	_t -= dt
	if _t > 0.0:
		return
	if not _hinted:
		_hinted = true
		Feel.I.callout(hero.head_top() + Vector3(0, 0.8, 0), String(NAMES.get(kind, "")), Vfx.ELEM_COLOR.get(_elem(), Color(1, 0.8, 0.5)), 1.6)
	var hp := hero.global_position + hero.velocity * 0.45
	hp.y = 0
	match kind:
		"miasma":
			_t = randf_range(6.0, 7.5)
			for i in range(2):
				var p := hp if i == 0 else hp + _rand_off(2.5, 5.0)
				var fp := FirePool.new()
				fp.elem = "poison"
				fp.radius = 1.8
				fp.damage = dmg * 0.4
				fp.life = 5.0
				fp.warn = 1.0
				main.add_child(fp)
				fp.global_position = _clamp(p)
		"bones":
			_t = randf_range(5.5, 7.0)
			for i in range(3):
				var p := _clamp(hp if i == 0 else hp + _rand_off(1.8, 3.5))
				Vfx.I.telegraph_circle(p, 1.2, Vfx.DANGER["bone"], 0.9)
				get_tree().create_timer(0.9).timeout.connect(_bone.bind(p))
		"bell":
			_t = randf_range(9.0, 11.0)
			# 声浪从屋子中间往外推，满屋子都会扫到：翻滚穿过，或者躲到柱子后面也没用
			var c := Vector3(0, 0, -1.0)
			Vfx.I.ground(c, "magic_01", Vfx.DANGER["holy"], 1.0, 8.0, 1.3)
			Feel.I.callout(c + Vector3(0, 2.2, 0), "铛——", Color(1.0, 0.85, 0.45), 1.2)
			get_tree().create_timer(1.1).timeout.connect(func() -> void:
				if not is_instance_valid(self) or main.get("mode") != "room":
					return
				var t := TideRing.new()
				t.damage = dmg
				t.color = Color(1.0, 0.8, 0.35)
				t.elem = "holy"
				t.speed = 6.0
				t.max_r = 26.0
				main.add_child(t)
				t.global_position = c
				Game.sfx("block", -3.0, 0.0, 0.45))
		"geyser":
			_t = randf_range(5.5, 7.0)
			for i in range(3):
				var p := _clamp(hp if i == 0 else hp + _rand_off(2.0, 4.5))
				Vfx.I.telegraph_circle(p, 1.4, Vfx.DANGER["water"], 1.0)
				Vfx.I.chips(p, Vector3.UP, Color(0.6, 0.9, 1.0), 3, 2.0, 0.06)
				get_tree().create_timer(1.0).timeout.connect(_geyser.bind(p))
		"molten":
			_t = randf_range(5.0, 6.5)
			for i in range(3):
				var p := _clamp(hp if i == 0 else hp + _rand_off(2.0, 5.0))
				var fp := FirePool.new()
				fp.radius = 1.5
				fp.damage = dmg * 0.45
				fp.life = 4.0
				fp.warn = 1.1
				main.add_child(fp)
				fp.global_position = p
				get_tree().create_timer(1.0).timeout.connect(_drip.bind(p))
		"arrows":
			_t = randf_range(6.0, 7.5)
			Game.sfx("arrow_volley", -5.0, 0.08, 0.9)   # 望楼上一齐放箭，一秒后落地
			for i in range(6):
				var p := _clamp(hp if i == 0 else hp + _rand_off(1.0, 3.8))
				Vfx.I.telegraph_circle(p, 0.9, Vfx.DANGER["shot"], 1.1)
				get_tree().create_timer(1.1 + i * 0.05).timeout.connect(_arrow.bind(p))
		_:
			_t = 999.0


func _elem() -> String:
	return {"miasma": "poison", "bones": "bone", "bell": "holy", "geyser": "water", "molten": "fire", "arrows": ""}.get(kind, "")


func _rand_off(r0: float, r1: float) -> Vector3:
	var a := randf() * TAU
	return Vector3(cos(a), 0, sin(a)) * randf_range(r0, r1)


## 别落到墙外面去
func _clamp(p: Vector3) -> Vector3:
	var ar: Variant = main.get("arena")
	if ar != null and is_instance_valid(ar):
		var h: Vector2 = ar.size * 0.5
		p.x = clampf(p.x, -h.x + 1.5, h.x - 1.5)
		p.z = clampf(p.z, -h.y + 1.5, h.y - 1.5)
	return p


func _live() -> bool:
	return is_instance_valid(self) and is_instance_valid(main) and main.get("mode") == "room"


func _bone(p: Vector3) -> void:
	if not _live():
		return
	Vfx.I.chips(p, Vector3.UP, Color(0.9, 0.9, 0.8), 10, 9.0, 0.12)
	Vfx.I.streaks(p, Vector3.UP, Color(0.85, 1.0, 0.75), 4, 2.4, 0.22, 0.25, 0.2)
	Vfx.I.shock_ring(p, Vfx.ELEM_COLOR["bone"], 0.2, 2.4, 0.25)
	Game.sfx("death", -9.0, 0.1, 1.3)
	_hit(p, 1.2, dmg, "bone", 7.0)


func _geyser(p: Vector3) -> void:
	if not _live():
		return
	Vfx.I.chips(p, Vector3.UP * 2.0, Color(0.6, 0.92, 1.0), 16, 11.0, 0.1)
	Vfx.I.streaks(p, Vector3.UP, Color(0.6, 0.95, 1.0), 6, 3.6, 0.3, 0.25, 0.22)
	Vfx.I.shock_ring(p, Vfx.ELEM_COLOR["water"], 0.3, 3.0, 0.3)
	Vfx.I.pop(p + Vector3(0, 1.5, 0), "circle_05", Color(0.5, 0.85, 1.0), 0.6, 2.4, 0.3)
	Game.sfx("splash", -3.0, 0.1, 0.8)
	Game.sfx("water_big", -10.0, 0.1)
	_hit(p, 1.4, dmg, "water", 12.0)


func _drip(p: Vector3) -> void:
	if not _live():
		return
	Vfx.I.streaks(p + Vector3(0, 6.0, 0), Vector3.DOWN, Color(1.0, 0.6, 0.2), 2, 6.0, 0.12, 0.05, 0.25)
	Vfx.I.chips(p, Vector3.UP, Color(1.0, 0.6, 0.2), 8, 5.0, 0.08)
	Game.sfx("sizzle", -6.0, 0.1)


func _arrow(p: Vector3) -> void:
	if not _live():
		return
	var d := Vector3(0.25, -1.0, 0.15).normalized()
	Vfx.I.streaks(p - d * 5.0, d, Color(1.0, 0.9, 0.75), 1, 5.0, 0.1, 0.0, 0.08)
	Vfx.I.chips(p, Vector3.UP, Color(0.5, 0.45, 0.4), 4, 3.0, 0.06)
	Vfx.I.pop(p + Vector3(0, 0.2, 0), "spark_05", Color(1.0, 0.8, 0.6), 0.2, 1.0, 0.12)
	Game.sfx("arrow_hit", -6.0, 0.12)
	_hit(p, 0.9, dmg * 0.7, "", 4.0)


func _hit(p: Vector3, r: float, d: float, elem: String, knock: float) -> void:
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var v := hh.global_position - p
		v.y = 0
		if v.length() <= r + hh.radius:
			var info := HitInfo.make(null, hh, d, HitInfo.Weight.LIGHT)
			info.dir = v.normalized() if v.length() > 0.01 else Vector3.FORWARD
			info.point = hh.chest()
			info.knock = knock
			info.elem = elem
			Feel.I.on_hit(info)
