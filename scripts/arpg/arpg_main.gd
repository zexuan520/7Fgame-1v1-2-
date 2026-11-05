class_name ArpgMain
extends Node3D
## 《残刃归途》斜俯视动作版的主场景。搭环境（卡通渲染、青绿雾、Bloom、后期）、镜头、特效、HUD，再跑一局的流程：
##   标题 → 山门（拾骨婆点天赋、兵器架换兵器、光门出发）→ 一层一层的分岔房间（战 / 精英 / 商人 / 歇脚 / 奇遇 / 头目）
##   → 清房三选一心法 → 光门选下一间 → 第一层头目「夜樱剑鬼」→ 第二层无名冢 → 头目「百骨将」→ 第三层古寺 → 头目「寂光」→ 结算（死了魂玉带回 60%）→ 山门。
##
## 命令行（-- 后面）：
##   --demo=fight 自动打（录视频用，主角不掉血）  --zone=temple 指定区域  --room=shop 直接进某种房间  --hub 直接进山门
##   --shot=路径 --shot_t=3,6 按时间拍图后退出（--nohud 不画界面）  --nowaves 不刷怪  --cam_dist/--cam_pitch/--cam_yaw 调镜头

const HUB_SIZE := Vector2(30, 22)
## 房间尺寸（米，x 宽 × z 深）：战斗房 / 商人土地庙之类的小房 / 头目
const ROOM_SIZE := Vector2(44, 32)
const SMALL_ROOM := Vector2(30, 22)
const BOSS_ROOM := Vector2(40, 30)

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var cam_rig: CamRig
var vfx: Vfx
var feel: Feel
var hud: Hud3D
var post_rect: ColorRect
var ui_layer: CanvasLayer
var touch: TouchPad
var arena: Arena
var hero: Hero
var state: ArpgState
var mode := "title"          # title / hub / room / over
var room_kind := ""
var wave_i := -1
var waves: Array = []
var _wave_delay := 0.0
var _room_done := false
var _portal: Node3D
var _portal_kind := ""       # next 下一间 / run 出发 / floor 下一层
var _going := false
var _menu: Control             # 打开着的菜单或对话框（ArpgMenu / DialogBox）
var _hold_waves := false       # 头目登场对话还没说完，先别刷怪
var _secret: Node3D            # 这间房里的裂墙（打三下开出密室）
var _secret_hits := 0
var _trial_t := 0.0            # 试炼房剩余时间
var _trial_ok := true
var _extra_portals: Array[Node3D] = []   # 密室光门（和“前路”光门同时存在）
var _sw_step := -1
var _sw_t := 0.0
var _title: TitleCard
var _npcs: Array[ArpgNpc] = []
var _args := {}
var _bot: ArpgBot
var _shots: Array[float] = []
var _clock := 0.0
var _shot_n := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	ArpgInput.setup()
	Foe.tokens = 0
	_rng.randomize()
	_parse_args()
	_setup_world()
	apply_quality(_initial_quality())
	if _args.has("shot"):
		for t: String in String(_args.get("shot_t", "3.0")).split(","):
			_shots.append(float(t))
	if _args.has("demo") or _args.has("room") or _args.has("zone"):
		_start_run(false)
		for i in range(int(_args.get("floor", "0"))):
			state.run.next_floor()
			state.remap()
		var kind := String(_args.get("room", "fight"))
		if kind == "1":
			kind = "fight"
		_enter_room(kind, String(_args.get("zone", "")))
		if _args.has("demo"):
			_bot = ArpgBot.new()
			_bot.hero = hero
			_bot.mode = String(_args["demo"])
			add_child(_bot)
			hero.invincible = not _args.has("mortal")
	elif _args.has("hub"):
		_enter_hub()
	else:
		_enter_title()
	if _args.has("cam_dist"):
		cam_rig.distance = float(_args["cam_dist"])
	if _args.has("cam_pitch"):
		cam_rig.pitch_deg = float(_args["cam_pitch"])
	if _args.has("cam_yaw"):
		cam_rig.yaw_deg = float(_args["cam_yaw"])
	if _args.has("fxtest"):
		# 测试：把所有 pixelfx 特效排一排循环播放（拍图检查大小、落点）
		var ids := ["spawn-cast", "rune-cast", "crit-hit", "hit-spark", "ground-slam", "stunned", "soul-rise", "dark-explosion", "charge-up", "portal"]
		for i in range(ids.size()):
			var p := hero.global_position + Vector3(-9.0 + (i % 5) * 4.5, 0, -7.5 + (i / 5) * 6.0)
			vfx.sheet(ids[i], p, 3.0, Color.WHITE, 1.6, false, 30.0, float(_args["fxtest"]) if _args["fxtest"] != "1" else 1.0)
			vfx.shock_ring(p, Color.RED, 0.2, 0.3, 30.0)
	if _args.has("secret") and is_instance_valid(_secret):
		# 测试：站到裂墙旁边，清场后自动砍三刀
		_place_hero(_secret.global_position + Vector3(-signf(_secret.global_position.x) * 1.8, 0, 0.5), Vector3(signf(_secret.global_position.x), 0, 0))
		for k in range(4):
			get_tree().create_timer(1.0 + k * 0.6).timeout.connect(func() -> void:
				Input.action_press(ArpgInput.act(0, "attack"))
				get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release(ArpgInput.act(0, "attack"))))
	if _args.has("lineup"):
		# 测试：一排角色模型站好，拍特写对比
		var ids := [["rogue", "sword"], ["skel_minion", ""], ["skel_warrior", "skel_blade"], ["skel_mage", "skel_staff"], ["skel_rogue", ""], ["knight", "axe2"], ["barbarian", "sword2"]]
		for i in range(ids.size()):
			var n := _npc(ids[i][0], hero.global_position + Vector3(-4.5 + i * 1.5, 0, -2.2), {"model": ids[i][0], "weapon": ids[i][1]}, func(_x: ArpgNpc) -> void: pass)
			n.rotation.y = PI
			n.radius = 0.0
		hero.visible = false
	if _args.has("outro"):
		# 测试：直接当作头目已经打倒
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _room_cleared())
	if _args.has("givegear") and state != null:
		# 测试：往行囊里塞几件装备，过一会儿打开行囊
		for i in range(int(_args["givegear"])):
			state.bag.append(ArpgGear.roll(_rng, i % 3))
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _open_bag())
	if _args.has("touchtest"):
		# 测试：模拟手指——左手推摇杆往右上走，右手按住“斩”
		var send := func(ev: InputEvent) -> void: Input.parse_input_event(ev)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			var vs := get_viewport().get_visible_rect().size
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.pressed = true
			t.position = Vector2(180, vs.y - 160)
			send.call(t)
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = Vector2(240, vs.y - 210)
			send.call(d)
			var t2 := InputEventScreenTouch.new()
			t2.index = 1
			t2.pressed = true
			t2.position = Vector2(vs.x - 118, vs.y - 112)
			send.call(t2))
	if _args.has("pause"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _open_pause())
	if _args.has("interact"):
		# 测试：过一会儿自动和第一个互动物说话（拍菜单截图用）
		get_tree().create_timer(float(_args["interact"]) if _args["interact"] != "1" else 1.5).timeout.connect(func() -> void:
			if not _npcs.is_empty():
				_npcs[0].interacted.emit(_npcs[0])
			elif is_instance_valid(_portal):
				_place_hero(_portal.global_position))
	if not Game.loaded_reported:
		Game.loaded_reported = true
		get_tree().process_frame.connect(Zaohua.game_loaded, CONNECT_ONE_SHOT)


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"


# ---------- 画质 ----------
## 0 低：关阴影、辉光、后期，3D 画面按 70% 分辨率渲染；1 中：开辉光和后期，关阴影，85%；2 高：全开。
## 网页版第一次默认中，电脑版默认高；开打头 20 秒平均帧数太低会自动降一档（只降一次，记进设置）。
const QUALITY_NAMES := ["低", "中", "高"]
var quality := 2
var _fps_t := 0.0
var _fps_frames := 0
var _fps_checked := false


func _initial_quality() -> int:
	if _args.has("quality"):
		return clampi(int(_args["quality"]), 0, 2)
	var q := int(Game.settings.get("quality", -1))
	if q < 0:
		q = 0 if TouchPad.want() else (1 if OS.has_feature("web") else 2)   # 手机默认低
	return q


func apply_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	vfx.lod = quality
	Arena.lod = quality
	sun.shadow_enabled = quality >= 2
	world_env.environment.glow_enabled = quality >= 1
	post_rect.visible = quality >= 1
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][quality]
	if TouchPad.active or TouchPad.want():
		# 手机屏幕像素密度高（画布按设备像素算），3D 再降一些也看不出来
		vp.scaling_3d_scale = [0.5, 0.65, 0.8][quality]
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality < 2 else Viewport.MSAA_2X


## 头 20 秒战斗里的平均帧数低于 40 就降一档
func _watch_fps(_dt: float) -> void:
	if _fps_checked or mode != "room" or quality == 0 or _args.has("quality") or _args.has("demo") or _args.has("shot"):
		return
	# 按真实时间算（录像时 --fixed-fps 下 dt 是固定的）
	if _fps_frames == 0:
		_fps_t = Time.get_ticks_msec() / 1000.0
	_fps_frames += 1
	var secs := Time.get_ticks_msec() / 1000.0 - _fps_t
	if secs < 20.0:
		return
	_fps_checked = true
	var fps := _fps_frames / secs
	if fps < 40.0:
		apply_quality(quality - 1)
		Game.settings["quality"] = quality
		Game.write_settings()
		hud.banner("画质 · %s" % QUALITY_NAMES[quality], ("帧数偏低（%d），已自动调低；%s菜单里可以改" % [int(fps), TouchPad.hint("Esc ", "右上角 Ⅱ ")]), 3.0)


