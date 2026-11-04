class_name VoxelKit
extends RefCounted
## 开源摆设体素化出来的场景件（tools/voxelize/voxelize_prop.py 生成的 assets/voxel/kit/*.json）。
## 原点在底面中心，+z 朝镜头。读进来合成一个网格并缓存；带火的件附带灯光位置。

const DIR := "res://assets/voxel/kit/%s.json"

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


## 返回 {"mesh": ArrayMesh, "size": Vector3（像素）, "light": [位置, 颜色, 半径] 或 []}；没有这个文件返回空字典
static func get_piece(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := DIR % id
	if not FileAccess.file_exists(path):
		_cache[id] = {}
		return {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var vs := float(d.get("vs", 2.0))
	var g := VoxelGrid.new(1)
	var v: Array = d["vox"]
	for i in range(0, v.size(), 6):
		g.cells[Vector3i(int(v[i]), int(v[i + 1]), int(v[i + 2]))] = Color8(int(v[i + 3]), int(v[i + 4]), int(v[i + 5]))
	var sz: Array = d["size"]
	var size := Vector3(float(sz[0]), float(sz[1]), float(sz[2])) * vs
	var light := []
	if LIGHTS.has(id):
		var l: Array = LIGHTS[id]
		var rel: Vector3 = l[0]
		light = [Vector3(rel.x * size.x * 0.5, rel.y * size.y, rel.z * size.z * 0.5), l[1], l[2]]
	var out := {"mesh": g.build(vs), "size": size, "light": light}
	_cache[id] = out
	return out
