class_name Flourish
extends RefCounted
## 耍刀动作（花刀）：站着没事干、处决之后、敌人挑衅时播放。
## 每个动作是一个按时间算姿势的函数：给定动作名、已播放时间和当前的基础姿势，返回这一刻的姿势。
## 刀的角度可以一直往上加（转几圈），姿势平滑时按最短角度插值，所以转多少圈都不会倒着转回去。

const PLAYER_IDLE := ["wheel", "figure8", "toss", "reverse", "overhead", "chiburi", "stretch", "look_back"]
const PLAYER_SHEATHED := ["stretch", "look_back"]   # 拔刀式刀在鞘里，只做不动刀的
const ENEMY_FAR := ["tap", "shoulder_twirl", "hat", "beckon"]
const ENEMY_NEAR := ["flick", "beckon", "flick"]

## 只改上半身的动作（敌人边走边做）
const UPPER_KEYS := ["arm_f", "arm_b", "sword", "head", "blur", "sword_at", "sword_free"]

const DURATION := {
	"wheel": 1.7, "figure8": 2.0, "toss": 2.1, "reverse": 1.9, "overhead": 2.8,
	"chiburi": 1.5, "stretch": 1.9, "look_back": 2.0,
	"tap": 1.3, "shoulder_twirl": 1.6, "hat": 1.4, "beckon": 1.6, "flick": 1.0,
}


static func duration(kind: String) -> float:
	return DURATION.get(kind, 1.0)


## 这一刻的姿势，并算出刀转动的残影
static func sample(kind: String, t: float, base: Dictionary) -> Dictionary:
	var p := _pose_at(kind, t, base)
	var prev := _pose_at(kind, maxf(t - 0.02, 0.0), base)
	var vel := angle_difference(float(prev["sword"]), float(p["sword"])) / 0.02
	p["blur"] = clampf(vel * 0.022, -0.5, 0.5) if absf(vel) > 9.0 else 0.0
	return p


## 把动作的上半身叠到另一个姿势上（腿还在走路）
static func overlay(lower: Dictionary, upper: Dictionary) -> Dictionary:
	var out := lower.duplicate()
	for k in UPPER_KEYS:
		out[k] = upper[k]
	return out


static func pick(list: Array, last: String) -> String:
	var kind: String = list[randi() % list.size()]
	if kind == last and list.size() > 1:
		kind = list[(list.find(kind) + 1) % list.size()]
	return kind


# ---------- 工具 ----------

static func _k(t: float, t0: float, t1: float) -> float:
	return clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)


static func _ease(x: float) -> float:
	# 缓入缓出（smootherstep），转圈时先加速再减速
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var p := base.duplicate()
	for k in over:
		p[k] = over[k]
	return p


## 进入、保持、退出：在 [t0,t1] 之间从 base 过渡到 hold，在 [t2,t3] 之间过渡回去
static func _in_out(base: Dictionary, hold: Dictionary, t: float, t0: float, t1: float, t2: float, t3: float) -> Dictionary:
	if t < t2:
		return Puppet.lerp_pose(base, hold, _ease(_k(t, t0, t1)))
	return Puppet.lerp_pose(hold, base, _ease(_k(t, t2, t3)))


static func _hand(p: Dictionary) -> Vector2:
	return Puppet.solve(p)["hand_f"]


# ---------- 各个动作 ----------

