class_name Poses
extends RefCounted
## 现成的姿势（给 VoxActor.apply 用）。模型空间：x 朝前、y 朝上、z 朝右；角度 θ 正 = 往左。

const D2R := PI / 180.0


## 由水平角 θ（度，0 = 正前，正 = 左）和仰角 φ（度）得到方向
static func dirv(theta_deg: float, phi_deg: float, length: float = 1.0) -> Vector3:
	var t := theta_deg * D2R
	var p := phi_deg * D2R
	return Vector3(cos(p) * cos(t), sin(p), -cos(p) * sin(t)) * length


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func idle(t: float, armed: bool = true) -> Dictionary:
	var br := sin(t * 2.2)
	var p := {
		"lean": 0.08, "bob": br * 0.35 - 0.6, "head": 0.05 + br * 0.02,
		"hand_r": dirv(-25, -55, 0.78), "hand_l": dirv(30, -70, 0.85),
		"foot_r": Vector3(1.5, 0, 0.6), "foot_l": Vector3(-1.5, 0, -0.6),
	}
	if armed:
		p["blade"] = dirv(-5, -25)
	return p


## 跑步：phase 是步伐相位（弧度），k 是速度比例 0~1
static func run(phase: float, k: float) -> Dictionary:
	var s := sin(phase)
	var c := cos(phase)
	var stride := 5.5 * k
	var lift := 3.2 * k
	return {
		"lean": 0.12 + 0.22 * k, "bob": absf(c) * 1.2 * k - 0.6, "twist": s * 0.12 * k, "head": -0.05 * k,
		"hand_r": dirv(-30 + s * 20.0 * k, -45 + s * 25.0 * k, 0.8), "hand_l": dirv(30 - s * 30.0 * k, -60 - s * 25.0 * k, 0.85),
		"blade": dirv(10, -35 + s * 10.0),
		"foot_r": Vector3(s * stride, maxf(0.0, c) * lift, 0.5), "foot_l": Vector3(-s * stride, maxf(0.0, -c) * lift, -0.5),
	}


## 挥刀：su/ac/rc 是前摇/判定/后摇里各自的进度 0~1（没到的那段是 0，过了的是 1）
static func swing(kind: String, su: float, ac: float, rc: float) -> Dictionary:
	if kind == "thrust" or kind == "shoot":
		return _thrust(kind, su, ac, rc)
	var w := ease_out(su)                 # 蓄到起手位置
	var a := ease_out(ac)                 # 挥过去
	var r := ease_in_out(rc)              # 收回来
	var th0 := 0.0
	var th1 := 0.0
	var ph0 := 0.0
	var ph1 := 0.0
	var p := {}
	match kind:
		"h_rl":
			th0 = -125.0; th1 = 115.0; ph0 = 12.0; ph1 = -8.0
		"h_lr":
			th0 = 125.0; th1 = -115.0; ph0 = 5.0; ph1 = -12.0
		"v_down":
			th0 = -10.0; th1 = 0.0; ph0 = 115.0; ph1 = -45.0
		"spin":
			th0 = -100.0; th1 = -95.0; ph0 = 0.0; ph1 = -5.0
		"enemy_h":
			th0 = -115.0; th1 = 100.0; ph0 = 20.0; ph1 = -15.0
		"enemy_v":
			th0 = -5.0; th1 = 0.0; ph0 = 120.0; ph1 = -50.0
		_:
			th0 = -100.0; th1 = 100.0
	var idle_th := -5.0
	var idle_ph := -25.0
	var th := lerpf(idle_th, th0, w)
	var ph := lerpf(idle_ph, ph0, w)
	if ac > 0.0:
		th = lerpf(th0, th1, a)
		ph = lerpf(ph0, ph1, a)
	if rc > 0.0:
		th = lerpf(th1, lerpf(th1, idle_th, 0.6), r)
		ph = lerpf(ph1, idle_ph, r * 0.7)
	var blade := dirv(th, ph)
	var hand := dirv(th * 0.75, clampf(ph * 0.7 - 10.0, -70.0, 75.0), 0.92)
	p["blade"] = blade
	p["hand_r"] = hand
	p["hand_l"] = dirv(40 - th * 0.2, -40, 0.8)
	var twist := clampf(th * 0.35 * D2R, -0.7, 0.7)
	p["twist"] = twist
	var lean := 0.15 + 0.15 * a - 0.1 * r
	var step := 3.0 * a * (1.0 - r * 0.6)
	if kind == "v_down" or kind == "enemy_v":
		lean = lerpf(-0.15, 0.5, a) * (1.0 - r * 0.7) + (-0.15 * w if ac == 0.0 else 0.0)
		p["hand_l"] = hand * 0.95
		p["head"] = 0.2 * a
	if kind == "spin":
		p["spin"] = TAU * a + 0.4 * w
		p["blade"] = dirv(-92, -4)
		p["hand_r"] = dirv(-80, 0, 0.98)
		p["bob"] = sin(a * PI) * 3.0 - 1.0
		lean = 0.2
		twist = 0.0
		p["twist"] = 0.0
	p["lean"] = lean
	p["foot_r"] = Vector3(2.0 + step, 0, 1.0)
	p["foot_l"] = Vector3(-2.5 - step * 0.3, 0, -0.8)
	p["bob"] = float(p.get("bob", 0.0)) - 1.2 * a
	return p


