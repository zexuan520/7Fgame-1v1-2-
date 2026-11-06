class_name ArpgInput
extends RefCounted
## 斜俯视版的按键。P1：WASD 移动、J 攻击、空格/Shift 翻滚、K 突进斩、I 光束斩、E 终结技、O 秘技、U 药葫芦、F 互动、
## Q 换兵器、R 用道具、T 换道具；
## 鼠标左键攻击、右键突进斩。P2（本地同屏双人）：方向键、小键盘 1 攻击 2 翻滚 3 突进 4 光束 5 终结 6 药 8 秘技 0 互动、
## 9 换兵器、+ 用道具、- 换道具。
## 手柄：左摇杆移动、X 攻击、A 翻滚、B 突进斩、Y 终结技、RB 光束斩、十字键上 药葫芦、十字键右 秘技、LB 互动、
## 十字键左 换兵器、十字键下 用道具、按下左摇杆 换道具。

const KEYS := [
	{"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D], "attack": [KEY_J], "roll": [KEY_SPACE, KEY_SHIFT, KEY_L],
	 "dash": [KEY_K], "beam": [KEY_I], "finish": [KEY_E], "heal": [KEY_U], "interact": [KEY_F], "bag": [KEY_TAB, KEY_B], "art": [KEY_O],
	 "swap": [KEY_Q], "item": [KEY_R], "item_next": [KEY_T]},
	{"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT], "attack": [KEY_KP_1], "roll": [KEY_KP_2],
	 "dash": [KEY_KP_3], "beam": [KEY_KP_4], "finish": [KEY_KP_5], "heal": [KEY_KP_6], "interact": [KEY_KP_0], "bag": [KEY_KP_7], "art": [KEY_KP_8],
	 "swap": [KEY_KP_9], "item": [KEY_KP_ADD], "item_next": [KEY_KP_SUBTRACT]},
]
const PAD := {"attack": JOY_BUTTON_X, "roll": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "finish": JOY_BUTTON_Y,
	"beam": JOY_BUTTON_RIGHT_SHOULDER, "heal": JOY_BUTTON_DPAD_UP, "interact": JOY_BUTTON_LEFT_SHOULDER, "bag": JOY_BUTTON_BACK, "art": JOY_BUTTON_DPAD_RIGHT,
	"swap": JOY_BUTTON_DPAD_LEFT, "item": JOY_BUTTON_DPAD_DOWN, "item_next": JOY_BUTTON_LEFT_STICK}
const NAMES := {"attack": "攻击", "roll": "翻滚", "dash": "突进斩", "beam": "光束斩", "finish": "终结技", "heal": "药葫芦", "interact": "互动", "bag": "行囊", "art": "秘技", "swap": "换兵器", "item": "道具", "item_next": "换道具"}

static var _done := false


static func act(index: int, name: String) -> String:
	return "a%d_%s" % [index + 1, name]


static func setup() -> void:
	if _done:
		return
	_done = true
	for i in range(KEYS.size()):
		var keys: Dictionary = KEYS[i]
		for a: String in keys:
			var an := act(i, a)
			if not InputMap.has_action(an):
				InputMap.add_action(an, 0.25)
			for k: int in keys[a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(an, ev)
		for a: String in PAD:
			var ev := InputEventJoypadButton.new()
			ev.device = i
			ev.button_index = PAD[a]
			InputMap.action_add_event(act(i, a), ev)
		for pair: Array in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
			var ev := InputEventJoypadMotion.new()
			ev.device = i
			ev.axis = pair[1]
			ev.axis_value = pair[2]
			InputMap.action_add_event(act(i, pair[0]), ev)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(act(0, "attack"), m)
	var m2 := InputEventMouseButton.new()
	m2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event(act(0, "dash"), m2)


static func key_name(index: int, name: String) -> String:
	var keys: Array = KEYS[index].get(name, [])
	if keys.is_empty():
		return ""
	return OS.get_keycode_string(int(keys[0]))


## 触屏模式：手指点屏幕会被模拟成鼠标左键，不能再当“攻击”，否则推摇杆也会出刀
static func drop_mouse() -> void:
	setup()
	for a: String in ["attack", "dash"]:
		for ev: InputEvent in InputMap.action_get_events(act(0, a)):
			if ev is InputEventMouseButton:
				InputMap.action_erase_event(act(0, a), ev)
