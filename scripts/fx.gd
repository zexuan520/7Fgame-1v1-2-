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


## 钩锁链子：甩出去 0.06 秒，钩住以后连着主角的手和敌人，主角不在钩锁状态就收回消失
class Chain extends Node2D:
	var player: Node2D
	var target: Node2D
	var _t := 0.0
	var _out := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var alive: bool = is_instance_valid(player) and is_instance_valid(target) and player.state == Player.S.HOOK
		_out = clampf(_t / 0.06, 0.0, 1.0) if alive else _out - delta * 8.0
		if _out <= 0.0 and _t > 0.1:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(player) or not is_instance_valid(target):
			return
		var a: Vector2 = player.global_position + Vector2(player.facing * 8.0, -30.0)
		var b: Vector2 = target.global_position + Vector2(0, -target.body_size.y * 0.55)
		var e := a.lerp(b, _out)
		var n := int(a.distance_to(e) / 5.0)
		for i in range(n + 1):
			var p := a.lerp(e, float(i) / maxf(n, 1))
			draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color(0.75, 0.8, 0.85) if i % 2 == 0 else Color(0.45, 0.48, 0.55))
		draw_line(a, e, Color(0.6, 0.95, 0.9, 0.35), 3.0)
		if _out >= 1.0:
			draw_circle(b, 4.0 + sin(_t * 40.0), Color(0.6, 0.95, 0.9, 0.6))


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


## 精灵残影（主角）：这一帧的剪影，整个染成一个颜色，慢慢淡掉
class SpriteGhost extends Node2D:
	var texture: Texture2D
	var region := Rect2()
	var origin := Vector2.ZERO
	var facing := 1
	var color := Color(0.5, 0.8, 1.0)
	var life := 0.22
	var _t := 0.0

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://scripts/sprite_tint.gdshader")
		mat.set_shader_parameter("tint", Color(color, 1.0))
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
		draw_texture_rect_region(texture, Rect2(-origin, region.size), region, Color(1, 1, 1, 0.45 * (1.0 - _t / life)))


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


## 大白光（快节奏改造）：命中时炸开一大团不规则的尖刺白光，青色描边，同时沿着刀的方向划过一道长光，
## 再崩出一把玻璃碎片似的三角块转着飞出去。size 1 是普通命中，1.5 以上是重击、击杀
class Shatter extends Node2D:
	var size := 1.0
	var rim := Color(0.6, 0.95, 0.9)
	var dir := 1.0               # 刀往哪边走
	var life := 0.16
	var _t := 0.0
	var _spikes: Array[float] = []
	var _rot := 0.0
	var _shards: Array = []       # [位置, 速度, 角度, 角速度, 大小]

	func _ready() -> void:
		_rot = randf() * TAU
		for i in range(16):
			_spikes.append(randf_range(0.55, 1.0) if i % 2 == 0 else randf_range(0.18, 0.32))
		for i in range(int(9 * size)):
			var a := randf() * TAU
			var sp := randf_range(120.0, 300.0) * size
			_shards.append([Vector2.ZERO, Vector2(cos(a) * sp + dir * 80.0, sin(a) * sp - 60.0), randf() * TAU,
				randf_range(-18.0, 18.0), randf_range(2.0, 4.5) * size])

	func _process(delta: float) -> void:
		_t += delta
		for sh: Array in _shards:
			var v: Vector2 = sh[1]
			v.y += 500.0 * delta
			v *= 1.0 - 2.5 * delta
			sh[1] = v
			sh[0] = (sh[0] as Vector2) + v * delta
			sh[2] = float(sh[2]) + float(sh[3]) * delta
		if _t >= 0.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		if k < 1.0:
			# 尖刺白光：一出来最大，然后往里收、变淡
			var r := 64.0 * size * (1.0 - 0.55 * k) * (0.8 + 0.2 * minf(_t / 0.03, 1.0))
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in _spikes.size():
				var a := _rot + TAU * i / _spikes.size()
				var d := Vector2(cos(a), sin(a) * 0.8)
				outer.append(d * r * _spikes[i])
				inner.append(d * r * _spikes[i] * 0.72)
			draw_colored_polygon(outer, Color(rim, 0.9 * (1.0 - k)))
			draw_colored_polygon(inner, Color(1, 1, 1, 1.0 - k * k))
			# 刀路：一道很长的斜光
			var len := 150.0 * size * (0.6 + 0.4 * k)
			var w := 5.0 * size * (1.0 - k)
			var t := Vector2(dir, -0.28).normalized()
			var n := Vector2(-t.y, t.x)
			draw_colored_polygon(PackedVector2Array([-t * len * 0.5, n * w, t * len * 0.5, -n * w]), Color(1, 1, 1, 1.0 - k))
		var fade := clampf(1.0 - (_t - 0.15) / 0.35, 0.0, 1.0)
		for sh: Array in _shards:
			var p: Vector2 = sh[0]
			var a: float = sh[2]
			var sz: float = sh[4]
			var d := Vector2(cos(a), sin(a)) * sz
			var n := Vector2(-d.y, d.x) * 0.55
			draw_colored_polygon(PackedVector2Array([p + d, p + n, p - d * 0.7]), Color(1, 1, 1, fade))
			draw_line(p + d, p - d * 0.7, Color(rim, fade * 0.8), 1.0)


