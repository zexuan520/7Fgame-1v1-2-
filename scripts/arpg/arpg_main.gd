class_name ArpgMain
extends Node3D
## 《残刃归途》斜俯视动作版的主场景。搭环境（卡通渲染、青绿雾、Bloom、后期）、镜头、特效、HUD，再跑一局的流程：
##   标题 → 山门（拾骨婆点天赋、兵器架换兵器、光门出发）→ 一层一层的分岔房间（战 / 精英 / 商人 / 歇脚 / 奇遇 / 头目）
##   → 清房三选一心法 → 光门选下一间 → 第一层头目「夜樱剑鬼」→ 第二层无名冢 → 头目「百骨将」→ 第三层古寺 → 头目「寂光」→ 结算（死了魂玉带回 60%）→ 山门。
##
## 命令行（-- 后面）：
##   --foes=archer,bomber 战斗房只刷这几种（测试新敌人）
##   --demo=fight 自动打（录视频用，主角不掉血）  --zone=temple 指定区域  --room=shop 直接进某种房间  --hub 直接进山门
##   --shot=路径 --shot_t=3,6 按时间拍图后退出（--nohud 不画界面）  --nowaves 不刷怪  --cam_dist/--cam_pitch/--cam_yaw 调镜头

const HUB_SIZE := Vector2(30, 22)
## 房间尺寸（米，x 宽 × z 深）：战斗房 / 商人土地庙之类的小房 / 头目
const ROOM_SIZE := Vector2(44, 32)
const SMALL_ROOM := Vector2(30, 22)
const BOSS_ROOM := Vector2(40, 30)
## 第二幕的地图板块再大一圈（地宫、灯冢、营地本来就该比山脚开阔；新小怪里有站远了打的、水底跟人的，得有地方跑）
const ACT2_ROOM := Vector2(52, 38)
const ACT2_SMALL := Vector2(34, 26)
const ACT2_BOSS := Vector2(46, 34)
## 第三幕：再大一圈
const ACT3_ROOM := Vector2(56, 40)
const ACT3_SMALL := Vector2(36, 28)
const ACT3_BOSS := Vector2(48, 36)

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
var _trial: ArpgTrial           # 试炼房：同一间房里四道试（疾 / 守 / 狂 / 乱）
var _extra_portals: Array[Node3D] = []   # 密室光门（和“前路”光门同时存在）
var side_rooms: Array[SideRoom] = []     # 这间房两侧墙外的侧室
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
var ach_toast: AchToast
var _run_t0 := 0.0             # 这一局出发时的 _clock（成就“一气呵成”）
var _first_intro := false     # 第一次玩：第一间房先说开场白
var _boss_retry := false       # 游历难度重打头目：不再放登场对话
var hints: ArpgHints
var secrets: ArpgSecrets        # 隐藏机制：散件开封门、秘境、山门闲聊、信物
var _room_hits0 := 0           # 进这间房时挨过几下（成就“片叶不沾身”“毫发无伤”）


func _ready() -> void:
	ArpgInput.setup()
	Foe.tokens = 0
	_rng.randomize()
	_parse_args()
	if _args.has("guide"):
		# 测试：当成新存档的第一局（逐步解锁、提示全没看过），--guidefights=N 当作已经打过几间战斗房
		Game.save["arpg_guide"] = "on"
		Game.save["arpg_unlocked"] = []
		Game.save["arpg_guide_fights"] = int(_args.get("guidefights", "0"))
		Game.save.erase("arpg_hints")
		Game.save.erase("arpg_hints_off")
	if _args.has("pad"):
		ArpgInput.pad_used[0] = true   # 测试：按键提示写成手柄的
	VoxelGrid.greedy = not _args.has("nogreedy")   # 测试：逐格画（对比合并面前后的三角形数）
	if _args.has("diff"):
		Game.save["arpg_diff"] = clampi(int(_args["diff"]), 0, 1)   # 测试：不写存档，只改这次
	if _args.has("cyclemax"):
		Game.save["arpg_cycle_max"] = clampi(int(_args["cyclemax"]), 0, ArpgCycle.MAX)   # 测试：开出轮回到第几级
		Game.save["arpg_cycle_told"] = _args.has("cycletold")
	if _args.has("talents"):
		_bench_talents(String(_args["talents"]))
	if _args.has("finaleopen"):
		Game.save["arpg_act3_endings"] = {"true": true}   # 测试：当成看过第三幕真结局（不写存档）
	if _args.has("storytest"):
		_story_test_save(String(_args["storytest"]))
	_setup_world()
	apply_quality(_initial_quality())
	if _args.has("perf") and get_node_or_null("PerfProbe") == null:
		var pp := PerfProbe.new()
		pp.name = "PerfProbe"
		add_child(pp)
	if _args.has("shot"):
		for t: String in String(_args.get("shot_t", "3.0")).split(","):
			_shots.append(float(t))
	if _args.has("demo") or _args.has("room") or _args.has("zone"):
		if _args.has("dailygo"):
			var dp := ArpgDaily.plan(ArpgDaily.today())
			ArpgState.pending = dp
			_start_run(false, int(dp["act"]))
			ArpgDaily.after_start(self, dp)
		else:
			_start_run(false, int(_args.get("act", "1")))
		for i in range(int(_args.get("floor", "0"))):
			state.run.next_floor()
			state.remap()
		var kind := String(_args.get("room", "fight"))
		if kind == "1":
			kind = "fight"
		if _args.has("finale"):
			state.flags["finale"] = true   # 测试：直接进无光殿（配 --room=boss --act=3 --floor=2）
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
	if _args.has("feeltest"):
		# 测试：--feeltest=mikiri|impact 在 --feel_t 秒（默认 4）时触发见切 / 冲击帧，配 --shot 拍图
		_feel_t = float(_args.get("feel_t", "4.0"))
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
	if _args.has("foelineup"):
		# 测试：新敌人站成一排不动（看模型、兵器、盾的位置）
		var ks := String(_args["foelineup"]).split(",")
		for i in range(ks.size()):
			var f: Foe = Act3Foe.new() if Act3Foe.TYPES3.has(ks[i]) else Foe.new()
			f.setup_kind(ks[i])
			add_child(f)
			f.global_position = hero.global_position + Vector3(-(ks.size() - 1) * 0.9 + i * 1.8, 0, -2.4)
			f.face_to(Vector3(0, 0, 1))
			f.set_physics_process(false)
			f.rig.scale = Vector3.ONE
			f.rig.visible = true
			var pz: Dictionary = f._aim_pose(1.0) if ks[i] in ["archer", "greyspear"] else Poses.idle(0.0)
			f._pose = pz
			f._apply_pose(1.0)
		hero.visible = false
	if _args.has("outro"):
		# 测试：直接当作头目已经打倒
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _room_cleared())
	if _args.has("boons") and state != null:
		# 测试：开局塞几个心法（看流派大成）
		for id: String in String(_args["boons"]).split(","):
			_take_boon(id)
	if _args.has("skills") and state != null:
		# 测试：开局点好技能分支，--skills=wave:3,thunder:2；--level=N 直接到第 N 重（多出的天赋点留着）
		for kv: String in String(_args["skills"]).split(","):
			var pr := kv.split(":")
			state.skills[pr[0]] = int(pr[1]) if pr.size() > 1 else 1
		hero.apply_stats(state.stats(), state.weapon)
	if _args.has("level") and state != null:
		var lv := int(_args["level"])
		state.points += lv - state.level
		state.level = lv
	if _args.has("skillmenu") and state != null:
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if _args["skillmenu"] == "1":
				_open_skills()
			else:
				_open_branch(int(_args["skillmenu"]), false))
	if _args.has("arms") and state != null:
		# 测试：--arms=主手,副手（兵器 id），品质看 --armsq=N
		var ws := String(_args["arms"]).split(",")
		var q := int(_args.get("armsq", 0))
		state.arms[0] = ArpgGear.weapon_item(ws[0], q)
		state.weapon = ws[0]
		if ws.size() > 1:
			state.arms[1] = ArpgGear.weapon_item(ws[1], q)
		hero.apply_stats(state.stats(), state.weapon)
	if _args.has("props") and state != null:
		# 测试：--props=fire_flask,thunder_talisman 塞道具（每种塞满）
		state.props.clear()
		for id: String in String(_args["props"]).split(","):
			state.add_item(id, 9)
	if _args.has("gearset") and state != null:
		# 测试：--gearset=thunder 穿上一整套
		for slot: String in ArpgData.GEAR_SLOTS:
			for g: Dictionary in ArpgData.gear_pool(slot):
				if String(g.get("set", "")) == String(_args["gearset"]) and (state.gear[slot] as Dictionary).is_empty():
					state.gear[slot] = {"slot": slot, "base": g["id"], "rarity": 2, "affixes": [], "name": "精·" + String(g["name"])}
		hero.apply_stats(state.stats(), state.weapon)
	if _args.has("skin") and is_instance_valid(hero):
		hero.apply_skin(String(_args["skin"]))   # 测试：只换这一次的皮肤，不写存档
	if _args.has("keys"):
		# 测试：--keys=swap@2.0,item@3.5,attack@4 在这些时刻按一下某个动作
		for pair: String in String(_args["keys"]).split(","):
			var aa := pair.split("@")
			get_tree().create_timer(float(aa[1])).timeout.connect(func() -> void:
				Input.action_press(ArpgInput.act(0, aa[0]))
				get_tree().create_timer(0.06).timeout.connect(func() -> void: Input.action_release(ArpgInput.act(0, aa[0]))))
	if _args.has("armsmenu"):
		get_tree().create_timer(1.5).timeout.connect(_arms_menu_test.bind(String(_args["armsmenu"])))
	if _args.has("givegear") and state != null:
		# 测试：往行囊里塞几件装备，过一会儿打开行囊
		for i in range(int(_args["givegear"])):
			state.bag.append(ArpgGear.roll(_rng, i % 3))
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _open_bag())
	if _args.get("touchtest", "") == "wheel":
		# 测试：按住「器」开道具轮盘，滑到第二个（拍轮盘截图）
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			var t := InputEventScreenTouch.new()
			t.index = 2
			t.pressed = true
			t.position = touch._item_center() * (Vector2(get_window().size) / get_viewport().get_visible_rect().size)
			Input.parse_input_event(t))
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			var d := InputEventScreenDrag.new()
			d.index = 2
			d.position = touch._wheel_slot(1, state.props.size()) * (Vector2(get_window().size) / get_viewport().get_visible_rect().size)
			Input.parse_input_event(d))
	elif _args.has("touchtest"):
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
	if _args.has("hero_at") and is_instance_valid(hero):
		var xz := String(_args["hero_at"]).split(",")
		_place_hero(Vector3(float(xz[0]), 0, float(xz[1])))
	if _args.has("dumptall"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			var tall := {}
			for n: Node in find_children("*", "VisualInstance3D", true, false):
				var vi := n as VisualInstance3D
				var ab := vi.global_transform * vi.get_aabb()
				if ab.end.y > 4.0:
					var key := "%s %s %s %s" % [vi.get_class(), (vi as MeshInstance3D).mesh.get_class() if vi is MeshInstance3D and (vi as MeshInstance3D).mesh else "", str(ab.end.y).pad_decimals(1), str(ab.get_center().snapped(Vector3.ONE))]
					tall[key] = int(tall.get(key, 0)) + 1
			print("TALL ", tall))
	if _args.has("pathtest") and state != null:
		# 测试：直接打开分岔路菜单（看路线图）
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			var ex := state.run.exits()
			while ex.size() < 2 and state.run.row < state.run.rows.size() - 2:
				state.run.advance(int(ex[0][0]))
				ex = state.run.exits()
			_choose_path(ex))
	if _args.has("runinfo") and state != null:
		get_tree().create_timer(1.2).timeout.connect(_open_run_info)
	if _args.has("storytest"):
		get_tree().create_timer(0.3 if _args["storytest"] == "shadow" else 1.5).timeout.connect(func() -> void: _story_test(String(_args["storytest"])))
	if _args.has("press"):
		# 测试：在这些时刻按一下攻击键（标题、菜单、对话框都认）
		for t: String in String(_args["press"]).split(","):
			# 不受慢镜头/世界停顿影响（标题画面一直压着 world_pause）
			get_tree().create_timer(float(t), true, false, true).timeout.connect(func() -> void:
				var ev := InputEventAction.new()
				ev.action = ArpgInput.act(0, "attack")
				ev.pressed = true
				Input.parse_input_event(ev)
				get_tree().create_timer(0.08, true, false, true).timeout.connect(func() -> void:
					var up := InputEventAction.new()
					up.action = ArpgInput.act(0, "attack")
					up.pressed = false
					Input.parse_input_event(up)))
	if _args.has("pause"):
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _open_pause())
	if _args.has("guidemenu"):
		# 测试：打开暂停菜单里的“新手提示”（--guidesel=N 选中第 N 项）
		get_tree().create_timer(1.5).timeout.connect(func() -> void: hints.open_menu(_close_menu, int(_args.get("guidesel", "0"))))
	if _args.has("statspanel"):
		# 测试：过一会儿打开属性面板（--statstab=N 第 N 页，--statsrow=M 选中第 M 行，--statsat=秒）
		get_tree().create_timer(float(_args.get("statsat", "1.5"))).timeout.connect(func() -> void:
			_open_stats(false, int(_args.get("statstab", "0")))
			if _args.has("statsrow") and _menu is ArpgStatsPanel:
				(_menu as ArpgStatsPanel).index = int(_args["statsrow"]))
	if _args.has("achtest"):
		# 测试：弹一个成就窗，再打开成就列表（拍图用）
		get_tree().create_timer(0.8).timeout.connect(func() -> void: ach_toast.push("四印俱全", "一间试炼房里拿齐疾、守、狂、乱四印"))
		if _args["achtest"] == "menu":
			get_tree().create_timer(1.2).timeout.connect(func() -> void: _open_achievements())
	if _args.has("cyclewin") and state != null:
		# 测试：进房两秒后直接算打通（看轮回结算、开下一级）
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			_game_over(true, "测试通关")
			print("CYCLE max=%d best=%s clear=%s jade=%d" % [ArpgCycle.unlocked(), str(Game.save.get("arpg_cycle_best")), str(Game.save.get("arpg_cycle_clear")), int(Game.save["jade"])]))
	if _args.has("cyclemenu"):
		# 测试：山门里打开轮回盘（配 --hub --cyclemax=N --cycletold）
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			for n: ArpgNpc in _npcs:
				if n.display.begins_with("轮回盘"):
					_open_cycle(n))
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


## 测试：--armsmenu=rack|skins|shop|pick|bag 打开兵器架、衣箱、游商、捡兵器、行囊
func _arms_menu_test(kind: String) -> void:
	match kind:
		"rack":
			_open_weapons(null)
		"skins":
			_open_skins(null)
		"shop":
			_open_shop(null)
		"pick":
			_gain_weapon(ArpgGear.weapon_item("hammer", 3, [["crit", 0.05]]))
		_:
			_open_bag()


var _feel_t := 0.0


func _feel_test() -> void:
	match String(_args["feeltest"]):
		"mikiri":
			var foes := get_tree().get_nodes_in_group("foes")
			if not foes.is_empty() and is_instance_valid(hero):
				hero._start_roll()
				hero.take_hit(HitInfo.make(foes[0], hero, 5.0))
		"impact":
			feel._impact_cd = 0.0
			feel.impact_frame(0.5)

func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"


# ---------- 画质 ----------
## 0 低：关阴影、辉光、后期，3D 画面按 70% 分辨率渲染；1 中：开辉光和后期，关阴影，85%；2 高：全开。
## 网页版第一次默认中，电脑版默认高；开打头 20 秒平均帧数太低会自动降一档（只降一次，记进设置）。
const QUALITY_NAMES := ["低", "中", "高"]
const LOW_EXPOSURE := 1.9
const LOW_AMBIENT := 1.8   # 低画质环境光倍数（补暗部提亮）
var _zone_info := {}
var _post_full: ShaderMaterial
var _post_lite: ShaderMaterial
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
	# 体素网格：低画质颜色分档粗一些、角色用半分辨率（之后新建的网格生效，缓存按档分开）
	VoxelGrid.quant = 24.0 if quality == 0 else 64.0
	VoxelModel.coarse = quality == 0
	vfx.lod = quality
	Arena.lod = quality
	sun.shadow_enabled = quality >= 2
	world_env.environment.glow_enabled = quality >= 1
	# 低画质不读屏幕贴图，换成轻量后期（闪屏、受伤泛红照样有）；
	# 没了辉光和暗部提亮，整体会暗一半，曝光补回来（手机默认低画质，评委多半看到的是这一档）
	post_rect.visible = true
	post_rect.material = _post_full if quality >= 1 else _post_lite
	feel.post = post_rect.material
	world_env.environment.tonemap_exposure = 1.05 if quality >= 1 else LOW_EXPOSURE
	if not _zone_info.is_empty():
		world_env.environment.ambient_light_energy = float(_zone_info["amb_e"]) * (1.0 if quality >= 1 else LOW_AMBIENT)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][quality]
	if TouchPad.active or TouchPad.want():
		# 手机屏幕像素密度高（画布按设备像素算），3D 再降一些也看不出来
		vp.scaling_3d_scale = [0.5, 0.65, 0.8][quality]
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality < 2 else Viewport.MSAA_2X


## 灯光上限：兼容渲染器里每盏点光都要在它照到的每个像素上多算一遍，手机吃不消。
## 低画质只留离主角最近的 10 盏（中 20 盏，高不限），每 0.25 秒挑一次；被自己代码关掉的灯不去碰。
const LIGHT_CAP := [10, 20, 0]
var _lb_t := 0.0


func _light_budget(dt: float) -> void:
	_lb_t -= dt
	if _lb_t > 0.0:
		return
	_lb_t = 0.25
	var cap: int = LIGHT_CAP[quality]
	var lights := get_tree().root.find_children("*", "OmniLight3D", true, false)
	if cap <= 0:
		# 调高画质以后把之前关掉的灯还回去
		for n: Node in lights:
			if n.has_meta("lb_off"):
				n.remove_meta("lb_off")
				(n as Light3D).visible = true
		return
	var focus := hero.global_position if is_instance_valid(hero) else (cam_rig.global_position if cam_rig != null else Vector3.ZERO)
	var cand := []
	for n: Node in lights:
		var l := n as OmniLight3D
		if not l.visible and not l.has_meta("lb_off"):
			continue
		if not l.is_inside_tree() or (l.get_parent() is Node3D and not (l.get_parent() as Node3D).is_visible_in_tree()):
			continue
		var d := l.global_position.distance_to(focus) - l.omni_range * 0.4
		if l.has_meta("lb_off"):
			d += 1.5   # 回差：已经关掉的灯要近一点才重新打开，免得来回闪
		cand.append([d, l])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in range(cand.size()):
		var l: OmniLight3D = cand[i][1]
		if i < cap:
			if l.has_meta("lb_off"):
				l.remove_meta("lb_off")
				l.visible = true
		elif l.visible:
			l.set_meta("lb_off", true)
			l.visible = false


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
	_post_full = pm
	_post_lite = ShaderMaterial.new()
	_post_lite.shader = load("res://shaders/arpg/post_lite.gdshader")
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
	# 成就弹窗：盖在菜单和对话框上面
	var ach_layer := CanvasLayer.new()
	ach_layer.layer = 10
	add_child(ach_layer)
	ach_toast = AchToast.new()
	ach_layer.add_child(ach_toast)
	ArpgAch.enabled = not _args.has("noach")
	ArpgAch.on_unlock = func(_id: String, n: String, d: String) -> void: ach_toast.push(n, d)
	ArpgAch.check_save(true)   # 旧存档里已经做到的，悄悄补上
	hints = ArpgHints.new()
	hints.main = self
	add_child(hints)
	secrets = ArpgSecrets.new()
	secrets.main = self
	add_child(secrets)


func _apply_zone_env(info: Dictionary) -> void:
	var env := world_env.environment
	env.background_color = info["bg"]
	env.ambient_light_color = info["amb"]
	_zone_info = info
	env.ambient_light_energy = float(info["amb_e"]) * (1.0 if quality >= 1 else LOW_AMBIENT)
	env.fog_light_color = info["fog"]
	env.fog_density = float(info["fog_d"]) * (state.omen_val("fog") if state != null and mode != "hub" else 1.0)
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
		if n is Loot or n is BossWave or n is TideRing or n is FirePool or n is Follower:
			n.queue_free()
	if is_instance_valid(_portal):
		_portal.queue_free()
	_portal = null
	for p: Node3D in _extra_portals:
		if is_instance_valid(p):
			p.queue_free()
	_extra_portals.clear()
	side_rooms.clear()
	for n: ArpgNpc in _npcs:
		if is_instance_valid(n):
			n.queue_free()
	_npcs.clear()
	hud.boss = null
	_going = false


func _build_arena(zone_id: String, seed_value: int, sz: Vector2, side_plans: Array = []) -> void:
	arena = Arena3.new() if Arena3.ZONES3.has(zone_id) else Arena.new()
	arena.doors = side_plans
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
	side_rooms.clear()
	for pl: Dictionary in side_plans:
		var sr := SideRoom.new()
		sr.main = self
		sr.arena = arena
		arena.add_child(sr)
		sr.build(pl)
		side_rooms.append(sr)
		# 镜头能跟进侧室
		var r := sr.rect
		var cr := Rect2(r.position.x + 4.0, r.position.y + 2.0, maxf(r.size.x - 8.0, 0.1), maxf(r.size.y - 6.0, 0.1))
		cam_rig.bounds = cam_rig.bounds.merge(cr)


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
	hero.link_fired.connect(_on_link)
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
		if not Game.save.has("arpg_diff"):
			_pick_difficulty(_after_title)
		else:
			_after_title())


