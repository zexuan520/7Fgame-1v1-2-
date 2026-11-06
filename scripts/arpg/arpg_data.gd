class_name ArpgData
extends RefCounted
## 斜俯视版的数据：兵器、护甲、护符、心法（清房三选一 / 商人卖）、天赋树、奇遇。
## 所有加成都写成 stats 表里的数值，Hero.apply_stats() 统一读：
##   atk 伤害倍率加成  crit 会心率  crit_dmg 会心伤害  hp 生命上限  gourds 药葫芦  gourd_heal 回复量
##   dash_cd / finish_cd 冷却缩短比例  energy 气力获取  bleed 出血额外层数  bleed_dmg 出血伤害
##   lifesteal 吸血  move 移速  dmg_taken 受伤倍率  iframes 翻滚无敌加时  beam 光束斩伤害  finish 终结技伤害
##   insight 开局天赋点  xp 悟道获取加成  sk_<分支> 技能分支级数  duo_<id> 双修（见 ArpgSkills）
##   coin 铜钱加成  jade 魂玉加成  discount 商人折扣  keep 死亡魂玉带回加成  start_coins 开局铜钱  revive 倒下再起
##   execute 对残血敌人增伤  roll_cd 翻滚减突进冷却（秒）  beam_heal 光束每照到一个敌人回血  fire_dmg 火团伤害  kill_fire 斩杀爆燃几率

## 兵器：每种兵器有自己的一套连招（ArpgArms.combo）、专属特性（trait，ArpgArms.TRAITS 说明）和人偶手里的模型。
## dmg 乘到所有招式上（突进、光束、终结技也算），连招本身的伤害写在连招里。trail 是刀光颜色。
const WEAPONS := {
	"sword": {"style": "四段，快慢适中", "name": "游侠剑", "desc": "四段连招，快慢适中。第四段回旋斩叠出血", "trait": "均衡：突进斩冷却 -10%", "model": "sword", "len": 34.0, "dmg": 1.0, "price": 0},
	"greatsword": {"style": "三段，慢而重，跳劈震地", "name": "斩马大剑", "desc": "三段，慢而重，范围大；第三段跳劈震地", "trait": "霸体：出刀时不会被打断，受伤 -15%", "model": "sword2", "len": 46.0, "dmg": 1.1, "price": 30},
	"dagger": {"style": "五段，极快", "name": "双刃短匕", "desc": "五段，极快，攻击范围小；收势影刺叠两层出血", "trait": "背刺：从背后砍必定会心，出血 +1", "model": "dagger", "len": 22.0, "dmg": 0.9, "price": 25},
	"axe": {"style": "三段，下劈震地", "name": "裂骨斧", "desc": "三段，第三段下劈震地", "trait": "碎骨：会心伤害 +50%", "model": "axe2", "len": 38.0, "dmg": 1.0, "price": 25},
	"spear": {"style": "四段，直刺够得远", "name": "破阵枪", "desc": "四段，前两段直刺够得远，第三段横扫，收势一枪扎穿一整排", "trait": "枪尖：2.4 米外的敌人伤害 +25%", "model": "spear", "len": 52.0, "dmg": 1.0, "price": 35},
	"staff": {"style": "五段，大开大合", "name": "齐眉棍", "desc": "五段，大开大合，把敌人打飞；收势扫堂把一圈人扫晕", "trait": "棍扫：每一棍多回 3 点气力，击退更远", "model": "staff", "len": 44.0, "dmg": 1.0, "price": 30},
	"twin": {"style": "六段，双手轮着砍", "name": "鸳鸯双刀", "desc": "六段，两手轮着砍，最后两段旋身连斩", "trait": "刀势：砍中叠层，每层伤害 +4%（最多 10 层）", "model": "twin_blade", "offhand": "twin_blade", "len": 28.0, "dmg": 0.95, "price": 40},
	"hammer": {"style": "三段，最慢最重", "name": "镇岳锤", "desc": "三段，最慢最重；后两锤砸地，第三锤震出三圈地波", "trait": "震荡：被砸中的敌人晕得更久（×1.8）", "model": "hammer", "len": 44.0, "dmg": 1.1, "price": 45},
	"crossbow": {"style": "远程，四段连射", "name": "连弩", "desc": "远程：三发连射，第四段扇形连珠五箭；射击时略往后退", "trait": "游射：翻滚后的第一箭必定会心，弩箭穿透两个敌人", "model": "crossbow", "len": 30.0, "dmg": 1.12, "price": 45, "ranged": true},
}

