class_name Puppet
extends RefCounted
## 像素角色：用骨骼姿势画出有体积的角色（和服、袴、袖子、刀），带明暗、描边和轮廓光。
## 姿势用字典描述，可以在两个姿势之间插值，做出动画。
##
## 坐标约定（朝右时）：原点在脚底中心，-y 向上。角色约 51 像素高。
## 手臂和刀的角度：0 = 垂直向下，PI/2 = 水平向前，PI = 竖直向上，负数 = 向后。
## 姿势里的位移（脚的位置、下蹲、前后偏移）按旧单位写，乘以 U 换算成像素。

const U := 1.5
const UPPER_ARM := 9.0
const LOWER_ARM := 8.5
const THIGH := 11.0
const SHIN := 11.0
const TORSO := 16.0
const HEAD_R := 6.2

## 外观（颜色和尺寸）
class Look:
	var skin := Color("e9b48f")
	var skin_dark := Color("b97a5f")
	var hair := Color("16141f")
	var cloth := Color("2c3c74")       # 和服
	var cloth_dark := Color("1b2550")
	var cloth_light := Color("4a63a8")
	var collar := Color("d8d2c4")      # 里衣领口
	var pants := Color("23222f")       # 袴
	var pants_dark := Color("15141d")
	var pants_light := Color("3a384c")
	var belt := Color("b8892c")        # 腰带
	var band := Color("c23a32")        # 头带
	var blade := Color("c9d3de")
	var blade_edge := Color("ffffff")
	var hilt := Color("2a1d22")
	var tsuba := Color("c9a227")
	var outline := Color("08070d")
	var saya := false                  # 腰间刀鞘（主角）
	var saya_color := Color("2a1a22")
	var hat := false                   # 斗笠（浪人）
	var hat_color := Color("b8955a")
	var hat_dark := Color("7d6138")
	var cape := false                  # 破披风（浪人）
	var cape_color := Color("3a2a2a")
	var eye_glow := Color(0, 0, 0, 0)  # 眼睛发光（第二阶段）
	var scale := 1.0
	var sword_len := 24.0
	var width := 1.0
	var weapon := "katana"             # katana 太刀 / dual 双短刃 / nodachi 野太刀 / spear 长枪 / fist 铁拳
	var helm := ""                     # 头甲：hood 头巾 / kasa 斗笠 / kabuto 铁盔
	var armor := ""                    # 身甲：vest 短打 / leather 皮甲 / plate 铁甲


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
		"blur": 0.0,                   # 刀转起来时的残影间隔（弧度，带方向）
		"sword_at": Vector2.ZERO,      # 刀脱手时刀柄的位置（抛刀）
		"sword_free": 0.0,             # 0 刀在手里，1 刀在 sword_at
		"sheathed": 0.0,               # 大于 0.5 时刀收在鞘里（拔刀式）
		"twist": 0.0,                  # 上身扭转：负数蓄力时把肩膀往后拧，正数出刀时把肩膀送出去
		"grip": 0.0,                   # 1 = 双手握刀：后手自动握在刀柄上（太刀、野太刀、长枪）
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


## 姿势弹簧：每个关节按弹簧运动追目标姿势，带速度和惯性。
## 比直接插值顺：起动有加速、停下有缓冲，出刀太快时还会甩过头一点再弹回来（跟随动作）。
## freq 越大跟得越紧（Hz），zeta 越小越容易甩过头（1 为刚好不过冲）。
class Spring:
	const SNAP := ["sheathed", "sword_free", "sword_at", "blur"]   # 这些直接跳到目标
	const ANGLE := ["sword", "lean", "head"]
	var pose: Dictionary = {}
	var vel: Dictionary = {}
	## 每个关节的频率倍数（没写的按 1）。出刀时腿和腰快、刀慢一点，就是"身体先动，刀被带出去"
	var lag: Dictionary = {}

	func reset(p: Dictionary) -> void:
		pose = p.duplicate()
		vel = {}

	func step(target: Dictionary, freq: float, zeta: float, dt: float) -> Dictionary:
		for k: String in target:
			var t = target[k]
			if not pose.has(k) or k in SNAP:
				pose[k] = t
				continue
			var w := TAU * freq * float(lag.get(k, 1.0))
			var n := maxi(1, ceili(dt * w / 0.3))   # 分几小步算，频率高也稳定
			var h := dt / n
			if t is float or t is int:
				var ang := k in ANGLE
				var x: float = pose[k]
				var v: float = vel.get(k, 0.0)
				for i in range(n):
					var err := angle_difference(x, float(t)) if ang else float(t) - x
					v += (w * w * err - 2.0 * zeta * w * v) * h
					x += v * h
				pose[k] = x
				vel[k] = v
			elif t is Vector2:
				var ang := k.begins_with("arm")
				var x: Vector2 = pose[k]
				var v: Vector2 = vel.get(k, Vector2.ZERO)
				var tv: Vector2 = t
				for i in range(n):
					var err := Vector2(angle_difference(x.x, tv.x), angle_difference(x.y, tv.y)) if ang else tv - x
					v += (err * w * w - v * 2.0 * zeta * w) * h
					x += v * h
				pose[k] = x
				vel[k] = v
			else:
				pose[k] = t
		return pose