## 标题之后：第一次玩直接上山开打（开场白在第一间房里说，按键在打的时候即时提示），以后回山门
func _after_title() -> void:
	Game.title_done = true
	feel.screen_flash(Color(0, 0, 0, 1), 0.0)
	# 发布在造化上：先等云存档回话（换了设备、清过缓存时用云端的进度），最多几秒
	if Game.cloud_pending:
		hud.visible = true
		hud.banner("读取存档", "正在同步云存档……", 4.0)
		Game.when_cloud_settled(_after_title_go)
		return
	_after_title_go()


func _after_title_go() -> void:
	# 上一局打到一半关掉了：问要不要接着打
	var ck := Game.load_checkpoint()
	if not ck.is_empty():
		_offer_resume(ck)
		return
	if not bool(Game.save.get("arpg_intro", false)) and int(Game.save.get("runs", 0)) == 0:
		Game.save["arpg_intro"] = true
		Game.write_save()
		_first_intro = true
		ArpgHints.begin_guide()   # 第一局逐步解锁招式
		_start_run()
		_enter_room()
		if _args.has("hintbot"):
			# 测试：新存档第一局交给机器人打（提示照常弹，没亮出来的招式机器人也不按）
			_bot = ArpgBot.new()
			_bot.hero = hero
			add_child(_bot)
			hero.invincible = not _args.has("mortal")
	else:
		_enter_hub()


## 选难度（第一次开始时，或暂停菜单里）
func _pick_difficulty(then: Callable) -> void:
	var items := []
	for i in range(2):
		items.append({"title": ArpgState.DIFF_NAMES[i], "desc": ArpgState.DIFF_DESC[i], "tag": "推荐" if i == 0 else "挑战",
			"color": Color(0.5, 1.0, 0.75) if i == 0 else Color(1.0, 0.45, 0.35), "glyph": ArpgState.DIFF_NAMES[i].substr(0, 1)})
	var m := _open_menu("选择难度", "之后可以在暂停菜单里改", items, "cards", false)
	m.index = ArpgState.difficulty()
	m.chosen.connect(func(i: int) -> void:
		Game.save["arpg_diff"] = i
		Game.write_save()
		_close_menu()
		if state != null and is_instance_valid(hero):
			hero.apply_stats(state.stats(), state.weapon)
		then.call())


# ---------- 山门（局外：天赋、兵器、出发） ----------

var _hag_tag := 0   # 拾骨婆天赋标语这次用哪一句，每回山门换一句


func _enter_hub() -> void:
	mode = "hub"
	Game.clear_checkpoint()   # 回到山门，这一局就结束了
	_hag_tag = randi() % ArpgStory.HAG_TAGS.size()
	state = null
	_clear_scene()
	_build_arena("forest", 4242, HUB_SIZE)
	_ensure_hero()
	hero.reset_for_run()
	hero.kit = null
	_hub_stats()
	_place_hero(arena.entry_pos)
	hud.visible = true
	hud.zone_name = "山门 · 拾骨婆的小院"
	hud.wave_text = "局外：点天赋、换兵器，走进光门出发"
	hud.coins = 0
	hud.jade = int(Game.save["jade"])
	hud.banner("山门", "魂玉 %d　·　出发 %d 次　·　登顶 %d 次" % [int(Game.save["jade"]), int(Game.save.get("runs", 0)), int(Game.save.get("clears", 0))], 2.6)
	if Game.save_notice != "":
		var note := Game.save_notice
		Game.save_notice = ""
		_show_save_notice(note, 2.8)
	feel.screen_flash(Color(0, 0, 0, 1), 1.4)
	Game.music("hub")
	var hz := HUB_SIZE.y * 0.5
	_npc("拾骨婆 · 天赋", Vector3(-4.0, 0, 1.0), {"model": "skel_mage", "weapon": "skel_staff", "tint": Color(1.1, 0.95, 0.8)}, _open_talents)
	_npc("兵器架", Vector3(4.0, 0, 1.0), {"kit": "sword_shield", "scale": 1.3}, _open_weapons)
	_npc("衣箱 · 皮肤", Vector3(-6.5, 0, 4.0), {"kit": "crates", "scale": 0.9}, _open_skins)
	_make_portal(Vector3(0, 0, -hz + 2.5), "run", Color(1.0, 0.8, 0.45))
	_npc("试刀 · 教学", Vector3(-4.5, 0, -3.5), {"kit": "sword_shield", "scale": 1.1}, func(_n: ArpgNpc) -> void: _start_tutorial())
	_npc("功业碑 · 成就 %d / %d" % [ArpgAch.count(), ArpgAch.LIST.size()], Vector3(4.5, 0, -3.5), {"kit": "shrine", "scale": 1.1}, func(_n: ArpgNpc) -> void: _open_achievements())
	# 轮回盘：打通过一次以后出现在光门左边，选这次出发的轮回级（通关后的加难）
	if ArpgCycle.unlocked() > 0:
		var cp := Vector3(-3.6, 0, -hz + 3.4)
		_npc(_cycle_npc_name(), cp, {"kit": "candles", "scale": 1.4}, _open_cycle)
		arena.spirit_fire(cp + Vector3(0, 0.9, 0), Color(0.75, 0.5, 1.0), 1.0, 1.8, 6.0)
	# 支线：无名碑（拿到守墓人的名单后立起来）、阿樱的风筝（凑齐三件后飘在山门上空）
	if ArpgStory.has_name_list():
		_npc("无名碑 %d / %d" % [ArpgStory.names().size(), ArpgStory.NAMES.size()], Vector3(-8.5, 0, -0.5), {"kit": "gravestone", "scale": 1.4}, _read_names)
	if ArpgStory.kite() >= ArpgStory.KITE.size():
		_hub_kite(Vector3(5.0, 0, 5.5))
	# 残页石：看已经找到的寂光残页（隐藏剧情）
	if not ArpgStory.pages().is_empty():
		_npc("残页 %d / %d" % [ArpgStory.pages().size(), ArpgStory.PAGES.size()], Vector3(0, 0, 2.5), {"kit": "gravestone", "scale": 1.2}, _read_pages)
	# 第二幕：第一幕任一结局后，山门右后方的古井冒青光，走进去就是“入井”
	if act2_open():
		var wp := Vector3(9.0, 0, -6.5)
		arena.kit("well", wp + Vector3(1.8, 0, -1.2), 0.0, 1.1, true)
		arena.spirit_fire(wp + Vector3(1.8, 1.0, -1.2), Color(0.45, 0.85, 1.0), 1.4, 2.2, 7.0)
		_make_secret_portal(wp, "act2", Color(0.45, 0.8, 1.0))
	# 第二幕的支线人物：刀匠（第二幕走过一次后来）、地藏（头放回去以后）
	if int(Game.save.get("arpg_act2_runs", 0)) > 0:
		_npc("老刀匠 · 刀镡已成" if ArpgStory.smith_done() else "老刀匠 %d / %d" % [ArpgStory.smith_items().size(), ArpgStory.SMITH_ITEMS.size()], Vector3(9.0, 0, 2.5), {"model": "barbarian", "tint": Color(1.05, 0.8, 0.6)}, _talk_smith)
		_npc("守灯僧 · 换物" if String(Game.save.get("arpg_monk_buy", "")) == "" else "守灯僧 · 已换过", Vector3(9.5, 0, -2.0), {"model": "mage", "tint": Color(0.8, 0.95, 0.8)}, _talk_monk)
	# 第三幕：第二幕任一结局后，山门左边下山的路口出现“出山”光门；阿禾、七村名录碑
	Act3.hub(self)
	ArpgDaily.hub(self)   # 每日挑战、种子局的告示牌（光门右边）
	if bool(Game.save.get("arpg_jizo_home", false)):
		_npc("地藏 · 求保佑" if String(Game.save.get("arpg_bless", "")) == "" else "地藏 · 已求过", Vector3(-9.0, 0, 3.5), {"kit": "shrine", "scale": 1.1}, _pray_jizo)
	# 隐藏机制：信物匣、阿七（闲聊、信物，见 ArpgSecrets）
	secrets.hub_entered()
	hints.hub_entered()   # 第一局的逐步解锁到此结束；第一次回来提示山门是做什么的
	# 第一次进山门：拾骨婆说开场白
	if not bool(Game.save.get("arpg_intro", false)) and not _args.has("demo"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_intro"] = true
			Game.write_save()
			_say(ArpgStory.INTRO))
	# 第一次打通：拾骨婆讲轮回（光门左边亮起轮回盘）
	elif ArpgCycle.unlocked() > 0 and not bool(Game.save.get("arpg_cycle_told", false)) and not _args.has("demo"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_cycle_told"] = true
			Game.write_save()
			_say(CYCLE_TALK))
	# 第二幕 · 拾骨婆的身世：看过灯冢的壁画、又在井底对枯荣做过选择，回山门时她自己说出来（一次）
	elif ArpgStory.hag_reveal_ready() and not _args.has("demo"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_hag_told"] = true
			Game.write_save()
			var hl: Array = ArpgStory.HAG_REVEAL.duplicate()
			if bool(Game.save.get("arpg_shard", false)):
				hl.append_array(ArpgStory.HAG_REVEAL_SHARD)
			ArpgAch.unlock("hag_truth")
			_say(hl))
	# 终章的伏笔：看过第三幕真结局，回来时拾骨婆说山底下还有东西在跳（一次）
	elif Finale.hint_ready() and not _args.has("demo"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_finale_told"] = true
			Game.write_save()
			_say(Finale.HINT))
	# 拾骨婆的碎念：死得够多了，回来时她多说一句自己的事（隐藏剧情）
	elif ArpgStory.next_mutter() >= 0 and not _args.has("demo"):
		var mi := ArpgStory.next_mutter()
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if mode != "hub":
				return
			Game.save["arpg_mutter"] = mi + 1
			Game.write_save()
			var ml := [["", "拾骨婆把魂玉一颗一颗数进你手里，嘴里念叨着。" if mi == 0 else "拾骨婆数着魂玉，又念叨起来。"],
				["拾骨婆", ArpgStory.MUTTERS[mi], ArpgStory.C_HAG]]
			if mi == ArpgStory.MUTTERS.size() - 1:
				ml.append(["", "她说完，像什么都没说过一样，接着数。"])
			_say(ml))


## 存档出过状况（从备份恢复等）：等对话、菜单都关了再在山门横幅提示
func _show_save_notice(note: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if mode != "hub":
			return
		if _menu != null or not _no_dialog():
			_show_save_notice(note, 1.0)
			return
		hud.banner("存档", note, 5.0))


## 拾骨婆第一次讲轮回
const CYCLE_TALK := [
	["拾骨婆", "走通了？……走通了也还得回来。灯没灭，山就还在，人就还得一遍一遍地上。", ArpgStory.C_HAG],
	["拾骨婆", "光门左边那盏灯盘，叫轮回盘。点一盏，山就凶一分：骨头更硬，刀子更快，还有身上带着怨的。", ArpgStory.C_HAG],
	["拾骨婆", "凶一分，魂玉也厚一分。你在哪一级走通了，下一级就给你点上。", ArpgStory.C_HAG],
	["", "（轮回盘：选这次出发的轮回级。级数叠加：轮回三包含一、二、三的规矩。每一级第一次打通还有一笔魂玉）"],
]


func _cycle_npc_name() -> String:
	return "轮回盘 · %s" % ArpgCycle.label(ArpgCycle.picked())


## 轮回盘：选出发的轮回级（0 本相 ~ 已开出的最高级），下面列每一级加的规矩和两幕的通关记录
func _open_cycle(n: ArpgNpc, keep_index: int = -1) -> void:
	var items := []
	var top := mini(ArpgCycle.unlocked() + 1, ArpgCycle.MAX)
	var cur := ArpgCycle.picked()
	for lv in range(top + 1):
		var open := lv <= ArpgCycle.unlocked()
		var rec := []
		for a in [1, 2, 3]:
			if a == 3 and ArpgState.ACT_NAMES.size() < 3:
				continue
			if ArpgCycle.best(a) >= lv:
				rec.append("%s幕已过" % ArpgState.CN_NUM[a - 1])
		var desc := String(ArpgCycle.RULES[lv][1])
		var title := ArpgCycle.label(lv)
		if lv > 0:
			title += "「%s」　敌人 +%d%%　魂玉 +%d%%" % [ArpgCycle.RULES[lv][0], int(round(ArpgCycle.HP_PER * lv * 100.0)), int(round(ArpgCycle.JADE_PER * lv * 100.0))]
			if not ArpgCycle.cleared(1, lv) or not ArpgCycle.cleared(2, lv) or not ArpgCycle.cleared(3, lv):
				desc += "（首通 +%d 魂玉）" % ArpgCycle.first_clear_jade(lv)
		if not open:
			desc = "在%s打通任一幕后开出：%s" % [ArpgCycle.label(lv - 1), desc]
		items.append({"title": title, "desc": desc,
			"right": "当前" if lv == cur else (" · ".join(rec) if not rec.is_empty() else ("" if open else "未开")),
			"enabled": open,
			"color": Color(0.85, 0.6, 1.0) if lv == cur else Color(0.95, 0.92, 0.85)})
	var m := _open_menu("轮回盘", "级数叠加：选轮回三，一到三的规矩全都生效。　已开出 %s" % ArpgCycle.label(ArpgCycle.unlocked()), items, "list", true)
	m.index = keep_index if keep_index >= 0 else cur
	m.chosen.connect(func(i: int) -> void:
		ArpgCycle.pick(i)
		Game.sfx("coin")
		n.display = _cycle_npc_name()
		if is_instance_valid(_portal):
			for c: Node in _portal.get_children():
				if c is Label3D:
					(c as Label3D).text = "出发" + ("" if i == 0 else " · " + ArpgCycle.label(i))
		for sp: Node3D in _extra_portals:
			var sk := String(sp.get_meta("kind", "")) if is_instance_valid(sp) else ""
			if sk == "act2" or sk == "act3":
				for c: Node in sp.get_children():
					if c is Label3D:
						(c as Label3D).text = ("入井 · 第二幕" if sk == "act2" else "出山 · 第三幕") + ("" if i == 0 else " · " + ArpgCycle.label(i))
		feel.callout(hero.head_top(), ArpgCycle.label(i), Color(0.85, 0.6, 1.0), 1.1)
		_close_menu()
		_open_cycle(n, i))


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
	# 第一项：闲聊（每回山门说一段新的，藏着提示和信物，见 ArpgSecrets）
	items.append({"tag": "闲聊", "tag_color": ArpgStory.C_HAG, "title": "闲聊",
		"desc": "听拾骨婆念叨几句" if secrets.can_chat("hag") else "今天已经说过了……再问问？",
		"right": "新" if secrets.can_chat("hag") and secrets._chat_i("hag") >= 0 else "", "enabled": true, "color": ArpgStory.C_HAG})
	refs.append(["", 0])
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
	var m := _open_menu("拾骨婆 · 天赋", "%s　　魂玉 %d" % [ArpgStory.HAG_TAGS[_hag_tag], int(Game.save["jade"])], items, "list", true)
	if keep_index >= 0:
		m.index = keep_index
	m.chosen.connect(func(i: int) -> void:
		var id: String = refs[i][0]
		if id == "":
			_close_menu()
			secrets.chat("hag")
			return
		var cost: int = ArpgData.TALENT_COSTS[refs[i][1]]
		Game.save["jade"] = int(Game.save["jade"]) - cost
		var tal: Dictionary = Game.save["talents"]
		tal[id] = int(tal.get(id, 0)) + 1
		Game.write_save()
		_hub_stats()
		hud.jade = int(Game.save["jade"])
		vfx.shock_ring(hero.global_position, Color(1.0, 0.85, 0.45), 0.3, 3.0, 0.4)
		_close_menu()
		_open_talents(_n, i))


func _read_pages(_n: ArpgNpc) -> void:
	var lines := [["", "你找到了寂光写下的几页残页。"]]
	for i: int in ArpgStory.pages():
		lines.append(["寂光的残页 · 其%s" % ["一", "二", "三", "四", "五"][i], ArpgStory.PAGES[i], ArpgStory.C_MASTER])
	if bool(Game.save.get("arpg_page6", false)):
		lines.append(["寂光的残页 · 其六", ArpgStory.PAGE6, ArpgStory.C_MASTER])
	if ArpgStory.has_all_pages():
		lines.append(["", "五页都齐了。打倒寂光之后，也许能换一个结局。"])
	_say(lines)


func _read_names(_n: ArpgNpc) -> void:
	var got := ArpgStory.names()
	var lines := [["", "守墓人的名单。认回来的名字，你一个一个刻在了碑上。"]]
	for i: int in got:
		lines.append([String(ArpgStory.NAMES[i][0]), String(ArpgStory.NAMES[i][1]), ArpgStory.C_KEEPER])
	if ArpgStory.names_done():
		lines.append(["", "碑的最下面空着一行。名单上的第十三个名字，你还没刻上去：残刃。"])
	else:
		lines.append(["", "（还差 %d 个。名牌在幽林、无名冢的遗骸侧室里）" % (ArpgStory.NAMES.size() - got.size())])
	_say(lines)


