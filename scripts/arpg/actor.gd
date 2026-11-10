class_name Actor
extends CharacterBody3D
## 主角和敌人的共同部分：血量、体素人偶、顿帧冻结、击退、受击闪白、出血叠层、无敌帧。
## 时间：ldt(dt) 是这个角色自己的时间（被顿帧冻住时为 0，大招全屏停顿时也为 0），逻辑和动画都用它。

signal died(a: Actor)

const BLEED_MAX := 5
const BLEED_TICK := 1.0
const BLEED_DPS := 3.0         # 每层每秒

var team := 0                  # 0 主角一边，1 敌人
var max_hp := 100.0
var hp := 100.0
var alive := true
var rig: VoxActor
var radius := 0.45
var freeze_t := 0.0            # 顿帧剩余时间
var knock := Vector3.ZERO      # 击退速度（逐渐衰减）
var iframes := 0.0             # 无敌剩余时间
var bleed := 0                 # 出血层数
var bleed_t := 0.0             # 出血剩余时间（每次叠层刷新）
var _bleed_acc := 0.0
var bleed_mult := 1.0          # 出血伤害倍率（施加者的“溃血”等加成）
var hit_stun := 0.0
var facing := Vector3(0, 0, 1)   # 地面上面朝的方向
var display_name := ""
var world: Node3D


static var interp := true        # 物理插值总开关（--nointerp 关掉对照）
var _ip_last := Vector3.ZERO


func _ready() -> void:
	collision_layer = 2 if team == 0 else 4
	collision_mask = 1
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON if interp else Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ip_last = global_position


## 瞬移（传送、换房、闪现）别被插值拉出一道滑行：一帧挪了 2.5 米以上就把插值起点重置到现在
func _process(_dt: float) -> void:
	var gp := global_position
	if gp.distance_squared_to(_ip_last) > 6.25:
		reset_physics_interpolation()
	_ip_last = gp


## 画面上的位置（插值后），名牌、箭头、镜头跟这个
func vis_pos() -> Vector3:
	if is_physics_interpolated_and_enabled() and not Engine.is_in_physics_frame():
		return get_global_transform_interpolated().origin
	return global_position


## 这个角色本帧的时间：被顿帧冻住、或者全屏停顿时为 0
func ldt(dt: float) -> float:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return 0.0
	if freeze_t > 0.0:
		return 0.0
	return dt


## 挨打顿帧时整个人偶左右打颤（只动 x/z，y 留给跳跃）：定住的那几帧不再是“卡住”，而是“被砍得一哆嗦”
var _shiver := 0.0
var _shiver_amp := 0.0


func shiver(t: float, amp: float = 0.06) -> void:
	_shiver = maxf(_shiver, t)
	_shiver_amp = maxf(_shiver_amp if _shiver > 0.0 else 0.0, amp)


func _tick_shiver(dt: float) -> void:
	if rig == null:
		return
	if _shiver > 0.0:
		_shiver -= dt
		var k := clampf(_shiver / 0.08, 0.0, 1.0)
		var ph := Time.get_ticks_msec() * 0.09
		rig.position.x = sin(ph * 7.0) * _shiver_amp * k
		rig.position.z = cos(ph * 5.3) * _shiver_amp * 0.6 * k
	elif rig.position.x != 0.0 or rig.position.z != 0.0:
		rig.position.x = 0.0
		rig.position.z = 0.0
		_shiver_amp = 0.0


func tick_common(dt: float) -> float:
	if rig != null:
		rig.tick_flash(dt)
		if team == 1:
			rig.set_bleed(bleed if alive else 0, BLEED_MAX)
	_tick_shiver(dt)
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return 0.0
	if freeze_t > 0.0:
		freeze_t -= dt
		return 0.0
	iframes = maxf(iframes - dt, 0.0)
	hit_stun = maxf(hit_stun - dt, 0.0)
	if bleed > 0:
		bleed_t -= dt
		_bleed_acc += dt
		if _bleed_acc >= BLEED_TICK:
			_bleed_acc -= BLEED_TICK
			var d := BLEED_DPS * bleed * bleed_mult
			if alive:
				hp -= d
				if Feel.I != null:
					Feel.I.number(chest(), "%d" % int(d), Color(0.9, 0.15, 0.2), 0.75)
				if Vfx.I != null:
					Vfx.I.bleed_drip(chest())
				if hp <= 0.0:
					hp = 0.0
					die(Vector3.UP)
		if bleed_t <= 0.0:
			bleed = 0
	return dt


func add_bleed(n: int, mult: float = 1.0) -> void:
	if not alive or n <= 0:
		return
	bleed_mult = maxf(bleed_mult, mult)
	bleed = mini(bleed + n, BLEED_MAX)
	bleed_t = 5.0


func freeze(t: float) -> void:
	freeze_t = maxf(freeze_t, t)


## 打中别人时自己的顿帧（主角一刀只顿一次，见 Hero.self_stop）
func self_stop(t: float) -> void:
	freeze(t)


## 胸口位置（火花、伤害数字从这里冒）
func chest() -> Vector3:
	var h := 1.0
	if rig != null:
		h = rig.height * VoxActor.PX * rig.scale_k * 0.62
	return vis_pos() + Vector3(0, h, 0)


func head_top() -> Vector3:
	var h := 1.9
	if rig != null:
		h = rig.height * VoxActor.PX * rig.scale_k + 0.25
	return global_position + Vector3(0, h, 0)


func face_to(dir: Vector3) -> void:
	dir.y = 0
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()
		rotation.y = atan2(-facing.x, -facing.z)


## 受到攻击；返回 true 表示真的打中了（无敌帧、已死返回 false）
func take_hit(info: HitInfo) -> bool:
	if not alive or iframes > 0.0:
		return false
	hp -= info.damage
	if rig != null:
		rig.flash(Feel.FLASH_T)
	if info.bleed > 0:
		add_bleed(info.bleed, info.bleed_mult)
	var kd := info.dir
	kd.y = 0
	knock = kd.normalized() * info.knock
	if hp <= 0.0:
		hp = 0.0
		die(kd.normalized() * (3.0 + info.knock * 0.4))
	return true


func die(_impulse: Vector3) -> void:
	alive = false
	died.emit(self)


## 击退和移动：把 velocity 加上击退后 move_and_slide
func move_with_knock(v: Vector3, dt: float) -> void:
	if dt <= 0.0:
		velocity = Vector3.ZERO
		return
	velocity = v + knock
	velocity.y = 0
	knock = knock.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * dt))
	move_and_slide()
	global_position.y = 0.0
