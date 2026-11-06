extends Node
## 数值上限自检（无界面运行，不碰正式存档）：
##   godot --headless --path . res://tests/test_balance.tscn
## 把所有加成来源（天赋全满、十二件信物、兵器特性、主手传世、五个部位传世、套装、心法叠满、天象、第三幕路上所得）
## 按“每个属性各自最极端”的搭配叠起来，交给 Hero.apply_stats 算出最终数值，检查会不会叠爆：
## 受伤倍率、冷却、翻滚无敌、吸血、会心、移速这些都要停在上限以内。
## 另外打一张兵器连招单体输出表（每秒伤害、一轮多久），给数值报告用。

var failures := 0
## 一局里同一种心法最多能拿几次（清房三选一 + 商人；三幕各 10~12 间房，按 8 次算极端）
const BOON_STACK := 8


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


## 某个属性往“好”的方向叠到最极端：每个来源挑这个属性最大的那一项
func _extreme(key: String, sign_: float) -> Dictionary:
	var st := {}
	# 天赋全满
	for t: Dictionary in ArpgData.TALENT_TREES:
		for tier: Array in t["tiers"]:
			for nd: Dictionary in tier:
				ArpgData.add_stats(st, nd["stats"], int(nd["max"]))
	# 信物
	for k: Dictionary in ArpgSecrets.KEEPS:
		ArpgData.add_stats(st, k["stats"])
	# 主手：传世 + 两条这个属性的词条（同一件不重复，这里放宽算两条）
	ArpgData.add_stats(st, {"atk": ArpgGear.WEAPON_RARITY_ATK * 4})
	var aff_max := 0.0
	for a: Array in ArpgGear.AFFIXES:
		if a[0] == key:
			aff_max = float(a[2]) if sign_ > 0 else float(a[1])
	if aff_max != 0.0:
		ArpgData.add_stats(st, {key: aff_max})
	# 五个部位都传世：每个部位挑这个属性最大的底子，再各带一条这个属性的词条
	for slot: String in ["armor", "helm", "boots", "charm", "charm2"]:
		var pool: Array = ArpgData.gear_pool("charm" if slot == "charm2" else slot)
		var best: Dictionary = {}
		var bv := 0.0
		for g: Dictionary in pool:
			var v := float((g["stats"] as Dictionary).get(key, 0.0)) * sign_
			if v > bv:
				bv = v
				best = g
		if not best.is_empty():
			ArpgData.add_stats(st, ArpgGear.stats({"slot": slot, "base": best["id"], "rarity": 4, "affixes": []}))
		if aff_max != 0.0:
			ArpgData.add_stats(st, {key: aff_max})
	# 套装两件效果全拿（实际最多两套，这里放宽）
	for sid: String in ArpgArms.GEAR_SETS:
		ArpgData.add_stats(st, ArpgArms.GEAR_SETS[sid]["s2"])
	# 心法：这个属性最大的那一种叠 BOON_STACK 次
	var bb: Dictionary = {}
	var bbv := 0.0
	for b: Dictionary in ArpgData.BOONS:
		var v := float((b["stats"] as Dictionary).get(key, 0.0)) * sign_
		if v > bbv:
			bbv = v
			bb = b
	if not bb.is_empty():
		ArpgData.add_stats(st, bb["stats"], BOON_STACK)
	# 天象、第三幕路上（石门灯、驿马、支线）
	for om: String in ArpgState.OMENS:
		var v := float((ArpgState.OMENS[om].get("stats", {}) as Dictionary).get(key, 0.0)) * sign_
		if v > 0.0:
			ArpgData.add_stats(st, {key: v * sign_})
	ArpgData.add_stats(st, {"atk": 0.15, "energy": 0.2, "move": 0.12, "crit": 0.1, "hp": 40.0})
	# 兵器特性
	var wbest := 0.0
	for wid: String in ArpgData.WEAPONS:
		wbest = maxf(wbest, float(ArpgArms.weapon_stats(wid).get(key, 0.0)) * sign_)
	ArpgData.add_stats(st, {key: wbest * sign_})
	return st


