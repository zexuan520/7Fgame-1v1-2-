class_name VoxelModel
extends RefCounted
## 从开源 3D 模型体素化出来的角色（tools/voxelize/voxelize_char.py 生成的 assets/voxel/*.json）。
## 每块部件的原点在它的起点关节，-y 指向终点关节；joints 是静止姿势下各关节的位置（脚底 y=0，面朝 +x，+z 朝镜头）。
## 读进来以后缓存，每块部件合成一个网格（1 像素 1 格）。

var joints := {}            # 关节名 → Vector3
var parts := {}             # 部件名 → {"anchor": Vector3, "len": float, "mesh": ArrayMesh}
var source := ""

static var _cache := {}
static var off := false      # true 时一律不用开源模型（演示工具拍前后对比用）
static var coarse := false   # 低画质：精细体素（res 2）的部件缩成一半分辨率再合网格，三角形少四倍左右，手机上看不出差别


## 体素数据文件：仓库里存的是 gzip 压缩过的 <名>.json.gz（体素 JSON 压缩后小六倍，网页包少十几 MB）；
## 工具刚生成、还没压的 <名>.json 也认。path 写 .json 结尾的那个名字
static func data_exists(path: String) -> bool:
	return FileAccess.file_exists(path + ".gz") or FileAccess.file_exists(path)


static func read_data(path: String) -> Dictionary:
	var _lp := LoadProf.t()
	var txt := ""
	if FileAccess.file_exists(path + ".gz"):
		var raw := FileAccess.get_file_as_bytes(path + ".gz")
		txt = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	elif FileAccess.file_exists(path):
		txt = FileAccess.get_file_as_string(path)
	var d: Variant = JSON.parse_string(txt) if txt != "" else null
	LoadProf.add("read_data", _lp)
	return d if d is Dictionary else {}


static func load_model(id: String) -> VoxelModel:
	if off:
		return null
	var ck := _mkey(id)
	if _cache.has(ck):
		return _cache[ck]
	if record != null:
		record["model|" + id] = ["model", id]
	var _lp := LoadProf.t()
	var m: VoxelModel = _make.call(id, false)   # 不分帧
	if m == null:
		push_warning("没有体素模型 " + id)
	_cache[ck] = m
	LoadProf.add("model.cold", _lp)
	return m


static var record: Variant = null   # 测试：记下用到了哪些模型、兵器（tools/gen_warm_list.sh）


static func _mkey(id: String) -> String:
	return "%s|%d|%d" % [id, int(coarse), int(VoxelGrid.quant)]


## 后台预拼（VoxelWarm 用）
static func warm(id: String) -> void:
	if off or _cache.has(_mkey(id)):
		return
	var ck := _mkey(id)
	var m: VoxelModel = await _make(id, true)
	if m != null and not _cache.has(ck) and _mkey(id) == ck:
		_cache[ck] = m


static func _make(id: String, sliced: bool) -> VoxelModel:
	var path := "res://assets/voxel/%s.json" % id
	if not data_exists(path):
		return null
	var cs := coarse
	var d := read_data(path)
	var m := VoxelModel.new()
	m.source = String(d.get("source", ""))
	# res：精细体素（2 表示一格切成 2×2×2 的小格）。关节、长度都换回原来的格子单位，网格按小格画，
	# 所以姿势、武器、碰撞这些按“格”算的东西都不用改。
	var res := float(d.get("res", 1))
	for k: String in d["joints"]:
		var a: Array = d["joints"][k]
		m.joints[k] = Vector3(a[0], a[1], a[2]) / res
	for pname: String in d["parts"]:
		var pd: Dictionary = d["parts"][pname]
		var g := VoxelGrid.new(1)
		var v: Array = pd["vox"]
		# stride 7：每格多一个 alpha（< 255 表示发光，toon 着色器按 1 - alpha 自发光；锻造台 tools/charforge 做的角色眼睛用）
		var st := int(pd.get("stride", 6))
		for i in range(0, v.size(), st):
			if sliced and (i % (st * 512)) == 0 and VoxelWarm.over():
				await VoxelWarm.pause()
			g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]), int(v[i + 6]) if st == 7 else 255)
		var an: Array = pd["anchor"]
		var mesh: ArrayMesh
		if sliced:
			mesh = await (await g.downsample_sliced(2)).build_sliced(2.0 / res) if cs and res > 1.2 else await g.build_sliced(1.0 / res)
		elif cs and res > 1.2:
			mesh = g.downsample(2).build(2.0 / res)
		else:
			mesh = g.build(1.0 / res)
		m.parts[pname] = {"anchor": Vector3(an[0], an[1], an[2]) / res, "len": float(pd["len"]) / res, "mesh": mesh}
		if pd.has("pivot"):
			var pv: Array = pd["pivot"]
			m.parts[pname]["pivot"] = Vector3(pv[0], pv[1], pv[2]) / res   # 会飘的件的转轴（相对锚点，格）
	return m


## 是不是锻造台（tools/charforge）自制的模型：颜色画在模型上，用的地方不该再染色
static func forged(id: String) -> bool:
	var m := load_model(id)
	return m != null and m.source.begins_with("本作自制")


func j(name: String) -> Vector3:
	return joints.get(name, Vector3.ZERO)


func length(pname: String) -> float:
	return float(parts[pname]["len"]) if parts.has(pname) else 0.0


static var _weapons := {}


## 开源武器（assets/voxel/weapon/*.json，原点在握把、刃朝 -y），按给定的总长缩放成网格；没有返回 null
static func weapon_mesh(id: String, length: float) -> ArrayMesh:
	var key := "%s|%.1f|%d|%d" % [id, length, int(coarse), int(VoxelGrid.quant)]
	if _weapons.has(key):
		return _weapons[key]
	if record != null and id != "":
		record["weapon|%s|%.1f" % [id, length]] = ["weapon", id, snappedf(length, 0.1)]
	var _lp := LoadProf.t()
	var path := "res://assets/voxel/weapon/%s.json" % id
	if id == "" or not data_exists(path):
		_weapons[key] = null
		return null
	var d := read_data(path)
	var g := VoxelGrid.new(1)
	var v: Array = d["vox"]
	for i in range(0, v.size(), 6):
		g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
	# len 是像素长，vs 是一格几像素（精细版 0.5），格数 = len / vs
	var vsz := length * float(d.get("vs", 1.0)) / maxf(float(d.get("len", 40.0)), 1.0)
	var m := g.downsample(2).build(vsz * 2.0) if coarse and float(d.get("vs", 1.0)) < 1.0 else g.build(vsz)
	_weapons[key] = m
	LoadProf.add("weapon.cold", _lp)
	return m
