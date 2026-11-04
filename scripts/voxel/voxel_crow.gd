class_name VoxelCrow
extends Node3D
## 体素鸦：身子、头（带喙和发光的眼）、尾羽、左右两只翅膀（绕肩膀上下扇）。
## 状态照 Crow：盘旋时慢扇、蓄力时快扇并后仰、俯冲时收翅前倾、挨刀翻一下、死了往下掉。

const VS := 2.0

var fighter: Crow
var parts := {}
var _overlay: StandardMaterial3D
var _eye: StandardMaterial3D

static var _meshes := {}


func setup(f: Node2D) -> void:
	fighter = f
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	var lk: Dictionary = fighter.data["look"]
	var key := (lk["feather"] as Color).to_html()
	if not _meshes.has(key):
		_meshes[key] = _build(lk)
	var m: Dictionary = _meshes[key]
	var body := Node3D.new()
	body.name = "body_root"
	add_child(body)
	parts["root"] = body
	for n in ["body", "head", "tail", "wing_f", "wing_b"]:
		var mi := MeshInstance3D.new()
		mi.mesh = m["wing"] if n.begins_with("wing") else m[n]
		mi.material_overlay = _overlay
		body.add_child(mi)
		parts[n] = mi
	_eye = StandardMaterial3D.new()
	_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye.albedo_color = Color(1.0, 0.85, 0.3)
	var eye := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.4, 5.2)
	eye.mesh = bm
	eye.material_override = _eye
	eye.position = Vector3(5.0, 4.6, 0)
	(parts["head"] as Node3D).add_child(eye)


static func _build(lk: Dictionary) -> Dictionary:
	var fe: Color = lk["feather"]
	var dark: Color = lk["feather_dark"]
	var beak: Color = lk["beak"]
	var out := {}
	var g := VoxelGrid.new(21)
	g.box(Vector3i(-4, -2, -2), Vector3i(3, 2, 2), fe, 0.08)
	g.box(Vector3i(-2, -3, -1), Vector3i(2, -3, 1), fe.lightened(0.1), 0.05)   # 胸
	g.paint(Vector3i(-4, 2, -2), Vector3i(3, 2, 2), dark)
	out["body"] = g.build(VS, Vector3(0.5, 0.5, 0.5))
	g = VoxelGrid.new(22)
	g.box(Vector3i(0, 0, -2), Vector3i(3, 3, 2), fe, 0.06)
	g.box(Vector3i(4, 1, -1), Vector3i(6, 2, 1), beak, 0.05)
	g.set_v(Vector3i(7, 1, 0), beak.darkened(0.2))
	g.box(Vector3i(0, 4, -1), Vector3i(1, 4, 0), dark)   # 头顶一撮
	out["head"] = g.build(VS, Vector3(0, 0.5, 0.5))
	g = VoxelGrid.new(23)
	g.box(Vector3i(-4, 0, -2), Vector3i(0, 0, 2), dark, 0.08)
	g.box(Vector3i(-5, -1, -1), Vector3i(-4, 0, 1), dark, 0.08)
	out["tail"] = g.build(VS, Vector3(0, 0.5, 0.5))
	# 翅膀：原点在肩膀，往 z 外（远离身子）长，羽尖深色
	g = VoxelGrid.new(24)
	g.box(Vector3i(-3, 0, 0), Vector3i(2, 0, 6), fe, 0.08)
	g.box(Vector3i(-4, 0, 4), Vector3i(0, 0, 8), dark, 0.08)
	g.paint(Vector3i(-4, 0, 7), Vector3i(0, 0, 8), dark.darkened(0.3))
	out["wing"] = g.build(VS, Vector3(0.5, 0.5, 0))
	return out


func sync(_dt: float) -> void:
	if not is_instance_valid(fighter):
		return
	var f := fighter
	var S := Enemy.S
	var gp: Vector2 = f.global_position
	position = Vector3(gp.x, -gp.y + 14.0, 0.0)
	var face := float(f.facing)
	scale = Vector3(face, 1, 1)
	rotation = Vector3(0, -0.35 * face, 0)
	var flap := sin(f._clock * Crow.FLAP_FREQ)
	var pitch := clampf(-f.velocity.y / 900.0, -0.4, 0.4)
	match f.state:
		S.WINDUP:
			flap = sin(f._clock * Crow.FLAP_FREQ * 2.2)
			pitch = 0.45
		S.ACTIVE:
			flap = -0.9
			pitch = -atan2(f.velocity.y, absf(f.velocity.x) + 0.01)
		S.FLINCH, S.STAGGER, S.BROKEN:
			pitch = 0.9 * sin(minf(f.state_time / 0.35, 1.0) * PI)
		S.DYING:
			flap = 0.6
			pitch = -1.2
	var root: Node3D = parts["root"]
	root.rotation = Vector3(0, 0, pitch)
	(parts["head"] as Node3D).position = Vector3(6, 1, 0)
	(parts["tail"] as Node3D).position = Vector3(-8, 1, 0)
	var wf: Node3D = parts["wing_f"]
	var wb: Node3D = parts["wing_b"]
	wf.position = Vector3(0, 4, 4)
	wb.position = Vector3(0, 4, -4)
	wf.rotation = Vector3(-flap * 1.0 + 0.2, 0, 0)
	wb.rotation = Vector3(PI + flap * 1.0 - 0.2, 0, 0)
	_overlay.albedo_color = f._tint()
	_eye.albedo_color = Color(1, 0.3, 0.2) if f.state == S.WINDUP else Color(1.0, 0.85, 0.3)
	visible = f.state != S.DEAD and not (f.state == S.DYING and f.state_time > 1.4)
