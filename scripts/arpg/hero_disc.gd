class_name HeroDisc
extends Node3D
## 秘技·飞轮：掷出去的回旋飞刃。直线飞出 range_m，再追着主角飞回来；去程、回程各打一次（穿透）。

var hero: Hero
var dir := Vector3.FORWARD
var range_m := 10.0
var damage := 16.0
var speed := 17.0
var _back := false
var _gone := 0.0
var _hit := {}
var _spin := 0.0
var _fx_t := 0.0
var _mesh: MeshInstance3D
var _life := 0.0


func _ready() -> void:
	# 飞刃本体：一片发光的旋转圆盘（贴图 twirl）+ 一圈刀光
	_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	_mesh.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", Vfx.I.tex("twirl_02"))
	m.set_shader_parameter("color", Color(1.0, 0.8, 0.45))
	m.set_shader_parameter("billboard", false)
	m.set_shader_parameter("energy", 3.5)
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.rotation.x = -PI / 2
	_mesh.position.y = 0.9
	add_child(_mesh)


func _physics_process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_life += dt
	_spin += dt * 22.0
	_mesh.rotation = Vector3(-PI / 2, 0, 0)
	_mesh.rotate_y(_spin)
	var v := dir
	if _back:
		if not is_instance_valid(hero) or not hero.alive:
			queue_free()
			return
		v = hero.global_position - global_position
		v.y = 0
		if v.length() < 0.8 or _life > 5.0:
			Vfx.I.pop(hero.chest(), "flare_01", Color(1.0, 0.8, 0.45), 0.6, 1.6, 0.2)
			queue_free()
			return
		v = v.normalized()
	global_position += v * speed * dt
	_gone += speed * dt
	if not _back and _gone >= range_m:
		_back = true
		_hit.clear()
		Vfx.I.shock_ring(global_position, Color(1.0, 0.8, 0.45), 0.3, 2.2, 0.2)
	_fx_t -= dt
	if _fx_t <= 0.0:
		_fx_t = 0.05 if Vfx.I.lod > 0 else 0.1
		var xf := Transform3D(Basis(Vector3.UP, _spin), global_position + Vector3(0, 0.9, 0))
		Vfx.I.slash(xf, 0.9, 0.0, -PI * 1.2, 0.14, Color(1, 1, 1), Color(1.0, 0.7, 0.35), 2.8, 0.55)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _hit.has(a):
			continue
		var to := a.global_position - global_position
		to.y = 0
		if to.length() <= 0.9 + a.radius:
			_hit[a] = true
			var info := HitInfo.make(hero if is_instance_valid(hero) else null, a, damage * randf_range(0.95, 1.08), HitInfo.Weight.LIGHT)
			info.attacker = null
			info.dir = v
			info.knock = 4.0
			info.hitstop = 0.04
			if Feel.I.on_hit(info) and is_instance_valid(hero):
				hero.on_skill_hit(a, info)
				hero.art_hits.append(a)
