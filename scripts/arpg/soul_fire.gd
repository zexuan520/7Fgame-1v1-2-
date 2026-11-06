class_name SoulFire
extends Node3D
## 一团飞出去的魂火：追着目标飞，打中交给 HeroRelics.soul_hit；百鬼大成时打中后再找下一个（hops 次）。

var owner_relics: HeroRelics
var target: Actor
var damage := 14.0
var hops := 1
var speed := 13.0
var _life := 3.0
var _hit: Array = []
var _mi: MeshInstance3D
var _trail_t := 0.0


func _ready() -> void:
	_mi = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	_mi.mesh = q
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Vfx.I != null:
		Vfx.I._mat(_mi, true, "flare_01", HeroRelics.SOUL_COLOR, true, 4.5)
	add_child(_mi)


func _physics_process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_life -= dt
	if _life <= 0.0 or owner_relics == null or not is_instance_valid(owner_relics):
		queue_free()
		return
	if target == null or not is_instance_valid(target) or not target.alive:
		target = _next()
		if target == null:
			queue_free()
			return
	var to := target.chest() - global_position
	var d := to.length()
	if d < 0.6:
		var dir := Vector3(to.x, 0, to.z).normalized()
		owner_relics.soul_hit(target, damage, dir)
		_hit.append(target)
		hops -= 1
		if Vfx.I != null:
			Vfx.I.pop(global_position, "flare_01", HeroRelics.SOUL_COLOR, 0.5, 1.8, 0.22, true, 0.0, 2.4)
		if hops <= 0:
			queue_free()
			return
		target = _next()
		if target == null:
			queue_free()
		return
	global_position += to / d * minf(speed * dt, d)
	speed = minf(speed + dt * 14.0, 24.0)
	_trail_t -= dt
	if _trail_t <= 0.0 and Vfx.I != null and Vfx.I.room_for(1):
		_trail_t = 0.05
		Vfx.I.pop(global_position, "flare_01", Color(HeroRelics.SOUL_COLOR, 0.6), 0.35, 0.1, 0.25, true, 0.0, 1.6)


func _next() -> Actor:
	if owner_relics == null or not is_instance_valid(owner_relics):
		return null
	return owner_relics._nearest(global_position, 9.0, _hit)