# ---------- 世界、镜头、后期、HUD ----------

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
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 8
	add_child(ui_layer)
	# 手机触屏按键
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 9   # 竖屏提示要盖住菜单；菜单打开时按键自己收起
	add_child(touch_layer)
	touch = TouchPad.new()
	touch_layer.add_child(touch)


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


## 换场景：清掉旧房间里的一切（敌人、掉落、光门、互动物）
func _clear_scene() -> void:
	Foe.tokens = 0
	if arena != null:
		arena.queue_free()
		arena = null
	for g: String in ["foes", "loot"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			n.queue_free()
	for n: Node in get_children():
		if n is Loot or n is BossWave:
			n.queue_free()
	if is_instance_valid(_portal):
		_portal.queue_free()
	_portal = null
	for p: Node3D in _extra_portals:
		if is_instance_valid(p):
			p.queue_free()
	_extra_portals.clear()
	for n: ArpgNpc in _npcs:
		if is_instance_valid(n):
			n.queue_free()
	_npcs.clear()
	hud.boss = null
	_going = false


func _build_arena(zone_id: String, seed_value: int, sz: Vector2) -> void:
	arena = Arena.new()
	add_child(arena)
	var _bt := Time.get_ticks_msec()
	arena.build(zone_id, seed_value, sz)
	if _args.has("dbg"):
		print("arena build ms ", Time.get_ticks_msec() - _bt)
	if _args.has("bench"):
		# 测缓存热了以后换房间要多久：再建一间同区域的房间，量完扔掉
		var a2 := Arena.new()
		add_child(a2)
		var t2 := Time.get_ticks_msec()
		a2.build(zone_id, seed_value + 1, sz)
		print("arena rebuild ms ", Time.get_ticks_msec() - t2)
		a2.queue_free()
	_apply_zone_env(arena.zone_info())
	cam_rig.bounds = Rect2(-sz.x * 0.5 + 6.0, -sz.y * 0.5 + 2.0, sz.x - 12.0, sz.y - 6.5)   # 靠镜头那边多收一点，别拍到墙外


## 主角：死过一次（人偶碎了）或者还没有，就新做一个
func _ensure_hero() -> void:
	if is_instance_valid(hero) and hero.alive:
		return
	if is_instance_valid(hero):
		hero.queue_free()
	hero = Hero.new()
	hero.name = "Hero"
	add_child(hero)
	hero.died.connect(_on_hero_died)
	cam_rig.target = hero
	hud.hero = hero
	touch.hero = hero
	if _bot != null:
		_bot.hero = hero


func _place_hero(p: Vector3, face: Vector3 = Vector3(0, 0, -1)) -> void:
	hero.global_position = p
	hero.velocity = Vector3.ZERO
	hero.knock = Vector3.ZERO
	hero.face_to(face)
	hero.clear_buffer()
	cam_rig.snap()


# ---------- 标题 ----------

func _enter_title() -> void:
	mode = "title"
	_clear_scene()
	_build_arena("sakura", 7, Vector2(30, 22))
	_ensure_hero()
	_place_hero(Vector3(0, 0, 2.0), Vector3(0, 0, 1))
	hero.visible = false
	hud.visible = false
	Game.music("hub")
	_title = TitleCard.new()
	ui_layer.add_child(_title)
	_title.started.connect(func() -> void:
		_title.queue_free()
		_title = null
		Game.sfx("door")
		feel.screen_flash(Color(0, 0, 0, 1), 0.0)
		_enter_hub())


# ---------- 山门（局外：天赋、兵器、出发） ----------

func _enter_hub() -> void:
	mode = "hub"
	state = null
	_clear_scene()
	_build_arena("forest", 4242, HUB_SIZE)
	_ensure_hero()
	hero.reset_for_run()
	hero.apply_stats(ArpgData.talent_stats(), String(Game.save.get("arpg_weapon", "sword")), true)
	_place_hero(arena.entry_pos)
	hud.visible = true
	hud.zone_name = "山门 · 拾骨婆的小院"
	hud.wave_text = "局外：点天赋、换兵器，走进光门出发"
	hud.coins = 0
	hud.jade = int(Game.save["jade"])
	hud.banner("山门", "魂玉 %d　·　出发 %d 次　·　登顶 %d 次" % [int(Game.save["jade"]), int(Game.save.get("runs", 0)), int(Game.save.get("clears", 0))], 2.6)
	feel.screen_flash(Color(0, 0, 0, 1), 1.4)
	Game.music("hub")
	var hz := HUB_SIZE.y * 0.5
	_npc("拾骨婆 · 天赋", Vector3(-4.0, 0, 1.0), {"model": "skel_mage", "weapon": "skel_staff", "tint": Color(1.1, 0.95, 0.8)}, _open_talents)
	_npc("兵器架", Vector3(4.0, 0, 1.0), {"kit": "sword_shield", "scale": 1.3}, _open_weapons)
	_make_portal(Vector3(0, 0, -hz + 2.5), "run", Color(1.0, 0.8, 0.45))
	_npc("试刀 · 教学", Vector3(-4.5, 0, -3.5), {"kit": "sword_shield", "scale": 1.1}, func(_n: ArpgNpc) -> void: _start_tutorial())
	# 残页石：看已经找到的寂光残页（隐藏剧情）
	if not ArpgStory.pages().is_empty():
		_npc("残页 %d / %d" % [ArpgStory.pages().size(), ArpgStory.PAGES.size()], Vector3(0, 0, 2.5), {"kit": "gravestone", "scale": 1.2}, _read_pages)
	# 第一次进山门：拾骨婆说开场白
	if not bool(Game.save.get("arpg_intro", false)) and not _args.has("demo"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_intro"] = true
			Game.write_save()
			_say(ArpgStory.INTRO))


func _npc(label: String, p: Vector3, spec: Dictionary, cb: Callable) -> ArpgNpc:
	var n := ArpgNpc.new()
	n.display = label
	n.model_id = String(spec.get("model", ""))
	n.weapon_id = String(spec.get("weapon", ""))
	n.tint = spec.get("tint", Color.WHITE)
	n.kit_id = String(spec.get("kit", ""))
	n.kit_scale = float(spec.get("scale", 1.0))
	add_child(n)
	n.global_position = p
	if n.model_id != "":
		var to := arena.entry_pos - p
		n.rotation.y = atan2(-to.x, -to.z)
	n.interacted.connect(func(_x: ArpgNpc) -> void: cb.call(n))
	_npcs.append(n)
	return n


func _open_talents(_n: ArpgNpc, keep_index: int = -1) -> void:
	var items := []
	var refs := []
	for ti in range(ArpgData.TALENT_TREES.size()):
		var t: Dictionary = ArpgData.TALENT_TREES[ti]
		for tier_i in range(t["tiers"].size()):
			var tier: Array = t["tiers"][tier_i]
			for ni in range(tier.size()):
				var nd: Dictionary = tier[ni]
				var r := ArpgData.talent_rank(nd["id"])
				var why := ArpgData.talent_why_not(ti, tier_i, ni)
				items.append({"tag": String(t["name"]), "tag_color": t["color"],
					"title": "%s　%d/%d" % [nd["name"], r, int(nd["max"])],
					"desc": String(nd["desc"]) + ("" if why == "" else "　（%s）" % why),
					"right": "已满" if why == "已满" else "%d 魂玉" % int(ArpgData.TALENT_COSTS[tier_i]),
					"enabled": why == "", "color": Color(0.95, 0.92, 0.85)})
				refs.append([nd["id"], tier_i])
	var m := _open_menu("拾骨婆 · 天赋", "“骨头记得你挨过的每一刀。”　　魂玉 %d" % int(Game.save["jade"]), items, "list", true)
	if keep_index >= 0:
		m.index = keep_index
	m.chosen.connect(func(i: int) -> void:
		var id: String = refs[i][0]
		var cost: int = ArpgData.TALENT_COSTS[refs[i][1]]
		Game.save["jade"] = int(Game.save["jade"]) - cost
		var tal: Dictionary = Game.save["talents"]
		tal[id] = int(tal.get(id, 0)) + 1
		Game.write_save()
		hero.apply_stats(ArpgData.talent_stats(), String(Game.save.get("arpg_weapon", "sword")), true)
		hud.jade = int(Game.save["jade"])
		vfx.shock_ring(hero.global_position, Color(1.0, 0.85, 0.45), 0.3, 3.0, 0.4)
		_close_menu()
		_open_talents(_n, i))


func _read_pages(_n: ArpgNpc) -> void:
	var lines := [["", "你找到了寂光写下的几页残页。"]]
	for i: int in ArpgStory.pages():
		lines.append(["寂光的残页 · 其%s" % ["一", "二", "三", "四", "五"][i], ArpgStory.PAGES[i], ArpgStory.C_MASTER])
	if ArpgStory.has_all_pages():
		lines.append(["", "五页都齐了。打倒寂光之后，也许能换一个结局。"])
	_say(lines)


func _open_weapons(_n: ArpgNpc) -> void:
	var owned: Array = Game.save.get("arpg_weapons", ["sword"])
	var cur := String(Game.save.get("arpg_weapon", "sword"))
	var items := []
	var ids := []
	for id: String in ArpgData.WEAPONS:
		var w: Dictionary = ArpgData.WEAPONS[id]
		var have := owned.has(id)
		var right := "使用中" if id == cur else ("换上" if have else "%d 魂玉" % int(w["price"]))
		items.append({"title": w["name"], "desc": w["desc"], "right": right,
			"enabled": have or int(Game.save["jade"]) >= int(w["price"]), "tag": "兵器"})
		ids.append(id)
	var m := _open_menu("兵器架", "换兵器就换了连招的手感。没有的用魂玉买下，永久留着。　　魂玉 %d" % int(Game.save["jade"]), items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		var id: String = ids[i]
		if not owned.has(id):
			Game.save["jade"] = int(Game.save["jade"]) - int(ArpgData.WEAPONS[id]["price"])
			owned.append(id)
			Game.save["arpg_weapons"] = owned
		Game.save["arpg_weapon"] = id
		Game.write_save()
		hero.apply_stats(ArpgData.talent_stats(), id, true)
		hud.jade = int(Game.save["jade"])
		feel.callout(hero.head_top(), String(ArpgData.WEAPONS[id]["name"]), Color(1.0, 0.85, 0.45), 1.1)
		_close_menu()
		_open_weapons(_n))


# ---------- 一局 ----------

func _start_run(fresh_hero: bool = true) -> void:
	state = ArpgState.start_new()
	if fresh_hero or not is_instance_valid(hero):
		_ensure_hero()
	hero.reset_for_run()
	hero.apply_stats(state.stats(), state.weapon, true)
	hero.revives = state.revives


## 数值调校用：--tel 时每间房打一行统计（耗时、挨打、剩血、药、铜钱）
var _tel := {}


func _tel_print(what: String) -> void:
	if not _args.has("tel") or state == null or not is_instance_valid(hero) or _tel.is_empty():
		return
	print("TEL %s %s clk=%.0f fl=%d row=%d secs=%.1f dmg=%.0f hp=%.0f/%.0f gourd=%d coins=%d kills=%d" % [what, room_kind, _clock, state.floor_i(), state.run.row,
		float(_tel["t"]), hero.dmg_total - float(_tel["dmg0"]), hero.hp, hero.max_hp, hero.gourds, state.coins, state.kills])


## 进当前房间（kind 为空时按地图上的房间类型）
func _enter_room(kind: String = "", zone_override: String = "") -> void:
	mode = "room"
	_clear_scene()
	_ensure_hero()
	_tel = {"t": 0.0, "dmg0": hero.dmg_total}
	room_kind = kind if kind != "" else state.room_type()
	var fl := state.floor_i()
	var zone_id := state.zone()
	if room_kind == "boss":
		zone_id = ArpgState.BOSS_ZONES[mini(fl, ArpgState.LAST_FLOOR)]
	if zone_override != "":
		zone_id = zone_override
	var sz := ROOM_SIZE
	if room_kind in ["shop", "rest", "event", "start", "story", "treasure", "secret", "tutorial"]:
		sz = SMALL_ROOM
	elif room_kind == "boss":
		sz = BOSS_ROOM
	_build_arena(zone_id, state.seed_value + fl * 1000 + state.run.row * 37 + state.run.col * 7 + (500 if room_kind == "secret" else 0), sz)
	_place_hero(arena.entry_pos)
	state.rooms += 1
	wave_i = -1
	waves = _make_waves(room_kind, fl)
	_wave_delay = 1.4
	_room_done = waves.is_empty()
	_hold_waves = false
	_secret = null
	_secret_hits = 0
	_trial_t = 50.0
	_trial_ok = true
	var title := "%s · %s" % [ArpgState.FLOOR_NAMES[mini(fl, ArpgState.LAST_FLOOR)], ArpgState.TYPE_NAMES.get(room_kind, "")]
	if room_kind == "boss":
		title = ArpgState.BOSS_TITLES[mini(fl, ArpgState.LAST_FLOOR)]
	if room_kind == "tutorial":
		title = "山门 · 试刀场"
	hud.zone_name = title
	hud.wave_text = ""
	hud.visible = true
	var sub := "第 %d 层　第 %d / %d 间" % [fl + 1, state.run.row + 1, state.run.rows.size()]
	if room_kind != "tutorial":
		hud.banner(title, sub, 2.4)
	feel.screen_flash(Color(0, 0, 0, 1), 1.6)
	match room_kind:
		"boss":
			Game.music(ArpgState.BOSS_MUSIC[mini(fl, ArpgState.LAST_FLOOR)])
		"secret":
			Game.music("secret")
		"shop", "rest", "event", "start", "story", "treasure", "tutorial":
			Game.music("hub")
		_:
			Game.music({"temple": "bamboo", "grave": "secret"}.get(zone_id, "village"))
	var mid := Vector3(-3.5, 0, -1.5)   # 摆在一边，别挡住去光门的路
	if room_kind in ["fight", "elite", "trial"] and not state.secrets_done.has(state.run.room_id()):
		var hint := state.flags.has("secret_hint")
		if hint or _args.has("secret") or _rng.randf() < 0.3:
			state.flags.erase("secret_hint")
			_make_secret_wall(sz)
	match room_kind:
		"tutorial":
			_tut_i = -1
			_tut_next()
		"start":
			_open_portal()
			if state.run.row == 0 and fl < ArpgStory.FLOOR_START.size() and not _args.has("demo") and not _args.has("lineup"):
				get_tree().create_timer(1.2).timeout.connect(func() -> void:
					if mode == "room" and _menu == null:
						_say(ArpgStory.FLOOR_START[fl]))
		"story":
			var en := ArpgStory.encounter_for(fl, state.flags, state.seen)
			if en.is_empty():
				var ev2 := state.event_for_room()
				_npc(String(ev2["name"]), mid, {"kit": "grave_a", "scale": 1.1}, _open_event)
			else:
				_npc(String(en["name"]), mid, {"kit": en["kit"], "scale": 1.1}, func(n: ArpgNpc) -> void: _open_story(n, en))
			_open_portal()
		"treasure":
			_npc("宝箱", Vector3(0, 0, -1.0), {"kit": "box", "scale": 1.4}, _open_chest)
			_open_portal()
		"secret":
			var pg := ArpgStory.next_page()
			if pg >= 0:
				_npc("刻字石碑", mid, {"kit": "gravestone", "scale": 1.3}, func(n: ArpgNpc) -> void: _take_page(n, pg))
			_npc("宝箱", Vector3(3.5, 0, -1.5), {"kit": "box", "scale": 1.4}, func(n: ArpgNpc) -> void: _open_chest(n, 2))
			arena.spirit_fire(Vector3(0, 0.6, -2.5), Color(0.8, 0.6, 1.0), 1.6, 2.4, 9.0)
			hud.banner("密室", "裂墙后面藏着的房间", 2.4)
			_open_portal()
		"boss":
			# 头目先说话，说完再出手
			_hold_waves = not _args.has("demo")
			if _hold_waves:
				get_tree().create_timer(1.3).timeout.connect(_boss_intro.bind(fl))
		"shop":
			_npc("游商", mid, {"model": "barbarian", "tint": Color(0.95, 0.85, 0.7)}, _open_shop)
			_open_portal()
		"rest":
			_npc("土地庙", mid, {"kit": "shrine", "scale": 1.2}, _open_rest)
			_open_portal()
		"event":
			var ev := state.event_for_room()
			var kits := {"blood_altar": "skull_candle", "wounded_ronin": "tent", "gambler": "table", "hermit": "well"}
			_npc(String(ev["name"]), mid, {"kit": kits.get(ev["id"], "grave_a"), "scale": 1.1}, _open_event)
			_open_portal()


# ---------- 试刀场（新手教学） ----------
## 每步：[标题（按键）, 说明, 要做的动作（机器人录像用）]
const TUT_STEPS := [
	["WASD 移动", "在院子里随便走两步", "move"],
	["空格 翻滚", "翻滚的一瞬间无敌，敌人举刀发红光时就滚开", "roll"],
	["J 攻击", "连按打出四段连招，最后一段最重。把这几只腐骨虫砍了", "attack"],
	["K 突进斩", "朝前冲过去斩一刀，隔得远也能贴上去，用完要等冷却", "dash"],
	["I 光束斩", "气力条（左下青色）满了才能放，一条直线上的敌人全吃到。现在已经给你攒满了", "beam"],
	["E 终结技", "敌人身上有出血（红点）时引爆，层数越多伤害越高。它们已经在流血了", "finish"],
	["U 药葫芦", "回复一大截生命，次数有限，土地庙能补满", "heal"],
]
## 触屏模式下的步骤标题
const TUT_TOUCH := ["左下摇杆 移动", "「滚」 翻滚", "「斩」 攻击", "「突」 突进斩", "「光」 光束斩", "「终」 终结技", "「药」 药葫芦"]
var _tut_i := -1
var _tut_t := 0.0
var _tut_moved := 0.0
var _tut_last := Vector3.ZERO
var _tut_did := false
var _tut_need := ""          # 机器人看这个按键
var _tut_wait := false       # 这一步完成了，等一下再进下一步


func _start_tutorial() -> void:
	_going = true
	_start_run()
	_fade_then(func() -> void: _enter_room("tutorial", "forest"))


func _tut_next() -> void:
	_tut_wait = false
	_tut_i += 1
	if _args.has("dbg"):
		print("TUT step ", _tut_i, " t=", _clock)
	_tut_t = 0.0
	_tut_did = false
	if _tut_i >= TUT_STEPS.size():
		_tut_need = ""
		Game.save["arpg_tutorial"] = true
		Game.write_save()
		hero.hp = hero.max_hp
		hero.gourds = hero.max_gourds
		hud.wave_text = "试刀完成"
		hud.banner("试刀完成", TouchPad.hint("走进光门正式上山。F 和人说话，Tab 打开行囊", "走进光门正式上山。靠近人点「互」说话，右上角「囊」打开行囊"), 3.5)
		Game.sfx("reward")
		_open_portal("run")
		return
	var st: Array = TUT_STEPS[_tut_i]
	if TouchPad.active:
		st = [TUT_TOUCH[_tut_i], st[1], st[2]]
	_tut_need = String(st[2])
	hud.wave_text = "试刀 %d / %d　%s" % [_tut_i + 1, TUT_STEPS.size(), st[0]]
	hud.banner(String(st[0]), String(st[1]), 4.0)
	Game.sfx("ui_back", -6.0)
	# 练习敌人刷在房间中间偏后（不管主角走到哪），突进斩的靶子放远一点
	var ahead := Vector3(0, 0, -2.5)
	var far_p := Vector3(0, 0, -4.0) if hero.global_position.z > 0.0 else Vector3(0, 0, 5.0)
	match _tut_need:
		"move":
			_tut_moved = 0.0
			_tut_last = hero.global_position
		"attack":
			for i in range(3):
				_tut_foe("crawler", ahead + Vector3(i * 1.6 - 1.6, 0, 0))
		"dash":
			_tut_foe("skeleton", far_p)
		"beam":
			hero.energy = hero.max_energy
			hero.energy_changed.emit()
			for i in range(4):
				_tut_foe("crawler", ahead + Vector3(randf_range(-0.6, 0.6), 0, -i * 1.2))
		"finish":
			hero.cd["finish"] = 0.0
			for i in range(3):
				var f := _tut_foe("skeleton", ahead + Vector3(i * 1.8 - 1.8, 0, 1.5))
				f.add_bleed(4)
		"heal":
			hero.hp = hero.max_hp * 0.45
			hero.gourds = maxi(hero.gourds, 1)


## 练习用的敌人：血少、伤害很低
func _tut_foe(kind: String, p: Vector3) -> Foe:
	var f := Foe.new()
	f.setup_kind(kind, 0.6, 0.25)
	add_child(f)
	f.global_position = p
	f.face_to(hero.global_position - p)
	return f


func _tut_tick(dt: float) -> void:
	if _tut_wait or _tut_i < 0 or _tut_i >= TUT_STEPS.size() or not is_instance_valid(hero) or is_instance_valid(_menu):
		return
	_tut_t += dt
	var st: Array = TUT_STEPS[_tut_i]
	if TouchPad.active:
		st = [TUT_TOUCH[_tut_i], st[1], st[2]]
	# 隔一阵子再提示一次，免得玩家没看到横幅
	if fmod(_tut_t, 9.0) < dt and _tut_t > 1.0:
		hud.banner(String(st[0]), String(st[1]), 3.0)
	if _tut_need == "move":
		_tut_moved += hero.global_position.distance_to(_tut_last)
		_tut_last = hero.global_position
		_tut_did = _tut_moved > 5.0
	elif _tut_need in ["roll", "dash", "beam", "finish", "heal"] and hero.state == _tut_need:
		_tut_did = true
	elif _tut_need == "attack" and hero.state == "attack":
		_tut_did = true
	# 守着练习敌人别让它们把人打死
	if hero.hp < hero.max_hp * 0.3 and _tut_need != "heal":
		hero.hp = hero.max_hp * 0.6
	var left := 0
	for f: Node in get_tree().get_nodes_in_group("foes"):
		if (f as Foe).alive:
			left += 1
	# 招式放完了，但还有没打死的：提示“把剩下的打完”
	if _tut_did and left > 0 and _tut_need != "heal":
		_tut_need = "attack"
		hud.wave_text = "试刀 %d / %d　把剩下的打完" % [_tut_i + 1, TUT_STEPS.size()]
	# 靶子被普通攻击打死了、招式还没用过：重新放一批再来
	if not _tut_did and left == 0 and _tut_need in ["dash", "beam", "finish"] and _tut_t > 1.5:
		_tut_i -= 1
		_tut_next()
		return
	if _tut_did and left == 0 and _tut_t > 0.8:
		hud.banner("好", "", 0.8)
		Game.sfx("reward", -8.0)
		get_tree().create_timer(0.9).timeout.connect(func() -> void:
			if mode == "room" and room_kind == "tutorial":
				_tut_next())
		_tut_wait = true


## 按房间类型配几波敌人：层数越深越多越硬
func _make_waves(kind: String, fl: int) -> Array:
	if _args.has("nowaves"):
		return []
	match kind:
		"fight":
			var w := [["crawler", 5 + fl * 2], ["skeleton", 3 + fl, "crawler", 3], ["skeleton", 2, "mage", 1 + mini(fl, 1), "crawler", 3]]
			if fl >= 1:
				# 无名冢起有骨刺客：快、血少，刺一下就退
				w[1] = ["skeleton", 2 + fl, "rogue", 2]
				w[2] = ["rogue", 2, "mage", 1 + mini(fl, 1), "crawler", 3]
			if state.run.row >= 3:
				w.append(["samurai", 1, "skeleton", 2 + mini(fl, 1)] if fl == 0 else ["samurai", 1, "rogue", 2, "skeleton", 1])
			return w
		"elite":
			if fl >= 1:
				return [["skeleton", 3, "rogue", 2, "mage", 1], ["samurai", 1 + mini(fl, 1), "crawler", 4], ["samurai", 2, "mage", 2, "rogue", 2]]
			return [["skeleton", 4, "mage", 2], ["samurai", 1 + fl, "crawler", 4], ["samurai", 2, "mage", 2, "skeleton", 2]]
		"boss":
			return [[ArpgState.BOSS_KINDS[mini(fl, ArpgState.LAST_FLOOR)], 1]]
		"trial":
			return [["crawler", 8, "skeleton", 3], ["crawler", 8, "mage", 2, "skeleton", 3], ["samurai", 1 + fl, "crawler", 10]]
	return []


func _next_wave() -> void:
	wave_i += 1
	if wave_i >= waves.size():
		_room_cleared()
		return
	var w: Array = waves[wave_i]
	hud.wave_text = "第 %d 波 / 共 %d 波" % [wave_i + 1, waves.size()]
	var pts := arena.spawn_points.duplicate()
	pts.shuffle()
	# 房间大了，不再刷在离主角最远的角落（要跑半天）：优先挑离主角 8~16 米的点，不够再按远近补
	var hp := hero.global_position
	var score := {}
	for q: Vector3 in pts:
		score[q] = _spawn_score(q.distance_to(hp))
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return float(score[a]) < float(score[b]))
	var pi := 0
	for j in range(0, w.size(), 2):
		var kind: String = w[j]
		var n: int = w[j + 1]
		for k in range(n):
			var p: Vector3 = pts[pi % pts.size()] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			pi += 1
			if kind.begins_with("boss"):
				p = Vector3(0, 0, -2.0)
			_spawn_foe(kind, p, k * 0.12)
	if wave_i > 0:
		Game.sfx("boss" if String(w[0]).begins_with("boss") else "danger", -6.0)


