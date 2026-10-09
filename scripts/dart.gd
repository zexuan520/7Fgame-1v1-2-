class_name Dart
extends Node2D
## 副武器飞镖：往前飞，打中一个敌人就没了。打中空中的敌人（跳起来、扑过来的）会把它打下来，踉跄一下。

const SIZE := Vector2(12, 12)
const LIFE := 0.9

var main: Node
var owner_player: Player
var facing := 1
var info: Dictionary = {}
var _life := LIFE


func _physics_process(delta: float) -> void:
	global_position.x += facing * float(info.get("speed", 520.0)) * delta
	_life -= delta
	if _life <= 0.0 or global_position.x < -40.0 or global_position.x > float(main.arena_w) + 40.0:
		queue_free()
		return
	var r := Rect2(global_position - SIZE / 2.0, SIZE)
	for e: Enemy in main.get_enemies():
		if not e.is_hittable() or not r.intersects(e.body_rect()):
			continue
		var airborne := not e.is_on_floor()
		var result := e.receive_player_hit({"dmg": info["dmg"], "posture": info["posture"], "heavy": false, "id": "dart"}, owner_player)
		if result == "none":
			continue
		main.spawn_spark(global_position, Color(0.85, 0.88, 0.95), 6)
		if airborne:
			# 打下来
			e.velocity = Vector2(-facing * 60.0, 320.0)
			e._stagger(0.9)
			main.spawn_text(e.global_position + Vector2(0, -e.body_size.y - 26.0), "击落", Color(0.85, 0.9, 1.0), 12)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := (LIFE - _life) * 30.0
	var pts := PackedVector2Array()
	for k in range(8):
		var r := 5.0 if k % 2 == 0 else 1.6
		pts.append(Vector2(cos(a + k * PI / 4.0), sin(a + k * PI / 4.0)) * r)
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.06))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.72)
	draw_colored_polygon(inner, Color(0.85, 0.88, 0.95))
	draw_line(Vector2(-facing * 4.0, 0), Vector2(-facing * 14.0, 0), Color(1, 1, 1, 0.3), 1.0)
