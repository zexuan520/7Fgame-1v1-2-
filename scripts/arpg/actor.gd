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


func _ready() -> void:
	collision_layer = 2 if team == 0 else 4
	collision_mask = 1


## 这个角色本帧的时间：被顿帧冻住、或者全屏停顿时为 0
func ldt(dt: float) -> float:
	if Feel.I != null and Feel.I.world_pause > 0.0:
		return 0.0
	if freeze_t > 0.0:
		return 0.0
	return dt


func tick_common(dt: float) -> float:
	if rig != null:
		rig.tick_flash(dt)
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


## 胸口位置（火花、伤害数字从这里冒）
func chest() -> Vector3:
	var h := 1.0
	if rig != null:
		h = rig.height * VoxActor.PX * rig.scale_k * 0.62
	return global_position + Vector3(0, h, 0)


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
		rig.flash(0.1)
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
