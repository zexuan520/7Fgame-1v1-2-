class_name HeroBurn
extends Node3D
## 长明：光束斩在地上烧出的一道光痕。站在上面的敌人每 0.5 秒挨烫一次。

var hero: Hero
var from := Vector3.ZERO
var to := Vector3.ZERO
var life := 3.0
var damage := 6.0
var bleed := 0
var width := 1.3
var tint := Color(0.45, 1.0, 1.0)   # 长明青白；震岳火缝橙红
var blob := 1.0                      # 地上光斑大小（火缝要细一点）
var _t := 0.0
var _tick := 0.2
var _spark := 0.0


func _ready() -> void:
	var seg := to - from
	var n := maxi(int(seg.length() / (1.6 * blob)), 2)
	for i in range(n + 1):
		var p := from.lerp(to, float(i) / n)
		Vfx.I.ground(p, "lm_circle_a", Color(tint, 0.75), 1.9 * blob, 2.3 * blob, life, true, 0.1)
		if blob >= 1.0:
			Vfx.I.ground(p, "magic_03", Color(tint.lightened(0.3), 0.5), 1.4, 1.8, life * 0.9, true, 0.15)
		else:
			Vfx.I.ground(p, "scorch_01", Color(0.08, 0.04, 0.02, 0.7), 1.2 * blob, 1.4 * blob, life + 0.5, false)
	var l := OmniLight3D.new()
	l.light_color = tint
	l.light_energy = 1.4
	l.omni_range = seg.length() * 0.6
	add_child(l)
	l.global_position = (from + to) * 0.5 + Vector3(0, 0.8, 0)


func _physics_process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	_tick -= dt
	_spark -= dt
	if _spark <= 0.0:
		_spark = 0.12 if Vfx.I.lod > 0 else 0.3
		var p := from.lerp(to, randf()) + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
		Vfx.I.pop(p, "light_01", tint.lightened(0.2), 0.3, 0.1, 0.6)
		Vfx.I.streaks(p, Vector3.UP, tint.lightened(0.2), 1, 1.0, 0.3, 0.1, 0.08)
	if _tick <= 0.0:
		_tick = 0.5
		var seg := to - from
		seg.y = 0
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a == null or not a.alive:
				continue
			var k := clampf((a.global_position - from).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
			var cp := from + seg * k
			var d := a.global_position - cp
			d.y = 0
			if d.length() <= width + a.radius:
				var info := HitInfo.make(hero if is_instance_valid(hero) else null, a, damage, HitInfo.Weight.LIGHT)
				info.attacker = null
				info.knock = 0.5
				info.bleed = bleed
				info.hitstop = 0.02
				info.shake = 0
				Feel.I.on_hit(info)
				Vfx.I.pop(a.chest(), "flare_01", tint.lightened(0.2), 0.8, 1.6, 0.2)
	if _t >= life:
		queue_free()