## 阿樱的风筝：山门上空一只纸鸢，一根线拴在地上的木桩上，跟着风慢慢晃
func _hub_kite(base: Vector3) -> void:
	var root := Node3D.new()
	arena.add_child(root)
	root.global_position = base
	var post := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.18, 0.7, 0.18)
	post.mesh = pb
	post.position.y = 0.35
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.32, 0.22)
	post.material_override = pm
	root.add_child(post)
	var kite := Node3D.new()
	kite.position = Vector3(1.0, 3.4, 0.6)
	root.add_child(kite)
	# 体素风筝：菱形纸面（粉）+ 十字竹骨（深色）+ 一串红布尾巴
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.16
	var mats := {}
	for key: String in ["paper", "spar", "tail"]:
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.albedo_color = {"paper": Color(1.0, 0.62, 0.72) * 1.15, "spar": Color(0.45, 0.25, 0.2), "tail": Color(1.0, 0.3, 0.3) * 1.2}[key]
		mats[key] = mm
	var face := Node3D.new()
	face.rotation = Vector3(-0.6, 0.0, 0.0)
	kite.add_child(face)
	for x in range(-3, 4):
		for y in range(-4, 4):
			if absi(x) + absi(y if y >= 0 else y + 1) > 3:
				continue
			var c := MeshInstance3D.new()
			c.mesh = cube
			c.position = Vector3(x, y, 0) * 0.16
			c.material_override = mats["spar" if x == 0 or y == 1 else "paper"]
			face.add_child(c)
	for i in range(5):
		var t := MeshInstance3D.new()
		t.mesh = cube
		t.scale = Vector3.ONE * 0.7
		t.position = Vector3(sin(i * 1.3) * 0.12, -0.75 - i * 0.2, 0)
		t.material_override = mats["tail"] if i % 2 == 0 else mats["paper"]
		face.add_child(t)
	# 线：从木桩顶拉到风筝
	var line := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(Vector3(0, 0.7, 0))
	im.surface_add_vertex(kite.position)
	im.surface_end()
	line.mesh = im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.9, 0.8)
	line.material_override = lm
	root.add_child(line)
	var tw := kite.create_tween().set_loops()
	tw.tween_property(kite, "rotation:z", 0.25, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(kite, "rotation:z", -0.25, 1.8).set_trans(Tween.TRANS_SINE)
	var lb := Label3D.new()
	lb.text = "阿樱的风筝"
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 40
	lb.pixel_size = 0.01
	lb.modulate = ArpgStory.C_SAKURA
	lb.position = Vector3(0, 1.3, 0)
	root.add_child(lb)


func _open_weapons(_n: ArpgNpc, keep_index: int = -1) -> void:
	var owned: Array = Game.save.get("arpg_weapons", ["sword"])
	var cur := String(Game.save.get("arpg_weapon", "sword"))
	var spare := bool(Game.save.get("arpg_spare", false))
	var cur2 := String(Game.save.get("arpg_weapon2", ""))
	var jade := int(Game.save["jade"])
	var items := []
	var acts := []
	for id: String in ArpgData.WEAPONS:
		var w: Dictionary = ArpgData.WEAPONS[id]
		var have := owned.has(id)
		var right := "主手" if id == cur else ("副手" if spare and id == cur2 else ("换上" if have else "%d 魂玉" % int(w["price"])))
		items.append({"title": w["name"], "desc": String(w["style"]) + "　" + String(w["trait"]), "right": right,
			"enabled": id != cur and (have or jade >= int(w["price"])), "tag": "兵器", "color": ArpgArms.trail(id)[1].lerp(Color(0.95, 0.92, 0.85), 0.5)})
		acts.append(["main", id])
	# 备刃：出发时副手带第二把；双佩：第二个护符槽
	if not spare:
		items.append({"tag": "解锁", "tag_color": Color(1.0, 0.8, 0.4), "title": "备刃", "desc": "出发时副手多带一把兵器（局内按 %s 换手，贴身换手打出换刃斩）" % ArpgInput.key_name(0, "swap"),
			"right": "%d 魂玉" % SPARE_PRICE, "enabled": jade >= SPARE_PRICE})
		acts.append(["spare", ""])
	else:
		for id: String in ArpgData.WEAPONS:
			if owned.has(id) and id != cur and id != cur2:
				items.append({"tag": "副手", "tag_color": ArpgMenu.TEAL, "title": "副手换成 " + String(ArpgData.WEAPONS[id]["name"]), "desc": String(ArpgData.WEAPONS[id]["trait"]), "right": "带上"})
				acts.append(["off", id])
	if not ArpgState.charm2_open():
		items.append({"tag": "解锁", "tag_color": Color(1.0, 0.8, 0.4), "title": "双佩", "desc": "多一个护符槽，可以同时戴两件护符", "right": "%d 魂玉" % CHARM2_PRICE, "enabled": jade >= CHARM2_PRICE})
		acts.append(["charm2", ""])
	var sub := "换兵器就换了一整套连招。没有的用魂玉买，局里捡到的兵器也会挂上来。　　魂玉 %d" % jade
	var m := _open_menu("兵器架", sub, items, "list", true)
	if keep_index >= 0:
		m.index = mini(keep_index, items.size() - 1)
	m.chosen.connect(func(i: int) -> void:
		var a: Array = acts[i]
		var id := String(a[1])
		match String(a[0]):
			"main":
				if not owned.has(id):
					Game.save["jade"] = int(Game.save["jade"]) - int(ArpgData.WEAPONS[id]["price"])
					owned.append(id)
					Game.save["arpg_weapons"] = owned
				Game.save["arpg_weapon"] = id
				if String(Game.save.get("arpg_weapon2", "")) == id:
					Game.save["arpg_weapon2"] = cur
				feel.callout(hero.head_top(), String(ArpgData.WEAPONS[id]["name"]), Color(1.0, 0.85, 0.45), 1.1)
			"off":
				Game.save["arpg_weapon2"] = id
				feel.callout(hero.head_top(), "副手：" + String(ArpgData.WEAPONS[id]["name"]), ArpgMenu.TEAL, 1.1)
			"spare":
				Game.save["jade"] = int(Game.save["jade"]) - SPARE_PRICE
				Game.save["arpg_spare"] = true
				feel.callout(hero.head_top(), "备刃", Color(1.0, 0.85, 0.45), 1.1)
			"charm2":
				Game.save["jade"] = int(Game.save["jade"]) - CHARM2_PRICE
				Game.save["arpg_charm2"] = true
				feel.callout(hero.head_top(), "双佩", Color(1.0, 0.85, 0.45), 1.1)
		Game.write_save()
		ArpgAch.check_save()
		_hub_stats()
		hud.jade = int(Game.save["jade"])
		_close_menu()
		_open_weapons(_n, i))


const SPARE_PRICE := 30
const CHARM2_PRICE := 50


## 山门衣箱：换皮肤（只是外观）。魂玉买的买下永久留着，其余按成就、通关、斩敌数解锁
func _open_skins(_n: ArpgNpc, keep_index: int = -1) -> void:
	var cur := String(Game.save.get("arpg_skin", "qing"))
	var jade := int(Game.save["jade"])
	var items := []
	for sk: Dictionary in ArpgArms.SKINS:
		var id := String(sk["id"])
		var why := ArpgArms.skin_why_not(id)
		var u: Dictionary = sk["unlock"]
		var buy := u.has("jade") and why != ""
		var right := "穿着" if id == cur else ("换上" if why == "" else why)
		items.append({"title": sk["name"], "desc": sk["desc"], "right": right, "tag": "皮肤", "tag_color": sk.get("rim", ArpgMenu.TEAL),
			"enabled": id != cur and (why == "" or (buy and jade >= int(u["jade"]))), "color": (sk.get("rim", Color.WHITE) as Color).lerp(Color(0.95, 0.92, 0.85), 0.55)})
	var m := _open_menu("衣箱 · 皮肤", "只换样子，不改数值。　　魂玉 %d" % jade, items, "list", true)
	if keep_index >= 0:
		m.index = keep_index
	m.chosen.connect(func(i: int) -> void:
		var sk: Dictionary = ArpgArms.SKINS[i]
		var id := String(sk["id"])
		var u: Dictionary = sk["unlock"]
		if u.has("jade") and not ArpgArms.skin_owned(id):
			Game.save["jade"] = int(Game.save["jade"]) - int(u["jade"])
			var own: Array = Game.save.get("arpg_skins", [])
			own.append(id)
			Game.save["arpg_skins"] = own
		Game.save["arpg_skin"] = id
		Game.write_save()
		hero.apply_skin(id)
		_hub_stats()
		ArpgAch.unlock("skin_any")
		vfx.shock_ring(hero.global_position, sk.get("rim", Color.WHITE), 0.3, 3.0, 0.4)
		vfx.ghost(hero.rig, sk.get("rim", Color.WHITE), 0.4)
		hud.jade = int(Game.save["jade"])
		Game.sfx("reward", -4.0)
		_close_menu()
		_open_skins(_n, i))


# ---------- 一局 ----------

func _start_run(fresh_hero: bool = true, act: int = 1) -> void:
	_pending_weapons.clear()
	state = ArpgState.start_new(act)
	if act == 2:
		# 第一幕的选择带进第二幕：flags 里加 a1_ 前缀的旗标（剧情遭遇、头目对白用）
		for g: String in ArpgState.ACT1_GROUPS:
			var f := ArpgState.act1(g)
			if f != "":
				state.flags["a1_" + f] = true
		if String(Game.save.get("arpg_last_end", "")) == "keep":
			state.flags["lantern_carry"] = true
		Game.save["arpg_act2_runs"] = int(Game.save.get("arpg_act2_runs", 0)) + 1
		Game.write_save()
		ArpgAch.unlock("act2")
	elif act == 3:
		Act3.start_run(self)
	if fresh_hero or not is_instance_valid(hero):
		_ensure_hero()
	hero.reset_for_run()
	# 地藏的保佑（山门求的，出发时生效一次）
	var bl := String(Game.save.get("arpg_bless", ""))
	if bl != "" and act >= 1:
		Game.save.erase("arpg_bless")
		Game.write_save()
		for b: Array in ArpgStory.JIZO_BLESS:
			if b[0] == bl:
				var fx: Dictionary = b[2]
				if fx.has("boon_id"):
					state.boons.append(String(fx["boon_id"]))
				if fx.has("coins"):
					state.coins += int(fx["coins"])
				state.flags["blessed"] = bl
	# 守灯僧那儿换的东西（出发时生效一次）
	var mb := String(Game.save.get("arpg_monk_buy", ""))
	if mb != "":
		Game.save.erase("arpg_monk_buy")
		Game.write_save()
		for w: Array in ArpgStory.MONK_WARES:
			if w[0] == mb:
				var fx2: Dictionary = w[3]
				if fx2.has("boon_id"):
					state.boons.append(String(fx2["boon_id"]))
				if fx2.has("boon_rand"):
					var rb := state.roll_boons(1, _rng)
					if not rb.is_empty():
						state.boons.append(String((rb[0] as Dictionary)["id"]))
	hero.kit = state
	hero.apply_stats(state.stats(), state.weapon, true)
	hero.revives = state.revives
	_run_t0 = _clock
	ArpgDaily.on_start(state)


## 数值联调：--talents=half|full 模拟局外养成（只改这次，不写存档），
## --quitend 一局结束（登顶或身死）打一行 RUN 汇总后退出；一间房卡住超过 BENCH_STALL 秒打 STALL 也退出。
## tools/balance/run_matrix.sh 用这两个参数并行跑多局，tools/balance/report.py 汇总。
const BENCH_STALL := 420.0
var _bench_seen := 0.0


## --quitend：不管在房间、对话、菜单还是山门，游戏时间过了 BENCH_STALL 秒都没再打 TEL 就算卡住
func _bench_watch() -> void:
	if not _args.has("quitend") or mode == "over":
		return
	if _clock - _bench_seen > BENCH_STALL:
		var dlg := ""
		for n: Node in ui_layer.get_children():
			dlg += n.get_class() + ":" + String(n.name) + " "
		print("STUCK mode=%s room=%s menu=%s ui=[%s] portal=%s hero=%s act=%d floor=%d row=%d" % [mode, room_kind, str(_menu.get("title")) if is_instance_valid(_menu) else "-", dlg,
			str(_portal.global_position) if is_instance_valid(_portal) else "-", str(hero.global_position) if is_instance_valid(hero) else "-",
			state.act if state != null else 0, state.floor_i() + 1 if state != null else 0, state.run.row if state != null else 0])
		print("STUCK2 done=%s wi=%d/%d hold=%s going=%s hero_state=%s alive=%s foes=%d extra=%d side=%d npcs=%d" % [_room_done, wave_i, waves.size(), _hold_waves, _going,
			hero.state if is_instance_valid(hero) else "-", hero.alive if is_instance_valid(hero) else false, get_tree().get_nodes_in_group("foes").size(), _extra_portals.size(), side_rooms.size(), _npcs.size()])
		get_tree().quit(4)


func _bench_talents(kind: String) -> void:
	var tl := {}
	for t: Dictionary in ArpgData.TALENT_TREES:
		var tiers: Array = t["tiers"]
		for ti in range(tiers.size()):
			for nd: Dictionary in tiers[ti]:
				var mx := int(nd["max"])
				if kind == "full":
					tl[nd["id"]] = mx
				elif ti < 2:
					tl[nd["id"]] = int(ceil(mx * 0.5))   # half：前两层各点一半，第三层不点
	Game.save["talents"] = tl


func _bench_end(won: bool) -> void:
	var gear := []
	for slot: String in state.gear:
		var it: Dictionary = state.gear[slot]
		if not it.is_empty():
			gear.append("%s:%s%d" % [slot, it.get("base", ""), int(it.get("rarity", 0))])
	print("RUN won=%s jade=%d act=%d weapon=%s cycle=%d diff=%d floor=%d row=%d rooms=%d kills=%d clk=%.0f lv=%d hits=%d dmg=%.0f drinks=%d maxhp=%.0f atk=%.2f taken=%.2f crit=%.2f boons=%s gear=%s skills=%s killer=%s" % [
		won, state.jade, state.act, state.weapon, state.cycle, ArpgState.difficulty(), state.floor_i() + 1, state.run.row, state.rooms, state.kills,
		_clock - _run_t0, state.level, hero.hits_taken, hero.dmg_total, hero.drinks, hero.max_hp, hero.dmg_mult, hero.taken_mult,
		hero.crit_bonus, ",".join(state.boons), ",".join(gear), str(state.skills).replace(" ", ""), "" if won else hero.last_hit_by])
	if not state.daily.is_empty():
		print("RUNDAILY kind=%s rule=%s seed=%d omen=%s" % [state.daily.get("kind", ""), state.daily.get("rule", ""), state.seed_value, state.omen])
	get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


## 数值调校用：--tel 时每间房打一行统计（耗时、挨打、剩血、药、铜钱）
var _tel := {}


func _tel_print(what: String) -> void:
	_bench_seen = _clock
	if not _args.has("tel") or state == null or not is_instance_valid(hero) or _tel.is_empty():
		return
	print("TEL %s %s clk=%.0f fl=%d row=%d secs=%.1f dmg=%.0f hp=%.0f/%.0f gourd=%d coins=%d kills=%d lv=%d pts=%d sk=%s" % [what, room_kind, _clock, state.floor_i(), state.run.row,
		float(_tel["t"]), hero.dmg_total - float(_tel["dmg0"]), hero.hp, hero.max_hp, hero.gourds, state.coins, state.kills, state.level, state.points, str(state.skills)])


## 进当前房间（kind 为空时按地图上的房间类型）
func _enter_room(kind: String = "", zone_override: String = "") -> void:
	mode = "room"
	_clear_scene()
	_ensure_hero()
	_tel = {"t": 0.0, "dmg0": hero.dmg_total}
	room_kind = kind if kind != "" else state.room_type()
	_save_checkpoint(kind, zone_override)
	_room_hits0 = hero.hits_taken
	if room_kind != "tutorial":
		ArpgAch.unlock("first_run")
	var fl := state.floor_i()
	var zone_id := state.zone()
	if room_kind == "boss":
		zone_id = state.boss_zone()
	if zone_override != "":
		zone_id = zone_override
	var a2 := state.act == 2 and room_kind != "tutorial"
	var a3 := state.act == 3 and room_kind != "tutorial"
	var sz := ACT3_ROOM if a3 else (ACT2_ROOM if a2 else ROOM_SIZE)
	if room_kind in ["shop", "rest", "event", "start", "story", "treasure", "secret", "tutorial", "nook", "realm"]:
		sz = ACT3_SMALL if a3 else (ACT2_SMALL if a2 else SMALL_ROOM)
	elif room_kind == "boss":
		sz = ACT3_BOSS if a3 else (ACT2_BOSS if a2 else BOSS_ROOM)
	var plans := [] if _args.has("noside") else SideRoom.plan(room_kind, sz, _rng, String(_args.get("side", "")) if _args.get("side", "1") != "1" else "", zone_id)
	_build_arena(zone_id, state.seed_value + fl * 1000 + state.run.row * 37 + state.run.col * 7 + (500 if room_kind == "secret" else 0) + (700 if room_kind == "realm" else 0), sz, plans)
	_place_hero(arena.entry_pos)
	state.rooms += 1
	if hints != null:
		hints.room_entered()
	wave_i = -1
	_trial = null
	if room_kind == "trial":
		_trial = ArpgTrial.new()
		_trial.main = self
		_trial.floor_i = fl
		arena.add_child(_trial)
	_squad = {}
	_hazard = null
	waves = _make_waves(room_kind, fl)
	if not _squad.is_empty() and String(_squad["hazard"]) != "" and not waves.is_empty() and not _args.has("nohazard"):
		# 这个阵带环境机关（瘴气、骨刺、钟声……），伤害跟着层数涨
		_hazard = RoomHazard.new()
		_hazard.kind = String(_squad["hazard"])
		_hazard.main = self
		_hazard.dmg = 9.0 * (1.0 + fl * 0.18) * state.act_dmg()
		arena.add_child(_hazard)
	_wave_delay = 1.4
	_room_done = waves.is_empty()
	_hold_waves = false
	_secret = null
	_secret_hits = 0
	var gf := state.gfloor()
	var title := "%s · %s" % [state.floor_name(), ArpgState.TYPE_NAMES.get(room_kind, "")]
	if room_kind == "boss":
		title = state.boss_title()
	if room_kind == "tutorial":
		title = "山门 · 试刀场"
	hud.zone_name = title
	hud.wave_text = ""
	hud.seals = []
	hud.omen = ""
	if state.omen != "" and room_kind != "tutorial":
		var om: Dictionary = ArpgState.OMENS[state.omen]
		hud.omen = "天象 · %s" % om["name"]
		hud.omen_color = om["color"]
		if state.cycle > 0:
			hud.omen += "　%s" % ArpgCycle.label(state.cycle)
		if state.rooms == 1:
			# 一局的第一间：报一下这局的天象
			get_tree().create_timer(2.8).timeout.connect(func() -> void:
				if mode == "room":
					hud.banner("天象 · %s" % om["name"], String(om["desc"]), 3.0))
	hud.visible = true
	var sub := "第 %d 层　第 %d / %d 间" % [gf + 1, state.run.row + 1, state.run.rows.size()]
	if not _squad.is_empty():
		# 战斗房报一下这间是什么阵（玩家一进门就知道这间和上一间不一样）
		sub = "「%s」%s" % [_squad["name"], _squad["desc"]]
		title = "%s · %s" % [state.floor_name(), _squad["name"]]
		hud.zone_name = title
	if state.cycle > 0:
		sub += "　·　" + ArpgCycle.label(state.cycle)
	if room_kind != "tutorial":
		hud.banner(title, sub, 2.4)
	if state.cycle > 0 and state.rooms == 1 and room_kind != "tutorial":
		get_tree().create_timer(6.2).timeout.connect(func() -> void:
			if mode == "room":
				hud.banner(ArpgCycle.label(state.cycle), ArpgCycle.summary(state.cycle), 3.6))
	feel.screen_flash(Color(0, 0, 0, 1), 1.6)
	if state.flags.has("xiaoman"):
		_ensure_xiaoman()
	match room_kind:
		"boss":
			Game.music(state.boss_music())
		"secret", "nook":
			Game.music("secret")
		"shop", "rest", "event", "start", "story", "treasure", "tutorial":
			Game.music("hub")
		_:
			Game.music(String(ArpgState.ZONE_MUSIC.get(zone_id, "village")))
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
			if state.run.row == 0 and gf < ArpgStory.FLOOR_START.size() and not _args.has("demo") and not _args.has("lineup") and not _first_intro:
				var fs: Array = ArpgStory.FLOOR_START[gf].duplicate()
				if state.act == 2 and fl == 0:
					fs = ArpgStory.act2_open() + fs   # 第二幕开场：按第一幕最后的结局
				get_tree().create_timer(1.2).timeout.connect(func() -> void:
					if mode == "room" and _menu == null:
						_say(fs))
			if zone_id == "well" and state.run.row == 0:
				_npc("井壁刻字", Vector3(-4.5, 0, -2.5), {"kit": "gravestone", "scale": 1.2}, _read_well_words)
			if zone_id == "vault" and state.run.row == 0:
				_npc("七个灯座", Vector3(-4.5, 0, -2.5), {"kit": "candles", "scale": 1.5}, _read_seven_lamps)
		"story":
			var en := ArpgStory.encounter_for(gf, state.flags, state.seen)
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
			var zen := pg < 0 and zone_id == "temple" and (Game.save.get("arpg_endings", {}) as Dictionary).has("true") and not bool(Game.save.get("arpg_page6", false))
			if pg >= 0:
				_npc("刻字石碑", mid, {"kit": "gravestone", "scale": 1.3}, func(n: ArpgNpc) -> void: _take_page(n, pg))
			elif zen:
				# 隐藏剧情 · 师父的禅房（看过真结局后）
				_npc("两把木刀", mid, {"kit": "sword_shield", "scale": 1.2}, func(n: ArpgNpc) -> void:
					if n.used:
						return
					n.used = true
					Game.save["arpg_page6"] = true
					Game.write_save()
					Game.sfx("memory")
					vfx.sheet("soul-rise", n.global_position, 3.5, Color(0.9, 0.8, 1.0), 1.8)
					_say(ArpgStory.ZEN_ROOM))
			_npc("宝箱", Vector3(3.5, 0, -1.5), {"kit": "box", "scale": 1.4}, func(n: ArpgNpc) -> void: _open_chest(n, 2))
			arena.spirit_fire(Vector3(0, 0.6, -2.5), Color(0.8, 0.6, 1.0), 1.6, 2.4, 9.0)
			hud.banner("禅房" if zen else "密室", "师父住过的屋子" if zen else "裂墙后面藏着的房间", 2.4)
			_open_portal()
		"realm":
			# 秘境：凑齐一层的散件后封门里面的地方（ArpgSecrets）
			secrets.enter_realm(zone_id)
		"boss":
			# 头目先说话，说完再出手
			_hold_waves = not _args.has("demo") and not _boss_retry
			_boss_retry = false
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
	if state.act == 3 and room_kind != "tutorial":
		Act3.enter_room(self, room_kind)
	if room_kind != "tutorial":
		ArpgRoutes.enter_room(self, room_kind)   # 分岔支线的房间、支线尽头的秘处
	# 第一次玩：第一间房先听拾骨婆的开场白，说完再刷怪
	if _first_intro:
		_first_intro = false
		_hold_waves = true
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			if mode != "room":
				return
			var lines: Array = ArpgStory.INTRO.slice(0, ArpgStory.INTRO.size() - 1)
			lines.append(["", "（先往山上闯。倒下了会回到山门，在那里找拾骨婆点天赋、去兵器架换兵器。）"])
			if room_kind == "start" and gf < ArpgStory.FLOOR_START.size():
				lines.append_array(ArpgStory.FLOOR_START[gf])
			var d := _say(lines)
			d.finished.connect(func() -> void:
				_hold_waves = false
				_wave_delay = 0.4))
	# 没有战斗的房间：侧门一进来就开着
	if _room_done:
		for sr: SideRoom in side_rooms:
			sr.unlock(false)
	secrets.room_entered(room_kind, zone_id)   # 封门（入口房）、散件
	if _args.has("inside") and not side_rooms.is_empty():
		# 测试：直接站进第一间侧室门口
		_args.erase("inside")
		var sr0 := side_rooms[0]
		sr0.unlock(false)
		_place_hero(sr0.at(0.25, 0.5), Vector3(sr0.side, 0, 0))


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
		ArpgAch.unlock("tutorial")
		hero.hp = hero.max_hp
		hero.gourds = hero.max_gourds
		hud.wave_text = "试刀完成"
		hud.banner("试刀完成", TouchPad.hint("走进光门正式上山。F 和人说话，Tab 打开行囊，C 看属性", "走进光门正式上山。靠近人点「互」说话，右上角「囊」打开行囊、「属」看属性"), 3.5)
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


## 战斗房的编成见 FoeSquads（每层四种“阵”，每间战斗房抽一种，同层不重样）；精英词缀见 FoeAffix。
var _squad := {}          # 这间房的阵（空 = 不是战斗房）
var _hazard: RoomHazard   # 这间房的环境机关


