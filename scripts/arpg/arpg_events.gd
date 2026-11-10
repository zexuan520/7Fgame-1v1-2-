class_name ArpgEvents
extends RefCounted
## 奇遇（问号房）和诅咒。原来的三个奇遇在 ArpgData.EVENTS，这里补十一个，合起来 all()。
## 一个奇遇 = 名字、一段话、摆设（kit）、几个选项 [文字, 效果]。效果键（ArpgMain._apply_event 读）：
##   hp 按比例掉/回血  heal 回血比例  coins 铜钱  jade 魂玉  gourd 药葫芦  gourd_refill 补满  boon 连选几次心法
##   boon_school 连选几次“你最多那派”的心法  relic 奇物几选一  curse 背诅咒（"random" 随机一个，或诅咒 id）
##   curses 背几个随机诅咒  uncurse 解几个诅咒  stat 这一局永久加成（{atk: 0.1} …）  xp 悟道大进（约一重 × 数）
##   gear 掉一件装备（品质）  fight 打一场（[[种类, 数量, …], …] 波次，赢了按精英房给奖励）  mimic 宝箱（一半是埋伏）
##   fate 这一层剩下的战斗房奖励都改成“心法·你最多那派”  next_relic 下一间战斗房改成给奇物  gamble 赌鬼  gamble_curse 求签
## need_coins / need_curse 不满足时选项变灰。
## 想加一个奇遇：在 LIST 里加一行就行；新效果键在 _apply_event 里加一个分支。

const LIST := [
	{"id": "curse_altar", "name": "诅咒祭坛", "kit": "skull_candle",
		"text": "黑石台上缠着锁链，锁链那头空着。石上刻着一行字：“背得起的，拿得走。”",
		"options": [["接下一个诅咒（随机），换一件奇物（三选一）", {"curse": "random", "relic": 3}],
			["接下两个诅咒，奇物连选两次", {"curses": 2, "relic": 2, "relic_twice": 1}],
			["离开", {}]]},
	{"id": "mimic_chest", "name": "可疑的宝箱", "kit": "chest",
		"text": "路中间摆着一口宝箱，锁是新的。凑近了听，箱缝里有呼吸声。",
		"options": [["打开它（可能是埋伏，赢了掉一件传说装备）", {"mimic": 1}],
			["踹一脚就走（得 10 铜钱）", {"coins": 10}]]},
	{"id": "doctor", "name": "游方郎中", "kit": "tent",
		"text": "背药箱的郎中坐在树根上数铜板：“看病收钱，解咒加钱。”",
		"options": [["抓一副药（30 铜钱：这一局生命上限 +15，回满）", {"coins": -30, "stat": {"hp": 15.0}, "heal": 1.0}],
			["请他解咒（40 铜钱：解一个诅咒）", {"coins": -40, "uncurse": 1, "need_curse": 1}],
			["离开", {}]]},
	{"id": "grinder", "name": "磨剑客", "kit": "table",
		"text": "磨刀石前坐着个独臂老人：“刀钝了，人就死了。”",
		"options": [["请他磨刀（25 铜钱：这一局伤害 +10%）", {"coins": -25, "stat": {"atk": 0.1}}],
			["以血开刃（失去 15% 生命：会心伤害 +25%）", {"hp": -0.15, "stat": {"crit_dmg": 0.25}}],
			["离开", {}]]},
	{"id": "duelist", "name": "流浪刀客", "kit": "banner",
		"text": "戴斗笠的刀客横刀拦路：“拔刀。赢了，我身上的东西归你。”",
		"options": [["应战（打一场精英战，赢了按精英房给奖励）", {"fight": [["samurai", 1], ["samurai", 1, "rogue", 2]]}],
			["绕开", {}]]},
	{"id": "fortune", "name": "算命先生", "kit": "lantern",
		"text": "幡上写着“铁口直断”。先生眯着眼看你的手：“你命里缺一样东西。”",
		"options": [["看手相（10 铜钱：这一层剩下的战斗房都给你最多那一派的心法）", {"coins": -10, "fate": 1}],
			["求一签（不要钱：一半得 40 铜钱，一半背一个诅咒）", {"gamble_curse": 1}],
			["离开", {}]]},
	{"id": "soul_well", "name": "魂井", "kit": "well",
		"text": "井口飘着淡青色的光。往下看，水面上映出来的不是你的脸。",
		"options": [["投两颗魂玉许愿（你最多那一派的心法，选两次）", {"jade": -2, "boon_school": 2, "need_jade": 2}],
			["掬一捧水喝（回复 35% 生命）", {"heal": 0.35}]]},
	{"id": "night_trader", "name": "夜商", "kit": "candles",
		"text": "一个看不清脸的人摊开一块黑布，上面的东西在发光：“不收钱。收一点你。”",
		"options": [["以生命上限 -20 换一件奇物（二选一）", {"stat": {"hp": -20.0}, "relic": 2}],
			["以一个药葫芦换一件奇物（二选一）", {"stat": {"gourds": -1.0}, "relic": 2}],
			["离开", {}]]},
	{"id": "scholar", "name": "落魄书生", "kit": "grave_a",
		"text": "书生抱着一卷残破的兵书：“小生一路逃难，就剩这点学问了。”",
		"options": [["给他 20 铜钱（悟道大进）", {"coins": -20, "xp": 1}],
			["听他讲兵法（下一间战斗房改成给奇物）", {"next_relic": 1}],
			["离开", {}]]},
	{"id": "hunter", "name": "负伤的猎户", "kit": "tent",
		"text": "猎户腿上扎着一支骨箭，靠着树喘气：“行行好……分我一口药。”",
		"options": [["分他一口药（药葫芦 -1：魂玉 +4、铜钱 +30）", {"gourd": -1, "jade": 4, "coins": 30}],
			["帮他拔箭（失去 10% 生命：得一个心法）", {"hp": -0.1, "boon": 1}],
			["不管他", {}]]},
	{"id": "stone_blade", "name": "石中刀", "kit": "grave_a",
		"text": "一把刀插在石头里，刀柄上缠着褪色的红绳。附近的草都枯了。",
		"options": [["拔出来（得一件传说装备，背上一个诅咒）", {"gear": 4, "curse": "random"}],
			["离开", {}]]},
]

