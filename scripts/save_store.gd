class_name SaveStore
extends RefCounted
## 存档读写的底层：带版本号和校验和的文本格式、先写临时文件再换名（写到一半断电不会把存档写坏）、
## 保留上一份做备份、网页版另存一份到浏览器 localStorage。
##
## 文件格式：第一行是注释头 "; canren-save v=版本 rev=第几次写 t=写入时间 sum=校验"，下面是 ConfigFile 文本。
## ConfigFile 把 ; 开头的行当注释，所以旧版游戏也能读新存档；旧存档（没有注释头）按第 1 版读进来。
##
## 读的时候主文件优先；主文件坏了用临时文件 / 备份；localStorage 那份更新时用它：
## 网页版写 user:// 是先进内存、下一帧才异步同步到 IndexedDB，刚存完就关页面可能来不及，
## 而 localStorage 是同步写的，这时它就是最新的那份。

const HEADER := "; canren-save"
const LS_PREFIX := "canren_"


## 把一个分区的数据编码成存档文本
static func encode(section: String, data: Dictionary, version: int, rev: int) -> String:
	var cfg := ConfigFile.new()
	for k: String in data.keys():
		if data[k] != null:
			cfg.set_value(section, k, data[k])
	var body := cfg.encode_to_text()
	return "%s v=%d rev=%d t=%d sum=%s\n%s" % [HEADER, version, rev, int(Time.get_unix_time_from_system()), body.md5_text(), body]


## 解码：{"ok": 是否可用, "data": {键: 值}, "v": 版本, "rev": 第几次写, "t": 写入时间, "why": 不可用的原因}
static func decode(text: String, section: String) -> Dictionary:
	var out := {"ok": false, "data": {}, "v": 1, "rev": 0, "t": 0, "why": ""}
	if text.strip_edges() == "":
		out["why"] = "空文件"
		return out
	var body := text
	if text.begins_with(HEADER):
		var nl := text.find("\n")
		var head := text.substr(0, nl) if nl >= 0 else text
		body = text.substr(nl + 1) if nl >= 0 else ""
		var sum := ""
		for part: String in head.split(" ", false):
			var kv := part.split("=")
			if kv.size() != 2:
				continue
			match kv[0]:
				"v": out["v"] = int(kv[1])
				"rev": out["rev"] = int(kv[1])
				"t": out["t"] = int(kv[1])
				"sum": sum = kv[1]
		if sum != "" and body.md5_text() != sum:
			out["why"] = "校验不对（文件被截断或改坏）"
			return out
	var cfg := ConfigFile.new()
	if cfg.parse(body) != OK:
		out["why"] = "解析失败"
		return out
	if not cfg.has_section(section):
		out["why"] = "没有 [%s] 分区" % section
		return out
	var data := {}
	for k: String in cfg.get_section_keys(section):
		data[k] = cfg.get_value(section, k)
	out["data"] = data
	out["ok"] = true
	return out


