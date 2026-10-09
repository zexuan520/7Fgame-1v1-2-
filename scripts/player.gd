class_name Player
extends Fighter
## 主角：移动、二段跳、三段轻攻击、蓄力重攻击、格挡、弹反、闪身、处决、药罐、刃意招式、架势切换。

enum S { FREE, CHARGE, ATTACK, GUARD, DODGE, HITSTUN, BROKEN, EXECUTE, DEAD, DRINK, ART }

const MOVE_SPEED := 200.0           # 奔跑（双击 左/右）
const WALK_SPEED := 120.0           # 平时走路
const DOUBLE_TAP := 0.28            # 两次按同一个方向的间隔在这之内算双击
const BUFFER_TIME := 0.2            # 输入缓冲：提前按的键在这段时间内有效，动作一结束马上接上
const BUFFERED := ["attack", "guard", "dodge", "jump", "art", "heal", "stance"]
const JUMP_VELOCITY := -520.0
const HEAVY_CHARGE_TIME := 0.6      # 长按 0.6 秒出重攻击
const DODGE_SPEED := 420.0
const DODGE_TIME := 0.22
const DODGE_INVUL := 0.2            # 闪身无敌 0.2 秒
const DODGE_COOLDOWN := 0.4
const HITSTUN_TIME := 0.25
const BROKEN_TIME := 1.2            # 架势满 → 破防僵直 1.2 秒
const EXECUTE_TIME := 0.55
const RESPAWN_TIME := 3.0
const GUARD_SPAM_GAP := 0.35        # 连按格挡间隔太短会缩小弹反窗口
const GUARD_SPAM_FACTOR := 0.4
const EXECUTE_RANGE := 80.0
const NOTO_TIME := 0.45             # 收刀入鞘用时
const BATTO_TIME := 0.3             # 拔刀用时
const COMBAT_RANGE := 260.0         # 敌人在这个距离内就拔刀
const DRAWN_KEEP := 2.5             # 打完 2.5 秒没敌人才收刀（拔刀式 1 秒）
const TURN_TIME := 0.1

# 药罐：每局 3 次，每次回 40% 生命；喝的时候被打会打断，这一口就浪费了
const MAX_GOURDS := 3
const HEAL_RATIO := 0.4
const DRINK_TIME := 0.95
const DRINK_HEAL_AT := 0.6

# 刃意：弹反、看破、命中、踩头、处决攒能量，满 40 可以放一次招式
const MAX_WILL := 100.0
const WILL_GAIN := {"hit": 4.0, "guardbreak": 6.0, "parry": 12.0, "mikiri": 15.0, "stomp": 8.0, "execute": 35.0}

# 刃意招式·回旋斩：原地转两圈，前后都砍，每圈一次判定，能破格挡；转的时候不吃伤害
const ART := {"cost": 40.0, "windup": 0.14, "active": 0.42, "recover": 0.3, "ticks": 2,
	"dmg": 22.0, "posture": 40.0, "size": Vector2(120, 46), "heavy": true}

# 攻击招式全部在 Moves.LIST 里（地面五连、重劈、升龙斩、空中斩、落雷斩、闪身突刺）
const AIR_ATTACKS := 2              # 每次跳起最多两下空中攻击（落雷斩不算）
const DASH_WINDOW := 0.2            # 闪身结束后多久内按攻击还能出闪身突刺

var index := 1
var prefix := "p1_"
var color := Color(0.35, 0.75, 0.95)
var spawn_pos := Vector2.ZERO

var state := S.FREE
var air_jumps := 1
var combo_step := 0
var combo_queued := false
var attack: Dictionary = {}
var attack_phase := 0               # 0 前摇 1 判定 2 后摇
var hit_targets: Array = []
var charge_time := 0.0
var parry_timer := 0.0
var last_guard_press := -10.0
var dodge_dir := 1
var dodge_cooldown := 0.0
var invul_timer := 0.0
var respawn_timer := 0.0
var clock := 0.0
var parry_count := 0                # 统计，用于界面显示
var gourds := MAX_GOURDS
var max_gourds := MAX_GOURDS        # 商人的空药罐、破庙供台能加
var gear: Dictionary = GearData.empty_loadout()   # 身上的装备（闯关时和 Game.run.gear 是同一个字典）
var stats: Dictionary = GearData.base_stats()     # 装备 + 天赋 + 商人加成汇总后的数值（见 GearData.base_stats）
var weapon: Dictionary = GearData.weapon_stats(GearData.starter("katana"))
var revives := 0                    # 不动“不死身”：这一局还能站起来几次
var frozen := false                 # 开着天赋界面时站着不动
var running := false                # 双击方向键后奔跑，松开方向键变回走路
var _tap := {"left": -10.0, "right": -10.0}
var _buf := {}                      # 输入缓冲：动作 → 按下的时刻
var auto_respawn := true            # 练武场倒下 3 秒自动复活；闯关时要清完房间才复活
var stance_index := 0               # 当前架势（见 Stance.LIST）
var _switch_t := -1.0               # 切换架势的转刀动画
var _drawn_timer := 0.0             # 打完之后多久收刀入鞘
var _sheath := true                 # 刀在鞘里（平时走路收着，进入战斗拔出来）
var _batto_t := -1.0                # 拔刀动画
var _noto_t := -1.0                 # 收刀入鞘动画（纳刀）
var _turn_t := 1.0                  # 转身动画
var _run_phase := 0.0               # 跑步周期按走过的距离算，脚不打滑
var _spring := Puppet.Spring.new()
var will := 0.0
var _drank := false
var _air_attacks := 0
var _dodge_end := -10.0
var _stun_time := HITSTUN_TIME      # 这次挨打的僵直时间（被擒拿更久）
var _art_tick := -1
var _counter_t := 0.0              # 太刀：弹反后追击
var _pierce_t := 0.0               # 修罗面：处决后无视格挡
var _dodge_buff_t := 0.0           # 风铃：闪身后加伤害

# 美术
var look := Puppet.Look.new()
var scarf_color := Color("c0392b")
var _pose: Dictionary = {}          # 当前画出来的姿势（平滑过渡）
var _scarf: Array[Vector2] = []     # 围巾各节的世界坐标
var _was_on_floor := true
var _ghost_timer := 0.0
var _squash := Vector2.ONE
var _fl_kind := ""                  # 正在耍的花刀动作（见 Flourish）
var _fl_t := 0.0
var _fl_next := 2.5                 # 站多久后耍下一个
var _fl_last := ""
var _victory := ""                  # 处决之后要耍的收势动作
var _idle_time := 0.0               # 站着不动多久了，用来触发闲置小动作
var _land_timer := 0.0
var _spin_time := -1.0              # 二段跳翻身
var _prev_facing := 1
var _ready_blend := 0.0             # 0 = 放松，1 = 戒备

static var POSES := {}


