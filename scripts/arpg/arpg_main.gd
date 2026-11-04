class_name ArpgMain
extends Node3D
## 《残刃归途》斜俯视动作版的主场景。搭环境（卡通渲染、青绿雾、Bloom、后期）、镜头、特效、HUD，再跑一局的流程：
##   标题 → 山门（拾骨婆点天赋、兵器架换兵器、光门出发）→ 一层一层的分岔房间（战 / 精英 / 商人 / 歇脚 / 奇遇 / 头目）
##   → 清房三选一心法 → 光门选下一间 → 第一层头目「夜樱剑鬼」→ 第二层古寺 → 头目「寂光」→ 结算（死了魂玉带回 60%）→ 山门。
##
## 命令行（-- 后面）：
##   --demo=fight 自动打（录视频用，主角不掉血）  --zone=temple 指定区域  --room=shop 直接进某种房间  --hub 直接进山门
##   --shot=路径 --shot_t=3,6 按时间拍图后退出  --nowaves 不刷怪  --cam_dist/--cam_pitch/--cam_yaw 调镜头

const HUB_SIZE := Vector2(24, 18)

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var cam_rig: CamRig
var vfx: Vfx
var feel: Feel
var hud: Hud3D
var post_rect: ColorRect
var ui_layer: CanvasLayer
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
var _menu: ArpgMenu
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
	if _args.has("shot"):
		for t: String in String(_args.get("shot_t", "3.0")).split(","):
			_shots.append(float(t))
	if _args.has("demo") or _args.has("room") or _args.has("zone"):
		_start_run(false)
		var kind := String(_args.get("room", "fight"))
		if kind == "1":
			kind = "fight"
		_enter_room(kind, String(_args.get("zone", "")))
		if _args.has("demo"):
			_bot = ArpgBot.new()
			_bot.hero = hero
			_bot.mode = String(_args["demo"])
			add_child(_bot)
			hero.invincible = true
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
	for n: ArpgNpc in _npcs:
		if is_instance_valid(n):
			n.queue_free()
	_npcs.clear()
	hud.boss = null
	_going = false


func _build_arena(zone_id: String, seed_value: int, sz: Vector2) -> void:
	arena = Arena.new()
	add_child(arena)
	arena.build(zone_id, seed_value, sz)
	_apply_zone_env(arena.zone_info())
	cam_rig.bounds = Rect2(-sz.x * 0.5 + 6.0, -sz.y * 0.5 + 2.0, sz.x - 12.0, sz.y - 4.0)


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


## 进当前房间（kind 为空时按地图上的房间类型）
func _enter_room(kind: String = "", zone_override: String = "") -> void:
	mode = "room"
	_clear_scene()
	_ensure_hero()
	room_kind = kind if kind != "" else state.room_type()
	var fl := state.floor_i()
	var zone_id := state.zone()
	if room_kind == "boss":
		zone_id = "sakura" if fl == 0 else "temple"
	if zone_override != "":
		zone_id = zone_override
	var sz := Vector2(30, 22)
	if room_kind in ["shop", "rest", "event", "start"]:
		sz = Vector2(24, 18)
	elif room_kind == "boss":
		sz = Vector2(32, 24)
	_build_arena(zone_id, state.seed_value + fl * 1000 + state.run.row * 37 + state.run.col * 7, sz)
	_place_hero(arena.entry_pos)
	state.rooms += 1
	wave_i = -1
	waves = _make_waves(room_kind, fl)
	_wave_delay = 1.4
	_room_done = waves.is_empty()
	var title := "%s · %s" % [ArpgState.FLOOR_NAMES[mini(fl, 1)], ArpgState.TYPE_NAMES.get(room_kind, "")]
	if room_kind == "boss":
		title = "夜樱广场" if fl == 0 else "古寺 · 寂光殿"
	hud.zone_name = title
	hud.wave_text = ""
	hud.visible = true
	var sub := "第 %d 层　第 %d / %d 间" % [fl + 1, state.run.row + 1, state.run.rows.size()]
	hud.banner(title, sub, 2.4)
	feel.screen_flash(Color(0, 0, 0, 1), 1.6)
	match room_kind:
		"boss":
			Game.music("boss")
		"shop", "rest", "event", "start":
			Game.music("hub")
		_:
			Game.music("bamboo" if zone_id == "temple" else "village")
	var mid := Vector3(-3.5, 0, -1.5)   # 摆在一边，别挡住去光门的路
	match room_kind:
		"start":
			_open_portal()
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


## 按房间类型配几波敌人：层数越深越多越硬
func _make_waves(kind: String, fl: int) -> Array:
	if _args.has("nowaves"):
		return []
	match kind:
		"fight":
			var w := [["crawler", 5 + fl * 2], ["skeleton", 3 + fl, "crawler", 3], ["skeleton", 2, "mage", 1 + fl, "crawler", 3]]
			if state.run.row >= 3:
				w.append(["samurai", 1, "skeleton", 2 + fl])
			return w
		"elite":
			return [["skeleton", 4, "mage", 2], ["samurai", 1 + fl, "crawler", 4], ["samurai", 2, "mage", 2, "skeleton", 2]]
		"boss":
			return [["boss" if fl == 0 else "boss2", 1]]
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
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(hero.global_position) > b.distance_to(hero.global_position))
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