## 按房间类型配几波敌人：层数越深越多越硬
func _make_waves(kind: String, fl: int) -> Array:
	if _args.has("nowaves"):
		return []
	if _args.has("foes") and kind in ["fight", "elite"]:
		# 测试用：--foes=archer,bomber 每波每种刷 3 个
		var tw := []
		for k: String in String(_args["foes"]).split(","):
			tw.append_array([k, 3])
		return [tw, tw, tw]
	match kind:
		"fight":
			# 每间战斗房抽一个“阵”（同一层先不重样）：阵定了小怪组合、词缀和房间机关
			var zone := state.zone()
			var key := "%d:%s" % [state.gfloor(), str(state.run.room_id())]
			if _args.has("squad"):
				_squad = FoeSquads.find(zone, String(_args["squad"]))
			elif state.squads.has(key):
				_squad = FoeSquads.find(zone, String(state.squads[key]))
			else:
				var used := []
				for k2: String in state.squads:
					if k2.begins_with("%d:" % state.gfloor()):
						used.append(state.squads[k2])
				_squad = FoeSquads.pick(zone, used, _rng)
			if _squad.is_empty():
				_squad = FoeSquads.themes(zone)[0]
			state.squads[key] = _squad["id"]
			var w := FoeSquads.make_waves(_squad, state.run.row >= 3, _rng)
			# 第一幕带走了铁伯的头盔：第二幕第一间战斗房，第一波不敢上来
			if state.act == 2 and state.flags.has("a1_iron_helm") and not state.flags.has("helm_used"):
				state.flags["helm_used"] = true
				w.pop_front()
				get_tree().create_timer(2.6).timeout.connect(func() -> void:
					if mode == "room":
						hud.banner("铁伯的头盔", "守过门的盔，这一波骨头不敢上前", 2.2))
			return w
		"elite":
			# 每层一组精英编成；领头的（每波第一种里的第一只）带词缀，见 _affix_for
			return (FoeSquads.ELITE.get(state.zone(), FoeSquads.ELITE["forest"]) as Array).duplicate(true)
		"boss":
			return [[state.boss_kind(), 1]]
		"trial":
			return _trial.make_waves() if _trial != null else []
	return []


func _next_wave() -> void:
	if _trial != null and wave_i >= 0:
		_trial.finish()
	wave_i += 1
	if wave_i >= waves.size():
		_room_cleared()
		return
	var w: Array = waves[wave_i]
	hud.wave_text = "第 %d 波 / 共 %d 波" % [wave_i + 1, waves.size()]
	var aff_slot := _affix_slot(w)
	if _trial != null:
		_trial.begin(wave_i)
	var pts := arena.spawn_points.duplicate()
	pts.shuffle()
	# 房间大了，不再刷在离主角最远的角落（要跑半天）：优先挑离主角 8~16 米的点，不够再按远近补
	var hp := hero.global_position
	var score := {}
	for q: Vector3 in pts:
		score[q] = _spawn_score(q.distance_to(hp))
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return float(score[a]) < float(score[b]))
	var pi := 0
	var counts := []
	var total := 0
	for j in range(0, w.size(), 2):
		var kind: String = w[j]
		var n: int = w[j + 1]
		if not kind.begins_with("boss") and state != null:
			n = maxi(1, int(round(n * state.omen_val("count") * ArpgCycle.count_mult(state.cycle) * ArpgDaily.foe_mult(state, "count"))))   # 天象：血月、骨潮多刷；轮回三起多两成
		counts.append(n)
		total += n
	# 轮回：这一波哪几只带词缀（试刀场、头目波不抽）
	var marks := {}
	if state != null and state.cycle > 0 and room_kind != "tutorial" and not String(w[0]).begins_with("boss"):
		marks = ArpgCycle.roll_wave(state.cycle, total, _rng)
	for j in range(0, w.size(), 2):
		var kind: String = w[j]
		var n: int = counts[j / 2]
		for k in range(n):
			var p: Vector3 = pts[pi % pts.size()] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			var afx: Array = marks.get(pi, [])
			pi += 1
			if kind.begins_with("boss"):
				p = Vector3(0, 0, -2.0)
				if state != null:
					afx = ArpgCycle.boss_affixes(state.cycle, _rng)
			# 本来就该带词缀的（精英房领头、深处那一波）+ 轮回抽到的，去重
			var base: Array = _affix_for(kind) if _args.has("affix") or (j == aff_slot and k == 0) else []
			for x: String in afx:
				if not base.has(x):
					base.append(x)
			_spawn_foe(kind, p, k * 0.12, base)
	if wave_i > 0:
		Game.sfx("boss" if String(w[0]).begins_with("boss") else "danger", -6.0)


## 这一波哪一种怪的第一只带词缀（返回在波次数组里的下标，-1 = 没有）：
## 精英房每波都有一只；战斗房第 2 排起第二波之后有几率出一只，深处那一波必有一只。挑这一波里最“硬”的那种。
func _affix_slot(w: Array) -> int:
	if _args.has("affix"):
		return 0
	var chance := 0.0
	if room_kind == "elite":
		chance = 1.0
	elif room_kind == "fight" and wave_i >= 1:
		chance = 0.0 if state.run.row < 1 else 0.15 + 0.08 * state.run.row + (0.1 if state.act >= 2 else 0.0)
		if wave_i >= 3:
			chance = 1.0
	if chance <= 0.0 or _rng.randf() > chance:
		return -1
	var best := -1
	var best_hp := -1.0
	for j in range(0, w.size(), 2):
		var k: String = w[j]
		# 第三幕的小怪在 Act3Foe.TYPES3 里（原来只查 Foe.TYPES，第三幕的精英房领头、深处那波常常一只词缀怪都没有）
		var td: Dictionary = Foe.TYPES.get(k, Act3Foe.TYPES3.get(k, {}))
		if td.is_empty() or td.has("aura") or td.has("boss") or td.has("phantom") or k in ["bomber", "lampkid", "lampnode"]:
			continue
		var hp := float(td["hp"])
		if hp > best_hp:
			best_hp = hp
			best = j
	return best


## 抽词缀：阵里写了用阵的，精英房用这层的精英词缀池；第二幕的精英房带两条
func _affix_for(kind: String) -> Array:
	if _args.has("affix"):
		return Array(String(_args["affix"]).split(","))
	var pool: Array = FoeSquads.ELITE_AFFIX.get(state.zone(), ["stout"]) if room_kind != "fight" or _squad.is_empty() else _squad["affix"]
	pool = pool.duplicate()
	pool.shuffle()
	var n := 2 if room_kind == "elite" and state.act >= 2 and pool.size() >= 2 else 1
	# 远程的不拿“狂”以外的近身词缀也无妨；只是“坚”放在小个子身上看不出来，换一条
	var out := pool.slice(0, n)
	if kind in ["archer", "greybow", "mage", "sporer"] and out.has("stout") and pool.size() > n:
		out[out.find("stout")] = pool[n]
	return out


## 刷怪点打分（越小越好）：8~16 米最好，太近容易贴脸，太远要跑
func _spawn_score(d: float) -> float:
	if d < 8.0:
		return 100.0 + (8.0 - d)
	if d > 16.0:
		return d - 16.0
	return randf() * 0.5


func _spawn_foe(kind: String, p: Vector3, delay: float, affix: Array = []) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if mode != "room" or arena == null:
		return
	var fl := state.floor_i() if state != null else 0
	var row := state.run.row if state != null else 0
	var f: Foe = FinaleFoe.new() if kind == "boss10" else (Act3Foe.new() if Act3Foe.TYPES3.has(kind) else Foe.new())
	# 越往后的房间越硬；头目不吃“第几间”的加成（它总在最后一间，原来白白多了 28% 血、21% 伤害，是整层最大的难度尖刺）
	var rk := 0 if kind.begins_with("boss") else row
	var om_hp: float = state.omen_val("hp") * ArpgDaily.foe_mult(state, "hp") if state != null and not kind.begins_with("boss") else 1.0
	var om_dmg := state.omen_val("dmg") if state != null else 1.0
	var ah := state.act_hp() if state != null else 1.0
	var ad := state.act_dmg() if state != null else 1.0
	# 第二、三幕的第三层：主角到这儿构筑已经成型（数值报告里挂伤只有第一层一半），小怪再硬一点
	if state != null and state.act >= 2 and fl == 2 and not kind.begins_with("boss"):
		ah *= 1.12
		ad *= 1.08
	f.setup_kind(kind, (1.0 + fl * 0.35 + rk * 0.04) * om_hp * ah, (1.0 + fl * 0.18 + rk * 0.03) * om_dmg * ad)
	if state != null and room_kind != "tutorial" and not f.data.has("phantom"):
		ArpgCycle.scale_foe(f, state.cycle)   # 轮回：敌人更硬、更疼
	if state != null and state.omen_val("speed") * ArpgDaily.foe_mult(state, "speed") != 1.0:
		f.data = f.data.duplicate()
		f.data["speed"] = float(f.data["speed"]) * state.omen_val("speed") * ArpgDaily.foe_mult(state, "speed")
	if _trial != null:
		_trial.mod_foe(f)
	if not affix.is_empty() and (not kind.begins_with("boss") or (state != null and state.cycle > 0)):
		FoeAffix.apply(f, affix)   # 头目只有轮回四起才带词缀
	add_child(f)
	if _trial != null:
		_trial.dress_foe(f)
	f.global_position = p
	f.face_to(hero.global_position - p)
	f.detect_mult = 1.6   # 波次刷的怪一出来就该找人，大房间里别在角落发呆
	f.dropped.connect(_on_drop.bind(kind))
	if not f.affixes.is_empty():
		f.dropped.connect(func(_p: Vector3, _c: int, _j: int) -> void: ArpgAch.add("k_affix"))
		if state != null and state.cycle > 0 and not f.no_loot:
			f.dropped.connect(func(dp: Vector3, _c: int, _j: int) -> void: _loot(dp, "jade", 1))   # 轮回里的词缀怪多掉一颗魂玉
	if f.is_boss:
		hud.boss = f
		var sub: String = {"boss": "守在樱树下的无名剑客", "boss3": "无名冢下，万骨之主", "boss2": "古寺深处，一盏不灭的灯",
			"boss4": "井底四十年，灯链缠身的老僧", "boss5": "烛国亡了四百年，他的兵还在站岗",
			"boss6": "寂光大弟子，腰间挂着断刀的前半截", "boss7": "续命司火师，樱落村的第一把火", "boss8": "押送第五盏灯进京的禁军将军",
			"boss9": "靠四盏灯活了一百二十年", "boss10": "烛国最后的王，胸口点着第八盏灯"}.get(kind, "")
		if kind == "boss6" and state.flags.has("roster"):
			# 阿七把守台的人支开了：烬叫不来援兵，生命少一成
			f.max_hp *= 0.9
			f.hp = f.max_hp
			f.set("_summon_t", 1.0e9)
		hud.banner(f.display_name, sub, 2.6)
		# 登场：镜头特写头目、上下黑边、脚下一圈本色冲击
		cam_rig.close_up(f, 1.9, 0.6)
		hud.cinema(2.2)
		vfx.shock_ring(f.global_position, f.fx_color(), 0.5, 7.0, 0.6)
		vfx.sheet("spawn-cast", f.global_position, 4.5, Color.WHITE, 1.6, false, 0.0, 1.4)
		cam_rig.shake(1, 1.0)


func _on_drop(pos: Vector3, c: int, j: int, kind: String) -> void:
	if state != null and kind != "":
		state.kills += 1
		ArpgAch.add("kills")
		ArpgAch.killed(kind)
		# 装备掉落：赤甲武士常掉，小怪偶尔掉
		var chance := {"sporer": 0.05, "coffin": 0.12, "bellmonk": 0.12, "ronin": 0.6, "digger": 0.8, "officer": 0.5, "greyguard": 0.06, "greyspear": 0.05, "greyflag": 0.08, "oiler": 0.06, "twin": 0.03, "eel": 0.04, "lampkid": 0.06, "greyblade": 0.04, "greybow": 0.04, "armored": 0.12, "flameskel": 0.03, "chainmonk": 0.12, "drowned": 0.03, "samurai": 0.35, "charger": 0.15, "summoner": 0.1, "shield": 0.08, "mage": 0.06, "archer": 0.05,
			"skeleton": 0.04, "rogue": 0.04, "crawler": 0.015,
			"lampman": 0.03, "scarecrow": 0.04, "lampguard": 0.1, "torcher": 0.05, "courier": 0.04, "lancer": 0.12, "wardbell": 0.08,
			"goldguard": 0.14, "censer": 0.06, "palaceghost": 0.05, "chief": 0.9}
		if _rng.randf() < float(chance.get(kind, 0.0)):
			_drop_gear(pos, -1, 0.1 if kind == "samurai" else 0.0)
		# 道具：小怪偶尔掉，精英常掉
		if _rng.randf() < (0.2 if float(chance.get(kind, 0.0)) >= 0.3 else 0.025):
			_drop_prop(pos, ArpgArms.random_item(_rng))
		# 骨铃：斩杀回血
		if is_instance_valid(hero) and hero.alive and hero.kill_heal > 0.0:
			hero.hp = minf(hero.hp + hero.kill_heal, hero.max_hp)
		# 焚身：斩杀时有几率让它爆燃
		if is_instance_valid(hero) and hero.alive and hero.kill_fire > 0.0 and _rng.randf() < hero.kill_fire:
			hero._fire_burst(pos + Vector3(0, 0.9, 0))
	if state != null and kind != "" and c > 0 and mode == "room":
		var ups := state.gain_xp(c)
		if ups > 0:
			_on_level_up(ups)
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
	if state != null and state.omen_val("heal", 0.0) > 0.0 and room_kind in ["fight", "elite", "trial"] and is_instance_valid(hero):
		_heal(state.omen_val("heal", 0.0))   # 天象：清明
	hud.wave_text = "清场"
	Game.sfx("door")
	var clean := is_instance_valid(hero) and hero.hits_taken == _room_hits0
	if clean and room_kind in ["fight", "elite"]:
		ArpgAch.unlock("room_clean")
	for sr: SideRoom in side_rooms:
		if is_instance_valid(sr):
			sr.unlock(true)
	if room_kind == "realm":
		secrets.realm_cleared()
		return
	if room_kind == "boss":
		var fl := state.floor_i()
		if state.boss_kind() in ["boss4", "boss5", "boss6", "boss7", "boss8", "boss9"]:
			ArpgAch.unlock(state.boss_kind())
		if state.act == 1 and fl == 0:
			ArpgAch.unlock("boss1")
		elif state.act == 1 and fl < ArpgState.LAST_FLOOR:
			ArpgAch.unlock("boss2")
		if clean:
			ArpgAch.unlock("boss_clean")
		get_tree().create_timer(1.6).timeout.connect(_boss_outro.bind(state.floor_i()))
		return
	if state != null and state.flags.has("shadow_fight"):
		state.flags.erase("shadow_fight")
		get_tree().create_timer(1.2).timeout.connect(_shadow_outro)
		return
	if room_kind == "elite":
		_drop_gear(hero.global_position + hero.facing * 1.5, -1, 0.25)
		if _rng.randf() < 0.4:
			_drop_weapon(hero.global_position + hero.facing * 1.5 + Vector3(0.8, 0, 0), -1, 0.2)
		# 支线 · 刀匠的三样东西：青井地宫的精英身上掉寒铁（要先在山门见过刀匠）
		# 烛国灯冢的精英房：铸灯炉里的烛铜
		var smith_id: String = {"well": "iron", "vault": "bronze", "camp": "seal"}.get(state.zone(), "")
		if smith_id != "" and bool(Game.save.get("arpg_smith_met", false)) and not ArpgStory.smith_items().has(smith_id):
			ArpgStory.smith_take(smith_id)
			Game.sfx("memory")
			vfx.sheet("soul-rise", hero.global_position, 3.0, Color(0.6, 0.85, 1.0) if smith_id == "iron" else Color(1.0, 0.7, 0.35), 1.6)
			var sl: Array = ({"iron": ArpgStory.SMITH_GOT_IRON, "bronze": ArpgStory.SMITH_GOT_BRONZE, "seal": ArpgStory.SMITH_GOT_SEAL}[smith_id] as Array).duplicate()
			var nm := ""
			for it: Array in ArpgStory.SMITH_ITEMS:
				if it[0] == smith_id:
					nm = it[1]
			sl.append(["", "（刀匠的三样东西 %d / %d：%s）" % [ArpgStory.smith_items().size(), ArpgStory.SMITH_ITEMS.size(), nm]])
			var dd := _say(sl)
			dd.finished.connect(func() -> void: _offer_boons(4, "next"))
			return
	var n_boons := 3 if room_kind != "elite" else 4
	if room_kind == "trial" and _trial != null:
		var rw := _trial.reward()
		var n := _trial.seals()
		hud.wave_text = "试炼完成　得印 %d / 4" % n
		if n >= 1:
			ArpgAch.unlock("seal_1")
		if n >= 4:
			ArpgAch.unlock("seal_4")
		_drop_gear(hero.global_position + hero.facing * 1.5, int(rw["rarity"]))
		for i in range(mini(int(rw["coins"]) / 5, 12)):
			_loot(hero.global_position + hero.facing * 1.2, "coin", 5)
		for i in range(int(rw["jade"])):
			_loot(hero.global_position + hero.facing * 1.2, "jade", 1)
		n_boons = int(rw["boons"])
		hud.banner("试炼完成", "得印 %d / 4　%s" % [n, "四印俱全，多一个心法可选" if n == 4 else "印越多，装备越好"], 2.2)
		get_tree().create_timer(1.6).timeout.connect(func() -> void: _offer_boons(n_boons, "next"))
		return
	if room_kind == "fight":
		ArpgRoutes.cleared(self)   # 支线的战斗房多给铜钱
	hud.banner("清场", "选一个心法", 1.6)
	get_tree().create_timer(0.9).timeout.connect(func() -> void: _offer_boons(n_boons, "next"))


# ---------- 主线：头目战前战后、结局 ----------

func _boss_intro(fl: int) -> void:
	if mode != "room":
		return
	var key := state.boss_kind()
	var lines: Array = (ArpgStory.BOSS_PRE[key] if ArpgStory.BOSS_PRE.has(key) else (Finale.pre(self) if key == "boss10" else Act3.boss_pre(key))).duplicate()
	var extra: Dictionary = ArpgStory.BOSS_PRE_FLAGS.get(key, Act3.boss_pre_flags(key))
	for f: String in extra:
		if state.flags.has(f):
			lines.append_array(extra[f])
	if key == "boss" and ArpgStory.kite() >= ArpgStory.KITE.size():
		lines.append(["夜樱剑鬼", "……你还留着那只风筝。", ArpgStory.C_SAKURA])
	var om: Dictionary = ArpgStory.BOSS_PRE_OMEN.get(key, {})
	if om.has(state.omen):
		lines.append_array(om[state.omen])
	var d := _say(lines)
	d.finished.connect(func() -> void:
		if key == "boss2" and state.flags.has("ronin_saved"):
			hero.revives += 1
		Act3.boss_intro_done(self, key)
		_hold_waves = false
		_wave_delay = 0.3)


func _boss_outro(fl: int) -> void:
	if mode != "room":
		return
	var key := state.boss_kind()
	_drop_gear(hero.global_position + hero.facing * 1.5, 3, 0.0)
	var d := _say(ArpgStory.BOSS_POST[key] if ArpgStory.BOSS_POST.has(key) else Act3.boss_post(key))
	match key:
		"boss":
			d.finished.connect(_sakura_choice)
		"boss3":
			d.finished.connect(_grave_choice)
		"boss2":
			d.finished.connect(_ending_choice)
		"boss4":
			d.finished.connect(_well_choice)
		"boss5":
			d.finished.connect(_vault_choice)
		"boss6":
			d.finished.connect(_act2_ending)
		"boss7", "boss8", "boss9":
			d.finished.connect(Act3.boss_choice.bind(self, key))
		"boss10":
			d.finished.connect(Finale.won.bind(self))


## 隐藏头目 · 残影 打赢以后：专属心法、成就，之后照常选心法
func _shadow_outro() -> void:
	if mode != "room":
		return
	var d := _say(ArpgStory.SHADOW_POST)
	d.finished.connect(func() -> void:
		Game.save["arpg_shadow"] = true
		Game.write_save()
		ArpgAch.unlock("shadow")
		_take_boon("afterimage")
		Game.sfx("reward")
		vfx.shock_ring(hero.global_position, ArpgStory.C_SHADOW, 0.4, 6.0, 0.6)
		hud.banner("残影", "专属心法：%s" % String(ArpgData.boon("afterimage").get("desc", "")), 3.0)
		_drop_gear(hero.global_position + hero.facing * 1.5, 3, 0.0)
		get_tree().create_timer(1.6).timeout.connect(func() -> void: _offer_boons(3, "next")))


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
		var go := func() -> void:
			hud.banner("第二层 · 完", "山顶就是寂光寺，最后一层", 3.0)
			state.add_jade(6)
			_offer_boons(3, "floor")
		# 支线 · 无名冢的名字：第一次立碑，守墓人给名单
		if fx["flag"] == "graves_named" and not ArpgStory.has_name_list():
			Game.save["arpg_name_list"] = true
			Game.write_save()
			_say(ArpgStory.NAME_LIST_GIVEN).finished.connect(go)
		else:
			go.call())


func _ending_choice() -> void:
	var opts := [["douse", "熄灭残灯", "让死者安息。师父也会跟着灯一起走"], ["keep", "接过残灯", "像师父一样守着它"]]
	if ArpgStory.has_all_pages():
		opts.append(["true", "把五页残页交给师父", "（隐藏）你找齐了他写下的每一页"])
	if ArpgStory.all_souls(state.flags):
		opts.append(["souls", "问问他们", "（隐藏）你这一路帮过的人，都在灯前等你"])
	var items := []
	for o: Array in opts:
		items.append({"title": o[1], "desc": o[2], "color": Color(1.0, 0.85, 0.5) if o[0] in ["true", "souls"] else ArpgStory.C_MASTER})
	var m := _open_menu("残灯", "灯就悬在你面前。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var id: String = opts[i][0]
		_close_menu()
		var e: Dictionary = ArpgStory.ENDINGS[id]
		var seen: Dictionary = Game.save.get("arpg_endings", {})
		seen[id] = true
		Game.save["arpg_endings"] = seen
		Game.save["arpg_last_end"] = id   # 第二幕开场按这个分三种
		Game.write_save()
		ArpgAch.check_save()
		if id == "true":
			state.add_jade(30)
		elif id == "souls":
			state.add_jade(30)
			ArpgAch.unlock("end_souls")
		var d := _say(e["lines"])
		d.finished.connect(func() -> void:
			hud.banner(String(e["title"]), "残刃归途", 4.0)
			Game.sfx("reward")
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _game_over(true, String(e["title"])))))


