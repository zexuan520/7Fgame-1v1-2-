class_name FoeLob
extends Node3D
## 泼油俑扔出去的灯油罐：抛一道弧线（落点早就亮着橙圈），落地碎开烧一摊火

const FLIGHT := 0.7

var from := Vector3.ZERO
var to := Vector3.ZERO
var damage := 6.0
var _t := 0.0
var _mi: MeshInstance3D


func _ready() -> void:
	_mi = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.34, 0.4, 0.34)
	_mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.28, 0.16)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 0.9
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	global_position = from


func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / FLIGHT, 0.0, 1.0)
	var p := from.lerp(to, k)
	p.y = lerpf(from.y, 0.2, k) + sin(k * PI) * 3.0
	global_position = p
	_mi.rotation += Vector3(7.0, 5.0, 0.0) * dt
	if Vfx.I != null and Vfx.I.lod > 0 and randf() < dt * 20.0:
		Vfx.I.pop(p, "spark_05", Color(1.0, 0.6, 0.2), 0.15, 0.45, 0.2)
	if k >= 1.0:
		_land()


func _land() -> void:
	var fp := FirePool.new()
	fp.radius = 1.8
	fp.damage = damage
	fp.life = 4.0
	get_parent().add_child(fp)
	fp.global_position = Vector3(to.x, 0, to.z)
	if Vfx.I != null:
		Vfx.I.explosion(Vector3(to.x, 0.4, to.z), 0.55)
		Vfx.I.chips(Vector3(to.x, 0.3, to.z), Vector3.UP, Color(0.5, 0.32, 0.2), 10, 6.0, 0.1)
	Game.sfx("flame", -4.0)
	queue_free()
