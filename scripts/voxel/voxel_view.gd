class_name VoxelView
extends Node3D
## 体素显示层：和 2D 游戏画在同一个 SubViewport 里，3D 在下面，2D 的特效、文字、机关叠在上面。
## 玩法完全不动：2D 的坐标 (x, y) 对应 3D 的 (x, -y, 0)，镜头是透视的，
## 放在 z = CAM_D 处、视野正好让 z = 0 这一层和 2D 画面一一对齐，所以判定框、特效的位置不会错开。
## 远近景放在 z 更小的地方，靠透视产生真正的纵深和视差。
##
## 开关：Game.voxel（F6 切换），关掉就回到原来的 2D 画面。

const CAM_D := 600.0
const FLOOR_Y := 300.0
const GROUND_S := 8.0                 # 地面一格 = 8 像素
const GROUND_Z0 := -280.0             # 地面从这里铺到镜头前
const GROUND_Z1 := 48.0
const DEBRIS_MAX := 160

var main: Node                        # Main
var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var room: Node3D                      # 当前房间的地面、摆设、远近景（换房间整个删掉）
var rigs := {}                        # Fighter → VoxelRig
var _debris: Array = []               # [MeshInstance3D, 速度, 剩余时间, 自转]
var _debris_mesh: BoxMesh
var _debris_mats := {}
var last_build_ms := 0
var _objs := {}                       # 2D 物件 → {"root": Node3D, "kind": 种类, "at": 最后的位置, ...}
var _feats: Array = []                # 机关：[种类, 2D 里的状态字典, 3D 节点...]

static var _room_cache := {}          # 房间名 → {摆设名: 网格}（同一间房再进来不用重算）


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = rad_to_deg(2.0 * atan(180.0 / CAM_D))
	camera.near = 4.0
	camera.far = 4000.0
	camera.position = Vector3(320, -180, CAM_D)
	add_child(camera)
	camera.current = true

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2a2248")
	sm.sky_horizon_color = Color("b8644a")
	sm.ground_horizon_color = Color("7a4a42")
	sm.ground_bottom_color = Color("2a2030")
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a6a9e")
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color("5e4a7a")
	env.fog_density = 0.0004
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.76, 0.56)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 1400.0
	sun.shadow_bias = 0.05
	add_child(sun)
	# 夕阳从左后上方斜照过来，角色正面带一点暖光
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.6, -0.5), Vector3.UP)
	# 冷色的逆光：给人物和房子右侧、顶上勾一道蓝紫边，和暖色的背景分开
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.62, 1.0)
	rim.light_energy = 0.7
	add_child(rim)
	rim.look_at_from_position(Vector3.ZERO, Vector3(-0.75, -0.35, 0.55), Vector3.UP)

	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3.ONE * 2.4


# ---------- 房间 ----------

func build_room(def: Dictionary) -> void:
	if room != null:
		room.queue_free()
	for f in rigs.keys():
		(rigs[f] as Node).queue_free()
	rigs.clear()
	for d: Array in _debris:
		(d[0] as Node).queue_free()
	_debris.clear()
	for n in _objs.keys():
		(_objs[n]["root"] as Node).queue_free()
	_objs.clear()
	_feats.clear()
	room = Node3D.new()
	add_child(room)
	var name_key := "%s|%s|%s" % [def.get("name", ""), def.get("seed", 0), def.get("width", 0)]
	var cache: Dictionary = _room_cache.get(name_key, {})
	_room_cache[name_key] = cache
	var w := float(def.get("width", 800.0))
	var t0 := Time.get_ticks_msec()
	_build_ground(def, w, cache)
	_build_props(def, cache)
	_build_scenery(def, w, cache)
	_build_features(def, cache)
	if OS.is_debug_build():
		print_verbose("体素房间 %s 搭好，用时 %d 毫秒" % [name_key, Time.get_ticks_msec() - t0])
	last_build_ms = Time.get_ticks_msec() - t0


func _mi(mesh: Mesh, pos: Vector3, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)
	return mi


