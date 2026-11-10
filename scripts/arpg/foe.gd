class_name Foe
extends Actor
## 敌人：状态机 巡逻 → 发现 → 追击 → 攻击前摇（红色预警）→ 攻击 → 硬直，挨打会僵直（重甲要先打掉韧性）。
## 攻击令牌：同时最多 MAX_TOKENS 个敌人在出招，其余的绕着主角游走，不会一拥而上。
## 种类在 TYPES 里：腐骨虫（小型快攻）、骷髅兵（近战）、骨刺客（快速突刺，打完就退开）、赤甲武士（重攻击、跳劈落地扬尘）、
## 幽魂术士（远程法阵）、骨弩手（远程弩箭，会躲着打）、冲阵骨（远距离直线冲锋，撞墙会晕）、爆骨鬼（贴脸自爆，先打死它反而炸到旁边的怪）、
## 盾骷髅（正面举盾挡刀，绕后或连砍破盾）、招魂巫（躲在后面招小鬼，打死它小鬼散架）、头目（夜樱剑鬼、百骨将会召唤小怪和地刺、寂光）。

## 头目进二阶段时头上冒的字
const RAGE_NAMES := {"boss": "剑鬼·狂", "boss3": "万骨·醒", "boss2": "残灯·燃", "boss4": "枯荣·涨", "boss5": "不夜·燃", "boss6": "烬·点灯"}
## 头目半血变身时说的一句
const RAGE_LINES := {"boss": "樱花……还没落完。", "boss3": "都起来！谁准你们躺下的！", "boss2": "灯不能灭……灯不能灭！", "boss4": "水……太冷了。", "boss5": "四百年了，谁来让我躺下！", "boss6": "师父舍不得点的灯，我来点。"}

signal dropped(pos: Vector3, coins: int, jade: int)

const MAX_TOKENS := 2
static var tokens := 0
## 这一区的小怪边缘光颜色（ArpgMain._apply_zone_env 按区域冷暖设）
static var zone_rim := Color(1.0, 0.55, 0.35)
static var zone_rim_k := 0.45
static var _base_shader: Shader
var _base_ring: MeshInstance3D

## 不出手时竖着拿的兵器
const UPRIGHT := {"staff": true, "skel_staff": true, "spear": true}

const TYPES := {
	"crawler": {"name": "腐骨虫", "model": "skel_crawler", "weapon": "", "wlen": 0.0, "tint": Color(0.85, 0.95, 0.8), "k": 0.72,
		"hp": 26.0, "speed": 5.4, "detect": 13.0, "range": 2.2, "dmg": 7.0, "windup": 0.42, "attack": "lunge", "poise": 0.0, "coins": 1},
	"skeleton": {"name": "骷髅兵", "model": "skel_grunt", "weapon": "skel_blade", "wlen": 30.0, "tint": Color(0.95, 0.95, 0.9), "k": 1.0,
		"hp": 55.0, "speed": 3.8, "detect": 12.0, "range": 2.1, "dmg": 11.0, "windup": 0.55, "attack": "slash", "poise": 0.0, "coins": 3},
	"shadow": {"name": "残影", "model": "hero_canren", "ghost": true, "weapon": "sword", "wlen": 34.0, "tint": Color(0.3, 0.26, 0.5), "mono": 1.0, "k": 0.82,
		"hp": 520.0, "speed": 5.4, "detect": 30.0, "range": 2.4, "dmg": 15.0, "windup": 0.4, "attack": "slash", "poise": 60.0, "coins": 30},
	"samurai": {"name": "赤甲武士", "model": "red_armor", "weapon": "axe2", "wlen": 44.0, "tint": Color(1.25, 0.5, 0.45), "k": 1.25,
		"hp": 190.0, "speed": 3.2, "detect": 14.0, "range": 2.8, "dmg": 22.0, "windup": 0.75, "attack": "heavy", "poise": 45.0, "coins": 9},
	"mage": {"name": "幽魂术士", "model": "skel_mage2", "weapon": "skel_staff", "wlen": 34.0, "tint": Color(0.85, 0.7, 1.15), "k": 1.0,
		"hp": 42.0, "speed": 3.4, "detect": 16.0, "range": 11.0, "dmg": 14.0, "windup": 0.7, "attack": "rune", "poise": 0.0, "coins": 4, "keep": 7.5, "elem": "magic"},
	"rogue": {"name": "骨刺客", "model": "skel_assassin", "weapon": "dagger", "wlen": 22.0, "tint": Color(0.8, 0.95, 0.85), "k": 0.95,
		"hp": 38.0, "speed": 5.0, "detect": 15.0, "range": 2.6, "dmg": 10.0, "windup": 0.32, "attack": "lunge", "poise": 0.0, "coins": 3},
	"archer": {"name": "骨弩手", "model": "skel_archer", "weapon": "crossbow", "wlen": 28.0, "tint": Color(0.95, 0.9, 0.8), "k": 0.95,
		"hp": 34.0, "speed": 3.6, "detect": 17.0, "range": 14.0, "dmg": 10.0, "windup": 0.65, "attack": "shot", "poise": 0.0, "coins": 3, "keep": 9.0},
	"charger": {"name": "冲阵骨", "model": "skel_charger", "weapon": "skel_axe", "wlen": 38.0, "tint": Color(1.2, 0.72, 0.55), "k": 1.3,
		"hp": 120.0, "speed": 3.1, "detect": 16.0, "range": 2.6, "dmg": 18.0, "windup": 0.7, "attack": "charge", "poise": 30.0, "coins": 6},
	"bomber": {"name": "爆骨鬼", "model": "skel_bomber", "weapon": "", "wlen": 0.0, "tint": Color(1.35, 0.8, 0.45), "k": 0.8,
		"hp": 20.0, "speed": 6.2, "detect": 16.0, "range": 2.3, "dmg": 20.0, "windup": 0.8, "attack": "blast", "poise": 0.0, "coins": 2, "elem": "fire"},
	"shield": {"name": "盾骷髅", "model": "skel_shield", "weapon": "skel_blade", "wlen": 28.0, "tint": Color(0.85, 0.9, 1.0), "k": 1.1,
		"hp": 70.0, "speed": 3.3, "detect": 12.0, "range": 2.2, "dmg": 12.0, "windup": 0.6, "attack": "slash", "poise": 0.0, "coins": 5,
		"offhand": "shield_f", "olen": 26.0, "guard": 4.0},
	"summoner": {"name": "招魂巫", "model": "summoner", "weapon": "staff", "wlen": 34.0, "tint": Color(0.75, 0.95, 0.8), "k": 1.0,
		"hp": 60.0, "speed": 3.2, "detect": 17.0, "range": 12.0, "dmg": 12.0, "windup": 0.7, "attack": "rune", "poise": 0.0, "coins": 6, "keep": 10.0, "elem": "magic"},
	# ---------- 第一幕 · 每层独有 ----------
	# 瘴菇骨（幽林）：顶着一朵毒菇的小骸骨，站开几步往你脚下喷一团瘴，落地留一滩毒；死了也会噗地散一小团
	"sporer": {"name": "瘴菇骨", "model": "skel_sporer", "weapon": "", "wlen": 0.0, "tint": Color(0.78, 1.0, 0.62), "k": 0.85,
		"hp": 44.0, "speed": 3.3, "detect": 15.0, "range": 8.0, "dmg": 8.0, "windup": 0.85, "attack": "spore", "poise": 0.0, "coins": 4, "keep": 5.5,
		"offhand": "shroom", "olen": 26.0, "elem": "poison"},
	# 抬棺骨（无名冢）：扛着一块棺盖当盾，抡斧头重劈；劈碎了它，棺材里还会爬出三只腐骨虫
	"coffin": {"name": "抬棺骨", "model": "skel_coffin", "weapon": "skel_axe", "wlen": 36.0, "tint": Color(0.88, 0.84, 0.74), "k": 1.25,
		"hp": 125.0, "speed": 2.8, "detect": 13.0, "range": 2.6, "dmg": 17.0, "windup": 0.75, "attack": "heavy", "poise": 25.0, "coins": 6,
		"offhand": "coffin_lid", "olen": 34.0, "guard": 3.0, "split": "crawler"},
	# 铜钟僧（古寺）：拄着钟杖的僧骨，站在几步外一敲钟，金色的声浪一圈圈往外推（翻滚穿过，或者站到圈外）
	"bellmonk": {"name": "铜钟僧", "model": "skel_bellmonk", "weapon": "bell_h", "wlen": 46.0, "tint": Color(1.05, 0.98, 0.85), "head": "skel_minion", "k": 1.1,
		"hp": 95.0, "speed": 2.9, "detect": 15.0, "range": 7.5, "dmg": 13.0, "windup": 0.95, "attack": "bell", "poise": 20.0, "coins": 6, "keep": 5.0, "elem": "holy"},
	# ---------- 第二幕 ----------
	# 水骨：埋在积水里，主角走近才猛地站起来扑一下（lurk）
	"drowned": {"name": "水骨", "model": "skel_drowned", "weapon": "dagger", "wlen": 22.0, "tint": Color(0.6, 0.85, 1.05), "k": 0.9,
		"hp": 40.0, "speed": 4.6, "detect": 14.0, "range": 2.4, "dmg": 11.0, "windup": 0.38, "attack": "lunge", "poise": 0.0, "coins": 3, "lurk": true, "elem": "water"},
	# 灯奴僧：拖着灯链的僧人骸骨，蓄力后链子横扫一整圈
	"chainmonk": {"name": "灯奴僧", "model": "skel_chainmonk", "weapon": "skel_staff", "wlen": 30.0, "tint": Color(0.7, 0.9, 1.1), "k": 1.15,
		"hp": 150.0, "speed": 2.7, "detect": 13.0, "range": 3.6, "dmg": 16.0, "windup": 0.9, "attack": "chain", "poise": 40.0, "coins": 7, "head": "skel_minion", "elem": "water"},
	# 阿七（第四层拔刀）：续命司的刀法，快刀加突刺
	"ronin": {"name": "阿七", "model": "aqi", "weapon": "sword", "wlen": 34.0, "tint": Color(1.15, 0.85, 0.65), "k": 1.0,
		"hp": 420.0, "speed": 4.8, "detect": 30.0, "range": 2.5, "dmg": 15.0, "windup": 0.42, "attack": "slash", "poise": 55.0, "coins": 25},
	# 烛国甲士：一身铜甲，平时只吃三成伤害；打掉韧性（破韧）后甲片松开，几秒内伤害全吃
	"armored": {"name": "烛国甲士", "model": "zhu_armored", "weapon": "axe2", "wlen": 44.0, "tint": Color(1.25, 0.88, 0.5), "mono": 0.75, "k": 1.2,
		"hp": 150.0, "speed": 2.9, "detect": 13.0, "range": 2.8, "dmg": 19.0, "windup": 0.7, "attack": "heavy", "poise": 55.0, "coins": 8, "armor": 0.35},
	# 披火骨：浑身着火的骨兵，死了留下一滩火
	"flameskel": {"name": "披火骨", "model": "skel_flame", "weapon": "skel_blade", "wlen": 30.0, "tint": Color(1.35, 0.75, 0.45), "k": 1.0,
		"hp": 60.0, "speed": 4.2, "detect": 14.0, "range": 2.2, "dmg": 12.0, "windup": 0.5, "attack": "slash", "poise": 0.0, "coins": 4, "fire": true, "elem": "fire"},
	# 不夜将军的亲兵（幻影）：列阵冲一趟就散
	"phantom": {"name": "亲兵", "model": "zhu_armored", "ghost": true, "weapon": "axe2", "wlen": 40.0, "tint": Color(1.5, 1.2, 0.7), "mono": 1.0, "phantom": true, "k": 1.15,
		"hp": 9999.0, "speed": 3.0, "detect": 40.0, "range": 2.6, "dmg": 16.0, "windup": 0.8, "attack": "charge", "poise": 999.0, "coins": 0},
	# 续命司的挖掘队头领（灯冢里的精英战，第一次和活人交手）
	"digger": {"name": "挖掘队头领", "model": "digger", "weapon": "axe2", "wlen": 40.0, "tint": Color(0.75, 0.78, 0.82), "k": 1.15,
		"hp": 360.0, "speed": 4.0, "detect": 30.0, "range": 2.7, "dmg": 18.0, "windup": 0.55, "attack": "heavy", "poise": 60.0, "coins": 20},
	# ---------- 第二幕 · 灰衣营（活人：会退、会挡、会躲） ----------
	# 灰衣刀手：砍一刀就斜着退开；你挥刀时偶尔侧身闪开
	"greyblade": {"name": "灰衣刀手", "model": "grey_blade", "weapon": "sword", "wlen": 32.0, "tint": Color(0.82, 0.84, 0.88), "mono": 1.0, "k": 1.0,
		"hp": 70.0, "speed": 4.6, "detect": 15.0, "range": 2.4, "dmg": 13.0, "windup": 0.42, "attack": "slash", "poise": 0.0, "coins": 4, "hitrun": true, "dodge": 0.3},
	# 灰衣盾兵：举盾挡正面，挡满几下破盾
	"greyguard": {"name": "灰衣盾兵", "model": "grey_guard", "weapon": "sword", "wlen": 30.0, "tint": Color(0.78, 0.8, 0.85), "mono": 0.9, "k": 1.1,
		"hp": 95.0, "speed": 3.4, "detect": 13.0, "range": 2.3, "dmg": 14.0, "windup": 0.55, "attack": "slash", "poise": 20.0, "coins": 6,
		"offhand": "shield_f", "olen": 26.0, "guard": 5.0},
	# 灰衣弩手：站远了射，人靠近就往后退
	"greybow": {"name": "灰衣弩手", "model": "grey_bow", "weapon": "crossbow", "wlen": 28.0, "tint": Color(0.8, 0.82, 0.86), "mono": 1.0, "k": 0.95,
		"hp": 45.0, "speed": 4.2, "detect": 17.0, "range": 14.0, "dmg": 9.0, "windup": 0.72, "attack": "shot", "poise": 0.0, "coins": 4, "keep": 9.5, "dodge": 0.2},
	# 灰衣军官：精英，重劈 + 突刺，会喊人
	"officer": {"name": "灰衣军官", "model": "grey_officer", "weapon": "axe2", "wlen": 42.0, "tint": Color(0.75, 0.78, 0.84), "mono": 0.8, "k": 1.2,
		"hp": 380.0, "speed": 4.0, "detect": 30.0, "range": 2.7, "dmg": 19.0, "windup": 0.5, "attack": "heavy", "poise": 60.0, "coins": 22, "dodge": 0.2},
	# ---------- 第二幕 · 扩充：每层两类新小怪 ----------
	# 引魂灯童（青井）：提着纸灯的小骸骨，不打人，躲在后面；隔一阵灯一亮，身边的怪都回血
	"lampkid": {"name": "引魂灯童", "model": "skel_lampkid", "weapon": "", "wlen": 0.0, "tint": Color(0.82, 0.92, 1.05), "k": 0.72,
		"hp": 34.0, "speed": 4.4, "detect": 16.0, "range": 9.0, "dmg": 0.0, "windup": 0.8, "attack": "aura", "poise": 0.0, "coins": 4, "keep": 8.5,
		"offhand": "lantern_h", "olen": 30.0, "aura": "heal"},
	# 井鳗骨（青井）：在积水底下游着跟你，冒头咬一口又潜下去（潜着时打不着）
	"eel": {"name": "井鳗骨", "model": "skel_eel", "weapon": "dagger", "wlen": 20.0, "tint": Color(0.5, 0.95, 1.0), "mono": 0.65, "k": 0.95,
		"hp": 48.0, "speed": 5.0, "detect": 16.0, "range": 2.6, "dmg": 13.0, "windup": 0.34, "attack": "lunge", "poise": 0.0, "coins": 4, "lurk": true, "dive": true, "elem": "water"},
	# 泼油俑（灯冢）：铜俑抱着灯油罐，站远了往你脚下扔，落地烧一摊火
	"oiler": {"name": "泼油俑", "model": "bronze_oiler", "weapon": "", "wlen": 0.0, "tint": Color(1.2, 0.84, 0.5), "mono": 0.7, "k": 1.05,
		"hp": 70.0, "speed": 3.0, "detect": 16.0, "range": 12.0, "dmg": 7.0, "windup": 0.8, "attack": "lob", "poise": 0.0, "coins": 5, "keep": 8.0, "elem": "fire"},
	# 殉灯俑（灯冢）：成对殉葬的铜俑，倒下一个，只要另一个还站着，几秒后又爬起来
	"twin": {"name": "殉灯俑", "model": "bronze_twin", "weapon": "sword", "wlen": 30.0, "tint": Color(1.2, 0.9, 0.55), "mono": 0.6, "k": 1.0,
		"hp": 62.0, "speed": 3.9, "detect": 14.0, "range": 2.3, "dmg": 13.0, "windup": 0.5, "attack": "slash", "poise": 0.0, "coins": 4, "twin": true},
	# 灰衣枪兵（灰衣营）：长枪，隔着四五步就扎过来，扎完退开
	"greyspear": {"name": "灰衣枪兵", "model": "grey_spear", "weapon": "spear", "wlen": 60.0, "tint": Color(0.8, 0.82, 0.87), "mono": 0.9, "k": 1.05,
		"hp": 80.0, "speed": 3.8, "detect": 15.0, "range": 4.6, "dmg": 15.0, "windup": 0.6, "attack": "thrust", "poise": 0.0, "coins": 5, "hitrun": true, "dodge": 0.15},
	# 灰衣旗手（灰衣营）：扛旗的，躲在后面，旗一举，身边的灰衣人发狠（出手更快、更疼）
	"greyflag": {"name": "灰衣旗手", "model": "grey_flag", "weapon": "flag", "wlen": 54.0, "tint": Color(0.8, 0.82, 0.86), "mono": 0.75, "k": 1.0,
		"hp": 75.0, "speed": 3.8, "detect": 16.0, "range": 9.0, "dmg": 10.0, "windup": 0.8, "attack": "aura", "poise": 0.0, "coins": 6, "keep": 7.5, "aura": "rally"},
	# 烬的残影（燃烬时）：灰烬凝成的人影，排开冲过来，打不着
	"ashghost": {"name": "烬影", "model": "jin", "ghost": true, "weapon": "sword", "wlen": 34.0, "tint": Color(1.4, 0.9, 0.7), "mono": 1.0, "k": 1.0,
		"hp": 9999.0, "speed": 3.0, "detect": 40.0, "range": 2.6, "dmg": 15.0, "windup": 0.7, "attack": "charge", "poise": 999.0, "coins": 0, "phantom": true},
	# 执灯使·烬：寂光大弟子，手里是断刀前半截。三段：刀法 → 点第四盏灯（放火、叫人）→ 燃烬（残影冲阵）
	"boss6": {"name": "执灯使·烬", "model": "jin", "weapon": "sword2", "wlen": 50.0, "tint": Color(0.82, 0.8, 0.86), "mono": 1.0, "k": 1.45,
		"hp": 1400.0, "speed": 4.4, "detect": 40.0, "range": 3.0, "dmg": 23.0, "windup": 0.47, "attack": "boss", "poise": 160.0, "coins": 120, "boss": true, "dodge": 0.15},
	"boss5": {"name": "不夜将军", "model": "boss_general", "weapon": "axe2", "wlen": 60.0, "tint": Color(1.3, 0.9, 0.5), "mono": 0.55, "k": 2.0,
		"hp": 1050.0, "speed": 3.2, "detect": 40.0, "range": 3.6, "dmg": 22.0, "windup": 0.62, "attack": "boss", "poise": 150.0, "coins": 90, "boss": true},
	"boss4": {"name": "井中人·枯荣", "model": "boss_kurong", "weapon": "skel_staff", "wlen": 48.0, "tint": Color(0.65, 0.88, 1.15), "k": 1.8,
		"hp": 950.0, "speed": 3.0, "detect": 40.0, "range": 3.4, "dmg": 20.0, "windup": 0.6, "attack": "boss", "poise": 130.0, "coins": 80, "boss": true, "head": "skel_minion"},
	"boss3": {"name": "百骨将", "model": "boss_bones", "weapon": "skel_axe", "wlen": 50.0, "tint": Color(0.9, 1.0, 0.85), "k": 2.0,
		"hp": 1100.0, "speed": 3.3, "detect": 40.0, "range": 3.4, "dmg": 22.0, "windup": 0.65, "attack": "boss", "poise": 140.0, "coins": 75, "boss": true},
	"boss": {"name": "夜樱剑鬼", "model": "boss_sakura", "weapon": "sword2", "wlen": 52.0, "tint": Color(0.78, 0.72, 0.9), "k": 1.55,
		"hp": 900.0, "speed": 3.6, "detect": 40.0, "range": 3.2, "dmg": 20.0, "windup": 0.6, "attack": "boss", "poise": 120.0, "coins": 60, "boss": true},
	"boss2": {"name": "寂光", "model": "boss_jiguang", "weapon": "sword2", "wlen": 56.0, "tint": Color(0.85, 0.9, 1.05), "k": 1.6,
		"hp": 1150.0, "speed": 3.9, "detect": 40.0, "range": 3.4, "dmg": 24.0, "windup": 0.55, "attack": "boss", "poise": 160.0, "coins": 90, "boss": true},
}