## 刷怪点打分（越小越好）：8~16 米最好，太近容易贴脸，太远要跑
func _spawn_score(d: float) -> float:
	if d < 8.0:
		return 100.0 + (8.0 - d)
	if d > 16.0:
		return d - 16.0
	return randf() * 0.5


func _spawn_foe(kind: String, p: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if mode != "room" or arena == null:
		return
	var fl := state.floor_i() if state != null else 0
	var row := state.run.row if state != null else 0
	var f := Foe.new()
	f.setup_kind(kind, 1.0 + fl * 0.35 + row * 0.04, 1.0 + fl * 0.18 + row * 0.03)
	add_child(f)
	f.global_position = p
	f.face_to(hero.global_position - p)
	f.detect_mult = 1.6   # 波次刷的怪一出来就该找人，大房间里别在角落发呆
	f.dropped.connect(_on_drop.bind(kind))
	if f.is_boss:
		hud.boss = f
		var sub: String = {"boss": "守在樱树下的无名剑客", "boss3": "无名冢下，万骨之主", "boss2": "古寺深处，一盏不灭的灯"}.get(kind, "")
		hud.banner(f.display_name, sub, 2.6)
		cam_rig.punch_zoom(0.4, 0.8)


func _on_drop(pos: Vector3, c: int, j: int, kind: String) -> void:
	if state != null and kind != "":
		state.kills += 1
		# 装备掉落：赤甲武士常掉，小怪偶尔掉
		var chance := {"samurai": 0.35, "mage": 0.06, "skeleton": 0.04, "rogue": 0.04, "crawler": 0.015}
		if _rng.randf() < float(chance.get(kind, 0.0)):
			_drop_gear(pos, -1, 0.1 if kind == "samurai" else 0.0)
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
		if state == null:
			return
		if k == "coin":
			state.add_coins(a)
		else:
			state.add_jade(a))


