class_name LevelData
extends RefCounted
## 关卡数据表：每一层的地图结构、房间、刷怪、奖励，商人货物和破庙供台。
## 加新房间只要在 ROOMS 里加一条，再把名字放进这一层的 pools；加新层就在 FLOORS 里加一条。
##
## 层字段：
##   name / sub             层名、副标题
##   rows                   地图从左到右每一列可能出现的房间类型。每列是一组候选，
##                          [类型, 权重] 抽 count 个（同列不重复，"fight" 可以重复）
##   pools                  每种房间类型能抽到的房间
##
## 房间类型：start 起点 / fight 战斗 / elite 精英 / shop 商人 / rest 土地庙 / boss 头目
##
## 房间字段：
##   name                   显示名
##   width                  房间宽度（画面 640，宽的房间镜头会跟着走）
##   theme                  village 荒村黄昏 / river 河畔夜 / temple 破庙
##   seed                   背景随机种子（房子、树的位置）
##   props                  摆设和地形 [种类, x] 或 [种类, x, 离地高度]，种类见 RoomProps 开头的说明。
##                          能站的：cart crates hay shed wall house2（两层楼带楼梯） scaffold tower；
##                          能砍碎的：jar urn barrel box（Breakable，掉铜钱、伤药）；
##                          能互动的：chest 宝箱、note 遗骸（第 4 项是 NOTES 里的 id）
##   waves                  一波一波的敌人。每波是 [[敌人类型, x], ...]，写了第 3 项高度的站在平台上不走动；
##                          第一波站在原地，主角走近才动手；后面的波次在上一波清完后从两边冲进来
##   intro                  头目先演登场
##   line                   进屋时屏幕下方的一句话 [谁, 内容]

const FLOORS := [
	{
		"name": "山脚荒村", "sub": "第一层",
		"rows": [
			{"count": 1, "types": [["start", 1]]},
			{"count": 2, "types": [["fight", 1]]},
			{"count": 3, "types": [["fight", 3], ["shop", 1], ["rest", 1]]},
			{"count": 3, "types": [["fight", 3], ["elite", 2]]},
			{"count": 3, "types": [["fight", 2], ["shop", 2], ["rest", 2]]},
			{"count": 2, "types": [["fight", 2], ["elite", 1]]},
			{"count": 1, "types": [["rest", 1]]},
			{"count": 1, "types": [["boss", 1]]},
		],
		"pools": {
			"start": ["village_gate"],
			"fight": ["lane", "yard", "well", "field", "barn", "graves"],
			"elite": ["shrine_ronin", "bandit_camp"],
			"shop": ["merchant"],
			"rest": ["roadside_shrine"],
			"boss": ["river"],
		},
	},
]