var kind := "skeleton"
var data: Dictionary
var state := "spawn"
var st_t := 0.0
var _home := Vector3.ZERO
var detect_mult := 1.0          # 发现主角的距离倍数（大房间的波次怪调大）
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _has_token := false
var _cool := 0.0
var _pose := {}
var _pose_prev := {}
var _blend := 1.0
var _phase := 0.0
var _anim_t := 0.0
var poise := 0.0
var max_poise := 0.0
var _atk := ""
var _atk_dir := Vector3.FORWARD
var _atk_target := Vector3.ZERO
var _leap_from := Vector3.ZERO
var _did_hit := false
var _strafe := 1.0
var _boss_phase := 0
var _combo_n := 0
var _summon_t := 6.0                 # 百骨将：多久召一次小怪
var _spikes: Array[Vector3] = []     # 百骨将：地刺落点
var _retreat_t := 0.0                # 骨刺客：刺完往后退
var _dodge_cd := 0.0                 # 活人（灰衣营）：多久能再闪一次
var _stage3 := false                 # 烬：燃烬（第三段）
var target: Hero
var is_boss := false
var guard := 0.0                     # 盾骷髅：举着盾还能挡几下（挡满就破盾）
var _guard_down := 0.0               # 破盾后多久举不起来
var no_loot := false                 # 被召唤出来的小鬼不掉钱
var _minions: Array[Foe] = []        # 招魂巫招出来的
var _summon_cd := 2.5
var _exploded := false               # 爆骨鬼已经炸过
var _aim: Array[Vector3] = []        # 骨弩手这一轮射哪几个方向
var _lurk_t := 0.0                   # 水骨在水里埋了多久
var _tide_t := 8.0                   # 枯荣：二阶段多久推一次水波
var _armor_down := 0.0               # 烛国甲士：破甲剩余时间
var _aura_cd := 2.5                  # 引魂灯童、灰衣旗手：多久亮一次灯 / 举一次旗
var _auras := 0                      # 亮过几次灯、举过几次旗（旗手没举过旗就被斩：成就）
var _rally := 0.0                    # 被旗手激励：剩余时间（出手更快、更疼，描边发红）
var _rim0 := []                      # 激励前的描边（结束后还原）
var _up_t := 0.0                     # 井鳗骨：冒出水面多久了（久了就潜回去）
static var _twin_dead_t := -100.0    # 殉灯俑：上一只倒下的时间（一秒内打死一对 → 成就）
const AURA_R := 7.0                  # 灯童回血、旗手激励的半径
const SPORE_R := 1.9                 # 瘴菇骨喷出的那团瘴的半径
const BELL_R := 9.0                  # 铜钟僧钟声推多远
var _trampled := {}                  # 冲阵骨这一趟冲锋已经撞翻的自己人（SharedHazards）
var charge_dir := Vector3.ZERO       # 亲兵：列阵冲锋的方向（定好了就不跟着主角转）
var _rank_t := 9.0                   # 不夜将军：多久号令一次亲兵
var _fire_t := 6.0                   # 不夜将军二阶段：多久点一次灯油
## 每种新敌人第一次出现时头上冒一句提示（一次游戏里只冒一次）
static var _seen := {}
const HINTS := {"archer": "骨弩手 · 躲开红线", "charger": "冲阵骨 · 引它撞墙", "bomber": "爆骨鬼 · 先下手",
	"shield": "盾骷髅 · 绕后或连砍破盾", "summoner": "招魂巫 · 先杀它", "shadow": "残影 · 他用的是你的刀法",
	"drowned": "水骨 · 小心脚下的水", "chainmonk": "灯奴僧 · 链子扫一圈，翻滚躲开", "ronin": "阿七 · 续命司的刀法",
	"armored": "烛国甲士 · 铜甲挡刀，先打破韧", "flameskel": "披火骨 · 死后留火，别站进去", "digger": "续命司 · 活人",
	"greyblade": "灰衣刀手 · 砍完就退，会闪", "greyguard": "灰衣盾兵 · 绕后或连砍破盾", "greybow": "灰衣弩手 · 贴上去", "officer": "灰衣军官 · 精英",
	"lampkid": "引魂灯童 · 先打它，灯一亮旁边的回血", "eel": "井鳗骨 · 水下跟着你，冒头就砍", "oiler": "泼油俑 · 别站进橙圈",
	"twin": "殉灯俑 · 成对的，要一起打死", "sporer": "瘴菇骨 · 别站进绿圈，贴上去砍",
	"coffin": "抬棺骨 · 棺盖挡正面，碎了里面还有东西", "bellmonk": "铜钟僧 · 钟声往外推，翻滚穿过去", "greyspear": "灰衣枪兵 · 枪长，侧闪或贴身", "greyflag": "灰衣旗手 · 先砍旗，旗一举旁边的发狠"}
var _trail: BladeTrail
var dmg_scale := 1.0
## 精英词缀（FoeAffix）：带了几条、金罩还剩多少
var affixes: Array[String] = []
var ward := 0.0
var ward_max := 0.0
var _affix_t := 1.0
var _affix_ring: MeshInstance3D
var _ward_fx: MeshInstance3D


## 第一次见到这种敌人时头上冒的提示（子类可以换，见 Act3Foe）
func _hint_text() -> String:
	return String(HINTS.get(kind, ""))


func setup_kind(k: String, hp_scale: float = 1.0, dmg_mult: float = 1.0) -> void:
	kind = k
	data = TYPES[k]
	max_hp = float(data["hp"]) * hp_scale
	hp = max_hp
	dmg_scale = dmg_mult
	max_poise = float(data["poise"])
	poise = max_poise
	is_boss = bool(data.get("boss", false))
	display_name = String(data["name"])
	guard = float(data.get("guard", 0.0))


## 头目外形放大倍数（只管看起来多大）
const BOSS_VIS := {"boss": 1.35, "boss2": 1.3, "boss3": 1.2, "boss4": 1.22, "boss5": 1.2, "boss6": 1.25,
	"boss7": 1.25, "boss8": 1.2, "boss9": 1.25, "boss10": 1.16}


