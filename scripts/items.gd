class_name Items
extends RefCounted
## 副武器（忍具）和道具（设计文档第 6 节“副武器”、第 9 节“道具与消耗品”）。
##
## 副武器：消耗纸人，按副武器键放（按住下再按换一种）。飞镖一开始就有，别的在铁铺用魂玉解锁。
##   纸人每局开局 PAPER_START 个，杂兵有几率掉一个、精英和头目掉几个，商人也卖。
## 道具：快捷栏 4 格，每格最多叠 STACK 个，按道具键用（按住下再按换一格）。用的时候有 0.5 秒前摇，被打中这一下就白用了。
##   商人卖、宝箱里有。只在这一局有效。
##
## 加新副武器：SUBS 里加一条，再在 Player 的 _tool_<id>() 里写它做什么。
## 加新道具：ITEMS 里加一条，再在 Player._use_item_effect() 里写它做什么。

const PAPER_START := 10
const PAPER_MAX := 20
const SLOTS := 4
const STACK := 3
const USE_TIME := 0.5                 # 用道具的前摇
const STARTER_SUB := "dart"

## 副武器：name、short 两字简称、paper 消耗纸人、unlock 铁铺解锁价（0 = 一开始就有）、desc
const SUBS := {
	"dart": {"name": "飞镖", "short": "飞镖", "paper": 1, "unlock": 0, "color": Color("b8c0cc"),
		"desc": "扔出去打中空中的敌人（跳起来、扑过来的）会把它打下来",
		"dmg": 8.0, "posture": 8.0, "speed": 520.0},
	"cracker": {"name": "爆竹", "short": "爆竹", "paper": 2, "unlock": 30, "color": Color("e05a3a"),
		"desc": "身前炸开一团：野兽（野狗）受惊僵直很久，别的敌人踉跄一下",
		"dmg": 10.0, "posture": 15.0, "size": Vector2(110, 50), "beast_stun": 1.6, "stun": 0.35},
	"hook": {"name": "钩索", "short": "钩索", "paper": 1, "unlock": 40, "color": Color("a08a6a"),
		"desc": "钩住前面的敌人，一下拉到他跟前；前面没人就钩住高处往上荡",
		"range": 260.0, "zip": 720.0},
	"smoke": {"name": "烟幕弹", "short": "烟幕", "paper": 2, "unlock": 40, "color": Color("9aa0a8"),
		"desc": "3 秒内敌人看不见你；这时砍出的第一刀是背刺：伤害翻倍、破格挡",
		"time": 3.0, "backstab": 1.0},
	"flame": {"name": "焰筒", "short": "焰筒", "paper": 3, "unlock": 50, "color": Color("f09a3a"),
		"desc": "往前喷火，烧四下；对妖物伤害翻倍",
		"dmg": 9.0, "posture": 6.0, "ticks": 4, "time": 0.6, "size": Vector2(86, 36)},
}

## 道具：name、short、desc、price 商人卖价；rare 的商人只是偶尔摆（每局最多买一张）
const ITEMS := {
	"calm": {"name": "静心丹", "short": "静心", "price": 25, "color": Color("6aa8f0"),
		"desc": "10 秒内架势不涨", "time": 10.0},
	"rage": {"name": "怒火散", "short": "怒火", "price": 25, "color": Color("e05a48"),
		"desc": "15 秒内攻击 +25%", "time": 15.0, "atk": 0.25},
	"stone": {"name": "重铸石", "short": "重铸", "price": 30, "color": Color("8a8a96"),
		"desc": "重抽身上武器的词条（凡品武器就重抽最好的那件）"},
	"return": {"name": "归庙符", "short": "归庙", "price": 60, "rare": true, "color": Color("e0c050"),
		"desc": "清完敌人时用：立刻回城，魂玉全部带回"},
}


static func sub(id: String) -> Dictionary:
	return SUBS[id]


static func item(id: String) -> Dictionary:
	return ITEMS[id]


## 这一局能用的副武器（飞镖 + 铁铺解锁过的）
static func unlocked_subs() -> Array:
	var out := []
	var have: Array = Game.save["hub"].get("subs", [])
	for id: String in SUBS:
		if int(SUBS[id]["unlock"]) == 0 or have.has(id):
			out.append(id)
	return out


## 往快捷栏里放一个道具；放不下返回 false
static func add_to(bar: Array, id: String) -> bool:
	for slot: Dictionary in bar:
		if slot["id"] == id:
			if int(slot["n"]) >= STACK:
				return false
			slot["n"] = int(slot["n"]) + 1
			return true
	if bar.size() >= SLOTS:
		return false
	bar.append({"id": id, "n": 1})
	return true


## 随机一个道具（宝箱、精英掉的；归庙符不会随机出来）
static func roll(rng: RandomNumberGenerator) -> String:
	var ids := []
	for id: String in ITEMS:
		if not ITEMS[id].get("rare", false):
			ids.append(id)
	return ids[rng.randi_range(0, ids.size() - 1)]


## 一个玩家的忍具和道具：{"subs": 能用的副武器, "sub": 选中第几个, "paper": 纸人, "bar": 道具栏, "bar_i": 选中第几格}
## practice 为 true 时（练武场）副武器全给、纸人用不完
static func new_kit(practice: bool = false) -> Dictionary:
	return {"subs": SUBS.keys() if practice else unlocked_subs(), "sub": 0,
		"paper": 99 if practice else PAPER_START, "bar": [], "bar_i": 0}

