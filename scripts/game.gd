extends Node
## 全局单例（自动加载为 Game）：按键映射、中文字体、调试开关、这一局的状态、存档、声音和设置。
## 声音：Game.sfx("parry") 放音效（assets/sfx/），Game.music("hub") 换背景音乐（assets/music/，循环）。
## 素材是 tools/gen_audio.py 合成的占位声音，换正式素材直接覆盖同名 wav。

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
## memories 拿到的记忆碎片，meets 每个头目见过几次，hub 破庙设施（见 Facilities）
var save := {"jade": 0, "talents": {}, "weapons": ["katana"], "start_weapon": "katana", "arts": [],
	"memories": [], "meets": {}, "boss_kills": {}, "best_floor": 0, "hub": {},
	"runs": 0, "clears": 0, "deaths": 0, "best_row": 0}
## 旧版破庙供台的价格：读到旧存档时把供奉过的魂玉退回来（供台换成了天赋树）
const OLD_ALTAR_COSTS := {"vigor": [5, 10, 15], "gourd": [8, 16], "purse": [4, 8, 12]}


## 设置（和存档分开放）：音量 0-1、低难度、改过的按键 {动作: [键码, ...]}
var settings := {"master": 0.8, "music": 0.6, "sfx": 0.8, "easy": false, "keys": {}}
var settings_path := "user://settings.cfg"
const SFX_VOICES := 16
const SFX_GAP := 0.035              # 同一个音效太密时（一把铜钱）跳过
var _voices: Array[AudioStreamPlayer] = []
var _voice := 0
var _sfx_cache := {}
var _sfx_last := {}
var _bgm: AudioStreamPlayer
var _bgm_name := ""
var _bgm_tween: Tween


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
	load_settings()
	_setup_audio()


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


# ---------- 设置 ----------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for k: String in settings.keys():
			settings[k] = cfg.get_value("settings", k, settings[k])
	easy_mode = bool(settings["easy"])
	for action: String in settings["keys"]:
		rebind(action, settings["keys"][action], false)


func write_settings() -> void:
	settings["easy"] = easy_mode
	var cfg := ConfigFile.new()
	for k: String in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(settings_path)


## 改键：把这个动作的键盘按键换成 keys（手柄不动）
func rebind(action: String, keys: Array, save_it: bool = true) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	_add_keys(action, keys)
	if save_it:
		settings["keys"][action] = keys
		write_settings()


## 这个动作现在的键盘按键名（界面上显示）
func key_names(action: String) -> String:
	var names := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			names.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode))
	return " / ".join(names)


# ---------- 声音 ----------

func _setup_audio() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in range(SFX_VOICES):
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Music"
	add_child(_bgm)
	apply_volume()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(settings["master"]), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(settings["music"]), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(settings["sfx"]), 0.0001)))


## 放一个音效。pitch_var 是随机音高的幅度（同一个声音听起来不那么机械）
func sfx(sound: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last.get(sound, -1.0)) < SFX_GAP:
		return
	_sfx_last[sound] = now
	var stream := _load_sound("res://assets/sfx/%s.wav" % sound)
	if stream == null or _voices.is_empty():
		return
	var v := _voices[_voice]
	_voice = (_voice + 1) % _voices.size()
	v.stream = stream
	v.volume_db = volume_db
	v.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	v.play()


## 换背景音乐（同一首不重来）；空字符串是停下
func music(track: String) -> void:
	if track == _bgm_name or _bgm == null:
		return
	_bgm_name = track
	if _bgm_tween != null:
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	if _bgm.playing:
		_bgm_tween.tween_property(_bgm, "volume_db", -40.0, 0.6)
	_bgm_tween.tween_callback(func() -> void:
		var s := _load_sound("res://assets/music/%s.wav" % track) if track != "" else null
		_bgm.stop()
		if s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		if s != null:
			_bgm.stream = s
			_bgm.volume_db = -40.0
			_bgm.play())
	_bgm_tween.tween_property(_bgm, "volume_db", 0.0, 0.8)


func music_name() -> String:
	return _bgm_name


func _load_sound(path: String) -> AudioStream:
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _sfx_cache[path]


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
		"heal": [KEY_U], "art": [KEY_I], "stance": [KEY_O], "tool": [KEY_P], "item": [KEY_Y],
	}, 0)
	# 2P：方向键 + 小键盘 1/2/3（没有小键盘可用 , . /），药罐小键盘 4 或 M，招式小键盘 5 或 N，架势小键盘 6 或 B，
	# 副武器小键盘 7 或 V，道具小键盘 8 或 C + 2 号手柄
	_bind_player("p2_", {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "jump": [KEY_UP], "down": [KEY_DOWN],
		"attack": [KEY_KP_1, KEY_COMMA], "guard": [KEY_KP_2, KEY_PERIOD], "dodge": [KEY_KP_3, KEY_SLASH],
		"heal": [KEY_KP_4, KEY_M], "art": [KEY_KP_5, KEY_N], "stance": [KEY_KP_6, KEY_B],
		"tool": [KEY_KP_7, KEY_V], "item": [KEY_KP_8, KEY_C],
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
	# 手柄：左摇杆/十字键移动（往下 = 下），A 跳，X 攻击，RB 格挡，B 闪身，Y 药罐，LB 招式，十字键上 换架势，
	# RT 副武器，LT 道具
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
	_add_pad_axis(prefix + "tool", pad, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_pad_axis(prefix + "item", pad, JOY_AXIS_TRIGGER_LEFT, 1.0)


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