func _ready() -> void:
	team = 1
	super._ready()
	if data.is_empty():
		setup_kind(kind)
	var k := float(data["k"])
	# 头目只放大外形（人偶、碰撞、脚下圈），出招范围仍按 data["k"] 算，难度不变：
	# 镜头拉近后头目也不过主角一倍半高，压不住场，这里统一放到主角两倍多
	if is_boss:
		k *= float(BOSS_VIS.get(kind, 1.2))
	radius = 0.42 * k
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = 1.7 * k
	cs.shape = cap
	cs.position.y = 0.85 * k
	add_child(cs)
	rig = VoxActor.new()
	add_child(rig)
	var mid := String(data["model"])
	# 锻造台做的模型颜色是画好的，不再染色、去色；只有幻影类（ghost）照旧染成一片光
	var forged := VoxelModel.forged(mid)
	var ghost := bool(data.get("ghost", false))
	rig.setup(mid, String(data["weapon"]), float(data["wlen"]), data["tint"] if (ghost or not forged) else Color.WHITE, k)
	if Arena.lod == 0 and not is_boss:
		rig.mat.next_pass = null   # 低画质：小怪不描边（描边是整个人偶再画一遍，成群时绘制调用翻倍）
	# 边缘光跟着区域走：冷色地面（幽林、墓园、樱林、地宫、驿站）用暖色，暖色地面用冷色，怎么都跟地面拉开
	rig.set_rim(zone_rim if not is_boss else Color(1.0, 0.6, 0.8), zone_rim_k if not is_boss else 0.35)
	_make_base_ring(k)
	if data.has("head") and not forged:
		rig.swap_head(String(data["head"]))
	if data.has("mono") and (ghost or not forged):
		rig.mat.set_shader_parameter("mono", float(data["mono"]))
	if data.has("offhand"):
		rig.set_offhand(String(data["offhand"]), float(data.get("olen", 22.0)))
	if data.has("mount"):
		rig.set_mount(String(data["mount"]))   # 冲骑、幽骑：骑马
	match kind:
		"shadow":
			rig.set_rim(Color(0.75, 0.5, 1.0), 1.0)   # 残影：一团墨色人影 + 紫色描边，和主角（白衣）一眼分开
		"bomber":
			rig.set_rim(Color(1.0, 0.55, 0.2), 0.9)
		"summoner":
			rig.set_rim(Color(0.5, 1.0, 0.6), 0.6)
		"charger":
			rig.set_rim(Color(1.0, 0.5, 0.3), 0.5)
		"flameskel":
			rig.set_rim(Color(1.0, 0.5, 0.15), 0.9)
		"phantom":
			rig.set_rim(Color(1.0, 0.8, 0.35), 1.0)
		"ashghost":
			rig.set_rim(Color(1.0, 0.5, 0.25), 1.2)
			rig.set_glow(Color(0.25, 0.08, 0.02))
		"armored":
			rig.set_rim(Color(1.0, 0.75, 0.4), 0.35)
		"lampkid":
			rig.set_rim(Color(1.0, 0.85, 0.5), 0.6)
			var ll := OmniLight3D.new()
			ll.light_color = Color(1.0, 0.8, 0.5)
			ll.light_energy = 1.3
			ll.omni_range = 4.5
			ll.position = Vector3(0.4, 1.1, 0.3)
			add_child(ll)
		"eel":
			rig.set_rim(Color(0.5, 0.9, 1.0), 0.5)
		"oiler":
			rig.set_rim(Color(1.0, 0.55, 0.2), 0.45)
		"twin":
			rig.set_rim(Color(1.0, 0.8, 0.4), 0.4)
		"greyflag":
			rig.set_rim(Color(1.0, 0.45, 0.35), 0.35)
		"sporer":
			rig.set_rim(Color(0.55, 1.0, 0.3), 0.55)
		"coffin":
			rig.set_rim(Color(0.95, 0.85, 0.6), 0.35)
		"bellmonk":
			rig.set_rim(Color(1.0, 0.82, 0.4), 0.5)
	# 精英和头目出刀带拖尾（颜色同时也是“危险”提示）
	if max_poise > 0.0 and rig.weapon != null:
		_trail = BladeTrail.new()
		_trail.actor = self
		_trail.rig = rig
		_trail.life = 0.2 if is_boss else 0.15
		_trail.width_k = 0.75
		add_child(_trail)
		var fc := fx_color()
		_trail.set_colors(Color(1, 0.95, 0.9), fc)
	FoeAffix.dress(self)
	_home = global_position
	_pose = Poses.idle(0.0)
	add_to_group("foes")
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_cool = randf_range(0.3, 1.2)
	if data.get("lurk", false):
		# 水骨：一出来就埋在水里，只看得见一圈涟漪
		_set_state("lurk")
		rig.visible = false
		_layer0 = collision_layer
		collision_layer = 0
		return
	# 出场：从地里冒出来
	rig.scale = Vector3(1, 0.01, 1)
	Vfx.I.dust(global_position, 1.0 * k, Color(0.35, 0.55, 0.55, 0.5))
	Vfx.I.ground(global_position, "magic_01", Color(0.4, 0.9, 1.0, 0.8) if not is_boss else Color(1.0, 0.4, 0.6, 0.9), 0.5, 2.5 * k, 0.6)
	# pixelfx 法阵光柱：小怪青色、头目樱粉
	Vfx.I.sheet("rune-cast" if is_boss else "spawn-cast", global_position, 3.4 * maxf(k, 0.8), Color(1, 1, 1, 0.9), 1.5, false, 0.0, 1.6 if is_boss else 2.6)


## 脚下底圈（foe_base.gdshader）：小怪红、精英金、头目粉
func _make_base_ring(k: float) -> void:
	if _base_shader == null:
		_base_shader = load("res://shaders/arpg/foe_base.gdshader")
	_base_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	var r := 1.5 * k * (1.25 if is_boss else 1.0)
	q.size = Vector2(r, r)
	_base_ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _base_shader
	var c := Color(1.0, 0.28, 0.2)
	if is_boss:
		c = Color(1.0, 0.45, 0.7)
	elif max_poise > 0.0:
		c = Color(1.0, 0.75, 0.3)
	m.set_shader_parameter("ring_color", Vector3(c.r, c.g, c.b))
	_base_ring.material_override = m
	_base_ring.rotation.x = -PI / 2
	_base_ring.position.y = 0.03
	_base_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_base_ring)


func _physics_process(delta: float) -> void:
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_physics_process_body(delta)
	if PerfProbe.on:
		PerfProbe.add("foe", _pt)


func _physics_process_body(delta: float) -> void:
	var dt := tick_common(delta)
	if not alive:
		return
	if dt <= 0.0:
		move_with_knock(Vector3.ZERO, 0.0)
		return
	st_t += dt
	_anim_t += dt
	_cool = maxf(_cool - dt * (1.7 if _rally > 0.0 else 1.0) * (1.45 if affixes.has("frenzy") else 1.0), 0.0)
	if not affixes.is_empty() and state != "lurk":
		FoeAffix.tick(self, dt)
	if _rally > 0.0:
		_rally -= dt
		if _rally <= 0.0 and _rim0.size() == 2:
			rig.mat.set_shader_parameter("rim_color", _rim0[0])
			rig.mat.set_shader_parameter("rim_strength", _rim0[1])
	if state != "lurk" and data.has("dive"):
		_up_t += dt
	if max_poise > 0.0 and state != "stagger":
		poise = minf(poise + max_poise * 0.12 * dt, max_poise)
	target = _pick_target()
	if _guard_down > 0.0:
		_guard_down -= dt
		if _guard_down <= 0.0:
			guard = float(data.get("guard", 0.0))
			if rig.offhand != null:
				rig.offhand.visible = true
	if _armor_down > 0.0:
		_armor_down -= dt
	if kind == "flameskel" and state != "windup":
		rig.set_glow(Color(1.0, 0.4, 0.1) * (0.18 + 0.1 * sin(_anim_t * 7.0)))
	if kind == "bomber" and state != "windup":
		# 爆骨鬼身上一直一明一暗地烧着
		rig.set_glow(Color(1.0, 0.45, 0.1) * (0.25 + 0.2 * sin(_anim_t * 9.0)))
	match state:
		"spawn":
			rig.scale = Vector3(1, minf(st_t / 0.45, 1.0), 1)
			move_with_knock(Vector3.ZERO, dt)
			_pose = Poses.idle(_anim_t)
			if st_t >= 0.45:
				rig.scale = Vector3.ONE
				_set_state("patrol")
				if data.has("phantom"):
					_has_token = false
					_begin_attack("charge")
				if _hint_text() != "" and not _seen.has(kind):
					_seen[kind] = true
					Feel.I.callout(head_top() + Vector3(0, 0.3, 0), _hint_text(), Color(1.0, 0.9, 0.6), 2.2)
		"lurk":
			_st_lurk(dt)
		"patrol":
			_st_patrol(dt)
		"chase":
			_st_chase(dt)
		"windup":
			_st_windup(dt)
		"attack":
			_st_attack(dt)
		"recover":
			move_with_knock(Vector3.ZERO, dt)
			if st_t >= _recover_time():
				_release()
				if data.has("dive") and randf() < 0.75:
					_submerge()
				else:
					_set_state("chase")
		"stagger":
			move_with_knock(Vector3.ZERO, dt)
			_pose = Poses.hurt(st_t / maxf(hit_stun, 0.2))
			if st_t >= maxf(hit_stun, 0.2):
				_set_state("chase")
	_apply_pose(dt)


func _pick_target() -> Hero:
	var best: Hero = null
	var bd := 1e9
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = hh
	return best


func _set_state(s: String) -> void:
	state = s
	st_t = 0.0
	if _base_ring != null:
		_base_ring.visible = s != "lurk" and alive
	if _trail != null:
		_trail.active = s == "attack"
	_pose_prev = _pose
	_blend = 0.0


func _release() -> void:
	if _has_token:
		_has_token = false
		tokens = maxi(tokens - 1, 0)
	rig.set_glow(Color(0, 0, 0))


func _recover_time() -> float:
	match _atk:
		"heavy", "leap":
			return 0.9
		"boss_combo", "boss_leap", "boss_wave":
			return 0.6 if _boss_phase == 0 else 0.4
		"rune", "shot", "volley", "summon_s":
			return 0.45
		"chain":
			return 1.0
		"boss_chain", "boss_tide", "boss_rank", "boss_fire":
			return 0.6 if _boss_phase == 0 else 0.4
		"charge":
			return 0.6
		"aura", "lob":
			return 0.5
		"thrust":
			return 0.6
	return 0.55


func _dist_to_target() -> float:
	if target == null:
		return 1e9
	return Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for f: Node in get_tree().get_nodes_in_group("foes"):
		if f == self:
			continue
		var a := f as Actor
		if a == null or not a.alive:
			continue
		var d := global_position - a.global_position
		d.y = 0
		var l := d.length()
		var r := radius + a.radius + 0.5
		if l < r and l > 0.001:
			push += d / l * (r - l) / r
	return push


func _walk(v: Vector3, dt: float) -> void:
	var sp := v.length() / maxf(float(data["speed"]), 0.1)
	_phase += dt * (5.0 + 6.0 * sp)
	if v.length() > 0.2:
		if guard > 0.0 and target != null:
			# 盾骷髅不跟着脚转身，盾一直慢慢对着主角（所以绕到侧后面就能砍）
			var td := target.global_position - global_position
			face_to(facing.slerp(td.normalized(), 1.0 - exp(-2.5 * dt)))
		else:
			face_to(facing.slerp(v.normalized(), 1.0 - exp(-10.0 * dt)) if facing.dot(v.normalized()) > -0.9 else v)
		_pose = Poses.run(_phase, clampf(sp, 0.0, 1.0) * 0.85)
	else:
		_pose = Poses.idle(_anim_t)
	move_with_knock(v + _separation() * 3.0, dt)


## 水骨埋在水里：隔一会儿冒一圈涟漪；主角走近（或者等太久）就破水而出，直接扑过去
func _st_lurk(dt: float) -> void:
	_lurk_t += dt
	var dive := data.has("dive")
	if dive and target != null and _lurk_t > 0.4:
		# 井鳗骨在水底下游着跟过来：只看得见一串涟漪
		var to := target.global_position - global_position
		to.y = 0
		move_with_knock(to.normalized() * float(data["speed"]) * 0.7 if to.length() > 0.5 else Vector3.ZERO, dt)
		if int(_lurk_t * 2.5) != int((_lurk_t - dt) * 2.5):
			Vfx.I.ground(global_position, "lm_ring_b", Color(0.5, 0.85, 1.0, 0.45), 0.3, 1.6, 0.8)
	else:
		move_with_knock(Vector3.ZERO, dt)
		if int(_lurk_t * 0.8) != int((_lurk_t - dt) * 0.8):
			Vfx.I.ground(global_position, "lm_ring_b", Color(0.5, 0.85, 1.0, 0.5), 0.4, 2.2, 1.1)
	var near := target != null and _dist_to_target() < (3.4 if dive else 5.5) and (not dive or _lurk_t > 1.0)
	if near or _lurk_t > 9.0:
		rig.visible = true
		_restore_layer()
		Vfx.I.chips(global_position + Vector3(0, 0.3, 0), Vector3.UP, Color(0.55, 0.85, 1.0), 16, 7.0, 0.1)
		Vfx.I.shock_ring(global_position, Color(0.5, 0.85, 1.0), 0.3, 3.0, 0.35)
		Vfx.I.dust(global_position, 1.2, Color(0.5, 0.75, 0.9, 0.55))
		if not FoeSfx.play(self, "emerge"):
			Game.sfx("slash", -8.0, 0.1, 0.7)
		_set_state("chase")
		if near and _get_token():
			_begin_attack("lunge")
		if _hint_text() != "" and not _seen.has(kind):
			_seen[kind] = true
			Feel.I.callout(head_top() + Vector3(0, 0.3, 0), _hint_text(), Color(1.0, 0.9, 0.6), 2.2)


var _layer0 := -1