## 按时间在一串关键姿势之间插值（带缓入缓出）。track 为 [[时间, 姿势], ...]，时间递增
static func sample(track: Array, t: float) -> Dictionary:
	if t <= float(track[0][0]):
		return track[0][1]
	for i in range(track.size() - 1):
		var t0: float = track[i][0]
		var t1: float = track[i + 1][0]
		if t <= t1:
			var k := (t - t0) / maxf(t1 - t0, 0.001)
			return lerp_pose(track[i][1], track[i + 1][1], smoothstep(0.0, 1.0, k))
	return track[track.size() - 1][1]


## 在姿势上叠加呼吸起伏（amount 为幅度倍数）
static func breathe(p: Dictionary, t: float, amount: float = 1.0) -> Dictionary:
	var out := p.duplicate()
	var b := sin(t * 2.4)
	out["crouch"] = float(p["crouch"]) + b * 0.45 * amount
	out["lean"] = float(p["lean"]) + b * 0.025 * amount
	out["head"] = float(p["head"]) - b * 0.04 * amount
	var af: Vector2 = p["arm_f"]
	out["arm_f"] = af + Vector2(b * 0.04, b * 0.05) * amount
	var ab: Vector2 = p["arm_b"]
	out["arm_b"] = ab + Vector2(-b * 0.05, b * 0.04) * amount
	out["sword"] = float(p["sword"]) + sin(t * 2.4 + 0.6) * 0.05 * amount
	return out


static func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))


## 两段骨骼的 IK：已知起点和终点，求关节位置（膝盖朝前）
static func _ik(start: Vector2, end: Vector2, l1: float, l2: float) -> Vector2:
	var to := end - start
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	return start + Vector2.from_angle(to.angle() - a) * l1


## 手臂 IK：肘关节取朝下的那一侧（垂着的胳膊肘不会往上翻）
static func _ik_arm(start: Vector2, end: Vector2, l1: float, l2: float) -> Vector2:
	var to := end - start
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var e1 := start + Vector2.from_angle(to.angle() - a) * l1
	var e2 := start + Vector2.from_angle(to.angle() + a) * l1
	return e1 if e1.y > e2.y else e2


## 计算各关节位置（朝右、未缩放）。grip_len 是双手握刀时两只手隔多远（沿刀柄），0 表示不双手握；
## 正数：前手握刀柄末端、后手握在护手下面（刀跟着往前挪一点，两只拳头都看得见）；负数：后手握在前手后面（长枪）
static func solve(p: Dictionary, grip_len: float = 4.5) -> Dictionary:
	var crouch: float = p["crouch"]
	var lean: float = p["lean"]
	var dx: float = float(p["dx"]) * U
	var hip := Vector2(dx, -(THIGH + SHIN) + crouch * U)
	var up := Vector2(sin(lean), -cos(lean))
	var neck := hip + up * TORSO
	var hl := lean + float(p["head"])
	var head := neck + Vector2(sin(hl), -cos(hl)) * 6.5
	# 扭腰转肩：前肩往前送/往后拧，后肩跟着转
	var tw := float(p.get("twist", 0.0))
	var side := Vector2(-up.y, up.x) * -1.0
	if side.x < 0.0:
		side = -side
	var shoulder := hip + up * (TORSO - 3.0) + side * tw * 2.2
	var arm_f: Vector2 = p["arm_f"]
	var arm_b: Vector2 = p["arm_b"]
	var elbow_f := shoulder + _dir(arm_f.x) * UPPER_ARM
	var hand_f := elbow_f + _dir(arm_f.y) * LOWER_ARM
	var sh_b := shoulder + Vector2(-1.5 + tw * 2.0 - absf(tw) * 0.5, -absf(tw) * 0.5)
	var elbow_b := sh_b + _dir(arm_b.x) * UPPER_ARM
	var hand_b := elbow_b + _dir(arm_b.y) * LOWER_ARM
	var g := clampf(float(p.get("grip", 0.0)), 0.0, 1.0) if grip_len != 0.0 else 0.0
	var grip_at := hand_f
	if g > 0.0:
		# 双手握刀：后手握到刀柄上，肘关节用 IK 算
		var sd := _dir(float(p["sword"]))
		hand_b = hand_b.lerp(hand_f + sd * grip_len, g)
		elbow_b = elbow_b.lerp(_ik_arm(sh_b, hand_b, UPPER_ARM, LOWER_ARM), g)
		if grip_len > 0.0:
			grip_at = hand_f + sd * grip_len * g
	var foot_f: Vector2 = p["foot_f"]
	var foot_b: Vector2 = p["foot_b"]
	foot_f = foot_f * U + Vector2(dx, 0)
	foot_b = foot_b * U + Vector2(dx, 0)
	var knee_f := _ik(hip + Vector2(1.5, 0), foot_f, THIGH, SHIN)
	var knee_b := _ik(hip - Vector2(1.5, 0), foot_b, THIGH, SHIN)
	return {
		"hip": hip, "neck": neck, "head": head, "shoulder": shoulder, "shoulder_b": sh_b,
		"elbow_f": elbow_f, "hand_f": hand_f, "elbow_b": elbow_b, "hand_b": hand_b, "grip_at": grip_at,
		"knee_f": knee_f, "foot_f": foot_f, "knee_b": knee_b, "foot_b": foot_b,
		"up": up,
	}


