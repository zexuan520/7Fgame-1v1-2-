class_name Fighter
extends CharacterBody2D
## 玩家和敌人的公共部分：生命、架势、身体与攻击判定框。
## 坐标约定：节点原点在脚底中心，向上为 -y。

const GRAVITY := 980.0
const POSTURE_RECOVER_DELAY := 1.5   # 不受攻击 1.5 秒后架势开始回落

var max_hp := 200.0
var hp := 200.0
var max_posture := 100.0
var posture := 0.0
var posture_recover_rate := 30.0     # 满血时每秒回落量，生命越低回落越慢
var facing := 1                      # 1 朝右，-1 朝左
var body_size := Vector2(18, 34)
var state_time := 0.0
var flash_timer := 0.0
var flash_color := Color.WHITE
var main: Node                       # 主场景，用来放特效、找对手

var _posture_idle := 0.0


func setup_body() -> void:
	collision_layer = 2
	collision_mask = 1   # 只和地形碰撞，角色之间可以穿过
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2(0, -body_size.y / 2.0)
	add_child(shape)


func body_rect() -> Rect2:
	return Rect2(global_position - Vector2(body_size.x / 2.0, body_size.y), body_size)


## 身前的判定框。reach 为框中心离身体中心的水平距离，height 为框中心离脚底的高度。
func front_rect(reach: float, size: Vector2, height: float) -> Rect2:
	var center := global_position + Vector2(facing * reach, -height)
	return Rect2(center - size / 2.0, size)


func add_posture(amount: float) -> void:
	if amount <= 0.0:
		return
	posture = minf(posture + amount, max_posture)
	_posture_idle = 0.0
	if posture >= max_posture:
		_on_posture_full()


func _on_posture_full() -> void:
	pass


## 设计文档：架势回落/秒 = 基础回落 × 当前HP / 最大HP
func tick_posture(delta: float) -> void:
	_posture_idle += delta
	if _posture_idle >= POSTURE_RECOVER_DELAY and posture > 0.0:
		var hp_factor := clampf(hp / max_hp, 0.0, 1.0)
		posture = maxf(0.0, posture - posture_recover_rate * hp_factor * delta)


func flash(color: Color, time: float = 0.12) -> void:
	flash_color = color
	flash_timer = time


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)


## 把世界坐标矩形转成本地坐标（用于 _draw）
func to_local_rect(r: Rect2) -> Rect2:
	return Rect2(r.position - global_position, r.size)


## 画一条从中间向两边增长的架势条（只狼风格）
func draw_posture_bar(center: Vector2, width: float, ratio: float) -> void:
	draw_rect(Rect2(center.x - width / 2.0 - 1, center.y - 1, width + 2, 5), Color(0, 0, 0, 0.7))
	var w := width * clampf(ratio, 0.0, 1.0)
	var col := Color(1.0, 0.75, 0.2).lerp(Color(1.0, 0.25, 0.1), clampf((ratio - 0.5) * 2.0, 0.0, 1.0))
	draw_rect(Rect2(center.x - w / 2.0, center.y, w, 3), col)
	draw_rect(Rect2(center.x - 0.5, center.y - 1, 1, 5), Color(1, 1, 1, 0.6))