## 星爆火花：弹反、格挡、重击时，一圈长短不一的光芒往外射，中间一点白光，外加几颗火星
class Burst extends Node2D:
	var size := 1.0
	var life := 0.2
	var _t := 0.0
	var _rays: Array[Vector3] = []     # 角度、长度、粗细
	var _embers: Array[Vector4] = []   # 位置 xy、速度 zw

	func _ready() -> void:
		var n := 12
		for i in range(n):
			var a := TAU * i / n + randf_range(-0.2, 0.2)
			var long := i % 3 == 0
			_rays.append(Vector3(a, (randf_range(26.0, 34.0) if long else randf_range(10.0, 18.0)) * size, 2.0 if long else 1.0))
		for i in range(int(8 * size)):
			var a := randf() * TAU
			var sp := randf_range(60.0, 160.0) * size
			_embers.append(Vector4(0, 0, cos(a) * sp, sin(a) * sp - 40.0))

	func _process(delta: float) -> void:
		_t += delta
		for i in range(_embers.size()):
			var e := _embers[i]
			e.w += 380.0 * delta
			_embers[i] = Vector4(e.x + e.z * delta, e.y + e.w * delta, e.z * 0.92, e.w)
		if _t >= life * 2.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		if k < 1.0:
			# 光芒：从里往外伸出去，越往后越细越淡；颜色白 → 黄 → 橙
			var col := Color(1.0, 1.0, 0.92).lerp(Color(1.0, 0.75, 0.25), k)
			for r in _rays:
				var d := Vector2(cos(r.x), sin(r.x))
				var r0 := r.y * (0.15 + 0.6 * k)
				var r1 := r.y * (0.45 + 0.55 * sqrt(k))
				draw_line((d * r0).round(), (d * r1).round(), Color(col, 1.0 - k * 0.7), maxf(1.0, r.z * (1.0 - k)))
			var c := 5.0 * size * (1.0 - k)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -c * 1.4), Vector2(c, 0), Vector2(0, c * 1.4), Vector2(-c, 0)]),
				Color(1, 1, 1, 1.0 - k))
		var ea := 1.0 - clampf(_t / (life * 2.0), 0.0, 1.0)
		for e in _embers:
			draw_rect(Rect2(Vector2(e.x, e.y).round(), Vector2(2, 2) if ea > 0.5 else Vector2(1, 1)), Color(1.0, 0.7, 0.25, ea))


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
