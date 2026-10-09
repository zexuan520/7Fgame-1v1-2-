class_name Events
extends RefCounted
## 奇遇（设计文档第 10 节“事件”房间）：路上碰到的人或东西，几个选项，多半高风险高回报。
## 地图上每层有一两间奇遇房，进去以后中间站着这件奇遇，按「下」打开，选一个；离开不选也行，回头还能再选。
## 选了谁的就算谁的：扣的血、拿到的招式心法是选的那个人的，铜钱魂玉是两人共用的。
##
## 加新奇遇：EVENTS 里加一条，再把 id 放进这一层的 events（LevelData.FLOORS）。
##
## 字段：
##   name                奇遇名（界面标题）
##   who                 说话的人（空 = 旁白）
##   npc                 站着的人（Npc 的种类），或者 prop 摆着的东西（Interactable 里画）
##   text                打开时的一段话
##   options             选项：
##     label             选项名
##     cost              代价：hp 扣当前生命上限的几成（扣不死，至少剩 1）/ max_hp 这一局生命上限 -N /
##                       coins 铜钱 / coins_half 一半铜钱 / jade 这一局的魂玉 / gourd 药罐 / will 刃意清空
##     gain              收获：pick 弹出三选一（"art" 招式 / "mind" 心法 / "up" 强化 / "any" 都行）、pick_lv 新招式几级 /
##                       coins / jade / heal 回复生命上限的几成 / gourds 补几个药罐 / max_hp 这一局生命上限 +N /
##                       gear 掉一件装备（品质 0-4）/ memory 记忆碎片 / ambush 冒出来的敌人 [[种类, 离玩家多远], ...]
##     chance            成功几率（不写就是一定成功）；失败时拿 fail 里的
##     say / fail_say    选完说的话
##   once                只发生一次的剧情奇遇：存档 hub 里这个标记有了就不再出现；没有之前，这一层第一间奇遇房一定是它
##   gain 里的 rescue    把存档 hub 里这个标记打上（救下白芦 → 药房开张）

const EVENTS := {
	"blood_altar": {"name": "血祭石", "who": "", "prop": "altar",
		"text": "一块被血浸黑的石头，刻着四个字：以血换刃。石头底下压着几把断刀，刀口还亮。",
		"options": [
			{"label": "割掌献血", "cost": {"hp": 0.25}, "gain": {"pick": "art"},
				"say": "血渗进石缝，石头底下的断刀一把把亮了起来。"},
			{"label": "把血放干一半", "cost": {"max_hp": 30}, "gain": {"pick": "art", "pick_lv": 2},
				"say": "石头喝饱了。你手里的刀轻了，身子也虚了。"},
			{"label": "离开", "leave": true},
		]},
	"wounded_ronin": {"name": "受伤的浪人", "who": "受伤的浪人", "npc": "ronin_w",
		"text": "「……别过来。我身上这东西，碰了会传。」他手背上的印记，和你的一模一样。",
		"options": [
			{"label": "分他一罐药", "cost": {"gourd": 1}, "gain": {"memory": 1, "jade": 3},
				"say": "「谢了……我想起来一件事，说给你听。」"},
			{"label": "给他 20 铜钱", "cost": {"coins": 20}, "gain": {"jade": 4},
				"say": "「钱我用不上了。拿着这个，比钱有用。」他塞给你几颗魂玉。"},
			{"label": "夺他的刀", "cost": {}, "gain": {"gear": 2, "ambush": [["dog", -140.0], ["dog", 160.0], ["archer", 260.0]]},
				"say": "刀到手的一瞬间，林子里窜出来几条野狗——是他的。"},
			{"label": "离开", "leave": true},
		]},
	"gambler": {"name": "路边赌客", "who": "赌客", "npc": "gambler",
		"text": "「过路的，来一把？大就是大，小就是小，天王老子来了也一样。」",
		"options": [
			{"label": "押 15 铜钱", "cost": {"coins": 15}, "gain": {"coins": 40}, "chance": 0.5, "fail": {},
				"say": "「大！你运气不赖。」", "fail_say": "「小！承让承让。」"},
			{"label": "押 3 颗魂玉", "cost": {"jade": 3}, "gain": {"pick": "mind"}, "chance": 0.45, "fail": {},
				"say": "「你赢了。我这儿没钱，教你一门心法抵账。」", "fail_say": "「魂玉归我了。下回再来。」"},
			{"label": "离开", "leave": true},
		]},
	"grave_mound": {"name": "无名坟", "who": "", "prop": "mound",
		"text": "一座新坟，坟头插着一把刀，刀穗还是新的。坟前的碗里落满了灰。",
		"options": [
			{"label": "上香（10 铜钱）", "cost": {"coins": 10}, "gain": {"heal": 0.3, "gourds": 1},
				"say": "香烧得很直。你觉得身上暖和了些。"},
			{"label": "挖开坟", "cost": {}, "gain": {"jade": 5, "ambush": [["shield", -120.0], ["dog", 140.0], ["dog", 180.0]]},
				"say": "坟里埋着一袋魂玉。还没装好，四周的土就动了。"},
			{"label": "离开", "leave": true},
		]},
	"hermit": {"name": "山中隐士", "who": "隐士", "npc": "hermit",
		"text": "「坐。」老人盘腿坐在石头上，眼睛没睁开。「你的刀太急了。」",
		"options": [
			{"label": "陪他打坐（一半铜钱）", "cost": {"coins_half": true}, "gain": {"pick": "up"},
				"say": "「心静了，刀自然慢下来。慢，才快。」"},
			{"label": "请教心法", "cost": {"hp": 0.2}, "gain": {"pick": "mind"},
				"say": "他拿竹枝在你身上点了几下，疼得你一身冷汗。「记住这个疼。」"},
			{"label": "离开", "leave": true},
		]},
	"herbalist": {"name": "被围的药师", "who": "白芦", "npc": "herbalist", "once": "herbalist",
		"text": "一个背着药篓的姑娘缩在石灯笼后面，几个僧兵正围上去。「……别过来！」",
		"options": [
			{"label": "出手相救", "cost": {}, "gain": {"rescue": "herbalist", "ambush": [["sohei", -130.0], ["sohei", 150.0]]},
				"say": "「多谢……我叫白芦，是个药师。等你回了山下的破庙，我去找你。」"},
			{"label": "绕开走", "leave": true},
		]},
	"mirror": {"name": "碎铜镜", "who": "", "prop": "mirror",
		"text": "挂在枯树上的一面铜镜，裂成几瓣。每一瓣里映出的你，脸都不一样。",
		"options": [
			{"label": "盯着镜子看", "cost": {"will": true, "hp": 0.1}, "gain": {"memory": 1},
				"say": "镜子里的你开口说了一句话。你听懂了。"},
			{"label": "把镜子砸了", "cost": {}, "gain": {"jade": 2, "coins": 15},
				"say": "镜子碎了一地。碎片里夹着几枚铜钱和魂玉。"},
			{"label": "离开", "leave": true},
		]},
}