## 各种兵器双手握时两只手的间距（见 solve）
static func grip_of(look: Look) -> float:
	match look.weapon:
		"dual", "fist": return 0.0
		"spear": return -10.0
	return 4.0


## 刀尖位置（本地坐标，已考虑朝向和缩放），用来画闪光
static func sword_tip(p: Dictionary, look: Look, facing: int) -> Vector2:
	var j := solve(p, grip_of(look))
	var hand: Vector2 = j["grip_at"]
	var tip := hand + _dir(float(p["sword"])) * look.sword_len
	return Vector2(tip.x * facing, tip.y) * look.scale


## 头顶位置（本地坐标），用来摆血条和文字
static func head_top(look: Look) -> float:
	return -(THIGH + SHIN + TORSO + 13.0) * look.scale


# ---------- 绘制 ----------

## 带轮廓光的完整绘制：先在月光方向偏一像素画一层亮色剪影，再画角色本身
static func draw_lit(ci: CanvasItem, p: Dictionary, look: Look, facing: int, rim: Color,
		offset: Vector2 = Vector2.ZERO, tint: Color = Color(0, 0, 0, 0), alpha: float = 1.0,
		rotation: float = 0.0, squash: Vector2 = Vector2.ONE, sway: float = 0.0) -> void:
	if rim.a > 0.0:
		draw(ci, p, look, facing, offset + Vector2(1, -1), Color(rim, 1.0), alpha * rim.a, rotation, squash, sway)
	draw(ci, p, look, facing, offset, tint, alpha, rotation, squash, sway)