# ---------- 第二幕 · 入山 ----------

## 第一幕看过任一结局后，山门出现“入井”光门
func act2_open() -> bool:
	return not (Game.save.get("arpg_endings", {}) as Dictionary).is_empty() or _args.has("act2")


## 青井地宫第一间的井壁刻字：寂光十七岁刻的
func _read_well_words(n: ArpgNpc) -> void:
	var lines: Array = ArpgStory.WELL_WORDS.duplicate()
	if not n.used:
		n.used = true
		lines.append(["", "（魂玉 +3）"])
		for i in range(3):
			_loot(n.global_position + Vector3(0, 0, 1.0), "jade", 1)
		Game.sfx("memory")
	_say(lines)


## 打倒井中人·枯荣后的选择
func _well_choice() -> void:
	var items := []
	for c: Array in ArpgStory.WELL_CHOICE:
		items.append({"title": c[0], "desc": c[1], "color": ArpgStory.C_KURONG})
	var m := _open_menu("灯链尽断", "老僧跪在水里，胸口的灯链上嵌着一片青色的碎灯。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var fx: Dictionary = ArpgStory.WELL_CHOICE[i][2]
		state.flags[fx["flag"]] = true
		_close_menu()
		var lines: Array = ArpgStory.KURONG_FREED if fx["flag"] == "kurong_freed" else ArpgStory.KURONG_SHARD
		if fx.has("jade"):
			state.add_jade(int(fx["jade"]))
			feel.callout(hero.head_top(), "魂玉 +%d" % int(fx["jade"]), Color(0.55, 1.0, 0.85), 1.2)
		if fx.has("boon_id"):
			_take_boon(String(fx["boon_id"]))
			Game.save["arpg_shard"] = true   # 拾骨婆之后会发现
			Game.write_save()
		else:
			Game.save["arpg_kurong_freed"] = true
			Game.write_save()
		var d := _say(lines)
		d.finished.connect(func() -> void:
			state.add_jade(6)
			_act2_floor_done("暗河那头是烛国灯冢")))


## 第二幕一层打完：做好的最后一层就“未完待续”，不然去下一层
func _act2_floor_done(sub: String) -> void:
	if state.is_last_floor():
		_act2_tbc()
	else:
		hud.banner("第%s层 · 完" % ArpgState.CN_NUM[state.gfloor()], sub, 3.0)
		_offer_boons(3, "floor")


## 灯冢第一间的七个灯座
func _read_seven_lamps(n: ArpgNpc) -> void:
	var lines: Array = ArpgStory.SEVEN_LAMPS.duplicate()
	if not n.used:
		n.used = true
		lines.append(["", "（魂玉 +3）"])
		for i in range(3):
			_loot(n.global_position + Vector3(0, 0, 1.0), "jade", 1)
		Game.sfx("memory")
	_say(lines)


## 打倒不夜将军后的选择：毁掉灯模 / 带走灯模
func _vault_choice() -> void:
	var items := []
	for c: Array in ArpgStory.VAULT_CHOICE:
		items.append({"title": c[0], "desc": c[1], "color": ArpgStory.C_GENERAL})
	var m := _open_menu("长夜将尽", "将军身后的铜台上放着一具灯模，模子里的纹路还是热的。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var fx: Dictionary = ArpgStory.VAULT_CHOICE[i][2]
		state.flags[fx["flag"]] = true
		_close_menu()
		var broke: bool = fx["flag"] == "mold_broken"
		if broke:
			state.add_jade(int(fx["jade"]))
			feel.callout(hero.head_top(), "魂玉 +%d" % int(fx["jade"]), Color(0.55, 1.0, 0.85), 1.2)
			Game.save["arpg_mold_broken"] = true
			Game.write_save()
		else:
			_drop_gear(hero.global_position + hero.facing * 1.5, int(fx["gear"]), 0.0)
		var d := _say(ArpgStory.MOLD_BROKEN if broke else ArpgStory.MOLD_TAKEN)
		d.finished.connect(func() -> void:
			state.add_jade(6)
			_act2_floor_done("铜殿后面的石阶通往灰衣营")))


## 第二幕暂时只做到这一层：说完“未完待续”，按通关结算
func _act2_tbc() -> void:
	var seen: Dictionary = Game.save.get("arpg_act2_clears", {})
	seen[String(state.boss_kind())] = true
	Game.save["arpg_act2_clears"] = seen
	Game.write_save()
	var gf := state.gfloor()
	var d := _say(ArpgStory.ACT2_TBC.get(gf, ArpgStory.ACT2_TBC[3]))
	var title := "%s · 通过" % state.floor_name()
	d.finished.connect(func() -> void:
		hud.banner("第二幕 · 入山", title, 3.5)
		Game.sfx("reward")
		get_tree().create_timer(2.5).timeout.connect(func() -> void: _game_over(true, title)))


## 灰衣营放出来的小满：跟着主角走到底（每进一间房重新放到主角身后）
var _xiaoman: Follower


func _ensure_xiaoman() -> void:
	if is_instance_valid(_xiaoman) and not _xiaoman.is_queued_for_deletion():
		return
	_xiaoman = Follower.new()
	add_child(_xiaoman)
	_xiaoman.setup("rogue", Color(1.15, 0.95, 0.8), 0.62, "小满")
	_xiaoman.hero = hero
	_xiaoman.global_position = hero.global_position + Vector3(1.5, 0, 1.5)


## 守灯僧：拿魂玉换下一局出发时的东西（一次换一样）
func _talk_monk(n: ArpgNpc) -> void:
	if not bool(Game.save.get("arpg_monk_met", false)):
		Game.save["arpg_monk_met"] = true
		Game.write_save()
		var d := _say(ArpgStory.MONK_MEET)
		d.finished.connect(func() -> void: _talk_monk(n))
		return
	if String(Game.save.get("arpg_monk_buy", "")) != "":
		var d := _say([["守灯僧", "东西替你收着了，出发时带上。", ArpgStory.C_MONK]])
		if secrets.can_chat("monk"):
			d.finished.connect(func() -> void:
				if mode == "hub":
					secrets.chat("monk"))
		return
	var jade := int(Game.save["jade"])
	var items := []
	for w: Array in ArpgStory.MONK_WARES:
		items.append({"title": "%s　%d 魂玉" % [w[0], int(w[1])], "desc": w[2], "color": ArpgStory.C_MONK, "enabled": jade >= int(w[1])})
	# 最后一项：闲聊（见 ArpgSecrets）
	items.append({"title": "闲聊", "desc": "听守灯僧说说寺里的事" if secrets.can_chat("monk") else "今天已经说过了", "color": ArpgStory.C_MONK, "enabled": true,
		"right": "新" if secrets.can_chat("monk") and secrets._chat_i("monk") >= 0 else ""})
	var m := _open_menu("守灯僧 · 换物", "魂玉 %d　　一次换一样，下一局出发时生效" % jade, items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		if i >= ArpgStory.MONK_WARES.size():
			_close_menu()
			secrets.chat("monk")
			return
		var w: Array = ArpgStory.MONK_WARES[i]
		Game.save["jade"] = int(Game.save["jade"]) - int(w[1])
		Game.save["arpg_monk_buy"] = String(w[0])
		Game.write_save()
		hud.jade = int(Game.save["jade"])
		_close_menu()
		n.display = "守灯僧 · 已换过"
		Game.sfx("reward")
		feel.callout(n.global_position + Vector3(0, 2.2, 0), "换得：%s" % w[0], Color(0.75, 1.0, 0.75), 1.4))


## 第二幕结局：打倒烬以后。斩烬总能选；渡烬要放出小满或找到三封家书；合刃要五封家书 + 刀匠的刀镡
func _act2_ending() -> void:
	var du_ok := state.flags.has("xiaoman") or ArpgStory.letters() >= 3
	var he_ok := ArpgStory.letters() >= ArpgStory.LETTERS.size() and ArpgStory.smith_done()
	var opts := [["zhan", "斩烬", "一刀了断。替樱落村，替柳溪村，替师父", true],
		["du", "渡烬", "收刀。让他自己去还" if du_ok else ArpgStory.DU_NEED, du_ok],
		["he", "合刃", "（隐藏）把三截刀合在一起" if he_ok else ArpgStory.HE_NEED, he_ok]]
	var items := []
	for o: Array in opts:
		items.append({"title": o[1], "desc": o[2], "enabled": o[3], "color": (Color(1.0, 0.85, 0.5) if o[0] == "he" else ArpgStory.C_JIN) if o[3] else Color(0.5, 0.5, 0.55)})
	var m := _open_menu("烬", "师兄跪在灰灯前，等你的刀。", items, "list", false)
	m.chosen.connect(func(i: int) -> void:
		var id: String = opts[i][0]
		_close_menu()
		var e: Dictionary = ArpgStory.ENDINGS2[id]
		var seen: Dictionary = Game.save.get("arpg_act2_endings", {})
		seen[id] = true
		Game.save["arpg_act2_endings"] = seen
		var cl: Dictionary = Game.save.get("arpg_act2_clears", {})
		cl["boss6"] = true
		Game.save["arpg_act2_clears"] = cl
		Game.write_save()
		ArpgAch.unlock("end2_" + id)
		Act3.on_act2_end(state, id)
		state.add_jade(30 if id == "he" else 15)
		var lines: Array = (e["lines"] as Array).duplicate()
		if state.flags.has("xiaoman"):
			lines.append(["小满", "哥哥，我们回家吗？", ArpgStory.C_XIAOMAN])
			lines.append(["残刃", "……嗯。回家。", ArpgStory.C_HERO])
		lines.append(["", "（第二幕 · 入山　完。山门左边下山的路口，亮起了“出山”的光门）"])
		var d := _say(lines)
		d.finished.connect(func() -> void:
			hud.banner(String(e["title"]), "第二幕 · 入山", 4.0)
			Game.sfx("reward")
			get_tree().create_timer(3.0).timeout.connect(func() -> void: _game_over(true, String(e["title"])))))


## 山门的老刀匠：第一次说来意，之后看三样东西找齐了几样
func _talk_smith(_n: ArpgNpc) -> void:
	if not bool(Game.save.get("arpg_smith_met", false)):
		Game.save["arpg_smith_met"] = true
		Game.write_save()
		_say(ArpgStory.SMITH_MEET)
		return
	var got := ArpgStory.smith_items()
	var lines := [["老刀匠", "东西带来了？我看看。", ArpgStory.C_SMITH]]
	for it: Array in ArpgStory.SMITH_ITEMS:
		var have := got.has(it[0])
		lines.append(["%s %s" % ["✓" if have else "○", it[1]], (String(it[3]) if have else "在%s。" % it[2]), ArpgStory.C_SMITH if have else ArpgStory.C_GREY])
	if ArpgStory.smith_done():
		lines = [["老刀匠", "刀镡在你身上了。剩下的半截刀，去找拿着它的人。", ArpgStory.C_SMITH]]
	elif got.size() >= ArpgStory.SMITH_ITEMS.size():
		# 三样齐了：打出刀镡（合刃结局要用）
		Game.save["arpg_smith_done"] = true
		Game.write_save()
		ArpgAch.unlock("smith")
		lines.append_array(ArpgStory.SMITH_DONE)
	else:
		lines.append(["老刀匠", "还差 %d 样。不急，刀等得起，人等不起。" % (ArpgStory.SMITH_ITEMS.size() - got.size()), ArpgStory.C_SMITH])
	var d := _say(lines)
	# 说完正事，每回山门再念叨一段（提示、最后给磨刀石）
	if secrets.can_chat("smith"):
		d.finished.connect(func() -> void:
			if mode == "hub":
				secrets.chat("smith"))


## 山门的地藏：每回山门求一次保佑，下一局出发时生效
func _pray_jizo(n: ArpgNpc) -> void:
	if String(Game.save.get("arpg_bless", "")) != "":
		secrets.rub_jizo()   # 求过了还来：摸摸脑袋（摸够了掉铜钱，见 ArpgSecrets）
		return
	var items := []
	for b: Array in ArpgStory.JIZO_BLESS:
		items.append({"title": b[0], "desc": b[1], "tag": "保佑", "color": Color(1.0, 0.9, 0.6), "glyph": String(b[0]).substr(0, 1)})
	var m := _open_menu("地藏 · 求保佑", "石头脑袋是你从井底捡回来的。它好像在笑。", items, "cards", true)
	m.chosen.connect(func(i: int) -> void:
		Game.save["arpg_bless"] = String(ArpgStory.JIZO_BLESS[i][0])
		Game.write_save()
		_close_menu()
		n.display = "地藏 · 已求过"
		Game.sfx("reward")
		vfx.shock_ring(n.global_position, Color(1.0, 0.9, 0.6), 0.3, 3.0, 0.5)
		feel.callout(n.global_position + Vector3(0, 2.2, 0), "保佑：%s" % ArpgStory.JIZO_BLESS[i][0], Color(1.0, 0.9, 0.6), 1.4))


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
			ArpgStory.mark_seen(String(en["id"]))
			_close_menu()
			_story_effect(en["options"][i][2], n)))


func _story_effect(fx: Dictionary, n: ArpgNpc) -> void:
	if fx.has("flag"):
		state.flags[fx["flag"]] = true
	if fx.has("save"):
		Game.save[String(fx["save"])] = true
		Game.write_save()
		if fx["save"] == "arpg_jizo_home":
			ArpgAch.unlock("jizo_home")
			hud.banner("地藏归位", "回山门看看：以后每局出发前可以向它求一个保佑", 3.0)
	if fx.has("letter") and ArpgStory.letters() < ArpgStory.LETTERS.size():
		var li := ArpgStory.letters()
		Game.save["arpg_letters"] = li + 1
		Game.write_save()
		if li + 1 >= ArpgStory.LETTERS.size():
			ArpgAch.unlock("letters")
		var ll: Array = (ArpgStory.LETTERS[li] as Array).duplicate()
		ll.append(["", "（烬的家书 %d / %d）" % [li + 1, ArpgStory.LETTERS.size()]])
		get_tree().create_timer(0.3).timeout.connect(func() -> void: _say(ll))
	if fx.get("flag", "") == "xiaoman":
		_ensure_xiaoman()
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
		waves = [[String(fx["fight"]), 1]] if fx.has("solo") else [[String(fx["fight"]), 1, String(fx.get("with", "skeleton")), 2]]
		wave_i = -1
		_wave_delay = 0.6
		room_kind = "elite"
		if is_instance_valid(_portal):
			_portal.queue_free()
		n.queue_free()
	if fx.has("boon"):
		_offer_boons_then(int(fx["boon"]))
	if state.act == 3:
		Act3.story_effect(self, fx)


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
	if _rng.randf() < 0.3:
		_drop_weapon(p + Vector3(-0.6, 0, 0), -1, 0.15)
	if _rng.randf() < 0.55:
		_drop_prop(p + Vector3(0, 0, 0.6), ArpgArms.random_item(_rng))
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
		ArpgAch.unlock("pages")
	_say(lines)


## 裂墙：靠墙放一段带裂缝的墙，墙缝里透一点紫光；清完房间后打三下就塌，后面是去密室的光门
func _make_secret_wall(sz: Vector2) -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var p := Vector3(side * (sz.x * 0.5 - 1.6), 0, _rng.randf_range(-sz.y * 0.5 + 4.0, sz.y * 0.5 - 6.0))
	for _try in range(12):
		# 别和侧室的门挤在一起
		var clash := false
		for sr: SideRoom in side_rooms:
			if signf(sr.side) == side and absf(sr.door_z - p.z) < 6.0:
				clash = true
		if not clash:
			break
		side = -side if _try % 2 == 0 else side
		p = Vector3(side * (sz.x * 0.5 - 1.6), 0, _rng.randf_range(-sz.y * 0.5 + 4.0, sz.y * 0.5 - 6.0))
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
		ArpgAch.unlock("secret")
		_make_secret_portal(p - Vector3(signf(p.x) * 1.5, 0, 0))


func _make_secret_portal(p: Vector3, kind: String = "secret", col: Color = Color(0.75, 0.5, 1.0)) -> void:
	var keep := _portal
	var keep_kind := _portal_kind
	_make_portal(p, kind, col)
	var sp := _portal
	sp.set_meta("kind", kind)
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
		items.append({"title": b["name"], "desc": b["desc"], "tag": _school_tag(String(b["school"])), "color": ArpgData.SCHOOL_COLORS.get(b["school"], ArpgMenu.TEAL),
			"right": ("已有 %d" % have) if have > 0 else "", "glyph": String(b["name"]).substr(0, 1)})
	var m := _open_menu("心法", "三选一，留在身上直到这一局结束", items, "cards", false)
	hints.menu_tip("boons", m)
	m.chosen.connect(func(i: int) -> void:
		_take_boon(String(offer[i]["id"]))
		_close_menu()
		_open_portal(then_portal)
		if ArpgSkills.any_open(state.skills, state.points):
			_open_skills())


## 心法卡片上的流派标签：“血 心法 2/3”，凑够了写“已大成”
func _school_tag(sc: String) -> String:
	var n := int(ArpgData.school_counts(state.boons).get(sc, 0))
	if n >= ArpgData.SET_NEED:
		return "%s · 已大成" % sc
	return "%s 心法 %d/%d" % [sc, n, ArpgData.SET_NEED]


func _take_boon(id: String) -> void:
	var b := ArpgData.boon(id)
	var sc := String(b.get("school", ""))
	var before := int(ArpgData.school_counts(state.boons).get(sc, 0))
	var duals0 := ArpgSkills.duals_of(state.boons)
	state.boons.append(id)
	hero.apply_stats(state.stats(), state.weapon)
	for d: String in ArpgSkills.duals_of(state.boons):
		if not duals0.has(d):
			# 双修：两色冲击环交错 + 横幅
			var dd := ArpgSkills.dual(d)
			var ca: Color = ArpgData.SCHOOL_COLORS.get(dd["a"], Color.WHITE)
			var cb: Color = ArpgData.SCHOOL_COLORS.get(dd["b"], Color.WHITE)
			get_tree().create_timer(0.3).timeout.connect(func() -> void:
				hud.banner("双修 · %s" % dd["name"], "%s + %s：%s" % [dd["a"], dd["b"], dd["desc"]], 3.2)
				Game.sfx("reward")
				for j in range(4):
					vfx.shock_ring(hero.global_position, ca if j % 2 == 0 else cb, 0.3 + j * 0.1, 3.0 + j * 1.6, 0.5))
			ArpgAch.unlock("dual_any")
	if before == ArpgData.SET_NEED - 1 and ArpgData.SETS.has(sc):
		# 流派大成：大横幅 + 本色冲击
		var st: Dictionary = ArpgData.SETS[sc]
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			hud.banner("%s · 大成「%s」" % [sc, st["name"]], String(st["desc"]), 4.0)
			Game.sfx("reward")
			feel.screen_flash(Color(ArpgData.SCHOOL_COLORS.get(sc, Color.WHITE), 0.35), 2.0)
			for j in range(3):
				vfx.shock_ring(hero.global_position, ArpgData.SCHOOL_COLORS.get(sc, Color.WHITE), 0.35 + j * 0.15, 4.0 + j * 2.0, 0.5))
		ArpgAch.unlock("set_any")
		if String(st["id"]) in ["set_storm", "set_pyre"]:
			ArpgAch.unlock(String(st["id"]))
	feel.callout(hero.head_top(), String(b.get("name", "")), ArpgData.SCHOOL_COLORS.get(b.get("school", ""), Color.WHITE), 1.2)
	vfx.shock_ring(hero.global_position, ArpgData.SCHOOL_COLORS.get(b.get("school", ""), Color.WHITE), 0.3, 3.5, 0.45)


# ---------- 悟道、技能分支、连携 ----------

## 升重：金色光柱从天落下、脚下金环、魂火升起；回一点血。天赋点在清房后（或暂停菜单）分配
func _on_level_up(ups: int) -> void:
	if not is_instance_valid(hero):
		return
	var p := hero.global_position
	SkillFx.pillar(p, 14.0, 1.8, 0.6)
	vfx.sheet("soul-rise", p, 3.6, Color(1.0, 0.85, 0.45), 2.2)
	for j in range(3):
		vfx.shock_ring(p, Color(1.0, 0.85, 0.45), 0.3 + j * 0.2, 3.0 + j * 1.8, 0.45 + j * 0.1)
	feel.callout(hero.head_top() + Vector3(0, 0.5, 0), "悟道 · %s重" % Hud3D._cn(state.level), Color(1.0, 0.88, 0.5), 1.5)
	feel.number(hero.head_top() + Vector3(0.8, 0.1, 0), "天赋点 +%d" % ups, Color(1.0, 0.85, 0.45), 0.9)
	hints.show("level")
	feel.screen_flash(Color(1.0, 0.85, 0.45, 0.2), 3.0)
	Game.sfx("reward", -3.0)
	hero.hp = minf(hero.hp + hero.max_hp * 0.08 * ups, hero.max_hp)
	if state.level >= 10:
		ArpgAch.unlock("lv_10")
	_tel_print("level%d" % state.level)


func _on_link(id: String) -> void:
	if state == null:
		return
	state.links_done[id] = true
	var seen: Array = Game.save.get("arpg_links", [])
	if not seen.has(id):
		seen.append(id)
		Game.save["arpg_links"] = seen
		Game.write_save()
	ArpgAch.unlock("link_1")
	if seen.size() >= ArpgSkills.LINKS.size():
		ArpgAch.unlock("link_all")
	if _args.has("tel"):
		print("LINK %s" % id)