## 装备部位：护甲、头冠、靴子、护符（护符可以戴两件，第二件要在兵器架解锁“双佩”）。
## stats 里除了通用属性，还有装备专属的机制键（Hero.apply_stats 读）：
##   thorns 近身挨打反弹伤害比例  hurt_energy 挨打回气  rage 生命低于一半时伤害加成  roll_bolt 翻滚落地放雷的伤害
##   roll_far 翻滚距离  kill_heal 斩杀回血  crit_bolt 会心时落雷的几率  fire_proc 命中炸火的几率
## set 是套装（ArpgArms.GEAR_SETS），同一套穿够两件、三件各有效果。
const ARMORS := [
	{"id": "leather", "name": "皮甲", "desc": "生命 +20", "stats": {"hp": 20.0}, "price": 30},
	{"id": "chain", "name": "锁子甲", "desc": "受伤 -12%", "stats": {"dmg_taken": -0.12}, "price": 45, "set": "iron"},
	{"id": "shadow_cloak", "name": "影纱斗篷", "desc": "翻滚无敌 +0.08 秒、移速 +6%", "stats": {"iframes": 0.08, "move": 0.06}, "price": 40},
	{"id": "oni_plate", "name": "鬼面铠", "desc": "生命 +35、受伤 -8%", "stats": {"hp": 35.0, "dmg_taken": -0.08}, "price": 70, "set": "oni"},
	{"id": "thorn_mail", "name": "荆棘甲", "desc": "受伤 -6%，近身挨打时反弹 60% 伤害", "stats": {"dmg_taken": -0.06, "thorns": 0.6}, "price": 55},
	{"id": "spirit_robe", "name": "灵纹袍", "desc": "气力获取 +15%，挨打时回 15 点气", "stats": {"energy": 0.15, "hurt_energy": 15.0}, "price": 45, "set": "thunder"},
]

const HELMS := [
	{"id": "iron_helm", "name": "铁盔", "desc": "生命 +15、受伤 -4%", "stats": {"hp": 15.0, "dmg_taken": -0.04}, "price": 35, "set": "iron"},
	{"id": "oni_mask", "name": "鬼面", "desc": "会心率 +6%", "stats": {"crit": 0.06}, "price": 40, "set": "oni"},
	{"id": "straw_hat", "name": "斗笠", "desc": "移速 +5%、翻滚无敌 +0.04 秒", "stats": {"move": 0.05, "iframes": 0.04}, "price": 30},
	{"id": "wolf_helm", "name": "狼首盔", "desc": "生命低于一半时伤害 +20%", "stats": {"rage": 0.2}, "price": 45},
	{"id": "thunder_crown", "name": "雷纹冠", "desc": "光束斩伤害 +25%、气力获取 +10%", "stats": {"beam": 0.25, "energy": 0.1}, "price": 45, "set": "thunder"},
]

const BOOTS := [
	{"id": "sandals", "name": "草鞋", "desc": "移速 +8%", "stats": {"move": 0.08}, "price": 25},
	{"id": "iron_boots", "name": "铁靴", "desc": "受伤 -5%、生命 +10", "stats": {"dmg_taken": -0.05, "hp": 10.0}, "price": 35, "set": "iron"},
	{"id": "thunder_boots", "name": "雷纹靴", "desc": "翻滚落地时放出一圈雷（伤害 12）", "stats": {"roll_bolt": 12.0}, "price": 45, "set": "thunder"},
	{"id": "wind_boots", "name": "风行履", "desc": "突进斩冷却 -15%、翻滚距离 +20%", "stats": {"dash_cd": 0.15, "roll_far": 0.2}, "price": 40},
	{"id": "oni_greaves", "name": "鬼纹胫甲", "desc": "伤害 +6%、移速 +3%", "stats": {"atk": 0.06, "move": 0.03}, "price": 40, "set": "oni"},
]

