class_name ArpgArms
extends RefCounted
## 兵器多重化、装备套装、道具、皮肤的数据和效果。
##   兵器：每种兵器一套连招（combo），特性写在 ArpgData.WEAPONS 的 trait 里，效果在 Hero 里按 weapon_id 判断。
##         一局里可以带两把（主手 / 副手），Q 切换；切换时附近有敌人，直接用新兵器打出收势一击（换刃斩）。
##   套装：GEAR_SETS，同一套穿够两件、三件各有效果（stats 键，Hero.apply_stats 读）。
##   道具：ITEMS，最多带三种、每种叠到 max 个，R 用、T 换下一种。效果在 use_item。
##   皮肤：SKINS，山门“衣箱”里换，解锁条件 unlock。


# ---------- 兵器连招 ----------

## AttackStep.make(名字, 挥法, 伤害, 前摇, 判定, 后摇, 可接下一段, 前冲, 半径, 扇角, 重击, 击退, 出血, 刀光倾斜)
static func combo(id: String) -> Array[AttackStep]:
	var c: Array[AttackStep] = []
	match id:
		"greatsword":
			c.append(AttackStep.make("横斩!", "h_rl", 16.0, 0.17, 0.09, 0.3, 0.28, 1.4, 3.1, 170.0, true, 7.0, 0, 0.1))
			c.append(AttackStep.make("回斩!", "h_lr", 17.0, 0.15, 0.09, 0.3, 0.27, 1.4, 3.1, 170.0, true, 7.0, 0, -0.15))
			c.append(AttackStep.make("跳劈!", "v_down", 32.0, 0.24, 0.1, 0.4, 0.38, 2.6, 3.3, 80.0, true, 11.0, 1).with_fx("quake", 3.0))
		"dagger":
			c.append(AttackStep.make("1段!", "h_rl", 6.0, 0.05, 0.05, 0.13, 0.1, 1.2, 2.0, 140.0, false, 2.5, 0, 0.1))
			c.append(AttackStep.make("2段!", "h_lr", 6.0, 0.05, 0.05, 0.13, 0.1, 1.2, 2.0, 140.0, false, 2.5, 0, -0.15))
			c.append(AttackStep.make("3段!", "h_rl", 7.0, 0.05, 0.05, 0.13, 0.1, 1.3, 2.0, 140.0, false, 2.5, 0, 0.2))
			c.append(AttackStep.make("4段!", "h_lr", 7.0, 0.05, 0.05, 0.14, 0.11, 1.3, 2.0, 140.0, false, 3.0, 1, -0.2))
			c.append(AttackStep.make("影刺!", "thrust", 13.0, 0.08, 0.06, 0.22, 0.2, 2.4, 2.5, 60.0, true, 6.0, 2))
		"axe":
			c.append(AttackStep.make("1段!", "h_rl", 13.0, 0.12, 0.08, 0.26, 0.22, 1.6, 2.6, 160.0, false, 5.0, 0, 0.12))
			c.append(AttackStep.make("2段!", "h_lr", 14.0, 0.11, 0.08, 0.26, 0.22, 1.6, 2.6, 160.0, false, 5.0, 0, -0.18))
			c.append(AttackStep.make("碎骨!", "v_down", 28.0, 0.2, 0.1, 0.36, 0.34, 2.2, 2.9, 70.0, true, 9.0, 1).with_fx("quake", 2.8))
		"spear":
			c.append(AttackStep.make("刺!", "thrust", 10.0, 0.08, 0.07, 0.2, 0.17, 1.8, 3.8, 36.0, false, 4.0, 0))
			c.append(AttackStep.make("再刺!", "thrust", 11.0, 0.08, 0.07, 0.2, 0.17, 1.8, 3.8, 36.0, false, 4.0, 0))
			c.append(AttackStep.make("横扫!", "h_rl", 13.0, 0.12, 0.08, 0.26, 0.22, 1.2, 3.4, 200.0, false, 7.0, 0, 0.05))
			c.append(AttackStep.make("破阵!", "thrust", 24.0, 0.14, 0.1, 0.32, 0.3, 3.6, 4.2, 30.0, true, 9.0, 1).with_fx("pierce", 6.5))
		"staff":
			c.append(AttackStep.make("1棍!", "h_rl", 8.0, 0.08, 0.07, 0.18, 0.15, 1.4, 3.0, 180.0, false, 8.0, 0, 0.1))
			c.append(AttackStep.make("2棍!", "h_lr", 8.0, 0.08, 0.07, 0.18, 0.15, 1.4, 3.0, 180.0, false, 8.0, 0, -0.12))
			c.append(AttackStep.make("劈!", "v_down", 11.0, 0.1, 0.08, 0.22, 0.19, 1.8, 3.1, 70.0, false, 9.0, 0))
			c.append(AttackStep.make("旋!", "spin", 11.0, 0.1, 0.12, 0.24, 0.22, 1.0, 3.2, 360.0, false, 9.0, 0))
			c.append(AttackStep.make("扫堂!", "spin", 17.0, 0.12, 0.14, 0.32, 0.3, 0.8, 3.6, 360.0, true, 13.0, 0).with_fx("sweep"))
		"twin":
			c.append(AttackStep.make("1段!", "h_rl", 6.0, 0.05, 0.05, 0.14, 0.11, 1.3, 2.3, 160.0, false, 3.0, 0, 0.1))
			c.append(AttackStep.make("2段!", "h_lr", 6.0, 0.05, 0.05, 0.14, 0.11, 1.3, 2.3, 160.0, false, 3.0, 0, -0.15))
			c.append(AttackStep.make("3段!", "h_rl", 7.0, 0.05, 0.05, 0.14, 0.11, 1.3, 2.3, 160.0, false, 3.0, 0, 0.25))
			c.append(AttackStep.make("4段!", "h_lr", 7.0, 0.05, 0.05, 0.14, 0.11, 1.3, 2.3, 160.0, false, 3.0, 0, -0.25))
			c.append(AttackStep.make("旋斩!", "spin", 9.0, 0.07, 0.1, 0.18, 0.16, 1.0, 2.6, 360.0, false, 5.0, 0))
			c.append(AttackStep.make("双飞!", "spin", 14.0, 0.08, 0.12, 0.28, 0.26, 1.2, 2.9, 360.0, true, 8.0, 1))
		"hammer":
			c.append(AttackStep.make("抡!", "h_rl", 19.0, 0.2, 0.1, 0.32, 0.3, 1.4, 2.9, 170.0, true, 9.0, 0, 0.1))
			c.append(AttackStep.make("砸!", "v_down", 26.0, 0.22, 0.1, 0.36, 0.33, 1.6, 2.8, 80.0, true, 10.0, 0).with_fx("quake", 2.6))
			c.append(AttackStep.make("镇岳!", "v_down", 44.0, 0.32, 0.12, 0.5, 0.48, 1.0, 3.0, 90.0, true, 14.0, 0).with_fx("quake3", 4.2))
		"crossbow":
			c.append(AttackStep.make("射!", "shoot", 10.0, 0.07, 0.04, 0.18, 0.14, -0.4, 15.0, 30.0, false, 3.0, 0).with_fx("bolt"))
			c.append(AttackStep.make("射!", "shoot", 10.0, 0.07, 0.04, 0.18, 0.14, -0.4, 15.0, 30.0, false, 3.0, 0).with_fx("bolt"))
			c.append(AttackStep.make("射!", "shoot", 11.0, 0.07, 0.04, 0.18, 0.14, -0.4, 15.0, 30.0, false, 3.0, 0).with_fx("bolt"))
			c.append(AttackStep.make("连珠!", "shoot", 7.0, 0.12, 0.05, 0.3, 0.27, -1.2, 13.0, 50.0, true, 4.0, 0).with_fx("spread"))
		_:
			c = AttackStep.default_combo()
	return c