## 选项卡上写的代价和收获
const COST_TEXT := {"hp": "生命 -%d%%", "max_hp": "生命上限 -%d（这一局）", "coins": "铜钱 -%d", "coins_half": "一半铜钱",
	"jade": "魂玉 -%d", "gourd": "药罐 -%d", "will": "刃意清空"}
const PICK_TEXT := {"art": "三选一：新招式", "mind": "三选一：心法", "up": "三选一：强化招式", "any": "三选一"}


static func get_event(id: String) -> Dictionary:
	return EVENTS[id]


## 一个选项的代价、收获写成一行字
static func describe(opt: Dictionary) -> String:
	if opt.get("leave", false):
		return "什么也不做，回头还能再来"
	var parts := []
	var cost: Dictionary = opt.get("cost", {})
	for k: String in cost:
		var v: Variant = cost[k]
		var fmt: String = COST_TEXT[k]
		if k == "hp":
			parts.append(fmt % roundi(float(v) * 100.0))
		elif v is bool:
			parts.append(fmt)
		else:
			parts.append(fmt % int(v))
	var gains := _gain_text(opt.get("gain", {}))
	var s := "、".join(parts)
	if gains != "":
		s += ("  →  " if s != "" else "") + gains
	if opt.has("chance"):
		s += "（%d%% 成功）" % roundi(float(opt["chance"]) * 100.0)
	return s


static func _gain_text(g: Dictionary) -> String:
	var parts := []
	if g.has("pick"):
		var t: String = PICK_TEXT[g["pick"]]
		if int(g.get("pick_lv", 1)) > 1:
			t += "（%d 级）" % int(g["pick_lv"])
		parts.append(t)
	if g.has("memory"):
		parts.append("记忆碎片")
	if g.has("gear"):
		parts.append(GearData.QUALITIES[int(g["gear"])]["name"] + "装备")
	if g.has("coins"):
		parts.append("铜钱 +%d" % int(g["coins"]))
	if g.has("jade"):
		parts.append("魂玉 +%d" % int(g["jade"]))
	if g.has("heal"):
		parts.append("回复 %d%% 生命" % roundi(float(g["heal"]) * 100.0))
	if g.has("gourds"):
		parts.append("药罐 +%d" % int(g["gourds"]))
	if g.has("max_hp"):
		parts.append("生命上限 +%d" % int(g["max_hp"]))
	if g.has("ambush"):
		parts.append("会有埋伏")
	if g.has("rescue"):
		parts.append("救下她")
	return "、".join(parts)


## 付不起返回原因，付得起返回 ""
static func why_not(opt: Dictionary, p: Player, r: Run) -> String:
	var cost: Dictionary = opt.get("cost", {})
	if cost.has("coins") and r.coins < int(cost["coins"]):
		return "铜钱不够"
	if cost.has("jade") and r.jade < int(cost["jade"]):
		return "魂玉不够"
	if cost.has("gourd") and p.gourds < int(cost["gourd"]):
		return "药罐空了"
	if cost.has("coins_half") and r.coins < 2:
		return "身上没钱"
	return ""
