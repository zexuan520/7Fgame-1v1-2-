class_name Fx
extends RefCounted
## 打击特效：刀光、残影、尘土、血、冲击环、屏幕闪光。


## 刀光：一道月牙形的弧。角度按朝右写，朝左时自动镜像
class Slash extends Node2D:
	var facing := 1
	var radius := 24.0
	var thickness := 7.0
	var from_angle := -2.2
	var to_angle := 0.6
	var color := Color(1, 1, 1)
	var life := 0.14
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var a := 1.0 - k
		scale = Vector2(facing, 1)
		var n := 14
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(n + 1):
			var f := float(i) / n
			var ang := lerpf(from_angle, to_angle, f)
			# 两头细、中间粗
			var th := thickness * sin(f * PI) * (1.0 - k * 0.5)
			outer.append(Vector2.from_angle(ang) * (radius + k * 4.0))
			inner.append(Vector2.from_angle(ang) * (radius + k * 4.0 - th))
		inner.reverse()
		var pts := outer + inner
		draw_colored_polygon(pts, Color(color, 0.55 * a))
		draw_polyline(outer, Color(1, 1, 1, a), 1.0)


## 直线刀光（突刺）
class Streak extends Node2D:
	var length := 40.0
	var facing := 1
	var color := Color(1, 1, 1)
	var life := 0.14
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / life
		var x := facing * length
		draw_line(Vector2.ZERO, Vector2(x, 0), Color(color, 0.5 * a), 5.0)
		draw_line(Vector2(x * 0.1, 0), Vector2(x, 0), Color(1, 1, 1, a), 1.0)


## 残影：闪身时留下的半透明人影
class Ghost extends Node2D:
	var pose: Dictionary
	var look: Puppet.Look
	var facing := 1
	var color := Color(0.5, 0.8, 1.0)
	var life := 0.22
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		Puppet.draw(self, pose, look, facing, Vector2.ZERO, Color(color, 1.0), 0.45 * (1.0 - _t / life))


## 粒子：尘土、血、火星共用
class Particles extends Node2D:
	var color := Color(0.6, 0.55, 0.5)
	var count := 6
	var speed := Vector2(40, 30)       # 水平、竖直初速度范围
	var dir := 0.0                     # 主方向（-1 左，1 右，0 两边）
	var gravity := 120.0
	var size := 2.0
	var life := 0.4
	var _t := 0.0
	var _p: Array[Vector2] = []
	var _v: Array[Vector2] = []

	func _ready() -> void:
		for i in range(count):
			_p.append(Vector2.ZERO)
			var vx := randf_range(-speed.x, speed.x)
			if dir != 0.0:
				vx = absf(vx) * dir
			_v.append(Vector2(vx, -randf_range(0.2, 1.0) * speed.y))

	func _process(delta: float) -> void:
		_t += delta
		for i in range(_p.size()):
			_v[i].y += gravity * delta
			_p[i] += _v[i] * delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / life
		for pt in _p:
			draw_rect(Rect2(pt.round() - Vector2(size, size) / 2.0, Vector2(size, size)), Color(color, a))


## 冲击环：弹反时向外扩散的圆圈
class Ring extends Node2D:
	var color := Color(1, 0.95, 0.6)
	var max_radius := 26.0
	var life := 0.25
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		draw_arc(Vector2.ZERO, 4.0 + max_radius * k, 0.0, TAU, 24, Color(color, 1.0 - k), 2.0 * (1.0 - k) + 1.0)


## 全屏闪光（处决时变红）
class ScreenFlash extends Node2D:
	var color := Color(1, 0, 0)
	var life := 0.25
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-100, -100, 840, 560), Color(color, 0.35 * (1.0 - _t / life)))