const CHARMS := [
	{"id": "fang", "name": "狼牙坠", "desc": "会心率 +8%", "stats": {"crit": 0.08}, "price": 35},
	{"id": "blood_bead", "name": "血珀珠", "desc": "命中回复伤害的 3% 生命", "stats": {"lifesteal": 0.03}, "price": 50},
	{"id": "moon_mirror", "name": "月镜", "desc": "气力获取 +35%", "stats": {"energy": 0.35}, "price": 40},
	{"id": "wind_bell", "name": "风铃", "desc": "突进斩冷却 -25%", "stats": {"dash_cd": 0.25}, "price": 40},
	{"id": "coin_frog", "name": "金蟾", "desc": "铜钱 +40%", "stats": {"coin": 0.4}, "price": 30},
	{"id": "red_thread", "name": "赤缘绳", "desc": "出血伤害 +40%", "stats": {"bleed_dmg": 0.4}, "price": 45},
	{"id": "bone_bell", "name": "骨铃", "desc": "每斩杀一个敌人回 3 点生命", "stats": {"kill_heal": 3.0}, "price": 40},
	{"id": "thunder_seal", "name": "雷符坠", "desc": "会心率 +4%，会心时 25% 机会引一道落雷", "stats": {"crit": 0.04, "crit_bolt": 0.25}, "price": 50, "set": "thunder"},
	{"id": "jade_turtle", "name": "玄龟甲", "desc": "药葫芦 +1", "stats": {"gourds": 1}, "price": 45},
	{"id": "fire_jade", "name": "火纹玉", "desc": "命中时 12% 机会在敌人身上炸开一团火", "stats": {"fire_proc": 0.12}, "price": 45},
]

## 部位 → 装备表、中文名
const GEAR_SLOTS := ["armor", "helm", "boots", "charm"]
const SLOT_NAMES := {"armor": "护甲", "helm": "头冠", "boots": "靴子", "charm": "护符", "charm2": "护符·二"}


static func gear_pool(slot: String) -> Array:
	match slot:
		"armor":
			return ARMORS
		"helm":
			return HELMS
		"boots":
			return BOOTS
	return CHARMS

