class_name SharedHazards
extends RefCounted
## 敌我共享机制：场上的危险不认人。敌人留下的火、毒，房间机关（骨刺、涌泉、箭雨、铜汁），骨弩手的箭，
## 冲阵骨的冲锋，打到敌人身上一样疼。会玩的人可以把敌人引进火里、站到弩手和别的怪连成一线、让冲阵骨撞翻自己人。
## 主角自己扔的火油罐本来就只烧敌人（FirePool.hurts_foes），不走这里。
## 每种来源一行：mult 对普通敌人的倍率（乘在原伤害上）、boss 对头目的倍率、immune 哪种敌人不怕（data 里有这个键）。
## 想加一种：在 RULES 里加一行，在伤害发生的地方调 hit_foes / hit_foe。--noshared 关掉（对比用）。

const RULES := {
	"pool_fire": {"mult": 2.0, "boss": 0.4, "immune": "fire", "word": "烫", "color": Color(1.0, 0.55, 0.2)},
	"pool_poison": {"mult": 2.0, "boss": 0.4, "immune": "poison_immune", "word": "毒", "color": Color(0.6, 1.0, 0.35)},
	"hazard": {"mult": 1.6, "boss": 0.4, "immune": "", "word": "", "color": Color(1.0, 0.85, 0.6)},
	"arrow": {"mult": 0.7, "boss": 0.3, "immune": "", "word": "误伤", "color": Color(1.0, 0.75, 0.45)},
	"charge": {"mult": 1.2, "boss": 0.3, "immune": "", "word": "撞翻", "color": Color(1.0, 0.8, 0.4)},
}

static var _off := -1
static var stats := {}   # 这一局每种来源打中敌人几次、多少伤害（跑局日志 RUNSHARED 行）


static func enabled() -> bool:
	if _off < 0:
		_off = 1 if OS.get_cmdline_user_args().has("--noshared") else 0
	return _off == 0


## 这个敌人吃不吃这一类伤害（火骨不怕火、瘴菇骨不怕毒、头目按 boss 倍率）
static func mult_for(f: Foe, rule: String) -> float:
	var r: Dictionary = RULES.get(rule, {})
	if r.is_empty() or f == null or not f.alive:
		return 0.0
	var im := String(r["immune"])
	if im != "" and f.data.get(im, false):
		return 0.0
	if rule == "pool_poison" and f.kind == "sporer":
		return 0.0
	return float(r["boss"]) if f.is_boss else float(r["mult"])


## 打一个敌人：返回打没打到
static func hit_foe(f: Foe, rule: String, dmg: float, dir: Vector3, knock: float = 0.0, elem: String = "", stun: float = 0.1) -> bool:
	if not enabled():
		return false
	var m := mult_for(f, rule)
	if m <= 0.0:
		return false
	var info := HitInfo.make(null, f, dmg * m, HitInfo.Weight.LIGHT if knock < 8.0 else HitInfo.Weight.HEAVY)
	info.attacker = null
	info.dir = dir if dir.length() > 0.01 else Vector3.FORWARD
	info.point = f.chest()
	info.knock = knock
	info.stun = stun
	info.elem = elem
	var r: Dictionary = RULES[rule]
	if String(r["word"]) != "" and randf() < 0.35:
		Feel.I.callout(f.head_top(), String(r["word"]), r["color"], 0.5)
	var stt: Array = stats.get(rule, [0, 0.0])
	stats[rule] = [int(stt[0]) + 1, float(stt[1]) + info.damage]
	Feel.I.on_hit(info)
	return true


## 打一圈里的敌人（except 不打，比如放箭的那个自己）
static func hit_foes(tree: SceneTree, p: Vector3, radius: float, rule: String, dmg: float, knock: float = 0.0, elem: String = "", except: Node = null) -> int:
	if not enabled():
		return 0
	var n := 0
	for f: Node in tree.get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or ff == except or not ff.alive:
			continue
		var d := ff.global_position - p
		d.y = 0
		if d.length() <= radius + ff.radius * 0.5:
			if hit_foe(ff, rule, dmg, d.normalized() if d.length() > 0.05 else Vector3.FORWARD, knock, elem):
				n += 1
	return n
