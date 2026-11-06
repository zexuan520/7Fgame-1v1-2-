class_name HeroBolt
extends Node3D
## 主角射出去的东西：连弩的弩箭、飞镖。直线飞，撞墙停；打中敌人走主角的命中流程（会心、吸血、装备特效都算），
## pierce 是还能再穿几个敌人。

var hero: Hero
var dir := Vector3.FORWARD
var speed := 28.0
var damage := 8.0
var bleed := 0
var life := 0.6
var pierce := 0
var crit := false              # 必定会心（连弩游射）
var step: AttackStep            # 连弩：按这一段连招算伤害；飞镖为 null，直接用 damage
var model := "arrow"
var color := Color(0.6, 1.0, 0.95)
var _t := 0.0
var _hit := {}

static var _sh_add: Shader


func _ready() -> void:
	rotation.y = atan2(-dir.x, -dir.z)
	var wm := VoxelModel.weapon_mesh(model, 30.0 if model == "arrow" else 16.0)
	if wm != null:
		var mi := MeshInstance3D.new()
		mi.mesh = wm
		var m := VoxActor.toon_material()
		m.set_shader_parameter("glow", Vector3(color.r, color.g, color.b) * 0.5)
		mi.material_override = m
		mi.scale = Vector3.ONE * VoxActor.PX
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.x = PI / 2
		mi.position.z = 0.5
		add_child(mi)
	if _sh_add == null:
		_sh_add = load("res://shaders/arpg/fx_add.gdshader")
	var gl := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.36, 2.0)
	q.center_offset = Vector3(0, -0.6, 0)
	gl.mesh = q
	var gm := ShaderMaterial.new()
	gm.shader = _sh_add
	gm.set_shader_parameter("tex", load("res://assets/fx/trace_01.png"))
	gm.set_shader_parameter("color", color)
	gm.set_shader_parameter("energy", 2.4)
	gl.material_override = gm
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gl.rotation.x = -PI / 2
	add_child(gl)


func _process(dt: float) -> void:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	_t += dt
	var from := global_position
	var to := from + dir * speed * dt
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		_poof(hit["position"])
		return
	global_position = to
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive or _hit.has(a):
			continue
		var d := a.global_position - global_position
		d.y = 0
		if d.length() < 0.5 + a.radius:
			_hit[a] = true
			var landed := false
			if is_instance_valid(hero):
				landed = hero.bolt_hit(a, self)
			if landed:
				if pierce <= 0:
					queue_free()
					return
				pierce -= 1
	if _t >= life:
		queue_free()


func _poof(p: Vector3) -> void:
	if Vfx.I != null:
		Vfx.I.chips(p, -dir + Vector3.UP, Color(0.75, 0.7, 0.6), 4, 4.0, 0.06)
		Vfx.I.pop(p, "spark_01", color, 0.3, 1.1, 0.12)
	queue_free()