## 刀光颜色（[芯, 边]）：每种兵器一个色调，一眼看出拿的是什么
const TRAILS := {
	"sword": [Color(1, 1, 1), Color(0.35, 0.8, 1.0)],
	"greatsword": [Color(1.0, 0.97, 0.9), Color(0.55, 0.7, 1.0)],
	"dagger": [Color(1.0, 0.95, 1.0), Color(0.75, 0.45, 1.0)],
	"axe": [Color(1.0, 0.95, 0.9), Color(1.0, 0.5, 0.3)],
	"spear": [Color(1.0, 1.0, 0.95), Color(1.0, 0.85, 0.45)],
	"staff": [Color(0.95, 1.0, 0.95), Color(0.45, 1.0, 0.6)],
	"twin": [Color(1.0, 0.95, 0.95), Color(1.0, 0.35, 0.45)],
	"hammer": [Color(1.0, 0.95, 0.85), Color(1.0, 0.7, 0.3)],
	"crossbow": [Color(1.0, 1.0, 1.0), Color(0.6, 1.0, 0.95)],
}


static func trail(id: String) -> Array:
	return TRAILS.get(id, TRAILS["sword"])


## 兵器特性给的数值加成（机制类的在 Hero 里按 weapon_id 判断）
static func weapon_stats(id: String) -> Dictionary:
	match id:
		"sword":
			return {"dash_cd": 0.1}
		"dagger":
			return {"bleed": 1}
		"axe":
			return {"crit_dmg": 0.5}
	return {}


