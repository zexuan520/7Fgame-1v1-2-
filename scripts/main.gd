extends Node2D
## 战斗原型主场景：搭建场地、生成角色、管理特效、顿帧和镜头震动。

const ARENA_W := 640.0
const FLOOR_Y := 300.0
const P1_SPAWN := Vector2(200, FLOOR_Y)
const P2_SPAWN := Vector2(150, FLOOR_Y)
const ENEMY_SPAWN := Vector2(440, FLOOR_Y)

var players: Array[Player] = []
var enemies: Array[Enemy] = []
var camera: Camera2D
var fx_root: Node2D
var hud: Hud

var _shake := 0.0
var _hitstop_until := 0


func _ready() -> void:
	_build_arena()
	fx_root = Node2D.new()
	fx_root.z_index = 10
	add_child(fx_root)

	camera = Camera2D.new()
	camera.position = Vector2(ARENA_W / 2.0, 180)
	add_child(camera)

	_spawn_player(1)
	var e := Enemy.new()
	e.main = self
	e.position = ENEMY_SPAWN
	add_child(e)
	enemies.append(e)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)


func _build_arena() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	_add_box(ground, Rect2(-100, FLOOR_Y, ARENA_W + 200, 100))   # 地面
	_add_box(ground, Rect2(-40, -200, 40, 600))                  # 左墙
	_add_box(ground, Rect2(ARENA_W, -200, 40, 600))              # 右墙


func _add_box(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	body.add_child(shape)


func _spawn_player(index: int) -> Player:
	var p := Player.new()
	p.main = self
	p.index = index
	p.prefix = "p%d_" % index
	if index == 1:
		p.position = P1_SPAWN
		p.color = Color(0.35, 0.75, 0.95)
	else:
		p.position = P2_SPAWN
		p.color = Color(0.5, 0.9, 0.45)
	add_child(p)
	players.append(p)
	_update_coop()
	return p


func _remove_player(index: int) -> void:
	for p in players:
		if p.index == index:
			players.erase(p)
			p.queue_free()
			break
	_update_coop()


func _update_coop() -> void:
	for e in enemies:
		e.set_coop(players.size() >= 2)


func has_player(index: int) -> bool:
	for p in players:
		if p.index == index:
			return true
	return false


# ---------- 给角色用的查询 ----------

func get_players() -> Array[Player]:
	return players


func get_enemies() -> Array[Enemy]:
	return enemies


func nearest_player(from: Vector2) -> Player:
	var best: Player = null
	var best_d := INF
	for p in players:
		if not p.is_alive():
			continue
		var d := absf(p.global_position.x - from.x)
		if d < best_d:
			best_d = d
			best = p
	return best


## 玩家身边有架势崩溃的敌人时返回它（按攻击即可处决）
func find_executable(p: Player) -> Enemy:
	for e in enemies:
		if e.state == Enemy.S.BROKEN \
				and absf(e.global_position.x - p.global_position.x) < Player.EXECUTE_RANGE \
				and absf(e.global_position.y - p.global_position.y) < 40.0:
			return e
	return null


# ---------- 特效 ----------

func spawn_text(pos: Vector2, text: String, color: Color, size: int = 14) -> void:
	var t := FxText.new()
	t.text = text
	t.color = color
	t.size = size
	t.position = pos
	fx_root.add_child(t)


func spawn_spark(pos: Vector2, color: Color, count: int = 8) -> void:
	var s := FxSpark.new()
	s.color = color
	s.count = count
	s.position = pos
	fx_root.add_child(s)


## 顿帧：短暂放慢时间，让弹反和处决有打击感
func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		_hitstop_until = 0
		Engine.time_scale = 1.0
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - 30.0 * delta / maxf(Engine.time_scale, 0.05))
	else:
		camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_p2"):
		if has_player(2):
			_remove_player(2)
		else:
			_spawn_player(2)
	elif event.is_action_pressed("p2_attack") and not has_player(2):
		_spawn_player(2)   # 2P 按攻击键直接加入
	elif event.is_action_pressed("toggle_easy"):
		Game.easy_mode = not Game.easy_mode
	elif event.is_action_pressed("toggle_hitbox"):
		Game.show_hitboxes = not Game.show_hitboxes
	elif event.is_action_pressed("toggle_help"):
		hud.show_help = not hud.show_help
	elif event.is_action_pressed("reset"):
		for e in enemies:
			e.reset()
		for p in players:
			p.respawn()
	elif event.is_action_pressed("quit"):
		get_tree().quit()


func _draw() -> void:
	# 背景：远山、地面
	draw_rect(Rect2(0, 0, ARENA_W, FLOOR_Y), Color(0.11, 0.1, 0.14))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 230), Vector2(90, 170), Vector2(170, 215), Vector2(280, 150),
		Vector2(400, 210), Vector2(500, 165), Vector2(640, 220), Vector2(640, FLOOR_Y), Vector2(0, FLOOR_Y),
	]), Color(0.16, 0.14, 0.2))
	draw_circle(Vector2(520, 70), 22.0, Color(0.85, 0.82, 0.7, 0.8))
	draw_rect(Rect2(0, FLOOR_Y, ARENA_W, 60), Color(0.22, 0.18, 0.15))
	draw_rect(Rect2(0, FLOOR_Y, ARENA_W, 2), Color(0.45, 0.38, 0.3))
