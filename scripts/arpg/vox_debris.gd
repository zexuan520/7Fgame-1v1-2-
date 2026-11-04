class_name VoxDebris
extends Node
## 一块飞出去的体素碎片（人偶碎掉的部件、命中溅出来的方块）：受重力、落地弹一下、最后缩小消失。
## 用真实时间走，不受顿帧影响。

var target: Node3D
var vel := Vector3.ZERO
var spin := Vector3.ZERO
var life := 1.4
var floor_y := 0.0
var _t := 0.0
var _s0 := Vector3.ONE


func _ready() -> void:
	if is_instance_valid(target):
		_s0 = target.scale


func _process(dt: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_t += dt
	vel.y -= 22.0 * dt
	var p := target.global_position + vel * dt
	if p.y < floor_y + 0.05 and vel.y < 0.0:
		p.y = floor_y + 0.05
		vel.y = -vel.y * 0.35
		vel.x *= 0.6
		vel.z *= 0.6
		spin *= 0.5
	target.global_position = p
	target.rotate_x(spin.x * dt)
	target.rotate_y(spin.y * dt)
	target.rotate_z(spin.z * dt)
	var k := clampf((life - _t) / 0.4, 0.0, 1.0)
	if k < 1.0:
		var b := target.global_transform.basis.orthonormalized()
		target.global_transform.basis = b.scaled(_s0 * maxf(k, 0.01))
	if _t >= life:
		target.queue_free()
		queue_free()
