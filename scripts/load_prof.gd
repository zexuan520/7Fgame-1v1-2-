class_name LoadProf
extends RefCounted
## 量加载耗时用（--loadprof）：按标签累计毫秒数和次数，report() 打一张表。
## 关着的时候 t()/add() 只多一次布尔判断。

static var on := false
static var big := OS.get_cmdline_user_args().has("--loadbig")   # 顺便列出拼得慢的大格子
static var _acc := {}
static var _cnt := {}


static func t() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(tag: String, t0: int) -> void:
	if not on:
		return
	_acc[tag] = int(_acc.get(tag, 0)) + Time.get_ticks_usec() - t0
	_cnt[tag] = int(_cnt.get(tag, 0)) + 1


static func report(title: String) -> void:
	if not on:
		return
	var keys := _acc.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _acc[a] > _acc[b])
	print("== LoadProf %s ==" % title)
	for k: String in keys:
		print("  %-28s %8.1f ms  ×%d" % [k, _acc[k] / 1000.0, _cnt[k]])
	_acc.clear()
	_cnt.clear()
