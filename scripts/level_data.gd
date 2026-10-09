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
##   events                 这一层的奇遇房能碰到哪些奇遇（见 Events），一局里不重复
##   scale                  层级系数（设计文档第 13 节）：hp 敌人生命、dmg 敌人伤害、jade 魂玉产出的倍率
##
## 房间类型：start 起点 / fight 战斗 / elite 精英 / shop 商人 / rest 土地庙 / event 奇遇 / boss 头目
##
## 房间字段：
##   name                   显示名
##   width                  房间宽度（画面 640，宽的房间镜头会跟着走）
##   theme                  village 荒村 / river 河畔夜 / temple 破庙 / bamboo_temple 竹林古寺（第二层）
##   mood                   荒村的天色和远近景：dusk 黄昏 / night 月夜 / graves 乱坟岗 / fog 雾田 / bamboo 竹林 / camp 山贼营；
##                          竹林古寺：mist 晨雾 / dusk 暮钟 / night 寺夜
##   exit_x                 出口门画在哪儿（不写就贴着右墙）。门右边还有地方时可以藏一间密室
##   features               跑酷和解谜机关：坑、竹签、烂木板、寨门、拉杆、石灯笼、裂墙，写法见 RoomFeatures 开头
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
			{"count": 3, "types": [["fight", 3], ["shop", 1], ["rest", 1], ["event", 2]]},
			{"count": 3, "types": [["fight", 3], ["elite", 2]]},
			{"count": 3, "types": [["fight", 2], ["shop", 2], ["rest", 2], ["event", 2]]},
			{"count": 2, "types": [["fight", 2], ["elite", 1]]},
			{"count": 1, "types": [["rest", 1]]},
			{"count": 1, "types": [["boss", 1]]},
		],
		"pools": {
			"start": ["village_gate"],
			"fight": ["lane", "yard", "well", "field", "barn", "graves", "bamboo_path"],
			"elite": ["shrine_ronin", "bandit_camp"],
			"shop": ["merchant"],
			"rest": ["roadside_shrine"],
			"event": ["mountain_fork", "fallen_shrine", "bamboo_deep"],
			"boss": ["river"],
		},
		"events": ["blood_altar", "wounded_ronin", "gambler", "grave_mound", "hermit", "mirror"],
		"scale": {"hp": 1.0, "dmg": 1.0, "jade": 1.0},
	},
	{
		"name": "竹林古寺", "sub": "第二层",
		"rows": [
			{"count": 1, "types": [["start", 1]]},
			{"count": 2, "types": [["fight", 1]]},
			{"count": 3, "types": [["fight", 3], ["shop", 1], ["rest", 1], ["event", 2]]},
			{"count": 3, "types": [["fight", 3], ["elite", 2]]},
			{"count": 3, "types": [["fight", 2], ["shop", 2], ["rest", 2], ["event", 2]]},
			{"count": 2, "types": [["fight", 2], ["elite", 1]]},
			{"count": 1, "types": [["rest", 1]]},
			{"count": 1, "types": [["boss", 1]]},
		],
		"pools": {
			"start": ["temple_steps"],
			"fight": ["bamboo_sea", "bell_court", "monk_dorm", "stone_garden", "hanging_bridge"],
			"elite": ["hakai_hall", "shadow_court"],
			"shop": ["temple_market"],
			"rest": ["bamboo_shrine"],
			"event": ["zen_garden", "ruined_gate"],
			"boss": ["zen_hall"],
		},
		"events": ["herbalist", "blood_altar", "wounded_ronin", "gambler", "grave_mound", "hermit", "mirror"],
		"scale": {"hp": 1.4, "dmg": 1.2, "jade": 1.3},
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
	# 每间两三屏长：前一段打架，后一段跳坑、过竹签、踩烂木板，再解一个机关才过得去
	"lane": {"name": "荒村小道", "width": 2100.0, "theme": "village", "mood": "dusk", "seed": 2,
		"props": [["laundry", 100.0], ["house2", 330.0], ["urn", 300.0], ["jar", 260.0, 70.0], ["jar", 300.0, 70.0],
			["chest", 340.0, 128.0], ["jar", 455.0], ["barrel", 472.0], ["cart", 520.0], ["crates", 610.0],
			["box", 610.0, 34.0], ["woodpile", 650.0], ["fire", 690.0], ["lantern", 760.0],
			["sign", 960.0], ["crates", 1580.0], ["jar", 1620.0], ["barrel", 1650.0], ["cart", 1690.0],
			["lantern", 1440.0], ["woodpile", 1900.0], ["fire", 1980.0]],
		"features": [["pit", 1010.0, 1090.0], ["spikes", 1150.0, 1190.0],
			["pit", 1240.0, 1380.0], ["plank", 1310.0, 24.0, 44.0],
			["lever", 1500.0, "a", 0.0, 2.2], ["gate", 1760.0, "a"]],
		"line": ["", "前面那道寨门，拉杆一扳就开，可开不了多久。"],
		"waves": [[["dog", 560.0], ["dog", 640.0], ["archer", 380.0, 70.0], ["dog", 1140.0], ["archer", 1580.0, 34.0]],
			[["dog", 40.0], ["dog", 920.0], ["dog", 900.0]]]},
	"yard": {"name": "破屋院子", "width": 2000.0, "theme": "village", "mood": "night", "seed": 3,
		"props": [["laundry", 170.0], ["urn", 215.0], ["bucket", 236.0], ["shed", 330.0], ["jar", 330.0, 74.0],
			["fire", 430.0], ["scaffold", 520.0], ["chest", 520.0, 112.0], ["box", 520.0, 56.0], ["crates", 615.0],
			["barrel", 650.0], ["jar", 668.0], ["woodpile", 700.0],
			["scaffold", 1350.0], ["box", 1350.0, 56.0], ["hay", 1460.0], ["urn", 1600.0], ["barrel", 1800.0]],
		"features": [["pit", 960.0, 1200.0], ["ledge", 1040.0, 40.0, 40.0], ["plank", 1120.0, 62.0, 40.0],
			["lantern", 1260.0, "b"], ["lantern", 1350.0, "b", 112.0], ["lantern", 1560.0, "b"],
			["spikes", 1500.0, 1530.0], ["gate", 1660.0, "b"]],
		"line": ["", "三盏石灯笼，一盏会灭。得趁亮着把另外两盏也点上。"],
		"waves": [[["shield", 440.0], ["archer", 520.0, 112.0], ["dog", 600.0], ["dog", 1300.0], ["archer", 1350.0, 112.0]],
			[["dog", 860.0], ["archer", 40.0]]]},
	"well": {"name": "枯井", "width": 2000.0, "exit_x": 1860.0, "theme": "village", "mood": "night", "seed": 4,
		"props": [["bamboo", 30.0], ["barrel", 230.0], ["jar", 252.0], ["jar", 264.0], ["well", 300.0], ["bucket", 326.0],
			["wall", 420.0], ["house2", 680.0], ["urn", 640.0, 70.0], ["chest", 690.0, 128.0], ["jar", 720.0],
			["box", 790.0], ["lantern", 810.0], ["hay", 1340.0], ["jar", 1340.0, 28.0], ["barrel", 1580.0],
			["urn", 1600.0], ["chest", 1940.0], ["jar", 1975.0], ["urn", 1915.0]],
		"features": [["pit", 1120.0, 1200.0], ["spikes", 1250.0, 1300.0], ["pit", 1400.0, 1520.0], ["crack", 1888.0]],
		"waves": [[["dog", 520.0], ["dog", 560.0], ["archer", 420.0, 46.0], ["shield", 1640.0]],
			[["archer", 1000.0], ["archer", 1040.0], ["shield", 960.0]]]},
	"field": {"name": "荒田", "width": 2300.0, "theme": "village", "mood": "fog", "seed": 5,
		"props": [["bamboo", 60.0], ["scarecrow", 300.0], ["hay", 400.0], ["jar", 400.0, 28.0], ["hay", 444.0],
			["woodpile", 490.0], ["cart", 560.0], ["urn", 600.0], ["scarecrow", 630.0], ["scaffold", 700.0],
			["box", 700.0, 56.0], ["tower", 830.0], ["chest", 830.0, 100.0], ["barrel", 880.0],
			["scarecrow", 1450.0], ["hay", 1760.0], ["jar", 1760.0, 28.0], ["woodpile", 1850.0], ["scarecrow", 2100.0]],
		"features": [["pit", 1180.0, 1420.0], ["plank", 1240.0, 30.0, 40.0], ["plank", 1300.0, 50.0, 40.0],
			["plank", 1360.0, 30.0, 40.0], ["spikes", 1480.0, 1520.0], ["spikes", 1580.0, 1615.0],
			["lever", 1660.0, "a", 0.0, 2.4], ["gate", 1960.0, "a"]],
		"line": ["", "雾里的木板都烂了，踩上去别停。"],
		"waves": [[["archer", 700.0, 112.0], ["archer", 830.0, 100.0], ["dog", 760.0], ["dog", 1700.0], ["dog", 1760.0]],
			[["dog", 1080.0], ["dog", 1060.0], ["shield", 40.0]]]},
	"barn": {"name": "粮仓", "width": 2000.0, "theme": "village", "mood": "dusk", "seed": 6,
		"props": [["barrel_d", 140.0], ["fire", 175.0], ["shed", 300.0], ["jar", 300.0, 74.0], ["hay", 385.0],
			["house2", 560.0], ["urn", 520.0, 70.0], ["chest", 570.0, 128.0], ["barrel", 470.0], ["box", 660.0],
			["woodpile", 700.0], ["house2", 1300.0], ["jar", 1260.0, 70.0], ["urn", 1340.0, 70.0],
			["hay", 1600.0], ["fire", 1880.0]],
		"features": [["pit", 1000.0, 1080.0], ["lever", 1340.0, "c", 128.0], ["spikes", 1460.0, 1520.0], ["gate", 1660.0, "c"]],
		"line": ["", "门闩拴在粮仓屋顶上。"],
		"waves": [[["shield", 470.0], ["dog", 520.0], ["dog", 600.0], ["archer", 1290.0, 128.0], ["shield", 1570.0]],
			[["archer", 560.0, 70.0], ["shield", 860.0]]]},
	"graves": {"name": "乱坟岗", "width": 2200.0, "theme": "village", "mood": "graves", "seed": 8,
		"props": [["grave", 200.0], ["urn", 215.0], ["grave", 250.0], ["jar", 266.0], ["banner", 300.0],
			["grave", 340.0], ["banner", 365.0], ["wall", 450.0], ["chest", 450.0, 46.0], ["note", 540.0, 0.0, "grave"],
			["grave", 600.0], ["jar", 615.0], ["grave", 660.0], ["bamboo", 700.0], ["grave", 900.0], ["grave", 1000.0],
			["urn", 1020.0], ["grave", 1700.0], ["banner", 1740.0], ["grave", 1990.0], ["jar", 2010.0]],
		"features": [["lantern", 1150.0, "b"], ["pit", 1240.0, 1330.0], ["ledge", 1400.0, 60.0, 50.0],
			["lantern", 1400.0, "b", 60.0], ["pit", 1460.0, 1580.0], ["plank", 1520.0, 20.0, 36.0],
			["lantern", 1650.0, "b"], ["gate", 1820.0, "b"]],
		"line": ["", "坟地里的长明灯都灭了。点亮它们，路才会开。"],
		"waves": [[["dog", 520.0], ["archer", 450.0, 46.0], ["shield", 1080.0], ["dog", 1700.0]],
			[["shield", 940.0], ["dog", 40.0], ["dog", 60.0]]]},
	"bamboo_path": {"name": "竹林小径", "width": 2200.0, "exit_x": 2060.0, "theme": "village", "mood": "bamboo", "seed": 14,
		"props": [["bamboo", 60.0], ["bamboo", 180.0], ["jar", 230.0], ["bamboo", 330.0], ["urn", 420.0], ["bamboo", 900.0],
			["scaffold", 1300.0], ["box", 1300.0, 56.0], ["bamboo", 1420.0], ["jar", 1600.0], ["bamboo", 1760.0],
			["chest", 2150.0], ["urn", 2120.0], ["jar", 2180.0]],
		"features": [["pit", 500.0, 580.0], ["pit", 650.0, 860.0], ["plank", 700.0, 30.0, 40.0], ["plank", 760.0, 56.0, 40.0],
			["ledge", 820.0, 30.0, 40.0], ["spikes", 1000.0, 1060.0], ["lantern", 1150.0, "c"], ["lantern", 1300.0, "c", 112.0],
			["lantern", 1500.0, "c"], ["gate", 1700.0, "c"], ["crack", 2088.0]],
		"waves": [[["dog", 380.0], ["dog", 420.0], ["archer", 1300.0, 112.0], ["shield", 1450.0]],
			[["dog", 40.0], ["dog", 2100.0], ["shield", 2100.0]]]},

	# ---------- 精英 ----------
	"shrine_ronin": {"name": "山神庙前", "width": 1420.0, "theme": "village", "mood": "bamboo", "seed": 9,
		"props": [["bamboo", 120.0], ["jar", 200.0], ["bamboo", 360.0], ["urn", 560.0], ["bamboo", 640.0],
			["wall", 750.0], ["stone_lantern", 840.0], ["fire", 920.0], ["banner", 1000.0],
			["stone_lantern", 1070.0], ["urn", 1100.0], ["jar", 1115.0], ["note", 1140.0, 0.0, "ronin"]],
		"features": [["spikes", 260.0, 300.0], ["pit", 420.0, 500.0]],
		"line": ["堕落浪人", "这条路，我先占了。"],
		"waves": [[["ronin", 1160.0]]]},
	"bandit_camp": {"name": "山贼营地", "width": 2100.0, "theme": "village", "mood": "camp", "seed": 10,
		"props": [["tent", 200.0], ["banner", 260.0], ["fire", 330.0], ["rack", 400.0], ["crates", 470.0],
			["box", 470.0, 34.0], ["barrel", 500.0], ["urn", 540.0], ["tower", 620.0], ["chest", 620.0, 100.0],
			["tent", 710.0], ["crates", 1000.0], ["tower", 1400.0], ["tent", 1560.0], ["fire", 1630.0], ["barrel", 1660.0],
			["banner", 1900.0], ["tent", 1990.0]],
		"features": [["pit", 1100.0, 1190.0], ["spikes", 1250.0, 1300.0], ["lever", 1400.0, "a", 100.0], ["gate", 1720.0, "a"]],
		"line": ["山贼", "有人闯营！"],
		"waves": [[["ronin", 420.0], ["archer", 620.0, 100.0], ["dog", 1350.0], ["dog", 1500.0]], [["dog", 960.0], ["dog", 40.0]]]},

	# ---------- 商人、土地庙 ----------
	"merchant": {"name": "行脚商人", "width": 960.0, "theme": "village", "mood": "night", "seed": 11,
		"props": [["bamboo", 40.0], ["barrel_d", 80.0], ["fire", 120.0], ["lantern", 740.0], ["woodpile", 860.0],
			["cart", 910.0]]},
	"roadside_shrine": {"name": "路边土地庙", "width": 720.0, "theme": "village", "mood": "fog", "seed": 12,
		"props": [["bamboo", 60.0], ["hay", 130.0], ["note", 190.0, 0.0, "shrine"], ["urn", 250.0],
			["stone_lantern", 300.0], ["stone_lantern", 420.0], ["jar", 470.0], ["grave", 520.0], ["bamboo", 600.0]]},

	# ---------- 奇遇（中间站着这间的奇遇，见 Events） ----------
	"mountain_fork": {"name": "山道岔口", "width": 720.0, "theme": "village", "mood": "fog", "seed": 15,
		"props": [["bamboo", 40.0], ["sign", 150.0], ["stone_lantern", 230.0], ["hay", 520.0], ["jar", 520.0, 28.0],
			["woodpile", 600.0], ["bamboo", 680.0]]},
	"fallen_shrine": {"name": "倒塌的祠堂", "width": 720.0, "theme": "village", "mood": "night", "seed": 16,
		"props": [["wall", 120.0], ["urn", 200.0], ["banner", 250.0], ["stone_lantern", 480.0], ["grave", 560.0],
			["jar", 590.0], ["bamboo", 660.0]]},
	"bamboo_deep": {"name": "竹林深处", "width": 720.0, "theme": "village", "mood": "bamboo", "seed": 17,
		"props": [["bamboo", 60.0], ["bamboo", 150.0], ["urn", 220.0], ["bamboo", 520.0], ["jar", 560.0],
			["bamboo", 610.0], ["bamboo", 690.0]]},

	# ---------- 头目 ----------
	"river": {"name": "断水河畔", "width": 840.0, "theme": "river", "seed": 13,
		"waves": [[["liu", 600.0]]], "intro": true},

	# ========== 第二层：竹林古寺 ==========
	"temple_steps": {"name": "古寺石阶", "width": 720.0, "theme": "bamboo_temple", "mood": "mist", "seed": 21,
		"props": [["bamboo", 40.0], ["stone_lantern", 160.0], ["banner", 230.0], ["note", 320.0, 0.0, "steps"],
			["urn", 380.0], ["jar", 398.0], ["stone_lantern", 470.0], ["bamboo", 640.0]],
		"line": ["", "石阶尽头是寺门。钟声停了很多年了。"]},

	"bamboo_sea": {"name": "竹海", "width": 2100.0, "theme": "bamboo_temple", "mood": "mist", "seed": 22,
		"props": [["bamboo", 100.0], ["stone_lantern", 300.0], ["jar", 360.0], ["scaffold", 520.0], ["chest", 520.0, 112.0],
			["box", 520.0, 56.0], ["crates", 610.0], ["box", 610.0, 34.0], ["urn", 660.0], ["bamboo", 760.0],
			["bamboo", 1450.0], ["urn", 1600.0], ["jar", 1620.0], ["stone_lantern", 1900.0], ["bamboo", 2000.0]],
		"features": [["pit", 980.0, 1060.0], ["spikes", 1120.0, 1160.0], ["pit", 1220.0, 1360.0], ["plank", 1290.0, 24.0, 44.0],
			["lever", 1480.0, "a", 0.0, 2.2], ["gate", 1740.0, "a"]],
		"line": ["", "竹子密得透不进光。有人在竹梢上跟着你。"],
		"waves": [[["sohei", 560.0], ["shinobi", 640.0], ["archer", 520.0, 112.0], ["sohei", 1140.0], ["shinobi", 1580.0]],
			[["shinobi", 40.0], ["shinobi", 900.0], ["sohei", 880.0]]]},
	"bell_court": {"name": "钟楼前庭", "width": 2000.0, "theme": "bamboo_temple", "mood": "dusk", "seed": 23,
		"props": [["banner", 160.0], ["wall", 300.0], ["urn", 300.0, 46.0], ["stone_lantern", 420.0], ["tower", 520.0],
			["chest", 520.0, 100.0], ["jar", 600.0], ["barrel", 640.0], ["scaffold", 1350.0], ["box", 1350.0, 56.0],
			["urn", 1600.0], ["banner", 1800.0]],
		"features": [["pit", 960.0, 1200.0], ["ledge", 1040.0, 40.0, 40.0], ["plank", 1120.0, 62.0, 40.0],
			["lantern", 1260.0, "b"], ["lantern", 1350.0, "b", 112.0], ["lantern", 1560.0, "b"],
			["spikes", 1500.0, 1530.0], ["gate", 1660.0, "b"]],
		"line": ["", "钟楼底下三盏长明灯。点亮它们，寺门才开。"],
		"waves": [[["sohei", 440.0], ["archer", 520.0, 100.0], ["shinobi", 640.0], ["sohei", 1300.0], ["archer", 1350.0, 112.0]],
			[["shinobi", 860.0], ["shinobi", 40.0]]]},
	"monk_dorm": {"name": "僧寮", "width": 2000.0, "theme": "bamboo_temple", "mood": "night", "seed": 24,
		"props": [["bamboo", 80.0], ["shed", 300.0], ["jar", 300.0, 74.0], ["stone_lantern", 420.0], ["house2", 640.0],
			["urn", 600.0, 70.0], ["chest", 650.0, 128.0], ["barrel", 700.0], ["house2", 1300.0], ["jar", 1260.0, 70.0],
			["urn", 1600.0], ["stone_lantern", 1880.0]],
		"features": [["pit", 1000.0, 1080.0], ["lever", 1340.0, "c", 128.0], ["spikes", 1460.0, 1520.0], ["gate", 1660.0, "c"]],
		"line": ["", "门闩挂在僧寮屋顶上。"],
		"waves": [[["sohei", 470.0], ["shinobi", 520.0], ["shinobi", 600.0], ["archer", 1290.0, 128.0], ["sohei", 1570.0]],
			[["archer", 640.0, 70.0], ["sohei", 860.0]]]},
	"stone_garden": {"name": "枯山水", "width": 2200.0, "exit_x": 2060.0, "theme": "bamboo_temple", "mood": "mist", "seed": 25,
		"props": [["bamboo", 60.0], ["stone_lantern", 200.0], ["jar", 230.0], ["urn", 420.0], ["bamboo", 900.0],
			["scaffold", 1300.0], ["box", 1300.0, 56.0], ["stone_lantern", 1420.0], ["jar", 1600.0], ["bamboo", 1760.0],
			["chest", 2150.0], ["urn", 2120.0], ["jar", 2180.0]],
		"features": [["pit", 500.0, 580.0], ["pit", 650.0, 860.0], ["plank", 700.0, 30.0, 40.0], ["plank", 760.0, 56.0, 40.0],
			["ledge", 820.0, 30.0, 40.0], ["spikes", 1000.0, 1060.0], ["lantern", 1150.0, "c"], ["lantern", 1300.0, "c", 112.0],
			["lantern", 1500.0, "c"], ["gate", 1700.0, "c"], ["crack", 2088.0]],
		"waves": [[["shinobi", 380.0], ["shinobi", 420.0], ["archer", 1300.0, 112.0], ["sohei", 1450.0]],
			[["shinobi", 40.0], ["sohei", 2100.0], ["sohei", 2100.0]]]},
	"hanging_bridge": {"name": "断桥", "width": 2100.0, "theme": "bamboo_temple", "mood": "night", "seed": 26,
		"props": [["bamboo", 120.0], ["stone_lantern", 300.0], ["banner", 400.0], ["crates", 620.0], ["box", 620.0, 34.0],
			["cart", 720.0], ["bamboo", 1460.0], ["tower", 1600.0], ["chest", 1600.0, 100.0], ["stone_lantern", 1950.0]],
		"features": [["pit", 900.0, 1300.0], ["plank", 960.0, 30.0, 44.0], ["plank", 1040.0, 40.0, 44.0],
			["plank", 1120.0, 30.0, 44.0], ["plank", 1200.0, 40.0, 44.0], ["spikes", 1400.0, 1440.0],
			["lever", 1520.0, "a", 0.0, 2.4], ["gate", 1760.0, "a"]],
		"line": ["", "桥板都烂了。一块一块踩过去，别停。"],
		"waves": [[["sohei", 500.0], ["shinobi", 600.0], ["shinobi", 700.0], ["archer", 1600.0, 100.0], ["sohei", 1650.0]],
			[["shinobi", 1350.0], ["shinobi", 40.0]]]},

	"hakai_hall": {"name": "罗汉堂", "width": 1420.0, "theme": "bamboo_temple", "mood": "night", "seed": 27,
		"props": [["bamboo", 120.0], ["jar", 200.0], ["stone_lantern", 360.0], ["urn", 560.0], ["banner", 640.0],
			["wall", 750.0], ["stone_lantern", 840.0], ["fire", 920.0], ["banner", 1000.0], ["stone_lantern", 1070.0],
			["urn", 1100.0], ["jar", 1115.0], ["note", 1140.0, 0.0, "hakai"]],
		"features": [["spikes", 260.0, 300.0], ["pit", 420.0, 500.0]],
		"line": ["破戒僧", "这寺里的佛，早被我砸了。"],
		"waves": [[["hakai", 1160.0]]]},
	"shadow_court": {"name": "影院", "width": 2100.0, "theme": "bamboo_temple", "mood": "dusk", "seed": 28,
		"props": [["banner", 200.0], ["stone_lantern", 330.0], ["crates", 470.0], ["box", 470.0, 34.0], ["tower", 620.0],
			["chest", 620.0, 100.0], ["urn", 700.0], ["crates", 1000.0], ["tower", 1400.0], ["stone_lantern", 1640.0],
			["banner", 1900.0]],
		"features": [["pit", 1100.0, 1190.0], ["spikes", 1250.0, 1300.0], ["lever", 1400.0, "a", 100.0], ["gate", 1720.0, "a"]],
		"line": ["忍者", "……来了。"],
		"waves": [[["hakai", 520.0], ["shinobi", 640.0], ["archer", 620.0, 100.0], ["shinobi", 1350.0]],
			[["shinobi", 960.0], ["shinobi", 40.0]]]},

	"temple_market": {"name": "山门下的货摊", "width": 960.0, "theme": "bamboo_temple", "mood": "dusk", "seed": 29,
		"props": [["bamboo", 40.0], ["barrel_d", 80.0], ["fire", 120.0], ["stone_lantern", 740.0], ["banner", 860.0],
			["bamboo", 920.0]]},
	"bamboo_shrine": {"name": "竹林小祠", "width": 720.0, "theme": "bamboo_temple", "mood": "mist", "seed": 30,
		"props": [["bamboo", 60.0], ["note", 190.0, 0.0, "shrine2"], ["urn", 250.0], ["stone_lantern", 300.0],
			["stone_lantern", 420.0], ["jar", 470.0], ["bamboo", 600.0]]},
	"zen_garden": {"name": "禅院", "width": 720.0, "theme": "bamboo_temple", "mood": "mist", "seed": 31,
		"props": [["bamboo", 40.0], ["stone_lantern", 180.0], ["urn", 520.0], ["stone_lantern", 600.0], ["bamboo", 680.0]]},
	"ruined_gate": {"name": "倒了的山门", "width": 720.0, "theme": "bamboo_temple", "mood": "night", "seed": 32,
		"props": [["wall", 120.0], ["banner", 220.0], ["jar", 260.0], ["stone_lantern", 500.0], ["urn", 580.0],
			["bamboo", 660.0]]},
	"zen_hall": {"name": "寂光殿", "width": 840.0, "theme": "bamboo_temple", "mood": "night", "seed": 33,
		"props": [["stone_lantern", 120.0], ["banner", 260.0], ["stone_lantern", 720.0]],
		"waves": [[["jakko", 600.0]]], "intro": true},

	# ---------- 据点 ----------
	"temple": {"name": "破庙", "width": 1200.0, "theme": "temple", "seed": 0},
}