## 井鳗骨潜回水里：溅一圈水花，身子看不见、打不着，接着在水底跟人
func _submerge() -> void:
	_release()
	_up_t = 0.0
	_lurk_t = 0.0
	rig.visible = false
	if _layer0 < 0:
		_layer0 = collision_layer
	collision_layer = 0
	Vfx.I.chips(global_position + Vector3(0, 0.3, 0), Vector3.UP, Color(0.55, 0.85, 1.0), 10, 5.0, 0.09)
	Vfx.I.shock_ring(global_position, Color(0.5, 0.85, 1.0), 0.3, 2.2, 0.3)
	FoeSfx.play(self, "submerge")
	_set_state("lurk")


func _restore_layer() -> void:
	if _layer0 >= 0:
		collision_layer = _layer0


func _st_patrol(dt: float) -> void:
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.0, 2.5)
		var a := randf() * TAU
		_wander = (_home + Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 3.0) - global_position)
		_wander.y = 0
		if randf() < 0.4:
			_wander = Vector3.ZERO
	var v := Vector3.ZERO
	if _wander.length() > 0.5:
		v = _wander.normalized() * float(data["speed"]) * 0.35
		_wander -= v * dt
	_walk(v, dt)
	if target != null and _dist_to_target() < float(data["detect"]) * detect_mult:
		_set_state("chase")
		# 发现主角：头上冒个“!”
		Feel.I.callout(head_top(), "!", Color(1.0, 0.35, 0.3), 0.9)


func _st_chase(dt: float) -> void:
	if target == null:
		_walk(Vector3.ZERO, dt)
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else facing
	var speed := float(data["speed"])
	var rng := float(data["range"])
	var v := Vector3.ZERO
	if data.has("dive") and _up_t > 4.0 and not _has_token:
		_submerge()
		return
	if kind == "boss3":
		_summon_t -= dt
		if _summon_t <= 0.0 and _cool <= 0.0 and get_tree().get_nodes_in_group("foes").size() < 7:
			_summon_t = 11.0 if _boss_phase == 0 else 7.5
			_get_token()
			_begin_attack("boss_summon")
			return
	if data.has("dodge") and _retreat_t <= 0.0:
		# 活人：你挥刀的时候，他偶尔侧身闪开（闪开那一下打不着）
		_dodge_cd -= dt
		if _dodge_cd <= 0.0 and dist < 3.4 and target.state == "attack":
			_dodge_cd = 1.4
			if randf() < float(data["dodge"]):
				_retreat_t = 0.4
				_strafe = -1.0 if randf() < 0.5 else 1.0
				iframes = 0.3
				Vfx.I.dust(global_position, 0.9, Color(0.7, 0.65, 0.6, 0.5))
				Feel.I.callout(head_top(), "闪", Color(0.85, 0.85, 0.9), 0.5)
	if kind == "boss6":
		# 烬：二段起隔一阵点火、叫人；燃烬后隔一阵放残影冲阵
		if _boss_phase >= 1:
			_fire_t -= dt
			_summon_t -= dt
		if _stage3:
			_rank_t -= dt
		if _cool <= 0.0 and _retreat_t <= 0.0:
			if _stage3 and _rank_t <= 0.0 and _get_token():
				_rank_t = randf_range(7.0, 9.0)
				_begin_attack("boss_rank")
				return
			if _boss_phase >= 1 and _fire_t <= 0.0 and _get_token():
				_fire_t = randf_range(8.0, 10.0)
				_begin_attack("boss_fire")
				return
			if _boss_phase >= 1 and _summon_t <= 0.0 and get_tree().get_nodes_in_group("foes").size() < 5 and _get_token():
				_summon_t = randf_range(13.0, 16.0)
				_begin_attack("boss_summon")
				return
	if _retreat_t > 0.0:
		# 骨刺客刺完一下就斜着退开，再找机会
		_retreat_t -= dt
		_walk((-dir + dir.cross(Vector3.UP) * _strafe * 0.7).normalized() * speed * 0.9, dt)
		face_to(facing.slerp(dir, 1.0 - exp(-8.0 * dt)))
		return
	if kind == "bomber":
		# 爆骨鬼不排队，直接冲上来，贴脸就点火
		if dist < rng:
			_begin_attack("blast")
			return
		_walk(dir * speed, dt)
		return
	if kind == "summoner":
		_summon_cd -= dt
		# 不能用 filter + 带类型的 lambda：小鬼被释放后传进去会报 “Cannot convert argument”，结果也不是 Array[Foe]
		var live: Array[Foe] = []
		for m in _minions:
			if is_instance_valid(m) and m.alive:
				live.append(m)
		_minions = live
		if _summon_cd <= 0.0 and _cool <= 0.0 and _minions.size() < 3 and get_tree().get_nodes_in_group("foes").size() < 10:
			_summon_cd = randf_range(7.0, 9.0)
			_begin_attack("summon_s")
			return
	if data.has("keep"):
		var keep := float(data.get("keep", 7.0))
		if dist < keep - 1.5:
			v = -dir * speed
		elif dist > keep + 2.0:
			v = dir * speed
		else:
			v = dir.cross(Vector3.UP) * _strafe * speed * 0.5
		if data.has("aura"):
			# 灯童、旗手：身边有同伴（灯童要有带伤的）就亮灯 / 举旗；旗手被贴脸了也会拿旗杆抡一下
			_aura_cd -= dt
			if kind == "greyflag" and dist < 2.6 and _cool <= 0.0 and _get_token():
				_begin_attack("slash")
				return
			if _aura_cd <= 0.0 and _cool <= 0.0 and _aura_allies() > 0:
				_aura_cd = randf_range(5.5, 7.0)
				_begin_attack("aura")
				return
		elif _cool <= 0.0 and dist < rng and _get_token():
			if data["attack"] == "shot":
				_begin_attack("volley" if randf() < 0.3 else "shot")
			elif data["attack"] == "lob":
				_begin_attack("lob")
			elif data["attack"] in ["spore", "bell"]:
				_begin_attack(String(data["attack"]))
			else:
				_begin_attack("rune")
			return
	else:
		if dist > rng * 0.85:
			# 没拿到令牌的敌人在外圈绕着走
			var circling := tokens >= MAX_TOKENS and not _has_token and dist < rng + 3.5
			if circling:
				v = (dir.cross(Vector3.UP) * _strafe * 0.8 + dir * 0.1) * speed * 0.6
			else:
				v = dir * speed
		elif _cool <= 0.0 and _get_token():
			_begin_attack(_choose_attack(dist))
			return
		else:
			v = dir.cross(Vector3.UP) * _strafe * speed * 0.35
		if kind == "charger" and _cool <= 0.0 and dist > 4.5 and dist < 13.0 and randf() < dt * 1.5 and _get_token():
			_begin_attack("charge")
			return
		if kind == "samurai" and _cool <= 0.0 and dist > 4.0 and dist < 9.0 and randf() < dt * 0.8 and _get_token():
			_begin_attack("leap")
			return
		if kind == "boss5":
			_rank_t -= dt
			if _boss_phase == 1:
				_fire_t -= dt
			if _rank_t <= 0.0 and _cool <= 0.0 and _get_token():
				_rank_t = randf_range(10.0, 13.0) if _boss_phase == 0 else randf_range(7.5, 9.5)
				_begin_attack("boss_rank")
				return
			if _boss_phase == 1 and _fire_t <= 0.0 and _cool <= 0.0 and _get_token():
				_fire_t = randf_range(6.0, 8.0)
				_begin_attack("boss_fire")
				return
		if kind == "boss4" and _boss_phase == 1:
			_tide_t -= dt
			if _tide_t <= 0.0 and _cool <= 0.0 and _get_token():
				_tide_t = randf_range(6.5, 8.5)
				_begin_attack("boss_tide")
				return
		if is_boss and _cool <= 0.0 and dist > 5.0 and randf() < dt * 1.2 and _get_token():
			if kind == "boss4":
				_begin_attack("boss_spikes" if randf() < 0.7 else "boss_leap")
			elif kind == "boss5":
				_begin_attack("boss_leap")
			elif kind == "boss6":
				_begin_attack("boss_wave" if randf() < 0.55 else "boss_leap")
			elif kind == "boss3":
				_begin_attack("boss_spikes" if randf() < 0.6 else "boss_leap")
			else:
				_begin_attack("boss_leap" if randf() < 0.5 else "boss_wave")
			return
	_walk(v, dt)
	face_to(facing.slerp(dir, 1.0 - exp((-2.5 if guard > 0.0 else -8.0) * dt)))


func _get_token() -> bool:
	if _has_token:
		return true
	if is_boss:
		_has_token = true
		tokens += 1
		return true
	if tokens < MAX_TOKENS:
		tokens += 1
		_has_token = true
		return true
	return false


func _choose_attack(_dist: float) -> String:
	match kind:
		"crawler":
			return "lunge"
		"samurai":
			return "heavy"
		"shadow":
			return "lunge" if randf() < 0.45 else "slash"
		"rogue":
			return "lunge"
		"charger":
			return "heavy"
		"shield":
			return "bash" if guard > 0.0 and randf() < 0.4 else "slash"
		"coffin":
			return "bash" if guard > 0.0 and randf() < 0.35 else "heavy"
		"boss", "boss2":
			return "boss_combo"
		"chainmonk":
			return "chain" if _dist <= 4.2 else "slash"
		"ronin":
			return "lunge" if randf() < 0.35 else "slash"
		"boss4":
			return "boss_chain" if randf() < 0.35 else "boss_combo"
		"boss5":
			return "boss_chain" if randf() < 0.4 else "boss_combo"
		"boss6":
			return "lunge" if randf() < 0.3 else "boss_combo"
		"officer":
			return "lunge" if randf() < 0.3 else "heavy"
		"greyspear":
			return "thrust"
		"digger":
			return "heavy" if randf() < 0.5 else "slash"
		"boss3":
			return "boss_spikes" if randf() < 0.25 else "boss_combo"
	return "slash"


func _windup_time() -> float:
	var w := float(data["windup"])
	match _atk:
		"leap", "boss_leap":
			return 0.35
		"boss_combo":
			return 0.55 if _boss_phase == 0 else 0.4
		"boss_wave":
			return 0.7
		"boss_summon":
			return 0.9
		"boss_spikes":
			return 0.75 if _boss_phase == 0 else 0.6
		"charge":
			return 0.8
		"volley":
			return w + 0.2
		"summon_s":
			return 0.9
		"bash":
			return 0.45
		"chain":
			return w
		"boss_chain":
			return 0.85 if _boss_phase == 0 else 0.65
		"boss_tide":
			return 0.8
		"boss_rank":
			return 0.7
		"boss_fire":
			return 0.6
		"spore":
			return w
		"bell":
			return w
	return w