static func _build_poses() -> void:
	if not POSES.is_empty():
		return
	POSES["idle"] = Puppet.pose({})
	# 放松持刀：刀背扛在肩上，刀尖朝后上方（不拖地）
	POSES["relaxed"] = Puppet.pose({"crouch": 1.2, "lean": 0.04, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.55, 2.75), "arm_b": Vector2(-0.12, 0.2), "sword": -2.45})
	# 戒备：敌人靠近时，双手持刀刀尖指向对方
	POSES["ready"] = Puppet.pose({"crouch": 2.8, "lean": 0.16, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.95, 1.55), "arm_b": Vector2(0.75, 1.45), "sword": 1.45})
	# 闲置小动作：甩刀（血振）
	POSES["chiburi_up"] = Puppet.pose({"crouch": 1.5, "lean": -0.05, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(1.9, 2.5), "arm_b": Vector2(-0.2, 0.3), "sword": 2.7})
	POSES["chiburi_down"] = Puppet.pose({"crouch": 2.5, "lean": 0.22, "foot_f": Vector2(6, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.9, 0.5), "arm_b": Vector2(-0.4, 0.1), "sword": 0.25})
	# 伸展、回头
	POSES["stretch"] = Puppet.pose({"crouch": 0.4, "lean": -0.16, "head": -0.25, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.3, 0.6), "arm_b": Vector2(2.7, 3.1), "sword": 0.5})
	POSES["look_back"] = Puppet.pose({"crouch": 1.4, "lean": -0.06, "head": -0.5, "foot_f": Vector2(5, 0), "foot_b": Vector2(-5, 0),
		"arm_f": Vector2(0.3, 0.7), "arm_b": Vector2(-0.3, 0.1), "sword": 0.6})
	POSES["land"] = Puppet.pose({"crouch": 6.5, "lean": 0.35, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.6, 1.0), "arm_b": Vector2(-0.8, -0.2), "sword": 0.9})
	# ---------- 架势（起手式），见 Stance ----------
	# 正眼放低：双手在腰前，刀尖略低于水平指向对方，不硬举
	POSES["st_seigan"] = Puppet.pose({"crouch": 2.9, "lean": 0.16, "head": 0.04, "foot_f": Vector2(6, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(0.35, 1.15), "arm_b": Vector2(0.25, 1.0), "sword": 1.25})
	POSES["st_iai"] = Puppet.pose({"crouch": 4.5, "lean": 0.32, "head": 0.05, "foot_f": Vector2(8, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(0.2, 1.55), "arm_b": Vector2(0.35, 1.25), "sword": 0.5, "sheathed": 1.0})
	# 刀在鞘里站着：双手自然垂下
	POSES["relaxed_sheathed"] = Puppet.pose({"crouch": 1.0, "lean": 0.03, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.08, 0.3), "arm_b": Vector2(-0.1, 0.12), "sword": 0.5, "sheathed": 1.0})
	POSES["iai_cut"] = Puppet.pose({"crouch": 4.2, "lean": 0.38, "foot_f": Vector2(11, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(1.55, 1.6), "arm_b": Vector2(-0.9, -0.6), "sword": 1.62})
	POSES["st_jodan"] = Puppet.pose({"crouch": 2.4, "lean": -0.04, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(2.55, 2.95), "arm_b": Vector2(2.35, 2.75), "sword": 4.15})
	POSES["st_gedan"] = Puppet.pose({"crouch": 3.0, "lean": 0.2, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.35, 0.8), "arm_b": Vector2(0.25, 0.7), "sword": 0.95})
	POSES["st_hasso"] = Puppet.pose({"crouch": 2.6, "lean": 0.06, "foot_f": Vector2(5, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.75, 2.7), "arm_b": Vector2(0.55, 2.35), "sword": 3.75})
	POSES["st_waki"] = Puppet.pose({"crouch": 3.2, "lean": 0.18, "foot_f": Vector2(7, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(-0.45, -0.15), "arm_b": Vector2(-0.3, 0.05), "sword": -1.25})
	# 喝药：后手把药罐举到嘴边，仰头
	POSES["drink"] = Puppet.pose({"crouch": 1.0, "lean": -0.12, "head": -0.4, "foot_f": Vector2(5, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.2, 0.5), "arm_b": Vector2(1.9, 3.7), "sword": 0.5})
	# 回旋斩：蓄势压低，转的时候双臂平伸、刀横着
	POSES["art_prep"] = Puppet.pose({"crouch": 5.0, "lean": 0.3, "head": 0.1, "foot_f": Vector2(8, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(-0.9, -0.6), "arm_b": Vector2(-0.5, 0.2), "sword": -1.3})
	POSES["art_spin"] = Puppet.pose({"crouch": 4.0, "lean": 0.05, "foot_f": Vector2(7, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(1.57, 1.57), "arm_b": Vector2(-1.4, -1.5), "sword": 1.57})
	# 倒下：先跪地
	POSES["kneel"] = Puppet.pose({"crouch": 8.0, "lean": 0.45, "head": 0.45, "foot_f": Vector2(7, 0), "foot_b": Vector2(-4, 0),
		"arm_f": Vector2(0.3, 0.2), "arm_b": Vector2(0.1, 0.0), "sword": 0.9})
	POSES["guard"] = Puppet.pose({"crouch": 2.5, "lean": 0.15, "foot_f": Vector2(5, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.1, 2.4), "arm_b": Vector2(0.7, 1.9), "sword": 2.75})
	POSES["parry"] = Puppet.pose({"crouch": 3.0, "lean": 0.3, "foot_f": Vector2(6, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.5, 2.6), "arm_b": Vector2(0.9, 2.0), "sword": 2.45})
	# 轻攻击三段：每段一个举刀姿势和一个出刀姿势
	POSES["raise1"] = Puppet.pose({"lean": -0.1, "arm_f": Vector2(2.7, 3.0), "arm_b": Vector2(2.4, 2.8), "sword": 3.7,
		"foot_f": Vector2(5, 0), "foot_b": Vector2(-5, 0)})
	POSES["cut1"] = Puppet.pose({"lean": 0.4, "crouch": 3.0, "foot_f": Vector2(8, 0), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(1.3, 1.5), "arm_b": Vector2(1.0, 1.4), "sword": 1.75})
	POSES["raise2"] = Puppet.pose({"lean": 0.25, "crouch": 3.0, "arm_f": Vector2(0.2, 0.5), "arm_b": Vector2(0.2, 0.4),
		"sword": 0.4, "foot_f": Vector2(6, 0), "foot_b": Vector2(-5, 0)})
	POSES["cut2"] = Puppet.pose({"lean": -0.05, "arm_f": Vector2(2.4, 2.8), "arm_b": Vector2(2.0, 2.4), "sword": 2.9,
		"foot_f": Vector2(7, 0), "foot_b": Vector2(-5, 0)})
	POSES["raise3"] = Puppet.pose({"lean": -0.15, "crouch": 3.0, "arm_f": Vector2(-0.6, 1.2), "arm_b": Vector2(-0.4, 0.6),
		"sword": 1.57, "foot_f": Vector2(4, 0), "foot_b": Vector2(-7, 0)})
	POSES["cut3"] = Puppet.pose({"lean": 0.45, "crouch": 4.0, "arm_f": Vector2(1.5, 1.57), "arm_b": Vector2(-0.6, -0.3),
		"sword": 1.57, "foot_f": Vector2(10, 0), "foot_b": Vector2(-7, 0)})
	POSES["charge"] = Puppet.pose({"crouch": 5.0, "lean": -0.15, "arm_f": Vector2(3.0, 3.4), "arm_b": Vector2(2.8, 3.2),
		"sword": 4.0, "foot_f": Vector2(6, 0), "foot_b": Vector2(-7, 0)})
	POSES["smash"] = Puppet.pose({"crouch": 5.0, "lean": 0.55, "arm_f": Vector2(1.1, 0.9), "arm_b": Vector2(0.9, 0.8),
		"sword": 1.0, "foot_f": Vector2(9, 0), "foot_b": Vector2(-7, 0)})
	POSES["dodge"] = Puppet.pose({"crouch": 6.0, "lean": 0.7, "foot_f": Vector2(6, -2), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(-0.6, -0.3), "arm_b": Vector2(-0.9, -0.6), "sword": -0.8})
	POSES["backstep"] = Puppet.pose({"crouch": 5.0, "lean": -0.3, "foot_f": Vector2(5, -1), "foot_b": Vector2(-6, 0),
		"arm_f": Vector2(0.9, 1.8), "sword": 2.2})
	POSES["hit"] = Puppet.pose({"lean": -0.45, "head": -0.3, "crouch": 2.0, "arm_f": Vector2(0.3, 0.0), "sword": 0.6,
		"arm_b": Vector2(-0.8, -0.4), "foot_f": Vector2(6, 0), "foot_b": Vector2(-4, 0)})
	POSES["broken"] = Puppet.pose({"crouch": 6.0, "lean": 0.7, "head": 0.4, "arm_f": Vector2(0.1, 0.0), "sword": 0.25,
		"arm_b": Vector2(0.1, 0.0), "foot_f": Vector2(4, 0), "foot_b": Vector2(-4, 0)})
	POSES["jump"] = Puppet.pose({"crouch": 0.0, "foot_f": Vector2(4, -5), "foot_b": Vector2(-3, -3),
		"arm_f": Vector2(1.8, 2.2), "sword": 2.3, "arm_b": Vector2(-1.2, -0.8), "lean": 0.05})
	POSES["fall"] = Puppet.pose({"crouch": 0.0, "foot_f": Vector2(3, -1), "foot_b": Vector2(-4, -2),
		"arm_f": Vector2(1.2, 1.9), "sword": 2.0, "arm_b": Vector2(-1.8, -1.4), "lean": 0.0})
	# ---------- 招式（见 Moves）----------
	# 横斩：刀先拉到身后放平，再整个横扫到身前
	POSES["yoko_raise"] = Puppet.pose({"crouch": 3.2, "lean": -0.12, "head": 0.05, "foot_f": Vector2(6, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(-0.5, -1.3), "arm_b": Vector2(0.2, 0.6), "sword": -1.6})
	POSES["yoko_cut"] = Puppet.pose({"crouch": 3.2, "lean": 0.38, "foot_f": Vector2(10, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(1.45, 1.8), "arm_b": Vector2(0.6, 1.0), "sword": 2.05})
	# 升龙斩：蹲低刀尖拖在身后，再连人带刀往上撩
	POSES["rise_prep"] = Puppet.pose({"crouch": 7.5, "lean": 0.25, "head": 0.1, "foot_f": Vector2(7, 0), "foot_b": Vector2(-7, 0),
		"arm_f": Vector2(0.0, -0.5), "arm_b": Vector2(0.3, 0.7), "sword": -0.4})
	POSES["rise_cut"] = Puppet.pose({"crouch": 0.0, "lean": -0.15, "head": -0.2, "foot_f": Vector2(3, -7), "foot_b": Vector2(-3, -3),
		"arm_f": Vector2(2.7, 3.0), "arm_b": Vector2(2.3, 2.7), "sword": 3.1})
	# 空中斩：腿收起来
	POSES["air_raise1"] = _tuck(POSES["raise1"])
	POSES["air_cut1"] = _tuck(POSES["cut1"])
	POSES["air_raise2"] = _tuck(POSES["raise2"])
	POSES["air_cut2"] = _tuck(POSES["cut2"])
	# 落雷斩：举刀 → 刀尖朝下往下砸 → 落地半跪，刀插在地上
	var pr := _tuck(POSES["raise1"])
	pr["lean"] = -0.2
	POSES["plunge_raise"] = pr
	POSES["plunge_fall"] = Puppet.pose({"crouch": 0.5, "lean": 0.15, "head": 0.25, "foot_f": Vector2(3, -4), "foot_b": Vector2(-3, -6),
		"arm_f": Vector2(0.6, 0.15), "arm_b": Vector2(0.5, 0.1), "sword": 0.05})
	POSES["plunge_land"] = Puppet.pose({"crouch": 8.0, "lean": 0.5, "head": 0.3, "foot_f": Vector2(9, 0), "foot_b": Vector2(-8, 0),
		"arm_f": Vector2(0.9, 0.3), "arm_b": Vector2(0.6, 0.2), "sword": 0.15})
	# 闪身突刺：身体压得很低，刀往前送到底
	var dc: Dictionary = POSES["cut3"].duplicate()
	dc["lean"] = 0.6
	dc["crouch"] = 5.0
	dc["foot_f"] = Vector2(14, 0)
	dc["foot_b"] = Vector2(-10, 0)
	POSES["dash_cut"] = dc


## 空中版本的姿势：腿收起来
static func _tuck(p: Dictionary) -> Dictionary:
	var t := p.duplicate()
	t["crouch"] = minf(float(p["crouch"]), 1.0)
	t["foot_f"] = Vector2(4, -6)
	t["foot_b"] = Vector2(-3, -4)
	return t


func _ready() -> void:
	_build_poses()
	setup_body()
	if index == 2:
		look.cloth = Color("2f6b45")
		look.cloth_dark = Color("1c4630")
		look.cloth_light = Color("4f9a6a")
		look.hair = Color("3a2418")
		look.band = Color("e0b03a")
	scarf_color = look.band
	look.saya = true
	_pose = POSES["relaxed_sheathed"].duplicate()   # 开局刀在鞘里
	_spring.reset(_pose)
	for i in range(7):
		_scarf.append(global_position + Vector2(0, -45))
	max_hp = 200.0
	hp = max_hp
	max_posture = 100.0
	posture_recover_rate = 30.0
	spawn_pos = global_position


func is_alive() -> bool:
	return state != S.DEAD


## 这个键刚按过（输入缓冲里还有）：用掉它返回 true。动作做不了的时候不要调用，让它留在缓冲里
func _pressed(action: String) -> bool:
	if not _buf.has(action):
		return Input.is_action_just_pressed(prefix + action)
	if clock - float(_buf[action]) <= BUFFER_TIME:
		_buf[action] = -10.0
		return true
	return false


func _record_inputs() -> void:
	for a: String in BUFFERED:
		if Input.is_action_just_pressed(prefix + a):
			_buf[a] = clock
	# 双击方向键奔跑
	for d: String in ["left", "right"]:
		if Input.is_action_just_pressed(prefix + d):
			if clock - float(_tap[d]) <= DOUBLE_TAP:
				running = true
			_tap[d] = clock
	if absf(Input.get_axis(prefix + "left", prefix + "right")) < 0.1:
		running = false


func _held(action: String) -> bool:
	return Input.is_action_pressed(prefix + action)


func _enter(s: S) -> void:
	state = s
	state_time = 0.0


func _physics_process(delta: float) -> void:
	clock += delta
	_record_inputs()
	state_time += delta
	parry_timer = maxf(0.0, parry_timer - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invul_timer = maxf(0.0, invul_timer - delta)
	_counter_t = maxf(0.0, _counter_t - delta)
	_pierce_t = maxf(0.0, _pierce_t - delta)
	_dodge_buff_t = maxf(0.0, _dodge_buff_t - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	if state != S.DEAD and state != S.BROKEN:
		tick_posture(delta)
	if is_on_floor():
		air_jumps = 1
		if state != S.ATTACK:
			_air_attacks = 0

	if frozen:
		velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
		apply_gravity(delta)
		move_and_slide()
		_update_art(delta)
		queue_redraw()
		return

	match state:
		S.FREE: _state_free(delta)
		S.CHARGE: _state_charge(delta)
		S.ATTACK: _state_attack(delta)
		S.GUARD: _state_guard(delta)
		S.DODGE: _state_dodge(delta)
		S.HITSTUN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= _stun_time:
				_enter(S.FREE)
		S.BROKEN:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time >= BROKEN_TIME:
				posture = 0.0
				_enter(S.FREE)
		S.EXECUTE:
			velocity.x = 0.0
			if state_time >= EXECUTE_TIME:
				_enter(S.FREE)
		S.DEAD:
			velocity.x = 0.0
			respawn_timer -= delta
			if respawn_timer <= 0.0 and auto_respawn:
				respawn()
		S.DRINK: _state_drink(delta)
		S.ART: _state_art(delta)

	if state != S.DODGE:
		apply_gravity(delta)
	_check_stomp()
	move_and_slide()
	_update_art(delta)
	queue_redraw()


# ---------- 各状态 ----------

func _state_free(delta: float) -> void:
	var dir := Input.get_axis(prefix + "left", prefix + "right")
	# 起步和刹车有很短的加减速，动作才接得上
	var accel := 2000.0 if absf(dir) > 0.1 else 2600.0
	velocity.x = move_toward(velocity.x, dir * move_speed(), accel * delta)
	if absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1
	if _pressed("jump"):
		_try_jump()
	if _pressed("guard"):
		_start_guard()
	elif dodge_cooldown <= 0.0 and _pressed("dodge"):
		_start_dodge(dir)
	elif _pressed("attack"):
		_attack_pressed()
	elif _pressed("stance"):
		switch_stance(1)
	elif _pressed("art"):
		_start_art()
	elif is_on_floor() and _pressed("heal"):
		_start_drink()


func _state_charge(delta: float) -> void:
	charge_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if _pressed("guard"):
		_start_guard()
	elif dodge_cooldown <= 0.0 and _pressed("dodge"):
		_start_dodge(Input.get_axis(prefix + "left", prefix + "right"))
	elif _pressed("jump"):
		_enter(S.FREE)
		_try_jump()
	elif charge_time >= charge_needed():
		_start_move("heavy")
	elif not _held("attack"):
		_start_move("slash1")


func _state_attack(delta: float) -> void:
	var plunge: bool = attack.get("plunge", false)
	var lunging: bool = attack_phase == 1 and attack.has("lunge")
	if not plunge and not lunging:
		velocity.x = move_toward(velocity.x, 0.0, (500.0 if not is_on_floor() else 1300.0) * delta)
	if attack.get("hang", false) and attack_phase < 2:
		velocity.y = minf(velocity.y, 30.0)   # 空中出刀时停一下，不往下掉
	if _pressed("attack"):
		combo_queued = true
	# 格挡、闪身随时能取消轻攻击（重攻击和落雷斩出刀那一下不行）；跳在前摇和后摇时能取消
	var locked: bool = attack_phase == 1 and (bool(attack["heavy"]) or plunge)
	if not locked:
		if _pressed("guard"):
			_start_guard()
			return
		if dodge_cooldown <= 0.0 and _pressed("dodge"):
			_start_dodge(Input.get_axis(prefix + "left", prefix + "right"))
			return
	if attack_phase != 1 and not plunge and (is_on_floor() or air_jumps > 0) and _pressed("jump"):
		_enter(S.FREE)
		_try_jump()
		return
	if attack_phase == 2 and _pressed("art"):
		_start_art()
		if state == S.ART:
			return

	var windup: float = attack["windup"]
	var active: float = attack["active"]
	var recover: float = attack["recover"]
	if attack_phase == 0 and state_time >= windup:
		attack_phase = 1
		state_time = 0.0
		hit_targets.clear()
		velocity.x = facing * float(attack.get("lunge", 105.0))   # 出刀时向前踏一步
		if attack.has("vy"):
			velocity.y = float(attack["vy"])
		_spawn_slash()
	if attack_phase == 1:
		if plunge:
			velocity = Vector2(facing * 40.0, 760.0)
		_check_attack_hits()
		if plunge and (is_on_floor() or state_time >= active):
			_plunge_land()
			attack_phase = 2
			state_time = 0.0
		elif not plunge and state_time >= active:
			attack_phase = 2
			state_time = 0.0
	if attack_phase == 2:
		if combo_queued and state_time >= 0.04:
			var target: Enemy = main.find_executable(self)
			if target != null:
				_start_execute(target)
				return
			var nxt := _next_move()
			if nxt != "":
				_start_move(nxt)
			else:
				combo_queued = false
		elif state_time >= recover:
			combo_step = 0
			_enter(S.FREE)


## 连段里下一招：地面按住下是升龙斩，空中按住下是落雷斩，否则接表里的 next
func _next_move() -> String:
	if attack.get("heavy", false) and not attack.get("plunge", false):
		return ""
	var id: String = attack.get("id", "")
	if is_on_floor():
		if _held("down") and id != "rising":
			return "rising"
		var n: String = attack.get("next", "")
		return "" if n.begins_with("air") else n
	if _held("down") and id != "plunge":
		return "plunge"
	var n2: String = attack.get("next", "")
	if n2 != "" and _air_attacks < AIR_ATTACKS:
		return n2
	return ""


## 落雷斩落地：前后震开一圈
func _plunge_land() -> void:
	var shock: Dictionary = attack["shock"]
	var size: Vector2 = shock["size"]
	var r := Rect2(global_position + Vector2(-size.x / 2.0, -size.y), size)
	var col := Color(1.0, 0.8, 0.45)
	main.spawn_ring(global_position + Vector2(0, -4), col, 54.0)
	main.spawn_slash(global_position + Vector2(0, -4), 1, 50.0, -0.25, 0.0, col, 5.0)
	main.spawn_slash(global_position + Vector2(0, -4), -1, 50.0, -0.25, 0.0, col, 5.0)
	main.spawn_dust(global_position, 1.0, 10)
	main.spawn_dust(global_position, -1.0, 10)
	main.shake(5.0)
	main.punch(0.05)
	_squash = Vector2(1.25, 0.8)
	var info := {"dmg": shock["dmg"], "posture": shock["posture"], "heavy": shock["heavy"]}
	for e: Enemy in main.get_enemies():
		if e in hit_targets or not e.is_hittable():
			continue
		if r.intersects(e.body_rect()):
			hit_targets.append(e)
			var result := e.receive_player_hit(info, self)
			gain_will(result)
			if result == "hit" and e.is_grunt() and e.state != Enemy.S.DYING:
				e.velocity.y = -220.0   # 震起来


func _state_guard(delta: float) -> void:
	# 格挡时可以慢慢移动、转身
	var dir := Input.get_axis(prefix + "left", prefix + "right")
	velocity.x = move_toward(velocity.x, dir * 60.0, 1300.0 * delta)
	if absf(dir) > 0.1:
		facing = 1 if dir > 0.0 else -1
	if _pressed("guard"):
		_arm_parry()
	if _pressed("attack"):
		_attack_pressed()
		return
	if dodge_cooldown <= 0.0 and _pressed("dodge"):
		_start_dodge(dir)
		return
	if _pressed("jump"):
		_enter(S.FREE)
		_try_jump()
		return
	# 松开格挡后，弹反窗口结束才真正退出格挡
	if not _held("guard") and parry_timer <= 0.0:
		_enter(S.FREE)


func _state_drink(delta: float) -> void:
	# 喝药时只能慢慢走
	var dir := Input.get_axis(prefix + "left", prefix + "right")
	velocity.x = move_toward(velocity.x, dir * 45.0, 900.0 * delta)
	if not _drank and state_time >= DRINK_HEAL_AT:
		_drank = true
		var amount := minf(max_hp * HEAL_RATIO * (1.0 + float(stats["gourd_heal"])), max_hp - hp)
		hp += amount
		flash(Color(0.5, 1.0, 0.6), 0.2)
		main.spawn_text(global_position + Vector2(0, -70), "+%d" % roundi(amount), Color(0.5, 1.0, 0.55))
		main.spawn_spark(global_position + Vector2(0, -30), Color(0.5, 1.0, 0.6), 12)
	if state_time >= DRINK_TIME:
		_enter(S.FREE)


func _state_art(delta: float) -> void:
	var windup: float = ART["windup"]
	var active: float = ART["active"]
	var recover: float = ART["recover"]
	var t := state_time - windup
	if t < 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
		return
	if t < active:
		velocity.x = facing * 130.0
		invul_timer = maxf(invul_timer, 0.05)
		var tick := int(t / (active / float(ART["ticks"])))
		if tick != _art_tick:
			_art_tick = tick
			hit_targets.clear()
			var c := global_position + Vector2(0, -26)
			main.spawn_slash(c, facing, 50.0, -3.0, 0.3, Color(1.0, 0.85, 0.45), 9.0)
			main.spawn_slash(c, -facing, 46.0, -2.6, 0.5, Color(1.0, 0.85, 0.45), 7.0)
			main.spawn_dust(global_position, float(facing), 6)
			main.shake(2.0)
		var r := Rect2(global_position + Vector2(-60.0 + facing * 8.0, -46.0), ART["size"])
		for e: Enemy in main.get_enemies():
			if e in hit_targets or not e.is_hittable():
				continue
			if r.intersects(e.body_rect()):
				hit_targets.append(e)
				var result := e.receive_player_hit(ART, self)
				if result == "hit" or result == "guardbreak":
					main.hitstop(0.05)
		return
	velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
	if t >= active + recover:
		_enter(S.FREE)


func _state_dodge(_delta: float) -> void:
	velocity.x = dodge_dir * DODGE_SPEED * (1.0 + float(stats["dodge_speed"]))
	velocity.y = 0.0   # 空中闪身保持高度
	if _pressed("attack") and state_time >= 0.06:
		# 闪身中按攻击：顺势突刺
		facing = dodge_dir
		_start_move("dash" if is_on_floor() else "air1")
		return
	if state_time >= DODGE_TIME:
		velocity.x = dodge_dir * 90.0
		_dodge_end = clock
		if float(stats["dodge_dmg"]) > 0.0:
			_dodge_buff_t = 1.0
		_enter(S.FREE)


# ---------- 动作 ----------

func _try_jump() -> void:
	if _drop_t > 0.0:
		return   # 刚穿下平台，这一下跳不算
	if on_platform() and _held("down"):
		drop_through()   # 下+跳：从平台上跳下去
		return
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		_squash = Vector2(0.85, 1.15)
		main.spawn_dust(global_position, 0.0, 6)
	elif air_jumps > 0:
		main.spawn_dust(global_position, 0.0, 4)
		_spin_time = 0.0
		air_jumps -= 1
		velocity.y = JUMP_VELOCITY * 0.9


func _attack_pressed() -> void:
	var target: Enemy = main.find_executable(self)
	if target != null:
		_start_execute(target)
		return
	if not is_on_floor():
		if _held("down"):
			_start_move("plunge")
		elif _air_attacks < AIR_ATTACKS:
			_start_move("air1")
		return
	if _held("down"):
		_start_move("rising")
		return
	if clock - _dodge_end < DASH_WINDOW:
		_start_move("dash")
		return
	charge_time = 0.0
	_enter(S.CHARGE)


func _start_move(id: String) -> void:
	var m := Moves.get_move(id)
	if m.get("air", false) and not m.get("plunge", false):
		_air_attacks += 1
	_start_attack(m, int(m.get("combo", -1)))


func _start_attack(data: Dictionary, step: int) -> void:
	var st := stance()
	if step == 0 and not bool(data["heavy"]):
		data = Stance.first_strike(data, st)
	elif not bool(data["heavy"]):
		data = data.duplicate()
	if not bool(data["heavy"]):
		data["recover"] = float(data["recover"]) * float(st["recover"])
	data = _weapon_scaled(data)
	attack = data
	combo_step = step
	combo_queued = false
	attack_phase = 0
	hit_targets.clear()
	_enter(S.ATTACK)


func _start_guard() -> void:
	_enter(S.GUARD)
	_arm_parry()


func _arm_parry() -> void:
	var window := Game.parry_window() + float(stance()["parry_bonus"]) + float(stats["parry"]) \
		+ (0.03 if weapon["trait"] == "crush" else 0.0)
	if clock - last_guard_press < GUARD_SPAM_GAP:
		window *= GUARD_SPAM_FACTOR   # 乱按惩罚
	last_guard_press = clock
	parry_timer = window


func _start_dodge(dir: float) -> void:
	if absf(dir) > 0.1:
		dodge_dir = 1 if dir > 0.0 else -1
	else:
		dodge_dir = -facing   # 不按方向时向后撤步
	var cd := 1.0 + float(stats["dodge_cd"]) - (0.3 if weapon["trait"] == "bleed" else 0.0)
	dodge_cooldown = DODGE_COOLDOWN * maxf(cd, 0.3) + DODGE_TIME
	invul_timer = DODGE_INVUL
	_enter(S.DODGE)
	if is_on_floor():
		main.spawn_dust(global_position, -dodge_dir, 6)


func _start_drink() -> void:
	if gourds <= 0:
		main.spawn_text(global_position + Vector2(0, -70), "药罐空了", Color(0.7, 0.7, 0.75), 12)
		return
	gourds -= 1
	_drank = false
	_enter(S.DRINK)


func _start_art() -> void:
	if will < art_cost():
		main.spawn_text(global_position + Vector2(0, -70), "刃意不足", Color(0.7, 0.7, 0.75), 12)
		return
	will -= art_cost()
	_art_tick = -1
	hit_targets.clear()
	_enter(S.ART)
	flash(Color(1.0, 0.85, 0.4), 0.12)
	main.spawn_text(global_position + Vector2(0, -74), "回旋斩", Color(1.0, 0.85, 0.4), 14)


func gain_will(kind: String) -> void:
	var k := float(stance()["will"]) * (1.0 + float(stats["will"]))
	if hp < max_hp * 0.3:
		k *= 1.0 + float(stats["low_will"])
	will = minf(MAX_WILL, will + float(WILL_GAIN.get(kind, 0.0)) * k)


func stance() -> Dictionary:
	return Stance.get_data(stance_index)


func switch_stance(step: int) -> void:
	stance_index = posmod(stance_index + step, Stance.LIST.size())
	_switch_t = 0.0
	_drawn_timer = 0.0
	_fl_kind = ""
	main.spawn_text(global_position + Vector2(0, -74), stance()["name"] + "式", Color(0.85, 0.9, 1.0), 12)


## 拔刀式下刀是否收在鞘里
func is_sheathed() -> bool:
	return _sheath and _batto_t < 0.0 and (state == S.FREE or state == S.CHARGE)


## 该不该拔刀：附近有敌人、刚打完、在耍刀或换架势时拔着；拔刀式在鞘里等着
func _wants_drawn() -> bool:
	if state != S.FREE and state != S.CHARGE:
		return true
	if _drawn_timer > 0.0 or _fl_kind != "" or _switch_t >= 0.0:
		return true
	if bool(stance()["sheathed"]):
		return false
	var e: Enemy = main.nearest_enemy(global_position, COMBAT_RANGE)
	return e != null and e.is_hittable()


func _start_execute(target: Enemy) -> void:
	facing = 1 if target.global_position.x >= global_position.x else -1
	_enter(S.EXECUTE)
	target.execute_by(self)
	gain_will("execute")
	if float(stats["exec_heal"]) > 0.0:
		heal(max_hp * float(stats["exec_heal"]))
	if float(stats["exec_pierce"]) > 0.0:
		_pierce_t = float(stats["exec_pierce"])
	_victory = "overhead" if target.lives <= 0 else "wheel"


func _attack_rect() -> Rect2:
	var size: Vector2 = attack["size"]
	if attack.get("around", false):
		return Rect2(global_position + Vector2(-size.x / 2.0, -float(attack["height"]) - size.y / 2.0), size)
	return front_rect(attack["reach"], size, attack["height"])


func _check_attack_hits() -> void:
	var r := _attack_rect()
	for e: Enemy in main.get_enemies():
		if e in hit_targets or not e.is_hittable():
			continue
		if r.intersects(e.body_rect()):
			hit_targets.append(e)
			var result := e.receive_player_hit(attack, self)
			gain_will(result)
			if result == "hit" and attack.has("launch") and e.is_grunt() and e.state != Enemy.S.DYING:
				# 挑飞杂兵
				e.velocity.y = float(attack["launch"])
				e._stagger(0.8)
			if result == "blocked":
				velocity.x = -facing * 135.0
			elif result == "guardbreak":
				main.hitstop(0.06)


## 下落时踩到敌人头上：可以再跳一次；敌人正在下段横扫时奖励架势
func _check_stomp() -> void:
	if velocity.y <= 0.0 or state == S.DEAD:
		return
	for e: Enemy in main.get_enemies():
		if not e.is_hittable():
			continue
		var head := e.body_rect()
		var feet := global_position
		if feet.x > head.position.x - 9.0 and feet.x < head.end.x + 9.0 \
				and feet.y > head.position.y - 6.0 and feet.y < head.position.y + 15.0:
			velocity.y = JUMP_VELOCITY * 0.85
			air_jumps = 1
			e.on_stomped(self)
			gain_will("stomp")
			return


# ---------- 装备和天赋的数值 ----------

## 按装备表重算数值：武器、外观跟着换
func apply_loadout(s: Dictionary) -> void:
	stats = s
	weapon = GearData.weapon_stats(gear["weapon"])
	look.weapon = weapon["id"]
	look.sword_len = float(weapon["len"])
	look.saya = weapon["id"] == "katana" or weapon["id"] == "dual"
	look.helm = gear["head"]["base"] if gear["head"] != null else ""
	look.armor = gear["body"]["base"] if gear["body"] != null else ""
	posture_recover_rate = 30.0 * (1.0 + float(s["posture_rec"]))


func move_speed() -> float:
	return (MOVE_SPEED if running else WALK_SPEED) * maxf(0.5, 1.0 + float(stats["move"]))


func charge_needed() -> float:
	return maxf(0.25, HEAVY_CHARGE_TIME - float(stats["charge"]))


func art_cost() -> float:
	return maxf(10.0, float(ART["cost"]) - float(stats["art_cost"]))


## 受到伤害的倍率：防御 d 时 × 60 / (60 + d)，金刚再减
func damage_taken_mult() -> float:
	return 60.0 / (60.0 + float(stats["def"])) * maxf(0.2, 1.0 + float(stats["dmg_taken"]))


func heal(amount: float) -> void:
	var add := minf(amount, max_hp - hp)
	if add <= 0.5 or state == S.DEAD:
		return
	hp += add
	main.spawn_text(global_position + Vector2(0, -64), "+%d" % roundi(add), Color(0.5, 1.0, 0.55), 12)


func _super_armor() -> bool:
	if weapon["trait"] != "armor":
		return false
	return state == S.CHARGE or (state == S.ATTACK and bool(attack.get("heavy", false)))


## 招式表里的数值按武器换算：伤害、架势、出手快慢、距离
func _weapon_scaled(data: Dictionary) -> Dictionary:
	var d := data.duplicate()
	d["dmg"] = float(d["dmg"]) * float(weapon["dmg"])
	d["posture"] = float(d["posture"]) * float(weapon["posture"])
	var sp := float(weapon["speed"])
	if not d.get("plunge", false):
		d["windup"] = float(d["windup"]) * sp
	d["recover"] = float(d["recover"]) * sp
	var rk := float(weapon["reach"])
	var size: Vector2 = d["size"]
	if d.get("around", false):
		d["size"] = Vector2(size.x * lerpf(1.0, rk, 0.5), size.y)
	else:
		# 判定框往前长：框的后边不动，前边按倍率伸出去
		var back := float(d["reach"]) - size.x / 2.0
		var new_w := size.x * rk
		d["size"] = Vector2(new_w, size.y)
		d["reach"] = back + new_w / 2.0
	if weapon["trait"] == "pierce" and (d.get("id", "") == "slash4" or d.get("id", "") == "dash"):
		d["pierce"] = true
	return d


## 一刀打到敌人身上的实际数值：伤害、架势伤害、能不能破防、会不会会心
func strike(atk: Dictionary, e: Enemy) -> Dictionary:
	var mult := 1.0 + float(stats["atk"])
	if hp < max_hp * float(stats["low_dmg_line"]):
		mult += float(stats["low_dmg"])
	if _dodge_buff_t > 0.0:
		mult += float(stats["dodge_dmg"])
	if e.max_posture > 0.0 and e.posture >= e.max_posture * 0.5:
		mult += float(stats["pressure"])
	if int(atk.get("combo", -1)) >= 3:
		mult += float(stats["combo_end"])
	if bool(atk.get("heavy", false)) and atk.get("id", "") in ["heavy", "plunge"]:
		mult += float(stats["heavy_dmg"])
	var counter := false
	if _counter_t > 0.0 and not atk.has("ticks"):
		mult += 0.6
		_counter_t = 0.0
		counter = true
	var crit := randf() < minf(0.6, float(stats["crit"]))
	if crit:
		mult *= 1.0 + float(stats["crit_dmg"])
	return {
		"dmg": float(atk["dmg"]) * mult,
		"posture": float(atk["posture"]) * (1.0 + float(stats["pdmg"])),
		"heavy": bool(atk["heavy"]) or bool(atk.get("pierce", false)) or _pierce_t > 0.0,
		"crit": crit, "counter": counter,
	}


## 这一刀真的砍到肉了（没被挡）：吸血、流血
func on_hit_landed(e: Enemy, hit: Dictionary) -> void:
	if float(stats["lifesteal"]) > 0.0:
		hp = minf(max_hp, hp + float(hit["dmg"]) * float(stats["lifesteal"]))
	if weapon["trait"] == "bleed":
		e.add_bleed()
	if hit["crit"]:
		main.spawn_text(e.global_position + Vector2(randf_range(-8, 8), -e.body_size.y - 40.0), "会心", Color(1.0, 0.85, 0.3), 12)
	elif hit["counter"]:
		main.spawn_text(e.global_position + Vector2(0, -e.body_size.y - 40.0), "追击", Color(0.9, 0.95, 1.0), 12)


# ---------- 受击 ----------

## 敌人攻击命中判定框时调用。返回 parry / block / hit / miss / mikiri
func receive_enemy_hit(info: Dictionary, attacker: Node2D) -> String:
	if state == S.DEAD or state == S.EXECUTE:
		return "miss"
	var to_attacker := 1 if attacker.global_position.x >= global_position.x else -1
	var kind: String = info["kind"]
	if invul_timer > 0.0:
		if kind == "thrust" and state == S.DODGE and dodge_dir == -int(attacker.get("facing")):
			gain_will("mikiri")
			return "mikiri"   # 看破：迎着突刺方向闪身
		return "miss"
	if kind == "sweep" and not is_on_floor():
		return "miss"         # 跳过下段横扫
	var p: float = info["posture"]
	var unblockable: bool = info["unblockable"]
	if not unblockable and state == S.GUARD and facing == to_attacker:
		if parry_timer > 0.0:
			parry_timer = 0.0
			parry_count += 1
			gain_will("parry")
			flash(Color(1.0, 0.95, 0.5), 0.15)
			add_posture(p * 0.25)
			if float(stats["parry_heal"]) > 0.0:
				heal(max_hp * float(stats["parry_heal"]))
			will = minf(MAX_WILL, will + float(stats["parry_will"]))
			if weapon["trait"] == "counter":
				_counter_t = 2.0
			return "parry"
		add_posture(p * float(stance()["block_posture"]) * maxf(0.1, 1.0 + float(stats["block_posture"])))
		if state != S.BROKEN:
			velocity.x = -to_attacker * 165.0
		return "block"
	var dmg: float = float(info["dmg"]) * damage_taken_mult()
	hp -= dmg
	flash(Color(1.0, 0.3, 0.3), 0.15)
	main.spawn_blood(global_position + Vector2(0, -28), -to_attacker, 10)
	if hp <= 0.0:
		_die()
		return "hit"
	add_posture(p * 0.5)
	if _super_armor() and kind != "grab":
		# 野太刀霸体：吃下这一刀，动作不停
		flash(Color(1.0, 0.75, 0.4), 0.1)
		return "hit"
	velocity.x = -to_attacker * 210.0
	if state != S.BROKEN:
		_stun_time = float(info.get("stun", HITSTUN_TIME))
		if kind == "grab":
			velocity = Vector2(-to_attacker * 260.0, -240.0)   # 被抓起来摔出去
		_enter(S.HITSTUN)
	return "hit"


func _on_posture_full() -> void:
	if state == S.DEAD:
		return
	_enter(S.BROKEN)
	parry_timer = 0.0
	main.spawn_text(global_position + Vector2(0, -70), "破防", Color(1.0, 0.5, 0.2))


func _die() -> void:
	if revives > 0:
		# 不死身：倒下一次，以一半生命站起来
		revives -= 1
		hp = max_hp * 0.5
		posture = 0.0
		invul_timer = 1.0
		flash(Color(1.0, 0.9, 0.5), 0.3)
		main.spawn_text(global_position + Vector2(0, -70), "不死身", Color(1.0, 0.85, 0.4), 14)
		main.spawn_ring(global_position + Vector2(0, -26), Color(1.0, 0.85, 0.4), 40.0)
		_enter(S.FREE)
		return
	hp = 0.0
	_enter(S.DEAD)
	respawn_timer = RESPAWN_TIME
	main.spawn_text(global_position + Vector2(0, -70), "倒下", Color(0.9, 0.2, 0.2))


func respawn() -> void:
	hp = max_hp
	posture = 0.0
	global_position = spawn_pos
	velocity = Vector2.ZERO
	_enter(S.FREE)


# ---------- 美术 ----------

func _spawn_slash() -> void:
	var heavy: bool = attack["heavy"]
	var center := global_position + Vector2(facing * 9.0, -26.0)
	var big: bool = attack.get("stance", "") == "jodan"
	var col := Color(1.0, 0.75, 0.4) if heavy or big else Color(0.75, 0.9, 1.0)
	var fx: Array = attack.get("fx", ["none"])
	match String(fx[0]):
		"slash":
			var r: float = fx[1]
			var w: float = fx[4]
			if big:
				r += 2.0
				w += 3.0
			main.spawn_slash(center, facing, r, fx[2], fx[3], col, w)
		"flat":
			# 横斩：从侧面看是一道又平又长的刀光
			main.spawn_slash(center + Vector2(0, 2), facing, fx[1], -0.45, 0.35, col, 6.0)
			main.spawn_streak(global_position + Vector2(facing * 2.0, -26.0), facing, 54.0, col)
		"streak":
			main.spawn_streak(global_position + Vector2(facing * 6.0, -24.0), facing, fx[1], col)
		"iai":
			# 居合：一道又长又平的横斩
			var c2 := Color(1.0, 0.95, 0.75)
			main.spawn_slash(center + Vector2(facing * 4.0, 0), facing, 48.0, -0.5, 0.55, c2, 6.0)
			main.spawn_streak(global_position + Vector2(facing * 4.0, -25.0), facing, 80.0, c2)
		"spin":
			var c3 := Color(0.85, 0.95, 1.0)
			var c := global_position + Vector2(0, -24)
			main.spawn_slash(c, facing, 48.0, -3.0, 0.3, c3, 8.0)
			main.spawn_slash(c, -facing, 44.0, -2.6, 0.5, c3, 6.0)
			main.spawn_dust(global_position, float(facing), 6)
	if heavy:
		main.punch(0.04)
	if attack.has("vy") and is_on_floor():
		main.spawn_dust(global_position, 0.0, 8)


func _target_pose() -> Dictionary:
	var t := state_time
	match state:
		S.FREE:
			if not is_on_floor():
				if _spin_time >= 0.0:
					return Puppet.pose({"crouch": 5.0, "lean": 0.5, "foot_f": Vector2(4, -6), "foot_b": Vector2(-2, -5),
						"arm_f": Vector2(1.2, 2.2), "arm_b": Vector2(1.0, 2.0), "sword": 1.0})
				return POSES["jump"] if velocity.y < 0.0 else POSES["fall"]
			if _land_timer > 0.0:
				return POSES["land"]
			if absf(velocity.x) > 10.0:
				return _run_pose()
			return _idle_pose()
		S.CHARGE:
			# 短按时还停在架势上（拔刀式刀不出鞘），按久了才举刀蓄力
			var cp: Dictionary = Puppet.lerp_pose(_stance_pose(), POSES["charge"], (charge_time - 0.1) / 0.25)
			if charge_time >= charge_needed() - 0.1:
				cp["dx"] = sin(clock * 90.0) * 0.8   # 蓄满时抖动
			return cp
		S.ATTACK:
			var keys: Array = [attack["raise"], attack["cut"]]
			var active: float = attack["active"]
			var recover: float = attack["recover"]
			if attack_phase == 0:
				return POSES[keys[0]]
			if attack_phase == 1:
				if attack.get("plunge", false):
					return POSES["plunge_fall"]
				return Puppet.lerp_pose(POSES[keys[0]], POSES[keys[1]], t / (active * 0.6))
			var after: Dictionary = _stance_pose(true) if is_on_floor() else POSES["fall"]
			return Puppet.lerp_pose(POSES[keys[1]], after, pow(t / recover, 2.0))
		S.GUARD:
			return POSES["parry"] if parry_timer > 0.0 else POSES["guard"]
		S.DODGE:
			return POSES["dodge"] if dodge_dir == facing else POSES["backstep"]
		S.HITSTUN:
			return POSES["broken"] if _stun_time > 0.5 else POSES["hit"]
		S.DEAD:
			return POSES["kneel"]
		S.DRINK:
			if t < 0.22:
				return Puppet.lerp_pose(POSES["relaxed"], POSES["drink"], t / 0.22)
			if t < DRINK_TIME - 0.2:
				var d: Dictionary = POSES["drink"].duplicate()
				d["head"] = -0.4 - 0.08 * sin(t * 20.0)   # 咕咚咕咚
				return d
			return Puppet.lerp_pose(POSES["drink"], POSES["relaxed"], (t - (DRINK_TIME - 0.2)) / 0.2)
		S.ART:
			return POSES["art_prep"] if t < float(ART["windup"]) else POSES["art_spin"]
		S.BROKEN:
			var bp: Dictionary = POSES["broken"].duplicate()
			bp["lean"] = 0.7 + sin(clock * 4.0) * 0.08
			return bp
		S.EXECUTE:
			return POSES["raise3"] if t < 0.12 else POSES["cut3"]
	return POSES["idle"]


func _run_pose() -> Dictionary:
	var ph := _run_phase
	var s := sin(ph)
	var c := cos(ph)
	var run := Puppet.pose({
		"crouch": 2.2 + absf(s) * 1.6, "lean": 0.34 + absf(s) * 0.04, "head": -0.1,
		"foot_f": Vector2(6.5 * s, -maxf(0.0, 4.5 * c)),
		"foot_b": Vector2(-6.5 * s, -maxf(0.0, -4.5 * c)),
		"arm_f": Vector2(0.55 + 0.08 * s, 2.7), "sword": -2.4 + 0.08 * s,   # 刀扛在肩上
		"arm_b": Vector2(0.9 * -s, 1.2 + 0.4 * -s),
	})
	if is_sheathed():
		# 刀在鞘里：两只手自然前后摆
		run["arm_f"] = Vector2(0.9 * s, 1.2 + 0.4 * s)
		run["sword"] = 0.5
		run["sheathed"] = 1.0
	if not running:
		run = _walk_pose(run)
	# 刚起步、快停下时只迈小步，和站姿混合
	var k := clampf(absf(velocity.x) / (MOVE_SPEED if running else WALK_SPEED), 0.0, 1.0)
	if k < 0.999:
		return Puppet.lerp_pose(_idle_pose(), run, smoothstep(0.0, 1.0, k))
	return run


## 走路：步子小、身子直，手臂（或扛着的刀）跟着轻轻晃
func _walk_pose(run: Dictionary) -> Dictionary:
	var ph := _run_phase
	var s := sin(ph)
	var c := cos(ph)
	var w := run.duplicate()
	w["crouch"] = 1.3 + absf(s) * 0.5
	w["lean"] = 0.1
	w["head"] = 0.0
	w["foot_f"] = Vector2(4.5 * s, -maxf(0.0, 2.2 * c))
	w["foot_b"] = Vector2(-4.5 * s, -maxf(0.0, -2.2 * c))
	w["arm_b"] = Vector2(0.4 * -s, 0.6 + 0.2 * -s)
	if is_sheathed():
		w["arm_f"] = Vector2(0.4 * s, 0.6 + 0.2 * s)
	return w


## 当前架势的姿势；drawn 为 true 时拔刀式也按出鞘算（刚砍完）
func _stance_pose(drawn: bool = false) -> Dictionary:
	var st := stance()
	if bool(st["sheathed"]) and (drawn or not _sheath):
		return POSES["st_seigan"]
	return POSES["st_" + str(st["id"])]


func _idle_pose() -> Dictionary:
	if _fl_kind != "" and not _sheath and _batto_t < 0.0:
		return Flourish.sample(_fl_kind, _fl_t, Puppet.breathe(POSES["relaxed"], clock, 0.6))
	# 敌人靠近时摆架势，远离时放松
	var relaxed: Dictionary = POSES["relaxed_sheathed"] if _sheath and _batto_t < 0.0 else POSES["relaxed"]
	var ready := _stance_pose()
	var p := Puppet.breathe(Puppet.lerp_pose(relaxed, ready, _ready_blend), clock, 1.0 - _ready_blend * 0.4)
	# 摆着架势时重心前后挪、刀尖小幅画圈，像在找出手的机会
	p["dx"] = float(p["dx"]) + 0.7 * sin(clock * 1.3) * _ready_blend
	p["crouch"] = float(p["crouch"]) + 0.35 * sin(clock * 2.6 + 1.0) * _ready_blend
	if not is_sheathed():
		p["sword"] = float(p["sword"]) + 0.07 * sin(clock * 1.9) * _ready_blend
	if _noto_t >= 0.0:
		p = _noto_pose(p)
	if _batto_t >= 0.0:
		p = _batto_pose(p)
	# 换架势：刀在手里转一圈再落到新架势
	if _switch_t >= 0.0 and not is_sheathed():
		var k := clampf(_switch_t / 0.35, 0.0, 1.0)
		p["sword"] = float(p["sword"]) - TAU * (1.0 - pow(1.0 - k, 3.0))
		p["blur"] = -0.35 * (1.0 - k)
	return p


## 纳刀：手往前伸、刀转成和鞘平行，再把手收回鞘口，刀身顺着鞘滑进去
func _noto_pose(base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	var j := Puppet.solve(p)
	var up: Vector2 = j["up"]
	var fwd := Vector2(-up.y, up.x) * -1.0
	if fwd.x < 0.0:
		fwd = -fwd
	var back := (-fwd * 0.93 - up * 0.36).normalized()
	var saya_angle := atan2(back.x, back.y)
	var k1 := smoothstep(0.0, 1.0, _noto_t / 0.2)
	var k2 := smoothstep(0.0, 1.0, (_noto_t - 0.2) / (NOTO_TIME - 0.2))
	var reach := Vector2(1.15, 1.45)                      # 手伸到身前
	var at_mouth: Vector2 = POSES["relaxed_sheathed"]["arm_f"]
	var af: Vector2 = base["arm_f"]
	p["arm_f"] = af.lerp(reach, k1).lerp(at_mouth, k2)
	p["arm_b"] = (base["arm_b"] as Vector2).lerp(Vector2(0.3, 1.1), k1)   # 后手扶住鞘口
	p["sword"] = lerp_angle(float(base["sword"]), saya_angle, k1)
	p["head"] = float(base["head"]) + 0.12 * k1
	return p


## 拔刀：手先握住鞘口的刀柄，往前一抽，刀顺着鞘的方向拔出来再转到架势
func _batto_pose(target: Dictionary) -> Dictionary:
	var p := target.duplicate()
	var j := Puppet.solve(p)
	var up: Vector2 = j["up"]
	var fwd := Vector2(-up.y, up.x) * -1.0
	if fwd.x < 0.0:
		fwd = -fwd
	var back := (-fwd * 0.93 - up * 0.36).normalized()
	var saya_angle := atan2(back.x, back.y)
	var hilt_arm: Vector2 = POSES["st_iai"]["arm_f"]
	var reach := Vector2(1.25, 1.5)
	var tarm: Vector2 = target["arm_f"]
	if _batto_t < 0.1:
		p["arm_f"] = hilt_arm
		p["arm_b"] = Vector2(0.3, 1.1)
		p["sheathed"] = 1.0
		return p
	var k := clampf((_batto_t - 0.1) / (BATTO_TIME - 0.1), 0.0, 1.0)
	p["arm_f"] = hilt_arm.lerp(reach, smoothstep(0.0, 0.5, k)).lerp(tarm, smoothstep(0.5, 1.0, k))
	p["sword"] = lerp_angle(saya_angle + PI, float(target["sword"]), smoothstep(0.3, 1.0, k))
	p["sheathed"] = 0.0
	return p


## 站着没事时轮流耍花刀；处决之后耍一个收势；一动就打断
func _update_flourish(delta: float) -> void:
	var idle := state == S.FREE and is_on_floor() and absf(velocity.x) < 10.0
	if not idle:
		_fl_kind = ""
		if state != S.EXECUTE:
			_victory = ""
		return
	if _fl_kind == "":
		if _victory != "":
			_start_flourish(_victory)
			_victory = ""
		elif _ready_blend < 0.1 and _idle_time > _fl_next:
			_start_flourish(Flourish.pick(Flourish.PLAYER_SHEATHED if bool(stance()["sheathed"]) else Flourish.PLAYER_IDLE, _fl_last))
		return
	if _sheath or _batto_t >= 0.0:
		return   # 先拔刀再耍
	_fl_t += delta
	if _fl_t >= Flourish.duration(_fl_kind):
		_fl_kind = ""
		_fl_next = _idle_time + randf_range(1.2, 2.5)


func _start_flourish(kind: String) -> void:
	_fl_kind = kind
	_fl_last = kind
	_fl_t = 0.0


## 弹簧松紧（频率 Hz，阻尼）：出刀快而甩，待机慢而稳
## 拔刀 / 收刀
func _update_sheath(delta: float) -> void:
	if state != S.FREE and state != S.CHARGE:
		# 出招、格挡、闪身……刀一定在手上（出招本身就是拔刀）
		_drawn_timer = 1.0 if bool(stance()["sheathed"]) else DRAWN_KEEP
		_sheath = false
		_batto_t = -1.0
		_noto_t = -1.0
		return
	if _drawn_timer > 0.0 and is_on_floor() and _fl_kind == "":
		_drawn_timer -= delta
	var want := _wants_drawn()
	if _sheath and want and _batto_t < 0.0:
		_batto_t = 0.0
		_noto_t = -1.0
	if _batto_t >= 0.0:
		_batto_t += delta
		if _batto_t >= BATTO_TIME:
			_batto_t = -1.0
			_sheath = false
	if not _sheath and not want and _noto_t < 0.0 and _batto_t < 0.0 and is_on_floor():
		_noto_t = 0.0
	if _noto_t >= 0.0:
		if want:
			_noto_t = -1.0
			return
		_noto_t += delta
		if _noto_t >= NOTO_TIME:
			_noto_t = -1.0
			_sheath = true
			# 刀完全入鞘：鞘口一点火星
			var j := Puppet.solve(_pose)
			var hip: Vector2 = j["hip"]
			main.spawn_spark(global_position + Vector2((hip.x + 6.0) * facing, hip.y - 3.5), Color(1.0, 0.9, 0.6), 4)


func _spring_params() -> Vector2:
	if _fl_kind != "" or _switch_t >= 0.0 or _noto_t >= 0.0 or _batto_t >= 0.0:
		return Vector2(10.0, 0.95)
	match state:
		S.ATTACK:
			match attack_phase:
				0: return Vector2(10.0, 0.85)
				1: return Vector2(12.0, 0.5)
				_: return Vector2(6.0, 0.75)
		S.EXECUTE, S.ART: return Vector2(11.0, 0.55)
		S.CHARGE: return Vector2(7.0, 0.8)
		S.GUARD: return Vector2(13.0, 0.6) if parry_timer > 0.0 else Vector2(9.0, 0.8)
		S.DODGE: return Vector2(9.0, 0.8)
		S.HITSTUN: return Vector2(9.0, 0.45)
		S.DRINK: return Vector2(6.0, 0.85)
		S.DEAD, S.BROKEN: return Vector2(5.0, 0.8)
	if not is_on_floor():
		return Vector2(7.0, 0.7)
	if _land_timer > 0.0:
		return Vector2(10.0, 0.6)
	if absf(velocity.x) > 10.0:
		return Vector2(8.0, 0.9)
	return Vector2(4.0, 0.8)


func _update_art(delta: float) -> void:
	# 待机时间、落地缓冲、翻身、戒备程度
	if state == S.FREE and is_on_floor() and absf(velocity.x) < 10.0:
		_idle_time += delta
	else:
		_idle_time = 0.0
	_land_timer = maxf(0.0, _land_timer - delta)
	if _spin_time >= 0.0:
		_spin_time += delta
		if _spin_time > 0.32 or is_on_floor():
			_spin_time = -1.0
	var near: Enemy = main.nearest_enemy(global_position, 170.0)
	var want := 1.0 if near != null and near.is_hittable() else 0.0
	_ready_blend = move_toward(_ready_blend, want, delta * 3.0)
	if want > 0.0:
		_idle_time = 0.0
		_fl_next = 2.5
	_update_flourish(delta)
	# 架势切换动画、拔刀式收刀
	if _switch_t >= 0.0:
		_switch_t += delta
		if _switch_t > 0.35:
			_switch_t = -1.0
	_update_sheath(delta)
	if facing != _prev_facing:
		_turn_t = 0.0   # 转身：身体先收窄再展开，像在原地转过来
		_prev_facing = facing
	_turn_t = minf(_turn_t + delta / TURN_TIME, 1.0)
	if absf(velocity.x) > 10.0 and is_on_floor():
		_run_phase += absf(velocity.x) * delta * 0.074

	# 姿势用弹簧追目标：不同动作用不同的松紧
	var sp := _spring_params()
	_pose = _spring.step(_target_pose(), sp.x, sp.y, delta)
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))

	# 落地扬尘和压扁
	if is_on_floor() and not _was_on_floor:
		main.spawn_dust(global_position, 0.0, 6)
		_squash = Vector2(1.18, 0.84)
		if state == S.FREE:
			_land_timer = 0.1
	_was_on_floor = is_on_floor()

	# 闪身残影
	_ghost_timer -= delta
	var dashing: bool = state == S.ATTACK and attack.get("ghost", false) and attack_phase == 1
	if (state == S.DODGE or dashing) and _ghost_timer <= 0.0:
		_ghost_timer = 0.03 if dashing else 0.04
		main.spawn_ghost(global_position, _pose.duplicate(), look, facing, color)

	# 头带飘带：每一节跟随前一节，受风和速度影响
	var j := Puppet.solve(_pose)
	var head: Vector2 = j["head"]
	var anchor := global_position + Vector2((head.x - 5.0) * facing, head.y - 2.0) * look.scale
	_scarf[0] = anchor
	for i in range(1, _scarf.size()):
		var wave := sin(clock * 10.0 - i * 0.9) * 1.4
		var target := _scarf[i - 1] + Vector2(-facing * 3.6 - velocity.x * 0.012, 0.7 + wave - velocity.y * 0.006)
		_scarf[i] = _scarf[i].lerp(target, 1.0 - exp(-32.0 * delta))
		if _scarf[i].distance_to(_scarf[i - 1]) > 4.5:
			_scarf[i] = _scarf[i - 1] + (_scarf[i] - _scarf[i - 1]).normalized() * 4.5


func _draw() -> void:
	var top := Puppet.head_top(look)
	# 影子
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tint := Color(0, 0, 0, 0)
	if flash_timer > 0.0:
		# 喝药、放招式时只是淡淡一层颜色，受击才整个闪白
		tint = Color(flash_color, 0.45 if state == S.DRINK or state == S.ART else 1.0)
	elif state == S.BROKEN:
		tint = Color(0.2, 0.2, 0.25, 0.35)
	var alpha := 0.6 if state == S.DODGE else 1.0

	# 头带飘带画在身体后面
	if _scarf.size() > 1 and state != S.DEAD:
		var pts := PackedVector2Array()
		for pt in _scarf:
			pts.append(pt - global_position)
		draw_polyline(pts, Color(0.03, 0.03, 0.06, alpha), 4.0)
		draw_polyline(pts, Color(scarf_color, alpha), 2.0)
		draw_polyline(pts.slice(0, 3), Color(scarf_color.lightened(0.3), alpha), 1.0)

	var rim := Color(0.5, 0.62, 0.9, 0.5)
	if state == S.DEAD:
		# 先跪下，再往前扑倒
		var k := _ease_out_bounce(clampf((state_time - 0.35) / 0.4, 0.0, 1.0))
		var rot := facing * PI / 2.0 * k
		var pivot := Vector2(facing * 8.0, 0)
		var off := pivot - pivot.rotated(rot)
		Puppet.draw_lit(self, _pose, look, facing, rim, off + Vector2(0, -2.0 * k), Color(0.15, 0.15, 0.2, 0.35 * k), 1.0, rot)
	elif (state == S.ART and state_time >= float(ART["windup"])) or (state == S.ATTACK and attack.get("spin", false) and attack_phase == 1):
		# 回旋斩、旋风斩：横向压扁再翻面，假装在原地转身
		var turn := 0.0
		if state == S.ART:
			turn = (state_time - float(ART["windup"])) / float(ART["active"]) * float(ART["ticks"]) * TAU
		else:
			turn = state_time / float(attack["active"]) * TAU
		var c := cos(turn)
		var f := facing if c >= 0.0 else -facing
		var sq := Vector2(maxf(absf(c), 0.25), 1.0) * _squash
		Puppet.draw_lit(self, _pose, look, f, Color(1.0, 0.85, 0.45, 0.7), Vector2.ZERO, tint, alpha, 0.0, sq, velocity.x)
	else:
		var spin := 0.0
		var spin_off := Vector2.ZERO
		if _spin_time >= 0.0:
			spin = facing * TAU * clampf(_spin_time / 0.32, 0.0, 1.0)
			# 绕身体中心翻转
			var pivot := Vector2(0, -26)
			spin_off = pivot - pivot.rotated(spin)
		var turn := lerpf(0.2, 1.0, smoothstep(0.0, 1.0, _turn_t))
		Puppet.draw_lit(self, _pose, look, facing, rim, spin_off, tint, alpha, spin, _squash * Vector2(turn, 1.0), velocity.x)

	if state == S.DRINK:
		_draw_gourd()

	# 弹反窗口内刀身发光
	if state == S.GUARD and parry_timer > 0.0:
		var tip := Puppet.sword_tip(_pose, look, facing)
		draw_circle(tip, 3.5, Color(1.0, 0.95, 0.6, 0.5))
		draw_circle(tip, 2.0, Color(1.0, 1.0, 0.85))
	if state == S.CHARGE:
		var ratio := clampf(charge_time / charge_needed(), 0.0, 1.0)
		var full := ratio >= 1.0
		draw_rect(Rect2(-14, 5, 28, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-14, 5, 28 * ratio, 3), Color(1, 1, 1) if full else Color(1.0, 0.6, 0.2))
	if state == S.BROKEN:
		_draw_label("破防", Vector2(0, top - 14), Color(1.0, 0.5, 0.2), 12)

	# 头顶：编号和架势条
	_draw_label("%dP" % index, Vector2(0, top - 7), color.lightened(0.3), 12)
	if posture > 0.5 and state != S.DEAD:
		draw_posture_bar(Vector2(0, top - 4), 34.0, posture / max_posture)

	if Game.show_hitboxes:
		var w := body_size.x
		var h := body_size.y
		draw_rect(Rect2(-w / 2.0, -h, w, h), Color(0, 1, 0, 0.6), false)
		if state == S.ATTACK and attack_phase == 1:
			var size: Vector2 = attack["size"]
			draw_rect(to_local_rect(front_rect(attack["reach"], size, attack["height"])), Color(1, 0, 0, 0.6), false)


## 葫芦药罐，拿在后手上
func _draw_gourd() -> void:
	var j := Puppet.solve(_pose)
	var hb: Vector2 = j["hand_b"]
	var at := Vector2(hb.x * facing, hb.y) * look.scale
	var tilt := Vector2(facing * 1.5, -1.5)        # 罐口朝嘴
	var outline := Color(0.03, 0.02, 0.04)
	draw_circle(at - tilt, 4.0, outline)
	draw_circle(at + tilt * 0.6, 3.0, outline)
	draw_circle(at - tilt, 3.0, Color("8a2f24"))
	draw_circle(at + tilt * 0.6, 2.0, Color("a5402f"))
	draw_rect(Rect2(at - tilt + Vector2(-1, -1), Vector2(1, 1)), Color("d9775a"))
	draw_line(at + tilt * 0.2, at + tilt * 0.2 + Vector2(0, 2), Color("d8c08a"), 1.0)   # 系绳


static func _ease_out_bounce(x: float) -> float:
	if x < 0.7:
		return pow(x / 0.7, 2.0)
	return 1.0 - 0.08 * sin((x - 0.7) / 0.3 * PI)


func _draw_label(text: String, pos: Vector2, col: Color, size: int) -> void:
	var w := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := (pos - Vector2(w / 2.0, 0)).round()
	draw_string_outline(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.9))
	draw_string(Game.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
