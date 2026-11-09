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
var _label: Label3D          # 只当“名字 / 显不显示”的记录用，不画（画在下面的 2D 名牌上）
var _plate: Label            # 2D 名牌：画在后期处理层上面，不被移轴模糊、调色压暗，也能夹在屏幕里（审查第 17 条）


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
	_label.position = Vector3(0, 2.6, 0)
	_label.modulate = Color(1, 1, 1, 0)
	_label.outline_modulate = Color(0, 0, 0, 0)
	add_child(_label)
	var cl := CanvasLayer.new()
	cl.layer = 5      # 后期处理层（1）之上、HUD（6）之下
	add_child(cl)
	_plate = Label.new()
	_plate.add_theme_font_override("font", _label.font)
	_plate.add_theme_font_size_override("font_size", 19)
	_plate.add_theme_constant_override("outline_size", 7)
	_plate.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_plate)
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
	_update_plate()
	if _near and Feel.I.world_pause <= 0.0 and Input.is_action_just_pressed(ArpgInput.act(0, "interact")):
		interacted.emit(self)


static var _plates: Array[Rect2] = []
static var _plates_frame := -1


func _update_plate() -> void:
	var cam := get_viewport().get_camera_3d()
	var hh := (rig.height * VoxActor.PX * rig.scale_k + 0.25) if rig != null else 1.7 * kit_scale
	var head := global_position + Vector3(0, hh, 0)
	if cam == null or not _label.visible or not is_visible_in_tree() or cam.is_position_behind(head):
		_plate.visible = false
		return
	_plate.visible = true
	_plate.text = _label.text
	var a := 1.0 if _near else 0.9
	if used:
		a = 0.45
	_plate.modulate = Color(1.0, 0.9, 0.6, a) if _near else Color(0.96, 0.9, 0.74, a)
	_plate.add_theme_font_size_override("font_size", 22 if _near else 19)
	_plate.reset_size()
	var p := cam.unproject_position(head)
	var vs := get_viewport().get_visible_rect().size
	var sz := _plate.size
	# 夹在屏幕里：站在最上沿、最左右边的 NPC，名牌也整块露出来
	var x := clampf(p.x - sz.x * 0.5, 8.0, vs.x - sz.x - 8.0)
	var y := clampf(p.y - sz.y, 6.0, vs.y - sz.y - 6.0)
	# 几块名牌挤在一起（都被夹到屏幕上沿）时往下错开，不叠成一团
	var f := Engine.get_process_frames()
	if f != _plates_frame:
		_plates_frame = f
		_plates.clear()
	var r := Rect2(x, y, sz.x, sz.y)
	for i in range(8):
		var hit := false
		for o: Rect2 in _plates:
			if o.grow(2.0).intersects(r):
				r.position.y = o.end.y + 2.0
				hit = true
		if not hit:
			break
	_plates.append(r)
	_plate.position = r.position