# ---------- 装备套装 ----------

## 同一套穿够两件、三件：stats 加到主角身上；s3 里的 set_* 键是质变效果（Hero 里实现）
const GEAR_SETS := {
	"iron": {"name": "不动", "pieces": "铁盔、锁子甲、铁靴", "color": Color(0.6, 0.75, 1.0),
		"d2": "生命 +25", "s2": {"hp": 25.0},
		"d3": "挨打时震开一圈反震（伤害 25）", "s3": {"set_iron": 1.0}},
	"oni": {"name": "鬼面", "pieces": "鬼面、鬼面铠、鬼纹胫甲", "color": Color(1.0, 0.4, 0.35),
		"d2": "伤害 +10%", "s2": {"atk": 0.1},
		"d3": "残血（低于 40%）伤害 +30%、吸血 +4%", "s3": {"set_oni": 1.0}},
	"thunder": {"name": "雷殛", "pieces": "雷纹冠、灵纹袍、雷纹靴、雷符坠", "color": Color(0.6, 0.85, 1.0),
		"d2": "会心率 +6%", "s2": {"crit": 0.06},
		"d3": "每 5 次命中引一道落雷（伤害 30）", "s3": {"set_thunder": 1.0}},
}


## 身上穿的每套各几件
static func set_counts(gear: Dictionary) -> Dictionary:
	var out := {}
	for slot: String in gear:
		var it: Dictionary = gear[slot]
		if it.is_empty() or String(it.get("slot", "")) == "weapon":
			continue
		var sid := String(ArpgData.gear(String(it["base"])).get("set", ""))
		if sid != "":
			out[sid] = int(out.get(sid, 0)) + 1
	return out


static func set_stats(gear: Dictionary) -> Dictionary:
	var st := {}
	for sp: Array in set_parts(gear):
		ArpgData.add_stats(st, sp[2])
	return st


## 每套各给了什么：[[套装 id, 件数, stats]...]（不够两件的不算）
static func set_parts(gear: Dictionary) -> Array:
	var out := []
	var n := set_counts(gear)
	for sid: String in n:
		var gs: Dictionary = GEAR_SETS[sid]
		var st := {}
		if int(n[sid]) >= 2:
			ArpgData.add_stats(st, gs["s2"])
		if int(n[sid]) >= 3:
			ArpgData.add_stats(st, gs["s3"])
		if not st.is_empty():
			out.append([sid, int(n[sid]), st])
	return out


# ---------- 道具 ----------

