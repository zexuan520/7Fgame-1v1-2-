class_name FxText
extends Node2D
## 飘字特效：弹反、看破、处决等

var text := ""
var color := Color.WHITE
var size := 14
var life := 0.8
var _t := 0.0
var pop := false            # 伤害数字：一出来放大再缩回去，往斜上方弹
var vel := Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if pop:
		position += vel * delta
		vel.y += 260.0 * delta
	else:
		position.y -= 26.0 * delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(1.0 - (_t / life) * (_t / life), 0.0, 1.0)
	var w := Game.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w / 2.0, 0)
	if pop:
		var sc := 1.0 + 0.8 * clampf(1.0 - _t / 0.12, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	draw_string_outline(Game.font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, a))
	draw_string(Game.font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, a))