## mono_or_tint：alpha 为 1 时整个角色画成单色剪影（受击闪白、残影、轮廓光），
## 小于 1 时按比例染色。sway 为衣摆、袖子被风吹动的程度（一般取水平速度）。
static func draw(ci: CanvasItem, p: Dictionary, look: Look, facing: int,
		offset: Vector2 = Vector2.ZERO, mono_or_tint: Color = Color(0, 0, 0, 0), alpha: float = 1.0,
		rotation: float = 0.0, squash: Vector2 = Vector2.ONE, sway: float = 0.0) -> void:
	var grip_len := grip_of(look)
	var j := solve(p, grip_len)
	var sc := look.scale
	ci.draw_set_transform(offset, rotation, Vector2(facing * sc * squash.x, sc * squash.y))
	var pal := _Pal.new(look, mono_or_tint, alpha)
	var w := look.width
	var hip: Vector2 = j["hip"]
	var neck: Vector2 = j["neck"]
	var up: Vector2 = j["up"]
	var fwd := Vector2(-up.y, up.x) * -1.0   # 身体朝前的方向（垂直于躯干）
	if fwd.x < 0.0:
		fwd = -fwd
	var sway_k := clampf(sway * facing * 0.012, -1.0, 1.0)   # 往前跑时衣服往后飘

	# 披风（最后面）
	if look.cape:
		_draw_cape(ci, j, pal, sway_k)

	var sheathed := float(p.get("sheathed", 0.0)) >= 0.5
	# 背着的长兵器（野太刀、长枪收起来时斜背在背上）
	if sheathed and (look.weapon == "spear" or look.weapon == "nodachi"):
		_draw_back_carry(ci, hip, neck, up, fwd, pal, look)
	# 后手的第二把短刃、后手铁拳
	if look.weapon == "dual" and not sheathed:
		_draw_sword(ci, j["hand_b"], float(p["sword"]) - 0.35, pal, look)

	# 后侧：袖子和腿
	_draw_arm(ci, j["shoulder_b"], j["elbow_b"], j["hand_b"], pal, true, sway_k, w)
	if look.weapon == "fist":
		_draw_gauntlet(ci, j["hand_b"], pal, true)
	_draw_leg(ci, hip - Vector2(1.5, 0), j["knee_b"], j["foot_b"], pal, true, w)

	# 前腿
	_draw_leg(ci, hip + Vector2(1.5, 0), j["knee_f"], j["foot_f"], pal, false, w)

	# 躯干（和服上衣）
	var tw := float(p.get("twist", 0.0))
	var waist := 6.0 * w
	var shoulder_w := 7.0 * w * (1.0 + absf(tw) * 0.18)
	var top := neck - up * 1.0
	var torso := PackedVector2Array([
		hip - fwd * waist + up * 1.0, hip + fwd * waist + up * 1.0,
		top + fwd * shoulder_w, top - fwd * shoulder_w,
	])
	_outline(ci, torso, pal.outline)
	_fill(ci, torso, pal.c(look.cloth))
	# 背面阴影
	# 背面阴影：肩膀往后拧时露出更多后背，送出去时露出前胸
	var bk := clampf(1.5 - tw * 3.0, -2.5, 5.5)
	var back := PackedVector2Array([
		hip - fwd * waist + up * 1.0, hip - fwd * 1.0 + up * 1.0, top - fwd * bk, top - fwd * shoulder_w,
	])
	_fill(ci, back, pal.c(look.cloth_dark))
	# 前胸受光
	ci.draw_line(top + fwd * (shoulder_w - 1.0), hip + fwd * (waist - 1.0) + up * 6.0, pal.c(look.cloth_light), 1.0)
	if look.armor != "":
		_draw_body_armor(ci, hip, top, up, fwd, waist, shoulder_w, pal, look)
	# 领口（V 字）
	var chest := hip + up * 9.0 + fwd * 1.5
	ci.draw_line(top + fwd * 2.5, chest, pal.c(look.collar), 1.0)
	ci.draw_line(top - fwd * 0.5, chest, pal.c(look.collar), 1.0)
	# 腰带
	var belt := PackedVector2Array([
		hip - fwd * (waist + 0.5) + up * 2.0, hip + fwd * (waist + 0.5) + up * 2.0,
		hip + fwd * (waist + 0.5) + up * 5.5, hip - fwd * (waist + 0.5) + up * 5.5,
	])
	_fill(ci, belt, pal.c(look.belt))
	ci.draw_line(belt[3], belt[2], pal.c(look.belt.lightened(0.3)), 1.0)
	ci.draw_rect(Rect2(hip - fwd * (waist + 2.0) + up * 5.0, Vector2(3, 3)), pal.c(look.belt.darkened(0.3)))

	# 刀鞘：插在腰带上，鞘口在前，鞘尾斜向后下
	if look.saya:
		_draw_saya(ci, hip, up, fwd, sheathed, pal, look)

	# 脖子和头
	var head: Vector2 = j["head"]
	ci.draw_line(neck, head, pal.c(look.skin_dark), 3.0)
	_draw_head(ci, head, pal, look)

	# 刀
	var hand_f: Vector2 = j["hand_f"]
	var carried := sheathed and (look.weapon == "spear" or look.weapon == "nodachi")
	if not sheathed and not carried and look.weapon != "fist":
		var grip: Vector2 = (j["grip_at"] as Vector2).lerp(p.get("sword_at", hand_f), float(p.get("sword_free", 0.0)))
		var blur := float(p.get("blur", 0.0))
		if absf(blur) > 0.02:
			_draw_sword_blur(ci, grip, float(p["sword"]), blur, pal, look)
		_draw_sword(ci, grip, float(p["sword"]), pal, look)
		# 双手握刀：后手的小臂和拳头压在刀柄上，看得出是两只手一起发力
		if grip_len != 0.0 and float(p.get("grip", 0.0)) >= 0.5 and float(p.get("sword_free", 0.0)) < 0.5:
			var hb: Vector2 = j["hand_b"]
			var eb: Vector2 = j["elbow_b"]
			var fore := _seg(eb.lerp(hb, 0.35), hb, 3.2, 2.8)
			_outline(ci, fore, pal.outline)
			_fill(ci, fore, pal.c(look.skin_dark))
			ci.draw_circle(hb, 2.6, pal.outline)
			ci.draw_circle(hb, 1.8, pal.c(look.skin_dark))

	# 前手（盖在刀柄上）
	_draw_arm(ci, j["shoulder"], j["elbow_f"], j["hand_f"], pal, false, sway_k, w)
	if look.weapon == "fist":
		_draw_gauntlet(ci, j["hand_f"], pal, false)
	if look.armor == "plate":
		# 铁甲的肩甲盖在前臂上面
		var sh: Vector2 = j["shoulder"]
		ci.draw_circle(sh + Vector2(0, 1), 4.2, pal.outline)
		ci.draw_circle(sh + Vector2(0, 1), 3.4, pal.c(Color("5a5e6a")))
		ci.draw_line(sh + Vector2(-3, 0), sh + Vector2(3, 0), pal.c(Color("8a909e")), 1.0)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 颜色板：处理单色剪影和染色