## 心法：清房后三选一，商人那里也卖；同一种可以叠
const BOONS := [
	{"id": "edge", "name": "利刃", "desc": "伤害 +12%", "stats": {"atk": 0.12}, "school": "修罗"},
	{"id": "keen", "name": "锐眼", "desc": "会心率 +7%", "stats": {"crit": 0.07}, "school": "修罗"},
	{"id": "deep_cut", "name": "深创", "desc": "每次出血多叠 1 层", "stats": {"bleed": 1}, "school": "血"},
	{"id": "blood_bloom", "name": "血华", "desc": "终结技伤害 +35%", "stats": {"finish": 0.35}, "school": "血"},
	{"id": "hemorrhage", "name": "溃血", "desc": "出血伤害 +35%", "stats": {"bleed_dmg": 0.35}, "school": "血"},
	{"id": "gale", "name": "疾风", "desc": "突进斩冷却 -20%", "stats": {"dash_cd": 0.2}, "school": "风"},
	{"id": "swift", "name": "轻身", "desc": "移速 +8%、翻滚无敌 +0.05 秒", "stats": {"move": 0.08, "iframes": 0.05}, "school": "风"},
	{"id": "moonlight", "name": "月华", "desc": "气力获取 +30%", "stats": {"energy": 0.3}, "school": "光"},
	{"id": "radiance", "name": "辉光", "desc": "光束斩伤害 +40%", "stats": {"beam": 0.4}, "school": "光"},
	{"id": "vigor", "name": "壮骨", "desc": "生命上限 +25 并回满这部分", "stats": {"hp": 25.0}, "school": "守"},
	{"id": "iron", "name": "铁衣", "desc": "受伤 -10%", "stats": {"dmg_taken": -0.1}, "school": "守"},
	{"id": "leech", "name": "饮血", "desc": "命中回复伤害的 2% 生命", "stats": {"lifesteal": 0.02}, "school": "血"},
	{"id": "finisher_cd", "name": "断念", "desc": "终结技冷却 -25%", "stats": {"finish_cd": 0.25}, "school": "血"},
	{"id": "gourd", "name": "药缘", "desc": "药葫芦 +1", "stats": {"gourds": 1}, "school": "守"},
	# 老流派各添一个带机制的
	{"id": "behead", "name": "斩首", "desc": "对生命不到三成的敌人伤害 +35%", "stats": {"execute": 0.35}, "school": "修罗"},
	{"id": "bloodlust", "name": "嗜杀", "desc": "每斩杀一个敌人回 4 点生命", "stats": {"kill_heal": 4.0}, "school": "血"},
	{"id": "chase_wind", "name": "逐风", "desc": "每次翻滚，突进斩冷却 -0.5 秒", "stats": {"roll_cd": 0.5}, "school": "风"},
	{"id": "lumen", "name": "流明", "desc": "光束斩每照到一个敌人，回 3 点生命", "stats": {"beam_heal": 3.0}, "school": "光"},
	{"id": "recoil", "name": "反震", "desc": "受伤 -4%，近身挨打时反弹 40% 伤害", "stats": {"dmg_taken": -0.04, "thorns": 0.4}, "school": "守"},
	# 雷：会心、翻滚引雷
	{"id": "thunder_call", "name": "引雷", "desc": "会心率 +3%，会心时 22% 机会引一道落雷", "stats": {"crit": 0.03, "crit_bolt": 0.22}, "school": "雷"},
	{"id": "thunder_step", "name": "雷步", "desc": "翻滚落地放出一圈雷（伤害 14）", "stats": {"roll_bolt": 14.0}, "school": "雷"},
	{"id": "thunder_heart", "name": "雷心", "desc": "会心伤害 +30%、气力获取 +10%", "stats": {"crit_dmg": 0.3, "energy": 0.1}, "school": "雷"},
	# 焰：命中炸火、斩杀爆燃
	{"id": "ember", "name": "火种", "desc": "命中时 10% 机会在敌人身上炸开一团火", "stats": {"fire_proc": 0.1}, "school": "焰"},
	{"id": "blaze", "name": "烈焰", "desc": "火团伤害 +60%、范围更大", "stats": {"fire_dmg": 0.6}, "school": "焰"},
	{"id": "pyre", "name": "焚身", "desc": "斩杀敌人时 35% 机会让它爆燃", "stats": {"kill_fire": 0.35}, "school": "焰"},
	# 专属心法：打赢隐藏头目残影才会出现（hidden，见 ArpgState.roll_boons）
	{"id": "afterimage", "name": "残影", "desc": "伤害 +10%、会心率 +5%、移速 +5%", "stats": {"atk": 0.1, "crit": 0.05, "move": 0.05}, "school": "风", "hidden": true},
	# 第二幕：井中人身上取下的灯片（只从战后选择拿到，不进心法池）
	# 终章：打倒烛王以后进心法池
	{"id": "eighth_lamp", "name": "第八灯", "desc": "伤害 +15%、生命 +20，斩杀时 25% 机会让敌人爆燃", "stats": {"atk": 0.15, "hp": 20.0, "kill_fire": 0.25}, "school": "焰", "hidden": true, "unlock": "arpg_king"},
	{"id": "lamp_shard", "name": "灯片", "desc": "伤害 +18%、气力获取 +25%，代价是受伤 +8%", "stats": {"atk": 0.18, "energy": 0.25, "taken_extra": 0.08}, "school": "光", "hidden": true, "unlock": "-"},
]