## 诅咒：这一局一直跟着你，游方郎中能解（40 铜钱一个）。stats 走和心法一样的表
const CURSES := {
	"wither": {"name": "血枯", "desc": "药葫芦回复 -12%", "stats": {"gourd_heal": -0.12}},
	"wound": {"name": "重伤", "desc": "受伤 +12%", "stats": {"taken_extra": 0.12}},
	"poor": {"name": "穷途", "desc": "铜钱获取 -40%", "stats": {"coin": -0.4}},
	"slow": {"name": "迟滞", "desc": "移速 -10%", "stats": {"move": -0.1}},
	"dull": {"name": "钝刃", "desc": "会心率 -8%", "stats": {"crit": -0.08}},
	"thirst": {"name": "断药", "desc": "药葫芦 -1", "stats": {"gourds": -1.0}},
	"heavy": {"name": "沉身", "desc": "突进斩冷却 +25%", "stats": {"dash_cd": -0.25}},
	"drain": {"name": "泄气", "desc": "气力获取 -25%", "stats": {"energy": -0.25}},
}
const CURSE_COLOR := Color(0.75, 0.3, 0.6)

## 宝箱埋伏的波次
const MIMIC_WAVES := [["crawler", 5, "bomber", 1], ["samurai", 1, "crawler", 4]]


static func all() -> Array:
	var out: Array = []
	out.append_array(ArpgData.EVENTS)
	out.append_array(LIST)
	return out


## 这一局还没见过的奇遇优先
static func pick(rng: RandomNumberGenerator, seen: Array) -> Dictionary:
	var ok := all().filter(func(e: Dictionary) -> bool: return ArpgUnlock.event_ok(e))   # 分局解锁：用到没开系统的奇遇先不出
	var pool := ok.filter(func(e: Dictionary) -> bool: return not seen.has(String(e["id"])))
	if pool.is_empty():
		pool = ok
	return pool[rng.randi_range(0, pool.size() - 1)]


## 随机一个还没背上的诅咒（全背了返回 ""）
static func random_curse(rng: RandomNumberGenerator, have: Array) -> String:
	var ids := CURSES.keys().filter(func(k: String) -> bool: return not have.has(k))
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]