func _room_cleared() -> void:
	_room_done = true
	_tel_print("clear")
	hud.wave_text = "清场"
	Game.sfx("door")
	if room_kind == "boss":
		get_tree().create_timer(1.6).timeout.connect(_boss_outro.bind(state.floor_i()))
		return
	if room_kind == "elite":
		_drop_gear(hero.global_position + hero.facing * 1.5, -1, 0.25)
	if room_kind == "trial":
		hud.wave_text = "试炼完成" if _trial_ok else "试炼超时"
		_drop_gear(hero.global_position + hero.facing * 1.5, 3 if _trial_ok else 1)
	hud.banner("清场", "选一个心法", 1.6)
	get_tree().create_timer(0.9).timeout.connect(func() -> void: _offer_boons(3 if room_kind != "elite" else 4, "next"))


# ---------- 主线：头目战前战后、结局 ----------

func _boss_intro(fl: int) -> void:
	if mode != "room":
		return
	var key: String = ArpgState.BOSS_KINDS[mini(fl, ArpgState.LAST_FLOOR)]
	var lines: Array = ArpgStory.BOSS_PRE[key].duplicate()
	var extra: Dictionary = ArpgStory.BOSS_PRE_FLAGS.get(key, {})
	for f: String in extra:
		if state.flags.has(f):
			lines.append_array(extra[f])
	var d := _say(lines)
	d.finished.connect(func() -> void:
		if key == "boss2" and state.flags.has("ronin_saved"):
			hero.revives += 1
		_hold_waves = false
		_wave_delay = 0.3)