## 可以带着走的道具：R 用当前这种，T 换下一种。max 每种最多叠几个
const ITEM_KINDS := 3
const ITEMS := {
	"fire_flask": {"name": "火油罐", "desc": "往前扔出去，落地炸开（伤害 35），留下一滩烧敌人的火", "max": 3, "price": 30, "color": Color(1.0, 0.55, 0.2)},
	"thunder_talisman": {"name": "雷符", "desc": "九米内最近的五个敌人各挨一道落雷（伤害 40）", "max": 2, "price": 40, "color": Color(0.6, 0.85, 1.0)},
	"bind_talisman": {"name": "定身符", "desc": "七米内的敌人定住 3 秒（头目 1.2 秒）", "max": 2, "price": 40, "color": Color(1.0, 0.9, 0.5)},
	"smoke_ball": {"name": "烟丸", "desc": "原地炸开一团烟：2.5 秒无敌、移速 +30%，身边的敌人被震开", "max": 3, "price": 25, "color": Color(0.75, 0.8, 0.85)},
	"elixir": {"name": "回魂丹", "desc": "回复 35% 生命、补 50 点气力，止住身上的出血", "max": 2, "price": 45, "color": Color(0.45, 1.0, 0.6)},
	"whetstone": {"name": "磨刀石", "desc": "12 秒内伤害 +35%，每一刀都叠出血", "max": 2, "price": 35, "color": Color(1.0, 0.8, 0.5)},
	"darts": {"name": "飞镖", "desc": "扇形掷出七枚飞镖（各 9 伤害、叠 1 层出血）", "max": 3, "price": 25, "color": Color(0.85, 0.9, 1.0)},
}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func random_item(rng: RandomNumberGenerator) -> String:
	var ks := ITEMS.keys()
	return String(ks[rng.randi_range(0, ks.size() - 1)])


## 用道具：效果全在这里（hero 是用的人）。返回 true 表示用掉了
static func use_item(hero: Hero, id: String) -> bool:
	var tree := hero.get_tree()
	var p := hero.global_position
	match id:
		"fire_flask":
			var tgt := hero.auto_target(hero.facing, 9.0)
			var land := p + hero.facing * 6.0
			if tgt != null:
				land = tgt.global_position
			var lob := HeroLob.new()
			lob.hero = hero
			lob.from = hero.chest() + hero.facing * 0.4
			lob.to = Vector3(land.x, 0.0, land.z)
			hero.get_parent().add_child(lob)
		"thunder_talisman":
			var foes := []
			for f: Node in tree.get_nodes_in_group("foes"):
				var a := f as Actor
				if a != null and a.alive and a.global_position.distance_to(p) < 9.0:
					foes.append(a)
			foes.sort_custom(func(x: Actor, y: Actor) -> bool: return x.global_position.distance_to(p) < y.global_position.distance_to(p))
			if foes.is_empty():
				Feel.I.callout(hero.head_top(), "附近没有敌人", Color(0.7, 0.8, 0.9), 0.7)
				return false
			for i in range(mini(foes.size(), 5)):
				var a: Actor = foes[i]
				hero.get_tree().create_timer(0.08 * i).timeout.connect(func() -> void:
					if is_instance_valid(a) and is_instance_valid(hero):
						lightning(hero, a.global_position, 40.0 * hero.dmg_mult, 0.6))
			Feel.I.callout(hero.head_top(), "雷符!", Color(0.6, 0.85, 1.0), 1.0)
		"bind_talisman":
			var n := 0
			for f: Node in tree.get_nodes_in_group("foes"):
				var a := f as Actor
				if a == null or not a.alive or a.global_position.distance_to(p) > 7.0:
					continue
				var boss := bool(a.get("is_boss"))
				a.freeze(1.2 if boss else 3.0)
				if a.rig != null:
					a.rig.flash(0.3, Color(1.0, 0.9, 0.5))
				Vfx.I.sheet("stunned", a.head_top() - Vector3(0, 0.3, 0), 1.0, Color(1.0, 0.95, 0.6), 1.6, false, 1.2 if boss else 3.0)
				n += 1
			Vfx.I.shock_ring(p, Color(1.0, 0.9, 0.5), 0.4, 7.0, 0.5)
			Vfx.I.ground(p, "lm_circle_a", Color(1.0, 0.9, 0.5, 0.6), 3.0, 14.0, 0.6, true)
			Game.sfx("art", -2.0)
			Feel.I.callout(hero.head_top(), "定!" if n > 0 else "定身符（没定住谁）", Color(1.0, 0.9, 0.5), 1.0)
		"smoke_ball":
			hero.iframes = maxf(hero.iframes, 2.5)
			hero.buff("smoke", 2.5)
			for i in range(6 if Vfx.I.lod > 0 else 3):
				var a := TAU * i / 6.0
				Vfx.I.dust(p + Vector3(cos(a), 0, sin(a)) * 1.2, 2.2, Color(0.6, 0.62, 0.66, 0.6))
			Vfx.I.dust(p, 3.0, Color(0.7, 0.72, 0.75, 0.7))
			for f: Node in tree.get_nodes_in_group("foes"):
				var a := f as Actor
				if a == null or not a.alive or a.global_position.distance_to(p) > 4.0:
					continue
				var d := a.global_position - p
				d.y = 0
				a.knock = d.normalized() * 9.0
			Game.sfx("dodge", 0.0)
			Feel.I.callout(hero.head_top(), "烟遁", Color(0.8, 0.85, 0.9), 0.9)
		"elixir":
			var heal := hero.max_hp * 0.35
			hero.hp = minf(hero.hp + heal, hero.max_hp)
			hero.bleed = 0
			hero.gain_energy(50.0 / maxf(hero.energy_mult, 0.01))
			Game.sfx("drink", -2.0)
			Vfx.I.pop(hero.chest(), "magic_03", Color(0.4, 1.0, 0.6), 0.6, 3.0, 0.6)
			Vfx.I.shock_ring(p, Color(0.5, 1.0, 0.7), 0.3, 3.0, 0.4)
			Feel.I.number(hero.head_top(), "+%d" % int(heal), Color(0.5, 1.0, 0.6), 1.0)
		"whetstone":
			hero.buff("whet", 12.0)
			Vfx.I.sheet("charge-up", hero.chest() - Vector3(0, 0.6, 0), 1.6, Color(1.0, 0.8, 0.5), 2.0)
			Game.sfx("art", -4.0)
			Feel.I.callout(hero.head_top(), "刃利 12 秒", Color(1.0, 0.8, 0.5), 1.0)
		"darts":
			var dir := hero.facing
			var tgt := hero.auto_target(dir, 12.0)
			if tgt != null:
				dir = tgt.global_position - p
				dir.y = 0
				dir = dir.normalized()
			for i in range(7):
				var b := HeroBolt.new()
				b.hero = hero
				b.dir = dir.rotated(Vector3.UP, deg_to_rad(-30.0 + 10.0 * i))
				b.damage = 9.0 * hero.dmg_mult
				b.bleed = 1
				b.model = "dagger"
				b.color = Color(0.85, 0.9, 1.0)
				b.life = 0.7
				hero.get_parent().add_child(b)
				b.global_position = hero.chest() + b.dir * 0.5
			Game.sfx("slash", -2.0, 0.1)
		_:
			return false
	return true


