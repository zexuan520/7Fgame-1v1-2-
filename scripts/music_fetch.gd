class_name MusicFetch
extends Node
## 网页版配乐边玩边下。
## 网页导出包里不带 assets/music（export_presets 的 exclude_filter 排除），build-web.cmd 把原 .ogg
## 复制到 dist/music/，跟 index.html 放在一起上传。游戏要哪首就先下哪首，其余按提示在后台一首一首预下，
## 下好的留在内存里（浏览器自己也会缓存文件，第二次打开基本不用再下）。
## 桌面版和编辑器里 res://assets/music 有原文件，Game 直接 load，不走这里。
## 测试：桌面上加 --musicweb=http://127.0.0.1:8000/ 也走下载（目录下要有 music/*.ogg）；--sfxlog 打印下载过程。

signal track_ready(track: String, stream: AudioStream)
signal track_failed(track: String)

const DIR := "music/"
const MAX_TRY := 3
const MAX_ACTIVE := 2      # 同时最多下两首（一首是正要放的，一首后台预下）

var _base := ""
var _ver := ""
var _done := {}            # 名 → AudioStream
var _tries := {}           # 名 → 已失败次数
var _queue: Array[String] = []
var _active := {}          # 名 → HTTPRequest
var _waiting := {}         # 名 → true：失败了，等一会儿重试
var _log := false


## 这次运行要不要走下载（网页版，或者测试参数指定了地址）
static func wanted() -> bool:
	if OS.has_feature("web"):
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--musicweb="):
			return true
	return false


func _ready() -> void:
	_log = OS.get_cmdline_user_args().has("--sfxlog")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--musicweb="):
			_base = a.substr(11)
	if _base == "" and OS.has_feature("web"):
		var href = JavaScriptBridge.eval("(function(){var u=location.href.split('#')[0].split('?')[0];return u.substring(0,u.lastIndexOf('/')+1);})()", true)
		_base = str(href) if href != null else ""
	if _base != "" and not _base.ends_with("/"):
		_base += "/"
	_ver = str(ProjectSettings.get_setting("application/config/version", ""))


## 已经下好的曲子；没下好返回 null，并且（want=true 时）马上插队去下
func stream(track: String, want: bool = true) -> AudioStream:
	if _done.has(track):
		return _done[track]
	if want:
		_enqueue(track, true)
	return null


## 正在下或者排着队（下好了会发 track_ready）
func pending(track: String) -> bool:
	return _active.has(track) or _queue.has(track) or _waiting.has(track)


func has_track(track: String) -> bool:
	return _done.has(track)


## 后台预下（排在队尾，已经有的不重复）
func prefetch(tracks: Array) -> void:
	for t in tracks:
		_enqueue(String(t), false)


func _enqueue(track: String, urgent: bool) -> void:
	if track == "" or _done.has(track) or _active.has(track):
		return
	if int(_tries.get(track, 0)) >= MAX_TRY:
		return
	if _queue.has(track):
		if not urgent:
			return
		_queue.erase(track)
	if urgent:
		_queue.push_front(track)
	else:
		_queue.push_back(track)
	_pump(urgent)


func _pump(urgent: bool = false) -> void:
	# 正要放的那首可以多开一路，不等后台预下的
	while not _queue.is_empty() and (_active.size() < MAX_ACTIVE or (urgent and _active.size() < MAX_ACTIVE + 1)):
		urgent = false
		_start(_queue.pop_front())


func _start(track: String) -> void:
	if _base == "":
		_fail(track, "不知道网页地址")
		return
	var req := HTTPRequest.new()
	req.timeout = 60.0
	add_child(req)
	_active[track] = req
	var url := _base + DIR + track.uri_encode() + ".ogg"
	if _ver != "":
		url += "?v=" + _ver.uri_encode()
	if _log:
		print("[music] 下载 ", url)
	req.request_completed.connect(_on_done.bind(track, req))
	var err := req.request(url)
	if err != OK:
		_active.erase(track)
		req.queue_free()
		_fail(track, "request 出错 %d" % err)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, track: String, req: HTTPRequest) -> void:
	_active.erase(track)
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300 or body.is_empty():
		_fail(track, "result=%d code=%d" % [result, code])
	else:
		var s := AudioStreamOggVorbis.load_from_buffer(body)
		if s == null:
			_fail(track, "解不开 ogg（%d 字节）" % body.size())
		else:
			s.loop = true
			_done[track] = s
			if _log:
				print("[music] 下好 ", track, " ", body.size() / 1024, "KB")
			track_ready.emit(track, s)
	_pump()


func _fail(track: String, why: String) -> void:
	var n := int(_tries.get(track, 0)) + 1
	_tries[track] = n
	if _log or n >= MAX_TRY:
		print("[music] 下载失败 ", track, "（第 %d 次）：" % n, why)
	if n < MAX_TRY:
		# 过一会儿再试（网络抖一下不至于整局没音乐）
		_waiting[track] = true
		get_tree().create_timer(2.0 * n).timeout.connect(func() -> void:
			_waiting.erase(track)
			_enqueue(track, false))
	else:
		track_failed.emit(track)
