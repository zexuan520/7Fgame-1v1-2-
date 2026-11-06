class_name FoeShot
extends Node3D
## 敌人射出的弩箭：体素箭杆（KayKit Skeleton_Arrow）+ 一条发光尾迹，直线飞，打中主角或撞到墙、柱子就停。
## 翻滚的无敌帧能躲过去（主角 take_hit 返回 false 时箭接着飞）。

var dir := Vector3.FORWARD
var speed := 17.0
var damage := 10.0
var life := 1.3
var color := Color(1.0, 0.55, 0.3)
var owner_foe: Actor
var _t := 0.0
var _glow: MeshInstance3D
var _gmat: ShaderMaterial

static var _sh_add: Shader


func _ready() -> void:
	rotation.y = atan2(-dir.x, -dir.z)
	var wm := VoxelModel.weapon_mesh("arrow", 30.0)
	if wm != null:
		var mi := MeshInstance3D.new()
		mi.mesh = wm
		var m := VoxActor.toon_material()
		m.set_shader_parameter("glow", Vector3(color.r, color.g, color.b) * 0.6)
		mi.material_override = m
		# 网格单位是体素格，要乘 PX 才是米（漏乘时箭有 30 米长，满屏橙色大块）
		mi.scale = Vector3.ONE * VoxActor.PX
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 箭的网格沿 -y（握把在原点），转到沿 -z（往前飞的方向）；往后挪一点让箭头在节点前面
		mi.rotation.x = PI / 2
		mi.position.z = 0.55
		add_child(mi)
	if _sh_add == null:
		_sh_add = load("res://shaders/arpg/fx_add.gdshader")
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 2.2)
	q.center_offset = Vector3(0, -0.7, 0)
	_glow.mesh = q
	_gmat = ShaderMaterial.new()
	_gmat.shader = _sh_add
	_gmat.set_shader_parameter("tex", load("res://assets/fx/trace_01.png"))
	_gmat.set_shader_parameter("color", color)
	_gmat.set_shader_parameter("energy", 2.6)
	_glow.material_override = _gmat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.rotation.x = -PI / 2
	add_child(_glow)


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	var from := global_position
	var to := from + dir * speed * dt
	# 撞墙、撞柱子（地形在第 1 层）
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_poof(hit["position"])
		return
	global_position = to
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position - global_position
		d.y = 0
		if d.length() < 0.55 + hh.radius:
			var info := HitInfo.make(owner_foe if is_instance_valid(owner_foe) else null, hh, damage * randf_range(0.9, 1.1), HitInfo.Weight.LIGHT)
			info.attacker = null
			info.dir = dir
			info.knock = 5.0
			if Feel.I.on_hit(info):
				queue_free()
				return
	# 敌我共享：箭不认人，挡在路上的别的敌人会挨一下（站到弩手和别的怪连成一线）
	if _t > 0.06:
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var ff := f as Foe
			if ff == null or ff == owner_foe or not ff.alive:
				continue
			var d2 := ff.global_position - global_position
			d2.y = 0
			if d2.length() < 0.45 + ff.radius and SharedHazards.hit_foe(ff, "arrow", damage, dir, 4.0):
				Vfx.I.pop(ff.chest(), "spark_01", color, 0.3, 1.2, 0.15)
				queue_free()
				return
	if _t >= life:
		queue_free()


func _poof(p: Vector3) -> void:
	if Vfx.I != null:
		Vfx.I.chips(p, -dir + Vector3.UP, Color(0.75, 0.7, 0.6), 5, 4.0, 0.06)
		Vfx.I.pop(p, "spark_01", color, 0.3, 1.2, 0.15)
	queue_free()
