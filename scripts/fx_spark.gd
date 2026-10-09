class_name FxSpark
extends Node2D
## 火花特效：从中心向外迸射的短线

var color := Color.WHITE
var count := 8
var life := 0.2
var _t := 0.0
var _dirs: Array[Vector2] = []


func _ready() -> void:
	for i in range(count):
		var ang := randf() * TAU
		_dirs.append(Vector2(cos(ang), sin(ang)) * randf_range(0.6, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var c := Color(color, 1.0 - k)
	for d in _dirs:
		draw_line(d * (4.0 + 26.0 * k), d * (10.0 + 34.0 * k), c, 2.0)
