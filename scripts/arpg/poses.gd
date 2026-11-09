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
##
## opt（主角用，敌人不传就是老样子）：
##   from Vector2(θ, φ) 起手前刀在哪（上一刀收在哪，就从哪起，刀路连成一条线）
##   lead 1 / -1 这一刀哪只脚上步（连招左右脚交替，人是往前“走”着砍的）
##   feet0 [右脚, 左脚] 起手时两只脚在哪（上步时从这里迈过去，迈的那只脚抬一下）
##   heft 0~1 兵器沉重度：重兵器举得开、拧得狠、刀头顺势带到地上再慢慢收
##   grip / grip_at 双手握（左手搭到刀柄上，离右手几格）
##   rise 0~1 翻滚里接的“起身斩”：从低处起、身子往前送
static func swing(kind: String, su: float, ac: float, rc: float, opt: Dictionary = {}) -> Dictionary:
	if kind == "thrust" or kind == "shoot":
		return _thrust(kind, su, ac, rc, opt)
	var heft := float(opt.get("heft", 0.0))
	var w := ease_out(su)                 # 蓄到起手位置
	var a := ease_out(ac)                 # 挥过去
	# 收回来：重兵器先顺着劲儿停一下再收（heft 越大停得越久）
	var r := ease_in_out(clampf((rc - 0.3 * heft) / (1.0 - 0.3 * heft), 0.0, 1.0))
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
	if kind == "h_rl" or kind == "h_lr":
		th0 *= 1.0 + 0.12 * heft
		ph1 -= 18.0 * heft                 # 重兵器横扫完刀头往地上带
	elif kind == "v_down":
		ph0 += 12.0 * heft
		ph1 -= 10.0 * heft
	var idle_th := -5.0
	var idle_ph := -25.0
	var f0: Vector2 = opt.get("from", Vector2(idle_th, idle_ph))
	f0.x = th0 + wrapf(f0.x - th0, -180.0, 180.0)
	var th := lerpf(f0.x, th0, w)
	var ph := lerpf(f0.y, ph0, w)
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
	var twist := clampf(th * (0.35 + 0.2 * heft) * D2R, -0.8, 0.8)
	p["twist"] = twist
	# 前摇往后坐一点（蓄力），出刀时重心送出去
	var lean := 0.15 + (0.15 + 0.12 * heft) * a - 0.1 * r - 0.08 * w * (1.0 - a)
	var step := (3.0 + 2.0 * heft) * a * (1.0 - r * 0.6)
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
	# 前摇压低身子（重兵器下劈反而踮脚举高），出刀沉下去
	var dip := -0.9 * w * (1.0 - a)
	if kind == "v_down" and heft > 0.5:
		dip = 1.6 * heft * w * (1.0 - a)
	p["bob"] = float(p.get("bob", 0.0)) - 1.2 * a + dip
	_opt_finish(p, opt, su, ac, rc, step)
	return p


## swing / _thrust 共用的收尾：双手握、左右脚交替上步、起身斩
static func _opt_finish(p: Dictionary, opt: Dictionary, su: float, ac: float, rc: float, step: float) -> void:
	if opt.is_empty():
		return
	var g := float(opt.get("grip", 0.0))
	if g > 0.0:
		p["grip"] = g
		p["grip_at"] = float(opt.get("grip_at", 3.0))
	var lead := float(opt.get("lead", 1.0))
	if lead < 0.0:
		# 左脚上步：两只脚前后对调（还是右脚在右、左脚在左）
		var fr: Vector3 = p["foot_r"]
		var fl: Vector3 = p["foot_l"]
		p["foot_l"] = Vector3(fr.x, fr.y, -absf(fr.z))
		p["foot_r"] = Vector3(fl.x, fl.y, absf(fl.z))
	if opt.has("feet0"):
		var f0: Array = opt["feet0"]
		var sp := ease_in_out(clampf(su * 0.6 + ac * 0.4 + rc, 0.0, 1.0))
		for i in range(2):
			var key := "foot_r" if i == 0 else "foot_l"
			var to: Vector3 = p[key]
			var from: Vector3 = f0[i]
			var v := from.lerp(to, sp)
			if to.x > from.x + 1.0:
				v.y += sin(sp * PI) * 2.2      # 往前迈的那只脚抬一下
			p[key] = v
	var rise := float(opt.get("rise", 0.0))
	if rise > 0.0:
		var a := ease_out(ac)
		var k := (1.0 - a) * rise
		p["bob"] = float(p.get("bob", 0.0)) - 3.5 * k
		p["lean"] = float(p.get("lean", 0.0)) + 0.35 * k


