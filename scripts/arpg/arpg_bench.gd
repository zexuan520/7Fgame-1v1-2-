class_name ArpgBench
extends CanvasLayer
## 帧率测试（2026-11-10 第三档 F3）：暂停菜单（山门、标题）里点“帧率测试”，自动跑三段最吃性能的场景，
## 每段先热身 4 秒再量 20 秒，记真实时间的每帧耗时：平均帧数、最慢 1% 的帧数、卡顿（一帧超过 50 毫秒）次数。
## 跑完回标题弹一张结果卡，能一键复制，发给开发者看。不碰存档进度（机器人不死、不记成就、不留存档点）。
## 用当前的画质设置跑：要比较高中低，就改了画质再测一次。
## 测试：--benchgo 开局直接开始（云端是软件渲染，帧数没意义，只用来看流程走不走得通）。

const SEGS := [
	{"name": "幽林 · 骨潮", "args": {"demo": "fight", "zone": "forest", "squad": "swarm"}},
	{"name": "古寺 · 头目", "args": {"demo": "fight", "room": "boss", "floor": "2"}},
	{"name": "长明宫 · 混战", "args": {"demo": "fight", "act": "3", "zone": "palace"}},
]
const WARM := 4.0
const MEASURE := 20.0
const STUTTER_MS := 50.0

static var active := false
static var seg := 0
static var results: Array = []        # 每段 {name, avg, low1, worst, stutters, frames}
static var show_result := false       # 回标题后弹结果卡
static var q_name := ""               # 这次测的画质（ArpgMain 填）
static var _go_done := false          # --benchgo 只触发一次（重载场景时命令行参数还在）

var _t := 0.0
var _last := 0
var _dts := PackedFloat32Array()
var _font: Font
var _label: Label


## 从菜单开始：清空，跑第一段
static func start(tree: SceneTree) -> void:
	active = true
	seg = 0
	results.clear()
	show_result = false
	tree.paused = false
	tree.reload_current_scene()


## ArpgMain._parse_args 之后调：测试进行中就用这一段的参数
static func merge_args(args: Dictionary) -> void:
	if args.has("benchgo") and not _go_done:
		_go_done = true
		active = true
		seg = 0
		results.clear()
	if not active:
		return
	var a: Dictionary = SEGS[seg]["args"]
	for k: String in a:
		args[k] = a[k]
	for k: String in ["seed0", "nohints", "noach", "fpsbench"]:
		args[k] = "1"


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = Feel.I.font if Feel.I != null else Game.font
	_label = Label.new()
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(24, 96)
	add_child(_label)
	_last = Time.get_ticks_usec()


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var real := (now - _last) / 1e6
	_last = now
	_t += real
	if _t > WARM:
		_dts.append(real)
	var left := WARM + MEASURE - _t
	var cur := 0.0
	if _dts.size() > 10:
		var s := 0.0
		for i in range(_dts.size() - 10, _dts.size()):
			s += _dts[i]
		cur = 10.0 / maxf(s, 0.0001)
	_label.text = "帧率测试 %d / %d · %s\n%s　当前 %d 帧　（Esc 结束）" % [seg + 1, SEGS.size(), SEGS[seg]["name"],
		"热身中" if _t <= WARM else "还剩 %d 秒" % ceili(left), int(round(cur))]
	if left <= 0.0:
		_finish_seg()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		active = false
		show_result = not results.is_empty()
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().reload_current_scene()


func _finish_seg() -> void:
	set_process(false)
	results.append(summarize(String(SEGS[seg]["name"]), _dts))
	seg += 1
	Engine.time_scale = 1.0
	get_tree().paused = false
	if seg >= SEGS.size():
		active = false
		show_result = true
		Game.save["bench_last"] = {"when": Time.get_datetime_string_from_system(), "text": report()}
		Game.write_save()
	get_tree().reload_current_scene.call_deferred()


static func summarize(nm: String, dts: PackedFloat32Array) -> Dictionary:
	var n := dts.size()
	if n == 0:
		return {"name": nm, "avg": 0.0, "low1": 0.0, "worst": 0.0, "stutters": 0, "frames": 0}
	var total := 0.0
	var st := 0
	var arr := Array(dts)
	for d: float in arr:
		total += d
		if d * 1000.0 > STUTTER_MS:
			st += 1
	arr.sort()
	# 最慢 1% 的帧的平均耗时 → 帧数
	var k := maxi(1, n / 100)
	var slow := 0.0
	for i in range(n - k, n):
		slow += float(arr[i])
	return {"name": nm, "avg": n / total, "low1": k / maxf(slow, 0.0001), "worst": float(arr[n - 1]) * 1000.0, "stutters": st, "frames": n}


## 结果文本（结果卡和复制用同一份）
static func report() -> String:
	var vs := DisplayServer.window_get_size()
	var lines := ["《残刃归途》帧率测试",
		"%s · %s · %s" % [OS.get_name(), RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()],
		"画质 %s · 窗口 %d×%d · %s" % [q_name, vs.x, vs.y,
			"网页" if OS.has_feature("web") else "桌面"]]
	for r: Dictionary in results:
		lines.append("%s：平均 %.0f 帧，最慢 1%% %.0f 帧，最长一帧 %.0f 毫秒，卡顿 %d 次" % [r["name"], r["avg"], r["low1"], r["worst"], r["stutters"]])
	return "\n".join(lines)
