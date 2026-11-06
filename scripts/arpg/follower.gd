class_name Follower
extends Node3D
## 跟着主角走的小人（灰衣营里放出来的小满）：打不着、不挡路，落后两三米跟着，主角停下她也停下。

var hero: Node3D
var rig: VoxActor
var _t := 0.0
var _phase := 0.0
var _vel := Vector3.ZERO
var _label: Label3D


func setup(model_id: String, tint: Color, k: float, label: String) -> void:
	rig = VoxActor.new()
	add_child(rig)
	rig.setup(model_id, "", 0.0, tint, k)
	rig.set_rim(Color(1.0, 0.85, 0.6), 0.5)
	rig.mat.set_shader_parameter("mono", 0.85)
	_label = Label3D.new()
	_label.text = label
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Feel.I.font if Feel.I != null else Game.font
	_label.font_size = 32
	_label.outline_size = 8
	_label.pixel_size = 0.008
	_label.modulate = Color(1.0, 0.85, 0.6)
	_label.position = Vector3(0, 1.7, 0)
	add_child(_label)


func _process(dt: float) -> void:
	_t += dt
	if hero == null or not is_instance_valid(hero) or rig == null:
		return
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return
	var to := hero.global_position - global_position
	to.y = 0
	var d := to.length()
	var want := Vector3.ZERO
	if d > 9.0:
		# 落太远（换房、翻滚冲出去）：直接跟上
		global_position = hero.global_position - to.normalized() * 2.5
	elif d > 2.6:
		want = to.normalized() * clampf((d - 2.6) * 2.5, 0.0, 6.5)
	_vel = _vel.lerp(want, 1.0 - exp(-8.0 * dt))
	global_position += _vel * dt
	global_position.y = 0
	var sp := _vel.length()
	if sp > 0.3:
		rotation.y = atan2(-_vel.x, -_vel.z)
		_phase += dt * sp * 2.2
		rig.apply(Poses.run(_phase, clampf(sp / 6.0, 0.0, 1.0)))
	else:
		rig.apply(Poses.idle(_t, false))
	_label.visible = _t < 6.0