class _Pal:
	var look: Look
	var tint: Color
	var alpha: float
	var outline: Color

	func _init(l: Look, t: Color, a: float) -> void:
		look = l
		tint = t
		alpha = a
		outline = c(l.outline) if t.a < 1.0 else Color(t.r, t.g, t.b, a)

	func c(col: Color) -> Color:
		var out := col.lerp(Color(tint.r, tint.g, tint.b), tint.a)
		out.a = alpha * col.a
		return out


## 填充多边形；自相交时退回到凸包，避免三角化失败
static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		pts = Geometry2D.convex_hull(pts)
		if pts.size() < 4:
			return
	ci.draw_colored_polygon(pts, col)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, 2.0)


## 一段粗细渐变的肢体（四边形）
static func _seg(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var n := (b - a).orthogonal().normalized()
	return PackedVector2Array([a + n * wa * 0.5, b + n * wb * 0.5, b - n * wb * 0.5, a - n * wa * 0.5])


static func _draw_leg(ci: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, pal: _Pal, is_back: bool, w: float) -> void:
	var look := pal.look
	var base := look.pants_dark if is_back else look.pants
	var ankle := foot + Vector2(0, -2.5)
	# 袴：大腿到小腿逐渐变宽，像裙裤
	var upper := _seg(hip, knee, 8.0 * w, 9.0 * w)
	var lower := _seg(knee, ankle, 9.0 * w, 12.0 * w)
	_outline(ci, upper, pal.outline)
	_outline(ci, lower, pal.outline)
	_fill(ci, upper, pal.c(base))
	_fill(ci, lower, pal.c(base))
	# 褶线和下摆
	ci.draw_line(hip.lerp(knee, 0.3), knee.lerp(ankle, 0.8), pal.c(base.darkened(0.35)), 1.0)
	if not is_back:
		ci.draw_line(lower[1].lerp(lower[0], 0.15), lower[0].lerp(lower[1], 0.6), pal.c(look.pants_light), 1.0)
	# 草鞋
	ci.draw_rect(Rect2(foot + Vector2(-2.5, -1.5), Vector2(7, 2)), pal.outline)
	ci.draw_rect(Rect2(foot + Vector2(-1.5, -2.5), Vector2(4, 1)), pal.c(look.skin_dark))


static func _draw_arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, pal: _Pal,
		is_back: bool, sway_k: float, w: float) -> void:
	var look := pal.look
	var cloth := look.cloth_dark if is_back else look.cloth
	# 宽袖：从肩到肘，袖口向下垂并随风后摆
	var hang := Vector2(-3.0 * sway_k - 1.0, 6.0)
	var sleeve := PackedVector2Array([
		shoulder + (elbow - shoulder).orthogonal().normalized() * 3.5 * w,
		elbow + (elbow - shoulder).orthogonal().normalized() * 3.0,
		elbow + hang,
		elbow - (elbow - shoulder).orthogonal().normalized() * 3.0,
		shoulder - (elbow - shoulder).orthogonal().normalized() * 3.5 * w,
	])
	_outline(ci, sleeve, pal.outline)
	_fill(ci, sleeve, pal.c(cloth))
	ci.draw_line(elbow, elbow + hang, pal.c(cloth.darkened(0.3)), 1.0)
	# 小臂（缠布）和手
	var fore := _seg(elbow, hand, 3.5, 3.0)
	_outline(ci, fore, pal.outline)
	_fill(ci, fore, pal.c(look.skin_dark if is_back else look.skin))
	ci.draw_circle(hand, 2.6, pal.outline)
	ci.draw_circle(hand, 1.8, pal.c(look.skin_dark if is_back else look.skin))