const ROOMS := {
	# ---------- 起点 ----------
	"village_gate": {"name": "荒村村口", "width": 720.0, "theme": "village", "seed": 1,
		"props": [["bamboo", 20.0], ["sign", 150.0], ["barrel", 205.0], ["jar", 228.0], ["urn", 244.0],
			["lantern", 290.0], ["hay", 350.0], ["jar", 350.0, 28.0], ["note", 410.0, 0.0, "gate"],
			["woodpile", 460.0], ["scarecrow", 540.0]],
		"line": ["", "山下的村子早就没人了。往前走，刀在河那边。"]},

	# ---------- 战斗 ----------
	"lane": {"name": "荒村小道", "width": 960.0, "theme": "village", "seed": 2,
		"props": [["laundry", 100.0], ["house2", 330.0], ["urn", 300.0], ["jar", 260.0, 70.0], ["jar", 300.0, 70.0],
			["chest", 340.0, 128.0], ["jar", 455.0], ["barrel", 472.0], ["cart", 520.0], ["crates", 610.0],
			["box", 610.0, 34.0], ["woodpile", 650.0], ["fire", 690.0], ["lantern", 760.0]],
		"waves": [[["dog", 560.0], ["dog", 640.0], ["archer", 380.0, 70.0]], [["dog", 40.0], ["dog", 920.0], ["dog", 900.0]]]},
	"yard": {"name": "破屋院子", "width": 900.0, "theme": "village", "seed": 3,
		"props": [["laundry", 170.0], ["urn", 215.0], ["bucket", 236.0], ["shed", 330.0], ["jar", 330.0, 74.0],
			["fire", 430.0], ["scaffold", 520.0], ["chest", 520.0, 112.0], ["box", 520.0, 56.0], ["crates", 615.0],
			["barrel", 650.0], ["jar", 668.0], ["woodpile", 700.0]],
		"waves": [[["shield", 440.0], ["archer", 520.0, 112.0], ["dog", 600.0]], [["dog", 860.0], ["archer", 40.0]]]},
	"well": {"name": "枯井", "width": 1060.0, "theme": "village", "seed": 4,
		"props": [["bamboo", 30.0], ["barrel", 230.0], ["jar", 252.0], ["jar", 264.0], ["well", 300.0], ["bucket", 326.0],
			["wall", 420.0], ["house2", 680.0], ["urn", 640.0, 70.0], ["chest", 690.0, 128.0], ["jar", 720.0],
			["box", 790.0], ["lantern", 810.0]],
		"waves": [[["dog", 520.0], ["dog", 560.0], ["archer", 420.0, 46.0]], [["archer", 1000.0], ["archer", 1040.0], ["shield", 960.0]]]},
	"field": {"name": "荒田", "width": 1120.0, "theme": "village", "seed": 5,
		"props": [["bamboo", 60.0], ["scarecrow", 300.0], ["hay", 400.0], ["jar", 400.0, 28.0], ["hay", 444.0],
			["woodpile", 490.0], ["cart", 560.0], ["urn", 600.0], ["scarecrow", 630.0], ["scaffold", 700.0],
			["box", 700.0, 56.0], ["tower", 830.0], ["chest", 830.0, 100.0], ["barrel", 880.0]],
		"waves": [[["archer", 700.0, 112.0], ["archer", 830.0, 100.0], ["dog", 760.0]],
			[["dog", 1080.0], ["dog", 1060.0], ["shield", 40.0]]]},
	"barn": {"name": "粮仓", "width": 920.0, "theme": "village", "seed": 6,
		"props": [["barrel_d", 140.0], ["fire", 175.0], ["shed", 300.0], ["jar", 300.0, 74.0], ["hay", 385.0],
			["house2", 560.0], ["urn", 520.0, 70.0], ["chest", 570.0, 128.0], ["barrel", 470.0], ["box", 660.0],
			["woodpile", 700.0]],
		"waves": [[["shield", 470.0], ["dog", 520.0], ["dog", 600.0]], [["archer", 560.0, 70.0], ["shield", 860.0]]]},
	"graves": {"name": "乱坟岗", "width": 980.0, "theme": "village", "seed": 8,
		"props": [["grave", 200.0], ["urn", 215.0], ["grave", 250.0], ["jar", 266.0], ["stone_lantern", 300.0],
			["grave", 340.0], ["banner", 365.0], ["wall", 450.0], ["chest", 450.0, 46.0], ["note", 540.0, 0.0, "grave"],
			["grave", 600.0], ["jar", 615.0], ["stone_lantern", 660.0], ["bamboo", 700.0]],
		"waves": [[["dog", 520.0], ["archer", 450.0, 46.0]], [["shield", 940.0], ["dog", 40.0], ["dog", 60.0]]]},

	# ---------- 精英 ----------
	"shrine_ronin": {"name": "山神庙前", "width": 820.0, "theme": "village", "seed": 9,
		"props": [["wall", 150.0], ["stone_lantern", 240.0], ["fire", 320.0], ["banner", 400.0],
			["stone_lantern", 470.0], ["urn", 500.0], ["jar", 515.0], ["note", 540.0, 0.0, "ronin"]],
		"line": ["堕落浪人", "这条路，我先占了。"],
		"waves": [[["ronin", 560.0]]]},
	"bandit_camp": {"name": "山贼营地", "width": 1000.0, "theme": "village", "seed": 10,
		"props": [["tent", 200.0], ["banner", 260.0], ["fire", 330.0], ["rack", 400.0], ["crates", 470.0],
			["box", 470.0, 34.0], ["barrel", 500.0], ["urn", 540.0], ["tower", 620.0], ["chest", 620.0, 100.0],
			["tent", 710.0]],
		"line": ["山贼", "有人闯营！"],
		"waves": [[["ronin", 420.0], ["archer", 620.0, 100.0]], [["dog", 960.0], ["dog", 40.0]]]},

	# ---------- 商人、土地庙 ----------
	"merchant": {"name": "行脚商人", "width": 720.0, "theme": "village", "seed": 11,
		"props": [["bamboo", 40.0], ["barrel_d", 100.0], ["fire", 150.0], ["lantern", 205.0], ["woodpile", 600.0],
			["cart", 640.0]]},
	"roadside_shrine": {"name": "路边土地庙", "width": 720.0, "theme": "village", "seed": 12,
		"props": [["bamboo", 60.0], ["hay", 130.0], ["note", 190.0, 0.0, "shrine"], ["urn", 250.0],
			["stone_lantern", 300.0], ["stone_lantern", 420.0], ["jar", 470.0], ["grave", 520.0], ["bamboo", 600.0]]},

	# ---------- 头目 ----------
	"river": {"name": "断水河畔", "width": 840.0, "theme": "river", "seed": 13,
		"waves": [[["liu", 600.0]]], "intro": true},

	# ---------- 据点 ----------
	"temple": {"name": "破庙", "width": 800.0, "theme": "temple", "seed": 0},
}

