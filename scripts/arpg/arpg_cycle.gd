class_name ArpgCycle
extends RefCounted
## 轮回（通关后的加难，肉鸽的根本）：任一幕打通一次就开出“轮回一”，在某一级打通就开出下一级，最高十级。
## 轮回是叠加的：选轮回五，一到五的规矩全都生效。每级敌人再硬一点、伤害再高一点，魂玉和装备也更好。
## 词缀怪：轮回一起，每波有敌人带词缀（FoeAffix 的九条 + 轮回专用的“回”），带词缀的多掉一颗魂玉。
##
## 存档键（全部用 Game.save.get 读，没有就当 0）：
##   arpg_cycle       选好的轮回级（出发时用，0 = 本相）
##   arpg_cycle_max   已经开出的最高级
##   arpg_cycle_best  每一幕打通过的最高级 {"1": 3, "2": 1}（幕号写成字符串，第三幕直接用 "3"，不用改这里）
##   arpg_cycle_clear 每一幕每一级第一次打通的奖励领过没有 {"1": {"3": true}}
##   arpg_cycle_told  拾骨婆讲过轮回没有
## 第三幕接口：ArpgState.act 是几就按几记，_game_over(true) 时调 on_clear(state) 即可，规矩和词缀对哪一幕都一样。

const MAX := 10

## 每级的基础加成（乘上级数）：敌人生命 / 伤害、魂玉、装备运气
const HP_PER := 0.08
const DMG_PER := 0.05
const JADE_PER := 0.15
const LUCK_PER := 0.04

## 每一级多加的一条规矩：[名字, 说明]
const RULES := [
	["本相", "山还是那座山"],
	["怨", "每波有一只敌人带词缀，多掉一颗魂玉"],
	["急", "敌人出手前摇短一成半，走得也快一成"],
	["众", "每波敌人多两成"],
	["厉", "头目带一个词缀（迅、狂、雷、回）"],
	["枯", "药葫芦少一个"],
	["双", "每波两只词缀敌人，可能一只带两个"],
	["贵", "游商涨价三成，回血少三成"],
	["伤", "你受到的伤害 +15%"],
	["乱", "三成敌人带词缀"],
	["劫", "头目带两个词缀，敌人伤害再加一成"],
]
const NUM := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

## 词缀用敌人那边的 FoeAffix（迅 坚 狂 爆 魂 罩 焰 瘴 雷，加上轮回专用的“回”）。头目只抽下面这几条
const BOSS_AFFIXES := ["swift", "frenzy", "thunder", "mend"]


# ---------- 存档 ----------

static func unlocked() -> int:
	return clampi(int(Game.save.get("arpg_cycle_max", 0)), 0, MAX)


## 出发时用的轮回级（不超过已开出的）
static func picked() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cycle="):
			return clampi(int(a.substr(8)), 0, MAX)   # 测试：直接指定，不看解锁
	return clampi(int(Game.save.get("arpg_cycle", 0)), 0, unlocked())


static func pick(lv: int) -> void:
	Game.save["arpg_cycle"] = clampi(lv, 0, unlocked())
	Game.write_save()


static func best(act: int) -> int:
	return int((Game.save.get("arpg_cycle_best", {}) as Dictionary).get(str(act), -1))


static func cleared(act: int, lv: int) -> bool:
	return ((Game.save.get("arpg_cycle_clear", {}) as Dictionary).get(str(act), {}) as Dictionary).has(str(lv))


## 这一级第一次打通某一幕的奖励魂玉
static func first_clear_jade(lv: int) -> int:
	return 0 if lv <= 0 else 40 + 20 * lv


## 打通一局（任一幕、任一结局）：记录最高级、开出下一级、给第一次打通的奖励。返回要报给玩家的几行字
static func on_clear(s: ArpgState) -> Array:
	var out := []
	var lv := s.cycle
	var key := str(s.act)
	var bests: Dictionary = Game.save.get("arpg_cycle_best", {})
	bests[key] = maxi(int(bests.get(key, -1)), lv)
	Game.save["arpg_cycle_best"] = bests
	var cl: Dictionary = Game.save.get("arpg_cycle_clear", {})
	var per: Dictionary = cl.get(key, {})
	if lv > 0 and not per.has(str(lv)):
		per[str(lv)] = true
		cl[key] = per
		Game.save["arpg_cycle_clear"] = cl
		var j := first_clear_jade(lv)
		Game.save["jade"] = int(Game.save["jade"]) + j
		out.append("第一次在轮回%s打通这一幕：魂玉 +%d" % [NUM[lv], j])
	if lv >= unlocked() and lv < MAX:
		Game.save["arpg_cycle_max"] = lv + 1
		out.append("开出 轮回%s「%s」：%s" % [NUM[lv + 1], RULES[lv + 1][0], RULES[lv + 1][1]])
	if lv >= 1:
		ArpgAch.unlock("cycle_1")
	if lv >= 5:
		ArpgAch.unlock("cycle_5")
	if lv >= MAX:
		ArpgAch.unlock("cycle_10")
	Game.write_save()
	return out


