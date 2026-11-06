class_name VoxelWarm
extends Node
## 后台预拼网格：趁玩家不在打架的时候（标题、山门、菜单、对话、清完房），把接下来要用的体素件、角色模型、
## 场景里自己画的件提前拼好放进缓存，真进房间时直接拿现成的。
##
## 网页版是单线程的，没法真开线程，所以是“分帧”：每帧只干 budget_us 微秒，到点就 await 下一帧接着干。
## 打架的时候 budget_us = 0，整个停住，不抢帧数。
## 要预拼什么看 res://assets/voxel/warm_list.json（tools/gen_warm_list.sh 跑一遍各区域房间记下来的），
## 列表过时也没关系：没预拼到的件进房间时照常现拼，只是慢一点。

static var budget_us := 0       # 这一帧还能干多久（ArpgMain 每帧按场合设）
static var _t0 := 0
static var I: VoxelWarm
static var _list := {}

var _queue: Array = []          # [kind, id, 参数...]
var _busy := false
var _seen := {}                 # 排过队的不重复排
var done_n := 0                 # 测试用：预拼完了几件


func _ready() -> void:
	I = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if I == self:
		I = null


## 这一片时间用完了没有（拼网格的循环里每隔几十格问一次）
static func over() -> bool:
	return Time.get_ticks_usec() - _t0 > budget_us


## 停到下一帧，有预算了再接着干
static func pause() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	while budget_us <= 0:
		await tree.process_frame
	_t0 = Time.get_ticks_usec()


static func warm_list() -> Dictionary:
	if _list.is_empty():
		var f := FileAccess.get_file_as_string("res://assets/voxel/warm_list.json")
		var d: Variant = JSON.parse_string(f) if f != "" else null
		_list = d if d is Dictionary else {"zones": {}, "models": []}
	return _list


## 排进队：一个区域用到的开源件和自己画的件（区域名同 Arena.build 的 zone_id）
func queue_zone(zone: String) -> void:
	var z: Dictionary = (warm_list().get("zones", {}) as Dictionary).get(zone, {})
	for id: String in z.get("kit", []):
		_push(["kit", id])
	for g: Array in z.get("grids", []):
		_push(["grid"] + g)


func queue_models() -> void:
	for m: Array in warm_list().get("models", []):
		_push(m)   # ["model", 名] 或 ["weapon", 名, 长度]


## 插到最前面（马上要进的区域）
func queue_zone_first(zone: String) -> void:
	var before := _queue.duplicate()
	_queue.clear()
	queue_zone(zone)
	for j: Array in before:
		if not _queue.has(j):
			_queue.append(j)


func _push(job: Array) -> void:
	var key := str(job)
	if _seen.has(key):
		return
	_seen[key] = true
	_queue.append(job)


func forget() -> void:
	_seen.clear()


func idle() -> bool:
	return not _busy and _queue.is_empty()


func _process(_dt: float) -> void:
	if _busy or _queue.is_empty() or budget_us <= 0:
		return
	_run(_queue.pop_front())


func _run(job: Array) -> void:
	_busy = true
	_t0 = Time.get_ticks_usec()
	var _lp := LoadProf.t()
	match String(job[0]):
		"kit":
			await VoxelKit.warm(String(job[1]))
		"model":
			await VoxelModel.warm(String(job[1]))
		"weapon":
			VoxelModel.weapon_mesh(String(job[1]), float(job[2]))   # 兵器都很小，一口气拼
		"grid":
			await Arena.warm_grid(job)
	LoadProf.add("warm." + String(job[0]), _lp)
	done_n += 1
	_busy = false