## 直刺（枪、匕首收势）：前摇把手往回收、刃端平；判定时整条胳膊送出去，身子前倾。
## 射击（连弩）：两手平端在胸前，判定时往后一顿（后坐）
static func _thrust(kind: String, su: float, ac: float, rc: float, opt: Dictionary = {}) -> Dictionary:
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
		if opt.has("grip"):
			p["grip"] = float(opt["grip"])
			p["grip_at"] = 3.0
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
	p["bob"] = -0.6 - 1.4 * a - 0.8 * w * (1.0 - a)
	if opt.has("from"):
		# 刺之前刃先从上一刀的位置收回到腰间
		var f0: Vector2 = opt["from"]
		var b0 := dirv(f0.x, f0.y)
		var k := 1.0 - w
		if ac <= 0.0 and k > 0.0:
			p["blade"] = (p["blade"] as Vector3).lerp(b0, k).normalized()
	_opt_finish(p, opt, su, ac, rc, step)
	return p


## 翻滚：k 0~1
static func roll(k: float) -> Dictionary:
	var tuck := sin(clampf(k, 0, 1) * PI)
	return {
		"roll": TAU * ease_in_out(k), "bob": -6.0 * tuck, "lean": 0.4 * tuck,
		"hand_r": dirv(-20, -10, 0.55), "hand_l": dirv(20, -10, 0.55), "blade": dirv(-170, 10),
		"foot_r": Vector3(2.0, 6.0 * tuck, 0.5), "foot_l": Vector3(1.0, 5.0 * tuck, -0.5), "head": 0.5 * tuck,
	}


## 受击后仰：k 0~1（1 = 恢复）；back = 从背后挨打（往前扑）
static func hurt(k: float, back: bool = false) -> Dictionary:
	var h := 1.0 - ease_out(k)
	if back:
		return {
			"tilt": -0.3 * h, "lean": 0.25 + 0.3 * h, "head": 0.35 * h, "bob": -1.6 * h,
			"hand_r": dirv(-50, -10 - 20 * h, 0.85), "hand_l": dirv(50, -10 - 20 * h, 0.85), "blade": dirv(-60, -20),
			"foot_r": Vector3(3.0, 0, 1.0), "foot_l": Vector3(-1.5, 2.0 * h, -0.8),
		}
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
		if key == "roll" or key == "spin":
			# 整圈的角（翻滚 2π、回旋 2π）按最近的方向插：不然翻完滚接站姿会倒着拧回去一整圈
			var fa := float(va) if va != null else 0.0
			var fb := float(vb) if vb != null else 0.0
			out[key] = lerpf(fb + wrapf(fa - fb, -PI, PI), fb, k)
		elif va == null:
			out[key] = vb if vb is Vector3 else lerpf(0.0, float(vb), k)
		elif vb == null:
			out[key] = va if va is Vector3 else lerpf(float(va), 0.0, k)
		elif va is Vector3:
			out[key] = (va as Vector3).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out


# ================= 主角：兵器拿法、架势、移动衔接（2026-11-09 动作衔接） =================

## 兵器的拿法：heft 沉重度（重兵器举得开、拧得狠、收得慢）、grip 双手握（左手离右手 grip_at 格）、
## carry 站着/跑着怎么拿、settle 收势后的收刀小动作
const ARMS := {
	"sword": {"heft": 0.3, "grip": 0.0, "grip_at": 3.0, "carry": "side", "settle": "flick"},
	"greatsword": {"heft": 0.85, "grip": 0.85, "grip_at": 4.0, "carry": "shoulder", "settle": "heave"},
	"dagger": {"heft": 0.0, "grip": 0.0, "grip_at": 3.0, "carry": "reverse", "settle": "flick"},
	"axe": {"heft": 0.65, "grip": 0.0, "grip_at": 3.0, "carry": "low", "settle": "flick"},
	"spear": {"heft": 0.45, "grip": 0.75, "grip_at": 9.0, "carry": "spear", "settle": "twirl"},
	"staff": {"heft": 0.4, "grip": 0.75, "grip_at": 10.0, "carry": "staff", "settle": "twirl"},
	"twin": {"heft": 0.1, "grip": 0.0, "grip_at": 3.0, "carry": "twin", "settle": "flick"},
	"hammer": {"heft": 1.0, "grip": 0.9, "grip_at": 4.0, "carry": "shoulder", "settle": "heave"},
	"crossbow": {"heft": 0.15, "grip": 0.6, "grip_at": 3.0, "carry": "bow", "settle": ""},
}