## 遗骸、遗书上写的字（站在前面按 下 查看）
const NOTES := {
	"gate": ["路边的遗书", "「村里的人都往山上逃了。别去河边，柳家那位谁也不让过。」"],
	"grave": ["无名墓", "「这里埋着十七个想过河的人。刀都插在坟上了。」"],
	"ronin": ["浪人的遗骸", "「我也想拿那把刀……他的居合，收刀比拔刀还快。」"],
	"shrine": ["土地庙的签", "「签文：水不可断。想断水的人，先断了自己。」"],
	"steps": ["石阶上的刻字", "「上山的人，把刀放下。」——刻字底下堆着一层断刀。"],
	"hakai": ["罗汉堂的供桌", "「十八罗汉，碎了十七尊。剩下那尊的脸，被人一棍子敲平了。」"],
	"shrine2": ["小祠的签", "「签文：静。不动的刀，才是最快的刀。」"],
}

## 房间类型在地图上的样子：图标名、颜色、门上的字
const NODE_TYPES := {
	"start": {"label": "村口", "color": Color("b8ab96")},
	"fight": {"label": "战斗", "color": Color("c9a24a")},
	"elite": {"label": "精英", "color": Color("d0453a")},
	"shop": {"label": "商人", "color": Color("6fc28a")},
	"rest": {"label": "土地庙", "color": Color("7fb2e0")},
	"event": {"label": "奇遇", "color": Color("b07cf0")},
	"boss": {"label": "头目", "color": Color("9a7cff")},
}

