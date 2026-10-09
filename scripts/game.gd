extends Node
## 全局单例（自动加载为 Game）：按键映射、中文字体、调试开关、这一局的状态、存档。

const PARRY_WINDOW := 0.15        # 设计文档：弹反窗口 0.15 秒
const PARRY_WINDOW_EASY := 0.25   # 低难度 0.25 秒

var easy_mode := false
var show_hitboxes := false
var font: Font

var practice := false             # 练武场：旧的单场地，数字键换对手（F4 切换）
var run: Run = null               # 正在进行的一局；null 时在破庙
var last_result := {}             # 上一局的结算，回到破庙时显示
var save_path := "user://save.cfg"
## 存档：魂玉、天赋等级、兵器架上解锁的武器、招式谱上加进掉落池的招式和心法、统计
## memories 拿到的记忆碎片，meets 每个头目见过几次
var save := {"jade": 0, "talents": {}, "weapons": ["katana"], "start_weapon": "katana", "arts": [],
	"memories": [], "meets": {}, "boss_kills": {}, "best_floor": 0,
	"runs": 0, "clears": 0, "deaths": 0, "best_row": 0}
## 旧版破庙供台的价格：读到旧存档时把供奉过的魂玉退回来（供台换成了天赋树）
const OLD_ALTAR_COSTS := {"vigor": [5, 10, 15], "gourd": [8, 16], "purse": [4, 8, 12]}


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
	load_save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for k: String in save.keys():
		save[k] = cfg.get_value("save", k, save[k])
	var old: Dictionary = cfg.get_value("save", "altar", {})
	if not old.is_empty():
		for id: String in old:
			var costs: Array = OLD_ALTAR_COSTS.get(id, [])
			for i in range(mini(int(old[id]), costs.size())):
				save["jade"] = int(save["jade"]) + int(costs[i])
		write_save()


func write_save() -> void:
	var cfg := ConfigFile.new()
	for k: String in save.keys():
		cfg.set_value("save", k, save[k])
	cfg.save(save_path)


## 兵器架：闯关时拿到过的武器解锁成出发武器
func unlock_weapon(id: String) -> bool:
	var list: Array = save["weapons"]
	if list.has(id):
		return false
	list.append(id)
	write_save()
	return true


func parry_window() -> float:
	return PARRY_WINDOW_EASY if easy_mode else PARRY_WINDOW


func _setup_inputs() -> void:
	# 1P：键盘左手区 + 1 号手柄
	_bind_player("p1_", {
		"left": [KEY_A], "right": [KEY_D], "jump": [KEY_W, KEY_SPACE], "down": [KEY_S],
		"attack": [KEY_J], "guard": [KEY_K], "dodge": [KEY_L, KEY_SHIFT],
		"heal": [KEY_U], "art": [KEY_I], "stance": [KEY_O],
	}, 0)
	# 2P：方向键 + 小键盘 1/2/3（没有小键盘可用 , . /），药罐小键盘 4 或 M，招式小键盘 5 或 N，架势小键盘 6 或 B + 2 号手柄
	_bind_player("p2_", {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_UP], "down": [KEY_DOWN],
		"attack": [KEY_KP_1, KEY_COMMA], "guard": [KEY_KP_2, KEY_PERIOD], "dodge": [KEY_KP_3, KEY_SLASH],
		"heal": [KEY_KP_4, KEY_M], "art": [KEY_KP_5, KEY_N], "stance": [KEY_KP_6, KEY_B],
	}, 1)
	_add_keys("toggle_p2", [KEY_F2])
	_add_keys("toggle_easy", [KEY_F1])
	_add_keys("toggle_hitbox", [KEY_F3])
	_add_keys("toggle_help", [KEY_H])
	_add_keys("toggle_map", [KEY_TAB])
	_add_pad_button("toggle_map", 0, JOY_BUTTON_BACK)
	_add_pad_button("toggle_map", 1, JOY_BUTTON_BACK)
	_add_keys("toggle_practice", [KEY_F4])
	_add_keys("reset", [KEY_R])
	_add_keys("debug_jade", [KEY_F5])
	# 数字键 1-5 换对手（见 EnemyData.ENCOUNTERS）
	var nums := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	for i in range(nums.size()):
		_add_keys("encounter_%d" % (i + 1), [nums[i]])
	_add_keys("quit", [KEY_ESCAPE])


func _bind_player(prefix: String, keys: Dictionary, pad: int) -> void:
	for action: String in keys:
		_add_keys(prefix + action, keys[action])
	# 手柄：左摇杆/十字键移动（往下 = 下），A 跳，X 攻击，RB 格挡，B 闪身，Y 药罐，LB 招式，十字键上 换架势
	_add_pad_axis(prefix + "left", pad, JOY_AXIS_LEFT_X, -1.0)
	_add_pad_axis(prefix + "right", pad, JOY_AXIS_LEFT_X, 1.0)
	_add_pad_button(prefix + "left", pad, JOY_BUTTON_DPAD_LEFT)
	_add_pad_button(prefix + "right", pad, JOY_BUTTON_DPAD_RIGHT)
	_add_pad_axis(prefix + "down", pad, JOY_AXIS_LEFT_Y, 1.0)
	_add_pad_button(prefix + "down", pad, JOY_BUTTON_DPAD_DOWN)
	_add_pad_button(prefix + "jump", pad, JOY_BUTTON_A)
	_add_pad_button(prefix + "attack", pad, JOY_BUTTON_X)
	_add_pad_button(prefix + "guard", pad, JOY_BUTTON_RIGHT_SHOULDER)
	_add_pad_button(prefix + "art", pad, JOY_BUTTON_LEFT_SHOULDER)
	_add_pad_button(prefix + "heal", pad, JOY_BUTTON_Y)
	_add_pad_button(prefix + "stance", pad, JOY_BUTTON_DPAD_UP)
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
