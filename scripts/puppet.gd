class_name Puppet
extends RefCounted
## 像素小人：用骨骼姿势画角色，四肢带深色描边。
## 姿势用字典描述，可以在两个姿势之间插值，做出动画。
##
## 坐标约定（朝右时）：原点在脚底中心，-y 向上。
## 手臂和刀的角度：0 = 垂直向下，PI/2 = 水平向前，PI = 竖直向上，负数 = 向后。

const UPPER_ARM := 6.0
const LOWER_ARM := 6.0
const THIGH := 7.0
const SHIN := 7.0
const TORSO := 11.0

## 外观（颜色和尺寸）
class Look:
	var skin := Color("e8b796")
	var hair := Color("1b1b24")
	var cloth := Color("2b3a67")      # 上衣
	var cloth_dark := Color("1c2647")
	var pants := Color("1e2233")
	var belt := Color("c9a227")
	var blade := Color("e6ecf2")
	var hilt := Color("5a3a22")
	var outline := Color("0b0b12")
	var hat := false                   # 斗笠（浪人）
	var hat_color := Color("c9a86a")
	var scale := 1.0
	var sword_len := 15.0
	var width := 1.0                   # 身材胖瘦


static func base_pose() -> Dictionary:
	return {
		"crouch": 1.0,                 # 臀部下沉
		"lean": 0.1,                   # 上身前倾
		"head": 0.0,
		"foot_f": Vector2(4, 0),       # 前脚相对脚底中心的位置
		"foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.7, 1.4),    # 前手：大臂、小臂角度
		"arm_b": Vector2(-0.2, 0.4),
		"sword": 1.9,
		"dx": 0.0,                     # 整体前后偏移
	}


static func pose(overrides: Dictionary) -> Dictionary:
	var p := base_pose()
	for k in overrides:
		p[k] = overrides[k]
	return p


static func lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	t = clampf(t, 0.0, 1.0)
	for k in a:
		var va = a[k]
		var vb = b.get(k, va)
		if va is float or va is int:
			if k == "sword" or k == "lean" or k == "head":
				out[k] = lerp_angle(float(va), float(vb), t)
			else:
				out[k] = lerpf(float(va), float(vb), t)
		elif va is Vector2:
			if k.begins_with("arm"):
				var av: Vector2 = va
				var bv: Vector2 = vb
				out[k] = Vector2(lerp_angle(av.x, bv.x, t), lerp_angle(av.y, bv.y, t))
			else:
				out[k] = (va as Vector2).lerp(vb, t)
		else:
			out[k] = va
	return out


static func _limb_dir(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))


## 两段骨骼的 IK：已知起点和终点，求关节位置（膝盖朝前）
static func _ik(start: Vector2, end: Vector2, l1: float, l2: float) -> Vector2:
	var to := end - start
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var base := to.angle()
	return start + Vector2.from_angle(base - a) * l1


## 计算各关节位置（朝右、未缩放）
static func solve(p: Dictionary) -> Dictionary:
	var crouch: float = p["crouch"]
	var lean: float = p["lean"]
	var dx: float = p["dx"]
	var hip := Vector2(dx, -(THIGH + SHIN) + crouch)
	var up := Vector2(sin(lean), -cos(lean))
	var neck := hip + up * TORSO
	var head_dir := Vector2(sin(lean + float(p["head"])), -cos(lean + float(p["head"])))
	var head := neck + head_dir * 4.5
	var shoulder := hip + up * (TORSO - 2.0)
	var arm_f: Vector2 = p["arm_f"]
	var arm_b: Vector2 = p["arm_b"]
	var elbow_f := shoulder + _limb_dir(arm_f.x) * UPPER_ARM
	var hand_f := elbow_f + _limb_dir(arm_f.y) * LOWER_ARM
	var elbow_b := shoulder + _limb_dir(arm_b.x) * UPPER_ARM
	var hand_b := elbow_b + _limb_dir(arm_b.y) * LOWER_ARM
	var foot_f: Vector2 = p["foot_f"]
	var foot_b: Vector2 = p["foot_b"]
	foot_f.x += dx
	foot_b.x += dx
	var knee_f := _ik(hip, foot_f, THIGH, SHIN)
	var knee_b := _ik(hip, foot_b, THIGH, SHIN)
	return {
		"hip": hip, "neck": neck, "head": head, "shoulder": shoulder,
		"elbow_f": elbow_f, "hand_f": hand_f, "elbow_b": elbow_b, "hand_b": hand_b,
		"knee_f": knee_f, "foot_f": foot_f, "knee_b": knee_b, "foot_b": foot_b,
		"up": up,
	}


## 刀尖位置（本地坐标，已考虑朝向和缩放），用来画闪光
static func sword_tip(p: Dictionary, look: Look, facing: int) -> Vector2:
	var j := solve(p)
	var hand: Vector2 = j["hand_f"]
	var tip := hand + _limb_dir(float(p["sword"])) * look.sword_len
	return Vector2(tip.x * facing, tip.y) * look.scale


