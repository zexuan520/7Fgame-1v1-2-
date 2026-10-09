class_name Fx
extends RefCounted
## 打击特效：刀光、残影、尘土、血、冲击环、屏幕闪光。


## 刀光：一道又宽又亮的月牙。前 30% 的时间刀光扫出去，之后从尾巴往刀尖慢慢消掉。
## 外圈是暖色的边，里面一层奶白的芯，最外沿描一道白线。角度按朝右写，朝左时自动镜像
class Slash extends Node2D:
	var facing := 1
	var radius := 24.0
	var thickness := 7.0
	var from_angle := -2.2
	var to_angle := 0.6
	var color := Color(1, 1, 1)
	var life := 0.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _band(f0: float, f1: float, r: float, th: float, col: Color) -> void:
		var n := 16
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(n + 1):
			var f := lerpf(f0, f1, float(i) / n)
			var ang := lerpf(from_angle, to_angle, f)
			# 刀尖那头粗、尾巴细
			var w := th * pow(sin(clampf(f, 0.0, 1.0) * PI * 0.5 + 0.15), 1.4)
			outer.append(Vector2.from_angle(ang) * r)
			inner.append(Vector2.from_angle(ang) * (r - maxf(w, 0.8)))
		inner.reverse()
		var pts := outer + inner
		if not Geometry2D.triangulate_polygon(pts).is_empty():
			draw_colored_polygon(pts, col)

	func _draw() -> void:
		var k := _t / life
		scale = Vector2(facing, 1)
		var head := clampf(k / 0.3, 0.0, 1.0)              # 刀光扫到哪了
		var tail := clampf((k - 0.3) / 0.7, 0.0, 1.0)      # 尾巴消到哪了
		if head - tail <= 0.01:
			return
		var a := 1.0 - tail * 0.6
		var r := radius + k * 3.0
		var th := thickness * 1.8
		_band(tail, head, r + 1.0, th + 2.0, Color(color.darkened(0.15), 0.75 * a))
		_band(tail, head, r - 1.0, th * 0.62, Color(Color(1.0, 0.97, 0.88).lerp(color, 0.25), 0.95 * a))
		var edge := PackedVector2Array()
		for i in range(13):
			var f := lerpf(tail, head, i / 12.0)
			edge.append(Vector2.from_angle(lerpf(from_angle, to_angle, f)) * (r + 1.0))
		draw_polyline(edge, Color(1, 1, 1, a), 1.0)


## 命中闪光：中间一团白光，四周射出长长的光芒和火星，横着一道光带。
## size 是大小倍数；orb 为 true 时先爆一个大白球（弹反）
class Impact extends Node2D:
	var color := Color(1.0, 0.85, 0.45)
	var size := 1.0
	var orb := false
	var life := 0.28
	var facing := 1
	var _t := 0.0
	var _rays: Array[Vector3] = []     # 方向、长度、粗细
	var _bits: Array[Vector4] = []     # 火星：位置、速度

	func _ready() -> void:
		if orb:
			life = 0.42
		for i in range(int(12 * size) + 5):
			var ang := randf() * TAU
			_rays.append(Vector3(ang, randf_range(20.0, 46.0) * size, randf_range(1.8, 3.4)))
		for i in range(int(12 * size)):
			var ang := randf() * TAU
			var sp := randf_range(60.0, 170.0) * size
			_bits.append(Vector4(0, 0, cos(ang) * sp + facing * 40.0, sin(ang) * sp - 40.0))

	func _process(delta: float) -> void:
		_t += delta
		for i in range(_bits.size()):
			var b := _bits[i]
			b.w += 380.0 * delta
			b.z *= 1.0 - 3.0 * delta
			_bits[i] = Vector4(b.x + b.z * delta, b.y + b.w * delta, b.z, b.w)
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var a := 1.0 - k
		if orb and _t < 0.1:
			# 弹反：一个刺眼的大白球
			var o := 1.0 - _t / 0.1
			draw_circle(Vector2.ZERO, 26.0 * size * (0.6 + 0.4 * o), Color(1, 1, 1, 0.95))
			draw_circle(Vector2.ZERO, 34.0 * size * (0.6 + 0.4 * o), Color(color, 0.35))
		# 横向光带
		var flare := 46.0 * size * (1.0 - k * 0.5)
		draw_rect(Rect2(-flare, -1, flare * 2.0, 2), Color(color.lightened(0.3), 0.8 * a))
		draw_rect(Rect2(-flare * 0.6, -0.5, flare * 1.2, 1), Color(1, 1, 1, a))
		# 光芒：细长的三角
		var grow := 0.4 + 0.6 * sqrt(clampf(k * 3.0, 0.0, 1.0))
		for r in _rays:
			var d := Vector2.from_angle(r.x)
			var n := Vector2(-d.y, d.x)
			var len := r.y * grow
			var w := r.z * (1.0 - k)
			var start := d * (3.0 + 6.0 * k) * size
			draw_colored_polygon(PackedVector2Array([start + n * w, start + d * len, start - n * w]), Color(color, a))
		# 白芯：先大后小
		var core := (12.0 * size) * (1.0 - k) * (1.0 - k)
		if core > 0.5:
			draw_circle(Vector2.ZERO, core * 1.6, Color(color, 0.5 * a))
			draw_circle(Vector2.ZERO, core, Color(1, 1, 1, a))
		for b in _bits:
			draw_rect(Rect2(Vector2(b.x, b.y).round(), Vector2(2, 1 + int(k < 0.5))), Color(color.lightened(0.2), a))


## 血：一大团溅出去的血块，大小不一，落下去的时候拉成水滴
class Splat extends Node2D:
	var dir := 1.0
	var count := 10
	var power := 1.0
	var life := 0.7
	var _t := 0.0
	var _p: Array[Vector2] = []
	var _v: Array[Vector2] = []
	var _r: Array[float] = []

	func _ready() -> void:
		for i in range(count):
			_p.append(Vector2(randf_range(-3, 3), randf_range(-4, 4)))
			var ang := randf_range(-1.1, 0.5)   # 主要往前上方喷
			var sp := randf_range(70.0, 210.0) * power
			var vx := cos(ang) * sp * (dir if dir != 0.0 else (1.0 if randf() < 0.5 else -1.0))
			_v.append(Vector2(vx, sin(ang) * sp))
			_r.append(randf_range(1.5, 4.5) * (0.8 + power * 0.3))

	func _process(delta: float) -> void:
		_t += delta
		for i in range(_p.size()):
			_v[i].y += 520.0 * delta
			_v[i].x *= 1.0 - 1.5 * delta
			_p[i] += _v[i] * delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var a := 1.0 - k * k
		for i in range(_p.size()):
			var r := _r[i] * (1.0 - k * 0.5)
			var col := Color(0.62, 0.04, 0.07, a) if i % 3 else Color(0.85, 0.1, 0.1, a)
			draw_circle(_p[i].round(), r, col)
			# 拖出来的尾巴
			var tail := _p[i] - _v[i].normalized() * r * 1.8
			draw_line(_p[i], tail, Color(col, a * 0.8), maxf(1.0, r))


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