static func label(lv: int) -> String:
	return "本相" if lv <= 0 else "轮回%s" % NUM[lv]


## 这一级累计生效的规矩（给菜单和“这一局”看）
static func summary(lv: int) -> String:
	if lv <= 0:
		return "不加难"
	var names := []
	for i in range(1, lv + 1):
		names.append(RULES[i][0])
	return "敌人生命 +%d%%、伤害 +%d%%；魂玉 +%d%%；规矩：%s" % [int(round(hp_mult_raw(lv) * 100.0 - 100.0)), int(round(dmg_mult_raw(lv) * 100.0 - 100.0)), int(round(JADE_PER * lv * 100.0)), "、".join(names)]


# ---------- 数值 ----------

static func hp_mult_raw(lv: int) -> float:
	return 1.0 + HP_PER * lv


static func dmg_mult_raw(lv: int) -> float:
	return (1.0 + DMG_PER * lv) * (1.1 if lv >= 10 else 1.0)


## 主角身上的加减（并进 ArpgState.stats()）
static func hero_stats(lv: int) -> Dictionary:
	var st := {}
	if lv <= 0:
		return st
	st["jade"] = JADE_PER * lv
	if lv >= 5:
		st["gourds"] = -1.0
	if lv >= 7:
		st["discount"] = -0.3
	if lv >= 8:
		st["taken_extra"] = 0.15   # 单独乘在最后（原来加进 dmg_taken，减伤叠到下限 0.3 的人这一条等于没有）
	return st


static func luck(lv: int) -> float:
	return LUCK_PER * lv


## 回血倍数（歇脚、清明天象）
static func heal_mult(lv: int) -> float:
	return 0.7 if lv >= 7 else 1.0


## 每波敌人数量倍数
static func count_mult(lv: int) -> float:
	return 1.2 if lv >= 3 else 1.0


# ---------- 词缀 ----------

## 这一波哪几只带词缀：返回 {第几只: 词缀数组}（第几只按这一波刷出来的先后算）
static func roll_wave(lv: int, total: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	if lv < 1 or total <= 0:
		return out
	var n := 1
	if lv >= 6:
		n = 2
	if lv >= 9:
		n = maxi(n, int(ceil(total * 0.3)))
	n = mini(n, total)
	var idx := range(total)
	idx.shuffle()
	for i in range(n):
		var k := 2 if lv >= 6 and rng.randf() < 0.35 else 1
		out[idx[i]] = roll_affixes(k, false, rng)
	return out


static func roll_affixes(k: int, boss: bool, rng: RandomNumberGenerator) -> Array:
	var pool: Array = BOSS_AFFIXES.duplicate() if boss else FoeAffix.DEFS.keys()
	var out := []
	while out.size() < k and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out


## 头目的词缀（轮回四一个，轮回十两个）
static func boss_affixes(lv: int, rng: RandomNumberGenerator) -> Array:
	if lv >= 10:
		return roll_affixes(2, true, rng)
	if lv >= 4:
		return roll_affixes(1, true, rng)
	return []


## 刷怪时（add_child 之前、FoeAffix.apply 之前）：按轮回级放大数值。词缀的数值由 FoeAffix.apply 管，这里不碰
static func scale_foe(f: Foe, lv: int) -> void:
	if lv <= 0:
		return
	f.max_hp *= hp_mult_raw(lv)
	f.hp = f.max_hp
	f.dmg_scale *= dmg_mult_raw(lv)
	if lv >= 2:
		# 轮回二「急」：所有敌人（不只是词缀怪）
		f.data = f.data.duplicate()
		f.data["windup"] = float(f.data["windup"]) * 0.85
		f.data["speed"] = float(f.data["speed"]) * 1.1
