class_name ArpgMain
extends Node3D
## 《残刃归途》斜俯视动作版的主场景：搭环境（卡通渲染、青绿雾、Bloom、后期）、镜头、特效、HUD，
## 按房间顺序推进：每个房间几波敌人，清完开出口光门，走进去换下一个房间；最后是夜樱广场的头目。
##
## 命令行（-- 后面）：--demo=fight 自动打一场（录视频用）  --zone=temple 直接进某个区域  --shot=路径 拍一张图后退出

const ROOMS := [
	{"zone": "forest", "name": "幽林遗迹 · 一", "waves": [["crawler", 6], ["skeleton", 3, "crawler", 4], ["samurai", 1, "mage", 2, "crawler", 3]]},
	{"zone": "forest", "name": "幽林遗迹 · 二", "waves": [["skeleton", 4, "mage", 2], ["crawler", 8], ["samurai", 2, "skeleton", 2]]},
	{"zone": "temple", "name": "古寺内殿", "waves": [["skeleton", 5], ["mage", 3, "crawler", 5], ["samurai", 2, "mage", 2]]},
	{"zone": "sakura", "name": "夜樱广场", "waves": [["boss", 1]]},
]

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var cam_rig: CamRig
var vfx: Vfx
var feel: Feel
var hud: Hud3D
var post_rect: ColorRect
var arena: Arena
var hero: Hero
var room_i := 0
var wave_i := -1
var _wave_delay := 0.0
var _portal: Node3D
var _state := "play"
var coins := 0
var jade := 0
var _args := {}
var _bot: ArpgBot
var _fade := 0.0
var _shots: Array[float] = []
var _clock := 0.0
var _shot_n := 0


func _ready() -> void:
	ArpgInput.setup()
	Foe.tokens = 0
	_parse_args()
	_setup_world()
	var start := 0
	if _args.has("zone"):
		for i in range(ROOMS.size()):
			if ROOMS[i]["zone"] == _args["zone"]:
				start = i
				break
	if _args.has("room"):
		start = int(_args["room"])
	_spawn_hero()
	_enter_room(start)
	if _args.has("demo"):
		_bot = ArpgBot.new()
		_bot.hero = hero
		_bot.mode = String(_args["demo"])
		add_child(_bot)
		hero.invincible = true
	if _args.has("cam_dist"):
		cam_rig.distance = float(_args["cam_dist"])
	if _args.has("cam_pitch"):
		cam_rig.pitch_deg = float(_args["cam_pitch"])
	if _args.has("cam_yaw"):
		cam_rig.yaw_deg = float(_args["cam_yaw"])
	if _args.has("shot"):
		for t: String in String(_args.get("shot_t", "3.0")).split(","):
			_shots.append(float(t))
	if not Game.loaded_reported:
		Game.loaded_reported = true
		get_tree().process_frame.connect(Zaohua.game_loaded, CONNECT_ONE_SHOT)


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _setup_world() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(-35), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_blur = 1.5
	add_child(sun)
	cam_rig = CamRig.new()
	add_child(cam_rig)
	vfx = Vfx.new()
	add_child(vfx)
	# 后期（盖在 3D 画面上）：调色、暗角、色差、闪屏
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/arpg/post3d.gdshader")
	post_rect.material = pm
	post_layer.add_child(post_rect)
	feel = Feel.new()
	add_child(feel)
	feel.post = pm
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 6
	add_child(hud_layer)
	hud = Hud3D.new()
	hud_layer.add_child(hud)


func _apply_zone_env(info: Dictionary) -> void:
	var env := world_env.environment
	env.background_color = info["bg"]
	env.ambient_light_color = info["amb"]
	env.ambient_light_energy = info["amb_e"]
	env.fog_light_color = info["fog"]
	env.fog_density = info["fog_d"]
	env.fog_sky_affect = 1.0
	env.fog_depth_begin = 15.0
	env.fog_depth_end = 34.0
	env.fog_depth_curve = 1.3
	sun.light_color = info["sun"]
	sun.light_energy = info["sun_e"]


func _spawn_hero() -> void:
	hero = Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.died.connect(_on_hero_died)
	cam_rig.target = hero
	hud.hero = hero


func _enter_room(i: int) -> void:
	room_i = i
	Foe.tokens = 0
	if arena != null:
		arena.queue_free()
	for n: Node in get_tree().get_nodes_in_group("foes"):
		n.queue_free()
	if is_instance_valid(_portal):
		_portal.queue_free()
	var room: Dictionary = ROOMS[i]
	arena = Arena.new()
	add_child(arena)
	var sz := Vector2(30, 22) if room["zone"] != "sakura" else Vector2(32, 24)
	arena.build(room["zone"], 1000 + i * 77, sz)
	_apply_zone_env(arena.zone_info())
	hero.global_position = arena.entry_pos
	hero.face_to(Vector3(0, 0, -1))
	cam_rig.bounds = Rect2(-sz.x * 0.5 + 6.0, -sz.y * 0.5 + 2.0, sz.x - 12.0, sz.y - 4.0)
	cam_rig.snap()
	wave_i = -1
	_wave_delay = 1.4
	hud.zone_name = room["name"]
	hud.wave_text = ""
	hud.banner(room["name"], "第 %d 间 / 共 %d 间" % [i + 1, ROOMS.size()], 2.4)
	_state = "play"
	feel.screen_flash(Color(0, 0, 0, 1), 1.6)
	Game.music("boss" if room["zone"] == "sakura" else ("bamboo" if room["zone"] == "temple" else "village"))


