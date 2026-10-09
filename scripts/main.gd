extends Node2D
## 战斗原型主场景：搭建场地、生成角色、管理特效、顿帧和镜头震动。
## 游戏画面画在 640×360 的低分辨率画布上再放大，得到清晰的像素颗粒；界面文字画在画布外，保持清晰。

const ARENA_W := 640.0
const FLOOR_Y := 300.0
const P1_SPAWN := Vector2(200, FLOOR_Y)
const P2_SPAWN := Vector2(150, FLOOR_Y)
const ENEMY_SPAWN := Vector2(440, FLOOR_Y)

var players: Array[Player] = []
var enemies: Array[Enemy] = []
var camera: Camera2D
var world: Node2D
var fx_root: Node2D
var hud: Hud

var _shake := 0.0
var _hitstop_until := 0


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(ARENA_W, 360)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(ARENA_W), 360)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	container.add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)

	var bg := Background.new()
	bg.floor_y = FLOOR_Y
	world.add_child(bg)
	_build_arena()
	fx_root = Node2D.new()
	fx_root.z_index = 10
	world.add_child(fx_root)

	camera = Camera2D.new()
	camera.position = Vector2(ARENA_W / 2.0, 180)
	world.add_child(camera)

	_spawn_player(1)
	var e := Enemy.new()
	e.main = self
	e.position = ENEMY_SPAWN
	world.add_child(e)
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
	world.add_child(ground)
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
	world.add_child(p)
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


## 刀光。from/to 为朝右时的角度（0 向右，正数向下）
func spawn_slash(pos: Vector2, facing: int, radius: float, from_angle: float, to_angle: float,
		color: Color = Color(1, 1, 1), thickness: float = 7.0) -> void:
	var s := Fx.Slash.new()
	s.position = pos
	s.facing = facing
	s.radius = radius
	s.from_angle = from_angle
	s.to_angle = to_angle
	s.color = color
	s.thickness = thickness
	fx_root.add_child(s)


func spawn_streak(pos: Vector2, facing: int, length: float, color: Color = Color(1, 1, 1)) -> void:
	var s := Fx.Streak.new()
	s.position = pos
	s.facing = facing
	s.length = length
	s.color = color
	fx_root.add_child(s)


func spawn_ghost(pos: Vector2, pose: Dictionary, look: Puppet.Look, facing: int, color: Color) -> void:
	var g := Fx.Ghost.new()
	g.position = pos
	g.pose = pose
	g.look = look
	g.facing = facing
	g.color = color
	fx_root.add_child(g)


func spawn_dust(pos: Vector2, dir: float = 0.0, count: int = 5) -> void:
	var d := Fx.Particles.new()
	d.position = pos
	d.color = Color(0.62, 0.58, 0.55)
	d.count = count
	d.dir = dir
	d.speed = Vector2(36, 24)
	d.gravity = 40.0
	d.life = 0.35
	fx_root.add_child(d)


func spawn_blood(pos: Vector2, dir: float, count: int = 8) -> void:
	var b := Fx.Particles.new()
	b.position = pos
	b.color = Color(0.75, 0.08, 0.1)
	b.count = count
	b.dir = dir
	b.speed = Vector2(90, 70)
	b.gravity = 260.0
	b.life = 0.45
	fx_root.add_child(b)


func spawn_ring(pos: Vector2, color: Color, radius: float = 26.0) -> void:
	var r := Fx.Ring.new()
	r.position = pos
	r.color = color
	r.max_radius = radius
	fx_root.add_child(r)


func flash_screen(color: Color, life: float = 0.25) -> void:
	var f := Fx.ScreenFlash.new()
	f.color = color
	f.life = life
	fx_root.add_child(f)


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
