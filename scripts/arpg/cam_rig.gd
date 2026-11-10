class_name CamRig
extends Node3D
## 斜俯视跟随镜头：俯角 pitch、离主角 distance，平滑跟随；攻击和大招时拉近再弹回；
## 震屏分轻/中/重三档（0.05 / 0.15 / 0.3 米起步），可以叠加，随时调用 shake(level)。

static var I: CamRig

@export var pitch_deg := 50.0          # 俯角：40~55，越大越像俯视
@export var yaw_deg := 0.0
@export var distance := 11.0
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
## 自动远近（2026-11-10 审视 C1）：平时离主角 NEAR 米，身边敌人多或者头目在场时慢慢拉到 FAR 米。
## 原来固定 14.5 米，主角在 720p 下只有约 85 像素高，一格体素不到一个像素，自制模型的细节全看不见。
const BASE_DIST := 14.5                # 房间边界（bounds）是按这个距离留的边
const NEAR := 11.0
const FAR := 13.2
const CROWD_R := 12.0                  # 主角多少米内的敌人算“身边”
var auto_dist := true
var _crowd := 0.0                      # 0 = 拉近，1 = 拉远（平滑过的）
var _crowd_want := 0.0
var _crowd_t := 0.0


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
	if auto_dist:
		# 换房间：先按拉近算，敌人刷出来以后再按人数拉远
		_crowd = 0.0
		_crowd_want = 0.0
		_crowd_t = 0.0
		distance = NEAR
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
	if auto_dist:
		_tick_auto_dist(dt)
	if is_instance_valid(target) or shooting:
		var goal := (_shot.global_position if shooting else _target_pos() + lead_dir * lead)
		# 镜头近了，看得见的范围小了，焦点可以更贴墙（不然主角走到墙边会跑到画面边上）
		var g := maxf(BASE_DIST - distance, 0.0)
		var b := bounds.grow_individual(g * 0.7, g * 0.15, g * 0.7, g * 0.3)
		goal.x = clampf(goal.x, b.position.x, b.end.x)
		goal.z = clampf(goal.z, b.position.y, b.end.y)
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


## 跟随点：角色走物理插值（逻辑 60 帧、画面按屏幕刷新率），跟插值后的位置，高刷屏上镜头和人不互相抖
func _target_pos() -> Vector3:
	if target is Actor:
		return (target as Actor).vis_pos()
	return target.global_position


## 数主角身边的敌人：少于 3 个拉近，9 个以上拉到最远；头目在场至少拉到七成。每 0.25 秒数一次，距离慢慢跟过去
func _tick_auto_dist(dt: float) -> void:
	_crowd_t -= dt
	if _crowd_t <= 0.0:
		_crowd_t = 0.25
		var n := 0
		var boss := false
		var c := target.global_position if is_instance_valid(target) else _focus
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Actor
			if a == null or not a.alive:
				continue
			if a is Foe and (a as Foe).is_boss:
				boss = true
			elif a.global_position.distance_squared_to(c) < CROWD_R * CROWD_R:
				n += 1
		_crowd_want = clampf((n - 3) / 6.0, 0.0, 1.0)
		if boss:
			_crowd_want = maxf(_crowd_want, 0.7)
	# 拉远快一点（敌人涌上来要马上看得见），拉近慢一点（不忽远忽近）
	var rate := 1.6 if _crowd_want > _crowd else 0.5
	_crowd = move_toward(_crowd, _crowd_want, rate * dt / maxf(Engine.time_scale, 0.3))
	var k := _crowd * _crowd * (3.0 - 2.0 * _crowd)
	distance = lerpf(NEAR, FAR, k)


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