## 落雷：天上劈下来一道，打中点附近（1.6 米）的敌人，麻痹 stun 秒
static func lightning(hero: Hero, at: Vector3, dmg: float, stun: float = 0.4) -> void:
	var g := Vector3(at.x, 0.0, at.z)
	if Vfx.I != null:
		Vfx.I.beam(g + Vector3(0.6, 9.0, -0.4), g + Vector3(0, 0.1, 0), 0.5, 0.18)
		Vfx.I.impact_flash(g + Vector3(0, 0.8, 0), 2.4, Color(0.6, 0.85, 1.0))
		Vfx.I.shock_ring(g, Color(0.6, 0.85, 1.0), 0.3, 3.2, 0.3)
		Vfx.I.streaks(g + Vector3(0, 0.6, 0), Vector3.UP, Color(0.7, 0.9, 1.0), 5, 2.0, 0.18, PI, 0.15)
	Game.sfx("boom", -8.0, 0.15)
	if not is_instance_valid(hero):
		return
	for f: Node in hero.get_tree().get_nodes_in_group("foes"):
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := a.global_position - g
		d.y = 0
		if d.length() > 1.6 + a.radius:
			continue
		var info := HitInfo.make(hero, a, dmg * randf_range(0.95, 1.08), HitInfo.Weight.HEAVY)
		info.attacker = null
		info.dir = d.normalized() if d.length() > 0.1 else hero.facing
		info.knock = 3.0
		info.stun = stun
		Feel.I.on_hit(info)