static func _pose_at(kind: String, t: float, base: Dictionary) -> Dictionary:
	var s0: float = base["sword"]
	match kind:
		# 风车花：手伸到身侧，刀在手腕上转四圈
		"wheel":
			var hold := _with(base, {"arm_f": Vector2(1.25, 1.45), "arm_b": Vector2(-0.35, 0.1),
				"crouch": 1.8, "lean": 0.02, "head": 0.12, "sword": s0})
			var p := _in_out(base, hold, t, 0.0, 0.25, 1.4, 1.7)
			var a := 4.0 * TAU * _ease(_k(t, 0.2, 1.45))
			p["sword"] = s0 + a
			var af: Vector2 = p["arm_f"]
			p["arm_f"] = af + Vector2(sin(a) * 0.08, cos(a) * 0.12) * (1.0 - _k(t, 1.3, 1.45))
			return p

		# 八字花：手左右摆，刀正转一圈、反转两圈、再正转回来
		"figure8":
			var u := _k(t, 0.25, 1.75)
			var w := sin(u * TAU)
			var hold := _with(base, {"arm_f": Vector2(1.25, 1.65), "arm_b": Vector2(-0.4, 0.0),
				"crouch": 2.2, "head": 0.08, "sword": s0})
			var p := _in_out(base, hold, t, 0.0, 0.25, 1.75, 2.0)
			var amt := 1.0 - _k(t, 1.75, 1.9)
			p["arm_f"] = Vector2(1.25 + 0.5 * w, 1.65 + 0.35 * w) * amt + (p["arm_f"] as Vector2) * (1.0 - amt)
			p["lean"] = float(p["lean"]) + 0.07 * w * amt
			p["dx"] = 0.8 * w * amt
			p["sword"] = s0 + TAU * w
			return p

		# 抛刀接刀：往上一抛，刀在空中转三圈，抬手接住，顺势甩一下
		"toss":
			var dip := _with(base, {"crouch": 3.4, "lean": 0.2, "arm_f": Vector2(0.55, 0.9), "sword": 1.2, "head": 0.1})
			var throw := _with(base, {"crouch": 0.3, "lean": -0.08, "arm_f": Vector2(2.6, 2.95),
				"arm_b": Vector2(-0.5, -0.1), "sword": 2.9, "head": -0.25})
			var watch := _with(base, {"crouch": 1.0, "lean": -0.1, "arm_f": Vector2(1.0, 1.6),
				"arm_b": Vector2(-0.3, 0.2), "head": -0.45})
			var catch := _with(base, {"crouch": 0.6, "lean": -0.1, "arm_f": Vector2(2.4, 2.75),
				"arm_b": Vector2(-0.3, 0.2), "sword": 2.85, "head": -0.3})
			var land := _with(base, {"crouch": 3.6, "lean": 0.22, "arm_f": Vector2(0.9, 0.5), "sword": 0.25, "head": 0.05})
			var p: Dictionary
			if t < 0.25:
				p = Puppet.lerp_pose(base, dip, _ease(_k(t, 0.0, 0.25)))
			elif t < 0.36:
				p = Puppet.lerp_pose(dip, throw, _ease(_k(t, 0.25, 0.36)))
			elif t < 1.3:
				p = Puppet.lerp_pose(throw, watch, _ease(_k(t, 0.36, 0.7)))
				p = Puppet.lerp_pose(p, catch, _ease(_k(t, 1.0, 1.28)))
			elif t < 1.5:
				p = Puppet.lerp_pose(catch, land, _ease(_k(t, 1.3, 1.45)))
			else:
				p = Puppet.lerp_pose(land, base, _ease(_k(t, 1.65, 2.1)))
			# 空中：刀柄沿抛物线飞，刀身转三圈
			if t >= 0.33 and t < 1.3:
				var u := _k(t, 0.33, 1.3)
				var r := _hand(throw)
				var c := _hand(catch)
				var at := r.lerp(c, u) - Vector2(0, 4.0 * 42.0 * u * (1.0 - u))
				p["sword_at"] = at
				p["sword_free"] = 1.0
				p["sword"] = 2.9 + 3.0 * TAU * u + (2.85 - 2.9) * u
			else:
				p["sword_at"] = _hand(p)
			return p

		# 反手花：刀往后转一圈半变成反手握，摆个架势，再转回来
		"reverse":
			var hold := _with(base, {"crouch": 3.0, "lean": 0.22, "arm_f": Vector2(0.85, 1.95),
				"arm_b": Vector2(0.9, 1.7), "head": 0.0, "foot_f": Vector2(6, 0), "foot_b": Vector2(-7, 0)})
			var p := _in_out(base, hold, t, 0.0, 0.3, 1.45, 1.9)
			var rev := -(0.95 + TAU)                     # 刀尖朝下贴着小臂
			var a := rev * _ease(_k(t, 0.15, 0.6)) - rev * _ease(_k(t, 1.1, 1.55))
			p["sword"] = s0 + a
			return p

		# 举顶风车：刀举过头顶飞转，最后金鸡独立、手搭凉棚（孙悟空的招牌动作）
		"overhead":
			var up := _with(base, {"crouch": 2.0, "lean": -0.04, "arm_f": Vector2(2.95, 3.25),
				"arm_b": Vector2(1.0, 1.6), "head": -0.2, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0), "sword": s0})
			var pose_end := _with(base, {"crouch": 0.6, "lean": -0.05, "head": -0.12,
				"foot_f": Vector2(1.0, 0), "foot_b": Vector2(4.0, -6.0),
				"arm_f": Vector2(2.3, 3.7), "sword": 4.25,
				"arm_b": Vector2(2.55, 4.55)})
			var p: Dictionary
			if t < 1.75:
				p = Puppet.lerp_pose(base, up, _ease(_k(t, 0.0, 0.3)))
				p["crouch"] = float(p["crouch"]) + 0.7 * sin(t * 13.0) * _k(t, 0.3, 0.5)
				p["sword"] = s0 + 5.0 * TAU * _ease(_k(t, 0.2, 1.75))
			elif t < 2.35:
				p = Puppet.lerp_pose(up, pose_end, _ease(_k(t, 1.75, 1.95)))
				p["sword"] = lerp_angle(s0, 4.25, _ease(_k(t, 1.75, 1.95)))
			else:
				p = Puppet.lerp_pose(pose_end, base, _ease(_k(t, 2.35, 2.8)))
			return p

		# 甩刀（血振）
		"chiburi":
			var a := _chiburi_up(base)
			var b := _chiburi_down(base)
			if t < 0.35:
				return Puppet.lerp_pose(base, a, _ease(_k(t, 0.0, 0.35)))
			if t < 1.0:
				return Puppet.lerp_pose(a, b, _ease(_k(t, 0.35, 0.47)))
			return Puppet.lerp_pose(b, base, _ease(_k(t, 1.0, 1.5)))

		"stretch":
			var hold := _with(base, {"crouch": 0.4, "lean": -0.16, "head": -0.25, "arm_b": Vector2(2.7, 3.1)})
			return _in_out(base, hold, t, 0.0, 0.6, 1.3, 1.9)

		"look_back":
			var hold := _with(base, {"crouch": 1.4, "lean": -0.06, "head": -0.5, "arm_b": Vector2(-0.3, 0.1)})
			return _in_out(base, hold, t, 0.0, 0.4, 1.6, 2.0)

		# ---------- 浪人 ----------
		# 扛着刀在肩上敲两下
		"tap":
			var p := base.duplicate()
			var b := absf(sin(_k(t, 0.1, 1.1) * PI * 2.0))
			var af: Vector2 = base["arm_f"]
			p["arm_f"] = af + Vector2(-0.3, -0.2) * b
			p["sword"] = s0 + 0.35 * b
			p["head"] = float(base["head"]) + 0.08 * b
			return p

		# 从肩上拿下来转两圈，再扛回去
		"shoulder_twirl":
			var hold := _with(base, {"arm_f": Vector2(1.3, 1.55), "head": 0.1, "sword": s0})
			var p := _in_out(base, hold, t, 0.0, 0.25, 1.3, 1.6)
			p["sword"] = s0 + 3.0 * TAU * _ease(_k(t, 0.2, 1.35))
			return p

		# 压低斗笠
		"hat":
			var hold := _with(base, {"arm_b": Vector2(2.75, 3.95), "head": 0.32})
			return _in_out(base, hold, t, 0.0, 0.3, 1.0, 1.4)

		# 勾手指挑衅
		"beckon":
			var hold := _with(base, {"arm_b": Vector2(1.55, 2.0), "head": -0.08})
			var p := _in_out(base, hold, t, 0.0, 0.25, 1.3, 1.6)
			var curl := maxf(0.0, sin(_k(t, 0.3, 1.25) * PI * 3.0)) * (1.0 - _k(t, 1.25, 1.3))
			var ab: Vector2 = p["arm_b"]
			p["arm_b"] = ab + Vector2(0.0, 0.9 * curl)
			return p

		# 低身持刀，手腕一抖转两圈刀花
		"flick":
			var p := base.duplicate()
			p["sword"] = s0 + 2.0 * TAU * _ease(_k(t, 0.1, 0.8))
			var af: Vector2 = base["arm_f"]
			p["arm_f"] = af + Vector2(0.15, 0.25) * sin(_k(t, 0.1, 0.8) * PI)
			return p
	return base


static func _chiburi_up(base: Dictionary) -> Dictionary:
	return _with(base, {"crouch": 1.5, "lean": -0.05, "arm_f": Vector2(1.9, 2.5), "arm_b": Vector2(-0.2, 0.3), "sword": 2.7})


static func _chiburi_down(base: Dictionary) -> Dictionary:
	return _with(base, {"crouch": 2.5, "lean": 0.22, "arm_f": Vector2(0.9, 0.5), "arm_b": Vector2(-0.4, 0.1), "sword": 0.25})