func _light(pos: Vector3, col: Color, rng_px: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = rng_px
	l.omni_attenuation = 1.4
	room.add_child(l)


## 地面：被坑切成几段；最前面一排往下多铺几层，挡住画面底部
func _build_ground(def: Dictionary, w: float, cache: Dictionary) -> void:
	if not cache.has("ground"):
		var g := VoxelGrid.new(int(def.get("seed", 0)) + 100)
		var noise := FastNoiseLite.new()
		noise.seed = int(def.get("seed", 0))
		noise.frequency = 0.08
		var dirt := Color("6e5a44")
		var grass := Color("5f6a3a")
		var path := Color("8a7458")
		var z0 := int(GROUND_Z0 / GROUND_S)
		var z1 := int(GROUND_Z1 / GROUND_S)
		for sp: Array in RoomFeatures.ground_spans(def.get("features", []), w):
			var xa := int(floorf(float(sp[0]) / GROUND_S))
			var xb := int(ceilf(float(sp[1]) / GROUND_S)) - 1
			if sp[0] <= -99.0:
				xa = int(-400.0 / GROUND_S)
			if sp[1] >= w + 99.0:
				xb = int((w + 400.0) / GROUND_S)
			for x in range(xa, xb + 1):
				for z in range(z0, z1 + 1):
					var n := noise.get_noise_2d(x, z)
					var c := grass.lerp(dirt, clampf(n + 0.4, 0.0, 1.0))
					if z >= -3 and z <= 1:          # 角色走的那条土路
						c = path.darkened(absf(n) * 0.25)
					c = c.darkened(g.rng.randf() * 0.1)
					g.set_v(Vector3i(x, -1, z), c)
					if z == z1:
						for y in range(-8, -1):
							g.set_v(Vector3i(x, y, z), dirt.darkened(0.25 + g.rng.randf() * 0.1))
					elif n > 0.35 and g.rng.randf() < 0.25 and (z < -4 or z > 2):   # 草丛冒出地面
						g.set_v(Vector3i(x, 0, z), grass.lightened(0.1))
			# 坑边：露出土层
			for x in [xa, xb]:
				for z in range(z0, z1 + 1):
					for y in range(-8, -1):
						g.set_v(Vector3i(x, y, z), dirt.darkened(0.3))
		cache["ground"] = g.build(GROUND_S)
	_mi(cache["ground"], Vector3(0, -FLOOR_Y, 0), false)


func _build_props(def: Dictionary, cache: Dictionary) -> void:
	var i := 0
	for pr: Array in def.get("props", []):
		var kind := String(pr[0])
		var x := float(pr[1])
		var base := float(pr[2]) if pr.size() > 2 else 0.0
		var key := "prop|" + kind
		if not cache.has(key):
			var d := VoxelProps.build(kind, 7 + i)
			if d.is_empty():
				cache[key] = null
			else:
				var glow: VoxelGrid = d["glow"]
				cache[key] = {"mesh": (d["grid"] as VoxelGrid).build(VoxelProps.ES),
					"glow": glow.build(VoxelProps.ES, Vector3.ZERO, true) if glow != null else null,
					"lights": d["lights"]}
		var c: Variant = cache[key]
		i += 1
		if c == null:
			continue
		var at := Vector3(x, -(FLOOR_Y - base), 0.0)
		_mi(c["mesh"], at)
		if c["glow"] != null:
			_mi(c["glow"], at, false)
		for l: Array in c["lights"]:
			_light(at + (l[0] as Vector3), l[1], l[2])


## 天色：天空、环境光、雾、主光（太阳或月亮）、逆光，以及中景摆什么
const MOODS := {
	"dusk": {"top": "2a2248", "hor": "b8644a", "gnd": "7a4a42", "amb": "6a6a9e", "amb_e": 0.5, "fog": "5e4a7a", "fog_d": 0.0004,
		"sun": [1.0, 0.76, 0.56], "sun_e": 1.05, "rim": [0.55, 0.62, 1.0], "rim_e": 0.7, "disc": "sun", "bg": "village", "mtn": ["3e3256", "5a4266"]},
	"night": {"top": "080c1e", "hor": "26304e", "gnd": "141a2a", "amb": "3a4a7a", "amb_e": 0.55, "fog": "1c2440", "fog_d": 0.0005,
		"sun": [0.6, 0.72, 1.0], "sun_e": 0.55, "rim": [1.0, 0.7, 0.45], "rim_e": 0.35, "disc": "moon", "bg": "village", "mtn": ["161c32", "222a44"]},
	"graves": {"top": "0c1214", "hor": "2a3a36", "gnd": "141a1a", "amb": "3a5a5a", "amb_e": 0.5, "fog": "26383a", "fog_d": 0.0009,
		"sun": [0.6, 0.85, 0.8], "sun_e": 0.5, "rim": [0.5, 1.0, 0.7], "rim_e": 0.3, "disc": "moon", "bg": "graves", "mtn": ["18221f", "22302c"]},
	"fog": {"top": "3e4250", "hor": "6e7280", "gnd": "4a4c56", "amb": "7a7a8e", "amb_e": 0.5, "fog": "626674", "fog_d": 0.0016,
		"sun": [0.95, 0.95, 1.0], "sun_e": 0.55, "rim": [0.8, 0.85, 1.0], "rim_e": 0.3, "disc": "", "bg": "village", "mtn": ["6a6c78", "80828c"]},
	"bamboo": {"top": "28362e", "hor": "a89a62", "gnd": "4a5a3a", "amb": "6a8a6a", "amb_e": 0.5, "fog": "5a6a4a", "fog_d": 0.0008,
		"sun": [1.0, 0.9, 0.65], "sun_e": 0.9, "rim": [0.7, 1.0, 0.7], "rim_e": 0.4, "disc": "sun", "bg": "bamboo", "mtn": ["2e3e30", "40503e"]},
	"camp": {"top": "100a14", "hor": "4a2220", "gnd": "1a1214", "amb": "5a3a4a", "amb_e": 0.5, "fog": "3a1e22", "fog_d": 0.0006,
		"sun": [0.7, 0.75, 1.0], "sun_e": 0.45, "rim": [1.0, 0.5, 0.3], "rim_e": 0.5, "disc": "moon", "bg": "camp", "mtn": ["1e1418", "2e1e24"]},
	"river": {"top": "060a1a", "hor": "1e2a4a", "gnd": "101626", "amb": "3a4a80", "amb_e": 0.55, "fog": "18223e", "fog_d": 0.00045,
		"sun": [0.65, 0.78, 1.0], "sun_e": 0.7, "rim": [0.7, 0.8, 1.0], "rim_e": 0.4, "disc": "moon", "bg": "river", "mtn": ["121a30", "1c2642"]},
	"temple": {"top": "1e1a3a", "hor": "8a4a4a", "gnd": "3a2a30", "amb": "6a5a8a", "amb_e": 0.5, "fog": "4a3a5a", "fog_d": 0.0005,
		"sun": [1.0, 0.72, 0.5], "sun_e": 0.8, "rim": [0.6, 0.65, 1.0], "rim_e": 0.6, "disc": "moon", "bg": "temple", "mtn": ["2e2646", "443658"]},
	"mist": {"top": "3a4646", "hor": "7a8680", "gnd": "4a5650", "amb": "7a8a82", "amb_e": 0.5, "fog": "66746e", "fog_d": 0.0014,
		"sun": [1.0, 0.97, 0.9], "sun_e": 0.6, "rim": [0.8, 1.0, 0.9], "rim_e": 0.3, "disc": "", "bg": "bamboo", "mtn": ["5a6a62", "707e76"]},
}


static func mood_of(def: Dictionary) -> String:
	match String(def.get("theme", "temple")):
		"village": return String(def.get("mood", "dusk")) if MOODS.has(String(def.get("mood", "dusk"))) else "dusk"
		"river": return "river"
		"bamboo_temple":
			var m := String(def.get("mood", "mist"))
			return {"mist": "mist", "dusk": "bamboo", "night": "night"}.get(m, "mist")
	return "temple"


var _rim: DirectionalLight3D


func _apply_mood(m: Dictionary) -> void:
	var sm: ProceduralSkyMaterial = env.sky.sky_material
	sm.sky_top_color = Color(m["top"])
	sm.sky_horizon_color = Color(m["hor"])
	sm.ground_horizon_color = Color(m["gnd"])
	env.ambient_light_color = Color(m["amb"])
	env.ambient_light_energy = m["amb_e"]
	env.fog_light_color = Color(m["fog"])
	env.fog_density = m["fog_d"]
	var sc: Array = m["sun"]
	sun.light_color = Color(sc[0], sc[1], sc[2])
	sun.light_energy = m["sun_e"]
	if _rim == null:
		for c in get_children():
			if c is DirectionalLight3D and c != sun:
				_rim = c
	var rc: Array = m["rim"]
	_rim.light_color = Color(rc[0], rc[1], rc[2])
	_rim.light_energy = m["rim_e"]


## 远近景：中景（茅草屋和树 / 坟地 / 竹林 / 山贼营 / 河 / 破庙），远处两层山，夕阳或月亮
func _build_scenery(def: Dictionary, w: float, cache: Dictionary) -> void:
	var seed_value := int(def.get("seed", 0))
	var mood := mood_of(def)
	var m: Dictionary = MOODS[mood]
	_apply_mood(m)
	var bg := String(m["bg"])
	if not cache.has("scenery"):
		var items := []
		var r := RandomNumberGenerator.new()
		r.seed = seed_value * 31 + 7
		var night: bool = m["disc"] == "moon"
		var add := func(g: VoxelGrid, size: float, pos: Vector3, glow: VoxelGrid = null) -> void:
			items.append({"mesh": g.build(size), "pos": pos, "glow": glow.build(size, Vector3.ZERO, true) if glow != null and glow.size() > 0 else null})
		if bg == "temple":
			var t := VoxelProps.bg_temple(seed_value)
			add.call(t[0], 6.0, Vector3(w * 0.5, -FLOOR_Y, -190.0), t[1])
		if bg == "river":
			items.append({"mesh": VoxelProps.water(w + 1600.0, seed_value).build(8.0), "pos": Vector3(-800.0, -FLOOR_Y - 6.0, -70.0), "glow": null})
		var x := -300.0
		var k := 0
		while x < w + 300.0:
			x += r.randf_range(110.0, 220.0) if bg != "bamboo" else r.randf_range(50.0, 110.0)
			var z := r.randf_range(-230.0, -150.0)
			var sd := seed_value * 100 + k
			match bg:
				"village":
					if r.randf() < 0.55:
						var hd := VoxelProps.bg_house(sd, r.randf() < (0.8 if night else 0.5))
						add.call(hd[0], 6.0, Vector3(x, -FLOOR_Y, z), hd[1])
					else:
						add.call(VoxelProps.bg_tree(sd), 6.0, Vector3(x, -FLOOR_Y, z))
				"graves":
					add.call(VoxelProps.bg_graves(sd), 4.0, Vector3(x, -FLOOR_Y, z + 60.0))
					if r.randf() < 0.5:
						add.call(VoxelProps.bg_tree(sd + 7, true), 6.0, Vector3(x + 60.0, -FLOOR_Y, z))
				"bamboo":
					add.call(VoxelProps.bg_bamboo(sd), 4.0, Vector3(x, -FLOOR_Y, z + r.randf_range(-60.0, 80.0)))
				"camp":
					if r.randf() < 0.6:
						var tn := VoxelProps.bg_tent(sd)
						add.call(tn[0], 5.0, Vector3(x, -FLOOR_Y, z), tn[1])
						items.append({"light": [Vector3(x + 30.0, -FLOOR_Y + 20.0, z + 30.0), Color(1.0, 0.5, 0.2), 140.0]})
					else:
						add.call(VoxelProps.bg_tree(sd, true), 6.0, Vector3(x, -FLOOR_Y, z))
				"river":
					add.call(VoxelProps.bg_reeds(sd), 4.0, Vector3(x, -FLOOR_Y, -58.0))
					if r.randf() < 0.4:
						add.call(VoxelProps.bg_tree(sd), 8.0, Vector3(x, -FLOOR_Y - 10.0, r.randf_range(-700.0, -520.0)))
				"temple":
					if absf(x - w * 0.5) > 180.0:
						add.call(VoxelProps.bg_tree(sd), 6.0, Vector3(x, -FLOOR_Y, z))
			if bg != "river" and r.randf() < 0.6:   # 再往后一排树
				items.append({"mesh": VoxelProps.bg_tree(sd + 50, bg == "graves" or bg == "camp").build(8.0),
					"pos": Vector3(x + r.randf_range(-60, 60), -FLOOR_Y, r.randf_range(-420.0, -320.0)), "glow": null})
			k += 1
		cache["scenery"] = items
		var mc: Array = m["mtn"]
		cache["mountains"] = VoxelProps.mountains(w + 2400.0, seed_value, Color(mc[0]), 0.8).build(20.0)
		cache["mountains2"] = VoxelProps.mountains(w + 3600.0, seed_value + 9, Color(mc[1]), 1.0).build(36.0)
		if m["disc"] == "sun":
			cache["disc"] = VoxelProps.sun_disc().build(30.0, Vector3.ZERO, true)
		elif m["disc"] == "moon":
			cache["disc"] = VoxelProps.moon_disc().build(18.0, Vector3.ZERO, true)
	for it: Dictionary in cache["scenery"]:
		if it.has("light"):
			var l: Array = it["light"]
			_light(l[0], l[1], l[2])
			continue
		_mi(it["mesh"], it["pos"])
		if it["glow"] != null:
			_mi(it["glow"], it["pos"], false)
	_mi(cache["mountains"], Vector3(-1200.0, -FLOOR_Y - 40.0, -900.0), false)
	_mi(cache["mountains2"], Vector3(-1600.0, -FLOOR_Y - 60.0, -1700.0), false)
	if cache.has("disc"):
		var high: bool = m["disc"] == "moon"
		_mi(cache["disc"], Vector3(w * (0.7 if high else 0.25), -FLOOR_Y + (430.0 if high else 260.0), -2600.0), false)


# ---------- 每帧 ----------

func sync(dt: float) -> void:
	# 镜头跟 2D 镜头对齐（震屏、拉近都带上）
	var c2: Camera2D = main.camera
	var center := c2.get_screen_center_position()
	var zoom := c2.zoom.x
	camera.position = Vector3(center.x, -center.y, CAM_D / zoom)
	# 角色：新出现的建体素人偶，没了的删掉
	var alive := {}
	for p in main.players:
		alive[p] = true
	for e in main.enemies:
		if is_instance_valid(e):
			alive[e] = true
	for f in rigs.keys():
		if not alive.has(f) or not is_instance_valid(f):
			(rigs[f] as Node).queue_free()
			rigs.erase(f)
	for f in alive.keys():
		if not rigs.has(f):
			var rig: Node3D
			if f is Dog:
				rig = VoxelDog.new()
			elif f is Crow:
				rig = VoxelCrow.new()
			else:
				rig = VoxelRig.new()
			add_child(rig)
			rig.setup(f)
			rigs[f] = rig
		rigs[f].sync(dt)
		if f.get("body") != null:
			(f.body as Sprite2D).visible = false
	_sync_objects()
	_sync_features()
	_update_debris(dt)
	_update_ghosts(dt)


var _ghosts: Array = []   # [节点, 材质, 剩余时间, 总时间]

## 闪身、瞬步的残影：把离 pos 最近的那个体素人偶当前的样子拷一份，半透明发光，很快淡掉
func spawn_ghost(pos: Vector2, color: Color, life: float = 0.28) -> void:
	var best: Node3D = null
	var bd := 1e9
	for f in rigs.keys():
		if not is_instance_valid(f) or not (rigs[f] is VoxelRig):
			continue
		var d: float = (f.global_position as Vector2).distance_to(pos)
		if d < bd:
			bd = d
			best = rigs[f]
	if best == null or bd > 160.0:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, 0.5)
	mat.no_depth_test = false
	var g := Node3D.new()
	g.transform = best.transform
	g.position = Vector3(pos.x, -pos.y, best.position.z - 3.0)
	for c in best.get_children():
		if c is MeshInstance3D and c.visible and (c as MeshInstance3D).material_override == null:
			var m := MeshInstance3D.new()
			m.mesh = c.mesh
			m.transform = c.transform
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(m)
	add_child(g)
	_ghosts.append([g, mat, life, life])