# ---------- 皮肤 ----------

## model 体素模型；swap 换掉游侠兜帽披风的颜色（只对 rogue 有用）；rim 描边光；trail 刀光边色（null 用兵器的）；
## k 体型缩放；unlock：free / jade 魂玉买 / ach 成就数 / clears 登顶次数 / kills 累计斩敌 / act2 第二幕通关
const SKINS := [
	{"id": "qing", "name": "青衫", "desc": "最早那身衣服，洗得发白", "model": "rogue", "swap": Color(0.24, 0.42, 0.72), "rim": Color(0.45, 0.95, 1.0), "unlock": {"free": true}},
	{"id": "chi", "name": "赤焰", "desc": "红得像要烧起来的披风", "model": "rogue", "swap": Color(0.7, 0.16, 0.12), "rim": Color(1.0, 0.5, 0.3), "unlock": {"jade": 25}},
	{"id": "mo", "name": "墨夜", "desc": "黑里透紫，夜里看不见人", "model": "rogue", "swap": Color(0.13, 0.1, 0.18), "rim": Color(0.72, 0.5, 1.0), "unlock": {"jade": 40}},
	{"id": "shuang", "name": "白霜", "desc": "一身素白，刀光也冷", "model": "rogue", "swap": Color(0.82, 0.86, 0.9), "rim": Color(0.75, 0.92, 1.0), "unlock": {"ach": 10}},
	{"id": "knight", "name": "铁甲骑士", "desc": "从柳江远那里学来的板甲", "model": "knight", "rim": Color(1.0, 0.85, 0.5), "unlock": {"clears": 1}},
	{"id": "barbarian", "name": "北地蛮勇", "desc": "一身兽皮，砍过一千个敌人才穿得上", "model": "barbarian", "rim": Color(1.0, 0.55, 0.35), "unlock": {"kills": 1000}},
	{"id": "mage", "name": "云游术士", "desc": "宽袍大袖，打起来却不含糊", "model": "mage", "k": 1.3, "rim": Color(0.72, 0.6, 1.0), "unlock": {"jade": 60}},
	{"id": "jin", "name": "金身", "desc": "第二幕走到底的人，才有这一身金", "model": "rogue", "swap": Color(1.0, 0.6, 0.14), "rim": Color(1.0, 0.85, 0.4), "glow": Color(0.08, 0.05, 0.0), "unlock": {"act2": true}},
]


static func skin(id: String) -> Dictionary:
	for s: Dictionary in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


static func current_skin() -> Dictionary:
	return skin(String(Game.save.get("arpg_skin", "qing")))


static func skin_owned(id: String) -> bool:
	var sk := skin(id)
	var u: Dictionary = sk["unlock"]
	if u.has("free"):
		return true
	if u.has("jade"):
		return (Game.save.get("arpg_skins", []) as Array).has(id)
	return skin_why_not(id) == ""


## 还差什么才能穿（"" 表示可以）
static func skin_why_not(id: String) -> String:
	var u: Dictionary = skin(id)["unlock"]
	if u.has("free"):
		return ""
	if u.has("jade"):
		if (Game.save.get("arpg_skins", []) as Array).has(id):
			return ""
		return "%d 魂玉" % int(u["jade"])
	if u.has("ach"):
		var n := ArpgAch.count()
		return "" if n >= int(u["ach"]) else "成就 %d / %d" % [n, int(u["ach"])]
	if u.has("clears"):
		var done := int(Game.save.get("clears", 0)) >= int(u["clears"]) or not (Game.save.get("arpg_endings", {}) as Dictionary).is_empty()
		return "" if done else "打通第一幕"
	if u.has("kills"):
		var k := int((Game.save.get("ach_stat", {}) as Dictionary).get("kills", 0))
		return "" if k >= int(u["kills"]) else "累计斩敌 %d / %d" % [k, int(u["kills"])]
	if u.has("act2"):
		var ends: Dictionary = Game.save.get("arpg_act2_endings", {})
		return "" if not ends.is_empty() else "打通第二幕"
	return "未解锁"