func _begin_attack(kind_: String) -> void:
	_atk = kind_
	_did_hit = false
	_trampled.clear()
	_combo_n = 0
	_set_state("windup")
	_blend = 0.3
	if target != null:
		_atk_dir = (target.global_position - global_position)
		_atk_dir.y = 0
		_atk_dir = _atk_dir.normalized() if _atk_dir.length() > 0.01 else facing
		_atk_target = target.global_position
		face_to(_atk_dir)
	if charge_dir != Vector3.ZERO:
		_atk_dir = charge_dir
		face_to(_atk_dir)
	var wt := _windup_time()
	# 预警配色统一用 Vfx.DANGER（红刀斧、橙红箭、紫法术、橙火、绿毒、青水、金钟声、白紫雷）
	var red: Color = Vfx.DANGER["melee"]
	match _atk:
		"slash", "boss_combo":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * (float(data["range"]) + 0.6), 2.6 * float(data["k"]), red, wt)
		"heavy":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.6, 2.2, red, wt)
		"lunge":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.2, 1.0, red, wt)
		"rune":
			Vfx.I.telegraph_circle(_atk_target, 1.7, Vfx.DANGER["magic"], wt + 0.55)
			# 法阵在落点慢慢亮起，光柱刚好在出手那一下打下来
			Vfx.I.sheet("rune-cast", _atk_target, 3.0, Color(0.9, 0.7, 1.0, 0.95), 1.6, false, 0.0, 2.0 / (wt + 0.55))
		"leap", "boss_leap":
			_atk_target = target.global_position + target.velocity * 0.25 if target != null else global_position
			Vfx.I.telegraph_circle(_atk_target, 2.4 if _atk == "leap" else 3.2, red, wt + 0.65)
		"boss_wave":
			for i in range(5):
				var a := -0.6 + 0.3 * i
				var d := _atk_dir.rotated(Vector3.UP, a)
				Vfx.I.telegraph_rect(global_position, global_position + d * 12.0, 1.1, red, wt)
		"boss_spikes":
			# 骨刺从地下顶出来：一排朝主角，加几根落在主角身边
			_spikes.clear()
			var n := 5 if _boss_phase == 0 else 7
			for i in range(n):
				_spikes.append(global_position + _atk_dir * (2.5 + i * 1.8))
			if target != null:
				for i in range(2 + _boss_phase * 2):
					var a := randf() * TAU
					_spikes.append(target.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.5))
			for s in _spikes:
				Vfx.I.telegraph_circle(s, 1.2, Vfx.DANGER["bone"] if kind != "boss4" else Vfx.DANGER["water"], wt)
		"boss_summon":
			Vfx.I.ground(global_position, "magic_01", Vfx.DANGER["summon"], 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "起来！" if kind != "boss6" else "灰衣营——上！", Color(0.7, 1.0, 0.7) if kind != "boss6" else Color(0.85, 0.85, 0.9), 1.0)
		"shot", "volley":
			# 红线是箭的路线：开弓前就定了方向，横着一步就能躲
			_aim.clear()
			var lead := target.velocity * 0.15 if target != null else Vector3.ZERO
			var ad := (_atk_target + lead - global_position)
			ad.y = 0
			ad = ad.normalized() if ad.length() > 0.01 else facing
			for a in ([0.0] if _atk == "shot" else [-0.28, 0.0, 0.28]):
				var d := ad.rotated(Vector3.UP, a)
				_aim.append(d)
				Vfx.I.telegraph_rect(global_position, global_position + d * 15.0, 0.45, Vfx.DANGER["shot"], wt)
			_atk_dir = ad
			face_to(ad)
		"charge":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 15.0, 1.9, red, wt)
			Feel.I.callout(head_top(), "冲!", Color(1.0, 0.5, 0.3), 0.8)
		"blast":
			Vfx.I.telegraph_circle(global_position, 2.8, Vfx.DANGER["fire"], wt)
			Game.sfx("flame", -6.0, 0.1, 1.4)
		"summon_s":
			Vfx.I.ground(global_position, "magic_01", Vfx.DANGER["summon"], 0.5, 4.0, wt + 0.3)
			Vfx.I.sheet("spawn-cast", global_position, 3.0, Color(0.6, 1.0, 0.7, 0.9), 1.6, false, 0.0, 1.6)
		"bash":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * 3.0, 1.8, red, wt)
		"chain", "boss_chain":
			# 灯链横扫一整圈：脚下一圈青色预警，越涨越满
			Vfx.I.telegraph_circle(global_position, _chain_r(), Vfx.DANGER["water"] if kind != "boss5" else Vfx.DANGER["fire"], wt)
			Feel.I.callout(head_top(), "链!" if kind != "boss5" else "扫!", Color(0.6, 0.9, 1.0) if kind != "boss5" else Color(1.0, 0.75, 0.4), 0.8)
		"boss_rank":
			Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.8, 0.4, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "列阵——冲!" if kind != "boss6" else "烬——", Color(1.0, 0.85, 0.45) if kind != "boss6" else Color(1.0, 0.55, 0.3), 1.2)
		"boss_fire":
			Vfx.I.ground(global_position, "magic_01", Color(1.0, 0.5, 0.15, 0.8), 0.5, 5.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "点灯!", Color(1.0, 0.6, 0.25), 1.0)
		"thrust":
			Vfx.I.telegraph_rect(global_position, global_position + _atk_dir * (float(data["range"]) + 0.8), 0.9, red, wt)
		"lob":
			_atk_target = target.global_position + target.velocity * 0.3 if target != null else global_position
			_atk_target.y = 0.0
			Vfx.I.telegraph_circle(_atk_target, 1.8, Vfx.DANGER["fire"], wt + FoeLob.FLIGHT)
		"aura":
			var heal := String(data.get("aura", "")) == "heal"
			Vfx.I.ground(global_position, "magic_01", Color(0.5, 1.0, 0.75, 0.7) if heal else Color(1.0, 0.35, 0.25, 0.7), 0.5, AURA_R * 2.0, wt + 0.3)
			Feel.I.callout(head_top(), "灯亮了" if heal else "举旗!", Color(0.7, 1.0, 0.8) if heal else Color(1.0, 0.5, 0.35), 0.8)
		"spore":
			# 瘴菇骨：落点一圈绿，喷出去的瘴落地就是一滩毒
			_atk_target = target.global_position + target.velocity * 0.35 if target != null else global_position
			_atk_target.y = 0.0
			Vfx.I.telegraph_circle(_atk_target, SPORE_R, Vfx.DANGER["poison"], wt + 0.25)
		"bell":
			# 铜钟僧：脚下一圈金光慢慢涨满，钟声出手时往外推一圈金环（只在环的前沿判定）
			Vfx.I.telegraph_circle(global_position, 2.0, Vfx.DANGER["holy"], wt)
			Vfx.I.ground(global_position, "magic_01", Vfx.DANGER["holy"], 0.5, BELL_R * 0.9, wt + 0.3)
			Feel.I.callout(head_top(), "铛!", Color(1.0, 0.85, 0.45), 0.8)
		"boss_tide":
			Vfx.I.ground(global_position, "magic_01", Color(0.4, 0.8, 1.0, 0.8), 0.5, 6.0, wt + 0.3)
			Feel.I.callout(head_top() + Vector3(0, 0.4, 0), "水来了——翻滚!", Color(0.6, 0.9, 1.0), 1.2)
	Game.sfx("danger", -8.0)
	FoeSfx.play(self, "windup:" + _atk)


func _st_windup(dt: float) -> void:
	var wt := _windup_time()
	var k := clampf(st_t / wt, 0.0, 1.0)
	move_with_knock(Vector3.ZERO, dt)
	# 红色预警：身上越来越红地闪
	var pulse := 0.5 + 0.5 * sin(st_t * (28.0 if _atk != "blast" else 20.0 + 50.0 * k))
	var gc := Color(1.0, 0.1, 0.05) if _atk != "blast" else Color(1.0, 0.55, 0.1) * 1.6
	if _atk == "aura":
		gc = Color(0.4, 1.0, 0.6) if String(data.get("aura", "")) == "heal" else Color(1.0, 0.4, 0.2)
	elif _atk == "spore":
		gc = Color(0.45, 1.0, 0.2)
	elif _atk == "bell":
		gc = Color(1.0, 0.8, 0.3)
	rig.set_glow(gc * (0.25 + 0.6 * k) * pulse)
	match _atk:
		"aura", "spore":
			_pose = Poses.cast(k, _anim_t)
		"bell":
			_pose = Poses.windup("enemy_v", k, st_t)
		"lob":
			_pose = Poses.windup("enemy_v", k, st_t)
		"thrust":
			_pose = _aim_pose(k * 0.5)
			_pose["lean"] = -0.15 * k
		"rune", "boss_summon", "summon_s":
			_pose = Poses.cast(k, _anim_t)
		"shot", "volley":
			_pose = _aim_pose(k)
		"charge":
			_pose = Poses.dash_ready(k)
			if randf() < dt * 8.0:
				Vfx.I.dust(global_position - _atk_dir * 0.6, 0.6, Color(0.5, 0.45, 0.4, 0.5))
		"blast":
			_pose = Poses.hurt(0.4 + 0.3 * sin(st_t * 30.0))
			# 越涨越大、越闪越快
			var sw := 1.0 + 0.35 * k + 0.05 * sin(st_t * (20.0 + 40.0 * k))
			rig.scale = Vector3(sw, sw, sw)
		"bash":
			_pose = Poses.windup("enemy_h", k, st_t)
		"chain", "boss_chain":
			_pose = Poses.windup("enemy_h", k, st_t)
			_pose["twist"] = -0.9 * k
		"boss_tide", "boss_fire":
			_pose = Poses.cast(k, _anim_t)
		"boss_rank":
			_pose = Poses.windup("enemy_v", k, st_t)
		"boss_spikes":
			_pose = Poses.windup("enemy_v", k, st_t)
		"leap", "boss_leap":
			_pose = Poses.dash_ready(k)
		"lunge":
			_pose = Poses.dash_ready(k)
		"heavy", "boss_wave":
			_pose = Poses.windup("enemy_v", k, st_t)
		_:
			_pose = Poses.windup("enemy_h", k, st_t)
	if st_t >= wt:
		rig.set_glow(Color(0, 0, 0))
		_leap_from = global_position
		_set_state("attack")
		_blend = 1.0
		if _atk in ["slash", "heavy", "boss_combo", "lunge", "bash", "thrust"]:
			Game.sfx("slash_heavy" if _atk == "heavy" else "slash", -4.0, 0.1)
		elif _atk in ["shot", "volley"]:
			Game.sfx("bow", -4.0, 0.1)
		FoeSfx.play(self, "release:" + _atk)