## 技能分支：五招各两支，同一招只能走一支，每支三级。先选招（列表），再在两支里选（卡片）。
## from_pause 时返回回到暂停菜单
func _open_skills(keep_index: int = -1, from_pause: bool = false) -> void:
	var items := []
	for s: Dictionary in ArpgSkills.SKILLS:
		var parts := []
		var open := false
		for b: Dictionary in s["branches"]:
			var bid := String(b["id"])
			var r := int(state.skills.get(bid, 0))
			var n := (b["ranks"] as Array).size()
			var why := ArpgSkills.why_not(state.skills, state.points, bid)
			open = open or why == ""
			parts.append("%s %s%s" % [b["name"], "●".repeat(r) + "○".repeat(n - r), "（锁）" if why.begins_with("已走") else ""])
		var cb := ArpgSkills.chosen_branch(state.skills, String(s["id"]))
		if (s["branches"] as Array).size() > 2:
			# 秘技四选一：学了只写学的那一种，没学写“四选一”
			parts = parts.filter(func(t: String) -> bool: return cb == "" or t.begins_with(String(ArpgSkills.branch(cb)["name"])))
			if cb == "":
				parts = ["旋风 · 飞轮 · 震岳 · 分身，四选一"]
		items.append({"tag": String(s["glyph"]), "tag_color": s["color"], "title": String(s["full"]) + ("　新" if s.get("new", false) and cb == "" else ""),
			"desc": "　　".join(parts), "right": "可点" if open else "", "color": s["color"], "enabled": open or from_pause})
	var sub := "悟道 %s重　　天赋点 %d　　每招两支，只能走一支" % [Hud3D._cn(state.level), state.points]
	var m := _open_menu("技能分支", sub, items, "list", true)
	hints.menu_tip("skills", m)
	if keep_index >= 0:
		m.index = keep_index
	m.chosen.connect(func(i: int) -> void: _open_branch(i, from_pause))
	m.cancelled.connect(func() -> void:
		if from_pause:
			_open_pause("skills"), CONNECT_DEFERRED)


## 一招的两支：卡片 + 下面列出三级的效果
func _open_branch(si: int, from_pause: bool) -> void:
	var s: Dictionary = ArpgSkills.SKILLS[si]
	var brs: Array = s["branches"]
	var items := []
	for b: Dictionary in brs:
		var bid := String(b["id"])
		var r := int(state.skills.get(bid, 0))
		var n := (b["ranks"] as Array).size()
		var why := ArpgSkills.why_not(state.skills, state.points, bid)
		items.append({"title": String(b["name"]), "desc": String(b["brief"]), "tag": "%s · %s" % [s["full"], "已选这一支" if r > 0 else "分支"],
			"color": s["color"] if not why.begins_with("已走") else Color(0.45, 0.45, 0.45), "glyph": String(b["name"]).substr(0, 1),
			"right": "%s　%s" % ["●".repeat(r) + "○".repeat(n - r), why if why != "" else "点一级"], "enabled": why == ""})
	var m := _open_menu(String(s["full"]), "天赋点 %d　　%s" % [state.points, "四选一，学了一种这一局就不能换" if brs.size() > 2 else "先点的那一支锁定，另一支这一局就不能点了"], items, "cards", true)
	var pick := 0
	for i in range(brs.size()):
		if ArpgSkills.why_not(state.skills, state.points, String(brs[i]["id"])) == "":
			pick = i
			break
	m.index = pick
	m.extra_draw = func(c: Control, vs: Vector2) -> void:
		var b: Dictionary = brs[clampi(m.index, 0, brs.size() - 1)]
		var r := int(state.skills.get(String(b["id"]), 0))
		var ranks: Array = b["ranks"]
		var y := vs.y * 0.5 + 214.0
		for k in range(ranks.size()):
			var col := Color(1.0, 0.85, 0.45) if k < r else (Color(0.9, 0.95, 0.95) if k == r else Color(0.55, 0.6, 0.6))
			var mark := "●" if k < r else ("▶" if k == r else "○")
			c.draw_string(c.get("font"), Vector2(0, y + k * 24), "%s %s级　%s" % [mark, Hud3D._cn(k + 1), ranks[k]], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 17, col)
	m.chosen.connect(func(i: int) -> void:
		var bid := String(brs[i]["id"])
		if not state.learn(bid):
			return
		hero.apply_stats(state.stats(), state.weapon)
		var b := ArpgSkills.branch(bid)
		var c: Color = b["color"]
		vfx.shock_ring(hero.global_position, c, 0.3, 3.6, 0.45)
		vfx.sheet("rune-cast", hero.global_position, 3.0, c, 2.0, true, 0.0, 1.5)
		feel.callout(hero.head_top(), "%s · %s %s级" % [b["skill_name"], b["name"], Hud3D._cn(int(state.skills[bid]))], c, 1.2)
		Game.sfx("reward", -4.0)
		if int(state.skills.get(bid, 0)) >= (b["ranks"] as Array).size():
			ArpgAch.unlock("branch_max")
		if b["skill"] == "art" and int(state.skills[bid]) == 1:
			var arts: Array = Game.save.get("arpg_arts", [])
			if not arts.has(bid):
				arts.append(bid)
				Game.save["arpg_arts"] = arts
				Game.write_save()
			if arts.size() >= 4:
				ArpgAch.unlock("art_all")
			hud.banner("秘技 · %s" % b["name"], "按 %s 施展" % TouchPad.hint(ArpgInput.key_name(0, "art"), "右下角“秘”"), 2.4)
		_close_menu()
		if ArpgSkills.any_open(state.skills, state.points) or from_pause:
			_open_skills(si, from_pause))
	m.cancelled.connect(func() -> void: _open_skills(si, from_pause), CONNECT_DEFERRED)


# ---------- 商人、歇脚、奇遇 ----------

func _open_shop(_n: ArpgNpc) -> void:
	var stock := state.shop_stock()
	var key := state.run.room_id()
	var sold: Array = state.bought.get(key, [])
	var items := []
	for i in range(stock.size()):
		var it: Dictionary = stock[i]
		var pr := _shop_price(it)
		var gone := sold.has(i)
		var en := not gone and state.coins >= pr
		if it["kind"] == "refill" and hero.gourds >= hero.max_gourds:
			en = false
		var desc := String(it["desc"])
		if it["kind"] == "item" and state.add_item_room(String(it["id"])) == 0:
			en = false
			desc += "　（道具带满了）"
		if it["kind"] == "whet" and state.whet > 0:
			desc += "　已磨 %d 次（+%d%%）" % [state.whet, int(round(ArpgState.WHET_ATK * 100 * state.whet))]
		items.append({"title": it["name"], "desc": desc, "right": "已售" if gone else "%d 铜钱" % pr, "enabled": en,
			"tag": {"boon": "心法", "gear": "装备", "refill": "补给", "whet": "磨刀", "weapon": "兵器", "item": "道具"}.get(it["kind"], ""),
			"color": ArpgGear.color(it["item"]) if it["kind"] in ["gear", "weapon"] else Color(0.95, 0.92, 0.85)})
	var m := _open_menu("游商", "“兵荒马乱的，什么都贵。”　　铜钱 %d" % state.coins, items, "list", true)
	m.chosen.connect(func(i: int) -> void:
		var it: Dictionary = stock[i]
		state.coins -= _shop_price(it)
		if it["kind"] != "whet":   # 磨刀不限次数
			sold.append(i)
			state.bought[key] = sold
		match String(it["kind"]):
			"boon":
				_take_boon(String(it["id"]))
			"gear":
				_gain_gear(it["item"])
			"weapon":
				_close_menu()
				Game.sfx("coin")
				_gain_weapon(it["item"])
				return
			"item":
				state.add_item(String(it["id"]))
			"refill":
				hero.gourds = hero.max_gourds
			"whet":
				state.whet += 1
				feel.callout(hero.head_top(), "刀更快了 +%d%%" % int(round(ArpgState.WHET_ATK * 100 * state.whet)), Color(1.0, 0.85, 0.45), 1.0)
		hero.apply_stats(state.stats(), state.weapon)
		Game.sfx("coin")
		_close_menu()
		_open_shop(_n))


func _shop_price(it: Dictionary) -> int:
	if it["kind"] == "whet":
		return state.price(state.whet_price())
	# 往后几层铜钱多，价钱跟着涨（第二层 ×1.3，第三层 ×1.6）
	var k := 1.0 + 0.3 * state.floor_i() if it["kind"] != "refill" else 1.0
	return state.price(int(round(int(it["price"]) * k)))


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
	var v := hero.max_hp * frac * (ArpgCycle.heal_mult(state.cycle) if state != null else 1.0)
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
		items.append({"title": b["name"], "desc": b["desc"], "tag": _school_tag(String(b["school"])), "color": ArpgData.SCHOOL_COLORS.get(b["school"], ArpgMenu.TEAL)})
	var m := _open_menu("心法", "三选一" + ("（还有 %d 次）" % (n - 1) if n > 1 else ""), items, "cards", false)
	m.chosen.connect(func(i: int) -> void:
		_take_boon(String(offer[i]["id"]))
		_close_menu()
		_offer_boons_then(n - 1))


# ---------- 光门、分岔路 ----------

func _open_portal(kind: String = "next") -> void:
	_room_done = true
	_make_portal(arena.open_exit(), kind, Color(0.4, 1.0, 1.0))


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
	var cyc := "" if ArpgCycle.picked() <= 0 else " · " + ArpgCycle.label(ArpgCycle.picked())
	lab.text = {"run": "出发" + cyc, "act2": "入井 · 第二幕" + cyc, "act3": "出山 · 第三幕" + cyc, "floor": "前往第%s层" % ArpgState.CN_NUM[state.gfloor()] if state != null else "", "next": "前路", "secret": "密室", "realm": "秘境"}.get(kind, "")
	_portal.add_child(lab)


func _step_portal() -> void:
	_going = true
	Game.sfx("door")
	match _portal_kind:
		"run":
			# 不再问“要不要先教学”：按键在第一局里遇到时即时提示（ArpgHints），想系统练的去山门“试刀”
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
		items.append({"title": ArpgState.TYPE_NAMES.get(t, t), "desc": ArpgRoutes.card_desc(nd, String(ArpgState.TYPE_DESC.get(t, ""))), "tag": ArpgRoutes.card_tag(nd),
			"color": _type_color(t), "glyph": String(ArpgState.TYPE_NAMES.get(t, t)).substr(0, 1)})
	var m := _open_menu("分岔路", "第 %d 层　第 %d / %d 间　·　往哪走？" % [state.gfloor() + 1, state.run.row + 2, state.run.rows.size()], items, "cards", true)
	hints.menu_tip("path", m)
	var r0 := state.run.row
	m.extra_draw = func(c: Control, vs: Vector2) -> void:
		c.set("cards_top_min", _map_top(vs) + _map_h(vs) + 16)   # 卡片让到路线图下面
		if state.run.row == r0:   # 选完以后菜单还会多画一帧，那时 row 已经变了
			_draw_map(c, vs, ex)
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
		"event": Color(0.75, 0.6, 1.0), "boss": Color(0.95, 0.25, 0.4), "start": Color(0.6, 0.9, 0.9), "nook": Color(1.0, 0.7, 0.35)}.get(t, ArpgMenu.TEAL)


## 路线图的位置：标题和副标题是固定像素排的，所以至少从 165 开始；矮屏（触屏 576 高）画扁一点
func _map_top(vs: Vector2) -> float:
	return maxf(vs.y * 0.16 + 50, 165.0)


func _map_h(vs: Vector2) -> float:
	var h := 66.0 if vs.y >= 650 else 52.0
	# 一列有四间（加了分岔支线）：画高一点，别挤成一团
	if state != null:
		for r: Array in state.run.rows:
			if r.size() >= 4:
				return h * 1.4
	return h


## 菜单上方画整层路线图：每个房间一个带字的圆点（战 / 精 / 商 / 歇 / 奇 / 首 …），走过的路亮，
## 分岔路菜单里选中哪张卡，就把从那里能走到的房间和路描金（ex = 这一步能去的出口）
func _draw_map(c: Control, vs: Vector2, ex: Array = [], top: float = -1.0) -> void:
	var rows: Array = state.run.rows
	var x0 := vs.x * 0.2
	var w := vs.x * 0.6
	var y0 := _map_top(vs) if top < 0.0 else top
	var h := _map_h(vs)
	var pos := func(r: int, i: int) -> Vector2:
		var n: int = (rows[r] as Array).size()
		return Vector2(x0 + w * r / float(rows.size() - 1), y0 + h * ((i + 0.5) / float(n)))
	# 选中的出口往后能走到哪些房间
	var reach := {}
	var sel := int(c.get("index")) if c.get("index") != null else -1
	if sel >= 0 and sel < ex.size():
		var front := [int(ex[sel][0])]
		var r := state.run.row + 1
		while r < rows.size() and not front.is_empty():
			var nxt := []
			for i: int in front:
				if i >= (rows[r] as Array).size():
					continue
				reach[Vector2i(r, i)] = true
				if r + 1 < rows.size():
					for j: int in rows[r][i]["next"]:
						if not nxt.has(j):
							nxt.append(j)
			front = nxt
			r += 1
	c.draw_rect(Rect2(x0 - 24, y0 - 10, w + 48, h + 20), Color(0.02, 0.04, 0.05, 0.75))
	for r in range(rows.size() - 1):
		for i in range((rows[r] as Array).size()):
			for j: int in rows[r][i]["next"]:
				var lit := (reach.has(Vector2i(r, i)) or (r == state.run.row and i == state.run.col)) and reach.has(Vector2i(r + 1, j))
				var walked := bool(rows[r][i]["visited"]) and bool(rows[r + 1][j]["visited"])
				c.draw_line(pos.call(r, i), pos.call(r + 1, j), Color(ArpgMenu.GOLD, 0.85) if lit else Color(0.6, 0.85, 0.85, 0.6 if walked else 0.18), 2.0 if lit else 1.0)
	var font: Font = c.get("font") if c.get("font") != null else Game.font
	for r in range(rows.size()):
		for i in range((rows[r] as Array).size()):
			var nd: Dictionary = rows[r][i]
			var p: Vector2 = pos.call(r, i)
			var t := String(nd["type"])
			var col := _type_color(t)
			var here := r == state.run.row and i == state.run.col
			var on := bool(nd["visited"]) or here or reach.has(Vector2i(r, i)) or ex.is_empty()
			var rad := 10.0 if here else 9.0
			c.draw_circle(p, rad, Color(0.03, 0.05, 0.06, 0.95))
			c.draw_arc(p, rad, 0, TAU, 20, Color(col, 1.0 if on else 0.35), 1.5)
			var g := String(ArpgState.TYPE_NAMES.get(t, "?")).substr(0, 1)
			c.draw_string(font, p + Vector2(-5.5, 4.5), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, 1.0 if on else 0.4))
			if nd.has("branch"):
				c.draw_arc(p, rad + 3.0, 0, TAU, 20, Color(1.0, 0.7, 0.35, 0.85 if on else 0.35), 1.0)   # 分岔支线：外面多一圈橙
			if here:
				c.draw_arc(p, 14.0, 0, TAU, 24, ArpgMenu.GOLD, 2.0)


# ---------- 剧情对话 ----------

## 放一段对话，返回对话框（await 它的 finished 等说完）
func _say(lines: Array) -> DialogBox:
	if _args.has("storytest"):
		for l: Array in lines:
			print("SAY [%s] %s" % [l[0], l[1]])
	_requeue_weapon_menu()
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
	var it := ArpgGear.roll(_rng, rarity, luck + state.floor_i() * 0.08 + state.omen_val("luck", 0.0) + ArpgCycle.luck(state.cycle))
	var l := Loot.new()
	l.kind = "gear"
	l.item = it
	add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)
	l.collected.connect(func(_k: String, _a: int) -> void: _gain_gear(it))


## 掉一把兵器（精英房、宝箱）
func _drop_weapon(pos: Vector3, rarity: int = -1, luck: float = 0.0) -> void:
	if state == null:
		return
	var it := ArpgGear.roll_weapon(_rng, rarity, luck + state.floor_i() * 0.08 + state.omen_val("luck", 0.0))
	var l := Loot.new()
	l.kind = "gear"
	l.item = it
	add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)
	l.collected.connect(func(_k: String, _a: int) -> void: _gain_weapon(it))


func _drop_prop(pos: Vector3, id: String) -> void:
	if state == null:
		return
	var l := Loot.new()
	l.kind = "prop"
	l.item = {"id": id}
	add_child(l)
	l.global_position = pos + Vector3(0, 0.7, 0)
	l.collected.connect(func(_k: String, _a: int) -> void: _gain_prop(id))


## 捡到道具：叠上去或者占一格；三格都满了就换成铜钱
func _gain_prop(id: String) -> void:
	if state == null:
		return
	var d := ArpgArms.item(id)
	var got := state.add_item(id)
	if got > 0:
		feel.callout(hero.head_top() + Vector3(0, 0.3, 0), String(d["name"]), d["color"], 1.1)
		hud.banner(String(d["name"]), String(d["desc"]) + TouchPad.hint("（%s 使用）" % ArpgInput.key_name(0, "item"), "（「器」使用）"), 2.0)
	else:
		var c := state.add_coins(10)
		feel.callout(hero.head_top() + Vector3(0, 0.3, 0), "%s（带满了，换 %d 铜钱）" % [d["name"], c], d["color"], 1.1)


## 捡到兵器：副手空着就挂上；两手都有就问换哪一把。没见过的兵器同时挂上山门兵器架
## 捡到兵器要问“换哪只手”，这时候要是正开着别的菜单或对话（精英房清场的心法三选一、头目战后的对话），
## 直接开会把那个顶掉，它后面的流程（开光门）就没了，房间里出不去。先排着，菜单关了再问。
var _pending_weapons: Array = []


## 捡兵器的菜单被别的菜单、对话顶掉了：这把兵器放回队里，等会儿再问
func _requeue_weapon_menu() -> void:
	if is_instance_valid(_menu) and _menu.has_meta("weapon_item"):
		_pending_weapons.append(_menu.get_meta("weapon_item"))
		_menu.remove_meta("weapon_item")


func _flush_pending_weapons() -> void:
	if _pending_weapons.is_empty() or is_instance_valid(_menu) or not _no_dialog() or state == null or mode != "room":
		return
	_gain_weapon(_pending_weapons.pop_front())


func _gain_weapon(it: Dictionary) -> void:
	if state == null:
		return
	if is_instance_valid(_menu) or not _no_dialog():
		_pending_weapons.append(it)
		return
	var wid := String(it["base"])
	var owned: Array = Game.save.get("arpg_weapons", ["sword"])
	var fresh := not owned.has(wid)
	if fresh:
		owned.append(wid)
		Game.save["arpg_weapons"] = owned
		Game.write_save()
	ArpgAch.unlock("arms_pick")
	if int(it["rarity"]) >= 4:
		ArpgAch.unlock("gear_legend")
	var tail := "（山门兵器架上也挂上了）" if fresh else ""
	if _args.has("lockarms"):
		state.coins += 20 + 15 * int(it["rarity"])   # 数值联调比兵器：捡到的兵器一律熔掉，整局只用出发时那一把
		return
	if (state.arms[1] as Dictionary).is_empty():
		state.arms[1] = it
		feel.callout(hero.head_top() + Vector3(0, 0.3, 0), String(it["name"]), ArpgGear.color(it), 1.3)
		hud.banner(String(it["name"]), "挂在副手。" + TouchPad.hint("%s 换手" % ArpgInput.key_name(0, "swap"), "「换」换手") + tail, 2.4)
		_check_arms_ach()
		return
	var items := []
	for k in range(2):
		var cur: Dictionary = state.arms[k]
		items.append({"tag": "主手" if k == 0 else "副手", "title": "换掉 " + String(cur["name"]), "desc": ArpgGear.describe(cur), "color": ArpgGear.color(cur), "right": "换"})
	var c := 20 + 15 * int(it["rarity"])
	items.append({"tag": "不要", "title": "熔了换铜钱", "desc": "", "right": "%d 铜钱" % c})
	var wd := ArpgData.weapon(wid)
	var m := _open_menu("捡到 " + String(it["name"]), String(wd["desc"]) + "。" + ArpgGear.describe(it) + tail, items, "list", false)
	m.set_meta("weapon_item", it)
	m.chosen.connect(func(i: int) -> void:
		if i < 2:
			state.arms[i] = it
			if i == 0:
				state.weapon = wid
			hero.apply_stats(state.stats(), state.weapon)
			feel.callout(hero.head_top() + Vector3(0, 0.3, 0), String(it["name"]), ArpgGear.color(it), 1.3)
			_check_arms_ach()
		else:
			state.add_coins(c)
			Game.sfx("coin")
		_close_menu())


func _check_arms_ach() -> void:
	if not (state.arms[1] as Dictionary).is_empty():
		ArpgAch.unlock("arms_two")


## 捡到装备：那个部位空着就直接穿上（护符先占第一格，有双佩再占第二格），否则放进行囊（满了就换成铜钱）
func _gain_gear(it: Dictionary) -> void:
	if state == null:
		return
	var slot := String(it["slot"])
	var where := ""
	if int(it["rarity"]) >= 4:
		ArpgAch.unlock("gear_legend")
	var free := ""
	if (state.gear[slot] as Dictionary).is_empty():
		free = slot
	elif slot == "charm" and ArpgState.charm2_open() and (state.gear["charm2"] as Dictionary).is_empty():
		free = "charm2"
	if free != "":
		state.gear[free] = it
		hero.apply_stats(state.stats(), state.weapon)
		where = "（已装备）"
		_check_set_ach()
	elif state.bag.size() < ArpgGear.BAG_MAX:
		state.bag.append(it)
		where = TouchPad.hint("（放进行囊，Tab 查看）", "（放进行囊，右上角「囊」查看）")
	else:
		var c := state.add_coins(15 + 15 * int(it["rarity"]))
		where = "（行囊满了，换成 %d 铜钱）" % c
	feel.callout(hero.head_top() + Vector3(0, 0.3, 0), String(it["name"]), ArpgGear.color(it), 1.3)
	hud.banner(String(it["name"]), ArpgGear.slot_name(it) + "：" + ArpgGear.describe(it) + where, 2.2)
	hints.show("gear")


