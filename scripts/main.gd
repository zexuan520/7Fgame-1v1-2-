extends Node2D
## 主场景：搭建房间、生成角色、管理特效、顿帧和镜头震动，以及一局肉鸽的流程：
## 破庙出发 → 一间间房间往右走（清完敌人门才开，岔路自己选） → 打柳江远 → 回破庙。
## 死了也回破庙，魂玉带回 60%，铜钱丢光。F4 切换到旧的练武场（数字键换对手）。
## 游戏画面画在 640×360 的低分辨率画布上再放大，得到清晰的像素颗粒；界面文字画在画布外，保持清晰。

const VIEW_W := 640.0
const VIEW_H := 360.0
const FLOOR_Y := 300.0
const PRACTICE_W := 800.0
const P1_SPAWN := Vector2(280, FLOOR_Y)
const P2_SPAWN := Vector2(220, FLOOR_Y)
const ENTRY_X := 70.0                 # 进房间时站的位置
const MAX_ATTACKERS := 2              # 设计文档：同时最多两个敌人进攻
const REVIVE_RATIO := 0.4             # 双人时倒下的人，清完房间以 40% 生命爬起来
const DEATH_DELAY := 2.4              # 全员倒下后多久出结算
const HEAL_PICKUP := 0.15             # 罐子里的伤药回 15% 生命
const GEAR_DROP := 0.05               # 杂兵掉装备的几率
const CHEST_GEAR := 0.6               # 宝箱里有装备的几率
const REWARD_DELAY := 1.2             # 清完战斗房、精英房后多久弹出三选一
const ELITE_MEMORY := 0.5             # 精英掉记忆碎片的几率

var arena_w := PRACTICE_W             # 当前房间宽度，镜头和墙都按它来
var mode := "practice"                # practice 练武场 / hub 破庙 / room 闯关中的房间
var players: Array[Player] = []
var enemies: Array[Enemy] = []
var interactables: Array[Interactable] = []
var breakables: Array[Breakable] = []
var camera: Camera2D
var world: Node2D
var fx_root: Node2D
var room_root: Node2D                 # 背景、地面、摆设、门、人物，换房间时整个删掉重建
var front_root: Node2D
var hud: Hud
var background: Background
var features: RoomFeatures            # 跑酷和解谜机关（坑、竹签、烂木板、寨门、拉杆、灯笼、裂墙）
var post: ShaderMaterial
var encounter := 0
var _clear_timer := -1.0

# 房间流程
var waves: Array = []
var wave := 0
var cleared := true
var _wave_timer := -1.0
var _death_timer := -1.0
var dead_wait := false                # 结算画面出来了，等按攻击回破庙
var menu_player: Player = null        # 拾骨婆的天赋界面开着（谁打开的谁来点）
var menu_cursor := Vector3i.ZERO      # 天赋界面光标：树、层、节点
var focus_gear := {}                  # 玩家序号 → 正站在跟前的地上装备（界面画对比卡）
## 清房奖励三选一：玩家序号 → {"choices": [...], "cursor": 选中第几个, "replace": -1 或正在选换掉哪一格, "type": 房间类型}
## 双人时各选各的，谁选完谁先能动；两个人都选完门才能进
var rewards := {}
var _reward_timer := -1.0             # 倒数到 0 弹出三选一
var _reward_frame := -1               # 三选一弹出的那一帧（这一帧的按键是别的界面的，不算）
var _reward_type := ""
var event_player: Player = null       # 奇遇界面开着（谁打开的谁来选）
var event_it: Interactable = null
var event_cursor := 0
var memory_player: Player = null      # 破庙忆境开着
var memory_cursor := 0
var codex_player: Player = null       # 破庙招式谱开着
var codex_cursor := Vector2i.ZERO     # 招式谱光标：列（0 招式 1 心法）、行
var _fade_dir := 0                    # 1 正在变黑，-1 正在变亮
var _after_fade: Callable

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

	fx_root = Node2D.new()
	fx_root.z_index = 10
	world.add_child(fx_root)
	camera = Camera2D.new()
	camera.position = Vector2(P1_SPAWN.x + 120.0, VIEW_H / 2.0)
	world.add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)

	_spawn_player(1)
	if Game.practice:
		_load_practice()
	elif Game.run != null:
		_load_room()
	else:
		_load_hub()


# ---------- 房间搭建 ----------

## 删掉旧房间，按数据搭一个新的：背景、地面和墙、能站的平台、摆设
func _build_room(def: Dictionary) -> void:
	if room_root != null:
		room_root.queue_free()
		front_root.queue_free()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	interactables.clear()
	breakables.clear()
	for f in fx_root.get_children():
		f.queue_free()
	waves = []
	wave = 0
	cleared = true
	_wave_timer = -1.0
	_clear_timer = -1.0
	arena_w = float(def.get("width", PRACTICE_W))

	room_root = Node2D.new()
	room_root.z_index = -10
	world.add_child(room_root)
	match String(def.get("theme", "temple")):
		"village":
			var bv := BgVillage.new()
			bv.mood = String(def.get("mood", "dusk"))
			background = bv
		"river": background = BgRiver.new()
		_: background = Background.new()
	background.floor_y = FLOOR_Y
	background.arena_w = arena_w
	background.seed_value = int(def.get("seed", 0))
	room_root.add_child(background)

	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	room_root.add_child(ground)
	var feats: Array = def.get("features", [])
	for sp: Array in RoomFeatures.ground_spans(feats, arena_w):   # 地面，被坑切成几段
		_add_box(ground, Rect2(sp[0], FLOOR_Y, sp[1] - sp[0], 100))
	_add_box(ground, Rect2(-40, -200, 40, 600))                  # 左墙
	_add_box(ground, Rect2(arena_w, -200, 40, 600))              # 右墙
	var props: Array = def.get("props", [])
	# 平台和楼梯单独一层：单向，能从下面跳上去，按 下+跳 落下去
	var plat := StaticBody2D.new()
	plat.collision_layer = 0
	plat.collision_mask = 0
	plat.set_collision_layer_value(Fighter.PLATFORM_LAYER, true)
	room_root.add_child(plat)
	for r in RoomProps.platform_rects(props, FLOOR_Y):
		_add_box(plat, r, true)
	for rp: Array in RoomProps.ramps(props, FLOOR_Y):
		_add_ramp(plat, rp[0], rp[1])
	var pr := RoomProps.new()
	pr.props = props
	pr.floor_y = FLOOR_Y
	room_root.add_child(pr)
	features = RoomFeatures.new()
	features.main = self
	features.features = feats
	features.floor_y = FLOOR_Y
	features.arena_w = arena_w
	features.z_index = 1
	room_root.add_child(features)
	features.setup()
	for item: Array in props:
		var at := Vector2(float(item[1]), FLOOR_Y - (float(item[2]) if item.size() > 2 else 0.0))
		if Breakable.KINDS.has(item[0]):
			var b := Breakable.new()
			b.kind = item[0]
			b.main = self
			b.position = at
			b.z_index = 3
			room_root.add_child(b)
			breakables.append(b)
		elif item[0] == "chest":
			var it := _add_interactable("chest", at.x, "", "chest", Color("e0b860"))
			it.position = at
		elif item[0] == "note":
			var id: String = item[3] if item.size() > 3 else "ronin"
			var it := _add_interactable("note", at.x, "", "note", Color("c8bca8"), {"id": id})
			it.position = at

	front_root = Node2D.new()
	front_root.z_index = 20
	world.add_child(front_root)
	for l in background.make_foreground():
		front_root.add_child(l)


