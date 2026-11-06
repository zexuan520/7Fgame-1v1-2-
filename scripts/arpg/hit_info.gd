class_name HitInfo
extends RefCounted
## 一次命中的全部信息，统一交给 Feel.on_hit() 处理（伤害、暴击、重量等级决定顿帧/震屏/火花大小）。

enum Weight { LIGHT, HEAVY, ULT }

var attacker: Actor
var target: Actor
var damage := 10.0
var crit := false
var weight := Weight.LIGHT
var point := Vector3.ZERO      # 命中点
var dir := Vector3.FORWARD     # 打过去的方向（击退方向）
var knock := 4.0               # 击退速度
var bleed := 0                 # 叠几层出血
var bleed_mult := 1.0          # 出血伤害倍率
var stun := 0.25               # 硬直时间
var hitstop := -1.0            # < 0 时按重量取默认值
var shake := -1                # < 0 时按重量取默认值
var gain := 0.0                # 给攻击者回多少气
var elem := ""                 # 敌人打主角的属性（fire/poison/water/magic/holy/thunder），决定挨打时冒什么颜色的特效


static func make(att: Actor, tgt: Actor, dmg: float, w: int = Weight.LIGHT) -> HitInfo:
	var h := HitInfo.new()
	h.attacker = att
	h.target = tgt
	h.damage = dmg
	h.weight = w
	if att != null and tgt != null:
		h.dir = tgt.global_position - att.global_position
		h.dir.y = 0
		if h.dir.length_squared() < 0.0001:
			h.dir = att.facing
		h.dir = h.dir.normalized()
		h.point = tgt.chest() - h.dir * 0.25
	return h