func _update_ghosts(dt: float) -> void:
	for i in range(_ghosts.size() - 1, -1, -1):
		var gh: Array = _ghosts[i]
		gh[2] = float(gh[2]) - dt
		var k := clampf(float(gh[2]) / float(gh[3]), 0.0, 1.0)
		if k <= 0.0:
			(gh[0] as Node).queue_free()
			_ghosts.remove_at(i)
			continue
		var mat: StandardMaterial3D = gh[1]
		mat.albedo_color.a = 0.5 * k


## 命中溅出的小方块：往刀的方向飞，落地弹两下，慢慢缩没
func spawn_debris(pos: Vector2, dir: float, count: int, colors: Array) -> void:
	for i in range(count):
		if _debris.size() >= DEBRIS_MAX:
			var old: Array = _debris.pop_front()
			(old[0] as Node).queue_free()
		var mi := MeshInstance3D.new()
		mi.mesh = _debris_mesh
		var col: Color = colors[randi() % colors.size()]
		var key := col.to_html()
		if not _debris_mats.has(key):
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.roughness = 1.0
			if col.v > 0.85:
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_debris_mats[key] = m
		mi.material_override = _debris_mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(pos.x, -pos.y, randf_range(-6.0, 10.0))
		mi.scale = Vector3.ONE * randf_range(0.6, 1.4)
		add_child(mi)
		var sx := (dir if dir != 0.0 else (1.0 if randf() < 0.5 else -1.0)) * randf_range(60.0, 220.0)
		var vel := Vector3(sx, randf_range(60.0, 240.0), randf_range(-80.0, 120.0))
		var spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		_debris.append([mi, vel, randf_range(0.8, 1.4), spin])