func _st_attack(dt: float) -> void:
	match _atk:
		"slash", "boss_combo":
			var dur := 0.32
			var k := st_t / dur
			_pose = Poses.swing("enemy_h" if _combo_n % 2 == 0 else "h_lr", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(_atk_dir * (3.0 if k < 0.4 else 0.0), dt)
			if not _did_hit and k >= 0.25:
				_did_hit = true
				var base := Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 0.9 * float(data["k"]), 0))
				var a0 := deg_to_rad(110) if _combo_n % 2 == 0 else deg_to_rad(-110)
				Vfx.I.slash(base, float(data["range"]) * 0.95, a0, -a0, 0.2 if not is_boss else 0.26, Color(1.0, 0.85, 0.8),
					Color(1.0, 0.2, 0.15) if not is_boss else fx_color(), 2.2 if not is_boss else 3.0)
				_melee_hit(float(data["range"]) + 0.3, 130.0, float(data["dmg"]), HitInfo.Weight.LIGHT if not is_boss else HitInfo.Weight.HEAVY)
			if k >= 1.0:
				if is_boss and _combo_n < (1 if _boss_phase == 0 else 2):
					_combo_n += 1
					_did_hit = false
					st_t = 0.0
					if target != null:
						_atk_dir = (target.global_position - global_position)
						_atk_dir.y = 0
						_atk_dir = _atk_dir.normalized()
						face_to(_atk_dir)
					return
				_end_attack()
		"heavy":
			var dur := 0.45
			var k := st_t / dur
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.35, 0, 1), clampf((k - 0.35) / 0.65, 0, 1))
			move_with_knock(_atk_dir * (4.0 if k < 0.35 else 0.0), dt)
			if not _did_hit and k >= 0.3:
				_did_hit = true
				var p := global_position + _atk_dir * 2.4
				Vfx.I.dust(p, 2.0)
				Vfx.I.shock_ring(p, Color(1.0, 0.5, 0.3), 0.5, 3.5, 0.3)
				Vfx.I.chips(p, Vector3.UP, Color(0.35, 0.33, 0.3), 12, 7.0, 0.12)
				CamRig.I.shake(1)
				Game.sfx("boom", -6.0)
				_area_hit(p, 1.9, float(data["dmg"]), HitInfo.Weight.HEAVY)
			if k >= 1.0:
				_end_attack()
		"lunge":
			var dur := 0.3
			var k := st_t / dur
			_pose = Poses.roll(k * 0.5)
			move_with_knock(_atk_dir * (11.0 * (1.0 - k)), dt)
			if not _did_hit and target != null and target.global_position.distance_to(global_position) < radius + target.radius + 0.6:
				_did_hit = true
				_hit_target(target, float(data["dmg"]), HitInfo.Weight.LIGHT)
			if k >= 1.0:
				_end_attack()
		"rune":
			var k := st_t / 0.55
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 1.0:
				_did_hit = true
				Vfx.I.pop(_atk_target + Vector3(0, 0.6, 0), "magic_05", Color(0.8, 0.3, 1.0), 1.0, 4.0, 0.35, true, 0.0, 3.0)
				Vfx.I.pop(_atk_target + Vector3(0, 0.6, 0), "twirl_01", Color(0.9, 0.5, 1.0), 0.6, 3.0, 0.3)
				Vfx.I.shock_ring(_atk_target, Color(0.8, 0.3, 1.0), 0.4, 3.6, 0.3)
				Game.sfx("flame", -4.0)
				_area_hit(_atk_target, 1.7, float(data["dmg"]), HitInfo.Weight.LIGHT)
				_end_attack()
		"leap", "boss_leap":
			var dur := 0.65
			var k := clampf(st_t / dur, 0.0, 1.0)
			var p := _leap_from.lerp(_atk_target, Poses.ease_in_out(k))
			global_position = Vector3(p.x, 0, p.z)
			rig.position.y = sin(k * PI) * (3.2 if _atk == "leap" else 4.5)
			_pose = Poses.leap(k)
			if k >= 1.0 and not _did_hit:
				_did_hit = true
				rig.position.y = 0
				var r := 2.4 if _atk == "leap" else 3.2
				Vfx.I.dust(global_position, r * 1.2, Color(0.55, 0.55, 0.5, 0.6))
				Vfx.I.shock_ring(global_position, Color(1.0, 0.45, 0.25), 0.5, r * 2.0, 0.35)
				Vfx.I.chips(global_position, Vector3.UP, Color(0.35, 0.33, 0.3), 18, 8.0, 0.13)
				Vfx.I.ground(global_position, "scorch_01", Color(0.05, 0.04, 0.04, 0.7), r * 1.6, r * 1.8, 1.5, false)
				Vfx.I.sheet("ground-slam", global_position, r * 1.5, Color(1.0, 0.9, 0.85), 1.4, false, 0.0, 1.5)
				if is_boss:
					# 头目落地：一圈本色的放射线 + 第二道冲击环，镜头往下一砸
					for i in range(8):
						Vfx.I.streaks(global_position + Vector3(0, 0.4, 0), Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)), fx_color(), 1, r * 1.3, 0.25, 0.05, 0.2)
					Vfx.I.shock_ring(global_position, fx_color(), 0.3, r * 3.2, 0.5)
					CamRig.I.kick(Vector3(0, 0, 1), 0.3, 0.015)
				CamRig.I.shake(2)
				Game.sfx("boom", -2.0)
				_area_hit(global_position, r, float(data["dmg"]) * 1.2, HitInfo.Weight.HEAVY)
			if st_t >= dur + 0.15:
				_end_attack()
		"boss_spikes":
			var k := st_t / 0.45
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.3, 0, 1), clampf((k - 0.3) / 0.7, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.25:
				_did_hit = true
				var water := kind == "boss4"
				for s in _spikes:
					# 百骨将：骨刺；枯荣：水柱
					Vfx.I.chips(s, Vector3.UP, Color(0.9, 0.9, 0.8) if not water else Color(0.6, 0.9, 1.0), 8 if not water else 14, 9.0 if not water else 11.0, 0.12 if not water else 0.1)
					Vfx.I.shock_ring(s, Color(0.7, 1.0, 0.6) if not water else Color(0.5, 0.85, 1.0), 0.2, 2.4, 0.25)
					Vfx.I.streaks(s, Vector3.UP, Color(0.8, 1.0, 0.7) if not water else Color(0.6, 0.95, 1.0), 3 if not water else 5, 2.4 if not water else 3.4, 0.22, 0.25, 0.2)
					_area_hit(s, 1.2, float(data["dmg"]) * 0.9, HitInfo.Weight.LIGHT)
				CamRig.I.shake(1)
				Game.sfx("death" if not water else "slash_heavy", -6.0)
			if k >= 1.0:
				_end_attack()
		"boss_summon":
			var k := st_t / 0.5
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var main := get_parent()
				var n := (3 if _boss_phase == 0 else 4) if kind != "boss6" else 2
				for i in range(n):
					var a := TAU * i / n + randf() * 0.5
					var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.0
					var sk := "crawler" if i % 2 == 0 or _boss_phase == 0 else "rogue"
					if kind == "boss6":
						sk = "greyblade" if i == 0 else "greybow"
					if main.has_method("_spawn_foe"):
						main._spawn_foe(sk, p, i * 0.15)
				Game.sfx("boom", -6.0)
			if k >= 1.0:
				_end_attack()
		"shot", "volley":
			var k := st_t / 0.3
			_pose = _aim_pose(1.0 - k * 0.4)
			move_with_knock(-_atk_dir * 2.0 * (1.0 - k), dt)
			if not _did_hit:
				_did_hit = true
				for d in _aim:
					_shoot(d)
			if k >= 1.0:
				_end_attack()
		"charge":
			var dur := 1.05
			var k := st_t / dur
			_phase += dt * 16.0
			_pose = Poses.run(_phase, 1.0)
			_pose["lean"] = 0.5
			move_with_knock(_atk_dir * 16.0 * (1.0 - k * 0.3), dt)
			if Vfx.I.lod > 0 and randf() < dt * 20.0:
				Vfx.I.dust(global_position, 0.7, Color(0.5, 0.45, 0.4, 0.45))
			if not _did_hit:
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh != null and hh.alive and hh.global_position.distance_to(global_position) < radius + hh.radius + 0.5:
						_did_hit = true
						_hit_target(hh, float(data["dmg"]), HitInfo.Weight.HEAVY)
			# 敌我共享：冲锋路上的自己人也被撞翻（每个只撞一次）
			if not data.has("phantom"):
				for f: Node in get_tree().get_nodes_in_group("foes"):
					var ff := f as Foe
					if ff == null or ff == self or not ff.alive or _trampled.has(ff.get_instance_id()):
						continue
					if ff.global_position.distance_to(global_position) < radius + ff.radius + 0.3:
						_trampled[ff.get_instance_id()] = true
						var side := (ff.global_position - global_position).normalized()
						SharedHazards.hit_foe(ff, "charge", float(data["dmg"]) * dmg_scale, (_atk_dir + side).normalized(), 9.0)
			# 撞到墙、柱子：自己晕一会儿（这时候是白打的机会）
			if data.has("phantom") and st_t > 0.1 and get_slide_collision_count() > 0 and get_real_velocity().length() < 6.0:
				_vanish()
				return
			if st_t > 0.1 and get_slide_collision_count() > 0 and get_real_velocity().length() < 6.0:
				Vfx.I.dust(global_position + _atk_dir * 0.8, 1.6)
				Vfx.I.chips(global_position + _atk_dir * 0.8 + Vector3(0, 1, 0), -_atk_dir + Vector3.UP, Color(0.45, 0.42, 0.38), 12, 7.0, 0.12)
				Vfx.I.shock_ring(global_position + _atk_dir * 0.8, Color(1.0, 0.7, 0.4), 0.3, 2.6, 0.3)
				CamRig.I.shake(1)
				Game.sfx("boom", -5.0)
				Feel.I.callout(head_top(), "撞墙!", Color(1.0, 0.85, 0.4), 1.0)
				_end_attack()
				_release()
				hit_stun = 2.8
				Vfx.I.sheet("stunned", head_top() - Vector3(0, 0.3, 0), 1.0, Color(1, 1, 1), 1.6, false, 1.4)
				_set_state("stagger")
				return
			if k >= 1.0:
				_end_attack()
		"blast":
			_explode(true)
			return
		"summon_s":
			var k := st_t / 0.5
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var n := 2
				var fl := 0
				var main := get_parent()
				var stt: Variant = main.get("state") if main != null else null
				if stt != null:
					fl = stt.floor_i()
				for i in range(n):
					var a := TAU * i / n + randf() * 0.8
					var p := global_position + Vector3(cos(a), 0, sin(a)) * 2.2
					var mk := "bomber" if fl >= 2 and i == 1 else "crawler"
					var m := _summon(mk, p)
					if m != null:
						_minions.append(m)
				Game.sfx("boom", -8.0, 0.1, 1.3)
			if k >= 1.0:
				_end_attack()
		"bash":
			var dur := 0.28
			var k := st_t / dur
			_pose = Poses.swing("enemy_h", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			_pose["hand_l"] = Poses.dirv(0, 10, 0.95)
			_pose["shield"] = Vector3(0.6, 1.0, 0.0)
			move_with_knock(_atk_dir * 8.0 * (1.0 - k), dt)
			if not _did_hit and k >= 0.3:
				_did_hit = true
				Vfx.I.shock_ring(global_position + _atk_dir * 1.4 + Vector3(0, 0.1, 0), Color(0.8, 0.9, 1.0), 0.3, 2.2, 0.2)
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh == null or not hh.alive:
						continue
					var to := hh.global_position - global_position
					to.y = 0
					if to.length() < 2.2 + hh.radius and rad_to_deg(_atk_dir.angle_to(to)) < 60.0:
						var info := HitInfo.make(self, hh, float(data["dmg"]) * 0.8 * dmg_scale, HitInfo.Weight.LIGHT)
						info.knock = 13.0
						Feel.I.on_hit(info)
				Game.sfx("block", -4.0)
			if k >= 1.0:
				_end_attack()
		"chain", "boss_chain":
			_st_chain(dt)
		"thrust":
			# 灰衣枪兵：往前一送，一条直线上都扎得到
			var dur := 0.26
			var k := st_t / dur
			_pose = _aim_pose(1.0)
			_pose["lean"] = 0.35
			move_with_knock(_atk_dir * (7.0 * (1.0 - k)), dt)
			if not _did_hit and k >= 0.2:
				_did_hit = true
				var reach := float(data["range"]) + 0.4
				Vfx.I.streaks(global_position + _atk_dir * 0.8 + Vector3(0, 1.0, 0), _atk_dir, Color(1.0, 0.88, 0.78), 3, reach, 0.14, 0.05, 0.12)
				Vfx.I.pop(global_position + _atk_dir * reach + Vector3(0, 1.0, 0), "spark_05", Color(1.0, 0.8, 0.6), 0.3, 1.4, 0.12)
				for h: Node in get_tree().get_nodes_in_group("heroes"):
					var hh := h as Hero
					if hh == null or not hh.alive:
						continue
					var to := hh.global_position - global_position
					to.y = 0
					var t := to.dot(_atk_dir)
					if t > -0.3 and t < reach + hh.radius and (to - _atk_dir * t).length() < 0.55 + hh.radius:
						_hit_target(hh, float(data["dmg"]), HitInfo.Weight.LIGHT)
			if k >= 1.0:
				_end_attack()
		"lob":
			# 泼油俑：把灯油罐抡出去（罐子自己飞，落地点着）
			var k := st_t / 0.3
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				var j := FoeLob.new()
				j.from = global_position + _atk_dir * 0.5 + Vector3(0, 1.7 * float(data["k"]), 0)
				j.to = _atk_target
				j.damage = float(data["dmg"]) * dmg_scale
				get_parent().add_child(j)
				Game.sfx("slash", -8.0, 0.1, 0.6)
			if k >= 1.0:
				_end_attack()
		"aura":
			var k := st_t / 0.45
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				_do_aura()
			if k >= 1.0:
				_end_attack()
		"spore":
			var k := st_t / 0.4
			_pose = Poses.cast(1.0, _anim_t)
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit:
				_did_hit = true
				# 菌盖一抖喷出一股绿雾，沿途几团烟，落点一下毒伤 + 留一滩瘴
				var from := global_position + Vector3(0, 1.6 * float(data["k"]), 0)
				for i in range(4):
					var q := from.lerp(_atk_target + Vector3(0, 0.5, 0), (i + 1) / 4.0)
					Vfx.I.pop(q, "smoke_04", Color(0.45, 0.85, 0.25, 0.7), 0.4, 1.4, 0.35 + i * 0.05, false)
				Vfx.I.pop(_atk_target + Vector3(0, 0.5, 0), "smoke_04", Color(0.4, 0.8, 0.2, 0.85), 1.0, 3.6, 0.55, false)
				Vfx.I.shock_ring(_atk_target, Vfx.ELEM_COLOR["poison"], 0.3, SPORE_R * 2.2, 0.3)
				Game.sfx("flame", -6.0, 0.1, 0.6)
				_area_hit(_atk_target, SPORE_R, float(data["dmg"]), HitInfo.Weight.LIGHT)
				var fp := FirePool.new()
				fp.elem = "poison"
				fp.radius = SPORE_R * 0.85
				fp.damage = 4.0 * dmg_scale
				fp.life = 3.8
				get_parent().add_child(fp)
				fp.global_position = _atk_target
			if k >= 1.0:
				_end_attack()
		"bell":
			var k := st_t / 0.45
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.35, 0, 1), clampf((k - 0.35) / 0.65, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.3:
				_did_hit = true
				# 钟杖往地上一顿：一圈金色声浪往外推，脚下一记佛光
				var t := TideRing.new()
				t.owner_foe = self
				t.damage = float(data["dmg"]) * dmg_scale
				t.color = Color(1.0, 0.82, 0.38)
				t.elem = "holy"
				t.speed = 7.0
				t.max_r = BELL_R
				get_parent().add_child(t)
				t.global_position = Vector3(global_position.x, 0.0, global_position.z)
				Vfx.I.shock_ring(global_position, Color(1.0, 0.9, 0.6), 0.3, 3.0, 0.25)
				Vfx.I.pop(rig.blade_tip, "light_03", Color(1.0, 0.85, 0.45), 0.6, 3.0, 0.3)
				Vfx.I.streaks(rig.blade_tip, Vector3.UP, Color(1.0, 0.85, 0.45), 6, 1.6, 0.22, PI, 0.1)
				CamRig.I.shake(1)
				Game.sfx("block", -2.0, 0.05, 0.55)
				Game.sfx("boom", -9.0, 0.0, 1.6)
			if k >= 1.0:
				_end_attack()
		"boss_tide":
			_st_tide(dt)
		"boss_rank":
			_st_rank(dt)
		"boss_fire":
			_st_fire(dt)
		"boss_wave":
			var k := st_t / 0.4
			_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
			move_with_knock(Vector3.ZERO, dt)
			if not _did_hit and k >= 0.35:
				_did_hit = true
				for i in range(5):
					var a := -0.6 + 0.3 * i
					var d := _atk_dir.rotated(Vector3.UP, a)
					_spawn_wave(d)
				CamRig.I.shake(1)
				Game.sfx("boom", -4.0)
			if k >= 1.0:
				_end_attack()


## 灯链横扫的半径：灯奴僧 4.2 米，枯荣 5.2（二阶段 5.8）
func _chain_r() -> float:
	if kind == "boss4":
		return 5.2 if _boss_phase == 0 else 5.8
	if kind == "boss5":
		return 5.0 if _boss_phase == 0 else 5.6
	return 4.2


## 灯链横扫一整圈：转一圈的刀光 + 一圈铁屑，圈内全吃到
func _st_chain(dt: float) -> void:
	var dur := 0.42
	var k := st_t / dur
	_pose = Poses.swing("enemy_h", 1.0, clampf(k / 0.5, 0, 1), clampf((k - 0.5) / 0.5, 0, 1))
	_pose["twist"] = lerpf(-0.9, 2.4, clampf(k, 0.0, 1.0))
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit and k >= 0.3:
		_did_hit = true
		var r := _chain_r()
		var base := Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3(0, 0.8, 0))
		var gold := kind == "boss5"
		Vfx.I.slash(base, r, PI, -PI, 0.3, Color(1.0, 0.95, 0.85) if gold else Color(0.85, 0.95, 1.0), Color(1.0, 0.65, 0.25) if gold else Color(0.3, 0.7, 1.0), 2.6, 0.75)
		Vfx.I.shock_ring(global_position, Color(1.0, 0.75, 0.35) if gold else Color(0.5, 0.85, 1.0), 0.5, r * 2.2, 0.35)
		for i in range(10):
			var a := TAU * i / 10.0
			Vfx.I.chips(global_position + Vector3(cos(a), 0.3, sin(a)) * r * 0.8, Vector3(cos(a), 0.6, sin(a)), Color(0.35, 0.4, 0.45), 2, 6.0, 0.08)
		CamRig.I.shake(1)
		Game.sfx("slash_heavy", -4.0, 0.1, 0.8)
		_area_hit(global_position, r, float(data["dmg"]) * (1.0 if kind != "boss4" else 1.1), HitInfo.Weight.HEAVY)
	if k >= 1.0:
		_end_attack()


## 枯荣二阶段：推出一圈（二阶段后期两圈）水波，从脚下往外涨，碰到就挨打；翻滚的无敌帧能穿过去
func _st_tide(dt: float) -> void:
	var k := st_t / 0.5
	_pose = Poses.cast(1.0, _anim_t)
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit:
		_did_hit = true
		var n := 1 if hp > max_hp * 0.25 else 2
		for i in range(n):
			var t := TideRing.new()
			t.owner_foe = self
			t.damage = float(data["dmg"]) * 0.9 * dmg_scale
			t.delay = i * 0.9
			get_parent().add_child(t)
			t.global_position = Vector3(global_position.x, 0.0, global_position.z)
		CamRig.I.shake(1)
		Game.sfx("boom", -5.0, 0.0, 0.7)
	if k >= 1.0:
		_end_attack()


## 不夜将军号令亲兵：四个金色幻影排成一排，从房间一头往另一头冲一趟（每个亲兵自己有冲锋预警）
func _st_rank(dt: float) -> void:
	var k := st_t / 0.45
	_pose = Poses.swing("enemy_v", 1.0, clampf(k / 0.4, 0, 1), clampf((k - 0.4) / 0.6, 0, 1))
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit:
		_did_hit = true
		var main := get_parent()
		var ar: Variant = main.get("arena") if main != null else null
		var half := Vector2(18.0, 13.0)
		if ar != null:
			half = (ar.size as Vector2) * 0.5 - Vector2(2.0, 2.0)
		var hp_ := target.global_position if target != null else Vector3.ZERO
		var from_side := randf() < 0.5
		var n := (4 if _boss_phase == 0 else 5) if kind != "boss6" else 3
		var gk := "phantom" if kind != "boss6" else "ashghost"
		for i in range(n):
			var off := (i - (n - 1) * 0.5) * (2.6 if kind != "boss6" else 3.4)
			var p: Vector3
			var d: Vector3
			if from_side:
				var sx := -1.0 if hp_.x > 0.0 else 1.0
				p = Vector3(sx * half.x, 0, clampf(hp_.z + off, -half.y, half.y))
				d = Vector3(-sx, 0, 0)
			else:
				p = Vector3(clampf(hp_.x + off, -half.x, half.x), 0, -half.y)
				d = Vector3(0, 0, 1)
			var f := Foe.new()
			f.setup_kind(gk, 1.0, dmg_scale)
			f.charge_dir = d
			f.no_loot = true
			main.add_child(f)
			f.global_position = p
			f.face_to(d)
		Game.sfx("boss", -6.0)
		CamRig.I.shake(1)
	if k >= 1.0:
		_end_attack()


## 不夜将军二阶段：把灯油泼一地点着——主角脚下和周围几处先亮预警圈，一会儿烧起来
func _st_fire(dt: float) -> void:
	var k := st_t / 0.45
	_pose = Poses.cast(1.0, _anim_t)
	move_with_knock(Vector3.ZERO, dt)
	if not _did_hit:
		_did_hit = true
		var c := target.global_position if target != null else global_position
		var pts := [c]
		for i in range(4):
			var a := TAU * i / 4.0 + randf() * 0.8
			pts.append(c + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 5.5))
		for q: Vector3 in pts:
			var fp := FirePool.new()
			fp.radius = 1.7
			fp.damage = float(data["dmg"]) * 0.3 * dmg_scale
			fp.life = 4.5
			fp.warn = 0.95
			get_parent().add_child(fp)
			fp.global_position = Vector3(q.x, 0, q.z)
		Game.sfx("flame", -4.0)
	if k >= 1.0:
		_end_attack()


