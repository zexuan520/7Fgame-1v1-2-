class_name FogDrift
extends Node
## 雾片慢慢横着飘，飘出范围从另一边回来。

var speed := 0.2
var span := 18.0


func _process(dt: float) -> void:
	var p := get_parent() as Node3D
	if p == null:
		return
	p.position.x += speed * dt
	if p.position.x > span:
		p.position.x = -span
	elif p.position.x < -span:
		p.position.x = span