func _boss_outro(fl: int) -> void:
	if mode != "room":
		return
	var key: String = ArpgState.BOSS_KINDS[mini(fl, ArpgState.LAST_FLOOR)]
	_drop_gear(hero.global_position + hero.facing * 1.5, 3, 0.0)
	var d := _say(ArpgStory.BOSS_POST[key])
	if fl == 0:
		d.finished.connect(_sakura_choice)
	elif fl < ArpgState.LAST_FLOOR:
		d.finished.connect(_grave_choice)
	else:
		d.finished.connect(_ending_choice)


func _sakura_choice() -> void:
	var items := []
	for c: Array in ArpgStory.SAKURA_CHOICE:
		items.append({"title": c[0], "desc": c[1], "color": ArpgStory.C_SAKURA})
	var m := _open_menu("夜樱散尽", "阿樱的刀插在樱树下。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var fx: Dictionary = ArpgStory.SAKURA_CHOICE[i][2]
		state.flags[fx["flag"]] = true
		_close_menu()
		if fx.has("jade"):
			state.add_jade(int(fx["jade"]))
			feel.callout(hero.head_top(), "魂玉 +%d" % int(fx["jade"]), Color(0.55, 1.0, 0.85), 1.2)
		hud.banner("第一层 · 完", "光门那头是无名冢，第二层", 3.0)
		state.add_jade(5)
		_offer_boons(3, "floor"))


## 打倒百骨将后的选择
func _grave_choice() -> void:
	var items := []
	for c: Array in ArpgStory.GRAVE_CHOICE:
		items.append({"title": c[0], "desc": c[1], "color": ArpgStory.C_BONE})
	var m := _open_menu("万骨归土", "百骨将的头盔滚到你脚边。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var fx: Dictionary = ArpgStory.GRAVE_CHOICE[i][2]
		state.flags[fx["flag"]] = true
		_close_menu()
		if fx.has("jade"):
			state.add_jade(int(fx["jade"]))
			feel.callout(hero.head_top(), "魂玉 +%d" % int(fx["jade"]), Color(0.55, 1.0, 0.85), 1.2)
		if fx.has("heal"):
			hero.hp = hero.max_hp
			hero.gourds = hero.max_gourds
			feel.callout(hero.head_top(), "生命、药葫芦补满", Color(0.6, 1.0, 0.6), 1.2)
		hud.banner("第二层 · 完", "山顶就是寂光寺，最后一层", 3.0)
		state.add_jade(6)
		_offer_boons(3, "floor"))


func _ending_choice() -> void:
	var opts := [["douse", "熄灭残灯", "让死者安息。师父也会跟着灯一起走"], ["keep", "接过残灯", "像师父一样守着它"]]
	if ArpgStory.has_all_pages():
		opts.append(["true", "把五页残页交给师父", "（隐藏）你找齐了他写下的每一页"])
	var items := []
	for o: Array in opts:
		items.append({"title": o[1], "desc": o[2], "color": Color(1.0, 0.85, 0.5) if o[0] == "true" else ArpgStory.C_MASTER})
	var m := _open_menu("残灯", "灯就悬在你面前。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var id: String = opts[i][0]
		_close_menu()
		var e: Dictionary = ArpgStory.ENDINGS[id]
		var seen: Dictionary = Game.save.get("arpg_endings", {})
		seen[id] = true
		Game.save["arpg_endings"] = seen
		if id == "true":
			state.add_jade(30)
		var d := _say(e["lines"])
		d.finished.connect(func() -> void:
			hud.banner(String(e["title"]), "残刃归途", 4.0)
			Game.sfx("reward")
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _game_over(true, String(e["title"])))))


# ---------- 剧情遭遇、宝箱、密室 ----------

func _open_story(n: ArpgNpc, en: Dictionary) -> void:
	if n.used:
		return
	var d := _say(en["lines"])
	d.finished.connect(func() -> void:
		var items := []
		for op: Array in en["options"]:
			var fx: Dictionary = op[2]
			var ok := state.coins >= -int(fx.get("coins", 0)) and (int(fx.get("gourd", 0)) >= 0 or hero.gourds > 0)
			items.append({"title": op[0], "desc": String(op[1]) if ok else "做不到", "enabled": ok})
		var m := _open_menu(String(en["name"]), "", items, "list", false)
		m.chosen.connect(func(i: int) -> void:
			n.used = true
			state.seen[en["id"]] = true
			_close_menu()
			_story_effect(en["options"][i][2], n)))


func _story_effect(fx: Dictionary, n: ArpgNpc) -> void:
	if fx.has("flag"):
		state.flags[fx["flag"]] = true
	if fx.has("coins"):
		state.coins += int(fx["coins"])
	if fx.has("jade"):
		state.add_jade(int(fx["jade"]))
	if fx.has("gourd"):
		hero.gourds = maxi(0, hero.gourds + int(fx["gourd"]))
	if fx.has("curse"):
		state.curse += int(fx["curse"])
		hud.banner("诅咒", "这一局受到的伤害 +10%", 2.0)
		feel.screen_flash(Color(0.4, 0.0, 0.2, 0.5), 1.5)
	if fx.has("boon_id"):
		_take_boon(String(fx["boon_id"]))
	if fx.has("heal"):
		hero.hp = hero.max_hp
		hero.gourds = hero.max_gourds
		feel.callout(hero.head_top(), "生命、药葫芦补满", Color(0.6, 1.0, 0.6), 1.2)
	hero.apply_stats(state.stats(), state.weapon)
	if fx.has("gear"):
		_drop_gear(n.global_position + Vector3(0, 0, 1.5), maxi(int(fx["gear"]), 1) if int(fx["gear"]) > 1 else -1, 0.2)
	if fx.has("fight"):
		hud.banner(n.display, "动手了", 1.6)
		_room_done = false
		waves = [[String(fx["fight"]), 1, "skeleton", 2]]
		wave_i = -1
		_wave_delay = 0.6
		room_kind = "elite"
		if is_instance_valid(_portal):
			_portal.queue_free()
		n.queue_free()
	if fx.has("boon"):
		_offer_boons_then(int(fx["boon"]))


func _open_chest(n: ArpgNpc, min_rarity: int = 0) -> void:
	if n.used:
		return
	n.used = true
	Game.sfx("chest")
	vfx.sheet("crit-hit", n.global_position + Vector3(0, 0.3, 0), 3.0, Color(1.0, 0.9, 0.6), 2.2)
	vfx.shock_ring(n.global_position, Color(1.0, 0.85, 0.4), 0.3, 3.5, 0.5)
	var p := n.global_position + Vector3(0, 0, 1.2)
	_drop_gear(p, -1 if min_rarity <= 0 else min_rarity + (1 if _rng.randf() < 0.3 else 0), 0.15)
	if _rng.randf() < 0.45:
		_drop_gear(p + Vector3(0.6, 0, 0), -1, 0.0)
	_on_drop(p, 25 + state.floor_i() * 15, 1, "")


func _take_page(n: ArpgNpc, pg: int) -> void:
	if n.used:
		return
	n.used = true
	ArpgStory.take_page(pg)
	Game.sfx("memory")
	vfx.sheet("soul-rise", n.global_position, 3.5, Color(0.9, 0.8, 1.0), 1.8)
	var lines := [["", "石碑背面压着一页发黄的纸，是师父的字。"],
		["寂光的残页 · 其%s" % ["一", "二", "三", "四", "五"][pg], ArpgStory.PAGES[pg], ArpgStory.C_MASTER],
		["", "（残页 %d / %d）" % [ArpgStory.pages().size(), ArpgStory.PAGES.size()]]]
	if ArpgStory.has_all_pages():
		lines.append(["", "五页都齐了。打倒寂光之后，也许能换一个结局。"])
	_say(lines)


