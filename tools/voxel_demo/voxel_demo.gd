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
const SHOT_TIMES := [1.2, 2.3, 3.45, 4.3, 5.6, 8.0, 10.5, 12.9]
const END := 14.0


func _ready() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	Game.save_path = "user://demo_save.cfg"
	Game.settings_path = "user://demo_settings.cfg"
	Game.title_done = true
	Game.voxel = not ("flat" in OS.get_cmdline_user_args())
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var def: Dictionary = LevelData.ROOMS["lane"].duplicate(true)
	def["waves"] = []
	main.mode = "practice"
	main._build_room(def)
	main._place_players(470.0)
	print("voxel room build ms: ", main.voxel.last_build_ms)
	ronin = main.spawn_enemy("ronin", Vector2(760.0, 300.0))
	ronin.hp = 9999.0
	ronin.max_hp = 9999.0
	set_process(true)


func _process(delta: float) -> void:
	if main == null or ronin == null:
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
