extends Node2D
## 战斗原型主场景：搭建场地、生成角色、管理特效、顿帧和镜头震动。
## 游戏画面画在 640×360 的低分辨率画布上再放大，得到清晰的像素颗粒；界面文字画在画布外，保持清晰。

const VIEW_W := 640.0
const VIEW_H := 360.0
const ARENA_W := 800.0                # 场地比画面宽，镜头跟着战斗移动
const FLOOR_Y := 300.0
const P1_SPAWN := Vector2(280, FLOOR_Y)
const P2_SPAWN := Vector2(220, FLOOR_Y)
const MAX_ATTACKERS := 2              # 设计文档：同时最多两个敌人进攻

var players: Array[Player] = []
var enemies: Array[Enemy] = []
var camera: Camera2D
var world: Node2D
var fx_root: Node2D
var hud: Hud
var background: Background
var post: ShaderMaterial
var encounter := 0
var _clear_timer := -1.0

var _shake := 0.0
var _punch := 0.0
var _flash := Color(0, 0, 0, 0)
var _hitstop_until := 0
var _slow_until := 0
var _slow_scale := 1.0


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(VIEW_W, VIEW_H)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = preload("res://shaders/post.gdshader")
	container.material = post
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(VIEW_W), int(VIEW_H))
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	container.add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)

	background = Background.new()
	background.floor_y = FLOOR_Y
	background.arena_w = ARENA_W
	world.add_child(background)
	_build_arena()
	fx_root = Node2D.new()
	fx_root.z_index = 10
	world.add_child(fx_root)
	for l in background.make_foreground():
		l.z_index = 20
		world.add_child(l)

	camera = Camera2D.new()
	camera.position = Vector2(P1_SPAWN.x + 120.0, VIEW_H / 2.0)
	world.add_child(camera)

	_spawn_player(1)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)
	start_encounter(0)
	hud.toast("数字键 1-5 换对手，H 查看操作说明")


# ---------- 遭遇 ----------

## 清掉场上的敌人，按 EnemyData.ENCOUNTERS 重新刷一批
func start_encounter(index: int) -> void:
	encounter = index
	_clear_timer = -1.0
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for a in fx_root.get_children():
		if a is Arrow:
			a.queue_free()
	var enc: Dictionary = EnemyData.ENCOUNTERS[index]
	for s: Array in enc["spawns"]:
		var e := spawn_enemy(s[0], Vector2(s[1], FLOOR_Y))
		if enc.get("intro", false):
			e.start_intro()
	hud.clear_lines()


func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.create(kind)
	e.main = self
	e.position = pos
	world.add_child(e)
	enemies.append(e)
	e.set_coop(players.size() >= 2)
	return e


## 同一时间最多两个敌人出招，其他的在外圈等
func can_attack(e: Enemy) -> bool:
	if e.is_attacking():
		return true
	var n := 0
	for o in enemies:
		if o != e and o.is_attacking():
			n += 1
	return n < MAX_ATTACKERS


func _check_cleared(delta: float) -> void:
	if enemies.is_empty():
		return
	if _clear_timer < 0.0:
		for e in enemies:
			if e.state != Enemy.S.DEAD:
				return
		_clear_timer = 3.0
		var enc: Dictionary = EnemyData.ENCOUNTERS[encounter]
		hud.toast(("击破 · " if enc.get("intro", false) else "全部击败 · ") + str(enc["name"]))
		return
	_clear_timer -= delta
	if _clear_timer <= 0.0:
		start_encounter(encounter)


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


## 离 from 最近、还能战斗的敌人（超出 max_dist 返回 null）
func nearest_enemy(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist
	for e in enemies:
		if not e.visible or e.state == Enemy.S.DEAD or e.state == Enemy.S.DYING:
			continue
		var d := absf(e.global_position.x - from.x)
		if d < best_d:
			best_d = d
			best = e
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


## 顿帧：短暂放慢时间，让弹反和处决有打击感
func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(seconds * 1000.0))


## 慢动作（处决时用），在顿帧之后生效
func slowmo(scale: float, seconds: float) -> void:
	_slow_scale = scale
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + int(seconds * 1000.0))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## 镜头往里推一下
func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


## 整个画面闪一下颜色（在后期里叠加）
func flash_screen(color: Color, strength: float = 0.35) -> void:
	_flash = Color(color, strength)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	if _hitstop_until > 0 and now >= _hitstop_until:
		_hitstop_until = 0
	if _slow_until > 0 and now >= _slow_until:
		_slow_until = 0
	if _hitstop_until > 0:
		Engine.time_scale = 0.05
	elif _slow_until > 0:
		Engine.time_scale = _slow_scale
	else:
		Engine.time_scale = 1.0

	_update_camera(real_dt)
	_check_cleared(real_dt)
	_flash.a = maxf(0.0, _flash.a - real_dt * 1.6)
	post.set_shader_parameter("flash", _flash)


func _update_camera(dt: float) -> void:
	# 跟随所有战斗中角色的中点，限制在场地内
	var sum := 0.0
	var n := 0
	for p in players:
		if p.is_alive():
			sum += p.global_position.x
			n += 1
	for e in enemies:
		if e.visible:
			sum += e.global_position.x
			n += 1
	var target := sum / n if n > 0 else ARENA_W / 2.0
	target = clampf(target, VIEW_W / 2.0, ARENA_W - VIEW_W / 2.0)
	camera.position.x = lerpf(camera.position.x, target, 1.0 - exp(-4.0 * dt))
	camera.position.x = roundf(camera.position.x)
	background.set_camera(camera.position.x - VIEW_W / 2.0)

	_punch = maxf(0.0, _punch - dt * 0.6)
	camera.zoom = Vector2.ONE * (1.0 + _punch)
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = maxf(0.0, _shake - 30.0 * dt)
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
		hud.toast("弹反窗口 %.2f 秒%s" % [Game.parry_window(), "（低难度）" if Game.easy_mode else ""])
	elif event.is_action_pressed("toggle_hitbox"):
		Game.show_hitboxes = not Game.show_hitboxes
	elif event.is_action_pressed("toggle_help"):
		hud.show_help = not hud.show_help
	elif event.is_action_pressed("reset"):
		start_encounter(encounter)
		for p in players:
			p.respawn()
	elif event.is_action_pressed("quit"):
		get_tree().quit()
	for i in range(EnemyData.ENCOUNTERS.size()):
		if event.is_action_pressed("encounter_%d" % (i + 1)):
			start_encounter(i)
			for p in players:
				p.respawn()
			hud.toast(str(EnemyData.ENCOUNTERS[i]["name"]))