static func arms(id: String) -> Dictionary:
	return ARMS.get(id, ARMS["sword"])


## 刀刃方向 → (θ, φ) 度数（swing 的 from 用）
static func blade_angles(b: Vector3) -> Vector2:
	if b.length_squared() < 0.0001:
		return Vector2(-5, -25)
	b = b.normalized()
	return Vector2(rad_to_deg(atan2(-b.z, b.x)), rad_to_deg(asin(clampf(b.y, -1.0, 1.0))))


## 手和兵器怎么拿：g 0 = 放松，1 = 架势（打完几秒里，刀尖前指、随时出手）
static func carry(style: String, g: float) -> Dictionary:
	var r := {}
	var gd := {}
	match style:
		"shoulder":
			# 扛在右肩上；架势时双手握着往前上方举
			r = {"hand_r": dirv(-15, 12, 0.5), "blade": dirv(-160, 55), "grip": 0.45, "grip_at": 4.0, "hand_l": dirv(15, -30, 0.6)}
			gd = {"hand_r": dirv(-8, -12, 0.75), "blade": dirv(-15, 42), "grip": 0.95, "grip_at": 4.0, "hand_l": dirv(15, -30, 0.6)}
		"reverse":
			# 匕首：刃往后、贴着小臂（像反握）；架势时拳头前伸
			r = {"hand_r": dirv(-30, -50, 0.8), "blade": dirv(-170, -35), "hand_l": dirv(30, -65, 0.85)}
			gd = {"hand_r": dirv(-12, -8, 0.78), "blade": dirv(-150, -45), "hand_l": dirv(25, -15, 0.7)}
		"low":
			r = {"hand_r": dirv(-30, -60, 0.85), "blade": dirv(-20, -55), "hand_l": dirv(30, -65, 0.85)}
			gd = {"hand_r": dirv(-22, -15, 0.8), "blade": dirv(-40, 35), "hand_l": dirv(30, -25, 0.75)}
		"spear":
			# 枪斜端在身前，枪尖朝左前上；架势时放平指向前
			r = {"hand_r": dirv(-30, -40, 0.65), "blade": dirv(30, 45), "grip": 0.6, "grip_at": 9.0, "hand_l": dirv(20, -20, 0.8)}
			gd = {"hand_r": dirv(-25, -32, 0.55), "blade": dirv(3, -6), "grip": 0.9, "grip_at": 9.0, "hand_l": dirv(20, -20, 0.8)}
		"staff":
			# 棍横在身前；架势时斜指左前
			r = {"hand_r": dirv(-25, -45, 0.7), "blade": dirv(75, 8), "grip": 0.6, "grip_at": 10.0, "hand_l": dirv(20, -30, 0.8)}
			gd = {"hand_r": dirv(-22, -25, 0.7), "blade": dirv(35, 15), "grip": 0.9, "grip_at": 10.0, "hand_l": dirv(20, -30, 0.8)}
		"twin":
			r = {"hand_r": dirv(-30, -55, 0.8), "blade": dirv(-25, -40), "hand_l": dirv(30, -55, 0.8)}
			gd = {"hand_r": dirv(-20, -20, 0.82), "blade": dirv(18, 2), "hand_l": dirv(22, -22, 0.82)}
		"bow":
			r = {"hand_r": dirv(-15, -50, 0.62), "blade": dirv(0, -15), "grip": 0.5, "grip_at": 3.0, "hand_l": dirv(25, -50, 0.7)}
			gd = {"hand_r": dirv(-8, -6, 0.8), "blade": dirv(0, 0), "grip": 0.8, "grip_at": 3.0, "hand_l": dirv(25, -50, 0.7)}
		_:
			# 剑：垂在右手边；架势时剑尖前指、左手捏剑指护在胸前
			r = {"hand_r": dirv(-25, -55, 0.78), "blade": dirv(-5, -25), "hand_l": dirv(30, -70, 0.85)}
			gd = {"hand_r": dirv(-14, -24, 0.86), "blade": dirv(8, 10), "hand_l": dirv(-5, 8, 0.5)}
	if not r.has("grip"):
		r["grip"] = 0.0
		gd["grip"] = 0.0
		r["grip_at"] = 3.0
		gd["grip_at"] = 3.0
	return blend(r, gd, g)