func _add_box(body: StaticBody2D, r: Rect2, one_way: bool = false) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)


## 楼梯：一块斜着的单向碰撞板，上表面贴着 a→b 这条线
func _add_ramp(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var d := b - a
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(d.length(), 8)
	shape.shape = rect
	shape.rotation = d.angle()
	shape.position = (a + b) / 2.0 + Vector2(-d.y, d.x).normalized() * 4.0
	shape.one_way_collision = true
	body.add_child(shape)


func _add_interactable(kind: String, x: float, label: String, icon: String, color: Color, data: Dictionary = {}) -> Interactable:
	var it := Interactable.new()
	it.kind = kind
	it.label = label
	it.icon = icon
	it.color = color
	it.data = data
	it.position = Vector2(x, FLOOR_Y)
	it.z_index = 2
	room_root.add_child(it)
	interactables.append(it)
	return it


func _add_npc(kind: String, x: float) -> Npc:
	var n := Npc.new()
	n.setup(kind)
	n.main = self
	n.position = Vector2(x, FLOOR_Y)
	n.z_index = 3
	room_root.add_child(n)
	return n


func _place_players(x: float) -> void:
	for p in players:
		p.global_position = Vector2(x - (p.index - 1) * 28.0, FLOOR_Y)
		p.spawn_pos = p.global_position
		p.velocity = Vector2.ZERO
		p.facing = 1
	camera.position.x = clampf(x + 120.0, VIEW_W / 2.0, arena_w - VIEW_W / 2.0)
	camera.position.x = roundf(camera.position.x)


# ---------- 练武场（F4） ----------

func _load_practice() -> void:
	mode = "practice"
	_build_room({"width": PRACTICE_W, "theme": "temple"})
	for p in players:
		p.global_position = P1_SPAWN if p.index == 1 else P2_SPAWN
		p.spawn_pos = p.global_position
		_apply_player_stats(p, true)
	start_encounter(0)
	hud.toast("练武场 · 数字键 1-5 换对手，F4 回破庙")


# ---------- 破庙 ----------

func _load_hub() -> void:
	mode = "hub"
	dead_wait = false
	_death_timer = -1.0
	_build_room(LevelData.room("temple"))
	_place_players(110.0)
	for p in players:
		if not p.is_alive():
			p.respawn()
		p.gear = GearData.empty_loadout(String(Game.save["start_weapon"]))
		p.build = Arts.new_build()
		p.revives = 0
		_apply_player_stats(p, true)
		p.will = 0.0
	_add_npc("monk", 300.0)
	_add_npc("granny", 452.0)
	_add_interactable("talent", 452.0, "", "talent", Color("5ed6a8"))
	var rack := _add_interactable("rack", 600.0, "兵器架", "rack", Color("c9a24a"))
	_refresh_rack(rack)
	var pool := _add_interactable("memory", 376.0, "忆境", "memory", Color("8ac8e0"))
	pool.sub = "拼合记忆碎片 · %d 片" % Story.collected().size()
	var codex := _add_interactable("codex", 190.0, "招式谱", "codex", Color("d8b878"))
	codex.sub = "用魂玉把招式、心法加进掉落池"
	var fd := LevelData.floor_data(0)
	var gate := _add_interactable("door", arena_w - 56.0, "出发", "start", Color("e0a050"), {"action": "start_run"})
	gate.sub = "%s · %s" % [fd["sub"], fd["name"]]
	var res := Game.last_result
	if not res.is_empty():
		if res["victory"]:
			hud.title_card("第一层 · 通关", "魂玉 +%d 全部带回" % res["kept"])
		else:
			hud.title_card("回到破庙", "魂玉 %d → 带回 %d（60%%）" % [res["jade"], res["kept"]])
		Game.last_result = {}
	else:
		hud.room_banner("破庙", "据点")


## 兵器架：出发时带哪把武器（闯关时拿到过的武器才会挂上来）
func _refresh_rack(it: Interactable) -> void:
	var cur: String = Game.save["start_weapon"]
	var n := (Game.save["weapons"] as Array).size()
	it.data["weapon"] = cur
	it.sub = "出发带 %s · %d/%d 把" % [GearData.WEAPONS[cur]["name"], n, GearData.WEAPONS.size()]
	for p in players:
		if p.gear["weapon"]["base"] != cur:
			p.gear = GearData.empty_loadout(cur)
			_apply_player_stats(p, false)


func _start_run() -> void:
	Game.run = Run.create(0)
	Game.run.coins = int(Talents.run_value("start_coins"))
	Game.save["runs"] = int(Game.save["runs"]) + 1
	Game.write_save()
	for p in players:
		p.gear = Game.run.loadout(p.index)
		p.build = Game.run.build(p.index)
		_apply_player_stats(p, true)
		p.will = 0.0
		Game.run.revives[p.index] = int(p.stats["revive"])
		p.revives = int(p.stats["revive"])
	_fade_then(_load_room)


# ---------- 闯关：房间 ----------

func _load_room() -> void:
	mode = "room"
	var r := Game.run
	var def := r.room()
	_close_rewards()
	_build_room(def)
	_place_players(ENTRY_X)
	for p in players:
		p.auto_respawn = false
	var fd := r.floor_data()
	Game.save["best_row"] = maxi(int(Game.save["best_row"]), r.row)
	var t := r.room_type()
	match t:
		"shop":
			var stock := r.stock()
			var x := 250.0
			for id: String in stock:
				var spec: Dictionary = LevelData.SHOP_ITEMS[id]
				var it := _add_interactable("item", x, spec["name"], id, Color("e0b860"), {"id": id})
				it.sub = "%s · %d 铜钱" % [spec["desc"], shop_price(int(spec["cost"]))]
				x += 84.0
			for item: Variant in r.shop_gear_list():
				if item != null:
					var g := _add_gear(item, Vector2(x, FLOOR_Y))
					g.data["price"] = shop_price(GearData.PRICES[int(item["q"])])
					g.data["shop_index"] = (r.shop_gear_list() as Array).find(item)
				x += 84.0
			_add_npc("merchant", x + 30.0)
		"event":
			var eid: String = r.node()["event"]
			var ev := Events.get_event(eid)
			var x := arena_w * 0.5
			if ev.has("npc"):
				_add_npc(ev["npc"], x + 14.0).lines = []
			var it := _add_interactable("event", x, "" if ev.has("npc") else String(ev["name"]), "event", Color("c8a8f0"),
				{"id": eid, "prop": ev.get("prop", "")})
			it.sub = String(ev["name"]) if ev.has("npc") else ""
			if r.events_done.has(r.room_id()):
				it.used = true
				it.enabled = false
		"rest":
			var it := _add_interactable("rest", arena_w * 0.5, "土地庙", "rest", Color("7fb2e0"))
			it.sub = "回满生命，补满药罐"
			if r.rested.has(r.room_id()):
				it.used = true
				it.enabled = false
	waves = def.get("waves", [])
	cleared = waves.is_empty()
	if not cleared:
		_spawn_wave(0, def.get("intro", false))
	_make_exits()
	if not def.get("intro", false):
		hud.room_banner(def["name"], "%s · %d / %d" % [fd["name"], r.row + 1, r.rows.size()])
	var line: Variant = def.get("line")
	if line is Array:
		hud.say(line[0], line[1], 3.0)


## 出口门画在哪儿：房间数据写了 exit_x 就在那儿（门右边可以藏密室），没写就贴着右墙
func exit_x() -> float:
	return float(Game.run.room().get("exit_x", arena_w)) if mode == "room" else arena_w


## 房间右边的出口：下一列连着几个房间就有几扇门
func _make_exits() -> void:
	var r := Game.run
	var exits := r.exits()
	if exits.is_empty():
		return   # 头目房间：打完才出现回破庙的门
	var n := exits.size()
	for i in range(n):
		var col: int = exits[i][0]
		var nd: Dictionary = exits[i][1]
		var tdef: Dictionary = LevelData.NODE_TYPES[nd["type"]]
		var x := exit_x() - 70.0 - (n - 1 - i) * 100.0   # 离右墙留出门匾上字的宽度
		var it := _add_interactable("door", x, tdef["label"], nd["type"], tdef["color"], {"action": "next", "col": col})
		it.sub = LevelData.room(nd["room"])["name"]
		it.enabled = cleared


func _spawn_wave(i: int, intro: bool = false) -> void:
	wave = i
	var n := 0
	for s: Array in waves[i]:
		var pos := Vector2(float(s[1]), FLOOR_Y - (float(s[2]) if s.size() > 2 else 0.0))
		if i > 0 and s.size() <= 2 and arena_w > VIEW_W * 1.5:
			# 长房间：后面的波次不从房间两头刷，从玩家身边冲出来
			pos.x = _wave_x(float(s[1]) < arena_w * 0.5, n)
			n += 1
		var e := spawn_enemy(s[0], pos)
		e.perch = s.size() > 2   # 写了高度的守在高处
		if intro:
			e.start_intro(Story.meet(e.kind))
		elif i == 0:
			e.aggro = false
		else:
			e.attack_cooldown = 1.0
			spawn_dust(pos, 0.0, 10)
			spawn_ring(pos + Vector2(0, -24), Color(1.0, 0.4, 0.3), 30.0)
	if i > 0:
		hud.toast("又来了一批！")
		shake(2.0)


func _update_room(dt: float) -> void:
	if _reward_timer >= 0.0:
		_reward_timer -= dt
		if _reward_timer < 0.0 and not dead_wait and _death_timer < 0.0:
			open_rewards(_reward_type)
	if not cleared:
		if _wave_timer >= 0.0:
			_wave_timer -= dt
			if _wave_timer < 0.0:
				_spawn_wave(wave + 1)
		elif _all_enemies_down():
			if wave + 1 < waves.size():
				_wave_timer = 0.9
			else:
				_on_room_cleared()
	# 全员倒下：等一会儿出结算
	if not dead_wait and _death_timer < 0.0 and not players.is_empty():
		var any_alive := false
		for p in players:
			if p.is_alive():
				any_alive = true
		if not any_alive:
			_death_timer = DEATH_DELAY
	if _death_timer >= 0.0:
		_death_timer -= dt
		if _death_timer < 0.0:
			dead_wait = true
			hud.show_death(Game.run)


func _all_enemies_down() -> bool:
	for e in enemies:
		if e.state != Enemy.S.DEAD and e.state != Enemy.S.DYING:
			return false
	return true


func _on_room_cleared() -> void:
	cleared = true
	var r := Game.run
	r.rooms_cleared += 1
	var jade: int = LevelData.CLEAR_JADE.get(r.room_type(), 0)
	var at := Vector2(camera.position.x, FLOOR_Y - 80.0)
	if jade > 0:
		spawn_pickups("jade", jade, at)
	for it in interactables:
		if it.kind == "door":
			it.set_enabled(true)
	# 双人时倒下的那个爬起来
	var alive: Player = null
	for p in players:
		if p.is_alive():
			alive = p
	for p in players:
		if not p.is_alive() and alive != null:
			p.spawn_pos = alive.global_position
			p.respawn()
			p.hp = p.max_hp * REVIVE_RATIO
			spawn_text(p.global_position + Vector2(0, -70), "复苏", Color(0.6, 1.0, 0.7))
	if LevelData.REWARD_ROOMS.has(r.room_type()):
		_reward_type = r.room_type()
		_reward_timer = REWARD_DELAY
	if r.is_last_room():
		Game.save["clears"] = int(Game.save["clears"]) + 1
		# 头目的身世：打败几次给第几片
		var boss: String = r.room()["waves"][0][0][0]
		grant_memory(Story.boss_fragment(boss, int(Game.save["clears"])), at)
		var it := _add_interactable("door", exit_x() - 60.0, "回破庙", "temple", Color("e0a050"), {"action": "victory"})
		it.sub = "第二层 · 尚未开放"
		it.set_enabled(true)
		_open_later(it)
	else:
		hud.toast("清场 · 出口开了")


## 门在头目倒下一会儿之后再出现，让死亡台词说完
func _open_later(it: Interactable) -> void:
	it.visible = false
	await get_tree().create_timer(2.5, true, false, true).timeout
	if is_instance_valid(it):
		it.visible = true
		it.set_enabled(true)
		spawn_ring(it.global_position + Vector2(0, -30), Color(1.0, 0.75, 0.4), 50.0)
		hud.title_card("第一层 · 通关", "断水 · 柳江远 击破")


# ---------- 清房奖励：三选一 ----------

## 弹出三选一。only 不为空时只给这一个人（奇遇里），kinds、art_lv 见 Arts.roll_choices
func open_rewards(room_type: String, only: Player = null, kinds: Array = ["art", "mind", "up"], art_lv: int = 0) -> void:
	var r := Game.run
	rewards.clear()
	_reward_frame = Engine.get_process_frames()
	for p in players:
		if only != null and p != only:
			continue
		rewards[p.index] = {"choices": Arts.roll_choices(r.rng, p.build, room_type, r.row, kinds, art_lv), "cursor": 0,
			"replace": -1, "type": room_type}
		p.frozen = true
	hud.show_map = false
	hud.show_gear = false
	hud.show_build = false


func _close_rewards() -> void:
	rewards.clear()
	_reward_timer = -1.0
	for p in players:
		_unfreeze(p)


func _unfreeze(p: Player) -> void:
	p.frozen = false
	p._buf.clear()   # 选奖励时按的键不要留到外面


func _update_rewards() -> void:
	if Engine.get_process_frames() == _reward_frame:
		return
	for idx: int in rewards.keys():
		var p: Player = null
		for q in players:
			if q.index == idx:
				p = q
		if p == null:
			rewards.erase(idx)   # 2P 退出了
			continue
		var rw: Dictionary = rewards[idx]
		var pr := p.prefix
		var step := 0
		if Input.is_action_just_pressed(pr + "left") or Input.is_action_just_pressed(pr + "jump"):
			step = -1
		elif Input.is_action_just_pressed(pr + "right") or Input.is_action_just_pressed(pr + "down"):
			step = 1
		var choice: Dictionary = rw["choices"][rw["cursor"]]
		if int(rw["replace"]) < 0:
			rw["cursor"] = posmod(int(rw["cursor"]) + step, (rw["choices"] as Array).size())
			if Input.is_action_just_pressed(pr + "attack"):
				choice = rw["choices"][rw["cursor"]]
				if Arts.needs_replace(p.build, choice):
					rw["replace"] = 0
				else:
					take_reward(p, -1)
		else:
			var n := Arts.MAX_ARTS if choice["kind"] == "art" else Arts.MAX_MINDS
			rw["replace"] = posmod(int(rw["replace"]) + step, n)
			if Input.is_action_just_pressed(pr + "attack"):
				take_reward(p, int(rw["replace"]))
			elif Input.is_action_just_pressed(pr + "guard") or Input.is_action_just_pressed(pr + "dodge"):
				rw["replace"] = -1


## 玩家选定了光标上的奖励（格子满了时 replace 是换掉第几个）
func take_reward(p: Player, replace: int) -> void:
	var rw: Dictionary = rewards[p.index]
	var choice: Dictionary = rw["choices"][rw["cursor"]]
	var at := p.global_position + Vector2(0, -74)
	if choice["kind"] == "coin":
		Game.run.coins += int(choice["amount"])
		hud.bump("coin")
	else:
		Arts.take(p.build, choice, replace)
		_apply_player_stats(p, false)
	var col := Arts.color(choice)
	spawn_text(at, Arts.describe(choice)[1], col, 12)
	spawn_spark(p.global_position + Vector2(0, -30), col, 12)
	rewards.erase(p.index)
	_unfreeze(p)


func _go_next(col: int) -> void:
	_fade_then(func() -> void:
		Game.run.advance(col)
		_load_room())


func _finish_run(victory: bool) -> void:
	var r := Game.run
	if r == null:
		return
	var kept := r.jade if victory else int(floor(r.jade * death_keep()))
	Game.save["jade"] = int(Game.save["jade"]) + kept
	if not victory:
		Game.save["deaths"] = int(Game.save["deaths"]) + 1
	Game.last_result = {"victory": victory, "jade": r.jade, "kept": kept, "coins": r.coins,
		"kills": r.kills, "rooms": r.rooms_cleared}
	Game.write_save()
	Game.run = null
	_fade_then(_load_hub)


## 敌人进入倒地时调用：掉铜钱和魂玉
func on_enemy_killed(e: Enemy) -> void:
	if mode != "room":
		return
	Game.run.kills += 1
	var drop: Dictionary = LevelData.DROPS.get(e.kind, {})
	var at := e.global_position + Vector2(0, -e.body_size.y * 0.6)
	if drop.has("coins"):
		spawn_pickups("coin", int(drop["coins"]), at)
	if drop.has("jade"):
		spawn_pickups("jade", int(drop["jade"]), at)
	# 精英有一半几率掉记忆碎片
	if not e.is_grunt() and e.kind != "liu" and randf() < ELITE_MEMORY:
		grant_memory(Story.next_fragment(), at)
	for p in players:
		if p.is_alive() and float(p.stats["kill_heal"]) > 0.0:
			p.heal(p.max_hp * float(p.stats["kill_heal"]))
	# 装备：精英必掉，头目掉传说，杂兵偶尔掉
	var luck := int(Talents.run_value("luck"))
	var source := "boss" if e.kind == "liu" else ("elite" if not e.is_grunt() else "")
	var chance := 1.0 if source != "" else GEAR_DROP + float(Talents.run_value("gear_drop"))
	if randf() < chance:
		var item := GearData.roll(Game.run.rng, GearData.weights_for(source, Game.run.row, luck),
			"weapon" if source == "boss" else "")
		_drop_gear(item, Vector2(e.global_position.x, e.global_position.y if e.is_on_floor() else FLOOR_Y))


## 崩出一把铜钱/魂玉/伤药：最多 8 个，钱数平分到每个上。ground 是它们落在哪一层
func spawn_pickups(kind: String, amount: int, at: Vector2, ground: float = FLOOR_Y) -> void:
	var n := mini(amount, 8) if kind != "heal" else amount
	var left := amount
	for i in range(n):
		var pk := Pickup.new()
		pk.kind = kind
		pk.amount = left / (n - i) if kind != "heal" else 1
		left -= pk.amount
		pk.main = self
		pk.floor_y = ground
		pk.position = at
		pk.velocity = Vector2(randf_range(-110, 110), randf_range(-320, -180))
		fx_root.add_child(pk)


func collect(kind: String, amount: int, p: Player) -> void:
	if kind == "heal":
		var add := minf(p.max_hp * HEAL_PICKUP * amount, p.max_hp - p.hp)
		p.hp += add
		spawn_text(p.global_position + Vector2(0, -64), "+%d" % roundi(add), Color(0.5, 1.0, 0.55), 12)
		spawn_spark(p.global_position + Vector2(0, -30), Color(0.5, 1.0, 0.6), 8)
		return
	if Game.run == null:
		return
	var r := Game.run
	var mult := 1.0 + (float(p.stats["coin"]) if kind == "coin" else float(Talents.run_value("jade")))
	r.bank[kind] = float(r.bank[kind]) + amount * mult
	var whole := int(floor(float(r.bank[kind]) + 0.0001))
	r.bank[kind] = float(r.bank[kind]) - whole
	if kind == "coin":
		r.coins += whole
	else:
		r.jade += whole
		if whole > 0:
			spawn_text(p.global_position + Vector2(0, -64), "魂玉 +%d" % whole, Color(0.5, 1.0, 0.8), 12)
	hud.bump(kind)


# ---------- 互动：门、货、香炉、供台 ----------

## 双人闯关时倒下的人进入濒死（还有同伴站着才行；练武场照旧自动复活）
func can_be_downed(p: Player) -> bool:
	if mode != "room":
		return false
	for q in players:
		if q != p and q.is_alive():
			return true
	return false


## 濒死的同伴身边按住「下」：扶的那个人返回被扶的人
func _revive_target(p: Player) -> Player:
	if not p.is_alive() or p.frozen or p.state != Player.S.FREE or not p.is_on_floor():
		return null
	for q in players:
		if q != p and q.state == Player.S.DEAD and q.downed > 0.0 \
				and absf(q.global_position.x - p.global_position.x) < Player.REVIVE_RANGE \
				and absf(q.global_position.y - p.global_position.y) < 40.0:
			return q
	return null


func _update_revive(dt: float) -> void:
	var helped := {}
	for p in players:
		var q := _revive_target(p)
		if q == null or not Input.is_action_pressed(p.prefix + "down"):
			continue
		helped[q] = true
		q.revive_progress += dt
		if q.revive_progress >= Player.REVIVE_HOLD:
			q.revive(Player.REVIVE_HP)
	for q in players:
		if not helped.has(q):
			q.revive_progress = 0.0   # 松手就从头来


func _update_interact() -> void:
	focus_gear.clear()
	for it in interactables:
		it.highlight = false
	if _fade_dir != 0 or dead_wait:
		return
	for p in players:
		if not p.is_alive():
			continue
		var best: Interactable = null
		var best_d := Interactable.RANGE
		for it in interactables:
			if not it.visible:
				continue
			var d := absf(it.global_position.x - p.global_position.x)
			if it.kind == "gear" or (it.kind == "chest" and not it.enabled):
				d += -6.0 if it.kind == "gear" else 8.0   # 地上的装备优先，开过的宝箱让一让
			if d < best_d and absf(it.global_position.y - p.global_position.y) < 60.0:
				best_d = d
				best = it
		if best == null:
			continue
		best.highlight = true
		if best.kind == "gear":
			focus_gear[p.index] = best
		if menu_open() or _revive_target(p) != null:
			continue   # 站在濒死的同伴旁边，「下」是扶人
		if Input.is_action_just_pressed(p.prefix + "down") and p.state == Player.S.FREE and p.is_on_floor():
			interact(best, p)


func interact(it: Interactable, p: Player) -> void:
	var at := it.global_position + Vector2(0, -60)
	match it.kind:
		"door":
			if not it.enabled:
				spawn_text(at, "清完敌人才能走", Color(0.8, 0.75, 0.75), 12)
				return
			match String(it.data.get("action", "")):
				"start_run": _start_run()
				"next": _go_next(int(it.data["col"]))
				"victory": _finish_run(true)
		"item":
			if not it.enabled:
				return
			var id: String = it.data["id"]
			var spec: Dictionary = LevelData.SHOP_ITEMS[id]
			var cost := shop_price(int(spec["cost"]))
			if Game.run.coins < cost:
				spawn_text(at, "铜钱不够", Color(0.8, 0.75, 0.75), 12)
				return
			Game.run.coins -= cost
			_apply_item(id)
			(Game.run.stock() as Array).erase(id)
			it.enabled = false
			it.sub = "已买下"
			spawn_text(at, spec["desc"], Color(1.0, 0.9, 0.5), 12)
			spawn_spark(it.global_position + Vector2(0, -10), Color(1.0, 0.85, 0.4), 12)
			hud.bump("coin")
		"rest":
			if not it.enabled:
				return
			it.used = true
			it.enabled = false
			Game.run.rested[Game.run.room_id()] = true
			for q in players:
				q.hp = q.max_hp
				q.gourds = q.max_gourds
				q.posture = 0.0
				spawn_spark(q.global_position + Vector2(0, -30), Color(0.6, 0.85, 1.0), 14)
			spawn_text(at, "香火绵长 · 伤势痊愈", Color(0.7, 0.9, 1.0), 12)
			flash_screen(Color(0.5, 0.7, 1.0), 0.2)
		"chest":
			if not it.enabled:
				return
			it.used = true
			it.enabled = false
			var top := it.global_position + Vector2(0, -16)
			spawn_pickups("coin", loot_amount("coin", randi_range(8, 16)), top, it.global_position.y)
			if randf() < CHEST_GEAR and Game.run != null:
				var item := GearData.roll(Game.run.rng, GearData.weights_for("chest", Game.run.row, int(Talents.run_value("luck"))))
				_drop_gear(item, it.global_position + Vector2(18, 0))
			if randf() < 0.4:
				spawn_pickups("heal", 1, top, it.global_position.y)
			if randf() < 0.25:
				spawn_pickups("jade", randi_range(1, 2), top, it.global_position.y)
			spawn_spark(top, Color(1.0, 0.85, 0.4), 16)
			spawn_ring(top, Color(1.0, 0.85, 0.4), 24.0)
			shake(1.5)
		"note":
			var note: Array = LevelData.NOTES.get(it.data["id"], ["", "……"])
			hud.say(note[0], note[1], 5.0)
			if not it.used:
				it.used = true
				spawn_pickups("coin", 5, it.global_position + Vector2(8, -6), it.global_position.y)
		"talent":
			open_talents(p)
		"codex":
			open_codex(p)
		"event":
			if it.enabled:
				open_event(it, p)
			else:
				spawn_text(at, "已经选过了", Color(0.8, 0.75, 0.75), 12)
		"memory":
			open_memories(p)
		"rack":
			var list: Array = Game.save["weapons"]
			var i := list.find(Game.save["start_weapon"])
			Game.save["start_weapon"] = list[(i + 1) % list.size()]
			Game.write_save()
			_refresh_rack(it)
			if list.size() <= 1:
				spawn_text(at, "闯关时拿到别的武器，就会挂到架上", Color(0.85, 0.8, 0.75), 12)
			else:
				spawn_text(at, GearData.WEAPONS[Game.save["start_weapon"]]["name"], Color(1.0, 0.9, 0.6), 12)
				spawn_spark(it.global_position + Vector2(0, -30), Color(1.0, 0.85, 0.4), 8)
		"gear":
			_take_gear(it, p)


func _apply_item(id: String) -> void:
	var b: Dictionary = Game.run.buffs
	match id:
		"refill":
			for q in players:
				q.gourds = q.max_gourds
		"heal":
			for q in players:
				q.hp = minf(q.max_hp, q.hp + q.max_hp * 0.5)
		"whetstone": b["dmg"] = float(b["dmg"]) + 0.15
		"amulet": b["hp"] = float(b["hp"]) + 30.0
		"gourd": b["gourds"] = int(b["gourds"]) + 1
		"guard_charm": b["posture"] = float(b["posture"]) + 20.0
	for q in players:
		_apply_player_stats(q, false)


## 按装备、天赋和这一局的加成算玩家数值。refill 为 true 时回满
func _apply_player_stats(p: Player, refill: bool) -> void:
	var b: Dictionary = Game.run.buffs if Game.run != null and mode != "practice" else {}
	var old_max := p.max_hp
	var old_gourds := p.max_gourds
	var st := GearData.totals(p.gear)
	if mode != "practice":
		Talents.apply(st)
	Arts.apply_minds(st, p.build)
	st["atk"] = float(st["atk"]) + float(b.get("dmg", 0.0))
	st["hp"] = float(st["hp"]) + float(b.get("hp", 0.0))
	st["max_posture"] = float(st["max_posture"]) + float(b.get("posture", 0.0))
	st["gourds"] = int(st["gourds"]) + int(b.get("gourds", 0))
	p.apply_loadout(st)
	p.max_hp = 200.0 + float(st["hp"])
	p.max_gourds = Player.MAX_GOURDS + int(st["gourds"])
	p.max_posture = (100.0 + float(st["max_posture"])) * (1.0 + float(st["max_posture_pct"]))
	p.auto_respawn = mode == "practice"
	if refill:
		p.hp = p.max_hp
		p.gourds = p.max_gourds
	else:
		p.hp = minf(p.max_hp, p.hp + maxf(0.0, p.max_hp - old_max))
		p.gourds = mini(p.max_gourds, p.gourds + maxi(0, p.max_gourds - old_gourds))


# ---------- 装备：掉在地上、捡起来换上 ----------

## 地上放一件装备（Interactable，站上去按 下 换上）
func _add_gear(item: Dictionary, at: Vector2) -> Interactable:
	var it := _add_interactable("gear", at.x, GearData.display_name(item), _gear_icon(item), GearData.color(item), {"item": item})
	it.position = at
	it.sub = "%s · %s" % [GearData.quality(item)["name"], GearData.SLOT_NAMES[item["slot"]]]
	return it


func _gear_icon(item: Dictionary) -> String:
	return Icons.gear_icon(item)


## 敌人、宝箱掉出来的装备：带一道光柱落地
func _drop_gear(item: Dictionary, at: Vector2) -> Interactable:
	var it := _add_gear(item, Vector2(clampf(at.x, 30.0, arena_w - 30.0), at.y))
	it.time = 0.0
	var col := GearData.color(item)
	spawn_ring(it.global_position + Vector2(0, -12), col, 22.0 + int(item["q"]) * 6.0)
	spawn_spark(it.global_position + Vector2(0, -12), col, 8 + int(item["q"]) * 4)
	if int(item["q"]) >= 3:
		flash_screen(col, 0.15)
		spawn_text(it.global_position + Vector2(0, -50), GearData.quality(item)["name"], col, 14)
	return it


## 换上地上的装备，身上原来那件放回地上（商人的要先付钱）
func _take_gear(it: Interactable, p: Player) -> void:
	var item: Dictionary = it.data["item"]
	var at := it.global_position + Vector2(0, -60)
	var price := int(it.data.get("price", 0))
	if price > 0:
		if Game.run.coins < price:
			spawn_text(at, "铜钱不够", Color(0.8, 0.75, 0.75), 12)
			return
		Game.run.coins -= price
		var list: Array = Game.run.shop_gear_list()
		list[int(it.data["shop_index"])] = null
		hud.bump("coin")
	var slot := GearData.target_slot(p.gear, item)
	var old: Variant = p.gear[slot]
	p.gear[slot] = item
	interactables.erase(it)
	it.queue_free()
	if old != null:
		_add_gear(old, it.position)
	_apply_player_stats(p, false)
	var col := GearData.color(item)
	spawn_text(at, "换上 " + GearData.display_name(item), col, 12)
	spawn_spark(p.global_position + Vector2(0, -30), col, 12)
	if item["slot"] == "weapon" and Game.unlock_weapon(item["base"]):
		hud.toast("%s 挂上了破庙的兵器架" % GearData.WEAPONS[item["base"]]["name"])


## 商人的价格（行者“识货”打折）
func shop_price(cost: int) -> int:
	return maxi(1, roundi(cost * (1.0 - float(Talents.run_value("discount")))))


## 罐子、宝箱里的铜钱（行者“寻宝”加成）
func loot_amount(kind: String, n: int) -> int:
	if kind != "coin":
		return n
	return roundi(n * (1.0 + float(Talents.run_value("loot"))))


func death_keep() -> float:
	return LevelData.DEATH_KEEP + float(Talents.run_value("keep"))


# ---------- 拾骨婆的天赋界面 ----------

func open_talents(p: Player) -> void:
	menu_player = p
	for q in players:
		q.frozen = true
	hud.show_map = false


func close_talents() -> void:
	menu_player = null
	for q in players:
		q.frozen = false
		_apply_player_stats(q, true)


func _update_menu() -> void:
	var p := menu_player
	if not is_instance_valid(p):
		close_talents()
		return
	var c := menu_cursor
	var pr := p.prefix
	if Input.is_action_just_pressed(pr + "left"):
		c = _menu_step(c, -1)
	elif Input.is_action_just_pressed(pr + "right"):
		c = _menu_step(c, 1)
	elif Input.is_action_just_pressed(pr + "jump"):
		c.y = maxi(0, c.y - 1)
	elif Input.is_action_just_pressed(pr + "down"):
		c.y = mini(Talents.UNLOCK.size() - 1, c.y + 1)
	menu_cursor = c
	if Input.is_action_just_pressed(pr + "attack"):
		var why := Talents.why_not(c.x, c.y, c.z)
		if why == "":
			Talents.learn(c.x, c.y, c.z)
			hud.bump("jade")
			hud.menu_flash = 0.3
		else:
			hud.menu_note = why
			hud.menu_note_time = 1.4
	elif Input.is_action_just_pressed(pr + "heal"):
		var back := Talents.reset()
		hud.menu_note = "洗髓 · 退回魂玉 %d" % back
		hud.menu_note_time = 1.6
		hud.bump("jade")
	elif Input.is_action_just_pressed(pr + "guard") or Input.is_action_just_pressed(pr + "dodge"):
		close_talents()


## 左右移动光标：一棵树三个节点走完就跳到下一棵树
func _menu_step(c: Vector3i, d: int) -> Vector3i:
	var flat := c.x * 3 + c.z + d
	flat = posmod(flat, Talents.TREES.size() * 3)
	return Vector3i(flat / 3, c.y, flat % 3)


## 有界面开着（天赋、招式谱、奇遇、忆境、三选一）：这时候不能和别的东西互动
func menu_open() -> bool:
	return menu_player != null or codex_player != null or event_player != null or memory_player != null \
		or not rewards.is_empty()


# ---------- 奇遇 ----------

func open_event(it: Interactable, p: Player) -> void:
	event_player = p
	event_it = it
	event_cursor = 0
	for q in players:
		q.frozen = true
	hud.show_map = false
	hud.show_gear = false
	hud.show_build = false


func close_event() -> void:
	if event_player == null:
		return
	event_player = null
	event_it = null
	for q in players:
		_unfreeze(q)


func _update_event() -> void:
	var p := event_player
	if not is_instance_valid(p) or not is_instance_valid(event_it):
		close_event()
		return
	var opts: Array = Events.get_event(event_it.data["id"])["options"]
	var pr := p.prefix
	if Input.is_action_just_pressed(pr + "jump") or Input.is_action_just_pressed(pr + "left"):
		event_cursor = posmod(event_cursor - 1, opts.size())
	elif Input.is_action_just_pressed(pr + "down") or Input.is_action_just_pressed(pr + "right"):
		event_cursor = posmod(event_cursor + 1, opts.size())
	if Input.is_action_just_pressed(pr + "attack"):
		choose_event(event_cursor)
	elif Input.is_action_just_pressed(pr + "guard") or Input.is_action_just_pressed(pr + "dodge"):
		close_event()


## 选定奇遇的第 i 个选项：付代价、掷成败、拿收获
func choose_event(i: int) -> void:
	var p := event_player
	var it := event_it
	var ev := Events.get_event(it.data["id"])
	var opt: Dictionary = ev["options"][i]
	if opt.get("leave", false):
		close_event()
		return
	var why := Events.why_not(opt, p, Game.run)
	if why != "":
		hud.menu_note = why
		hud.menu_note_time = 1.4
		return
	close_event()
	it.used = true
	it.enabled = false
	Game.run.events_done[Game.run.room_id()] = true
	_pay_event(opt.get("cost", {}), p)
	var ok := true
	if opt.has("chance"):
		ok = Game.run.rng.randf() < float(opt["chance"])
	var who: String = ev.get("who", "")
	hud.say(who, String(opt.get("say", "")) if ok else String(opt.get("fail_say", "")), 3.5)
	_gain_event(opt.get("gain", {}) if ok else opt.get("fail", {}), p, it.global_position)


func _pay_event(cost: Dictionary, p: Player) -> void:
	var r := Game.run
	if cost.has("hp"):
		var lose := p.max_hp * float(cost["hp"])
		p.hp = maxf(1.0, p.hp - lose)
		p.flash(Color(1.0, 0.3, 0.3), 0.2)
		spawn_blood(p.global_position + Vector2(0, -28), float(p.facing), 10)
	if cost.has("max_hp"):
		r.buffs["hp"] = float(r.buffs["hp"]) - float(cost["max_hp"])
		_apply_player_stats(p, false)
		p.hp = minf(p.hp, p.max_hp)
	if cost.has("coins"):
		r.coins -= int(cost["coins"])
		hud.bump("coin")
	if cost.has("coins_half"):
		r.coins -= r.coins / 2
		hud.bump("coin")
	if cost.has("jade"):
		r.jade -= int(cost["jade"])
		hud.bump("jade")
	if cost.has("gourd"):
		p.gourds -= int(cost["gourd"])
	if cost.has("will"):
		p.will = 0.0


func _gain_event(g: Dictionary, p: Player, at: Vector2) -> void:
	var r := Game.run
	var top := at + Vector2(0, -40)
	if g.has("coins"):
		spawn_pickups("coin", int(g["coins"]), top)
	if g.has("jade"):
		spawn_pickups("jade", int(g["jade"]), top)
	if g.has("heal"):
		p.heal(p.max_hp * float(g["heal"]))
		spawn_spark(p.global_position + Vector2(0, -30), Color(0.5, 1.0, 0.6), 12)
	if g.has("gourds"):
		p.gourds = mini(p.max_gourds, p.gourds + int(g["gourds"]))
	if g.has("max_hp"):
		r.buffs["hp"] = float(r.buffs["hp"]) + float(g["max_hp"])
		_apply_player_stats(p, false)
	if g.has("gear"):
		_drop_gear(GearData.roll(r.rng, _only_quality(int(g["gear"]))), at + Vector2(30, 0))
	if g.has("memory"):
		grant_memory(Story.next_fragment(), top)
	if g.has("ambush"):
		_ambush(g["ambush"], p)
	if g.has("pick"):
		var kinds: Array = ["art", "mind", "up"] if g["pick"] == "any" else [g["pick"]]
		open_rewards("event", p, kinds, int(g.get("pick_lv", 1)))


## 只出某一个品质的权重表（GearData.roll 用）
func _only_quality(q: int) -> Array:
	var w := [0.0, 0.0, 0.0, 0.0, 0.0]
	w[clampi(q, 0, 4)] = 1.0
	return w


## 埋伏：敌人从玩家身边冒出来，门锁上，打完才开
func _ambush(spawns: Array, p: Player) -> void:
	waves = [[]]
	wave = 0
	cleared = false
	for it in interactables:
		if it.kind == "door":
			it.set_enabled(false)
	for s: Array in spawns:
		var x := clampf(p.global_position.x + float(s[1]), 40.0, arena_w - 40.0)
		var e := spawn_enemy(s[0], Vector2(x, FLOOR_Y))
		e.attack_cooldown = 1.2
		spawn_dust(e.global_position, 0.0, 10)
		spawn_ring(e.global_position + Vector2(0, -24), Color(1.0, 0.4, 0.3), 30.0)
	hud.toast("有埋伏！")
	shake(3.0)


## 拿到一片记忆：存档里记下，头上冒字
func grant_memory(id: String, at: Vector2) -> void:
	var got := Story.collect(id)
	if got.is_empty():
		return
	spawn_ring(at, Color(0.55, 0.85, 1.0), 34.0)
	spawn_spark(at, Color(0.55, 0.85, 1.0), 16)
	spawn_text(at + Vector2(0, -20), "记忆碎片", Color(0.6, 0.9, 1.0), 14)
	hud.toast("记忆碎片 · %s %d/%d（回破庙在忆境里看）" % got)
	flash_screen(Color(0.5, 0.8, 1.0), 0.15)


# ---------- 破庙的忆境 ----------

func open_memories(p: Player) -> void:
	memory_player = p
	memory_cursor = 0
	for q in players:
		q.frozen = true
	hud.show_gear = false
	hud.show_build = false


func close_memories() -> void:
	if memory_player == null:
		return
	memory_player = null
	for q in players:
		_unfreeze(q)


func _update_memories() -> void:
	var p := memory_player
	if not is_instance_valid(p):
		close_memories()
		return
	var n := Story.MEMORIES.size()
	var pr := p.prefix
	if Input.is_action_just_pressed(pr + "jump") or Input.is_action_just_pressed(pr + "left"):
		memory_cursor = posmod(memory_cursor - 1, n)
	elif Input.is_action_just_pressed(pr + "down") or Input.is_action_just_pressed(pr + "right"):
		memory_cursor = posmod(memory_cursor + 1, n)
	elif Input.is_action_just_pressed(pr + "guard") or Input.is_action_just_pressed(pr + "dodge") \
			or Input.is_action_just_pressed(pr + "attack"):
		close_memories()


# ---------- 破庙的招式谱 ----------

func open_codex(p: Player) -> void:
	codex_player = p
	for q in players:
		q.frozen = true
	hud.show_map = false
	hud.show_gear = false
	hud.show_build = false


func close_codex() -> void:
	if codex_player == null:
		return
	codex_player = null
	for q in players:
		_unfreeze(q)


## 招式谱一列：0 招式、1 心法
func codex_ids(col: int) -> Array:
	return Arts.ARTS.keys() if col == 0 else Arts.MINDS.keys()


func _update_codex() -> void:
	var p := codex_player
	if not is_instance_valid(p):
		close_codex()
		return
	var c := codex_cursor
	var pr := p.prefix
	if Input.is_action_just_pressed(pr + "left") or Input.is_action_just_pressed(pr + "right"):
		c.x = 1 - c.x
	elif Input.is_action_just_pressed(pr + "jump"):
		c.y -= 1
	elif Input.is_action_just_pressed(pr + "down"):
		c.y += 1
	c.y = posmod(c.y, codex_ids(c.x).size())
	codex_cursor = c
	if Input.is_action_just_pressed(pr + "attack"):
		var why := Arts.unlock("art" if c.x == 0 else "mind", codex_ids(c.x)[c.y])
		if why == "":
			hud.bump("jade")
			hud.menu_flash = 0.3
		else:
			hud.menu_note = why
			hud.menu_note_time = 1.4
	elif Input.is_action_just_pressed(pr + "guard") or Input.is_action_just_pressed(pr + "dodge"):
		close_codex()


## 玩家出手的判定框碰到罐子、木桶就砍碎
func _hit_breakables() -> void:
	for p in players:
		var r := Rect2()
		if p.state == Player.S.ATTACK and p.attack_phase == 1:
			r = p._attack_rect()
		elif p.state == Player.S.ART and p.art["run"] == "spin" and p.state_time >= float(p.art["windup"]):
			var size: Vector2 = p.art["size"]
			r = Rect2(p.global_position + Vector2(-size.x / 2.0, -size.y), size)
		else:
			continue
		for b: Variant in breakables:
			if is_instance_valid(b) and not b.broken and r.intersects(b.rect()):
				b.hit(p.global_position.x)
		if features != null:
			features.hit(r, p)
	breakables.assign(breakables.filter(func(b: Variant) -> bool: return is_instance_valid(b) and not b.broken))


## 这里是坑吗（敌人走到坑边会停下）
func is_gap(x: float) -> bool:
	return features != null and is_instance_valid(features) and features.in_pit(x)


## 后面几波敌人从玩家两边冲出来：离玩家 240-300，避开坑和关着的门
func _wave_x(want_left: bool, i: int) -> float:
	var px := camera.position.x
	var alive := get_players().filter(func(p: Player) -> bool: return p.is_alive())
	if not alive.is_empty():
		px = (alive[0] as Player).global_position.x
	for side in [want_left, not want_left]:
		var d := -1.0 if side else 1.0
		for k in range(8):
			var x := px + d * (250.0 + i * 22.0 + k * 30.0)
			if x < 30.0 or x > arena_w - 30.0:
				break
			if not is_gap(x) and not is_gap(x - 20.0) and not is_gap(x + 20.0) \
					and not (features != null and features.blocked_between(px, x)):
				return x
	return clampf(px + (-260.0 if want_left else 260.0), 30.0, arena_w - 30.0)


## 黑屏过渡：变黑 → 执行 → 变亮
func _fade_then(f: Callable) -> void:
	if _fade_dir != 0:
		return
	_fade_dir = 1
	_after_fade = f


func _update_fade(dt: float) -> void:
	if _fade_dir == 1:
		hud.fade = minf(1.0, hud.fade + dt * 3.5)
		if hud.fade >= 1.0:
			_fade_dir = -1
			Engine.time_scale = 1.0
			_hitstop_until = 0
			_slow_until = 0
			_after_fade.call()
	elif _fade_dir == -1:
		hud.fade = maxf(0.0, hud.fade - dt * 3.0)
		if hud.fade <= 0.0:
			_fade_dir = 0


# ---------- 练武场的遭遇 ----------

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
		# 闯关中途加入：站到 1P 旁边
		if mode != "practice" and not players.is_empty():
			p.position = players[0].global_position + Vector2(-24, -10)
	if Game.run != null and mode != "practice":
		p.gear = Game.run.loadout(index)
		p.build = Game.run.build(index)
		p.revives = int(Game.run.revives.get(index, 0))
	else:
		p.gear = GearData.empty_loadout(String(Game.save["start_weapon"]) if not Game.practice else "katana")
	world.add_child(p)
	players.append(p)
	_apply_player_stats(p, true)
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
	var s := Fx.Splat.new()
	s.position = pos
	s.dir = dir
	s.count = count
	s.power = clampf(count / 10.0, 0.5, 1.8)
	fx_root.add_child(s)
	var b := Fx.Particles.new()
	b.position = pos
	b.color = Color(0.75, 0.08, 0.1)
	b.count = count / 2
	b.dir = dir
	b.speed = Vector2(110, 90)
	b.gravity = 300.0
	b.life = 0.5
	fx_root.add_child(b)


## 命中闪光（见 Fx.Impact）
func spawn_impact(pos: Vector2, color: Color, size: float = 1.0, orb: bool = false, facing: int = 1) -> void:
	var f := Fx.Impact.new()
	f.position = pos
	f.color = color
	f.size = size
	f.orb = orb
	f.facing = facing
	fx_root.add_child(f)


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
	if menu_player != null:
		_update_menu()
	elif codex_player != null:
		_update_codex()
	elif event_player != null:
		_update_event()
	elif memory_player != null:
		_update_memories()
	if not rewards.is_empty():
		_update_rewards()
	if mode == "practice":
		_check_cleared(real_dt)
	elif mode == "room" and _fade_dir == 0:
		_update_room(real_dt)
		_update_revive(delta)
	_update_interact()
	_hit_breakables()
	_update_fade(real_dt)
	_flash.a = maxf(0.0, _flash.a - real_dt * 1.6)
	post.set_shader_parameter("flash", _flash)


func _update_camera(dt: float) -> void:
	# 跟着玩家走；附近正在打的敌人也算进来，把战斗框在画面里
	var sum := 0.0
	var n := 0
	var pmin := INF
	var pmax := -INF
	for p in players:
		if p.is_alive() or players.size() == 1:
			sum += p.global_position.x
			n += 1
			pmin = minf(pmin, p.global_position.x)
			pmax = maxf(pmax, p.global_position.x)
	if n > 0:
		var pc := sum / n
		for e in enemies:
			if e.visible and e.aggro and e.state != Enemy.S.DEAD and absf(e.global_position.x - pc) < 320.0:
				sum += e.global_position.x
				n += 1
	var target := sum / n if n > 0 else arena_w / 2.0
	if pmin < INF:
		# 玩家不能出画面
		target = clampf(target, pmax - VIEW_W / 2.0 + 70.0, maxf(pmax - VIEW_W / 2.0 + 70.0, pmin + VIEW_W / 2.0 - 70.0))
	target = clampf(target, VIEW_W / 2.0, maxf(VIEW_W / 2.0, arena_w - VIEW_W / 2.0))
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
	if menu_player != null:
		if event.is_action_pressed("toggle_map") or event.is_action_pressed("quit"):
			close_talents()
			get_viewport().set_input_as_handled()
		return
	if codex_player != null or event_player != null or memory_player != null:
		if event.is_action_pressed("toggle_map") or event.is_action_pressed("quit"):
			close_codex()
			close_event()
			close_memories()
			get_viewport().set_input_as_handled()
		return
	if not rewards.is_empty():
		return   # 三选一的时候别的键都不管
	if dead_wait:
		# 结算画面：任意一个人按攻击回破庙
		if event.is_action_pressed("p1_attack") or event.is_action_pressed("p2_attack"):
			dead_wait = false
			hud.hide_death()
			_finish_run(false)
		return
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
	elif event.is_action_pressed("toggle_map"):
		# Tab：闯关时 地图 → 装备 → 招式心法 → 关；破庙里没有地图
		if hud.show_map:
			hud.show_map = false
			hud.show_gear = true
		elif hud.show_gear:
			hud.show_gear = false
			hud.show_build = true
		elif hud.show_build:
			hud.show_build = false
		elif Game.run == null:
			hud.show_gear = true
		else:
			hud.show_map = true
	elif event.is_action_pressed("debug_jade") and mode == "hub":
		Game.save["jade"] = int(Game.save["jade"]) + 50
		Game.write_save()
		hud.bump("jade")
		hud.toast("调试：魂玉 +50")
	elif event.is_action_pressed("toggle_practice") and mode != "room":
		Game.practice = not Game.practice
		get_tree().reload_current_scene()
	elif event.is_action_pressed("reset") and mode == "practice":
		start_encounter(encounter)
		for p in players:
			p.respawn()
	elif event.is_action_pressed("quit"):
		get_tree().quit()
	if mode != "practice":
		return
	for i in range(EnemyData.ENCOUNTERS.size()):
		if event.is_action_pressed("encounter_%d" % (i + 1)):
			start_encounter(i)
			for p in players:
				p.respawn()
			hud.toast(str(EnemyData.ENCOUNTERS[i]["name"]))