## 遗骸、遗书上写的字（站在前面按 下 查看）
const NOTES := {
	"gate": ["路边的遗书", "「村里的人都往山上逃了。别去河边，柳家那位谁也不让过。」"],
	"grave": ["无名墓", "「这里埋着十七个想过河的人。刀都插在坟上了。」"],
	"ronin": ["浪人的遗骸", "「我也想拿那把刀……他的居合，收刀比拔刀还快。」"],
	"shrine": ["土地庙的签", "「签文：水不可断。想断水的人，先断了自己。」"],
}

## 房间类型在地图上的样子：图标名、颜色、门上的字
const NODE_TYPES := {
	"start": {"label": "村口", "color": Color("b8ab96")},
	"fight": {"label": "战斗", "color": Color("c9a24a")},
	"elite": {"label": "精英", "color": Color("d0453a")},
	"shop": {"label": "商人", "color": Color("6fc28a")},
	"rest": {"label": "土地庙", "color": Color("7fb2e0")},
	"boss": {"label": "头目", "color": Color("9a7cff")},
}

## 掉落：铜钱是局内钱（死了就没了），魂玉带回破庙（死亡带回 60%）
const DROPS := {
	"dog": {"coins": 3}, "archer": {"coins": 4}, "shield": {"coins": 6},
	"ronin": {"coins": 25, "jade": 3}, "liu": {"coins": 40, "jade": 15},
}
const CLEAR_JADE := {"fight": 1, "elite": 2}
const DEATH_KEEP := 0.6

## 商人：每次进店从这里抽 3 样，用铜钱买，只在这一局有效
const SHOP_ITEMS := {
	"refill": {"name": "补药", "desc": "药罐补满", "cost": 20},
	"heal": {"name": "金疮药", "desc": "回复 50% 生命", "cost": 15},
	"whetstone": {"name": "磨刀石", "desc": "攻击 +15%", "cost": 35},
	"amulet": {"name": "铁护符", "desc": "生命上限 +30", "cost": 35},
	"gourd": {"name": "空药罐", "desc": "药罐 +1", "cost": 40},
	"guard_charm": {"name": "镇心符", "desc": "架势上限 +20", "cost": 30},
}

## 土地庙：上香一次，回满生命、补满药罐
const REST_HEAL := 1.0

## 破庙供台：用魂玉换永久加成，存档里记等级
const ALTAR := {
	"vigor": {"name": "体魄", "desc": "初始生命 +20", "costs": [5, 10, 15]},
	"gourd": {"name": "药缘", "desc": "初始药罐 +1", "costs": [8, 16]},
	"purse": {"name": "盘缠", "desc": "开局铜钱 +15", "costs": [4, 8, 12]},
}


static func floor_data(index: int) -> Dictionary:
	return FLOORS[index]


static func room(key: String) -> Dictionary:
	return ROOMS[key]
