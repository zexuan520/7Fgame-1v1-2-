class_name BladeWave
extends Node2D
## 空刃斩挥出的刃气：往前飞，打中敌人；打中正在出招前摇的敌人会打断它。
## info 是招式数值（Arts.art("kuujin", 等级)）：dmg、posture、speed、life、pierce。

const SIZE := Vector2(26, 34)

var main: Node
var owner_player: Player
var facing := 1
var info: Dictionary = {}
var _life := 0.85
var _hit: Array = []
var _t := 0.0


func _ready() -> void:
	_life = float(info.get("life", 0.85))


func _physics_process(delta: float) -> void:
	_t += delta
	global_position.x += facing * float(info.get("speed", 430.0)) * delta
	_life -= delta
	if _life <= 0.0 or global_position.x < -40.0 or global_position.x > float(main.arena_w) + 40.0:
		queue_free()
		return
	var r := Rect2(global_position - SIZE / 2.0, SIZE)
	for e: Enemy in main.get_enemies():
		if e in _hit or not e.is_hittable() or not r.intersects(e.body_rect()):
			continue
		_hit.append(e)
		var winding := e.state == Enemy.S.WINDUP
		var result := e.receive_player_hit(info, owner_player)
		if result == "none":
			continue
		main.spawn_spark(global_position, Color(0.7, 0.9, 1.0), 8)
		if winding and result != "blocked":
			# 打断：前摇被打掉，踉跄一下
			e._stagger(0.5)
			main.spawn_text(e.global_position + Vector2(0, -e.body_size.y - 30.0), "打断", Color(0.7, 0.9, 1.0), 12)
		if not bool(info.get("pierce", false)):
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	# 一道竖着的月牙，后面拖两道淡影
	var a := clampf(_life / 0.2, 0.0, 1.0)
	for k in range(3):
		var off := Vector2(-facing * k * 7.0, 0)
		var col := Color(0.75, 0.92, 1.0, a * (0.9 - k * 0.3))
		var pts := PackedVector2Array()
		for i in range(9):
			var ang := lerpf(-1.2, 1.2, i / 8.0)
			pts.append(off + Vector2(facing * cos(ang) * 8.0, sin(ang) * 16.0))
		draw_polyline(pts, col, 3.0 - k)
	draw_line(Vector2(facing * 6.0, -12), Vector2(facing * 8.0, 0), Color(1, 1, 1, a), 1.0)