## 套装成就：穿齐一套三件
func _check_set_ach() -> void:
	var n := ArpgArms.set_counts(state.gear)
	for k: String in n:
		if int(n[k]) >= 3:
			ArpgAch.unlock("gear_set")


func _open_bag(keep_index: int = -1) -> void:
	if state == null:
		return
	var items := []
	var acts := []
	# 兵器：主手、副手（点主手 = 换手）
	for k in range(2):
		var w: Dictionary = state.arms[k]
		if w.is_empty():
			items.append({"tag": "副手", "title": "（空）", "desc": "精英房、宝箱、游商那里能弄到兵器", "enabled": false})
		else:
			items.append({"tag": "主手" if k == 0 else "副手", "tag_color": ArpgArms.trail(String(w["base"]))[1], "title": w["name"], "desc": ArpgGear.describe(w), "color": ArpgGear.color(w),
				"right": "换手" if not (state.arms[1] as Dictionary).is_empty() else "", "enabled": not (state.arms[1] as Dictionary).is_empty()})
		acts.append(["swap", k])
	var slots: Array = ["armor", "helm", "boots", "charm"]
	if ArpgState.charm2_open():
		slots.append("charm2")
	for slot: String in slots:
		var it: Dictionary = state.gear[slot]
		var sname := String(ArpgData.SLOT_NAMES[slot])
		if it.is_empty():
			items.append({"tag": sname, "title": "（空）", "desc": "", "enabled": false})
		else:
			items.append({"tag": sname, "title": it["name"], "desc": ArpgGear.describe(it), "color": ArpgGear.color(it),
				"right": "卸下", "enabled": state.bag.size() < ArpgGear.BAG_MAX})
		acts.append(["unequip", slot])
	# 套装进度
	var sc := ArpgArms.set_counts(state.gear)
	for sid: String in sc:
		var gs: Dictionary = ArpgArms.GEAR_SETS[sid]
		var n := int(sc[sid])
		var d := "两件 %s；三件 %s" % [gs["d2"], gs["d3"]]
		items.append({"tag": "套装", "tag_color": gs["color"], "title": "%s %d / 3" % [gs["name"], mini(n, 3)], "desc": d, "color": gs["color"], "enabled": false})
		acts.append(["none", 0])
	# 道具
	for i in range(state.props.size()):
		var pr: Dictionary = state.props[i]
		var d := ArpgArms.item(String(pr["id"]))
		items.append({"tag": "道具", "tag_color": d["color"], "title": "%s ×%d" % [d["name"], int(pr["n"])], "desc": d["desc"],
			"right": "当前" if i == state.prop_sel else "选用", "enabled": i != state.prop_sel, "color": d["color"]})
		acts.append(["prop", i])
	for i in range(state.bag.size()):
		var it: Dictionary = state.bag[i]
		items.append({"tag": "行囊", "title": it["name"], "desc": ArpgGear.slot_name(it) + "：" + ArpgGear.describe(it),
			"color": ArpgGear.color(it), "right": "换上"})
		acts.append(["equip", i])
	for r: int in ArpgGear.craftable(state.bag):
		items.append({"tag": "合成", "tag_color": Color(1.0, 0.8, 0.4), "title": "三件「%s」合成一件「%s」" % [ArpgGear.RARITY_NAMES[r], ArpgGear.RARITY_NAMES[r + 1]],
			"desc": "用掉行囊里三件同品质的装备，随机得到一件高一档的", "color": ArpgGear.RARITY_COLORS[r + 1], "right": "合成"})
		acts.append(["craft", r])
	var sub := "行囊 %d / %d　·　心法 %d 个　·　残页 %d / %d" % [state.bag.size(), ArpgGear.BAG_MAX, state.boons.size(), ArpgStory.pages().size(), ArpgStory.PAGES.size()]
	var m := _open_menu("行囊", sub, items, "list", true)
	hints.menu_tip("bag", m)
	m.footer = TouchPad.hint("J 选择　　Tab / 空格 关闭", "点选一项　　右上角 ✕ 关闭")
	if keep_index >= 0:
		m.index = mini(keep_index, items.size() - 1)
	m.chosen.connect(func(i: int) -> void:
		var a: Array = acts[i]
		match String(a[0]):
			"swap":
				state.swap_arms()
			"prop":
				state.prop_sel = int(a[1])
			"unequip":
				state.bag.append(state.gear[a[1]])
				state.gear[a[1]] = {}
			"equip":
				var it: Dictionary = state.bag[int(a[1])]
				state.bag.remove_at(int(a[1]))
				var slot := String(it["slot"])
				# 护符：第一格有了、第二格空着就戴第二格
				if slot == "charm" and not (state.gear["charm"] as Dictionary).is_empty() and ArpgState.charm2_open() and (state.gear["charm2"] as Dictionary).is_empty():
					slot = "charm2"
				var old: Dictionary = state.gear[slot]
				if not old.is_empty():
					state.bag.append(old)
				state.gear[slot] = it
				_check_set_ach()
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
	if _args.has("storytest"):
		print("MENU %s | %s | %s" % [title, sub, str(items.map(func(it: Dictionary) -> String: return String(it.get("title", ""))))])
	_requeue_weapon_menu()
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
	if _args.has("pick"):
		# 测试：菜单开了一会儿自动选第 N 项
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(m) and _menu == m:
				m.chosen.emit(mini(int(_args["pick"]), items.size() - 1)))
	return m


func _no_dialog() -> bool:
	return get_tree().get_nodes_in_group("dialog_box").is_empty()


## Esc / 手柄 Start：暂停菜单（音量、放弃这一局）。网页版里没有“退出游戏”
## sel：选中第几项，或者选项 id（"stats"、"run"、"skills" ...，从子菜单返回时用）
var _pause_ids: Array = []


func _open_pause(sel: Variant = 0) -> void:
	var pct := func(k: String) -> String: return "%d%%" % int(round(float(Game.settings[k]) * 100.0))
	var items := [{"id": "resume", "title": "继续"},
		{"id": "stats", "title": "属性", "desc": "数值和加成来源、装备套装、心法技能、轮回规矩（%s）" % TouchPad.hint(ArpgInput.key_name(0, "stats") + " 键", "右上角“属”")},
		{"id": "music", "title": "音乐音量", "right": pct.call("music"), "desc": TouchPad.hint("按确认键切换", "点一下切换")},
		{"id": "sfx", "title": "音效音量", "right": pct.call("sfx"), "desc": TouchPad.hint("按确认键切换", "点一下切换")},
		{"id": "quality", "title": "画质", "right": QUALITY_NAMES[quality], "desc": "低：关阴影和辉光，降低渲染分辨率，适合网页和轻薄本"},
		{"id": "diff", "title": "难度", "right": ArpgState.DIFF_NAMES[ArpgState.difficulty()], "desc": ArpgState.DIFF_DESC[ArpgState.difficulty()]},
		{"id": "impact", "title": "冲击帧", "right": "开" if bool(Game.settings.get("impact_frames", true)) else "关", "desc": "清完一波、斩精英、见切时整屏黑白定格一瞬；对闪光敏感可以关掉"}]
	if TouchPad.active:
		items.insert(5, {"id": "touchsize", "title": "按键大小", "right": TouchPad.SIZE_NAMES[TouchPad.size_i], "desc": "右下角触屏按键的大小（小 → 中 → 大）"})
	items.append({"id": "ach", "title": "成就", "right": "%d / %d" % [ArpgAch.count(), ArpgAch.LIST.size()], "desc": "看看做到了哪些"})
	items.append({"id": "guide", "title": "新手提示", "right": "开" if ArpgHints.enabled() else "关", "desc": "开关提示、回看全部提示、重新提示一遍"})
	if mode == "room":
		items.append({"id": "run", "title": "这一局", "desc": "路线图、天象、心法、流派、双修和连携"})
		items.append({"id": "giveup", "title": "放弃这一局", "desc": "回到山门，魂玉带回六成"})
		items.append({"id": "skills", "title": "技能分支", "right": "天赋点 %d" % state.points if state.points > 0 else "悟道 %s重" % Hud3D._cn(state.level),
			"desc": "斩敌悟道，每升一重得 1 个天赋点，用来点招式的分支"})
	_pause_ids = items.map(func(it: Dictionary) -> String: return String(it["id"]))
	var m := _open_menu("暂停", "", items, "list", true)
	m.index = maxi(0, _pause_ids.find(sel)) if sel is String else clampi(int(sel), 0, items.size() - 1)
	m.chosen.connect(_on_pause_chosen)


func _on_pause_chosen(i: int) -> void:
	var id := String(_pause_ids[i]) if i < _pause_ids.size() else "resume"
	match id:
		"music", "sfx":
			var k := id
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
			_open_pause(id)
		"quality":
			apply_quality((quality + 2) % 3)   # 高 → 中 → 低 → 高
			Game.settings["quality"] = quality
			Game.write_settings()
			_fps_checked = true
			Game.sfx("coin")
			_open_pause(id)
		"impact":
			Game.settings["impact_frames"] = not bool(Game.settings.get("impact_frames", true))
			Game.write_settings()
			Game.sfx("coin")
			_open_pause(id)
		"touchsize":
			TouchPad.size_i = (TouchPad.size_i + 1) % 3
			Game.settings["touch_size"] = TouchPad.size_i
			Game.write_settings()
			Game.sfx("coin")
			_open_pause(id)
		"diff":
			Game.save["arpg_diff"] = 1 - ArpgState.difficulty()
			Game.write_save()
			if state != null and is_instance_valid(hero):
				hero.apply_stats(state.stats(), state.weapon)
			elif mode == "hub" and is_instance_valid(hero):
				_hub_stats()
			Game.sfx("coin")
			_open_pause(id)
		"stats":
			_open_stats(true)
		"ach":
			_open_achievements(true)
		"guide":
			hints.open_menu(func() -> void: _open_pause("guide"))
		"run":
			_open_run_info()
		"giveup":
			_close_menu()
			_game_over(false)
		"skills":
			_open_skills(-1, true)
		_:
			_close_menu()


## 属性面板（暂停菜单“属性”、C 键、触屏“属”）。局里看这一局的主角，山门里看出发时的样子
func _open_stats(from_pause: bool = false, tab: int = 0) -> void:
	if not is_instance_valid(hero):
		return
	var hub := mode == "hub" or state == null
	_close_menu()
	var m := ArpgStatsPanel.new()
	m.hero = hero
	m.in_hub = hub
	m.state = ArpgState.preview() if hub else state
	m.tab = tab
	m.cancellable = true
	ui_layer.add_child(m)
	if from_pause:
		m.cancelled.connect(func() -> void: _open_pause("stats"), CONNECT_DEFERRED)
	else:
		m.cancelled.connect(_close_menu)
	_menu = m
	hud.visible = false
	hero.clear_buffer()
	hints.menu_tip("stats_menu", m)


## 山门里主角的数值：按“出发时”的样子算（天赋 + 兵器架的兵器 + 轮回级 + 难度），属性面板和试刀看到的一样
func _hub_stats() -> void:
	hero.apply_stats(ArpgState.preview().stats(), String(Game.save.get("arpg_weapon", "sword")), true)


## 暂停菜单“这一局”：上面画整层路线图，下面列天象、心法流派进度
func _open_run_info() -> void:
	var items := []
	if state.cycle > 0:
		items.append({"title": ArpgCycle.label(state.cycle), "desc": ArpgCycle.summary(state.cycle), "tag": "轮回", "tag_color": Color(0.85, 0.6, 1.0)})
	if state.omen != "":
		var om: Dictionary = ArpgState.OMENS[state.omen]
		items.append({"title": "天象 · %s" % om["name"], "desc": om["desc"], "tag": "天象"})
	if String(state.daily.get("kind", "")) == "daily":
		var rd: Dictionary = ArpgDaily.RULES.get(String(state.daily.get("rule", "")), {})
		items.append({"title": "每日挑战 · %s" % ArpgDaily.date_cn(String(state.daily.get("date", ""))), "desc": "今日规矩「%s」：%s" % [rd.get("name", ""), rd.get("desc", "")], "tag": "每日", "color": ArpgDaily.C_BOARD})
	items.append({"title": "种子 %d" % state.seed_value, "desc": "同一个种子，房间和路线都一样。回山门后告示牌上能“重走上一局的图”", "tag": "种子"})
	for k in range(2):
		var w: Dictionary = state.arms[k]
		if not w.is_empty():
			items.append({"title": "%s · %s" % ["主手" if k == 0 else "副手", w["name"]], "desc": ArpgGear.describe(w), "tag": "兵器", "color": ArpgGear.color(w)})
	var gsc := ArpgArms.set_counts(state.gear)
	for sid: String in gsc:
		var gs: Dictionary = ArpgArms.GEAR_SETS[sid]
		var gn := int(gsc[sid])
		items.append({"title": "套装「%s」" % gs["name"], "right": "%d / 3" % mini(gn, 3), "desc": "两件 %s；三件 %s" % [gs["d2"], gs["d3"]],
			"color": gs["color"], "enabled": gn >= 2, "tag": "套装"})
	var sc := ArpgData.school_counts(state.boons)
	for k: String in ArpgData.SETS:
		var n := int(sc.get(k, 0))
		var st: Dictionary = ArpgData.SETS[k]
		items.append({"title": "%s「%s」" % [k, st["name"]], "right": "已大成" if n >= ArpgData.SET_NEED else "%d / %d" % [n, ArpgData.SET_NEED],
			"desc": st["desc"], "color": ArpgData.SCHOOL_COLORS.get(k, ArpgMenu.TEAL), "enabled": n >= ArpgData.SET_NEED})
	var ds := ArpgSkills.duals_of(state.boons)
	for d: Dictionary in ArpgSkills.DUALS:
		var on := ds.has(String(d["id"]))
		var sc2 := ArpgData.school_counts(state.boons)
		items.append({"tag": "双修", "title": "%s + %s「%s」" % [d["a"], d["b"], d["name"]], "desc": d["desc"],
			"right": "已成" if on else "%d / %d" % [mini(int(sc2.get(d["a"], 0)), ArpgSkills.DUAL_NEED) + mini(int(sc2.get(d["b"], 0)), ArpgSkills.DUAL_NEED), ArpgSkills.DUAL_NEED * 2],
			"color": ArpgData.SCHOOL_COLORS.get(d["a"], ArpgMenu.TEAL), "enabled": on})
	for l: Dictionary in ArpgSkills.LINKS:
		var got := state.links_done.has(String(l["id"]))
		items.append({"tag": "连携", "title": String(l["name"]), "desc": l["desc"], "right": "这一局打出过" if got else "",
			"color": l["color"], "enabled": got})
	var m := _open_menu("这一局", "%s　第 %d 层　第 %d / %d 间　心法 %d 个" % [ArpgState.ACT_NAMES[state.act], state.gfloor() + 1, state.run.row + 1, state.run.rows.size(), state.boons.size()], items, "list", true)
	m.extra_draw = func(c: Control, vs: Vector2) -> void: _draw_map(c, vs, [], vs.y - 150.0)   # 列表下面
	m.chosen.connect(func(_i: int) -> void: _open_pause("run"))
	m.cancelled.connect(func() -> void: _open_pause("run"), CONNECT_DEFERRED)


## 成就列表（山门功业碑、暂停菜单）。from_pause 时返回回到暂停菜单
func _open_achievements(from_pause: bool = false) -> void:
	var m := _open_menu("功业碑", "已达成 %d / %d　　成就跨局永久保存" % [ArpgAch.count(), ArpgAch.LIST.size()], ArpgAch.menu_items(), "list", true)
	if from_pause:
		m.cancelled.connect(func() -> void: _open_pause("ach"), CONNECT_DEFERRED)


func _close_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	hud.visible = mode != "title"
	if is_instance_valid(hero):
		hero.clear_buffer()


# ---------- 局中断点（关掉游戏后接着打） ----------
## 主角身上要跟着存的数值（新加的跨房间数值写进这里）
const CKPT_HERO := ["hp", "gourds", "energy", "revives", "drinks", "hits_taken", "dmg_total"]


## 每进一间房存一次：一局的全部状态 + 主角的血、药、气力。下次打开从这间房的入口重来
func _save_checkpoint(kind: String, zone_override: String) -> void:
	if state == null or room_kind == "tutorial" or (_args.has("demo") and not _args.has("ckpt")) or _args.has("storytest"):
		return
	var hd := {}
	for k: String in CKPT_HERO:
		hd[k] = hero.get(k)
	Game.write_checkpoint({"state": state.to_dict(), "hero": hd, "kind": kind, "zone": zone_override,
		"elapsed": _clock - _run_t0, "where": "%s　第 %d 层　第 %d / %d 间" % [ArpgState.ACT_NAMES.get(state.act, ""), state.gfloor() + 1, state.run.row + 1, state.run.rows.size()]})


## 标题画面之后发现有没打完的一局：继续，或者放弃（按倒下结算）
func _offer_resume(ck: Dictionary) -> void:
	var s := ArpgState.from_dict(ck.get("state", {}) if ck.get("state") is Dictionary else {})
	if s == null:
		push_warning("局中断点读不出来，丢掉")
		Game.clear_checkpoint()
		_after_title_go()
		return
	var keep := int(floor(s.jade * (0.6 + ArpgData.stat(s.stats(), "keep"))))
	var items := [{"title": "接着打", "desc": "回到上次那间房的入口重打这间，身上的心法、装备、铜钱、魂玉、生命和药都还在", "tag": "继续", "glyph": "续",
			"color": Color(0.5, 1.0, 0.75)},
		{"title": "不打了", "desc": "这一局按倒下算：魂玉 %d 带回 %d，回到山门" % [s.jade, keep], "glyph": "归", "color": Color(1.0, 0.6, 0.45)}]
	var m := _open_menu("上一局还没打完", String(ck.get("where", "")), items, "cards", false)
	if _args.has("resume"):
		m.index = clampi(int(_args["resume"]), 0, 1)   # 测试：预先选好
	m.chosen.connect(func(i: int) -> void:
		_close_menu()
		if i == 0:
			_resume_run(s, ck)
			return
		state = s
		var r := state.settle(false)
		print("放弃上一局：魂玉 %d 带回 %d" % [r["jade"], r["kept"]])
		ArpgAch.check_save()
		Game.clear_checkpoint()
		state = null
		_enter_hub())


func _resume_run(s: ArpgState, ck: Dictionary) -> void:
	state = s
	ArpgState.cur = s
	_ensure_hero()
	hero.reset_for_run()
	hero.kit = state
	hero.apply_stats(state.stats(), state.weapon, true)
	var hd: Dictionary = ck.get("hero", {}) if ck.get("hero") is Dictionary else {}
	SaveStore.load_vars(hero, hd)
	hero.hp = clampf(hero.hp, 1.0, hero.max_hp)
	hero.gourds = clampi(hero.gourds, 0, hero.max_gourds)
	hero.energy = clampf(hero.energy, 0.0, hero.max_energy)
	_run_t0 = _clock - float(ck.get("elapsed", 0.0))
	print("接着上一局：%s　生命 %.0f/%.0f　药 %d　铜钱 %d　魂玉 %d　心法 %d" % [String(ck.get("where", "")), hero.hp, hero.max_hp, hero.gourds, state.coins, state.jade, state.boons.size()])
	_enter_room(String(ck.get("kind", "")), String(ck.get("zone", "")))


# ---------- 死亡、结算 ----------

func _on_hero_died(_a: Actor) -> void:
	if mode != "room":
		return
	hud.banner("败", "残刃折于此地", 2.5)
	feel.screen_flash(Color(0.5, 0.0, 0.0, 0.6), 0.8)
	var fl := _retry_key()
	if room_kind == "boss" and ArpgState.difficulty() == 0 and not state.boss_retry.has(fl):
		get_tree().create_timer(2.2).timeout.connect(_offer_boss_retry)
		return
	if state.flags.has("finale"):
		# 终章：倒在烛王面前不丢这一局，推回金殿照常选结局
		get_tree().create_timer(2.2).timeout.connect(func() -> void: Finale.fallen(self))
		return
	get_tree().create_timer(2.2).timeout.connect(func() -> void: _game_over(false))


## 游历的“再战一次”按哪一层记：终章的烛王单独算一次
func _retry_key() -> int:
	return 99 if state.flags.has("finale") else state.floor_i()


## 游历难度：倒在头目面前，可以回满血、补满药再打一次（每层一次）
func _offer_boss_retry() -> void:
	if mode != "room":
		return
	var items := [{"title": "再战一次", "desc": "回满生命、补满药葫芦，从头目登场重来（这一层只有一次）", "tag": "游历"},
		{"title": "就此作罢", "desc": "回到山门，魂玉带回六成"}]
	var m := _open_menu("再战？", "%s还站着" % hud.zone_name, items, "cards", false)
	m.chosen.connect(func(i: int) -> void:
		_close_menu()
		if i == 1:
			if state.flags.has("finale"):
				Finale.fallen(self)
				return
			_game_over(false)
			return
		state.boss_retry[_retry_key()] = true
		_ensure_hero()
		hero.reset_for_run()
		hero.apply_stats(state.stats(), state.weapon, true)
		hero.revives = 0
		_boss_retry = true
		_fade_then(func() -> void: _enter_room("boss")))


