extends Node
## 体素样例演示：搭一间荒村小道，主角对浪人，按时间表自动按键，用来截图、录 GIF。
##   截图：xvfb-run godot --path . res://tools/voxel_demo/voxel_demo.tscn -- shots
##   录像：xvfb-run godot --path . --fixed-fps 30 --write-movie /tmp/f.png res://tools/voxel_demo/voxel_demo.tscn
## 不是自动测试，不进 tests/。

var main: Node
var t := 0.0
var shots := false
var _shot_i := 0
var ronin: Enemy

# [开始秒, 结束秒, 动作]（按住），单按的用很短的区间
const SCRIPT := [
	[0.6, 1.3, "p1_right"],
	[2.0, 2.05, "p1_jump"],
	[2.0, 2.3, "p1_right"],
	[3.0, 3.05, "p1_attack"], [3.3, 3.35, "p1_attack"], [3.6, 3.65, "p1_attack"], [3.9, 3.95, "p1_attack"], [4.2, 4.25, "p1_attack"],
	[5.0, 6.2, "p1_guard"],
	[6.6, 6.65, "p1_dodge"],
	[7.2, 7.25, "p1_attack"], [7.5, 7.55, "p1_attack"], [7.8, 7.85, "p1_attack"],
	[8.4, 9.6, "p1_guard"],
	[10.0, 10.05, "p1_attack"], [10.3, 10.35, "p1_attack"], [10.6, 10.65, "p1_attack"], [10.9, 10.95, "p1_attack"],
	[11.6, 12.6, "p1_left"],
	[12.7, 12.75, "p1_jump"], [12.9, 12.95, "p1_jump"],
]
const SHOT_TIMES := [1.2, 2.3, 3.45, 4.3, 5.6, 6.72, 6.8, 8.0, 10.5, 12.9]
const END := 14.0


func _ready() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	_run.call_deferred()


var tour := false
const TOUR_X := [300.0, 640.0, 1050.0, 1300.0, 1520.0, 1760.0]


func _run() -> void:
	tour = "tour" in OS.get_cmdline_user_args() or "gallery" in OS.get_cmdline_user_args()
	Game.save_path = "user://demo_save.cfg"
	Game.settings_path = "user://demo_settings.cfg"
	Game.title_done = true
	Game.voxel = not ("flat" in OS.get_cmdline_user_args())
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var room := "lane"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("room="):
			room = a.substr(5)
	var def: Dictionary = LevelData.ROOMS[room].duplicate(true)
	if not tour:
		def["waves"] = []
	main.mode = "practice"
	main._build_room(def)
	main._place_players(470.0)
	print("voxel room build ms: ", main.voxel.last_build_ms)
	if "gallery" in OS.get_cmdline_user_args():
		_gallery()
		return
	if "boss" in OS.get_cmdline_user_args():
		_boss()
		return
	if "feel" in OS.get_cmdline_user_args():
		_feel()
		return
	if tour:
		main.mode = "room"
		main.waves = def.get("waves", [])
		main._spawn_wave(0, true)
		ronin = main.enemies[0] if not main.enemies.is_empty() else null
		set_process(true)
		_tour()
		return
	ronin = main.spawn_enemy("ronin", Vector2(760.0, 300.0))
	ronin.hp = 9999.0
	ronin.max_hp = 9999.0
	set_process(true)


## 头目演示：断水河畔，柳江远开场白、亮名号，然后强行切到二、三阶段看气和眼睛
##   xvfb-run godot --path . res://tools/voxel_demo/voxel_demo.tscn -- boss
func _boss() -> void:
	var def: Dictionary = LevelData.room("river").duplicate(true)
	main.mode = "room"
	main._build_room(def)
	main._place_players(330.0)
	var boss: Enemy = main.enemies[0] if not main.enemies.is_empty() else main.spawn_enemy("liu", Vector2(600.0, 300.0))
	boss.start_intro(0)
	var plan := [[1.2, "shot"], [3.0, "shot"], [4.6, "shot"], [6.0, "guard"], [7.5, "shot"],
		[8.0, "phase"], [9.4, "shot"], [10.6, "shot"], [11.5, "phase"], [12.8, "shot"], [14.0, "shot"], [15.0, "end"]]
	var t0 := Time.get_ticks_msec()
	var k := 0
	var frames := 0
	for step: Array in plan:
		while frames / 30.0 < float(step[0]):
			await get_tree().process_frame
			frames += 1
			boss.hp = maxf(boss.hp, 50.0)
			for p in main.players:
				p.hp = p.max_hp
		match String(step[1]):
			"shot":
				get_viewport().get_texture().get_image().save_png("user://voxel_boss_%d.png" % k)
				print("boss shot ", k, " phase ", boss.phase, " state ", boss.state)
				k += 1
			"guard":
				Input.action_press("p1_guard")
			"phase":
				boss._next_phase()
			"end":
				Input.action_release("p1_guard")
				print("boss demo ms ", Time.get_ticks_msec() - t0)
				get_tree().quit()