func _spawn_foe(kind: String, p: Vector3, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if mode != "room" or arena == null:
		return
	var fl := state.floor_i() if state != null else 0
	var row := state.run.row if state != null else 0
	var f := Foe.new()
	f.setup_kind(kind, 1.0 + fl * 0.45 + row * 0.04, 1.0 + fl * 0.25 + row * 0.03)
	add_child(f)
	f.global_position = p
	f.face_to(hero.global_position - p)
	f.dropped.connect(_on_drop)
	if f.is_boss:
		hud.boss = f
		var sub := "守在樱树下的无名剑客" if kind == "boss" else "古寺深处，一盏不灭的灯"
		hud.banner(f.display_name, sub, 2.6)
		cam_rig.punch_zoom(0.4, 0.8)


func _on_drop(pos: Vector3, c: int, j: int) -> void:
	if state != null:
		state.kills += 1
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
	hud.wave_text = "清场"
	Game.sfx("door")
	if room_kind == "boss":
		if state.floor_i() >= ArpgState.FLOOR_ZONES.size() - 1:
			hud.banner("胜", "寂光熄灭，残刃归途", 4.0)
			Game.sfx("reward")
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _game_over(true))
			return
		hud.banner("夜樱散尽", "光门那头是古寺，第二层", 3.0)
		state.add_jade(5)
		get_tree().create_timer(1.2).timeout.connect(func() -> void: _offer_boons(3, "floor"))
		return
	hud.banner("清场", "选一个心法", 1.6)
	get_tree().create_timer(0.9).timeout.connect(func() -> void: _offer_boons(3 if room_kind != "elite" else 4, "next"))


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
			"tag": {"boon": "心法", "armor": "护甲", "charm": "护符", "refill": "补给"}.get(it["kind"], "")})
	var m := _open_menu("游商", "“兵荒马乱的，什么都贵。”　　铜钱 %d" % state.coins, items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		var it: Dictionary = stock[i]
		state.coins -= state.price(int(it["price"]))
		sold.append(i)
		state.bought[key] = sold
		match String(it["kind"]):
			"boon":
				_take_boon(String(it["id"]))
			"armor":
				state.armor = String(it["id"])
			"charm":
				state.charm = String(it["id"])
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
	lab.text = {"run": "出发", "floor": "前往第二层", "next": "前路"}.get(kind, "")
	_portal.add_child(lab)


func _step_portal() -> void:
	_going = true
	Game.sfx("door")
	match _portal_kind:
		"run":
			_start_run()
			_fade_then(func() -> void: _enter_room())
		"floor":
			state.run.next_floor()
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


func _game_over(won: bool) -> void:
	if mode == "over":
		return
	mode = "over"
	var r := state.settle(won)
	var sub := "第 %d 层　走过 %d 间　斩敌 %d　铜钱 %d" % [r["floor"], r["rooms"], r["kills"], r["coins"]]
	var desc := "魂玉 %d，全部带回" % r["jade"] if won else "魂玉 %d，带回 %d" % [r["jade"], r["kept"]]
	var items := [{"title": "回到山门", "desc": desc, "right": "存档魂玉 %d" % int(Game.save["jade"])}]
	var m := _open_menu("登顶" if won else "身死", sub, items, "list", false)
	m.chosen.connect(func(_i: int) -> void:
		_close_menu()
		feel.screen_flash(Color(0, 0, 0, 1), 0.0)
		_enter_hub())


# ---------- 每帧 ----------

func _process(dt: float) -> void:
	if arena != null and cam_rig.cam != null and is_instance_valid(hero):
		arena.update_occluders(cam_rig.cam, [hero])
	if state != null:
		hud.coins = state.coins
		hud.jade = state.jade
	_clock += dt
	if _args.has("dbg") and int(_clock * 2.0) != int((_clock - dt) * 2.0):
		var out := []
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Foe
			out.append("%s hp%d %s %s alive%s" % [a.kind, int(a.hp), a.state, str(a.global_position.snapped(Vector3.ONE * 0.1)), a.alive])
		print("t=%d %s done=%s wd=%.2f wi=%d alive=%s hero=%s %s foes=%s" % [int(_clock), mode, _room_done, _wave_delay, wave_i, hero.alive, str(hero.global_position.snapped(Vector3.ONE * 0.1)), hero.state, out])
	if not _shots.is_empty() and _clock >= _shots[0]:
		_shots.pop_front()
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(_args["shot"]).replace(".png", "_%d.png" % _shot_n))
		_shot_n += 1
		if _shots.is_empty():
			get_tree().quit()
	if mode == "room" and not _room_done and is_instance_valid(hero) and hero.alive:
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