func _update_debris(dt: float) -> void:
	var keep: Array = []
	for d: Array in _debris:
		var mi: MeshInstance3D = d[0]
		var vel: Vector3 = d[1]
		d[2] = float(d[2]) - dt
		if d[2] <= 0.0:
			mi.queue_free()
			continue
		vel.y -= 700.0 * dt
		mi.position += vel * dt
		if mi.position.y < -FLOOR_Y + 1.2 and vel.y < 0.0:
			mi.position.y = -FLOOR_Y + 1.2
			vel = Vector3(vel.x * 0.5, -vel.y * 0.35, vel.z * 0.5)
			d[3] = (d[3] as Vector3) * 0.5
		mi.rotation += (d[3] as Vector3) * dt
		if d[2] < 0.3:
			mi.scale = Vector3.ONE * maxf(float(d[2]) / 0.3, 0.05)
		d[1] = vel
		keep.append(d)
	_debris = keep


# ---------- 物件：罐子箱子、宝箱、遗骸、门、土地庙 ----------

const OBJ_KINDS := ["chest", "note", "door", "rest"]


func _sync_objects() -> void:
	var seen := {}
	for b in main.breakables:
		if is_instance_valid(b) and not b.broken:
			seen[b] = true
			var o := _obj(b, String(b.kind))
			var sh := sin(Time.get_ticks_msec() * 0.06) * 1.5 if b._shake > 0.0 else 0.0
			(o["root"] as Node3D).position = Vector3(b.global_position.x + sh, -b.global_position.y, -2.0)
			o["at"] = b.global_position
			b.self_modulate.a = 0.0
	for it in main.interactables:
		if not is_instance_valid(it) or not OBJ_KINDS.has(it.kind) or not it.visible:
			continue
		seen[it] = true
		var o := _obj(it, String(it.kind))
		var root: Node3D = o["root"]
		root.position = Vector3(it.global_position.x, -it.global_position.y, -6.0 if it.kind == "door" or it.kind == "rest" else -2.0)
		it.hide_art = true
		match it.kind:
			"chest":
				var lid: Node3D = o["lid"]
				lid.rotation.x = lerpf(lid.rotation.x, -1.15 if it.used else 0.0, 0.2)
				(o["gold"] as Node3D).visible = it.used
			"door":
				var mat: StandardMaterial3D = o["mat"]
				var glow: Color = it.color if it.enabled else Color(0.08, 0.06, 0.08)
				mat.albedo_color = Color(glow.darkened(0.35), 1.0)
				(o["light"] as OmniLight3D).visible = it.enabled
				(o["light"] as OmniLight3D).light_color = it.color
	for n in _objs.keys():
		if not seen.has(n):
			var o: Dictionary = _objs[n]
			if Breakable.KINDS.has(o["kind"]):
				var at: Vector2 = o["at"]
				spawn_debris(at + Vector2(0, -8), 0.0, 10, VoxelObjects.shard_colors(o["kind"]))
			(o["root"] as Node).queue_free()
			_objs.erase(n)


