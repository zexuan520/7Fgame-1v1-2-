class_name CamRig
extends Node3D
## 斜俯视跟随镜头：俯角 pitch、离主角 distance，平滑跟随；攻击和大招时拉近再弹回；
## 震屏分轻/中/重三档（0.05 / 0.15 / 0.3 米起步），可以叠加，随时调用 shake(level)。

static var I: CamRig

@export var pitch_deg := 50.0          # 俯角：40~55，越大越像俯视
@export var yaw_deg := 0.0
@export var distance := 14.5
@export var fov := 38.0
@export var follow_speed := 7.0
@export var look_offset := Vector3(0, 0.9, 0.0)
@export var lead := 1.2                 # 往主角面朝的方向多看一点
const SHAKE_AMP := [0.05, 0.15, 0.3]
## 设置里的震屏强度（Game.settings.shake 0~3）：关 / 弱 / 中 / 强，乘到震屏和定向冲击上
const SHAKE_NAMES := ["关", "弱", "中", "强"]
const SHAKE_SCALES := [0.0, 0.5, 1.0, 1.5]

var cam: Camera3D
var target: Node3D
var _focus := Vector3.ZERO
var _trauma := 0.0                     # 当前震屏幅度（米），叠加后慢慢衰减
var _zoom := 0.0                       # 拉近量 0~1（距离 × (1 - 0.25×zoom)）
var _zoom_target := 0.0
var _zoom_hold := 0.0
var _t := 0.0
var bounds := Rect2(-100, -100, 200, 200)   # 镜头焦点能去的范围（xz）
var lead_dir := Vector3.ZERO
var _kick := Vector3.ZERO              # 定向冲击：镜头顺着打击方向猛推一下再弹簧回位
var _kick_v := Vector3.ZERO
var _roll := 0.0                       # 镜头滚转（重击时歪一下）
var _roll_v := 0.0
var _shot: Node3D                      # 特写：镜头暂时对准它（头目登场、变身、倒下）
var _shot_left := 0.0                  # 特写剩余时间（真实秒，不受慢镜头影响）
var _shot_zoom := 0.0


func _ready() -> void:
	I = self
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.5
	cam.far = 120.0
	add_child(cam)
	cam.current = true


func snap() -> void:
	if is_instance_valid(target):
		_focus = target.global_position
	_place(0.0)


static func shake_level() -> int:
	return clampi(int(Game.settings.get("shake", 2)), 0, SHAKE_SCALES.size() - 1)


static func shake_scale() -> float:
	return SHAKE_SCALES[shake_level()]


## 震屏：level 0 轻 / 1 中 / 2 重；scale 再按伤害调
func shake(level: int, scale: float = 1.0) -> void:
	var a: float = SHAKE_AMP[clampi(level, 0, 2)] * scale * shake_scale()
	_trauma = minf(_trauma + a, 0.6 * maxf(shake_scale(), 0.01))


## 定向冲击：镜头沿 dir（地面方向）被推 amt 米，带一点回弹；roll 是顺带歪的角度（弧度）
func kick(dir: Vector3, amt: float, roll: float = 0.0) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	var ss := minf(shake_scale(), 1.2)
	_kick_v += dir.normalized() * amt * 28.0 * ss
	_roll_v += roll * 28.0 * ss * (1.0 if randf() < 0.5 else -1.0)


## 拉近：amount 0~1，hold 秒后弹回
func punch_zoom(amount: float, hold: float = 0.12) -> void:
	_zoom_target = maxf(_zoom_target, amount)
	_zoom_hold = maxf(_zoom_hold, hold)


## 特写：镜头对准 node 拉近 zoom（0~1），持续 dur 真实秒，之后回到主角
func close_up(node: Node3D, dur: float, zoom: float = 0.6) -> void:
	_shot = node
	_shot_left = dur
	_shot_zoom = zoom


func _process(dt: float) -> void:
	_t += dt
	_shot_left = maxf(_shot_left - dt / maxf(Engine.time_scale, 0.01), 0.0)
	var shooting := _shot_left > 0.0 and is_instance_valid(_shot)
	if shooting:
		punch_zoom(_shot_zoom, 0.05)
	if is_instance_valid(target) or shooting:
		var goal := (_shot.global_position if shooting else target.global_position + lead_dir * lead)
		goal.x = clampf(goal.x, bounds.position.x, bounds.end.x)
		goal.z = clampf(goal.z, bounds.position.y, bounds.end.y)
		_focus = _focus.lerp(goal, 1.0 - exp(-(follow_speed * (0.6 if shooting else 1.0)) * dt / maxf(Engine.time_scale, 0.3)))
	if _zoom_hold > 0.0:
		_zoom_hold -= dt
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-30.0 * dt))
	else:
		_zoom_target = 0.0
		_zoom = lerpf(_zoom, 0.0, 1.0 - exp(-6.0 * dt))
	_trauma = maxf(_trauma - dt * 1.6 * maxf(_trauma, 0.08) * 6.0, 0.0)
	# 弹簧：刚度 260、阻尼 22（略欠阻尼，回弹一下就停）
	var sdt := minf(dt, 0.05)
	_kick_v += (-_kick * 260.0 - _kick_v * 22.0) * sdt
	_kick += _kick_v * sdt
	_roll_v += (-_roll * 260.0 - _roll_v * 22.0) * sdt
	_roll += _roll_v * sdt
	_place(dt)


func _place(_dt: float) -> void:
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var d := distance * (1.0 - 0.22 * _zoom)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	var look := _focus + look_offset
	var pos := look + back * cos(pitch) * d + Vector3.UP * sin(pitch) * d
	var shake := Vector3.ZERO
	if _trauma > 0.001:
		var a := _trauma
		shake = Vector3(sin(_t * 71.0) + sin(_t * 37.0) * 0.5, cos(_t * 63.0) + sin(_t * 29.0) * 0.5, sin(_t * 53.0)) * a * 0.66
	global_position = pos
	cam.global_position = pos + shake + _kick
	cam.look_at(look + shake * 0.5 + _kick * 0.6, Vector3.UP)
	if absf(_roll) > 0.0001:
		cam.rotate_object_local(Vector3.BACK, _roll)
	cam.fov = fov * (1.0 - 0.06 * _zoom)


## 屏幕上的“上/右”在地面上的方向（八方向移动按镜头方向算）
func ground_axes() -> Array:
	var yaw := deg_to_rad(yaw_deg)
	var up := -Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return [up, right]
