class_name Moves
extends RefCounted
## 主角的攻击招式表。加新招式：在 LIST 里加一条，再在 Player._build_poses() 里加它用的姿势，
## 然后在 Player._attack_pressed() / _next_move() 里决定什么时候出这一招。
##
## 字段：
##   name                  显示名
##   raise / cut           蓄力姿势、出手姿势
##   windup/active/recover 前摇 / 判定 / 后摇（秒）
##   dmg / posture         伤害、架势伤害
##   reach/size/height     判定框（同 Fighter.front_rect）；around 为 true 时框在身体正中，前后都打
##   heavy                 能破敌人的普通格挡和盾
##   combo                 地面连段第几段（0 开始，第 0 段吃架势的第一刀加成；-1 不算连段）
##   next                  再按攻击接哪一招
##   lunge                 出手时往前冲的速度（默认 105）
##   vy                    出手时的竖直速度（负数往上）
##   launch                打中杂兵时把它挑飞的速度
##   hang                  空中出招时不往下掉
##   air                   空中招式（每次跳起最多两下）
##   plunge                下劈：一直往下砸直到落地，落地震一圈
##   spin                  转身画法（像在原地转一圈）
##   ghost                 出手时留残影
##   fx                    刀光 ["slash", 半径, 起始角, 结束角, 粗细] / ["streak", 长度] / ["flat", 半径] /
##                         ["spin"] / ["none"]；角度朝右为 0、向下为正

const LIST := {
	# ---------- 地面五连：横斩 → 上撩 → 竖劈 → 突刺 → 旋风斩 ----------
	"slash1": {"name": "横斩", "raise": "yoko_raise", "cut": "yoko_cut", "combo": 0, "next": "slash2",
		"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0,
		"reach": 33.0, "size": Vector2(54, 30), "height": 28.0, "heavy": false, "fx": ["flat", 40.0]},
	"slash2": {"name": "上撩", "raise": "raise2", "cut": "cut2", "combo": 1, "next": "slash3",
		"windup": 0.07, "active": 0.08, "recover": 0.20, "dmg": 20.0, "posture": 20.0,
		"reach": 33.0, "size": Vector2(51, 36), "height": 30.0, "heavy": false, "fx": ["slash", 36.0, 0.9, -1.8, 7.0]},
	"slash3": {"name": "竖劈", "raise": "raise1", "cut": "cut1", "combo": 2, "next": "slash4",
		"windup": 0.09, "active": 0.08, "recover": 0.22, "dmg": 22.0, "posture": 24.0,
		"reach": 34.0, "size": Vector2(54, 40), "height": 30.0, "heavy": false, "fx": ["slash", 42.0, -2.3, 0.7, 8.0]},
	"slash4": {"name": "突刺", "raise": "raise3", "cut": "cut3", "combo": 3, "next": "slash5", "lunge": 240.0,
		"windup": 0.08, "active": 0.10, "recover": 0.24, "dmg": 24.0, "posture": 26.0,
		"reach": 42.0, "size": Vector2(66, 24), "height": 28.0, "heavy": false, "fx": ["streak", 72.0]},
	"slash5": {"name": "旋风斩", "raise": "art_prep", "cut": "art_spin", "combo": 4, "lunge": 170.0, "spin": true,
		"windup": 0.12, "active": 0.30, "recover": 0.36, "dmg": 30.0, "posture": 34.0, "around": true,
		"reach": 0.0, "size": Vector2(100, 44), "height": 26.0, "heavy": false, "fx": ["spin"]},

	# 长按蓄力：重劈
	"heavy": {"name": "重劈", "raise": "charge", "cut": "smash", "combo": -1,
		"windup": 0.12, "active": 0.10, "recover": 0.40, "dmg": 30.0, "posture": 60.0,
		"reach": 39.0, "size": Vector2(69, 45), "height": 30.0, "heavy": true, "fx": ["slash", 44.0, -2.4, 0.9, 14.0]},

	# 下 + 攻击：升龙斩，人跟着刀往上冲，杂兵被挑飞；空中可以接空中斩
	"rising": {"name": "升龙斩", "raise": "rise_prep", "cut": "rise_cut", "combo": -1, "next": "air1",
		"windup": 0.10, "active": 0.16, "recover": 0.26, "dmg": 22.0, "posture": 26.0, "vy": -470.0, "lunge": 60.0,
		"launch": -380.0, "reach": 20.0, "size": Vector2(46, 70), "height": 44.0, "heavy": false,
		"fx": ["slash", 42.0, 1.2, -1.9, 9.0]},

	# 空中：两下空中斩
	"air1": {"name": "空中斩", "raise": "air_raise1", "cut": "air_cut1", "combo": -1, "next": "air2", "air": true, "hang": true,
		"windup": 0.06, "active": 0.08, "recover": 0.16, "dmg": 18.0, "posture": 18.0, "lunge": 60.0,
		"reach": 30.0, "size": Vector2(50, 40), "height": 28.0, "heavy": false, "fx": ["slash", 38.0, -2.2, 0.8, 7.0]},
	"air2": {"name": "空中回斩", "raise": "air_raise2", "cut": "air_cut2", "combo": -1, "air": true, "hang": true,
		"windup": 0.06, "active": 0.08, "recover": 0.22, "dmg": 18.0, "posture": 18.0, "lunge": 60.0,
		"reach": 30.0, "size": Vector2(50, 40), "height": 28.0, "heavy": false, "fx": ["slash", 38.0, 1.0, -1.8, 7.0]},

	# 空中 下 + 攻击：落雷斩，刀尖朝下砸到地上，落地震开一圈，能破格挡
	"plunge": {"name": "落雷斩", "raise": "plunge_raise", "cut": "plunge_land", "combo": -1, "air": true, "plunge": true,
		"windup": 0.12, "active": 1.5, "recover": 0.34, "dmg": 24.0, "posture": 30.0,
		"reach": 6.0, "size": Vector2(34, 40), "height": 8.0, "heavy": true, "fx": ["none"],
		"shock": {"dmg": 18.0, "posture": 30.0, "size": Vector2(104, 26), "heavy": true}},

	# 闪身中或刚闪完按攻击：闪身突刺，冲得很远
	"dash": {"name": "闪身突刺", "raise": "raise3", "cut": "dash_cut", "combo": -1, "lunge": 400.0, "ghost": true,
		"windup": 0.04, "active": 0.12, "recover": 0.26, "dmg": 24.0, "posture": 28.0,
		"reach": 40.0, "size": Vector2(80, 26), "height": 28.0, "heavy": false, "fx": ["streak", 96.0]},
}

## 架势改了第一刀的出手姿势时，刀光跟着换
const FX_BY_CUT := {
	"iai_cut": ["iai"],
	"cut1": ["slash", 42.0, -2.3, 0.7, 8.0],
	"cut2": ["slash", 36.0, 0.9, -1.8, 7.0],
	"cut3": ["streak", 66.0],
	"yoko_cut": ["flat", 40.0],
}


static func get_move(id: String) -> Dictionary:
	var m: Dictionary = LIST[id].duplicate()
	m["id"] = id
	return m
