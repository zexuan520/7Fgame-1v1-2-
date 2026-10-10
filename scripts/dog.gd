class_name Dog
extends Enemy
## 野狗：四条腿，身体自己画（不用人形骨架）。招式、AI、受击都和其他敌人一样走 EnemyData。

const RUN_FREQ := 15.0


func _mouth() -> Vector2:
	return Vector2(facing * 20.0, -17.0)


func _glint_pos() -> Vector2:
	if sheet != null:
		return super._glint_pos()
	return _mouth()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state == S.DEAD:
		return
	if sheet != null:
		# 身子是精灵表里的逐帧像素画，这里只画头顶的提示
		if state != S.DYING:
			_draw_overlay(-34.0, _danger())
		return

	var lk: Dictionary = data["look"]
	var tint := _tint()
	var alpha := 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	var crouch := 0.0        # 身体压低
	var stretch := 0.0       # 扑出去时身体拉长
	var jaw := 0.0           # 张嘴
	var head_dip := 0.0
	var run := clampf(absf(velocity.x) / float(data["speed"]), 0.0, 1.0)
	var ph := _clock * RUN_FREQ

	match state:
		S.WINDUP:
			var k := clampf(state_time / maxf(_hit_times()[0] * _speed(), 0.01), 0.0, 1.0)
			crouch = 4.0 * k
			jaw = 0.35 * k
			head_dip = 2.0 * k
			off.x = sin(_clock * 60.0) * 0.6 * k    # 低吼发抖
			run = 0.0
		S.ACTIVE:
			stretch = 5.0
			jaw = 1.0
			run = 1.0
		S.RECOVER:
			crouch = 1.5
			jaw = 0.4
		S.FLINCH, S.STAGGER:
			off.x = -facing * 2.0
			head_dip = -2.0
			crouch = 1.0
		S.DYING:
			# 腿一软趴到地上，侧着头，慢慢消失
			var k := clampf(state_time / 0.35, 0.0, 1.0)
			crouch = 9.0 * k
			head_dip = 4.0 * k
			rot = 0.12 * facing * k
			alpha = 1.0 - clampf((state_time - 1.2) / 0.7, 0.0, 1.0)
			run = 0.0
	if not is_on_floor() and state != S.DYING:
		rot = clampf(velocity.y / 700.0, -0.5, 0.5) * facing   # 起跳抬头，下落低头

	var fur: Color = lk["fur"]
	var dark: Color = lk["fur_dark"]
	var light: Color = lk["fur_light"]
	var c := func(col: Color) -> Color:
		var out := col
		if tint.a >= 1.0:
			out = Color(tint, 1.0)
		elif tint.a > 0.0:
			out = col.lerp(Color(tint, 1.0), tint.a)
		return Color(out, out.a * alpha)
	var outline: Color = c.call(Color("0b0a0e"))

	draw_set_transform(off, rot, Vector2(facing, 1.0))
	var y0 := -12.0 + crouch
	# 腿：远侧两条颜色深，先画
	var legs := [[-8.0, PI, true], [8.0, 0.0, true], [-10.0, 0.0, false], [10.0, PI, false]]
	for leg: Array in legs:
		var jx: float = leg[0]
		var lp: float = ph + float(leg[1])
		var far: bool = leg[2]
		var joint := Vector2(jx + (stretch * 0.6 if jx > 0.0 else -stretch * 0.4), y0 + 1.0)
		var foot := Vector2(joint.x + sin(lp) * 5.0 * run, -maxf(0.0, cos(lp)) * 3.0 * run)
		if state == S.ACTIVE:
			foot = Vector2(joint.x + (7.0 if jx > 0.0 else -7.0), y0 + 7.0)   # 前腿前伸、后腿后蹬
		elif state == S.DYING:
			foot = Vector2(joint.x + (8.0 if jx > 0.0 else -8.0), 0.0)        # 四条腿摊开
		var knee := (joint + foot) / 2.0 + Vector2(-1.5 if jx > 0.0 else 1.5, 0)
		var col: Color = c.call(dark if far else fur)
		draw_polyline(PackedVector2Array([joint, knee, foot]), outline, 4.0)
		draw_polyline(PackedVector2Array([joint, knee, foot]), col, 2.0)
		draw_rect(Rect2(foot + Vector2(-1, -1), Vector2(3, 2)), c.call(dark))

	# 尾巴
	var wag := sin(_clock * (14.0 if state == S.IDLE else 4.0)) * 2.0
	var tail := PackedVector2Array([Vector2(-12.0 - stretch * 0.4, y0 - 4.0), Vector2(-17.0, y0 - 7.0 + wag), Vector2(-20.0, y0 - 5.0 + wag)])
	draw_polyline(tail, outline, 4.0)
	draw_polyline(tail, c.call(fur), 2.0)

	# 身体
	var bx := stretch
	var body := PackedVector2Array([
		Vector2(-13.0 - bx * 0.4, y0 - 5.0), Vector2(-4.0, y0 - 7.0), Vector2(8.0 + bx * 0.6, y0 - 8.0),
		Vector2(12.0 + bx * 0.6, y0 - 4.0), Vector2(10.0 + bx * 0.6, y0 + 1.0), Vector2(0.0, y0 + 2.0),
		Vector2(-12.0 - bx * 0.4, y0 + 1.0),
	])
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, outline, 3.0)
	draw_colored_polygon(body, c.call(fur))
	draw_colored_polygon(PackedVector2Array([body[5], body[4], Vector2(9.0 + bx * 0.6, y0 - 1.0), Vector2(-11.0, y0 - 1.0), body[6]]), c.call(dark))
	draw_line(Vector2(-12.0 - bx * 0.4, y0 - 5.0), Vector2(8.0 + bx * 0.6, y0 - 8.0), c.call(light), 1.0)
	# 背上乱毛
	for i in range(4):
		var x := -9.0 + i * 4.5
		draw_rect(Rect2(x, y0 - 8.0 + absf(sin(i * 2.3)) * 1.5, 1, 2), c.call(dark))

	# 头
	var hx := 14.0 + bx
	var hy := y0 - 8.0 + head_dip
	var head := Vector2(hx, hy)
	draw_circle(head, 5.5, outline)
	draw_circle(head, 4.5, c.call(fur))
	# 耳朵
	var ear := PackedVector2Array([head + Vector2(-3, -3), head + Vector2(-1, -9), head + Vector2(1, -3)])
	draw_colored_polygon(ear, c.call(dark))
	# 上颚
	var snout := PackedVector2Array([head + Vector2(2, -3), head + Vector2(9, -1), head + Vector2(9, 1), head + Vector2(2, 1)])
	draw_polyline(PackedVector2Array([snout[0], snout[1], snout[2], snout[3]]), outline, 2.0)
	draw_colored_polygon(snout, c.call(fur))
	draw_rect(Rect2(head + Vector2(8, -2), Vector2(2, 2)), c.call(Color("1a1414")))
	# 下颚（咬的时候张开）
	var j := jaw * 4.0
	var lower := PackedVector2Array([head + Vector2(2, 1.5), head + Vector2(8, 1.5 + j), head + Vector2(7, 3 + j), head + Vector2(1, 3)])
	draw_colored_polygon(lower, c.call(dark))
	if jaw > 0.3:
		draw_line(head + Vector2(3, 1.5), head + Vector2(8, 1.5 + j * 0.5), c.call(Color(0.95, 0.92, 0.85)), 1.0)
	# 眼睛
	draw_rect(Rect2(head + Vector2(1, -2), Vector2(2, 1)), Color(1.0, 0.25, 0.1, alpha) if tint.a < 1.0 else c.call(fur))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if state != S.DYING:
		_draw_overlay(-34.0, _danger())
