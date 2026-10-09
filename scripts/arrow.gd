class_name Arrow
extends Node2D
## 弓手射出的箭：可以格挡；弹反会把箭打回去，反过来射中敌人。

const LIFE := 3.0

var main: Node
var velocity := Vector2.ZERO
var facing := 1
var dmg := 16.0
var posture := 22.0
var deflected_by: Player = null     # 被谁弹回去的（弹回之后只打敌人）
var star := false                   # 忍者的手里剑：画成转着的四角星
var _life := LIFE
var _trail: Array[Vector2] = []


func _physics_process(delta: float) -> void:
	_trail.push_front(global_position)
	if _trail.size() > 5:
		_trail.pop_back()
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0 or global_position.y > Fighter.GROUND_Y + 2.0 or global_position.x < -60.0 or global_position.x > float(main.arena_w) + 60.0:
		queue_free()
		return
	if deflected_by == null:
		_check_players()
	else:
		_check_enemies()
	queue_redraw()


func _check_players() -> void:
	for p: Player in main.get_players():
		if not p.is_alive() or not p.body_rect().grow(2.0).has_point(global_position):
			continue
		var info := {"kind": "slash", "unblockable": false, "dmg": dmg, "posture": posture}
		match p.receive_enemy_hit(info, self):
			"parry":
				# 弹反：箭掉头飞回去
				deflected_by = p
				velocity = -velocity * 1.3
				facing = -facing
				_life = LIFE
				main.spawn_spark(global_position, Color(1.0, 0.9, 0.4), 12)
				main.spawn_ring(global_position, Color(1.0, 0.95, 0.6), 20.0)
				main.spawn_text(global_position + Vector2(0, -20), "弹反", Color(1.0, 0.9, 0.4))
				main.hitstop(0.05)
				main.shake(2.0)
			"block":
				main.spawn_spark(global_position, Color(0.7, 0.8, 1.0), 6)
				queue_free()
			"hit":
				main.spawn_spark(global_position, Color(0.9, 0.15, 0.15), 6)
				queue_free()
		return


func _check_enemies() -> void:
	for e: Enemy in main.get_enemies():
		if not e.is_hittable() or not e.body_rect().has_point(global_position):
			continue
		var result := e.receive_player_hit({"dmg": 25.0, "posture": 30.0, "heavy": false}, deflected_by)
		if result != "none":
			deflected_by.gain_will("hit")
			queue_free()
			return


func _draw() -> void:
	if star:
		_draw_star()
		return
	var back := deflected_by != null
	var shaft := Color("c9b08a") if not back else Color(1.0, 0.85, 0.4)
	for i in range(_trail.size()):
		var a := 0.35 * (1.0 - float(i) / _trail.size())
		var p := _trail[i] - global_position
		draw_line(p, p - velocity.normalized() * 6.0, Color(1, 1, 1, a) if not back else Color(1.0, 0.85, 0.4, a), 1.0)
	var d := velocity.normalized() if velocity.length() > 1.0 else Vector2(facing, 0)
	draw_line(-d * 13.0, Vector2.ZERO, Color(0.05, 0.03, 0.03), 3.0)
	draw_line(-d * 12.0, Vector2.ZERO, shaft, 1.0)
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([d * 3.0, n * -1.5, n * 1.5]), Color(0.85, 0.88, 0.95))
	# 箭羽
	draw_line(-d * 12.0, -d * 15.0 - n * 2.0, Color(0.9, 0.9, 0.85), 1.0)
	draw_line(-d * 12.0, -d * 15.0 + n * 2.0, Color(0.9, 0.9, 0.85), 1.0)


func _draw_star() -> void:
	var a := (LIFE - _life) * 22.0
	var col := Color(0.75, 0.78, 0.85) if deflected_by == null else Color(1.0, 0.85, 0.4)
	for i in range(_trail.size()):
		var p := _trail[i] - global_position
		draw_circle(p, 2.0, Color(col, 0.25 * (1.0 - float(i) / _trail.size())))
	var pts := PackedVector2Array()
	for k in range(8):
		var r := 6.0 if k % 2 == 0 else 2.0
		pts.append(Vector2(cos(a + k * PI / 4.0), sin(a + k * PI / 4.0)) * r)
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.06))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.75)
	draw_colored_polygon(inner, col)
	draw_circle(Vector2.ZERO, 1.0, Color(0.1, 0.1, 0.12))