## 灯童、旗手身边有几个能照顾到的同伴（灯童只算带伤的）
func _aura_allies() -> int:
	var heal := String(data.get("aura", "")) == "heal"
	var n := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or ff == self or not ff.alive or ff.data.has("phantom") or ff.data.has("aura") or ff.state == "lurk":
			continue
		if ff.global_position.distance_to(global_position) > AURA_R:
			continue
		if heal and ff.hp > ff.max_hp * 0.9:
			continue
		n += 1
	return n


## 灯一亮：身边的怪回一截血；旗一举：身边的灰衣人发狠几秒（头目不吃）
func _do_aura() -> void:
	_auras += 1
	var heal := String(data.get("aura", "")) == "heal"
	var col := Color(0.55, 1.0, 0.75) if heal else Color(1.0, 0.35, 0.2)
	Vfx.I.shock_ring(global_position, col, 0.5, AURA_R * 2.0, 0.5)
	Vfx.I.sheet("soul-rise" if heal else "spawn-cast", global_position, 2.6, Color(col, 0.9), 1.6, false, 0.0, 1.6)
	if not FoeSfx.play(self, "aura"):
		Game.sfx("heal" if heal else "danger", -6.0)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or ff == self or not ff.alive or ff.data.has("phantom") or ff.data.has("aura") or ff.state == "lurk":
			continue
		if ff.global_position.distance_to(global_position) > AURA_R:
			continue
		Vfx.I.streaks(chest(), (ff.chest() - chest()).normalized(), col, 1, ff.chest().distance_to(chest()), 0.25, 0.0, 0.1)
		if heal:
			var v := ff.max_hp * 0.18
			ff.hp = minf(ff.max_hp, ff.hp + v)
			Feel.I.number(ff.chest(), "+%d" % int(v), Color(0.5, 1.0, 0.65), 0.8)
			ff.rig.flash(0.15, Color(0.6, 1.0, 0.7))
		elif not ff.is_boss:
			ff.rally(5.0)


## 被旗手激励：几秒内出手更快、更疼，描边发红
func rally(t: float) -> void:
	if _rally <= 0.0:
		_rim0 = [rig.mat.get_shader_parameter("rim_color"), rig.mat.get_shader_parameter("rim_strength")]
	_rally = t
	rig.set_rim(Color(1.0, 0.3, 0.2), 1.0)
	Feel.I.callout(head_top(), "狠", Color(1.0, 0.45, 0.3), 0.6)


## 殉灯俑倒下：另一只还站着，就在原地留一圈灯光，几秒后爬起来（复活的那只不会再起来、不掉钱）
func _twin_died() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _twin_dead_t < 1.0:
		ArpgAch.unlock("twin_pair")
	_twin_dead_t = now
	if has_meta("revived") or not _twin_alive(get_tree()):
		return
	var main := get_parent()
	var ar: Variant = main.get("arena")
	var p := global_position
	var hs := max_hp / float(data["hp"])
	var ds := dmg_scale
	Vfx.I.ground(p, "magic_01", Color(1.0, 0.75, 0.35, 0.7), 1.5, 2.2, 4.0)
	Feel.I.callout(p + Vector3(0, 1.8, 0), "还会起来", Color(1.0, 0.8, 0.45), 1.2)
	get_tree().create_timer(4.0).timeout.connect(func() -> void: Foe._revive_twin(main, ar, p, hs, ds))


static func _twin_alive(tree: SceneTree) -> bool:
	for f: Node in tree.get_nodes_in_group("foes"):
		if f is Foe and (f as Foe).alive and (f as Foe).data.has("twin"):
			return true
	return false


static func _revive_twin(main: Node, ar: Variant, p: Vector3, hs: float, ds: float) -> void:
	if not is_instance_valid(main) or ar == null or not is_instance_valid(ar) or main.get("arena") != ar or main.get("mode") != "room":
		return
	if not _twin_alive(main.get_tree()):
		return
	var f := Foe.new()
	f.setup_kind("twin", hs * 0.7, ds)
	f.no_loot = true
	f.set_meta("revived", true)
	main.add_child(f)
	f.global_position = p
	f.detect_mult = 2.0
	FoeSfx.play(f, "rise")
	if main.has_method("_on_drop"):
		f.dropped.connect(main._on_drop.bind("twin"))


func _spawn_wave(d: Vector3) -> void:
	var w := BossWave.new()
	w.dir = d
	w.owner_foe = self
	w.damage = float(data["dmg"]) * 0.8 * dmg_scale
	get_parent().add_child(w)
	w.global_position = global_position + d * 1.0 + Vector3(0, 0.7, 0)


## 骨弩手端弩瞄准：两手往前平举，弩身朝前（k 越大端得越稳）
func _aim_pose(k: float) -> Dictionary:
	var e := Poses.ease_out(k)
	return {"lean": 0.05, "twist": -0.15 * e, "bob": -0.8,
		"hand_r": Poses.dirv(-5, lerpf(-40, 5, e), 0.85), "blade": Poses.dirv(0, lerpf(-30, 0, e)),
		"hand_l": Poses.dirv(15, lerpf(-50, 5, e), 0.75), "foot_r": Vector3(-1.5, 0, 0.8), "foot_l": Vector3(2.0, 0, -0.8)}


func _shoot(d: Vector3) -> void:
	var s := FoeShot.new()
	s.dir = d
	s.owner_foe = self
	s.damage = float(data["dmg"]) * dmg_scale
	get_parent().add_child(s)
	s.global_position = global_position + d * 0.8 + Vector3(0, 1.0 * float(data["k"]), 0)
	Vfx.I.pop(s.global_position, "muzzle_02", Color(1.0, 0.6, 0.3), 0.4, 1.4, 0.12)


## 招魂巫招小鬼：直接在身边生出来（不经过波次，不掉钱，巫死了跟着散架）
func _summon(k: String, p: Vector3) -> Foe:
	var f := Foe.new()
	f.setup_kind(k, max_hp / float(data["hp"]) * 0.8, dmg_scale)
	f.no_loot = true
	get_parent().add_child(f)
	f.global_position = p
	if target != null:
		f.face_to(target.global_position - p)
	f.detect_mult = 2.0
	var main := get_parent()
	if main.has_method("_on_drop"):
		f.dropped.connect(main._on_drop.bind(k))
	return f


## 爆骨鬼炸开：hurt_hero 时（自己点火）也伤主角；被打死的残爆只伤旁边的怪
func _explode(hurt_hero: bool) -> void:
	if _exploded:
		return
	_exploded = true
	var p := global_position
	var r := 2.8 if hurt_hero else 2.4
	Vfx.I.explosion(p + Vector3(0, 0.6, 0), 0.9)
	Vfx.I.shock_ring(p, Color(1.0, 0.6, 0.2), 0.4, r * 2.0, 0.3)
	if Vfx.I.lod > 0:
		Vfx.I.sheet("dark-explosion", p, r * 1.6, Color(1.0, 0.75, 0.5), 1.8)
	CamRig.I.shake(2 if hurt_hero else 1)
	Game.sfx("boom", -2.0 if hurt_hero else -5.0)
	if hurt_hero:
		_area_hit(p, r, float(data["dmg"]), HitInfo.Weight.HEAVY)
	for f: Node in get_tree().get_nodes_in_group("foes"):
		var ff := f as Foe
		if ff == null or ff == self or not ff.alive:
			continue
		var d := ff.global_position - p
		d.y = 0
		if d.length() > r + ff.radius:
			continue
		var info := HitInfo.make(null, ff, (40.0 if not ff.is_boss else 25.0), HitInfo.Weight.HEAVY)
		info.dir = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
		info.point = ff.chest()
		info.knock = 9.0
		Feel.I.on_hit(info)
	if alive:
		hp = 0.0
		die(Vector3.UP * 4.0)


## 亲兵冲完一趟：化成一阵金色的灰散掉（不掉东西）
func _vanish() -> void:
	if not alive:
		return
	_release()
	Vfx.I.sheet("soul-rise", global_position, 2.5, Color(1.0, 0.8, 0.4, 0.8), 1.6, false, 0.0, 1.6)
	Vfx.I.dust(global_position, 1.2, Color(0.8, 0.65, 0.4, 0.5))
	alive = false
	remove_from_group("foes")
	collision_layer = 0
	queue_free()


func _end_attack() -> void:
	if data.has("phantom"):
		_vanish()
		return
	_cool = randf_range(0.9, 1.8) if not is_boss else randf_range(0.6, 1.2) * (1.0 if _boss_phase == 0 else 0.6)
	if kind == "rogue" or data.has("hitrun"):
		_retreat_t = 0.7
	rig.position.y = 0
	_set_state("recover")
	_blend = 0.3


func _melee_hit(reach: float, arc_deg: float, dmg: float, w: int) -> void:
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var to := hh.global_position - global_position
		to.y = 0
		if to.length() > reach + hh.radius:
			continue
		if rad_to_deg(_atk_dir.angle_to(to)) > arc_deg * 0.5:
			continue
		_hit_target(hh, dmg, w)


func _area_hit(p: Vector3, r: float, dmg: float, w: int) -> void:
	for h: Node in get_tree().get_nodes_in_group("heroes"):
		var hh := h as Hero
		if hh == null or not hh.alive:
			continue
		var d := hh.global_position - p
		d.y = 0
		if d.length() <= r + hh.radius:
			_hit_target(hh, dmg, w)


func _hit_target(hh: Hero, dmg: float, w: int) -> void:
	var info := HitInfo.make(self, hh, dmg * dmg_scale * randf_range(0.9, 1.1) * (1.25 if _rally > 0.0 else 1.0), w)
	info.knock = 6.0 if w == HitInfo.Weight.LIGHT else 10.0
	info.elem = _atk_elem()
	Feel.I.on_hit(info)


## 这一招算什么属性（挨打时冒的特效颜色）：法术紫、火橙、毒绿、水青、钟声金；普通刀斧没有属性
func _atk_elem() -> String:
	match _atk:
		"rune":
			return "magic"
		"blast":
			return "fire"
		"spore":
			return "poison"
		"bell":
			return "holy"
		"chain", "boss_chain":
			return "fire" if kind == "boss5" else "water"
		"boss_spikes":
			return "water" if kind == "boss4" else "bone"
	if _atk in ["slash", "heavy", "lunge", "boss_combo"] and String(data.get("elem", "")) in ["magic", "holy", "poison"]:
		return ""   # 法师、钟僧、毒菇近身挥杖算普通一下
	return String(data.get("elem", ""))


