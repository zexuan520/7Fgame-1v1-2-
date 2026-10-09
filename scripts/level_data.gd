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
##   props                  摆设 [种类, x]：well 井、cart 板车（能站）、crates 木箱（能站）、
##                          shed 破棚顶（能站）、scarecrow 稻草人、fire 篝火、sign 路牌、grave 坟头
##   waves                  一波一波的敌人。每波是 [[敌人类型, x], ...]；
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
		"props": [["sign", 300.0], ["scarecrow", 470.0]],
		"line": ["", "山下的村子早就没人了。往前走，刀在河那边。"]},

	# ---------- 战斗 ----------
	"lane": {"name": "荒村小道", "width": 960.0, "theme": "village", "seed": 2,
		"props": [["cart", 380.0], ["fire", 620.0]],
		"waves": [[["dog", 620.0], ["dog", 680.0]], [["dog", 40.0], ["dog", 920.0], ["dog", 900.0]]]},
	"yard": {"name": "破屋院子", "width": 900.0, "theme": "village", "seed": 3,
		"props": [["crates", 330.0], ["shed", 560.0], ["fire", 760.0]],
		"waves": [[["shield", 560.0], ["archer", 780.0]], [["dog", 860.0], ["archer", 40.0]]]},
	"well": {"name": "枯井", "width": 1000.0, "theme": "village", "seed": 4,
		"props": [["well", 470.0], ["crates", 720.0]],
		"waves": [[["dog", 560.0], ["dog", 620.0]], [["archer", 940.0], ["archer", 980.0], ["shield", 900.0]]]},
	"field": {"name": "荒田", "width": 1120.0, "theme": "village", "seed": 5,
		"props": [["scarecrow", 420.0], ["scarecrow", 780.0], ["cart", 600.0]],
		"waves": [[["archer", 700.0], ["archer", 860.0]], [["dog", 1080.0], ["dog", 1060.0], ["shield", 40.0]]]},
	"barn": {"name": "粮仓", "width": 920.0, "theme": "village", "seed": 6,
		"props": [["shed", 380.0], ["crates", 640.0], ["fire", 520.0]],
		"waves": [[["shield", 600.0], ["dog", 660.0], ["dog", 700.0]], [["archer", 880.0], ["shield", 860.0]]]},
	"graves": {"name": "乱坟岗", "width": 980.0, "theme": "village", "seed": 8,
		"props": [["grave", 340.0], ["grave", 420.0], ["grave", 660.0], ["grave", 760.0], ["fire", 560.0]],
		"waves": [[["dog", 600.0], ["archer", 820.0]], [["shield", 940.0], ["dog", 40.0], ["dog", 60.0]]]},

	# ---------- 精英 ----------
	"shrine_ronin": {"name": "山神庙前", "width": 820.0, "theme": "village", "seed": 9,
		"props": [["fire", 300.0], ["grave", 620.0]],
		"line": ["堕落浪人", "这条路，我先占了。"],
		"waves": [[["ronin", 560.0]]]},
	"bandit_camp": {"name": "山贼营地", "width": 1000.0, "theme": "village", "seed": 10,
		"props": [["fire", 480.0], ["crates", 300.0], ["cart", 760.0]],
		"line": ["山贼", "有人闯营！"],
		"waves": [[["ronin", 640.0], ["archer", 900.0]], [["dog", 960.0], ["dog", 40.0]]]},

	# ---------- 商人、土地庙 ----------
	"merchant": {"name": "行脚商人", "width": 720.0, "theme": "village", "seed": 11,
		"props": [["fire", 150.0], ["cart", 640.0]]},
	"roadside_shrine": {"name": "路边土地庙", "width": 720.0, "theme": "village", "seed": 12,
		"props": [["grave", 520.0]]},

	# ---------- 头目 ----------
	"river": {"name": "断水河畔", "width": 840.0, "theme": "river", "seed": 13,
		"waves": [[["liu", 600.0]]], "intro": true},

	# ---------- 据点 ----------
	"temple": {"name": "破庙", "width": 800.0, "theme": "temple", "seed": 0},
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