## 流派大成：同一流派的心法拿够 SET_NEED 个（同一个叠两次也算），触发一个质变效果
const SET_NEED := 3
const SETS := {
	"修罗": {"id": "set_shura", "name": "修罗场", "desc": "会心一击的余劲会斩到身边 2.8 米内的其他敌人（40% 伤害）"},
	"血": {"id": "set_blood", "name": "血涌", "desc": "敌人出血叠到 6 层时自己炸开，伤到周围的敌人"},
	"风": {"id": "set_wind", "name": "御风", "desc": "翻滚后 1.2 秒内的下一刀必定会心，每次翻滚突进斩冷却 -0.8 秒"},
	"光": {"id": "set_light", "name": "天光", "desc": "光束斩返还 40% 气力，命中的敌人叠 3 层出血"},
	"守": {"id": "set_guard", "name": "金身", "desc": "每 10 秒凝一层金光，挡掉下一次伤害"},
	"雷": {"id": "set_storm", "name": "天雷", "desc": "落雷会跳到附近两个敌人身上（六成伤害），被劈中的晕得更久"},
	"焰": {"id": "set_pyre", "name": "燎原", "desc": "火团炸完留下火种，一秒后在原地再炸一次（七成伤害）"},
}


## 这些心法里每个流派各有几个
static func school_counts(boons: Array) -> Dictionary:
	var out := {}
	for b in boons:
		var sc := String(boon(String(b)).get("school", ""))
		if sc != "":
			out[sc] = int(out.get(sc, 0)) + 1
	return out


const SCHOOL_COLORS := {"修罗": Color(1.0, 0.45, 0.35), "血": Color(0.95, 0.2, 0.3), "风": Color(0.45, 1.0, 0.8), "光": Color(1.0, 0.9, 0.5), "守": Color(0.5, 0.75, 1.0),
	"雷": Color(0.68, 0.72, 1.0), "焰": Color(1.0, 0.58, 0.2)}

## 天赋：三棵树（修罗攻 / 不动守 / 行者运），每棵三层，往这棵树里投够点数解锁下一层；用魂玉点，存档里永久保留
const TALENT_TREES := [
	{"id": "shura", "name": "修罗", "role": "攻", "color": Color(0.88, 0.35, 0.28), "tiers": [
		[{"id": "t_sharpen", "name": "磨刃", "desc": "伤害 +5%", "max": 3, "stats": {"atk": 0.05}},
		 {"id": "t_keen", "name": "鹰目", "desc": "会心率 +3%", "max": 3, "stats": {"crit": 0.03}}],
		[{"id": "t_bleed", "name": "血契", "desc": "出血伤害 +15%", "max": 2, "stats": {"bleed_dmg": 0.15}},
		 {"id": "t_vital", "name": "会心", "desc": "会心伤害 +25%", "max": 2, "stats": {"crit_dmg": 0.25}}],
		[{"id": "t_asura", "name": "修罗道", "desc": "终结技伤害 +50%", "max": 1, "stats": {"finish": 0.5}}],
	]},
	{"id": "fudo", "name": "不动", "role": "守", "color": Color(0.42, 0.66, 0.94), "tiers": [
		[{"id": "t_vigor", "name": "体魄", "desc": "生命 +15", "max": 3, "stats": {"hp": 15.0}},
		 {"id": "t_hide", "name": "坚甲", "desc": "受伤 -4%", "max": 3, "stats": {"dmg_taken": -0.04}}],
		[{"id": "t_gourd", "name": "药缘", "desc": "药葫芦 +1", "max": 2, "stats": {"gourds": 1}},
		 {"id": "t_elixir", "name": "灵药", "desc": "药葫芦回复 +10%", "max": 2, "stats": {"gourd_heal": 0.1}}],
		[{"id": "t_undying", "name": "不死身", "desc": "每局倒下一次，以 50% 生命站起", "max": 1, "stats": {"revive": 1}}],
	]},
	{"id": "gyo", "name": "行者", "role": "运", "color": Color(0.44, 0.76, 0.54), "tiers": [
		[{"id": "t_purse", "name": "盘缠", "desc": "开局铜钱 +15", "max": 3, "stats": {"start_coins": 15}},
		 {"id": "t_stride", "name": "疾行", "desc": "移速 +4%、突进冷却 -5%", "max": 2, "stats": {"move": 0.04, "dash_cd": 0.05}}],
		[{"id": "t_haggle", "name": "识货", "desc": "商人价格 -10%", "max": 2, "stats": {"discount": 0.1}},
		 {"id": "t_spirit", "name": "聚灵", "desc": "魂玉获取 +15%", "max": 2, "stats": {"jade": 0.15}},
		 {"id": "t_insight", "name": "慧根", "desc": "每局出发就有 1 个天赋点、悟道 +10%", "max": 2, "stats": {"insight": 1, "xp": 0.1}}],
		[{"id": "t_homeward", "name": "归途", "desc": "身死时魂玉带回 60% → 85%", "max": 1, "stats": {"keep": 0.25}}],
	]},
]
const TALENT_COSTS := [3, 6, 12]
const TALENT_UNLOCK := [0, 3, 5]