## 裂墙：靠墙放一段带裂缝的墙，墙缝里透一点紫光；清完房间后打三下就塌，后面是去密室的光门
func _make_secret_wall(sz: Vector2) -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var p := Vector3(side * (sz.x * 0.5 - 1.6), 0, _rng.randf_range(-sz.y * 0.5 + 4.0, sz.y * 0.5 - 6.0))
	_secret = Node3D.new()
	arena.add_child(_secret)
	_secret.global_position = p
	var w := arena.kit("wall_broken", p, PI * 0.5, 1.0, false)
	if w != null:
		w.reparent(_secret)
	var f := vfx.sheet("spirit-flame", p + Vector3(-signf(p.x) * 0.6, 0.1, 0), 1.1, Color(0.85, 0.55, 1.0, 0.8), 2.0, false, 1.0e6)
	f.reparent(_secret)
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.45, 1.0)
	l.light_energy = 1.6
	l.omni_range = 3.5
	_secret.add_child(l)
	l.position = Vector3(-signf(p.x) * 0.8, 0.8, 0)


func _hit_secret_wall() -> void:
	# 每一刀只算一次：换了连段、或者同一段重新开始，算新的一刀
	var new_swing := hero.state == "attack" and (hero.step_i != _sw_step or hero.st_t < _sw_t)
	_sw_step = hero.step_i if hero.state == "attack" else -1
	_sw_t = hero.st_t
	if not new_swing or not is_instance_valid(_secret):
		return
	if hero.global_position.distance_to(_secret.global_position) > 2.6:
		return
	pass
	if not _room_done:
		feel.callout(_secret.global_position + Vector3(0, 2, 0), "墙后有风声……", Color(0.8, 0.7, 1.0), 0.8)
		return
	_secret_hits += 1
	Game.sfx("block", -4.0)
	vfx.chips(_secret.global_position + Vector3(0, 1, 0), hero.facing, Color(0.4, 0.38, 0.36), 10, 6.0, 0.12)
	CamRig.I.shake(0)
	if _secret_hits >= 3:
		var p := _secret.global_position
		_secret.queue_free()
		_secret = null
		state.secrets_done[state.run.room_id()] = true
		Game.sfx("boom")
		CamRig.I.shake(1)
		vfx.dust(p, 2.5)
		vfx.chips(p + Vector3(0, 1, 0), Vector3.UP, Color(0.4, 0.38, 0.36), 24, 8.0, 0.14)
		hud.banner("裂墙塌了", "后面藏着一间密室", 2.0)
		_make_secret_portal(p - Vector3(signf(p.x) * 1.5, 0, 0))


func _make_secret_portal(p: Vector3) -> void:
	var keep := _portal
	var keep_kind := _portal_kind
	_make_portal(p, "secret", Color(0.75, 0.5, 1.0))
	var sp := _portal
	sp.set_meta("kind", "secret")
	_portal = keep
	_portal_kind = keep_kind
	_extra_portals.append(sp)


## 清房后选一个心法（卡片横排）
func _offer_boons(n: int, then_portal: String) -> void:
	if mode != "room":
		return
	var offer := state.roll_boons(n, _rng)
	var items := []
	for b: Dictionary in offer:
		var have := state.boons.count(String(b["id"]))
		items.append({"title": b["name"], "desc": b["desc"], "tag": "%s 心法" % b["school"], "color": ArpgData.SCHOOL_COLORS.get(b["school"], ArpgMenu.TEAL),
			"right": ("已有 %d" % have) if have > 0 else "", "glyph": String(b["name"]).substr(0, 1)})
	var m := _open_menu("心法", "三选一，留在身上直到这一局结束", items, "cards", false)
	m.chosen.connect(func(i: int) -> void:
		_take_boon(String(offer[i]["id"]))
		_close_menu()
		_open_portal(then_portal))


func _take_boon(id: String) -> void:
	state.boons.append(id)
	hero.apply_stats(state.stats(), state.weapon)
	var b := ArpgData.boon(id)
	feel.callout(hero.head_top(), String(b.get("name", "")), ArpgData.SCHOOL_COLORS.get(b.get("school", ""), Color.WHITE), 1.2)
	vfx.shock_ring(hero.global_position, ArpgData.SCHOOL_COLORS.get(b.get("school", ""), Color.WHITE), 0.3, 3.5, 0.45)


# ---------- 商人、歇脚、奇遇 ----------

func _open_shop(_n: ArpgNpc) -> void:
	var stock := state.shop_stock()
	var key := state.run.room_id()
	var sold: Array = state.bought.get(key, [])
	var items := []
	for i in range(stock.size()):
		var it: Dictionary = stock[i]
		var pr := state.price(int(it["price"]))
		var gone := sold.has(i)
		var en := not gone and state.coins >= pr
		if it["kind"] == "refill" and hero.gourds >= hero.max_gourds:
			en = false
		items.append({"title": it["name"], "desc": it["desc"], "right": "已售" if gone else "%d 铜钱" % pr, "enabled": en,
			"tag": {"boon": "心法", "gear": "装备", "refill": "补给"}.get(it["kind"], ""),
			"color": ArpgGear.color(it["item"]) if it["kind"] == "gear" else Color(0.95, 0.92, 0.85)})
	var m := _open_menu("游商", "“兵荒马乱的，什么都贵。”　　铜钱 %d" % state.coins, items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		var it: Dictionary = stock[i]
		state.coins -= state.price(int(it["price"]))
		sold.append(i)
		state.bought[key] = sold
		match String(it["kind"]):
			"boon":
				_take_boon(String(it["id"]))
			"gear":
				_gain_gear(it["item"])
			"refill":
				hero.gourds = hero.max_gourds
		hero.apply_stats(state.stats(), state.weapon)
		Game.sfx("coin")
		_close_menu()
		_open_shop(_n))


func _open_rest(n: ArpgNpc) -> void:
	if n.used:
		return
	var items := [
		{"title": "上香歇息", "desc": "回复 50% 生命", "tag": "歇脚"},
		{"title": "求一壶药", "desc": "补满药葫芦，再回复 15% 生命", "tag": "歇脚"},
	]
	var m := _open_menu("土地庙", "香火还没断。歇一歇再走。", items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		if i == 0:
			_heal(0.5)
		else:
			hero.gourds = hero.max_gourds
			_heal(0.15)
		n.used = true
		_close_menu())


func _heal(frac: float) -> void:
	var v := hero.max_hp * frac
	hero.hp = minf(hero.max_hp, hero.hp + v)
	feel.number(hero.chest(), "+%d" % int(v), Color(0.5, 1.0, 0.6), 1.0)
	vfx.shock_ring(hero.global_position, Color(0.5, 1.0, 0.6), 0.3, 3.0, 0.5)
	Game.sfx("heal")


func _open_event(n: ArpgNpc) -> void:
	if n.used:
		return
	var ev := state.event_for_room()
	var items := []
	for op: Array in ev["options"]:
		var fx: Dictionary = op[1]
		var en := state.coins >= -int(fx.get("coins", 0))
		if int(fx.get("gourd", 0)) < 0 and hero.gourds <= 0:
			en = false
		items.append({"title": op[0], "desc": "" if en else "做不到", "enabled": en})
	var m := _open_menu(String(ev["name"]), String(ev["text"]), items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var fx: Dictionary = ev["options"][i][1]
		n.used = true
		_close_menu()
		_apply_event(fx))


func _apply_event(fx: Dictionary) -> void:
	if fx.has("coins"):
		state.coins += int(fx["coins"])
	if fx.has("hp"):
		var d := hero.max_hp * float(fx["hp"])
		hero.hp = maxf(1.0, hero.hp + d)
		feel.number(hero.chest(), "%d" % int(d), Color(0.9, 0.2, 0.25), 1.0)
		hero.rig.flash(0.15)
	if fx.has("heal"):
		_heal(float(fx["heal"]))
	if fx.has("gourd"):
		hero.gourds = maxi(0, hero.gourds + int(fx["gourd"]))
	if fx.has("gourd_refill"):
		hero.gourds = hero.max_gourds
	var boons := int(fx.get("boon", 0))
	if fx.has("gamble"):
		if _rng.randf() < 0.5:
			boons = 2
			hud.banner("赢了", "赌鬼骂骂咧咧地掏出两卷心法", 2.0)
		else:
			hud.banner("输了", "赌鬼笑着收起了铜钱", 2.0)
			Game.sfx("block")
	if boons > 0:
		_offer_boons_then(boons)


## 奇遇给的心法：连着选 n 次（不开光门，光门本来就开着）
func _offer_boons_then(n: int) -> void:
	if n <= 0:
		return
	var offer := state.roll_boons(3, _rng)
	var items := []
	for b: Dictionary in offer:
		items.append({"title": b["name"], "desc": b["desc"], "tag": "%s 心法" % b["school"], "color": ArpgData.SCHOOL_COLORS.get(b["school"], ArpgMenu.TEAL)})
	var m := _open_menu("心法", "三选一" + ("（还有 %d 次）" % (n - 1) if n > 1 else ""), items, "cards", false)
	m.chosen.connect(func(i: int) -> void:
		_take_boon(String(offer[i]["id"]))
		_close_menu()
		_offer_boons_then(n - 1))


# ---------- 光门、分岔路 ----------

func _open_portal(kind: String = "next") -> void:
	_room_done = true
	_make_portal(arena.exit_pos, kind, Color(0.4, 1.0, 1.0))