## 直刺（枪、匕首收势）：前摇把手往回收、刃端平；判定时整条胳膊送出去，身子前倾。
## 射击（连弩）：两手平端在胸前，判定时往后一顿（后坐）
static func _thrust(kind: String, su: float, ac: float, rc: float) -> Dictionary:
	var w := ease_out(su)
	var a := ease_out(ac)
	var r := ease_in_out(rc)
	var p := {}
	if kind == "shoot":
		var kick := a * (1.0 - r)
		p["blade"] = dirv(0, lerpf(-25.0, 0.0, w) + 6.0 * kick)
		p["hand_r"] = dirv(-8, lerpf(-40.0, -2.0, w) + 4.0 * kick, 0.82 - 0.12 * kick)
		p["hand_l"] = dirv(14, lerpf(-50.0, -6.0, w), 0.78 - 0.1 * kick)
		p["lean"] = 0.05 - 0.12 * kick
		p["twist"] = -0.2 * w
		p["bob"] = -0.8
		p["foot_r"] = Vector3(-1.5, 0, 0.8)
		p["foot_l"] = Vector3(2.0, 0, -0.8)
		return p
	var ext := lerpf(0.75, 0.45, w)
	var ph := lerpf(-25.0, -4.0, w)
	if ac > 0.0:
		ext = lerpf(0.45, 1.0, a)
	if rc > 0.0:
		ext = lerpf(1.0, 0.75, r)
		ph = lerpf(-4.0, -25.0, r * 0.7)
	p["blade"] = dirv(-4, ph)
	p["hand_r"] = dirv(-12, ph * 0.6 - 4.0, ext)
	p["hand_l"] = dirv(12, ph * 0.6 - 8.0, ext * 0.85)
	p["twist"] = -0.35 * w * (1.0 - a) + 0.25 * a * (1.0 - r)
	p["lean"] = 0.1 + 0.35 * a * (1.0 - r * 0.7) - 0.1 * w * (1.0 - a)
	var step := 3.5 * a * (1.0 - r * 0.6)
	p["foot_r"] = Vector3(2.0 + step, 0, 1.0)
	p["foot_l"] = Vector3(-2.5 - step * 0.3, 0, -0.8)
	p["bob"] = -0.6 - 1.4 * a
	return p


## 翻滚：k 0~1
static func roll(k: float) -> Dictionary:
	var tuck := sin(clampf(k, 0, 1) * PI)
	return {
		"roll": TAU * ease_in_out(k), "bob": -6.0 * tuck, "lean": 0.4 * tuck,
		"hand_r": dirv(-20, -10, 0.55), "hand_l": dirv(20, -10, 0.55), "blade": dirv(-170, 10),
		"foot_r": Vector3(2.0, 6.0 * tuck, 0.5), "foot_l": Vector3(1.0, 5.0 * tuck, -0.5), "head": 0.5 * tuck,
	}


## 受击后仰：k 0~1（1 = 恢复）
static func hurt(k: float) -> Dictionary:
	var h := 1.0 - ease_out(k)
	return {
		"tilt": 0.45 * h, "lean": -0.3 * h, "head": -0.4 * h, "bob": -1.0 * h,
		"hand_r": dirv(-60, 10 + 30 * h, 0.85), "hand_l": dirv(60, 10 + 30 * h, 0.85), "blade": dirv(-90, 40),
		"foot_r": Vector3(1.5, 0, 0.8), "foot_l": Vector3(-2.5, 0, -0.8),
	}


