class_name AttackStep
extends Resource
## 普攻的一段（数据化配置）：时间单位秒。可以在编辑器里新建 .tres 改参数，挂到 Hero.combo 上。
##   startup 前摇 → active 判定 → recovery 后摇；cancel_at 之后可以接下一段，roll 任何时候都能取消。

@export var label := "1段!"
@export var swing := "h_rl"          # 挥刀方式：h_rl 右往左横扫 / h_lr 左往右反手 / v_down 下劈 / spin 回旋
@export var damage := 10.0
@export var startup := 0.09
@export var active := 0.08
@export var recovery := 0.22
@export var cancel_at := 0.2          # 从这段开始算，过了这个时间可以接下一段
@export var lunge := 2.2              # 出招时往前冲多远（米）
@export var reach := 2.4              # 判定半径（米）
@export var arc := 150.0              # 判定扇形角度（度，360 = 一圈）
@export var heavy := false            # 重击：顿帧 0.1、中震
@export var knock := 5.0
@export var bleed := 0                # 叠几层出血
@export var crit_chance := 0.12
@export var slash_radius := 2.3       # 刀光半径
@export var slash_tilt := 0.0         # 刀光平面倾斜（弧度，正 = 右边高）
## 兵器专属效果（ArpgArms 按兵器配）：quake 震地一圈（fx_r 半径）/ pierce 一条直线都扎穿（fx_r 长度）/
## bolt 射一支弩箭 / spread 扇形连射五支 / sweep 扫堂（晕得更久）
@export var fx := ""
@export var fx_r := 0.0


func total() -> float:
	return startup + active + recovery


func with_fx(kind: String, r: float = 0.0) -> AttackStep:
	fx = kind
	fx_r = r
	return self


static func make(lbl: String, sw: String, dmg: float, su: float, ac: float, rc: float, ca: float, lunge_m: float, rch: float, arc_deg: float, hv: bool, kn: float, bl: int, tilt: float = 0.0) -> AttackStep:
	var s := AttackStep.new()
	s.label = lbl
	s.swing = sw
	s.damage = dmg
	s.startup = su
	s.active = ac
	s.recovery = rc
	s.cancel_at = ca
	s.lunge = lunge_m
	s.reach = rch
	s.arc = arc_deg
	s.heavy = hv
	s.knock = kn
	s.bleed = bl
	s.slash_radius = rch * 0.95
	s.slash_tilt = tilt
	return s


## 默认四段：横扫 → 反手 → 下劈（叠出血）→ 回旋斩（重、叠出血）
static func default_combo() -> Array[AttackStep]:
	var c: Array[AttackStep] = []
	c.append(make("1段!", "h_rl", 10.0, 0.08, 0.07, 0.2, 0.17, 1.6, 2.5, 160.0, false, 4.0, 0, 0.12))
	c.append(make("2段!", "h_lr", 11.0, 0.07, 0.07, 0.2, 0.16, 1.6, 2.5, 160.0, false, 4.0, 0, -0.18))
	c.append(make("3段!", "v_down", 15.0, 0.12, 0.08, 0.26, 0.22, 2.2, 2.7, 70.0, true, 6.0, 1, 0.0))
	c.append(make("4段!", "spin", 24.0, 0.14, 0.14, 0.34, 0.34, 1.2, 3.1, 360.0, true, 10.0, 2, 0.0))
	return c