## 把小人画到 ci 上。tint 用于受击闪白、残影变色；alpha 控制透明度
static func draw(ci: CanvasItem, p: Dictionary, look: Look, facing: int,
		offset: Vector2 = Vector2.ZERO, tint: Color = Color(0, 0, 0, 0), alpha: float = 1.0,
		rotation: float = 0.0) -> void:
	var j := solve(p)
	ci.draw_set_transform(offset, rotation, Vector2(facing * look.scale, look.scale))
	var w := look.width

	var c_skin := _tint(look.skin, tint, alpha)
	var c_cloth := _tint(look.cloth, tint, alpha)
	var c_dark := _tint(look.cloth_dark, tint, alpha)
	var c_pants := _tint(look.pants, tint, alpha)
	var c_out := Color(look.outline, alpha)
	var c_blade := _tint(look.blade, tint, alpha)
	var c_hilt := _tint(look.hilt, tint, alpha)

	# 后侧手脚（颜色更暗）
	_limb(ci, j["hip"], j["knee_b"], j["foot_b"], 3.0 * w, c_pants.darkened(0.3), c_out)
	_foot(ci, j["foot_b"], c_out)
	_limb(ci, j["shoulder"], j["elbow_b"], j["hand_b"], 2.0 * w, c_dark, c_out)

	# 前腿
	_limb(ci, j["hip"], j["knee_f"], j["foot_f"], 3.0 * w, c_pants, c_out)
	_foot(ci, j["foot_f"], c_out)

	# 身体：上衣是一个梯形
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var up: Vector2 = j["up"]
	var side := Vector2(-up.y, up.x)
	var torso := PackedVector2Array([
		hip - side * 3.5 * w + up * -1.0, hip + side * 3.5 * w + up * -1.0,
		neck + side * 3.0 * w, neck - side * 3.0 * w,
	])
	_poly_outline(ci, torso, c_out)
	ci.draw_colored_polygon(torso, c_cloth)
	# 衣襟和腰带
	ci.draw_line(neck + side * 1.5, hip - side * 0.5 + up * 3.0, c_dark, 1.0)
	ci.draw_line(hip - side * 3.5 * w + up * 2.0, hip + side * 3.5 * w + up * 2.0, _tint(look.belt, tint, alpha), 1.5)

	# 头
	var head: Vector2 = j["head"]
	ci.draw_circle(head, 4.6, c_out)
	ci.draw_circle(head, 3.6, c_skin)
	# 头发和发髻
	ci.draw_circle(head + Vector2(-1.2, -1.4), 3.2, _tint(look.hair, tint, alpha))
	if not look.hat:
		ci.draw_circle(head + Vector2(-3.6, -2.6), 1.6, _tint(look.hair, tint, alpha))
	# 眼睛
	ci.draw_rect(Rect2(head + Vector2(1.4, -0.6), Vector2(1.2, 1.2)), c_out)
	if look.hat:
		var brim := PackedVector2Array([
			head + Vector2(-8, -1.5), head + Vector2(8, -1.5), head + Vector2(1.5, -6.5), head + Vector2(-1.5, -6.5),
		])
		_poly_outline(ci, brim, c_out)
		ci.draw_colored_polygon(brim, _tint(look.hat_color, tint, alpha))
		ci.draw_line(head + Vector2(-7, -2), head + Vector2(7, -2), _tint(look.hat_color.darkened(0.3), tint, alpha), 1.0)

	# 刀（在前手）
	var hand: Vector2 = j["hand_f"]
	var dir := _limb_dir(float(p["sword"]))
	var tip := hand + dir * look.sword_len
	var guard := hand + dir * 1.5
	ci.draw_line(hand - dir * 3.5, guard, c_out, 3.0)
	ci.draw_line(hand - dir * 3.0, guard, c_hilt, 1.5)
	ci.draw_line(guard, tip, c_out, 3.0)
	ci.draw_line(guard, tip, c_blade, 1.2)
	ci.draw_line(guard - Vector2(-dir.y, dir.x) * 1.5, guard + Vector2(-dir.y, dir.x) * 1.5, _tint(look.belt, tint, alpha), 1.5)

	# 前手臂盖在刀柄上
	_limb(ci, j["shoulder"], j["elbow_f"], j["hand_f"], 2.0 * w, c_cloth, c_out)
	ci.draw_circle(hand, 1.4, c_skin)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _tint(c: Color, tint: Color, alpha: float) -> Color:
	var out := c.lerp(Color(tint.r, tint.g, tint.b), tint.a)
	out.a = alpha
	return out


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, width: float, col: Color, out: Color) -> void:
	ci.draw_line(a, b, out, width + 2.0)
	ci.draw_line(b, c, out, width + 2.0)
	ci.draw_line(a, b, col, width)
	ci.draw_line(b, c, col, width)
	ci.draw_circle(b, width * 0.5, col)


static func _foot(ci: CanvasItem, f: Vector2, out: Color) -> void:
	ci.draw_rect(Rect2(f + Vector2(-2, -1.5), Vector2(5, 2)), out)


static func _poly_outline(ci: CanvasItem, pts: PackedVector2Array, out: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, out, 2.0)