## 掉落：铜钱是局内钱（死了就没了），魂玉带回破庙（死亡带回 60%）
const DROPS := {
	"dog": {"coins": 3}, "archer": {"coins": 4}, "shield": {"coins": 6},
	"ronin": {"coins": 25, "jade": 3}, "liu": {"coins": 40, "jade": 15},
}
const CLEAR_JADE := {"fight": 1, "elite": 2}
## 清完这些房间弹出三选一奖励（招式、心法、强化、铜钱，见 Arts）
const REWARD_ROOMS := ["fight", "elite"]
const DEATH_KEEP := 0.6

## 商人老钱（设计文档第 11 节）：货架六格——固定一格补药、两格别的消耗品、一卷招式、两件装备（行者“随缘”再多一件）；
## 服务：强化招式（升一级）、重铸装备（重抽词条）、卖出装备（原价 30%）、刷新货架（首次 50 铜钱，每刷一次 ×1.5）
const SHOP := {
	"fixed": "refill", "consumables": 2, "gear": 2,
	"art_price": [0, 45, 70],          # 招式卷：一级 45、二级 70（下标是等级）
	"upgrade": [0, 30, 50],            # 招式从 N 级升到 N+1 级的价格（下标是当前等级）
	"reforge": [0, 15, 25, 35, 50],    # 重铸价格（按品质；凡品没有词条，不能重铸）
	"sell": 0.3,                       # 卖出：原价 30%
	"refresh": 50, "refresh_mult": 1.5,
}