func take_hit(info: HitInfo) -> bool:
	if state == "spawn" and st_t < 0.2:
		return false
	if state == "lurk":
		return false
	if data.has("phantom"):
		return false
	if ward > 0.0 and alive and iframes <= 0.0:
		FoeAffix.absorb(self, info)
	var raw_dmg := info.damage
	if data.has("armor") and _armor_down <= 0.0 and info.weight < HitInfo.Weight.ULT:
		# 烛国甲士：铜甲挡掉大半，火星四溅
		info.damage *= float(data["armor"])
		Vfx.I.pop(chest() - info.dir * 0.4, "spark_05", Color(1.0, 0.8, 0.45), 0.35, 1.5, 0.12)
		FoeSfx.play(self, "armor")
	# 盾骷髅：正面来的刀挡掉大半，挡满几下就破盾；绕到侧后面、或者大招，直接打进去
	var blocked := false
	if guard > 0.0 and alive and iframes <= 0.0 and info.weight < HitInfo.Weight.ULT and state != "stagger":
		var from := -info.dir
		from.y = 0
		if from.length() > 0.01 and facing.dot(from.normalized()) > 0.3:
			blocked = true
			guard -= 2.0 if info.weight == HitInfo.Weight.HEAVY else 1.0
			if guard <= 0.0:
				guard = 0.0
				_guard_down = 4.0
				if rig.offhand != null:
					rig.offhand.visible = false
					Vfx.I.chips(chest(), info.dir + Vector3.UP, Color(0.6, 0.62, 0.66), 14, 7.0, 0.12)
				Feel.I.callout(head_top(), "破盾!", Color(1.0, 0.85, 0.4), 1.0)
				Game.sfx("guard_break", -3.0)
				info.damage *= 0.5
				info.stun = maxf(info.stun, 1.0)
				blocked = false
			else:
				info.damage *= 0.15
				info.knock *= 0.3
				Vfx.I.pop(chest() - info.dir * 0.4, "spark_05", Color(0.8, 0.9, 1.0), 0.4, 1.8, 0.14)
				if Vfx.I.room_for(1):
					Vfx.I.sheet("parry", global_position - info.dir * 0.4 + Vector3(0, 0.3, 0), 2.4, Color(1, 1, 1), 1.6, false, 0.0, 1.5)
				Feel.I.callout(head_top(), "格", Color(0.75, 0.85, 1.0), 0.5)
				Game.sfx("block", -5.0)
	var ok := super.take_hit(info)
	if ok and blocked:
		knock *= 0.3
		return ok
	if not ok or not alive:
		return ok
	# 韧性：重甲要先打掉韧性才会僵直；正在跳劈的不打断
	var interrupt := true
	if max_poise > 0.0:
		poise -= raw_dmg * (1.6 if info.weight >= 1 else 1.0)
		interrupt = poise <= 0.0
		if interrupt:
			poise = max_poise
			if data.has("armor"):
				_armor_down = 3.5
				Feel.I.callout(head_top(), "破甲!", Color(1.0, 0.75, 0.35), 1.1)
				Vfx.I.chips(chest(), info.dir + Vector3.UP, Color(0.75, 0.55, 0.3), 14, 7.0, 0.12)
			else:
				Feel.I.callout(head_top(), "破韧!", Color(1.0, 0.85, 0.4), 1.0)
			Game.sfx("posture_break", -3.0)
	if state == "attack" and _atk in ["leap", "boss_leap"]:
		interrupt = false
	if interrupt:
		_release()
		rig.position.y = 0
		rig.scale = Vector3.ONE
		hit_stun = info.stun * (0.6 if is_boss else 1.0)
		if max_poise > 0.0:
			# 重甲被打断：头上冒星星
			Vfx.I.sheet("stunned", head_top() - Vector3(0, 0.3, 0), 1.0, Color(1, 1, 1), 1.6, false, maxf(hit_stun, 0.9))
		_set_state("stagger")
		_blend = 1.0
		if is_boss:
			knock *= 0.3
	else:
		knock *= 0.15
	if kind == "boss6" and _boss_phase == 1 and not _stage3 and hp < max_hp * 0.33:
		# 烬 · 第三段：燃烬。身上烧起来，更快，残影开始冲阵
		_stage3 = true
		_rank_t = 2.0
		data["speed"] = float(data["speed"]) * 1.15
		rig.set_glow(Color(0.35, 0.1, 0.02))
		rig.set_rim(Color(1.0, 0.45, 0.2), 1.2)
		Feel.I.callout(head_top() + Vector3(0, 0.6, 0), "烬·燃", Color(1.0, 0.45, 0.25), 1.5)
		FoeSfx.play(self, "rage2")
		Feel.I.callout(head_top() + Vector3(0, 1.4, 0), "“师弟，你不该来的。”", Color(0.95, 0.92, 0.85), 2.2)
		CamRig.I.close_up(self, 1.3, 0.55)
		if Hud3D.I != null:
			Hud3D.I.cinema(1.5)
		Feel.I.screen_flash(Color(1.0, 0.4, 0.15, 0.4), 2.0)
		Feel.I.slowmo(0.3, 0.6)
		for j in range(3):
			Vfx.I.shock_ring(global_position, Color(1.0, 0.5, 0.2) if j != 1 else Color(1, 1, 1), 0.4, 5.0 + j * 2.5, 0.45 + j * 0.2)
	if is_boss and _boss_phase == 0 and hp < max_hp * (0.66 if kind == "boss6" else 0.5):
		_boss_phase = 1
		rig.set_rim(fx_color(), 0.9)
		Feel.I.callout(head_top() + Vector3(0, 0.6, 0), String(RAGE_NAMES.get(kind, data.get("rage", "狂"))), Color(1.0, 0.4, 0.55), 1.5)
		Feel.I.callout(head_top() + Vector3(0, 1.4, 0), "“%s”" % String(RAGE_LINES.get(kind, data.get("rage_line", ""))), Color(0.95, 0.92, 0.85), 2.2)
		# 特写：镜头转过去、上下黑边
		CamRig.I.close_up(self, 1.3, 0.55)
		if Hud3D.I != null:
			Hud3D.I.cinema(1.5)
		Feel.I.screen_flash(Color(fx_color(), 0.4), 2.0)
		# 进入狂暴：慢镜头一下，本色冲击环一圈圈推开
		Feel.I.slowmo(0.3, 0.6)
		for j in range(3):
			Vfx.I.shock_ring(global_position, fx_color() if j != 1 else Color(1, 1, 1), 0.4, 5.0 + j * 2.5, 0.45 + j * 0.2)
		Vfx.I.streaks(chest(), Vector3.UP, fx_color(), 10, 3.5, 0.4, PI, 0.22)
		CamRig.I.shake(2, 1.2)
		Game.sfx("boss_kill", -6.0, 0.0, 1.3)
		FoeSfx.play(self, "rage")
		data = data.duplicate()
		data["speed"] = float(data["speed"]) * 1.25
		if kind == "boss6":
			# 烬 · 第二段：点起第四盏灯
			_fire_t = 2.5
			_summon_t = 5.0
		if kind == "boss5":
			# 不夜将军半血：整座灯冢的灯都点着了
			_fire_t = 2.0
			var ar5: Variant = get_parent().get("arena") if get_parent() != null else null
			if ar5 != null and ar5.has_method("ignite"):
				ar5.ignite()
		if kind == "boss4":
			# 枯荣半血：整间殿水位上涨，之后隔一阵推一圈水波
			_tide_t = 2.5
			var ar: Variant = get_parent().get("arena") if get_parent() != null else null
			if ar != null and ar.has_method("flood"):
				ar.flood(true)
	return ok


## 这个敌人的特效主色：头目各有一套（夜樱粉、百骨将骨青、寂光金），精英橙红，小怪暖黄
func fx_color() -> Color:
	match kind:
		"boss":
			return Color(1.0, 0.45, 0.7)
		"boss3":
			return Color(0.75, 1.0, 0.7)
		"boss2":
			return Color(1.0, 0.82, 0.4)
		"boss4":
			return Color(0.45, 0.85, 1.0)
		"boss5":
			return Color(1.0, 0.7, 0.3)
		"boss6":
			return Color(1.0, 0.55, 0.35)
	return Color(1.0, 0.5, 0.3) if max_poise > 0.0 else Color(1.0, 0.85, 0.4)


func die(impulse: Vector3) -> void:
	super.die(impulse)
	if _base_ring != null:
		_base_ring.visible = false
	_release()
	remove_from_group("foes")
	if _trail != null:
		_trail.active = false
	Feel.I.on_kill(self, impulse)
	if not FoeSfx.play(self, "death"):
		Game.sfx("death", -4.0)
	if data.get("fire", false):
		var fp := FirePool.new()
		fp.radius = 1.5
		fp.damage = 5.0 * dmg_scale
		fp.life = 3.5
		get_parent().add_child(fp)
		fp.global_position = Vector3(global_position.x, 0, global_position.z)
	if data.has("twin"):
		_twin_died()
	if kind == "sporer":
		# 瘴菇骨死了：菌盖噗地散一小团瘴
		Vfx.I.pop(chest(), "smoke_04", Color(0.45, 0.85, 0.25, 0.8), 0.8, 3.0, 0.5, false)
		var sp := FirePool.new()
		sp.elem = "poison"
		sp.radius = 1.3
		sp.damage = 3.0 * dmg_scale
		sp.life = 2.8
		sp.warn = 0.3
		get_parent().add_child(sp)
		sp.global_position = Vector3(global_position.x, 0, global_position.z)
	if data.has("split") and not has_meta("split_done"):
		# 抬棺骨：棺盖碎成木片，棺里爬出三只腐骨虫（不掉钱）
		set_meta("split_done", true)
		Vfx.I.chips(chest(), Vector3.UP + facing, Color(0.36, 0.24, 0.16), 18, 7.0, 0.14)
		Vfx.I.sheet("soul-rise", global_position, 2.4, Color(0.75, 1.0, 0.7, 0.85), 1.6)
		Feel.I.callout(head_top(), "棺里还有!", Color(0.85, 1.0, 0.7), 1.0)
		Game.sfx("death", -6.0, 0.1, 0.7)
		for i in range(3):
			var a := TAU * i / 3.0 + randf() * 0.5
			var m := _summon(String(data["split"]), global_position + Vector3(cos(a), 0, sin(a)) * 1.3)
			if m != null:
				m.hit_stun = 0.0
	if not affixes.is_empty():
		FoeAffix.on_death(self)
	if kind == "greyflag" and _auras == 0 and not no_loot:
		ArpgAch.unlock("flag_cut")
	if kind == "bomber" and not _exploded:
		# 爆骨鬼被打死：短暂一下后残爆，炸旁边的怪，不伤主角
		get_tree().create_timer(0.18).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_explode(false))
	for m in _minions:
		if is_instance_valid(m) and m.alive:
			m.die(Vector3.UP * 2.0)
	if is_boss:
		# 头目倒下，召出来的小怪跟着散架
		for f: Node in get_tree().get_nodes_in_group("foes"):
			if f != self and f is Foe and (f as Foe).alive:
				(f as Foe).die(Vector3.UP * 2.0)
	Vfx.I.impact_flash(chest(), 2.5 if not is_boss else 6.0)
	Vfx.I.chips(chest(), impulse, Color(0.85, 0.85, 0.78), 10, 6.0)
	CamRig.I.shake(1 if not is_boss else 2)
	rig.shatter(get_parent(), impulse)
	var jade := 3 if is_boss else (1 if randf() < 0.25 and not no_loot else 0)
	if jade > 0:
		# 掉魂玉的敌人飘出一缕魂
		Vfx.I.sheet("soul-rise", global_position, 3.0 if not is_boss else 5.0, Color(0.7, 1.0, 0.95, 0.9), 1.6, false, 0.0, 1.3)
	dropped.emit(global_position, 0 if no_loot else int(data["coins"]), jade)
	collision_layer = 0
	remove_from_group("foes")
	queue_free_later()


func queue_free_later() -> void:
	await get_tree().create_timer(2.0).timeout
	queue_free()


var _pose_acc := 0.0
var _pose_skip := 0


## 低画质：离主角远、又没在出招的小怪少摆几次姿势（8 米外隔一帧，14 米外（多半在画面外）隔三帧），
## 出招、蓄力时每帧都摆（刀光、预警要准）
func _apply_pose(dt: float) -> void:
	_pose_acc += dt
	if Arena.lod == 0 and not is_boss and is_instance_valid(target) and state in ["patrol", "chase", "recover", "lurk", "stagger"]:
		var d2 := global_position.distance_squared_to(target.global_position)
		var every := 4 if d2 > 196.0 else (2 if d2 > 64.0 else 1)
		_pose_skip += 1
		if _pose_skip < every:
			return
	_pose_skip = 0
	var pdt := _pose_acc
	_pose_acc = 0.0
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_apply_pose_body(pdt)
	if PerfProbe.on:
		PerfProbe.add("foe_pose", _pt)


func _apply_pose_body(dt: float) -> void:
	_blend = minf(_blend + dt * 10.0, 1.0)
	var p := _pose
	if _blend < 1.0 and not _pose_prev.is_empty():
		p = Poses.blend(_pose_prev, _pose, Poses.ease_in_out(_blend))
	if UPRIGHT.has(String(data["weapon"])) and not state in ["windup", "attack"] and not p.has("keep_blade"):
		# 长杖、锡杖、长枪：不出手时竖着拿，杖头朝上（兵器模型尖端朝 -y，默认姿势会把杖头拖在地上）
		p = p.duplicate()
		p["blade"] = Vector3(0.32, 0.9, 0.3)        # 往前、往外斜一点：俯视时杖头露在肩膀外面
		p["hand_r"] = Poses.dirv(-45, -35, 0.8)
	if kind == "greyflag" and _atk != "slash" or kind == "greyflag" and not state in ["windup", "attack"]:
		# 旗手：旗杆一直竖着扛（抡旗杆打人时才放下来）
		p = p.duplicate()
		p["blade"] = Vector3(0.15, 1.0, 0.1)
	if kind == "sporer":
		# 瘴菇骨：左手把毒菇高高举过头
		p = p.duplicate()
		p["hand_l"] = Vector3(0.5, 0.6, -0.1)
		p["shield"] = Vector3(0.15, 1.0, 0.1)
	if kind == "lampkid":
		# 灯童：左手把灯往前挑着
		p = p.duplicate()
		p["hand_l"] = Vector3(0.7, -0.2, -0.3)
		p["shield"] = Vector3(0.9, 0.5, -0.2)
	if rig.mount_model != null:
		rig.mount_speed = Vector2(velocity.x, velocity.z).length()
	rig.apply(p)
