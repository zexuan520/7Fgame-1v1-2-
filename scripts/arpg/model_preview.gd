class_name ModelPreview
extends Control
## 菜单右边的转台小窗：衣箱、兵器架里光标移到哪一项，就转着给你看穿上 / 拿上是什么样（审查第 16 条）。
## 自己一个 3D 小世界（不受房间灯光、调色影响），挂在 ArpgMenu 底下，菜单关了跟着没。
## pick(index) → {"skin": 皮肤 id, "weapon": 兵器 id}

var menu: ArpgMenu
var pick: Callable
var _vp: SubViewport
var _holder: Node3D
var _rig: VoxActor
var _key := ""
var _t := 0.0
const W := 260
const H := 340


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.size = Vector2i(W, H)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	cam.position = Vector3(0, 2.1, 6.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.05, 0))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.rotation = Vector3(-0.9, 0.6, 0)
	_vp.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.9
	env.environment = e
	_vp.add_child(env)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	size = Vector2(W, H)


func _process(dt: float) -> void:
	if not is_instance_valid(menu):
		queue_free()
		return
	var vs := get_viewport_rect().size
	# 列表在屏幕正中宽 620；转台放右边空着的地方，放不下（竖屏、小窗）就不显示
	var x := (vs.x + 620.0) * 0.5 + 80.0
	var room := vs.x - x - 16.0
	visible = room >= 170.0
	if not visible:
		return
	var k := minf(1.0, room / float(W))
	scale = Vector2(k, k)
	position = Vector2(x, vs.y * 0.16 + 70.0)
	var want: Dictionary = pick.call(menu.index)
	var key := "%s|%s" % [want.get("skin", ""), want.get("weapon", "")]
	if key != _key:
		_key = key
		_build(String(want.get("skin", "qing")), String(want.get("weapon", "sword")))
	_t += dt
	_holder.rotation.y = PI + _t * 0.9   # 人偶正面朝 -z，先转过来对着镜头
	if _rig != null:
		_rig.apply(Poses.idle(_t))
	queue_redraw()


func _build(skin_id: String, weapon_id: String) -> void:
	if _rig != null:
		_rig.queue_free()
	var sk := ArpgArms.skin(skin_id)
	var w := ArpgData.weapon(weapon_id)
	_rig = VoxActor.new()
	_holder.add_child(_rig)
	_rig.setup(String(sk.get("model", "hero_canren")), String(w["model"]), float(w["len"]), Color(1, 1, 1), float(sk.get("k", 1.0)))
	_rig.set_offhand(String(w.get("offhand", "")), float(w["len"]))
	var rc: Color = sk.get("rim", Color(0.45, 0.95, 1.0))
	_rig.set_rim(rc, 0.6)
	_rig.mat.set_shader_parameter("swap_green", sk.has("swap"))
	if sk.has("swap"):
		var sc: Color = sk["swap"]
		_rig.mat.set_shader_parameter("swap_color", Vector3(sc.r, sc.g, sc.b))
	_rig.mat.set_shader_parameter("light_neutral", float(sk.get("neutral", 0.0)))
	_rig.mat.set_shader_parameter("swap_glow", float(sk.get("swap_glow", 0.0)))
	_rig.set_glow(sk.get("glow", Color(0, 0, 0)))
	# 正面先朝镜头，再慢慢转
	_t = 0.0


func _draw() -> void:
	# 底下一块深色衬底 + 金边，和菜单一个样式
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.03, 0.06, 0.07, 0.88))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(ArpgMenu.TEAL, 0.35), false, 1.0)
	draw_set_transform(Vector2(W * 0.5, H * 0.83), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 80.0, Color(0.9, 0.8, 0.5, 0.12))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(W, H)), false)


## 菜单开着时挂一个转台
static func attach(m: ArpgMenu, picker: Callable) -> ModelPreview:
	var p := ModelPreview.new()
	p.menu = m
	p.pick = picker
	m.add_child(p)
	return p
