class_name ArpgStory
extends RefCounted
## 剧情数据：主线（开场、每层入口、头目战前战后、三个结局）、分支剧情遭遇（剧情房里的选择会改后面的走向）、
## 隐藏剧情（寂光的五页残页，藏在隐藏房间里，集齐了最终战后多出一个真结局）。
##
## 说话：每句 [说话人, 文字, 名字颜色(可省)]，说话人为空是旁白。
## 一局里的选择记在 ArpgState.flags；跨局的东西（残页、看过的结局、第一次进山门）记在存档 Game.save。

const C_HERO := Color(0.55, 0.8, 1.0)
const C_HAG := Color(0.85, 0.75, 0.55)
const C_SAKURA := Color(1.0, 0.6, 0.78)
const C_MASTER := Color(0.75, 0.9, 1.0)
const C_RONIN := Color(1.0, 0.7, 0.4)
const C_MONK := Color(0.7, 0.85, 0.7)

## 第一次进山门
const INTRO := [
	["", "十年前，樱落村一夜成灰。逃出来的少年，只带走半截断刀。"],
	["拾骨婆", "又一个往山上走的。骨头我见得多了，活人倒是少见。", C_HAG],
	["拾骨婆", "山上那盏灯又亮了。寂光寺的残灯一亮，死人就不肯躺下。", C_HAG],
	["残刃", "我师父还在寺里。", C_HERO],
	["拾骨婆", "那就去问问他，为什么让灯亮着。死了也别怕，你的魂玉我替你捡回来，捡回六成。", C_HAG],
	["", "（找拾骨婆点天赋，去兵器架挑兵器，准备好了就走进光门。）"],
]

## 每层第一间
const FLOOR_START := [
	[["", "幽林遗迹。樱落村的废墟被林子吞了一半，骷髅在旧路上游荡。"],
	 ["残刃", "……路还是这条路。", C_HERO]],
	[["", "寂光寺。钟早就不响了，殿里只剩那盏灯，青得像冰。"],
	 ["残刃", "师父，我回来了。", C_HERO]],
]

const BOSS_PRE := {
	"boss": [
		["", "樱树下站着一个人，刀上落满了花瓣。"],
		["夜樱剑鬼", "……残刃？你还记得这棵树吗。我们在这里比过刀，你输了，哭了一整晚。", C_SAKURA],
		["残刃", "阿樱。你死在那场火里了。", C_HERO],
		["夜樱剑鬼", "灯不让我死。来吧，像小时候一样，这次别再输了。", C_SAKURA],
	],
	"boss2": [
		["", "大殿尽头，残灯悬在半空。灯下坐着一个老僧，肩上落满了灰。"],
		["寂光", "你回来了。我等这一刀，等了十年。", C_MASTER],
		["残刃", "师父，为什么要点灯？村里的人，阿樱……他们都在受苦。", C_HERO],
		["寂光", "灯灭了，他们就真的没了。我宁可他们这样活着。", C_MASTER],
	],
}

## 头目战前，按一局里的选择多出来的话
const BOSS_PRE_FLAGS := {
	"boss2": {
		"sakura_blade": [["寂光", "你背上那把刀……是阿樱的。她把刀给你了？", C_MASTER]],
		"monk_told": [["残刃", "守灯僧都告诉我了。灯在吃你的寿数。", C_HERO], ["寂光", "……多嘴的家伙。", C_MASTER]],
		"ronin_saved": [["阿七", "残刃！我欠你一条命，这一刀我替你挡！", C_RONIN],
			["", "阿七挡在你身前，替你扛下了第一击。（你多了一次倒下再起的机会）"]],
	},
}

const BOSS_POST := {
	"boss": [
		["夜樱剑鬼", "好……这次是你赢了。", C_SAKURA],
		["夜樱剑鬼", "灯在寺里，师父在灯旁边。他已经……不是你记得的那个人了。", C_SAKURA],
	],
	"boss2": [
		["寂光", "……你长大了。", C_MASTER],
		["寂光", "灯就在那儿。熄了它，还是接过去，你自己选。", C_MASTER],
	],
}

## 打倒夜樱后的选择
const SAKURA_CHOICE := [
	["为她超度", "让阿樱安息。魂玉 +8", {"jade": 8, "flag": "sakura_rest"}],
	["接过她的刀", "带着她一起上山。得到一个心法，寂光会认出这把刀", {"boon": 1, "flag": "sakura_blade"}],
]