## 安全地写一个存档文件：写临时文件 → 读回来核对 → 旧文件改名成 .bak → 临时文件改名成正式文件。
## 网页版再同步写一份到 localStorage。返回是否写成功。
static func write_text(path: String, text: String) -> bool:
	_ls_set(path, text)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("存档写不进去：%s（%s）" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		push_warning("存档写完读回来不一致：" + tmp)
		return false
	var bak := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("存档换名失败：" + tmp)
		return false
	return true


## 读一个存档：主文件能用就用主文件；主文件坏了或没有，用临时文件 / 备份里 rev 大的。
## 网页版的 localStorage 那份 rev 更大（IndexedDB 还没同步完就关了页面）时用它。
## 返回 decode() 的结果，另加 "from"（用的是哪一份）、"broken"（主文件存在但坏了）、"exists"（有没有任何存档）
static func read_best(path: String, section: String) -> Dictionary:
	var best := {"ok": false, "data": {}, "v": 1, "rev": -1, "t": 0, "from": "", "broken": false, "exists": false}
	var broken := false
	var exists := false
	if FileAccess.file_exists(path):
		exists = true
		var d := decode(FileAccess.get_file_as_string(path), section)
		if d["ok"]:
			d["from"] = "file"
			best = d
		else:
			broken = true
			push_warning("存档 %s 读不了：%s" % [path, d["why"]])
			_keep_broken(path)
	if not best["ok"]:
		for c: Array in [[path + ".tmp", "tmp"], [path + ".bak", "bak"]]:
			var p: String = c[0]
			if not FileAccess.file_exists(p):
				continue
			exists = true
			var d1 := decode(FileAccess.get_file_as_string(p), section)
			if d1["ok"] and int(d1["rev"]) > int(best["rev"]):
				d1["from"] = c[1]
				best = d1
	var ls := _ls_get(path)
	if ls != "":
		exists = true
		var d2 := decode(ls, section)
		if d2["ok"] and int(d2["rev"]) > int(best["rev"]):
			d2["from"] = "localStorage"
			best = d2
	best["broken"] = broken
	best["exists"] = exists
	return best


## 删掉一个存档（局中断点用完就删）
static func remove(path: String) -> void:
	for p: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_ls_remove(path)


## 坏掉的存档另存一份（.broken），万一需要手工救回来
static func _keep_broken(p: String) -> void:
	var raw := FileAccess.get_file_as_bytes(p)
	var f := FileAccess.open(p + ".broken", FileAccess.WRITE)
	if f != null:
		f.store_buffer(raw)
		f.close()


# ---------- 网页版：localStorage ----------

## user:// 在浏览器里能不能长期保存（IndexedDB 可用）。非网页版总是 true
static func userfs_persistent() -> bool:
	return OS.is_userfs_persistent()


static func _web() -> bool:
	return OS.has_feature("web")


static func _ls_key(path: String) -> String:
	return LS_PREFIX + path.get_file()


static func _ls_set(path: String, text: String) -> void:
	if not _web():
		return
	JavaScriptBridge.eval("try{localStorage.setItem(%s,%s)}catch(e){}" % [JSON.stringify(_ls_key(path)), JSON.stringify(text)], true)


static func _ls_get(path: String) -> String:
	if not _web():
		return ""
	var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()" % JSON.stringify(_ls_key(path)), true)
	return String(v) if v is String else ""


static func _ls_remove(path: String) -> void:
	if not _web():
		return
	JavaScriptBridge.eval("try{localStorage.removeItem(%s)}catch(e){}" % JSON.stringify(_ls_key(path)), true)


# ---------- 把对象的脚本变量存成字典（局中断点用） ----------

## 对象上所有脚本变量（var 声明的）→ 字典。跳过 skip 里的名字和对象类型的值。
## 新加的 var 自动就会存进去，不用改这里。
static func dump_vars(o: Object, skip: Array = []) -> Dictionary:
	var d := {}
	for p: Dictionary in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n := String(p["name"])
		if n in skip or n.begins_with("_"):
			continue
		var v = o.get(n)
		if v is Object or v is Callable or v is Signal:
			continue
		d[n] = _deep_copy(v)
	return d


## 字典 → 对象的脚本变量（只写对象上有的、类型对得上的）
static func load_vars(o: Object, d: Dictionary, skip: Array = []) -> void:
	var names := {}
	for p: Dictionary in o.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names[String(p["name"])] = true
	for n: String in d:
		if n in skip or not names.has(n):
			continue
		var cur = o.get(n)
		var v = d[n]
		if cur is Array and v is Array:
			(cur as Array).clear()
			(cur as Array).assign(v)   # 有类型的数组（Array[String]）要用 assign
		elif cur == null or typeof(cur) == typeof(v):
			o.set(n, _deep_copy(v))
		elif (cur is int or cur is float) and (v is int or v is float):
			o.set(n, int(v) if cur is int else float(v))


static func _deep_copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v