func _game_over(won: bool, ending: String = "") -> void:
	if mode == "over":
		return
	_tel_print("won" if won else "dead")
	if _args.has("quitend"):
		_bench_end(won)
	mode = "over"
	var r := state.settle(won)
	Game.clear_checkpoint()
	var cyc_lines: Array = ArpgCycle.on_clear(state) if won else []
	ArpgAch.check_save()   # 首次身死、累计身死、登顶次数
	if won:
		if _clock - _run_t0 <= 20.0 * 60.0:
			ArpgAch.unlock("clear_fast")
		if is_instance_valid(hero) and hero.drinks == 0:
			ArpgAch.unlock("clear_dry")
	var sub := "第 %d 层　走过 %d 间　斩敌 %d　铜钱 %d" % [r["floor"], r["rooms"], r["kills"], r["coins"]]
	var desc := "魂玉 %d，全部带回" % r["jade"] if won else "魂玉 %d，带回 %d" % [r["jade"], r["kept"]]
	if state.cycle > 0:
		sub += "　" + ArpgCycle.label(state.cycle)
	var items := [{"title": "回到山门", "desc": desc, "right": "存档魂玉 %d" % int(Game.save["jade"])}]
	for cl: String in cyc_lines:
		items.append({"title": "轮回", "desc": cl, "tag": "轮回", "color": Color(0.85, 0.6, 1.0)})
	for dl: String in ArpgDaily.on_end(self, won):
		items.append({"title": "每日挑战", "desc": dl, "tag": "每日", "color": ArpgDaily.C_BOARD})
	var m := _open_menu(ending if ending != "" else ("登顶" if won else "身死"), sub, items, "list", false)
	m.chosen.connect(func(_i: int) -> void:
		_close_menu()
		feel.screen_flash(Color(0, 0, 0, 1), 0.0)
		_enter_hub())
	if not cyc_lines.is_empty():
		Game.sfx("reward")


# ---------- 每帧 ----------

func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec() if PerfProbe.on else 0
	_process_body(dt)
	if PerfProbe.on:
		PerfProbe.add("main", _pt)


func _process_body(dt: float) -> void:
	if mode == "room" and room_kind == "tutorial":
		_tut_tick(dt)
	if not _tel.is_empty():
		_tel["t"] = float(_tel["t"]) + dt
		if _args.has("tel") and not _room_done and int(float(_tel["t"]) / 30.0) != int((float(_tel["t"]) - dt) / 30.0) and float(_tel["t"]) > 80.0:
			var out := []
			for f: Node in get_tree().get_nodes_in_group("foes"):
				var a := f as Foe
				out.append("%s hp%d %s %s" % [a.kind, int(a.hp), a.state, str(a.global_position.snapped(Vector3.ONE * 0.1))])
			print("SLOW %s t=%d wi=%d/%d hold=%s hero=%s foes=%s" % [room_kind, int(_tel["t"]), wave_i, waves.size(), _hold_waves, str(hero.global_position.snapped(Vector3.ONE * 0.1)), out])
		if _args.has("quitend") and not _room_done and float(_tel["t"]) > BENCH_STALL and mode == "room":
			print("STALL %s act=%d floor=%d row=%d t=%d wi=%d/%d" % [room_kind, state.act, state.floor_i() + 1, state.run.row, int(_tel["t"]), wave_i, waves.size()])
			_tel.clear()
			get_tree().quit(3)
	if arena != null and cam_rig.cam != null and is_instance_valid(hero):
		arena.update_occluders(cam_rig.cam, [hero])
	if state != null:
		hud.coins = state.coins
		hud.jade = state.jade
		hud.level = state.level if mode == "room" else 0
		hud.xp_k = float(state.xp) / ArpgSkills.need(state.level) if state.level < ArpgSkills.MAX_LEVEL else 1.0
		hud.points = state.points if ArpgSkills.any_open(state.skills, state.points) else 0
		if state.coins >= 300:
			ArpgAch.unlock("rich")
	if feel.combo >= 25:
		ArpgAch.combo(feel.combo)
	_clock += dt
	_watch_fps(dt)
	_light_budget(dt)
	if _args.has("nohud"):
		hud.visible = false   # 拍宣传图用
	if _args.has("dbg") and int(_clock * 2.0) != int((_clock - dt) * 2.0):
		var out := []
		for f: Node in get_tree().get_nodes_in_group("foes"):
			var a := f as Foe
			out.append("%s hp%d %s %s alive%s" % [a.kind, int(a.hp), a.state, str(a.global_position.snapped(Vector3.ONE * 0.1)), a.alive])
		print("wp=%.2f menu=%s cam=%s t=%d %s done=%s wd=%.2f wi=%d alive=%s hero=%s %s foes=%s" % [feel.world_pause, is_instance_valid(_menu), str(cam_rig.cam.global_position.snapped(Vector3.ONE*0.1)) if cam_rig.cam else "", int(_clock), mode, _room_done, _wave_delay, wave_i, hero.alive, str(hero.global_position.snapped(Vector3.ONE * 0.1)), hero.state, out])
	if _feel_t > 0.0 and _clock >= _feel_t:
		_feel_t = 0.0
		_feel_test()
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
			and (Input.is_action_just_pressed(ArpgInput.act(0, "stats")) or Input.is_action_just_pressed(ArpgInput.act(1, "stats"))):
		_open_stats()
	if (mode == "room" or mode == "hub") and _menu == null and _no_dialog() and is_instance_valid(hero) and hero.alive \
			and Input.is_action_just_pressed("quit"):
		_open_pause()
	if mode == "room" and is_instance_valid(_trial) and not _room_done:
		_trial.tick(dt)
		hud.seals = _trial.results
	for sp: Node3D in _extra_portals:
		if is_instance_valid(sp):
			sp.rotation.y += dt
			if not _going and _menu == null and is_instance_valid(hero) and hero.alive:
				var dd := hero.global_position - sp.global_position
				dd.y = 0
				if dd.length() < 1.3:
					_going = true
					Game.sfx("door")
					if String(sp.get_meta("kind", "secret")) == "act2":
						# 山门的“入井”光门：开第二幕的一局
						_start_run(true, 2)
						_fade_then(func() -> void: _enter_room())
					elif String(sp.get_meta("kind", "secret")) == "act3":
						# 山门的“出山”光门：开第三幕的一局
						_start_run(true, 3)
						_fade_then(func() -> void: _enter_room())
					else:
						var sk := String(sp.get_meta("kind", "secret"))   # secret 裂墙密室 / realm 秘境
						_fade_then(func() -> void: _enter_room(sk))
	_watch_stuck(dt)
	_bench_watch()
	_flush_pending_weapons()
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


## 防卡死：敌人没有寻路，偶尔会被障碍物、墙角卡住，主角也绕不过去，这一波就清不完、门永远不开。
## 场上只剩三只以内、STUCK_SECS 秒里谁都没掉血也没打到主角时，把离主角远的挪到主角附近的刷怪点。
const STUCK_SECS := 12.0
var _stuck_t := 0.0
var _stuck_sig := -1.0


func _watch_stuck(dt: float) -> void:
	# 头目房不管（长明帝的护体灯是钉在原地的，不能挪）
	if mode != "room" or _room_done or room_kind == "boss" or not is_instance_valid(hero) or not hero.alive or arena == null or is_instance_valid(_menu):
		_stuck_t = 0.0
		return
	var foes := get_tree().get_nodes_in_group("foes")
	if foes.is_empty() or foes.size() > 3:
		_stuck_t = 0.0
		return
	var sig := float(hero.hits_taken) * 10000.0
	for f: Node in foes:
		sig += float((f as Actor).hp)
	if absf(sig - _stuck_sig) > 0.01:
		_stuck_sig = sig
		_stuck_t = 0.0
		return
	_stuck_t += dt
	if _stuck_t < STUCK_SECS:
		return
	_stuck_t = 0.0
	var hp3 := hero.global_position
	for f: Node in foes:
		var a := f as Foe
		if a == null or not a.alive or a.is_boss or a.state == "lurk" or a.global_position.distance_to(hp3) < 4.5:
			continue
		var best := Vector3.INF
		for q: Vector3 in arena.spawn_points:
			var d := q.distance_to(hp3)
			if d >= 4.0 and (best == Vector3.INF or d < best.distance_to(hp3)):
				best = q
		if best == Vector3.INF:
			continue
		if _args.has("tel"):
			print("UNSTICK %s %s -> %s" % [a.kind, str(a.global_position.snapped(Vector3.ONE * 0.1)), str(best.snapped(Vector3.ONE * 0.1))])
		vfx.sheet("spawn-cast", a.global_position, 3.0, Color.WHITE, 1.2)
		a.global_position = best
		a.velocity = Vector3.ZERO
		vfx.sheet("spawn-cast", best, 3.0, Color.WHITE, 1.2)


# ---------- 测试：故事线（--storytest=hub / shadow / lore / souls / zen，会改写存档里的故事线进度，只在云端测试用） ----------

func _story_test_save(c: String) -> void:
	match c:
		"hub":
			Game.save["deaths"] = 3
			Game.save["arpg_intro"] = true
			Game.save["arpg_mutter"] = 0
			Game.save["arpg_kite"] = 3
			Game.save["arpg_name_list"] = true
			Game.save["arpg_names"] = range(12)
			Game.save["arpg_page6"] = true
			Game.save["arpg_pages"] = [0, 1]
		"shadow":
			Game.save["arpg_names"] = range(12)
			Game.save["arpg_shadow"] = false
		"lore":
			Game.save["arpg_kite"] = 2
			Game.save["arpg_name_list"] = true
			Game.save["arpg_names"] = range(10)
		"zen":
			Game.save["arpg_pages"] = [0, 1, 2, 3, 4]
			Game.save["arpg_endings"] = {"true": true}
			Game.save["arpg_page6"] = false
		"act2", "act2keep", "act2boss":
			# 第二幕：第一幕看过结局、救过阿七、听守灯僧讲完
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_last_end"] = "keep" if c == "act2keep" else "douse"
			Game.save["arpg_act1"] = {"ronin": "ronin_saved", "monk": "monk_told", "sakura": "sakura_rest"}
			Game.save["arpg_enc_seen"] = []
		"act2hub":
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_act2_runs"] = 1
			Game.save["arpg_smith_met"] = false
			Game.save["arpg_jizo_home"] = true
			Game.save.erase("arpg_bless")
		"jizo":
			Game.save["arpg_jizo_head"] = true
			Game.save["arpg_jizo_home"] = false
		"campboss", "campend":
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_last_end"] = "douse"
			Game.save["arpg_act1"] = {"ronin": "ronin_saved"}
			Game.save["arpg_smith_met"] = true
			Game.save["arpg_smith"] = ["iron", "bronze", "seal"]
			Game.save["arpg_smith_done"] = false
			Game.save["arpg_letters"] = 4 if c == "campend" else 0
			Game.save["arpg_enc_seen"] = []
		"monk":
			Game.save["arpg_intro"] = true
			Game.save["arpg_mutter"] = 99
			Game.save["arpg_hag_told"] = true
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_act2_runs"] = 2
			Game.save["arpg_monk_met"] = false
			Game.save.erase("arpg_monk_buy")
			Game.save["jade"] = maxi(int(Game.save.get("jade", 0)), 40)
		"vaultboss", "vaultmold":
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_last_end"] = "douse"
			Game.save["arpg_act1"] = {"grave": "iron_helm", "ronin": "ronin_saved"}
			Game.save["arpg_smith_met"] = true
			Game.save["arpg_smith"] = ["iron"]
			Game.save["arpg_enc_seen"] = []
		"hag":
			Game.save["arpg_intro"] = true
			Game.save["arpg_mutter"] = 99
			Game.save["arpg_hag_mural"] = true
			Game.save["arpg_hag_told"] = false
			Game.save["arpg_shard"] = true
		"act3", "act3boss", "act3end", "act3hub":
			# 第三幕：第二幕看过合刃、救过阿七、见过刀匠；act3end 七村名录认齐（看真结局）
			Game.save["arpg_endings"] = {"douse": true}
			Game.save["arpg_act2_endings"] = {"he": true} if c != "act3" else {"du": true}
			Game.save["arpg_last_end2"] = "he" if c != "act3" else "du"
			Game.save["arpg_act1"] = {"ronin": "ronin_saved"}
			Game.save["arpg_smith_met"] = true
			Game.save["arpg_enc_seen"] = []
			Game.save["arpg_villages"] = range(7) if c == "act3end" else ([0, 1] if c == "act3hub" else [])
			Game.save["arpg_ahe_home"] = c == "act3hub"
			Game.save["arpg_intro"] = true
			Game.save["arpg_mutter"] = 99
			Game.save["arpg_hag_told"] = true


func _story_test(c: String) -> void:
	print("STORYTEST ", c)
	match c:
		"hub":
			_read_names(null)
			get_tree().create_timer(0.5).timeout.connect(func() -> void: _read_pages(null))
		"shadow":
			for n: ArpgNpc in _npcs:
				if is_instance_valid(n) and n.display == "第十三座坟":
					for e: Dictionary in ArpgStory.ENCOUNTERS:
						if e["id"] == "shadow":
							_say(e["lines"])
							_story_effect(e["options"][0][2], n)
					print("STORYTEST fight kind=%s waves=%s done=%s" % [room_kind, str(waves), _room_done])
					get_tree().create_timer(3.0).timeout.connect(func() -> void:
						for f: Node in get_tree().get_nodes_in_group("foes"):
							print("STORYTEST foe %s hp=%d" % [(f as Foe).kind, int((f as Foe).hp)]))
					return
			print("STORYTEST 没有第十三座坟")
		"lore":
			var lines := []
			for sr: SideRoom in side_rooms:
				sr._story_finds(lines)
			_say(lines)
			print("STORYTEST kite=%d names=%d" % [ArpgStory.kite(), ArpgStory.names().size()])
		"souls":
			for f: String in ArpgStory.ALL_SOULS_NEED:
				state.flags[f] = true
			_ending_choice()
		"act2", "act2keep":
			# 第二幕第一间：开场白（按第一幕结局）+ 井壁刻字；再看这一局的剧情遭遇轮到哪段
			_start_run(true, 2)
			_enter_room("start")
			print("STORYTEST act=%d gfloor=%d zone=%s omen=%s flags=%s" % [state.act, state.gfloor(), state.zone(), state.omen, str(state.flags)])
			for i in range(3):
				var en := ArpgStory.encounter_for(state.gfloor(), state.flags, state.seen)
				print("STORYTEST encounter %s" % String(en.get("id", "-")))
				if not en.is_empty():
					ArpgStory.mark_seen(String(en["id"]))
		"act2boss":
			_start_run(true, 2)
			_enter_room("boss")
			state.flags["ronin_forgiven"] = true
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				_close_menu()
				_boss_outro(0))
		"campboss", "campend":
			if _title != null:
				_title.queue_free()
				_title = null
			_start_run(true, 2)
			state.run.next_floor()
			state.remap()
			state.run.next_floor()
			state.remap()
			state.flags["ronin_forgiven"] = true
			print("STORYTEST camp encounter %s" % String(ArpgStory.encounter_for(state.gfloor(), state.flags, state.seen).get("id", "-")))
			print("STORYTEST camp fight waves %s" % str(_make_waves("fight", state.floor_i())))
			print("STORYTEST camp elite waves %s" % str(_make_waves("elite", state.floor_i())))
			if c == "campend":
				# 刀匠：三样齐了，去山门找他打刀镡；小满放出来；找到第五封家书
				_talk_smith(null)
				state.flags["xiaoman"] = true
				_story_effect({"letter": 1}, null)
			_enter_room("boss")
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				_close_menu()
				for f: Node in get_tree().get_nodes_in_group("foes"):
					f.queue_free()
				hero.invincible = true
				print("STORYTEST xiaoman follower %s" % str(is_instance_valid(_xiaoman)))
				if c == "campend":
					_act2_ending()
					var mm := _menu as ArpgMenu
					print("STORYTEST ending enabled %s" % str(mm.items.map(func(it: Dictionary) -> bool: return bool(it.get("enabled", true)))))
					mm.chosen.emit(2)
				else:
					_boss_outro(2))
		"monk":
			get_tree().create_timer(6.0).timeout.connect(func() -> void:
				for n: ArpgNpc in _npcs:
					if is_instance_valid(n) and n.display.begins_with("守灯僧"):
						n.interacted.emit(n)
				get_tree().create_timer(12.0).timeout.connect(func() -> void:
					print("STORYTEST monk buy=%s jade=%d" % [String(Game.save.get("arpg_monk_buy", "")), int(Game.save["jade"])])))
		"vaultboss", "vaultmold":
			if _title != null:
				_title.queue_free()
				_title = null
			_start_run(true, 2)
			state.run.next_floor()
			state.remap()
			state.flags["kurong_shard"] = true
			print("STORYTEST vault encounter %s" % String(ArpgStory.encounter_for(state.gfloor(), state.flags, state.seen).get("id", "-")))
			print("STORYTEST vault fight waves %s" % str(_make_waves("fight", state.floor_i())))
			_enter_room("boss")
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				_close_menu()
				for f: Node in get_tree().get_nodes_in_group("foes"):
					f.queue_free()
				hero.invincible = true
				if c == "vaultmold":
					_vault_choice()
					(_menu as ArpgMenu).chosen.emit(1)
				else:
					_boss_outro(1))
		"act2hub":
			for n: ArpgNpc in _npcs:
				print("STORYTEST npc %s" % n.display)
				if n.display.begins_with("老刀匠"):
					n.interacted.emit(n)
			print("STORYTEST portals %s" % str(_extra_portals.map(func(p: Node3D) -> String: return String(p.get_meta("kind", "")))))
		"jizo":
			_start_run(true, 1)
			print("STORYTEST jizo encounter %s" % String(ArpgStory.encounter_for(0, state.flags, state.seen).get("id", "-")))
		"act3":
			# 第三幕三层：开场、剧情遭遇轮到哪段、各层的阵
			if _title != null:
				_title.queue_free()
				_title = null
			_start_run(true, 3)
			for fl in range(3):
				print("STORYTEST act3 floor=%d gfloor=%d zone=%s boss=%s flags=%s" % [fl, state.gfloor(), state.zone(), state.boss_kind(), str(state.flags.keys())])
				for i in range(4):
					var en := ArpgStory.encounter_for(state.gfloor(), state.flags, state.seen)
					print("STORYTEST encounter %s" % String(en.get("id", "-")))
					if not en.is_empty():
						ArpgStory.mark_seen(String(en["id"]))
						state.seen[en["id"]] = true
				print("STORYTEST fight waves %s" % str(_make_waves("fight", state.floor_i())))
				print("STORYTEST elite waves %s" % str(_make_waves("elite", state.floor_i())))
				if fl < 2:
					state.run.next_floor()
					state.remap()
			_start_run(true, 3)
			_enter_room("start")
		"act3boss", "act3end":
			if _title != null:
				_title.queue_free()
				_title = null
			_start_run(true, 3)
			for i in range(2):
				state.run.next_floor()
				state.remap()
			state.flags["jin_along"] = true
			_enter_room("boss")
			get_tree().create_timer(5.0).timeout.connect(func() -> void:
				_close_menu()
				for f: Node in get_tree().get_nodes_in_group("foes"):
					f.queue_free()
				hero.invincible = true
				print("STORYTEST jin follower %s revives %d" % [str(is_instance_valid(Act3._jin)), hero.revives])
				Act3.final_choice(self)
				var mm := _menu as ArpgMenu
				print("STORYTEST ending enabled %s" % str(mm.items.map(func(it: Dictionary) -> bool: return bool(it.get("enabled", true)))))
				if c == "act3end":
					mm.chosen.emit(2))
		"route":
			# 分岔支线：打印三层的地图（列数、支线在哪），然后直接走到第一层支线尽头，拿第一样
			if _title != null:
				_title.queue_free()
				_title = null
			_start_run(true, 3)
			for fl in range(3):
				var desc := []
				for r: Array in state.run.rows:
					desc.append("".join(r.map(func(nd: Dictionary) -> String: return String(ArpgState.TYPE_NAMES.get(nd["type"], "?")).substr(0, 1) + ("*" if nd.has("branch") else ""))))
				print("STORYTEST route floor=%d rows=%d %s" % [fl, state.run.rows.size(), " | ".join(desc)])
				if fl < 2:
					state.run.next_floor()
					state.remap()
			_start_run(true, 3)
			for r in range(state.run.rows.size()):
				for i in range((state.run.rows[r] as Array).size()):
					if String(state.run.rows[r][i]["type"]) == "nook":
						state.run.row = r
						state.run.col = i
			print("STORYTEST tag %s" % ArpgRoutes.card_tag(state.run.node()))
			_enter_room()
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				for n: ArpgNpc in _npcs:
					if is_instance_valid(n) and n.display == "山神庙":
						n.interacted.emit(n)
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					var dd := _menu as DialogBox
					if dd != null:
						dd.finished.emit()
					get_tree().create_timer(0.5).timeout.connect(func() -> void:
						if _menu is ArpgMenu:
							(_menu as ArpgMenu).chosen.emit(0)
						print("STORYTEST route_stats %s max_hp %d" % [str(state.flags.get("route_stats", {})), int(hero.max_hp)]))))
		"act3hub":
			for n: ArpgNpc in _npcs:
				print("STORYTEST npc %s" % n.display)
			print("STORYTEST portals %s" % str(_extra_portals.map(func(p: Node3D) -> String: return String(p.get_meta("kind", "")))))
		"zen":
			for n: ArpgNpc in _npcs:
				if is_instance_valid(n) and n.display == "两把木刀":
					n.interacted.emit(n)
					return
			print("STORYTEST 没有禅房")