## 奇遇：选项 [文字, 效果]；效果 hp（按比例）、coins、boon（随机一个心法）、heal（按比例）、gourd_refill
const EVENTS := [
	{"id": "blood_altar", "name": "血祭坛", "text": "石台上刻满古老的血纹，掌心贴上去会被吸走一些血。",
		"options": [["献血（失去 20% 生命，得一个心法）", {"hp": -0.2, "boon": 1}], ["离开", {}]]},
	{"id": "gambler", "name": "赌鬼", "text": "“赌一把？赢了心法归你，输了铜钱归我。”",
		"options": [["押 25 铜钱（一半机会得两个心法）", {"coins": -25, "gamble": 1}], ["离开", {}]]},
	{"id": "hermit", "name": "隐士的茶", "text": "林中小屋里有个老人在煮茶，请你坐下歇一歇。",
		"options": [["喝茶（回复 40% 生命）", {"heal": 0.4}], ["请教（得一个心法）", {"boon": 1}]]},
]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["sword"])


static func boon(id: String) -> Dictionary:
	for b: Dictionary in BOONS:
		if b["id"] == id:
			return b
	return {}


static func gear(id: String) -> Dictionary:
	for slot: String in GEAR_SLOTS:
		for g: Dictionary in gear_pool(slot):
			if g["id"] == id:
				return g.merged({"slot": slot})
	return {}


static func talent_node(id: String) -> Dictionary:
	for t: Dictionary in TALENT_TREES:
		for tier: Array in t["tiers"]:
			for n: Dictionary in tier:
				if n["id"] == id:
					return n
	return {}


static func talent_rank(id: String) -> int:
	return int((Game.save["talents"] as Dictionary).get(id, 0))


static func talent_spent_in(tree: Dictionary) -> int:
	var n := 0
	for tier: Array in tree["tiers"]:
		for nd: Dictionary in tier:
			n += talent_rank(nd["id"])
	return n


## 能不能再点一级："" 表示可以，否则是原因
static func talent_why_not(tree_i: int, tier_i: int, node_i: int) -> String:
	var t: Dictionary = TALENT_TREES[tree_i]
	var nd: Dictionary = t["tiers"][tier_i][node_i]
	if talent_rank(nd["id"]) >= int(nd["max"]):
		return "已满"
	if talent_spent_in(t) < int(TALENT_UNLOCK[tier_i]):
		return "%s投入 %d 点后解锁" % [t["name"], TALENT_UNLOCK[tier_i]]
	if int(Game.save["jade"]) < int(TALENT_COSTS[tier_i]):
		return "魂玉不够"
	return ""


static func talent_stats() -> Dictionary:
	var st := {}
	for t: Dictionary in TALENT_TREES:
		for tier: Array in t["tiers"]:
			for nd: Dictionary in tier:
				var r := talent_rank(nd["id"])
				if r > 0:
					add_stats(st, nd["stats"], r)
	add_stats(st, ArpgSecrets.keep_stats())   # 信物（隐藏机制拿到的小东西，永久生效）
	return st


static func add_stats(into: Dictionary, add: Dictionary, times: int = 1) -> void:
	for k: String in add:
		into[k] = float(into.get(k, 0.0)) + float(add[k]) * times


static func stat(st: Dictionary, k: String) -> float:
	return float(st.get(k, 0.0))