## 突进斩蓄势：压低身子、刀拖在身后
static func dash_ready(k: float) -> Dictionary:
	var e := ease_out(k)
	return {
		"lean": 0.55 * e, "bob": -4.0 * e, "twist": -0.4 * e,
		"hand_r": dirv(-150, -20, 0.9), "blade": dirv(-175, 5), "hand_l": dirv(40, -20, 0.7),
		"foot_r": Vector3(-3.0 * e, 0, 1.5), "foot_l": Vector3(4.0 * e, 0, -1.2),
	}


## 光束斩：举刀过头 → 斜劈下去（k 0~1，0.6 时出光束）
static func beam_cast(k: float) -> Dictionary:
	if k < 0.6:
		var e := ease_out(k / 0.6)
		return {
			"lean": -0.2 * e, "head": -0.2 * e, "bob": 1.5 * e,
			"hand_r": dirv(-30, 60 + 20 * e, 0.95), "hand_l": dirv(-10, 70 + 15 * e, 0.9), "blade": dirv(-40, 95),
			"foot_r": Vector3(2.0, 0, 1.4), "foot_l": Vector3(-3.0, 0, -1.4),
		}
	var a := ease_out((k - 0.6) / 0.4)
	return {
		"lean": lerpf(-0.2, 0.5, a), "head": 0.2 * a, "bob": lerpf(1.5, -3.0, a), "twist": 0.3 * a,
		"hand_r": dirv(lerpf(-30, 40, a), lerpf(80, -40, a), 0.95), "hand_l": dirv(lerpf(-10, 40, a), lerpf(85, -40, a), 0.9),
		"blade": dirv(lerpf(-40, 50, a), lerpf(95, -50, a)),
		"foot_r": Vector3(4.0, 0, 1.4), "foot_l": Vector3(-4.0, 0, -1.4),
	}


## 敌人蓄力（危险预警时）：刀举高、身子发抖
static func windup(kind: String, k: float, t: float) -> Dictionary:
	var p := swing(kind, k, 0.0, 0.0)
	var tremble := sin(t * 60.0) * 0.03 * k
	p["twist"] = float(p.get("twist", 0.0)) + tremble
	return p


## 跳劈：k 0~1，起跳 → 空中举刀 → 砸地
static func leap(k: float) -> Dictionary:
	if k < 0.75:
		var e := ease_out(k / 0.75)
		return {
			"lean": -0.25 * e, "bob": 2.0 * e, "hand_r": dirv(-5, 100, 0.95), "hand_l": dirv(5, 100, 0.95), "blade": dirv(-5, 130),
			"foot_r": Vector3(1.0, 4.0 * e, 1.0), "foot_l": Vector3(-1.0, 5.0 * e, -1.0),
		}
	var a := ease_out((k - 0.75) / 0.25)
	return {
		"lean": lerpf(-0.25, 0.6, a), "bob": lerpf(2.0, -4.0, a), "hand_r": dirv(0, lerpf(100, -50, a), 0.95),
		"hand_l": dirv(0, lerpf(100, -50, a), 0.9), "blade": dirv(0, lerpf(130, -60, a)),
		"foot_r": Vector3(3.0, 0, 1.4), "foot_l": Vector3(-3.0, 0, -1.4),
	}


## 施法：法杖举起往前指
static func cast(k: float, t: float) -> Dictionary:
	var e := ease_out(k)
	return {
		"lean": -0.1 * e, "head": -0.1 * e, "bob": sin(t * 8.0) * 0.4,
		"hand_r": dirv(-10, lerpf(-40, 40, e), 0.95), "blade": dirv(-5, lerpf(-20, 70, e)),
		"hand_l": dirv(20, lerpf(-60, 20, e), 0.9), "foot_r": Vector3(1.5, 0, 0.8), "foot_l": Vector3(-1.5, 0, -0.8),
	}


## 把姿势里的数值按权重混合（a → b，k=1 时全是 b）
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var out := {}
	var keys := {}
	for key: String in a:
		keys[key] = true
	for key: String in b:
		keys[key] = true
	for key: String in keys:
		var va = a.get(key)
		var vb = b.get(key)
		if va == null:
			out[key] = vb if vb is Vector3 else lerpf(0.0, float(vb), k)
		elif vb == null:
			out[key] = va if va is Vector3 else lerpf(float(va), 0.0, k)
		elif va is Vector3:
			out[key] = (va as Vector3).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out
