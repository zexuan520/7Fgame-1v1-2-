class_name Loot
extends Node3D
## 掉落：铜钱（金色小方块）和魂玉（青色发光方块）。先弹出来，0.5 秒后被吸到最近的主角身上。

signal collected(kind: String, amount: int)

var kind := "coin"
var amount := 1
var item := {}            # kind == "gear" 时是掉落的装备
var vel := Vector3.ZERO
var _t := 0.0
var _mi: MeshInstance3D


func _ready() -> void:
	_mi = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3.ONE * (0.16 if kind == "coin" else (0.24 if kind == "jade" else 0.34))
	_mi.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.3) * 1.6 if kind == "coin" else Color(0.4, 1.0, 0.85) * 2.0
	if kind == "gear":
		# 装备：按品质上色的大方块，脚下一道同色光柱，晚一点才吸过来（让人看清是什么）
		m.albedo_color = ArpgGear.color(item) * 2.2
		if Vfx.I != null:
			Vfx.I.pop(global_position, "light_01", ArpgGear.color(item), 0.6, 2.4, 0.5)
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	vel = Vector3(randf_range(-3, 3), randf_range(4, 7), randf_range(-3, 3))


func _process(dt: float) -> void:
	_t += dt
	_mi.rotation.y += dt * 6.0
	_mi.rotation.x += dt * 3.0
	var h: Hero = null
	var bd := 1e9
	for n: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := n as Hero
		if hh != null and hh.alive:
			var d := hh.global_position.distance_squared_to(global_position)
			if d < bd:
				bd = d
				h = hh
	if _t < (1.1 if kind == "gear" else 0.5) or h == null:
		vel.y -= 20.0 * dt
		global_position += vel * dt
		if global_position.y < 0.15:
			global_position.y = 0.15
			vel *= Vector3(0.5, -0.4, 0.5)
		return
	var to := h.chest() - global_position
	var sp := 6.0 + _t * 22.0
	if to.length() < 0.4:
		collected.emit(kind, amount)
		Game.sfx("coin" if kind == "coin" else ("jade" if kind == "jade" else "chest"), -10.0 if kind != "gear" else -4.0, 0.15)
		queue_free()
		return
	global_position += to.normalized() * minf(sp * dt, to.length())
