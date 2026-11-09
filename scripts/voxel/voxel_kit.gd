class_name VoxelKit
extends RefCounted
## 开源摆设体素化出来的场景件（tools/voxelize/voxelize_prop.py 生成的 assets/voxel/kit/*.json）。
## 原点在底面中心，+z 朝镜头。读进来合成一个网格并缓存；带火的件附带灯光位置。

const DIR := "res://assets/voxel/kit/%s.json"
const DIM := 0.85          # KayKit 原色偏亮、像玩具，压暗一点配暗色光照
## 个别件再压暗 / 换色（中世纪包的山石是很亮的浅灰，放进暗色场景像发光）
const TINT := {
	"rock_a": Color(0.62, 0.64, 0.66), "rock_b": Color(0.62, 0.64, 0.66), "rock_c": Color(0.62, 0.64, 0.66),
	"rock_d": Color(0.62, 0.64, 0.66), "rock_e": Color(0.62, 0.64, 0.66), "stones": Color(0.7, 0.7, 0.72),
	# 地上的骨头小件压暗、偏土色：亮白的骷髅头在斜俯视下和骷髅小怪的头一样大一样白，一眼看去像敌人（审查第 18 条）
	"skull": Color(0.56, 0.52, 0.46), "bone_a": Color(0.6, 0.56, 0.48), "bone_b": Color(0.6, 0.56, 0.48), "bone_c": Color(0.6, 0.56, 0.48),
	"ribcage": Color(0.56, 0.52, 0.46),
	"tree_a": Color(0.7, 0.78, 0.7), "tree_b": Color(0.7, 0.78, 0.7),
	"reeds_a": Color(0.45, 0.62, 0.6), "reeds_b": Color(0.45, 0.62, 0.6),
}

## 会发光的件：[相对底面中心的位置（以件的高度为 1）, 颜色, 半径]
const LIGHTS := {
	"torch": [Vector3(0, 1.0, 0.2), Color(1.0, 0.6, 0.28), 150.0],
	"torch_wall": [Vector3(0, 1.0, 0.4), Color(1.0, 0.6, 0.28), 150.0],
	"candles": [Vector3(0, 1.0, 0.2), Color(1.0, 0.7, 0.4), 90.0],
	"lantern": [Vector3(0, 0.6, 0.2), Color(1.0, 0.75, 0.4), 130.0],
	"post_lantern": [Vector3(0.3, 0.8, 0.2), Color(1.0, 0.75, 0.4), 130.0],
	"shrine": [Vector3(0, 0.6, 0.4), Color(1.0, 0.7, 0.4), 110.0],
	"skull_candle": [Vector3(0, 1.0, 0.2), Color(0.6, 1.0, 0.75), 100.0],
	"pumpkin": [Vector3(0, 0.5, 0.5), Color(1.0, 0.55, 0.2), 90.0],
}

static var _cache := {}


## 返回 {"mesh": ArrayMesh, "size": Vector3（像素）, "lo": 最小角（像素）, "light": [位置, 颜色, 半径] 或 []}；没有这个文件返回空字典
static func get_piece(id: String) -> Dictionary:
	var ck := _key(id)
	if _cache.has(ck):
		return _cache[ck]
	if record != null:
		record[id] = true
	var _lp := LoadProf.t()
	var out: Dictionary = _make.call(id, false)   # 不分帧：一口气拼完
	_cache[ck] = out
	LoadProf.add("kit.cold", _lp)
	return out


## 后台预拼（VoxelWarm 用）：分帧拼好放进缓存
static func warm(id: String) -> void:
	if _cache.has(_key(id)):
		return
	var out: Dictionary = await _make(id, true)
	var ck := _key(id)   # 拼的过程中可能换了画质，按现在的画质存（不对就扔掉）
	if not _cache.has(ck) and out.get("q", "") == ck:
		_cache[ck] = out


static var record: Variant = null   # 测试：记下用到了哪些件（tools/gen_warm_list.sh）


static func _key(id: String) -> String:
	return "%s|%d|%d" % [id, int(VoxelGrid.quant), int(VoxelModel.coarse)]


static func _make(id: String, sliced: bool) -> Dictionary:
	var ck := _key(id)
	var coarse := VoxelModel.coarse
	var path := DIR % id
	if not VoxelModel.data_exists(path):
		return {}
	var d := VoxelModel.read_data(path)
	var vs := float(d.get("vs", 2.0))
	var g := VoxelGrid.new(1)
	var v: Array = d["vox"]
	var t: Color = TINT.get(id, Color.WHITE)
	for i in range(0, v.size(), 6):
		if sliced and (i % 3072) == 0 and VoxelWarm.over():
			await VoxelWarm.pause()
		g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3] * DIM * t.r), int(v[i + 4] * DIM * t.g), int(v[i + 5] * DIM * t.b))
	var sz: Array = d["size"]
	var size := Vector3(float(sz[0]), float(sz[1]), float(sz[2])) * vs
	var light := []
	if LIGHTS.has(id):
		var l: Array = LIGHTS[id]
		var rel: Vector3 = l[0]
		light = [Vector3(rel.x * size.x * 0.5, rel.y * size.y, rel.z * size.z * 0.5), l[1], l[2]]
	var mn: Array = d.get("min", [0, 0, 0])
	# 低画质：两格并一格（手机上一格不到两个像素，看不出来，三角形少四倍）
	var mesh: ArrayMesh
	if sliced:
		mesh = await (await g.downsample_sliced(2)).build_sliced(vs * 2.0) if coarse else await g.build_sliced(vs)
	else:
		mesh = g.downsample(2).build(vs * 2.0) if coarse else g.build(vs)
	return {"mesh": mesh, "size": size, "lo": Vector3(float(mn[0]), float(mn[1]), float(mn[2])) * vs, "light": light, "q": ck}
