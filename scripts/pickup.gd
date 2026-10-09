class_name Pickup
extends Node2D
## 敌人死后崩出来的铜钱、魂玉：先弹几下落在地上，过一会儿自己飞向最近的玩家。

var kind := "coin"          # coin / jade
var amount := 1
var main: Node
var velocity := Vector2.ZERO
var floor_y := 300.0
var _t := 0.0
var _done := false

const HOME_DELAY := 0.7
const HOME_SPEED := 520.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _done:
		return
	var target: Player = main.nearest_player(global_position) if _t > HOME_DELAY else null
	if target != null:
		var to := target.global_position + Vector2(0, -26) - global_position
		if to.length() < 10.0:
			_done = true
			main.collect(kind, amount, target)
			queue_free()
			return
		velocity = velocity.lerp(to.normalized() * HOME_SPEED * minf(1.0, (_t - HOME_DELAY) * 2.5 + 0.3), 1.0 - exp(-10.0 * delta))
	else:
		velocity.y += 900.0 * delta
		if position.y >= floor_y - 2.0 and velocity.y > 0.0:
			position.y = floor_y - 2.0
			velocity.y *= -0.45
			velocity.x *= 0.6
	position += velocity * delta
	queue_redraw()


func _draw() -> void:
	if kind == "jade":
		for i in range(3):
			draw_circle(Vector2.ZERO, 3.0 + i * 2.5, Color(0.3, 0.9, 0.65, 0.08))
	var spin := absf(cos(_t * 8.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(spin, 0.3), 1.0))
	Icons.draw(self, kind, Vector2.ZERO, Color(1, 1, 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