func _make_portal(p: Vector3, kind: String, col: Color) -> void:
	_portal_kind = kind
	_portal = Node3D.new()
	add_child(_portal)
	_portal.global_position = p
	vfx.ground(p, "magic_01", Color(col, 0.9), 0.5, 3.0, 0.6)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/arpg/fx_add.gdshader")
	m.set_shader_parameter("tex", load("res://assets/fx/magic_01.png"))
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("energy", 2.0)
	ring.material_override = m
	ring.rotation.x = -PI / 2
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_portal.add_child(ring)
	var beam := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(2.4, 6.0)
	beam.mesh = q2
	var m2 := ShaderMaterial.new()
	m2.shader = load("res://shaders/arpg/fx_add.gdshader")
	m2.set_shader_parameter("tex", load("res://assets/fx/lm_cone_a_blur.png"))
	m2.set_shader_parameter("color", Color(col, 0.8))
	m2.set_shader_parameter("energy", 1.6)
	beam.material_override = m2
	beam.position.y = 3.0
	beam.rotation.z = PI
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_portal.add_child(beam)
	# pixelfx 旋涡光门（循环）
	var swirl := vfx.sheet("portal", p, 4.6, Color(col.lightened(0.3), 1.0), 1.8, false, 100000.0)
	swirl.reparent(_portal)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.position.y = 1.5
	_portal.add_child(l)
	var lab := Label3D.new()
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.font = feel.font
	lab.font_size = 40
	lab.outline_size = 10
	lab.pixel_size = 0.008
	lab.modulate = Color(col.lightened(0.4), 0.9)
	lab.position.y = 3.2
	lab.text = {"run": "出发", "floor": "前往第%s层" % ["一", "二", "三"][mini(state.floor_i() + 1, 2)] if state != null else "", "next": "前路", "secret": "密室"}.get(kind, "")
	_portal.add_child(lab)


func _step_portal() -> void:
	_going = true
	Game.sfx("door")
	match _portal_kind:
		"run":
			if mode == "hub" and not bool(Game.save.get("arpg_tutorial", false)) and not _args.has("demo"):
				_going = false
				var items := [{"title": "先试试刀", "desc": "一间练习房，一步一步学会移动、翻滚、连招和三个招式（约两分钟）", "tag": "推荐"},
					{"title": "直接出发", "desc": "已经会了，直接上山"}]
				var mn := _open_menu("第一次上山", "拾骨婆：“先在院子里比划两下？”", items, "cards", false)
				mn.chosen.connect(func(i: int) -> void:
					_close_menu()
					if i == 0:
						_start_tutorial()
					else:
						Game.save["arpg_tutorial"] = true
						Game.write_save()
						_going = true
						_start_run()
						_fade_then(func() -> void: _enter_room()))
				return
			_start_run()
			_fade_then(func() -> void: _enter_room())
		"floor":
			state.run.next_floor()
			state.remap()
			_fade_then(func() -> void: _enter_room())
		_:
			var ex := state.run.exits()
			if ex.size() <= 1:
				if ex.size() == 1:
					state.run.advance(int(ex[0][0]))
				_fade_then(func() -> void: _enter_room())
			else:
				_choose_path(ex)


func _fade_then(cb: Callable) -> void:
	feel.screen_flash(Color(0, 0, 0, 1.0), 0.0)
	get_tree().create_timer(0.35).timeout.connect(cb)


func _choose_path(ex: Array) -> void:
	var items := []
	for e: Array in ex:
		var nd: Dictionary = e[1]
		var t := String(nd["type"])
		items.append({"title": ArpgState.TYPE_NAMES.get(t, t), "desc": ArpgState.TYPE_DESC.get(t, ""), "tag": "岔路",
			"color": _type_color(t), "glyph": String(ArpgState.TYPE_NAMES.get(t, t)).substr(0, 1)})
	var m := _open_menu("分岔路", "第 %d 层　第 %d / %d 间　·　往哪走？" % [state.floor_i() + 1, state.run.row + 2, state.run.rows.size()], items, "cards", true)
	m.extra_draw = _draw_map
	m.chosen.connect(func(i: int) -> void:
		state.run.advance(int(ex[i][0]))
		_close_menu()
		_fade_then(func() -> void: _enter_room()))
	m.cancelled.connect(func() -> void:
		_close_menu()
		_going = false
		_place_hero(hero.global_position + Vector3(0, 0, 2.2), Vector3(0, 0, -1)))


func _type_color(t: String) -> Color:
	return {"fight": Color(0.75, 0.85, 0.9), "elite": Color(1.0, 0.4, 0.35), "shop": Color(1.0, 0.85, 0.45), "rest": Color(0.5, 1.0, 0.6),
		"event": Color(0.75, 0.6, 1.0), "boss": Color(0.95, 0.25, 0.4), "start": Color(0.6, 0.9, 0.9)}.get(t, ArpgMenu.TEAL)


## 菜单上方画一条小地图：每列的房间点、走过的路
func _draw_map(c: Control, vs: Vector2) -> void:
	var rows: Array = state.run.rows
	var x0 := vs.x * 0.22
	var w := vs.x * 0.56
	var y0 := vs.y * 0.16 + 58
	var h := 40.0
	var pos := func(r: int, i: int) -> Vector2:
		var n: int = (rows[r] as Array).size()
		return Vector2(x0 + w * r / float(rows.size() - 1), y0 + h * ((i + 0.5) / float(n)))
	for r in range(rows.size() - 1):
		for i in range((rows[r] as Array).size()):
			for j: int in rows[r][i]["next"]:
				c.draw_line(pos.call(r, i), pos.call(r + 1, j), Color(0.5, 0.7, 0.7, 0.3), 1.0)
	for r in range(rows.size()):
		for i in range((rows[r] as Array).size()):
			var nd: Dictionary = rows[r][i]
			var p: Vector2 = pos.call(r, i)
			var col := _type_color(String(nd["type"]))
			var here := r == state.run.row and i == state.run.col
			c.draw_circle(p, 7.0 if here else 4.5, Color(col, 1.0 if bool(nd["visited"]) or here else 0.45))
			if here:
				c.draw_arc(p, 11.0, 0, TAU, 20, ArpgMenu.GOLD, 1.5)


# ---------- 剧情对话 ----------

## 放一段对话，返回对话框（await 它的 finished 等说完）
func _say(lines: Array) -> DialogBox:
	_close_menu()
	var d := DialogBox.new()
	d.lines = lines
	ui_layer.add_child(d)
	_menu = d
	hud.visible = false
	hero.clear_buffer()
	d.finished.connect(func() -> void:
		if _menu == d:
			_menu = null
		hud.visible = mode != "title"
		hero.clear_buffer())
	return d


# ---------- 装备：掉落、行囊、合成 ----------

func _drop_gear(pos: Vector3, rarity: int = -1, luck: float = 0.0) -> void:
	if state == null:
		return
	var it := ArpgGear.roll(_rng, rarity, luck + state.floor_i() * 0.08)
	var l := Loot.new()
	l.kind = "gear"
	l.item = it
	add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)
	l.collected.connect(func(_k: String, _a: int) -> void: _gain_gear(it))


## 捡到装备：那个部位空着就直接穿上，否则放进行囊（满了就换成铜钱）
func _gain_gear(it: Dictionary) -> void:
	if state == null:
		return
	var slot := String(it["slot"])
	var where := ""
	if (state.gear[slot] as Dictionary).is_empty():
		state.gear[slot] = it
		hero.apply_stats(state.stats(), state.weapon)
		where = "（已装备）"
	elif state.bag.size() < ArpgGear.BAG_MAX:
		state.bag.append(it)
		where = TouchPad.hint("（放进行囊，Tab 查看）", "（放进行囊，右上角「囊」查看）")
	else:
		var c := state.add_coins(15 + 15 * int(it["rarity"]))
		where = "（行囊满了，换成 %d 铜钱）" % c
	feel.callout(hero.head_top() + Vector3(0, 0.3, 0), String(it["name"]), ArpgGear.color(it), 1.3)
	hud.banner(String(it["name"]), ArpgGear.describe(it) + where, 2.2)