## 主角站姿：呼吸 + 兵器拿法；架势时屈膝、侧身、两脚分开
static func hero_idle(t: float, style: String, g: float) -> Dictionary:
	var p := idle(t)
	var br := sin(t * (2.2 + 0.8 * g))
	p["bob"] = br * (0.35 + 0.15 * g) - 0.6 - 1.6 * g
	p["lean"] = 0.08 + 0.08 * g
	p["twist"] = -0.18 * g
	p["foot_r"] = Vector3(1.5 + 0.8 * g, 0, 0.6 + 0.7 * g)
	p["foot_l"] = Vector3(-1.5 - 1.0 * g, 0, -0.6 - 0.5 * g)
	# 放松时重心慢慢在两脚间换（很轻）
	var sway := sin(t * 0.55) * (1.0 - g)
	p["bank"] = sway * 0.025
	p.merge(carry(style, g), true)
	return p


## 主角跑：手里拿着兵器的那只手不再前后甩（剑例外，放松时照甩）；架势里跑刀也端着
static func hero_run(phase: float, k: float, style: String, g: float) -> Dictionary:
	var p := run(phase, k)
	var s := sin(phase)
	var c := carry(style, g)
	if style == "side" and g <= 0.0:
		return p
	var hold := 1.0 if style != "side" else g
	var cr: Vector3 = c["hand_r"]
	c["hand_r"] = cr + Vector3(s * 0.04 * k, absf(cos(phase)) * 0.06 * k, 0)
	var out := blend(p, p.merged(c, true), hold)
	if float(c.get("grip", 0.0)) > 0.3:
		out["twist"] = float(out.get("twist", 0.0)) * 0.4      # 双手握着跑，上身不怎么拧
	return out


## 急停：后仰刹步，前脚蹬在前面，两手往外张开稳住（k 0~1）
static func skid(k: float, style: String) -> Dictionary:
	var e := sin(clampf(k, 0.0, 1.0) * PI) if k > 0.3 else sin(clampf(k / 0.3, 0.0, 1.0) * PI * 0.5)
	var p := {
		"lean": -0.22 * e + 0.05, "bob": -2.6 * e - 0.6, "twist": 0.22 * e, "head": 0.12 * e,
		"hand_l": dirv(55, -15, 0.85),
		"foot_r": Vector3(4.5 * e + 1.0, 0, 1.3), "foot_l": Vector3(-2.5 * e - 1.0, 0, -1.0),
	}
	p.merge(carry(style, 0.5), false)
	return p


## 急转身：压低、往新方向拧，脚蹬地（k 0~1，朝向由 Hero 转）
static func pivot(k: float, style: String, dir_left: bool) -> Dictionary:
	var e := sin(clampf(k, 0.0, 1.0) * PI)
	var sd := 1.0 if dir_left else -1.0
	var p := {
		"lean": 0.35 * e + 0.1, "bob": -3.0 * e - 0.6, "twist": 0.45 * sd * (1.0 - k), "head": -0.1 * e, "bank": -0.18 * sd * e,
		"hand_l": dirv(50, -25, 0.85),
		"foot_r": Vector3(2.5 * e, 0, 1.6), "foot_l": Vector3(-2.5 * e, 1.5 * e, -1.4),
	}
	p.merge(carry(style, 0.5), false)
	return p


## 落地缓冲（翻滚完、跳劈完）：k 0~1
static func land(k: float) -> Dictionary:
	var e := 1.0 - ease_out(k)
	return {"bob": -2.8 * e, "lean": 0.3 * e, "head": 0.1 * e}


## 站久了的小动作（k 0~1）：剑、匕首、双刀低头看一眼刃，翻一下手腕；其他兵器换个重心、左右看看
static func fidget(k: float, style: String, t: float) -> Dictionary:
	var e := sin(clampf(k, 0.0, 1.0) * PI)
	if style in ["side", "reverse", "twin"]:
		var tw := sin(clampf((k - 0.35) / 0.3, 0.0, 1.0) * PI) * 25.0      # 中间翻一下腕
		return {
			"hand_r": dirv(-5, -12, 0.62).lerp(dirv(-25, -55, 0.78), 1.0 - e), "blade": dirv(70 - tw, 18 + tw * 0.4).lerp(dirv(-5, -25), 1.0 - e),
			"head": 0.05 + 0.3 * e, "look": -0.35 * e, "twist": 0.1 * e,
		}
	return {"look": sin(k * TAU) * 0.6 * e, "bob": -0.6 - 0.5 * e, "bank": 0.05 * sin(k * PI * 2.0), "head": 0.05}