## 商人的消耗品，用铜钱买，只在这一局有效
const RARE_CHANCE := 0.25           # rare 的货（归庙符）每次进店有这么大几率摆出来，每局最多买一张
const SHOP_ITEMS := {
	"refill": {"name": "补药", "desc": "药罐补满", "cost": 20},
	"heal": {"name": "金疮药", "desc": "回复 50% 生命", "cost": 15},
	"whetstone": {"name": "磨刀石", "desc": "攻击 +15%", "cost": 35},
	"amulet": {"name": "铁护符", "desc": "生命上限 +30", "cost": 35},
	"gourd": {"name": "空药罐", "desc": "药罐 +1", "cost": 40},
	"guard_charm": {"name": "镇心符", "desc": "架势上限 +20", "cost": 30},
	# 道具（放进买的人的道具栏，见 Items）和纸人；rare 的只是偶尔摆出来
	"calm": {"name": "静心丹", "desc": "道具：10 秒内架势不涨", "cost": 25, "give": "calm"},
	"rage": {"name": "怒火散", "desc": "道具：15 秒内攻击 +25%", "cost": 25, "give": "rage"},
	"stone": {"name": "重铸石", "desc": "道具：重抽武器词条", "cost": 30, "give": "stone"},
	"return": {"name": "归庙符", "desc": "道具：清完敌人时立刻回城，魂玉全部带回", "cost": 60, "give": "return", "rare": true},
	"paper": {"name": "纸人", "desc": "副武器用的纸人 +5", "cost": 15, "paper": 5},
}

## 土地庙：上香一次，回满生命、补满药罐
const REST_HEAL := 1.0

static func floor_data(index: int) -> Dictionary:
	return FLOORS[index]


static func room(key: String) -> Dictionary:
	return ROOMS[key]
