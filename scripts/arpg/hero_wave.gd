class_name HeroWave
extends Node3D
## 破风：连招第四段挥出的飞行剑气。沿直线飞，穿透，每个敌人只挨一次；一路留下月牙刀光和地面刀痕。

var hero: Hero
var dir := Vector3.FORWARD
var speed := 20.0
var range_m := 9.0
var damage := 18.0
var bleed := 0
var width := 1.2
var _gone := 0.0
var _fx_t := 0.0
var _hit := {}


func _physics_process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	var step := speed * dt
	global_position += dir * step
	_gone += step
	_fx_t -= dt
	if _fx_t <= 0.0:
		_fx_t = 0.035 if Vfx.I.lod > 0 else 0.07
		var yaw := atan2(dir.x, dir.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw + PI), global_position + Vector3(0, 0.9, 0))
		Vfx.I.slash(xf, 1.5, deg_to_rad(-75), deg_to_rad(75), 0.16, Color(1, 1, 1), Color(0.45, 0.95, 1.0), 3.4, 0.62)
		if randf() < 0.5:
			Vfx.I.scar(global_position, dir, 1.1, 0.8)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _hit.has(a):
			continue
		var to := a.global_position - global_position
		to.y = 0
		if to.length() <= width + a.radius:
			_hit[a] = true
			var info := HitInfo.make(hero if is_instance_valid(hero) else null, a, damage * randf_range(0.95, 1.08), HitInfo.Weight.HEAVY)
			info.attacker = null
			info.dir = dir
			info.knock = 6.0
			info.bleed = bleed
			info.bleed_mult = hero.bleed_dmg if is_instance_valid(hero) else 1.0
			if Feel.I.on_hit(info) and is_instance_valid(hero):
				hero.on_skill_hit(a, info)
			Vfx.I.cut_line(a.chest(), dir.rotated(Vector3.UP, PI / 2) + Vector3(0, 0.4, 0), 2.6, Color(1, 1, 1), 0.2, 0.2, Color(0.45, 0.95, 1.0))
	if _gone >= range_m:
		Vfx.I.shock_ring(global_position, Color(0.45, 0.95, 1.0), 0.3, 2.4, 0.25)
		queue_free()
