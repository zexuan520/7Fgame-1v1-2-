class_name Breakable
extends Node2D
## 能砍碎的东西：陶罐、酒坛、木桶、小木箱。砍碎了崩出碎片，按掉落表掉铜钱、伤药，偶尔有魂玉。
## 主场景每帧拿玩家正在出手的判定框来碰它（见 main._hit_breakables）。

## 种类：hp 几刀砍碎，size 判定框，loot [[掉什么, 概率, 最少, 最多], ...]
const KINDS := {
	"jar": {"hp": 1, "size": Vector2(12, 14), "loot": [["coin", 0.75, 1, 4], ["heal", 0.15, 1, 1], ["jade", 0.04, 1, 1]]},
	"urn": {"hp": 1, "size": Vector2(14, 20), "loot": [["coin", 0.9, 2, 6], ["heal", 0.2, 1, 1], ["jade", 0.06, 1, 1]]},
	"barrel": {"hp": 2, "size": Vector2(16, 20), "loot": [["coin", 1.0, 3, 7], ["heal", 0.25, 1, 1], ["jade", 0.08, 1, 1]]},
	"box": {"hp": 2, "size": Vector2(16, 16), "loot": [["coin", 1.0, 2, 5], ["heal", 0.1, 1, 1]]},
}

var kind := "jar"
var main: Node
var hp := 1
var broken := false
var _hit_cd := 0.0
var _shake := 0.0
var _seed := 0


func _ready() -> void:
	hp = KINDS[kind]["hp"]
	_seed = int(position.x)


func rect() -> Rect2:
	var s: Vector2 = KINDS[kind]["size"]
	return Rect2(global_position - Vector2(s.x / 2.0, s.y), s)


## 被砍一刀。返回 true 表示这一刀算数
func hit(from_x: float) -> bool:
	if broken or _hit_cd > 0.0:
		return false
	_hit_cd = 0.18
	hp -= 1
	_shake = 0.2
	main.spawn_spark(global_position + Vector2(0, -8), Color(0.95, 0.8, 0.5), 5)
	if hp <= 0:
		_break(signf(global_position.x - from_x))
	return true


func _break(dir: float) -> void:
	broken = true
	var col := _color()
	var shards := Fx.Particles.new()
	shards.position = global_position + Vector2(0, -8)
	shards.color = col
	shards.count = 12
	shards.dir = dir
	shards.speed = Vector2(110, 150)
	shards.gravity = 520.0
	shards.life = 0.6
	main.fx_root.add_child(shards)
	main.spawn_dust(global_position, dir, 6)
	main.shake(1.5)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for l: Array in KINDS[kind]["loot"]:
		if rng.randf() < float(l[1]):
			main.spawn_pickups(l[0], rng.randi_range(int(l[2]), int(l[3])), global_position + Vector2(0, -10), global_position.y)
	queue_free()


func _process(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()


func _color() -> Color:
	match kind:
		"barrel", "box": return Color("6a4a30")
		"urn": return Color("5a4a5a")
	return Color("8a5a3a")


func _draw() -> void:
	var o := Color("0c080a")
	var off := Vector2(roundf(sin(_shake * 80.0) * 2.0 * (_shake / 0.2)), 0)
	draw_set_transform(off, 0.0, Vector2.ONE)
	match kind:
		"jar":
			# 陶罐：圆肚子、窄口
			draw_circle(Vector2(0, -6), 7, o)
			draw_circle(Vector2(0, -6), 6, Color("8a5a3a"))
			draw_circle(Vector2(-2, -8), 2, Color("b07a4a"))
			draw_rect(Rect2(-4, -14, 8, 4), o)
			draw_rect(Rect2(-3, -13, 6, 3), Color("6a4028"))
			draw_rect(Rect2(-6, -6, 12, 1), Color("5a3420"))
		"urn":
			# 酒坛：贴着红纸，口上扎着布
			draw_rect(Rect2(-7, -19, 14, 19), o)
			draw_circle(Vector2(0, -9), 8, o)
			draw_circle(Vector2(0, -9), 7, Color("4a3e4a"))
			draw_rect(Rect2(-6, -17, 12, 16), Color("4a3e4a"))
			draw_rect(Rect2(-6, -17, 2, 16), Color("6a5e6a"))
			draw_rect(Rect2(-3, -13, 6, 7), Color("a82a24"))
			draw_rect(Rect2(-1, -11, 2, 3), Color("e8c060"))
			draw_rect(Rect2(-5, -21, 10, 4), Color("c8b088"))
		"barrel":
			draw_rect(Rect2(-9, -21, 18, 21), o)
			draw_rect(Rect2(-8, -20, 16, 20), Color("6a4a30"))
			draw_rect(Rect2(-8, -20, 3, 20), Color("8a6440"))
			for y in [-17, -10, -3]:
				draw_rect(Rect2(-8, y, 16, 2), Color("3a3036"))
			draw_rect(Rect2(-8, -20, 16, 1), Color("a07850"))
		"box":
			draw_rect(Rect2(-9, -17, 18, 17), o)
			draw_rect(Rect2(-8, -16, 16, 16), Color("6a4a30"))
			draw_rect(Rect2(-8, -16, 16, 2), Color("9a6a42"))
			draw_line(Vector2(-7, -1), Vector2(7, -15), Color("3a2418"), 2.0)
			draw_rect(Rect2(-6, -14, 12, 12), Color("3a2418"), false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