func _open_bag(keep_index: int = -1) -> void:
	if state == null:
		return
	var items := []
	var acts := []
	for slot: String in ["armor", "charm"]:
		var it: Dictionary = state.gear[slot]
		var sname := "护甲" if slot == "armor" else "护符"
		if it.is_empty():
			items.append({"tag": sname, "title": "（空）", "desc": "", "enabled": false})
		else:
			items.append({"tag": sname, "title": it["name"], "desc": ArpgGear.describe(it), "color": ArpgGear.color(it),
				"right": "卸下", "enabled": state.bag.size() < ArpgGear.BAG_MAX})
		acts.append(["unequip", slot])
	for i in range(state.bag.size()):
		var it: Dictionary = state.bag[i]
		items.append({"tag": "行囊", "title": it["name"], "desc": ("护甲：" if it["slot"] == "armor" else "护符：") + ArpgGear.describe(it),
			"color": ArpgGear.color(it), "right": "换上"})
		acts.append(["equip", i])
	for r: int in ArpgGear.craftable(state.bag):
		items.append({"tag": "合成", "tag_color": Color(1.0, 0.8, 0.4), "title": "三件「%s」合成一件「%s」" % [ArpgGear.RARITY_NAMES[r], ArpgGear.RARITY_NAMES[r + 1]],
			"desc": "用掉行囊里三件同品质的装备，随机得到一件高一档的", "color": ArpgGear.RARITY_COLORS[r + 1], "right": "合成"})
		acts.append(["craft", r])
	var sub := "行囊 %d / %d　·　心法 %d 个　·　残页 %d / %d" % [state.bag.size(), ArpgGear.BAG_MAX, state.boons.size(), ArpgStory.pages().size(), ArpgStory.PAGES.size()]
	var m := _open_menu("行囊", sub, items, "list", true)
	m.footer = TouchPad.hint("J 选择　　Tab / 空格 关闭", "点选一项　　右上角 ✕ 关闭")
	if keep_index >= 0:
		m.index = mini(keep_index, items.size() - 1)
	m.chosen.connect(func(i: int) -> void:
		var a: Array = acts[i]
		match String(a[0]):
			"unequip":
				state.bag.append(state.gear[a[1]])
				state.gear[a[1]] = {}
			"equip":
				var it: Dictionary = state.bag[int(a[1])]
				state.bag.remove_at(int(a[1]))
				var old: Dictionary = state.gear[it["slot"]]
				if not old.is_empty():
					state.bag.append(old)
				state.gear[it["slot"]] = it
			"craft":
				var made := ArpgGear.craft(state.bag, int(a[1]), _rng)
				state.bag.append(made)
				Game.sfx("reward")
				vfx.shock_ring(hero.global_position, ArpgGear.color(made), 0.3, 4.0, 0.5)
				vfx.sheet("crit-hit", hero.chest() - Vector3(0, 0.6, 0), 3.0, ArpgGear.color(made), 2.0)
				feel.callout(hero.head_top(), "合成：" + String(made["name"]), ArpgGear.color(made), 1.5)
		hero.apply_stats(state.stats(), state.weapon)
		_close_menu()
		_open_bag(i))


# ---------- 菜单 ----------

func _open_menu(title: String, sub: String, items: Array, layout: String, cancellable: bool) -> ArpgMenu:
	_close_menu()
	var m := ArpgMenu.new()
	m.title = title
	m.subtitle = sub
	m.items = items
	m.layout = layout
	m.cancellable = cancellable
	ui_layer.add_child(m)
	m.cancelled.connect(_close_menu)
	_menu = m
	hud.visible = false
	hero.clear_buffer()
	return m


func _no_dialog() -> bool:
	return get_tree().get_nodes_in_group("dialog_box").is_empty()


## Esc / 手柄 Start：暂停菜单（音量、放弃这一局）。网页版里没有“退出游戏”
func _open_pause(sel: int = 0) -> void:
	var pct := func(k: String) -> String: return "%d%%" % int(round(float(Game.settings[k]) * 100.0))
	var items := [{"title": "继续"},
		{"title": "音乐音量", "right": pct.call("music"), "desc": TouchPad.hint("按确认键切换", "点一下切换")},
		{"title": "音效音量", "right": pct.call("sfx"), "desc": TouchPad.hint("按确认键切换", "点一下切换")},
		{"title": "画质", "right": QUALITY_NAMES[quality], "desc": "低：关阴影和辉光，降低渲染分辨率，适合网页和轻薄本"}]
	if mode == "room":
		items.append({"title": "放弃这一局", "desc": "回到山门，魂玉带回六成"})
	var m := _open_menu("暂停", "", items, "list", true)
	m.index = sel
	m.chosen.connect(_on_pause_chosen)


func _on_pause_chosen(i: int) -> void:
	match i:
		1, 2:
			var k := "music" if i == 1 else "sfx"
			var steps := [1.0, 0.75, 0.5, 0.25, 0.0]
			var cur := float(Game.settings[k])
			var nxt := 1.0   # 往下调一档，到 0 之后回到 100%
			for s: float in steps:
				if s < cur - 0.05:
					nxt = s
					break
			Game.settings[k] = nxt
			Game.apply_volume()
			Game.write_settings()
			Game.sfx("coin")
			_open_pause(i)
		3:
			apply_quality((quality + 2) % 3)   # 高 → 中 → 低 → 高
			Game.settings["quality"] = quality
			Game.write_settings()
			_fps_checked = true
			Game.sfx("coin")
			_open_pause(i)
		4:
			_close_menu()
			_game_over(false)
		_:
			_close_menu()


func _close_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	hud.visible = mode != "title"
	if is_instance_valid(hero):
		hero.clear_buffer()


# ---------- 死亡、结算 ----------

func _on_hero_died(_a: Actor) -> void:
	if mode != "room":
		return
	hud.banner("败", "残刃折于此地", 2.5)
	feel.screen_flash(Color(0.5, 0.0, 0.0, 0.6), 0.8)
	get_tree().create_timer(2.2).timeout.connect(func() -> void: _game_over(false))


func _game_over(won: bool, ending: String = "") -> void:
	if mode == "over":
		return
	_tel_print("won" if won else "dead")
	mode = "over"
	var r := state.settle(won)
	var sub := "第 %d 层　走过 %d 间　斩敌 %d　铜钱 %d" % [r["floor"], r["rooms"], r["kills"], r["coins"]]
	var desc := "魂玉 %d，全部带回" % r["jade"] if won else "魂玉 %d，带回 %d" % [r["jade"], r["kept"]]
	var items := [{"title": "回到山门", "desc": desc, "right": "存档魂玉 %d" % int(Game.save["jade"])}]
	var m := _open_menu(ending if ending != "" else ("登顶" if won else "身死"), sub, items, "list", false)
	m.chosen.connect(func(_i: int) -> void:
		_close_menu()
		feel.screen_flash(Color(0, 0, 0, 1), 0.0)
		_enter_hub())


# ---------- 每帧 ----------

func _process(dt: float) -> void:
	if mode == "room" and room_kind == "tutorial":
		_tut_tick(dt)
	if not _tel.is_empty():
		_tel["t"] = float(_tel["t"]) + dt
	if arena != null and cam_rig.cam != null and is_instance_valid(hero):
		arena.update_occluders(cam_rig.cam, [hero])
	if state != null:
		hud.coins = state.coins
		hud.jade = state.jade
	_clock += dt
	_watch_fps(dt)
	if _args.has("nohud"):
		hud.visible = false   # 拍宣传图用
	if _args.has("dbg") and int(_clock * 2.0) != int((_clock - dt) * 2.0):
		var out := []
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Foe
			out.append("%s hp%d %s %s alive%s" % [a.kind, int(a.hp), a.state, str(a.global_position.snapped(Vector3.ONE * 0.1)), a.alive])
		print("wp=%.2f menu=%s cam=%s t=%d %s done=%s wd=%.2f wi=%d alive=%s hero=%s %s foes=%s" % [feel.world_pause, is_instance_valid(_menu), str(cam_rig.cam.global_position.snapped(Vector3.ONE*0.1)) if cam_rig.cam else "", int(_clock), mode, _room_done, _wave_delay, wave_i, hero.alive, str(hero.global_position.snapped(Vector3.ONE * 0.1)), hero.state, out])
	if not _shots.is_empty() and _clock >= _shots[0]:
		_shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(_args["shot"]).replace(".png", "_%d.png" % _shot_n))
		_shot_n += 1
		if _shots.is_empty():
			get_tree().quit()
	if mode == "room" and is_instance_valid(_secret) and is_instance_valid(hero):
		_hit_secret_wall()
	if (mode == "room" or mode == "hub") and _menu == null and state != null and is_instance_valid(hero) and hero.alive \
			and Input.is_action_just_pressed(ArpgInput.act(0, "bag")):
		_open_bag()
	if (mode == "room" or mode == "hub") and _menu == null and _no_dialog() and is_instance_valid(hero) and hero.alive \
			and Input.is_action_just_pressed("quit"):
		_open_pause()
	if mode == "room" and room_kind == "trial" and not _room_done and wave_i >= 0:
		_trial_t -= dt if feel.world_pause <= 0.0 else 0.0
		if _trial_t <= 0.0 and _trial_ok:
			_trial_ok = false
			hud.banner("超时", "还能打完，但奖励差一些", 1.6)
		hud.wave_text = "第 %d 波 / 共 %d 波　限时 %d 秒" % [wave_i + 1, waves.size(), maxi(0, int(ceil(_trial_t)))] if _trial_ok else "第 %d 波 / 共 %d 波　已超时" % [wave_i + 1, waves.size()]
	for sp: Node3D in _extra_portals:
		if is_instance_valid(sp):
			sp.rotation.y += dt
			if not _going and _menu == null and is_instance_valid(hero) and hero.alive:
				var dd := hero.global_position - sp.global_position
				dd.y = 0
				if dd.length() < 1.3:
					_going = true
					Game.sfx("door")
					_fade_then(func() -> void: _enter_room("secret"))
	if mode == "room" and not _room_done and not _hold_waves and is_instance_valid(hero) and hero.alive:
		if get_tree().get_nodes_in_group("foes").is_empty():
			_wave_delay -= dt
			if _wave_delay <= 0.0:
				_wave_delay = 1.0
				_next_wave()
	if is_instance_valid(_portal):
		_portal.rotation.y += dt
		if not _going and _menu == null and is_instance_valid(hero) and hero.alive:
			var d := hero.global_position - _portal.global_position
			d.y = 0
			if d.length() < 1.3:
				_step_portal()