static func _draw_head(ci: CanvasItem, head: Vector2, pal: _Pal, look: Look) -> void:
	ci.draw_circle(head, HEAD_R + 1.0, pal.outline)
	ci.draw_circle(head, HEAD_R, pal.c(look.hair))
	# 脸（偏前下方），留出后脑和头顶的头发
	ci.draw_circle(head + Vector2(2.0, 1.4), 4.6, pal.c(look.skin))
	ci.draw_rect(Rect2(head + Vector2(-0.5, 3.0), Vector2(5, 2)), pal.c(look.skin_dark))   # 下巴阴影
	# 眼睛
	if look.eye_glow.a > 0.0:
		ci.draw_rect(Rect2(head + Vector2(3.0, -0.5), Vector2(3, 1.5)), pal.c(look.eye_glow))
	else:
		ci.draw_rect(Rect2(head + Vector2(3.5, -0.5), Vector2(1.5, 2)), pal.outline)
	if look.helm == "hood" or look.helm == "kabuto":
		_draw_helm(ci, head, pal, look)
		return
	if look.hat or look.helm == "kasa":
		# 斗笠：宽圆锥，右上受月光
		var brim_l := head + Vector2(-13, -2)
		var brim_r := head + Vector2(13, -2)
		var tip := head + Vector2(0, -11)
		var hat := PackedVector2Array([brim_l, brim_r, tip])
		_outline(ci, hat, pal.outline)
		_fill(ci, hat, pal.c(look.hat_dark))
		_fill(ci, PackedVector2Array([head + Vector2(-2, -2), brim_r, tip]), pal.c(look.hat_color))
		for i in range(3):
			var t := 0.3 + i * 0.22
			ci.draw_line(tip.lerp(brim_l, t), tip.lerp(brim_r, t), pal.c(look.hat_dark.darkened(0.2)), 1.0)
		ci.draw_line(brim_l, brim_r, pal.c(look.hat_dark.darkened(0.4)), 1.0)
		# 斗笠在脸上投下阴影
		if pal.tint.a < 1.0:
			ci.draw_rect(Rect2(head + Vector2(-1, -1.5), Vector2(8, 2)), Color(0, 0, 0, 0.35 * pal.alpha))
	else:
		# 头带和发髻
		ci.draw_line(head + Vector2(-HEAD_R, -2.0), head + Vector2(HEAD_R, -2.5), pal.c(look.band), 2.0)
		ci.draw_circle(head + Vector2(-4.5, -5.5), 2.6, pal.outline)
		ci.draw_circle(head + Vector2(-4.5, -5.5), 1.8, pal.c(look.hair))


static func _draw_sword(ci: CanvasItem, hand: Vector2, angle: float, pal: _Pal, look: Look) -> void:
	var dir := _dir(angle)
	var n := dir.orthogonal()
	if look.weapon == "spear":
		# 长枪：木杆从手后面伸出来，前头一个枪尖和一撮红缨
		var tail := hand - dir * 16.0
		var head := hand + dir * (look.sword_len - 7.0)
		var point := hand + dir * look.sword_len
		ci.draw_line(tail, head, pal.outline, 4.0)
		ci.draw_line(tail, head, pal.c(Color("7a5236")), 2.0)
		ci.draw_line(tail + n * 0.5, head + n * 0.5, pal.c(Color("a87a52")), 1.0)
		var tip_poly := PackedVector2Array([head + n * 2.2, point, head - n * 2.2, head - dir * 1.5])
		_outline(ci, tip_poly, pal.outline)
		_fill(ci, tip_poly, pal.c(look.blade))
		ci.draw_line(head, point, pal.c(look.blade_edge), 1.0)
		ci.draw_line(head - dir * 1.5 - n * 1.5, head - dir * 4.0 - n * 2.5, pal.c(Color("c0302a")), 2.0)
		ci.draw_line(head - dir * 1.5 + n * 1.0, head - dir * 4.5 + n * 0.5, pal.c(Color("e04a3a")), 1.0)
		return
	var guard := hand + dir * 2.5
	var tip := hand + dir * look.sword_len
	# 刀柄（缠绳）
	ci.draw_line(hand - dir * 6.0, guard, pal.outline, 4.0)
	ci.draw_line(hand - dir * 5.0, guard, pal.c(look.hilt), 2.0)
	for i in range(3):
		ci.draw_rect(Rect2(hand - dir * (4.0 - i * 2.2) - Vector2(0.5, 0.5), Vector2(1, 1)), pal.c(look.collar.darkened(0.3)))
	# 刀身：略带弧度的细长三角，刃口一侧高光
	var blade := PackedVector2Array([
		guard + n * 1.4, tip + n * 0.3 + n * 1.0, tip, guard - n * 1.0,
	])
	_outline(ci, blade, pal.outline)
	_fill(ci, blade, pal.c(look.blade))
	ci.draw_line(guard + n * 1.0, tip + n * 0.8, pal.c(look.blade_edge), 1.0)
	# 护手
	ci.draw_line(guard - n * 3.0, guard + n * 3.0, pal.outline, 3.0)
	ci.draw_line(guard - n * 2.2, guard + n * 2.2, pal.c(look.tsuba), 1.5)


