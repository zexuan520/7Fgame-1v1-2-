class_name VoxelDog
extends Node3D
## 体素野狗：身子、头（上下颌分开能张嘴）、耳朵、尾巴、四条腿。
## 动画参数照搬 Dog._draw（压低、扑出去拉长、张嘴、低头、跑步摆腿、倒地），读的是同一套状态。

const VS := 2.0

var fighter: Dog
var parts := {}
var _overlay: StandardMaterial3D

static var _meshes := {}


func setup(f: Node2D) -> void:
	fighter = f
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	var lk: Dictionary = fighter.data["look"]
	var key := (lk["fur"] as Color).to_html()
	if not _meshes.has(key):
		_meshes[key] = _build(lk)
	var m: Dictionary = _meshes[key]
	for n in ["body", "head", "jaw", "tail", "leg_fb", "leg_bb", "leg_ff", "leg_bf"]:
		var mi := MeshInstance3D.new()
		mi.mesh = m["leg"] if n.begins_with("leg") else m[n]
		mi.material_overlay = _overlay
		add_child(mi)
		parts[n] = mi


static func _build(lk: Dictionary) -> Dictionary:
	var fur: Color = lk["fur"]
	var dark: Color = lk["fur_dark"]
	var light: Color = lk["fur_light"]
	var out := {}
	# 身子：原点在身体中心，长 12 格（24 像素），胸口高一点
	var g := VoxelGrid.new(1)
	g.box(Vector3i(-6, -2, -2), Vector3i(5, 2, 2), fur, 0.1)
	g.box(Vector3i(2, -2, -2), Vector3i(6, 3, 2), fur, 0.1)
	g.paint(Vector3i(-6, 2, -2), Vector3i(6, 3, 2), dark)       # 背上一道深色
	g.paint(Vector3i(-3, -2, -2), Vector3i(4, -2, 2), light)    # 肚子
	g.box(Vector3i(-1, 3, -1), Vector3i(1, 3, 1), dark, 0.1)    # 炸毛
	out["body"] = g.build(VS, Vector3(0.5, 0.5, 0.5))
	# 头：原点在后脑勺下沿，往前（x+）长嘴
	g = VoxelGrid.new(2)
	g.box(Vector3i(0, 0, -2), Vector3i(3, 3, 2), fur, 0.08)
	g.box(Vector3i(4, 1, -1), Vector3i(6, 2, 1), fur, 0.08)
	g.set_v(Vector3i(7, 2, 0), Color("15121c"))                  # 鼻头
	g.set_v(Vector3i(3, 3, 2), Color("e8c040"))                  # 眼睛（黄）
	g.set_v(Vector3i(3, 3, -2), Color("e8c040"))
	g.box(Vector3i(0, 4, -2), Vector3i(1, 5, -2), dark)          # 耳朵
	g.box(Vector3i(0, 4, 2), Vector3i(1, 5, 2), dark)
	out["head"] = g.build(VS, Vector3(0, 0.5, 0.5))
	g = VoxelGrid.new(3)
	g.box(Vector3i(0, 0, -1), Vector3i(5, 0, 1), light, 0.05)
	g.set_v(Vector3i(5, 1, 0), Color("f0ece0"))                  # 牙
	g.set_v(Vector3i(3, 1, 0), Color("f0ece0"))
	out["jaw"] = g.build(VS, Vector3(0, 1, 0.5))
	g = VoxelGrid.new(4)
	g.box(Vector3i(0, -5, 0), Vector3i(0, 0, 0), fur, 0.1)
	g.box(Vector3i(0, -5, 0), Vector3i(0, -4, 0), light)
	out["tail"] = g.build(VS, Vector3(0.5, 0, 0.5))
	g = VoxelGrid.new(5)
	g.box(Vector3i(0, -5, 0), Vector3i(1, 0, 1), fur, 0.1)
	g.box(Vector3i(0, -6, 0), Vector3i(2, -6, 1), dark)          # 爪子
	out["leg"] = g.build(VS, Vector3(1, 0, 1))
	return out