func _run() -> void:
	var keep := Game.save.duplicate(true)
	Game.save["talents"] = {}
	var h := Hero.new()
	print("属性叠到最极端（每个属性各算一次）")
	var cases := [
		["dmg_taken", -1.0, "受伤倍率", func(x: Hero) -> float: return x.taken_mult, func(v: float) -> bool: return v >= 0.3 - 0.001],
		["dash_cd", 1.0, "突进冷却（秒）", func(x: Hero) -> float: return x.dash_cd, func(v: float) -> bool: return v >= Hero.BASE_DASH_CD * 0.3 - 0.001],
		["finish_cd", 1.0, "终结冷却（秒）", func(x: Hero) -> float: return x.finish_cd, func(v: float) -> bool: return v >= Hero.BASE_FINISH_CD * 0.3 - 0.001],
		["iframes", 1.0, "翻滚无敌（秒，翻滚 %.2f 秒、没有冷却）" % 0.4, func(x: Hero) -> float: return x.roll_iframes, func(v: float) -> bool: return v <= Hero.ROLL_IFRAMES_MAX + 0.001],
		["lifesteal", 1.0, "吸血", func(x: Hero) -> float: return x.lifesteal, func(v: float) -> bool: return v <= Hero.LIFESTEAL_MAX + 0.001],
		["crit", 1.0, "会心率加成", func(x: Hero) -> float: return x.crit_bonus, func(_v: float) -> bool: return true],
		["move", 1.0, "移速（米/秒）", func(x: Hero) -> float: return x.move_speed, func(v: float) -> bool: return v <= Hero.BASE_MOVE * Hero.MOVE_MAX + 0.001],
		["energy", 1.0, "气力获取倍率", func(x: Hero) -> float: return x.energy_mult, func(v: float) -> bool: return v <= Hero.ENERGY_MAX + 0.001],
		["atk", 1.0, "伤害倍率", func(x: Hero) -> float: return x.dmg_mult, func(_v: float) -> bool: return true],
		["thorns", 1.0, "荆棘反弹", func(x: Hero) -> float: return x.thorns, func(_v: float) -> bool: return true],
		["kill_heal", 1.0, "斩杀回血", func(x: Hero) -> float: return x.kill_heal, func(_v: float) -> bool: return true],
		["gourds", 1.0, "药葫芦", func(x: Hero) -> float: return float(x.max_gourds), func(v: float) -> bool: return v <= Hero.GOURDS_MAX],
	]
	for c: Array in cases:
		var st := _extreme(String(c[0]), float(c[1]))
		h.apply_stats(st, "sword", true)
		var v: float = (c[3] as Callable).call(h)
		_check((c[4] as Callable).call(v), "%s 最多叠到 %.3f（原始加成 %.3f）" % [c[2], v, ArpgData.stat(st, String(c[0]))])
	# 游历难度再乘一层：受伤倍率最低
	var st2 := _extreme("dmg_taken", -1.0)
	st2["easy"] = ArpgState.EASY_TAKEN
	h.apply_stats(st2, "sword", true)
	_check(h.taken_mult >= 0.3 * (1.0 - ArpgState.EASY_TAKEN) - 0.001, "游历难度下受伤倍率最低 %.3f" % h.taken_mult)

	print("\n来回换兵器、穿脱装备不能刷血刷药")
	h.apply_stats({}, "sword", true)
	h.hp = 60.0
	for i in range(5):
		h.apply_stats({"hp": 20.0, "gourds": 1.0}, "sword")
		h.apply_stats({}, "sword")
	_check(is_equal_approx(h.hp, 80.0) and h.gourds == 4, "换五个来回：生命 %.0f（60 + 第一次戴上的 20）、药葫芦 %d（3 + 第一次的 1）" % [h.hp, h.gourds])
	h.apply_stats({}, "sword", true)
	h.apply_stats({"hp": 20.0}, "sword")
	_check(is_equal_approx(h.hp, h.max_hp), "满血时上限变高照样补满（%.0f / %.0f）" % [h.hp, h.max_hp])
	h.apply_stats({}, "sword")
	h.apply_stats({"hp": 20.0}, "sword")
	_check(is_equal_approx(h.hp, h.max_hp), "满血时换下再换回，不掉血（%.0f / %.0f）" % [h.hp, h.max_hp])
	h.apply_stats({"hp": 45.0}, "sword")
	_check(is_equal_approx(h.hp, h.max_hp), "壮骨这类新加的上限照样补上（%.0f / %.0f）" % [h.hp, h.max_hp])
	h.free()

	print("\n兵器连招单体输出（伤害倍率 1、不算会心出血和特性；一轮 = 前几段按可接时间、最后一段打满）")
	for wid: String in ArpgData.WEAPONS:
		var cmb := ArpgArms.combo(wid)
		var t := 0.0
		var d := 0.0
		for i in range(cmb.size()):
			var s: AttackStep = cmb[i]
			t += s.total() if i == cmb.size() - 1 else s.cancel_at
			d += s.damage
		d *= float(ArpgData.weapon(wid)["dmg"])
		print("  %-10s %d 段  一轮 %.2f 秒  伤害 %3d  每秒 %.1f" % [wid, cmb.size(), t, int(d), d / t])

	Game.save = keep
	print("\n" + ("全部测试通过" if failures == 0 else "有 %d 项没通过" % failures))
	get_tree().quit(1 if failures > 0 else 0)
