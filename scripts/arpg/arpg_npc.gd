class_name ArpgNpc
extends Node3D
## 可以互动的人或物（拾骨婆、兵器架、游商、土地庙、奇遇）：主角走近时头上出现“F 名字”，按互动键触发 interacted。

signal interacted(npc: ArpgNpc)

var display := ""
var model_id := ""
var weapon_id := ""
var tint := Color.WHITE
var kit_id := ""             # 不是人，是一件摆设（土地庙、兵器架）
var kit_scale := 1.0
var radius := 2.0
var rig: VoxActor
var used := false            # 用过一次就不再提示（歇脚、奇遇）
var _t := 0.0
var _near := false
var _label: Label3D


func _ready() -> void:
	add_to_group("npcs")
	if model_id != "":
		rig = VoxActor.new()
		add_child(rig)
		rig.setup(model_id, weapon_id, 30.0, tint, 1.0)
		rig.set_rim(Color(1.0, 0.85, 0.5), 0.35)
	elif kit_id != "":
		var piece := VoxelKit.get_piece(kit_id)
		if not piece.is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = piece["mesh"]
			mi.material_override = VoxActor.toon_material()
			mi.scale = Vector3.ONE * VoxActor.PX * kit_scale
			add_child(mi)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 2.0
	cs.shape = cyl
	cs.position.y = 1.0
	sb.add_child(cs)
	add_child(sb)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Feel.I.font if Feel.I != null else Game.font
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.008
	_label.modulate = Color(1.0, 0.9, 0.6)
	_label.position = Vector3(0, 2.6, 0)
	add_child(_label)
	# 脚下一圈淡金色光环，告诉玩家这里能互动
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/lm_ring_b.png"))
	m.set_shader_parameter("color", Color(1.0, 0.8, 0.4, 0.6))
	m.set_shader_parameter("energy", 1.5)
	ring.material_override = m
	ring.rotation.x = -PI / 2
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)


func _process(dt: float) -> void:
	_t += dt
	if rig != null:
		rig.apply(Poses.idle(_t, weapon_id != ""))
	var hero: Hero = null
	for n: Node in get_tree().get_nodes_in_group("heroes"):
		hero = n as Hero
		break
	_near = hero != null and hero.alive and hero.global_position.distance_to(global_position) < radius and not used
	_label.text = (("[%s] %s" % [ArpgInput.key_name(0, "interact"), display]) if not TouchPad.active else "「互」" + display) if _near else display
	_label.modulate.a = 1.0 if _near else 0.55
	if used:
		_label.modulate.a = 0.25
	if _near and Feel.I.world_pause <= 0.0 and Input.is_action_just_pressed(ArpgInput.act(0, "interact")):
		interacted.emit(self)