func _next_wave() -> void:
	var room: Dictionary = ROOMS[room_i]
	var waves: Array = room["waves"]
	wave_i += 1
	if wave_i >= waves.size():
		_room_cleared()
		return
	var w: Array = waves[wave_i]
	hud.wave_text = "第 %d 波 / 共 %d 波" % [wave_i + 1, waves.size()]
	var pts := arena.spawn_points.duplicate()
	pts.shuffle()
	# 优先刷在离主角远一点的地方
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(hero.global_position) > b.distance_to(hero.global_position))
	var pi := 0
	for j in range(0, w.size(), 2):
		var kind: String = w[j]
		var n: int = w[j + 1]
		for k in range(n):
			var p: Vector3 = pts[pi % pts.size()] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			pi += 1
			if kind == "boss":
				p = Vector3(0, 0, -2.0)
			_spawn_foe(kind, p, k * 0.12)
	if wave_i > 0:
		Game.sfx("boss" if w[0] == "boss" else "danger", -6.0)


func _spawn_foe(kind: String, p: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var f := Foe.new()
	f.setup_kind(kind, 1.0 + room_i * 0.12, 1.0 + room_i * 0.08)
	add_child(f)
	f.global_position = p
	f.face_to(hero.global_position - p)
	f.dropped.connect(_on_drop)
	if f.is_boss:
		hud.boss = f
		hud.banner("夜樱剑鬼", "守在樱树下的无名剑客", 2.6)
		cam_rig.punch_zoom(0.4, 0.8)


func _on_drop(pos: Vector3, c: int, j: int) -> void:
	for i in range(mini(c, 12)):
		_loot(pos, "coin", maxi(1, c / mini(c, 12)))
	for i in range(j):
		_loot(pos, "jade", 1)


func _loot(pos: Vector3, kind: String, amount: int) -> void:
	var l := Loot.new()
	l.kind = kind
	l.amount = amount
	add_child(l)
	l.global_position = pos + Vector3(0, 0.6, 0)
	l.collected.connect(func(k: String, a: int) -> void:
		if k == "coin":
			coins += a
		else:
			jade += a
		hud.coins = coins
		hud.jade = jade)


func _room_cleared() -> void:
	_state = "cleared"
	hud.wave_text = "清场"
	if room_i >= ROOMS.size() - 1:
		hud.banner("胜", "夜樱散尽，残刃归途", 5.0)
		Game.sfx("reward")
		_state = "won"
		return
	hud.banner("清场", "走进光门前往下一处", 2.2)
	Game.sfx("door")
	_portal = Node3D.new()
	add_child(_portal)
	_portal.global_position = arena.exit_pos
	vfx.ground(arena.exit_pos, "magic_01", Color(0.4, 1.0, 1.0, 0.9), 0.5, 3.0, 0.6)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/magic_01.png"))
	m.set_shader_parameter("color", Color(0.4, 1.0, 1.0))
	m.set_shader_parameter("energy", 2.0)
	ring.material_override = m
	ring.rotation.x = -PI / 2
	ring.position.y = 0.05
	_portal.add_child(ring)
	var col := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(2.4, 6.0)
	col.mesh = q2
	var m2 := ShaderMaterial.new()
	m2.shader = load("res://shaders/arpg/fx_add.gdshader")
	m2.set_shader_parameter("tex", load("res://assets/fx/lm_cone_a_blur.png"))
	m2.set_shader_parameter("color", Color(0.4, 1.0, 1.0, 0.8))
	m2.set_shader_parameter("energy", 1.6)
	col.material_override = m2
	col.position.y = 3.0
	col.rotation.z = PI
	_portal.add_child(col)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 1.0)
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.position.y = 1.5
	_portal.add_child(l)


func _on_hero_died(_a: Actor) -> void:
	_state = "dead"
	hud.banner("败", "按 J 或攻击键重来", 999.0)
	feel.screen_flash(Color(0.5, 0.0, 0.0, 0.6), 0.8)


func _process(dt: float) -> void:
	if arena != null and cam_rig.cam != null:
		arena.update_occluders(cam_rig.cam, [hero])
	hud.coins = coins
	hud.jade = jade
	_clock += dt
	if not _shots.is_empty() and _clock >= _shots[0]:
		_shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(_args["shot"]).replace(".png", "_%d.png" % _shot_n))
		_shot_n += 1
		if _shots.is_empty():
			get_tree().quit()
	match _state:
		"play":
			if _args.has("nowaves"):
				return
			var alive := get_tree().get_nodes_in_group("foes").size()
			if alive == 0:
				_wave_delay -= dt
				if _wave_delay <= 0.0:
					_wave_delay = 1.0
					_next_wave()
		"cleared":
			if is_instance_valid(_portal) and hero.alive:
				_portal.rotation.y += dt
				var d := hero.global_position - _portal.global_position
				d.y = 0
				if d.length() < 1.3:
					_state = "transition"
					feel.screen_flash(Color(0, 0, 0, 1.0), 0.0)
					Game.sfx("door")
					get_tree().create_timer(0.35).timeout.connect(func() -> void: _enter_room(room_i + 1))
		"dead":
			if Input.is_action_just_pressed(ArpgInput.act(0, "attack")):
				get_tree().reload_current_scene()
		"won":
			if Input.is_action_just_pressed(ArpgInput.act(0, "attack")) and hud._banner_t < 3.0:
				get_tree().reload_current_scene()
