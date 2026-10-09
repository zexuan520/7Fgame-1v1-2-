extends Node
## 全局单例（自动加载为 Game）：按键映射、中文字体、调试开关。

const PARRY_WINDOW := 0.15        # 设计文档：弹反窗口 0.15 秒
const PARRY_WINDOW_EASY := 0.25   # 低难度 0.25 秒

var easy_mode := false
var show_hitboxes := false
var font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 像素字体 Fusion Pixel（SIL OFL 1.1），12 像素的倍数最清晰
	var pixel: FontFile = load("res://assets/fonts/fusion-pixel.ttf")
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.hinting = TextServer.HINTING_NONE
	pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	pixel.oversampling = 1.0
	font = pixel
	_setup_inputs()


func parry_window() -> float:
	return PARRY_WINDOW_EASY if easy_mode else PARRY_WINDOW


func _setup_inputs() -> void:
	# 1P：键盘左手区 + 1 号手柄
	_bind_player("p1_", {
		"left": [KEY_A], "right": [KEY_D], "jump": [KEY_W, KEY_SPACE],
		"attack": [KEY_J], "guard": [KEY_K], "dodge": [KEY_L, KEY_SHIFT],
	}, 0)
	# 2P：方向键 + 小键盘 1/2/3（没有小键盘可用 , . /）+ 2 号手柄
	_bind_player("p2_", {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_UP],
		"attack": [KEY_KP_1, KEY_COMMA], "guard": [KEY_KP_2, KEY_PERIOD], "dodge": [KEY_KP_3, KEY_SLASH],
	}, 1)
	_add_keys("toggle_p2", [KEY_F2])
	_add_keys("toggle_easy", [KEY_F1])
	_add_keys("toggle_hitbox", [KEY_F3])
	_add_keys("toggle_help", [KEY_H])
	_add_keys("reset", [KEY_R])
	_add_keys("quit", [KEY_ESCAPE])


func _bind_player(prefix: String, keys: Dictionary, pad: int) -> void:
	for action: String in keys:
		_add_keys(prefix + action, keys[action])
	# 手柄：左摇杆/十字键移动，A 跳，X 攻击，RB 或 LB 格挡，B 闪身
	_add_pad_axis(prefix + "left", pad, JOY_AXIS_LEFT_X, -1.0)
	_add_pad_axis(prefix + "right", pad, JOY_AXIS_LEFT_X, 1.0)
	_add_pad_button(prefix + "left", pad, JOY_BUTTON_DPAD_LEFT)
	_add_pad_button(prefix + "right", pad, JOY_BUTTON_DPAD_RIGHT)
	_add_pad_button(prefix + "jump", pad, JOY_BUTTON_A)
	_add_pad_button(prefix + "attack", pad, JOY_BUTTON_X)
	_add_pad_button(prefix + "guard", pad, JOY_BUTTON_RIGHT_SHOULDER)
	_add_pad_button(prefix + "guard", pad, JOY_BUTTON_LEFT_SHOULDER)
	_add_pad_button(prefix + "dodge", pad, JOY_BUTTON_B)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)


func _add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_pad_button(action: String, pad: int, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.device = pad
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_pad_axis(action: String, pad: int, axis: JoyAxis, dir: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.device = pad
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)