## 头甲：头巾裹住头顶、后面打个结；铁盔是一个铁碗加前面的金色锹形
static func _draw_helm(ci: CanvasItem, head: Vector2, pal: _Pal, look: Look) -> void:
	var heavy := look.helm == "kabuto"
	var r := HEAD_R + (1.6 if heavy else 0.6)
	var col := Color("4a4e5a") if heavy else Color("3a3a52")
	var lit := Color("8a909e") if heavy else Color("5a5a7a")
	var dome := PackedVector2Array()
	for i in range(9):
		var a := PI + PI * i / 8.0
		dome.append(head + Vector2(cos(a) * r, sin(a) * r * 0.95 - 0.5))
	dome.append(head + Vector2(r, 0.5))
	dome.append(head + Vector2(-r, 0.5))
	_outline(ci, dome, pal.outline)
	_fill(ci, dome, pal.c(col))
	ci.draw_line(head + Vector2(-1, -r + 1.0), head + Vector2(r - 1.5, -2.0), pal.c(lit), 1.0)
	if heavy:
		ci.draw_line(head + Vector2(-r - 1.0, 0.5), head + Vector2(r + 1.0, 0.5), pal.outline, 3.0)
		ci.draw_line(head + Vector2(-r - 0.5, 0.5), head + Vector2(r + 0.5, 0.5), pal.c(col.lightened(0.15)), 1.0)
		ci.draw_line(head + Vector2(2, -4), head + Vector2(5, -10), pal.c(Color("d8b040")), 1.0)
		ci.draw_line(head + Vector2(4, -4), head + Vector2(8, -9), pal.c(Color("d8b040")), 1.0)
	else:
		# 头巾在脑后打的结
		ci.draw_rect(Rect2(head + Vector2(-r - 2.0, -2.0), Vector2(3, 3)), pal.c(col))
		ci.draw_line(head + Vector2(-r - 1.0, 0), head + Vector2(-r - 4.0, 3.0), pal.c(col), 1.0)


## 铁拳：手上套一个铁护手
static func _draw_gauntlet(ci: CanvasItem, hand: Vector2, pal: _Pal, is_back: bool) -> void:
	ci.draw_circle(hand, 3.6, pal.outline)
	ci.draw_circle(hand, 2.8, pal.c(Color("4a4e58") if is_back else Color("6a707e")))
	ci.draw_rect(Rect2(hand + Vector2(-1, -2), Vector2(2, 1)), pal.c(Color("a8aebb")))


## 野太刀、长枪收起来时背在背上：从腰后斜到肩膀上面
static func _draw_back_carry(ci: CanvasItem, hip: Vector2, neck: Vector2, up: Vector2, fwd: Vector2, pal: _Pal, look: Look) -> void:
	var dir := (up * 0.85 + fwd * 0.5).normalized()       # 往上、往前（柄或枪尖从肩膀后面露出来）
	var c := hip.lerp(neck, 0.45) - fwd * 4.0
	var half := look.sword_len * 0.55
	var a := c - dir * half
	var b := c + dir * half
	if look.weapon == "spear":
		ci.draw_line(a, b, pal.outline, 4.0)
		ci.draw_line(a, b, pal.c(Color("7a5236")), 2.0)
		var n := dir.orthogonal()
		var tip_poly := PackedVector2Array([b + n * 2.0, b + dir * 6.0, b - n * 2.0])
		_outline(ci, tip_poly, pal.outline)
		_fill(ci, tip_poly, pal.c(look.blade))
		ci.draw_line(b - n * 1.5, b - dir * 3.0 - n * 2.0, pal.c(Color("c0302a")), 2.0)
	else:
		# 野太刀：长刀鞘，刀柄从右肩上面露出来
		ci.draw_line(a, b - dir * 6.0, pal.outline, 5.0)
		ci.draw_line(a, b - dir * 6.0, pal.c(look.saya_color), 3.0)
		ci.draw_line(a + up * 0.5, b - dir * 6.0 + up * 0.5, pal.c(look.saya_color.lightened(0.25)), 1.0)
		var n := dir.orthogonal()
		var g := b - dir * 6.0
		ci.draw_line(g - n * 3.0, g + n * 3.0, pal.outline, 3.0)
		ci.draw_line(g - n * 2.2, g + n * 2.2, pal.c(look.tsuba), 1.5)
		ci.draw_line(g, b + dir * 3.0, pal.outline, 4.0)
		ci.draw_line(g, b + dir * 2.5, pal.c(look.hilt), 2.0)


## 身甲：皮甲是一块棕色胸甲加肩带，铁甲是一排排甲片，短打是一条束腰
static func _draw_body_armor(ci: CanvasItem, hip: Vector2, top: Vector2, up: Vector2, fwd: Vector2,
		waist: float, shoulder_w: float, pal: _Pal, look: Look) -> void:
	var lo := hip + up * 4.0
	var hi := top - up * 2.0
	match look.armor:
		"vest":
			var sash := PackedVector2Array([lo - fwd * (waist + 0.5), lo + fwd * (waist + 0.5),
				lo + fwd * (waist + 0.5) + up * 3.0, lo - fwd * (waist + 0.5) + up * 3.0])
			_fill(ci, sash, pal.c(Color("3a5a4a")))
			ci.draw_line(sash[3], sash[2], pal.c(Color("5a8a6a")), 1.0)
		"leather", "plate":
			var col := Color("6a4a30") if look.armor == "leather" else Color("50545e")
			var lit := Color("9a7048") if look.armor == "leather" else Color("8a909e")
			var plate := PackedVector2Array([lo - fwd * (waist - 0.5), lo + fwd * (waist + 0.5),
				hi + fwd * (shoulder_w - 1.0), hi - fwd * (shoulder_w - 2.5)])
			_outline(ci, plate, pal.outline)
			_fill(ci, plate, pal.c(col))
			ci.draw_line(plate[1], plate[2], pal.c(lit), 1.0)
			if look.armor == "plate":
				for i in range(1, 4):
					var t := i / 4.0
					ci.draw_line(plate[0].lerp(plate[3], t), plate[1].lerp(plate[2], t), pal.c(col.darkened(0.35)), 1.0)
			else:
				# 斜挎的皮带
				ci.draw_line(hi - fwd * (shoulder_w - 2.5), lo + fwd * (waist - 1.0), pal.c(Color("3a2414")), 1.0)