## 结局
const ENDINGS := {
	"douse": {"title": "结局 · 灯灭", "lines": [
		["", "你一刀劈碎了灯罩。青光像潮水一样退下山去。"],
		["", "樱落村的骷髅一个接一个躺回土里。这一次，没有谁再站起来。"],
		["寂光", "……谢谢你。", C_MASTER],
		["", "你在樱树下埋了半截断刀，下山了。"]]},
	"keep": {"title": "结局 · 守灯人", "lines": [
		["", "你把残灯捧在手里。它很轻，轻得不像压了十年的寿数。"],
		["残刃", "师父守了十年，接下来换我。", C_HERO],
		["", "寂光寺的钟，又响了一声。"]]},
	"true": {"title": "真结局 · 归途", "lines": [
		["", "你把五页残页放在师父手里。他一页一页地看，看到最后一页，笑了。"],
		["寂光", "原来我写过这些。……灯芯在这里。", C_MASTER],
		["", "他亲手取出灯芯，按进你那半截断刀。刀身亮了一下，接上了。"],
		["", "灯灭了，死者安眠。师父的灰落了一地，像一场很小的雪。"],
		["残刃", "我回来了。这次，是真的回来了。", C_HERO]]},
}

## 分支剧情遭遇：剧情房里碰到，按层出现；need / not 是一局里的条件（flags）
const ENCOUNTERS := [
	{"id": "ronin", "floor": 0, "name": "负伤的浪人阿七", "kit": "tent", "lines": [
		["阿七", "别动手……我不是死人。骷髅追了我三天，药早就用完了。", C_RONIN],
		["阿七", "你也是往山上去的？那地方……去了的人都没回来。", C_RONIN]],
		"options": [
			["分他一壶药", "失去 1 个药葫芦。他会记得你", {"gourd": -1, "flag": "ronin_saved"}],
			["给他 15 铜钱，让他下山", "失去 15 铜钱", {"coins": -15, "flag": "ronin_left", "jade": 2}],
			["不理他", "", {"flag": "ronin_ignored"}]]},
	{"id": "jizo", "floor": 0, "name": "无头地藏", "kit": "shrine", "lines": [
		["", "路边一尊石地藏，头不知被谁砍掉了，脚下却还压着几枚新铜钱。"]],
		"options": [
			["放上 10 铜钱", "求个平安：生命上限 +15", {"coins": -10, "boon_id": "vigor"}],
			["拿走铜钱", "铜钱 +25，但这一局受到的伤害 +10%", {"coins": 25, "curse": 1}],
			["合掌离开", "", {}]]},
	{"id": "monk", "floor": 1, "name": "守灯僧", "kit": "candles", "lines": [
		["守灯僧", "施主是寂光师父的弟子？……那盏灯，是师父从山腹里挖出来的。", C_MONK],
		["守灯僧", "灯每亮一年，师父就老十年。他撑不了多久了。", C_MONK]],
		"options": [
			["听他讲完", "知道了灯的秘密，寂光会有话对你说", {"flag": "monk_told", "jade": 2}],
			["请他指路", "这一层多一个隐藏房间的线索（下一个战斗房必有裂墙）", {"flag": "secret_hint"}],
			["拔刀", "他护着灯，你要从他手里拿东西，就得打一场（精英战，必掉装备）", {"fight": "samurai"}]]},
	{"id": "ronin_bones", "floor": 1, "need": "ronin_ignored", "name": "阿七的尸骨", "kit": "grave_a", "lines": [
		["", "路边躺着一具新尸骨，手里还攥着一个空药壶。是那个浪人。"],
		["残刃", "……", C_HERO]],
		"options": [
			["埋了他", "魂玉 +4", {"jade": 4}],
			["搜身", "得到一件装备", {"gear": 1}]]},
	{"id": "ronin_again", "floor": 1, "need": "ronin_left", "name": "又见阿七", "kit": "tent", "lines": [
		["阿七", "我没下山。想了想，还是欠你的。", C_RONIN],
		["阿七", "这个你拿着，山脚下捡的，我用不上。", C_RONIN]],
		"options": [["收下", "得到一件精良以上的装备", {"gear": 2}]]},
]

## 寂光的残页（隐藏房间里找，跨局保留）
const PAGES := [
	"「灯是从山腹里挖出来的。挖出来那天，寺里的井水全变成了青色。」",
	"「樱落村起火那夜，我把灯点亮了。火灭了，烧死的人却一个个站了起来。」",
	"「阿樱问我，她为什么不冷。我答不上来。」",
	"「灯在吃我的寿数。再点十年，我就和他们一样了。」",
	"「若残刃回来，就让他带走灯芯。我不配做他的师父，但他该知道归途在哪儿。」",
]


static func pages() -> Array:
	return Game.save.get("arpg_pages", [])


static func has_all_pages() -> bool:
	return pages().size() >= PAGES.size()


## 下一页还没捡到的残页（-1 表示全齐了）
static func next_page() -> int:
	var got := pages()
	for i in range(PAGES.size()):
		if not got.has(i):
			return i
	return -1


static func take_page(i: int) -> void:
	var got: Array = pages().duplicate()
	if not got.has(i):
		got.append(i)
	Game.save["arpg_pages"] = got
	Game.write_save()


static func encounter_for(floor_i: int, flags: Dictionary, seen: Dictionary) -> Dictionary:
	for e: Dictionary in ENCOUNTERS:
		if int(e["floor"]) != floor_i or seen.has(e["id"]):
			continue
		if e.has("need") and not flags.has(e["need"]):
			continue
		return e
	return {}