## 收势后的收刀小动作（k 0~1，约 0.55 秒）：flick 振刀（甩一下血）/ heave 扛回肩上 / twirl 枪棍在身前转一圈
static func settle(kind: String, k: float, style: String) -> Dictionary:
	var g := carry(style, 1.0)
	match kind:
		"flick":
			# 0~0.3 刀往右下猛地一甩，之后慢慢回到架势
			var a := ease_out(clampf(k / 0.3, 0.0, 1.0))
			var b := ease_in_out(clampf((k - 0.4) / 0.6, 0.0, 1.0))
			var p := {
				"hand_r": dirv(-20, 10, 0.7).lerp(dirv(-70, -35, 0.95), a).lerp(g["hand_r"], b),
				"blade": dirv(-10, 40).lerp(dirv(-80, -40), a).lerp(g["blade"], b),
				"twist": lerpf(0.1, -0.35, a) * (1.0 - b) - 0.18 * b, "lean": 0.12, "bob": -1.0 - 1.2 * a * (1.0 - b) - 1.4 * b,
				"head": 0.12 * a * (1.0 - b),
			}
			return g.merged(p, true)
		"heave":
			var rs := carry(style, 0.0)
			var a := ease_in_out(k)
			var p := blend(g, rs, a)
			p["bob"] = -1.0 - 2.2 * sin(k * PI)
			p["lean"] = 0.25 * sin(k * PI)
			return p
		"twirl":
			var a := ease_in_out(clampf(k / 0.75, 0.0, 1.0))
			var ang := -40.0 + 400.0 * a
			var p := g.duplicate()
			p["blade"] = dirv(ang, 10.0 * sin(a * PI)).lerp(g["blade"], clampf((k - 0.75) / 0.25, 0.0, 1.0))
			p["grip"] = 0.0 if k < 0.75 else g["grip"]
			p["hand_r"] = dirv(-10, -15, 0.7)
			p["bob"] = -1.2
			return p
	return g


## 突进斩穿过去之后的残心：压低滑停，刀横在身后，然后慢慢起身（k 0~1）
static func dash_end(k: float) -> Dictionary:
	var e := ease_out(clampf(k, 0.0, 1.0))
	var up := ease_in_out(clampf((k - 0.55) / 0.45, 0.0, 1.0))
	return {
		"lean": lerpf(0.55, 0.15, up), "bob": lerpf(-4.5, -1.2, up), "twist": lerpf(0.55, 0.0, up), "head": 0.15 * (1.0 - up),
		"hand_r": dirv(lerpf(105, -14, up), lerpf(-12, -24, up), 0.95 - 0.1 * up), "blade": dirv(lerpf(150, 8, up), lerpf(-15, 10, up)),
		"hand_l": dirv(lerpf(-30, -5, up), lerpf(-30, 8, up), lerpf(0.7, 0.5, up)),
		"foot_r": Vector3(lerpf(5.0, 2.3, up), 0, 1.8), "foot_l": Vector3(lerpf(-4.5, -2.5, up), 0, -1.6),
		"bank": 0.1 * (1.0 - e),
	}


## 喝药葫芦：左手举到嘴边、仰头喝，喝完放下（k 0~1）；右手兵器照常拿着
static func drink(k: float, style: String) -> Dictionary:
	var up := ease_out(clampf(k / 0.3, 0.0, 1.0)) * (1.0 - ease_in_out(clampf((k - 0.75) / 0.25, 0.0, 1.0)))
	var tilt := sin(clampf((k - 0.3) / 0.45, 0.0, 1.0) * PI)
	var p := carry(style, 0.0)
	p.merge({
		"hand_l": dirv(30, -65, 0.85).lerp(dirv(-55, 38, 0.48), up), "head": -0.4 * tilt, "lean": 0.04 - 0.12 * tilt,
		"bob": -0.6, "foot_r": Vector3(1.8, 0, 0.8), "foot_l": Vector3(-1.8, 0, -0.8),
	}, true)
	if float(p.get("grip", 0.0)) > 0.0:
		p["grip"] = 0.0     # 腾出左手
	return p