## 鞘口位置和鞘的方向（本地坐标），拔刀式时手要放到这里
static func saya_mouth(hip: Vector2, up: Vector2, fwd: Vector2) -> Vector2:
	return hip + fwd * 6.0 + up * 3.5


static func _draw_saya(ci: CanvasItem, hip: Vector2, up: Vector2, fwd: Vector2, sheathed: bool, pal: _Pal, look: Look) -> void:
	var mouth := saya_mouth(hip, up, fwd)
	var back := (-fwd * 0.93 - up * 0.36).normalized()
	var end := mouth + back * (look.sword_len + 3.0)
	ci.draw_line(mouth, end, pal.outline, 4.0)
	ci.draw_line(mouth, end, pal.c(look.saya_color), 2.0)
	ci.draw_line(mouth + back * 2.0 - up * 0.5, end - up * 0.5, pal.c(look.saya_color.lightened(0.25)), 1.0)
	ci.draw_line(end - back * 2.5, end, pal.c(look.tsuba.darkened(0.2)), 2.0)    # 鞘尾金属
	ci.draw_line(mouth + back * 1.0, mouth + back * 2.5, pal.c(look.belt.lightened(0.2)), 3.0)   # 鞘口
	if sheathed:
		# 刀在鞘里：只露出护手和刀柄
		var hdir := -back
		var n := hdir.orthogonal()
		ci.draw_line(mouth - n * 3.0, mouth + n * 3.0, pal.outline, 3.0)
		ci.draw_line(mouth - n * 2.2, mouth + n * 2.2, pal.c(look.tsuba), 1.5)
		ci.draw_line(mouth + hdir * 1.0, mouth + hdir * 8.0, pal.outline, 4.0)
		ci.draw_line(mouth + hdir * 1.0, mouth + hdir * 7.5, pal.c(look.hilt), 2.0)
		for i in range(3):
			ci.draw_rect(Rect2(mouth + hdir * (2.5 + i * 2.0) - Vector2(0.5, 0.5), Vector2(1, 1)), pal.c(look.collar.darkened(0.3)))


## 转刀残影：刀身后面拖几道越来越淡的刀影，看起来像一圈刀光
static func _draw_sword_blur(ci: CanvasItem, grip: Vector2, angle: float, blur: float, pal: _Pal, look: Look) -> void:
	for k in range(1, 6):
		var d := _dir(angle - blur * k)
		var col := pal.c(look.blade_edge)
		col.a *= 0.42 * (1.0 - k / 6.0)
		ci.draw_line(grip + d * 4.0, grip + d * look.sword_len, col, 2.0)
	# 刀尖划出的弧线
	var arc := PackedVector2Array()
	for k in range(0, 7):
		arc.append(grip + _dir(angle - blur * k * 0.85) * (look.sword_len + 0.5))
	var ac := pal.c(look.blade_edge)
	ac.a *= 0.5
	ci.draw_polyline(arc, ac, 1.0)


static func _draw_cape(ci: CanvasItem, j: Dictionary, pal: _Pal, sway_k: float) -> void:
	var look := pal.look
	var neck: Vector2 = j["neck"]
	var hip: Vector2 = j["hip"]
	var flow := Vector2(-4.0 - 6.0 * maxf(sway_k, 0.0), 0)
	var pts := PackedVector2Array([
		neck + Vector2(2, 1), neck + Vector2(-6, 2),
		hip + Vector2(-9, 4) + flow,
		hip + Vector2(-7, 12) + flow * 1.3,
		hip + Vector2(-4, 9) + flow,
		hip + Vector2(-2, 13) + flow * 0.8,
		hip + Vector2(1, 8),
	])
	_outline(ci, pts, pal.outline)
	_fill(ci, pts, pal.c(look.cape_color))
	ci.draw_line(neck + Vector2(-3, 3), hip + Vector2(-6, 9) + flow, pal.c(look.cape_color.darkened(0.3)), 1.0)