func sync(_dt: float) -> void:
	if not is_instance_valid(fighter):
		return
	var f := fighter
	var S := Enemy.S
	var crouch := 0.0
	var stretch := 0.0
	var jaw := 0.0
	var head_dip := 0.0
	var rot := 0.0
	var off := Vector2.ZERO
	var run := clampf(absf(f.velocity.x) / float(f.data["speed"]), 0.0, 1.0)
	var ph: float = f._clock * Dog.RUN_FREQ
	match f.state:
		S.WINDUP:
			var k := clampf(f.state_time / maxf(f._hit_times()[0] * f._speed(), 0.01), 0.0, 1.0)
			crouch = 4.0 * k
			jaw = 0.35 * k
			head_dip = 2.0 * k
			off.x = sin(f._clock * 60.0) * 0.6 * k
			run = 0.0
		S.ACTIVE:
			stretch = 5.0
			jaw = 1.0
			run = 1.0
		S.RECOVER:
			crouch = 1.5
			jaw = 0.4
		S.FLINCH, S.STAGGER:
			off.x = -2.0
			head_dip = -2.0
			crouch = 1.0
		S.DYING:
			var k := clampf(f.state_time / 0.35, 0.0, 1.0)
			crouch = 9.0 * k
			head_dip = 4.0 * k
			rot = 0.12 * k
			run = 0.0
	if not f.is_on_floor() and f.state != S.DYING:
		rot = clampf(f.velocity.y / 700.0, -0.5, 0.5)
	visible = f.state != S.DEAD and not (f.state == S.DYING and f.state_time > 1.9)
	var gp := f.global_position
	position = Vector3(gp.x + off.x * f.facing, -gp.y, 0.0)
	scale = Vector3(f.facing, 1, 1)
	rotation = Vector3(0, 0, -rot)

	var y0 := 12.0 - crouch               # 身体中心离地
	var body: MeshInstance3D = parts["body"]
	body.position = Vector3(0, y0, 0)
	body.scale = Vector3(1.0 + stretch / 24.0, 1, 1)
	var head: MeshInstance3D = parts["head"]
	head.position = Vector3(10.0 + stretch * 0.6, y0 + 3.0 - head_dip, 0)
	head.rotation = Vector3(0, 0, -head_dip * 0.05)
	var jw: MeshInstance3D = parts["jaw"]
	jw.position = head.position + Vector3(2.0, 1.0, 0)
	jw.rotation = Vector3(0, 0, -jaw * 0.5 - head_dip * 0.05)
	var tail: MeshInstance3D = parts["tail"]
	tail.position = Vector3(-12.0, y0 + 3.0, 0)
	tail.rotation = Vector3(0, 0, 2.2 + sin(f._clock * 9.0) * 0.25 + run * 0.4)
	# 腿：[前后位置, 相位, 远侧?]
	var legs := {"leg_fb": [8.0, 0.0, -3.0], "leg_bb": [-8.0, PI, -3.0], "leg_ff": [10.0, PI, 3.0], "leg_bf": [-10.0, 0.0, 3.0]}
	for n: String in legs:
		var L: Array = legs[n]
		var swing := sin(ph + float(L[1])) * 0.7 * run
		var mi: MeshInstance3D = parts[n]
		mi.position = Vector3(float(L[0]) + stretch * (0.5 if float(L[0]) > 0 else -0.3), y0 - 1.0, float(L[2]))
		mi.rotation = Vector3(0, 0, swing + (0.6 if f.state == S.ACTIVE and float(L[0]) > 0 else 0.0) - (0.5 if f.state == S.ACTIVE and float(L[0]) < 0 else 0.0))
		if f.state == S.DYING:
			mi.rotation.z = (1.3 if float(L[0]) > 0 else -1.3) * clampf(f.state_time / 0.35, 0.0, 1.0)
	_overlay.albedo_color = f._tint()