func _obj(n: Node2D, kind: String) -> Dictionary:
	if _objs.has(n):
		return _objs[n]
	var root := Node3D.new()
	add_child(root)
	var o := {"root": root, "kind": kind, "at": n.global_position}
	var add := func(m: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = pos
		root.add_child(mi)
		return mi
	match kind:
		"chest":
			add.call(VoxelObjects.mesh("chest_base"))
			o["lid"] = add.call(VoxelObjects.mesh("chest_lid"), Vector3(-12.0, 10.0, -8.0))
			o["gold"] = add.call(VoxelObjects.mesh("chest_gold"))
			(o["gold"] as Node3D).visible = false
		"door":
			add.call(VoxelObjects.mesh("door_frame"))
			var panel := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(38, 56)
			panel.mesh = q
			panel.position = Vector3(0, 28, -2)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			panel.material_override = mat
			root.add_child(panel)
			o["mat"] = mat
			var l := OmniLight3D.new()
			l.position = Vector3(0, 24, 14)
			l.omni_range = 70.0
			l.light_energy = 1.2
			root.add_child(l)
			o["light"] = l
		"rest":
			add.call(VoxelObjects.mesh("shrine"))
			add.call(VoxelObjects.mesh("shrine_glow"))
			var l := OmniLight3D.new()
			l.position = Vector3(0, 18, 12)
			l.omni_range = 60.0
			l.light_color = Color(1.0, 0.7, 0.35)
			root.add_child(l)
		_:
			add.call(VoxelObjects.mesh(kind))
	_objs[n] = o
	return o


# ---------- 机关 ----------

func _build_features(def: Dictionary, cache: Dictionary) -> void:
	var f: RoomFeatures = main.features
	if f == null:
		return
	# 坑底竹签、地上的竹签排：合成一块静态网格
	if not cache.has("spikes"):
		var g := VoxelGrid.new(77)
		var depth := -16                                  # 坑底在地面下 64 像素
		for p: Array in f.pits:
			for x in range(int(ceilf(float(p[0]) / 4.0)), int(floorf(float(p[1]) / 4.0))):
				for z in range(-30, 12):
					g.set_v(Vector3i(x, depth - 1, z), Color("2a2220").darkened(g.rng.randf() * 0.2))
				for z in range(-6, 5, 2):
					if (x + z) % 3 == 0:
						g.box(Vector3i(x, depth, z), Vector3i(x, depth + 3, z), Color("8a8a50"))
						g.set_v(Vector3i(x, depth + 4, z), Color("c8c890"))
		for sp: Array in f.spikes:
			for x in range(int(ceilf(float(sp[0]) / 4.0)), int(floorf(float(sp[1]) / 4.0))):
				for z in range(-6, 5, 2):
					if (x + z) % 2 == 0:
						g.box(Vector3i(x, 0, z), Vector3i(x, 2, z), Color("8a8a50"))
						g.set_v(Vector3i(x, 3, z), Color("c8c890"))
		cache["spikes"] = g.build(4.0)
	_mi(cache["spikes"], Vector3(0, -FLOOR_Y, 0), false)
	for pl: Dictionary in f.planks:
		var mi := _mi(VoxelObjects.mesh("plank" if pl["crumble"] else "ledge"), Vector3(pl["x"], -float(pl["top"]), 0.0))
		mi.scale = Vector3(float(pl["w"]) / 24.0, 1, 1)
		_feats.append(["plank", pl, mi])
	for g: Dictionary in f.gates:
		_mi(VoxelObjects.mesh("gate_wall"), Vector3(g["x"], -FLOOR_Y, 0.0))
		var bars := _mi(VoxelObjects.mesh("gate_bars"), Vector3(g["x"], -FLOOR_Y, 0.0))
		_feats.append(["gate", g, bars])
	for lv: Dictionary in f.levers:
		_mi(VoxelObjects.mesh("lever_base"), Vector3(lv["x"], -float(lv["y"]), -6.0))
		var h := _mi(VoxelObjects.mesh("lever_handle"), Vector3(lv["x"], -float(lv["y"]) + 8.0, -6.0))
		_feats.append(["lever", lv, h])
	for ln: Dictionary in f.lanterns:
		var at := Vector3(ln["x"], -float(ln["y"]), -8.0)
		_mi(VoxelObjects.mesh("stone_lantern"), at)
		var gl := _mi(VoxelObjects.mesh("stone_lantern_glow"), at, false)
		var l := OmniLight3D.new()
		l.position = at + Vector3(0, 32, 14)
		l.omni_range = 90.0
		l.light_color = Color(1.0, 0.65, 0.3)
		room.add_child(l)
		_feats.append(["lantern", ln, gl, l])
	for c: Dictionary in f.cracks:
		var wall := _mi(VoxelObjects.mesh("crack"), Vector3(c["x"], -FLOOR_Y, 0.0))
		var rub := _mi(VoxelObjects.mesh("crack_rubble"), Vector3(c["x"], -FLOOR_Y, 0.0))
		_feats.append(["crack", c, wall, rub, false])
	f.self_modulate.a = 0.0


func _sync_features() -> void:
	for ft: Array in _feats:
		var d: Dictionary = ft[1]
		match String(ft[0]):
			"plank":
				var mi: MeshInstance3D = ft[2]
				var base_y := -float(d["top"])
				if float(d["down"]) > 0.0:
					var fl: float = d["fall"]
					mi.visible = fl < 0.6
					mi.position.y = base_y - 260.0 * fl * fl
					mi.rotation.z = fl * 2.0
				else:
					mi.visible = true
					mi.position.y = base_y
					mi.rotation.z = 0.0
					mi.position.x = float(d["x"]) + (sin(Time.get_ticks_msec() * 0.06) if float(d["t"]) >= 0.0 else 0.0)
			"gate":
				var bars: MeshInstance3D = ft[2]
				bars.position.y = -FLOOR_Y + float(d["open"]) * (RoomFeatures.DOOR_H - 8.0)
			"lever":
				(ft[2] as MeshInstance3D).rotation.z = -0.7 if d["on"] else 0.7
			"lantern":
				var lit: float = 1.0 if d["done"] else clampf(float(d["lit"]) / 1.5, 0.0, 1.0)
				(ft[2] as MeshInstance3D).visible = lit > 0.0
				(ft[3] as OmniLight3D).light_energy = 1.6 * lit
			"crack":
				var broken: bool = d["broken"]
				(ft[2] as MeshInstance3D).visible = not broken
				(ft[3] as MeshInstance3D).visible = broken
				if broken and not ft[4]:
					ft[4] = true
					spawn_debris(Vector2(d["x"], FLOOR_Y - 60.0), 0.0, 24, VoxelObjects.shard_colors("crack"))
				(ft[2] as MeshInstance3D).position.x = float(d["x"]) + (sin(Time.get_ticks_msec() * 0.07) * 1.5 if float(d["shake"]) > 0.0 else 0.0)
