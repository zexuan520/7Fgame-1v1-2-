class_name ArpgInput
extends RefCounted
## 斜俯视版的按键。P1：WASD 移动、J 攻击、空格/Shift 翻滚、K 突进斩、I 光束斩、E 终结技、O 秘技、U 药葫芦、F 互动、
## Q 换兵器、R 用道具、T 换道具；
## 鼠标左键攻击、右键突进斩。P2（本地同屏双人）：方向键、小键盘 1 攻击 2 翻滚 3 突进 4 光束 5 终结 6 药 8 秘技 0 互动、
## 9 换兵器、+ 用道具、- 换道具。
## 手柄：左摇杆移动、X 攻击、A 翻滚、B 突进斩、Y 终结技、RB 光束斩、十字键上 药葫芦、十字键右 秘技、LB 互动、
## 十字键左 换兵器、十字键下 用道具、按下左摇杆 换道具、按下右摇杆 属性。

const KEYS := [
	{"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D], "attack": [KEY_J], "roll": [KEY_SPACE, KEY_SHIFT, KEY_L],
	 "dash": [KEY_K], "beam": [KEY_I], "finish": [KEY_E], "heal": [KEY_U], "interact": [KEY_F], "bag": [KEY_TAB, KEY_B], "art": [KEY_O],
	 "swap": [KEY_Q], "item": [KEY_R], "item_next": [KEY_T], "stats": [KEY_C]},
	{"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT], "attack": [KEY_KP_1], "roll": [KEY_KP_2],
	 "dash": [KEY_KP_3], "beam": [KEY_KP_4], "finish": [KEY_KP_5], "heal": [KEY_KP_6], "interact": [KEY_KP_0], "bag": [KEY_KP_7], "art": [KEY_KP_8],
	 "swap": [KEY_KP_9], "item": [KEY_KP_ADD], "item_next": [KEY_KP_SUBTRACT], "stats": [KEY_KP_DIVIDE]},
]
const PAD := {"attack": JOY_BUTTON_X, "roll": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "finish": JOY_BUTTON_Y,
	"beam": JOY_BUTTON_RIGHT_SHOULDER, "heal": JOY_BUTTON_DPAD_UP, "interact": JOY_BUTTON_LEFT_SHOULDER, "bag": JOY_BUTTON_BACK, "art": JOY_BUTTON_DPAD_RIGHT,
	"swap": JOY_BUTTON_DPAD_LEFT, "item": JOY_BUTTON_DPAD_DOWN, "item_next": JOY_BUTTON_LEFT_STICK, "stats": JOY_BUTTON_RIGHT_STICK}
const NAMES := {"attack": "攻击", "roll": "翻滚", "dash": "突进斩", "beam": "光束斩", "finish": "终结技", "heal": "药葫芦", "interact": "互动", "bag": "行囊", "art": "秘技", "swap": "换兵器", "item": "道具", "item_next": "换道具", "stats": "属性"}

## 手柄上的按键名（Xbox 布局）
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "十字↑", JOY_BUTTON_DPAD_RIGHT: "十字→", JOY_BUTTON_DPAD_LEFT: "十字←",
	JOY_BUTTON_DPAD_DOWN: "十字↓", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start"}

static var _done := false
## 每个玩家最近一次用的是不是手柄：按键提示跟着换（键盘 J / 手柄 X / 触屏「斩」）
static var pad_used := [false, false]


## 记下玩家最近用的设备（ArpgHints._input 里调）
static func note(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed and event.device >= 0 and event.device < 2:
			pad_used[event.device] = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.6 and event.device >= 0 and event.device < 2:
			pad_used[event.device] = true
	elif event is InputEventKey:
		if not (event as InputEventKey).pressed:
			return
		var k := int((event as InputEventKey).physical_keycode)
		for i in range(KEYS.size()):
			for a: String in KEYS[i]:
				if (KEYS[i][a] as Array).has(k):
					pad_used[i] = false
					return
	elif event is InputEventMouseButton and not TouchPad.active:
		pad_used[0] = false
		mouse_seen = true
	elif event is InputEventMouseMotion and not TouchPad.active:
		if (event as InputEventMouseMotion).relative.length() > 3.0:
			mouse_seen = true


## 鼠标瞄准（2026-11-10）：电脑上动过鼠标，一号玩家出刀、光束斩朝鼠标指的地方；用手柄、触屏时照旧自动瞄准。设置里能关
static var mouse_seen := false


static func mouse_aim_on() -> bool:
	return mouse_seen and not pad_used[0] and not TouchPad.active and bool(Game.settings.get("mouse_aim", true))


## 鼠标指着的地面点（y = 主角脚下高度），算不出来返回 null
static func mouse_ground(vp: Viewport, y: float) -> Variant:
	var cam := vp.get_camera_3d()
	if cam == null:
		return null
	var mp := vp.get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return null
	var t := (y - o.y) / d.y
	if t < 0.0:
		return null
	return o + d * t


## 当前该显示哪套按键提示：kb 键鼠 / pad 手柄 / touch 触屏
static func device(index: int = 0) -> String:
	if TouchPad.active and index == 0:
		return "touch"
	return "pad" if pad_used[clampi(index, 0, 1)] else "kb"


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
	if pad_used[clampi(index, 0, 1)] and not (TouchPad.active and index == 0):
		if name == "quit":
			return "Start"
		if PAD.has(name):
			return String(PAD_NAMES.get(PAD[name], "?"))
	if name == "quit":
		return "Esc"
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