## 快节奏手感演示：一群小怪（野狗、忍者、高处的弓手），机器人按“钩锁突进 → 空中连砍弹起 → 空中冲刺 → 再钩”打
##   xvfb-run godot --path . --fixed-fps 30 --write-movie /tmp/f.png res://tools/voxel_demo/voxel_demo.tscn -- feel
func _feel() -> void:
	var p: Player = main.players[0]
	p.global_position = Vector2(300.0, 300.0)
	for sp in [["dog", 560.0, 0.0], ["crow", 640.0, 120.0], ["shinobi", 760.0, 0.0], ["crow", 820.0, 140.0], ["shinobi", 880.0, 0.0], ["dog", 980.0, 0.0]]:
		var e: Enemy = main.spawn_enemy(sp[0], Vector2(sp[1], 300.0 - sp[2]))
		e.attack_cooldown = 1.5
	var frames := 0
	var held := {}
	var last_atk := 0
	while frames < 30 * 14:
		await get_tree().process_frame
		frames += 1
		p.hp = p.max_hp
		for a in held.keys():
			held[a] -= 1
			if held[a] <= 0:
				Input.action_release(a)
				held.erase(a)
		var press := func(a: String, n: int = 2) -> void:
			Input.action_press(a)
			held[a] = n
		var alive: Array = main.get_enemies().filter(func(e): return e.is_hittable())
		if alive.is_empty():
			if frames % 60 == 0:
				for sp in [["crow", p.global_position.x + 260.0, 130.0], ["shinobi", p.global_position.x + 340.0, 0.0], ["crow", p.global_position.x + 420.0, 110.0]]:
					main.spawn_enemy(sp[0], Vector2(minf(sp[1], main.arena_w - 40.0), 300.0 - sp[2])).attack_cooldown = 1.0
			press.call("p1_right", 4)
			continue
		var near: Enemy = alive[0]
		for e in alive:
			if absf(e.global_position.x - p.global_position.x) < absf(near.global_position.x - p.global_position.x):
				near = e
		var dx: float = near.global_position.x - p.global_position.x
		if p.state == Player.S.FREE and p.hook_cd <= 0.0 and absf(dx) > 60.0:
			press.call("p1_right" if dx > 0 else "p1_left", 3)
			press.call("p1_hook")
		elif p.state == Player.S.FREE and p.is_on_floor() and absf(dx) <= 60.0 and frames - last_atk > 6:
			press.call("p1_jump")
			last_atk = frames
		elif not p.is_on_floor() and frames - last_atk > 5:
			if p.air_dashes > 0 and absf(dx) > 90.0 and p.state == Player.S.FREE:
				press.call("p1_right" if dx > 0 else "p1_left", 3)
				press.call("p1_dodge")
			else:
				press.call("p1_attack")
			last_atk = frames
	print("feel demo done")
	get_tree().quit()


func _gallery() -> void:
	var k := 0
	for room in ["village_gate", "merchant", "roadside_shrine", "graves", "bamboo_path", "bandit_camp", "river", "temple"]:
		var def: Dictionary = LevelData.room(room).duplicate(true)
		def["waves"] = []
		main._build_room(def)
		main._place_players(min(260.0, float(def.get("width", 800.0)) * 0.3))
		for i in range(20):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("user://voxel_gallery_%d.png" % k)
		print("gallery ", room, " build ms ", main.voxel.last_build_ms)
		k += 1
	get_tree().quit()


func _tour() -> void:
	var k := 0
	for x: float in TOUR_X:
		for p in main.players:
			p.global_position = Vector2(x, 300.0)
		main.camera.position.x = clampf(x + 120.0, 320.0, main.arena_w - 320.0)
		for i in range(25):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://voxel_tour_%d.png" % k)
		print("tour ", k)
		k += 1
	get_tree().quit()


func _process(delta: float) -> void:
	if tour or main == null or ronin == null:
		return
	t += delta
	for s: Array in SCRIPT:
		var on: bool = t >= float(s[0]) and t < float(s[1])
		var a: String = s[2]
		if on and not Input.is_action_pressed(a):
			Input.action_press(a)
		elif not on and Input.is_action_pressed(a):
			var still := false
			for s2: Array in SCRIPT:
				if s2[2] == a and t >= float(s2[0]) and t < float(s2[1]):
					still = true
			if not still:
				Input.action_release(a)
	if shots and _shot_i < SHOT_TIMES.size() and t >= SHOT_TIMES[_shot_i]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://voxel_shot_%d.png" % _shot_i)
		print("shot ", _shot_i, " -> ", ProjectSettings.globalize_path("user://voxel_shot_%d.png" % _shot_i))
		_shot_i += 1
	if t >= END:
		get_tree().quit()
