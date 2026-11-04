class_name Crow
extends Enemy
## 鸦：会飞的杂兵（快节奏改造加的）。不受重力，在玩家斜上方盘旋，蓄一下就朝玩家俯冲啄过去，
## 啄完飞回高处。血少，一刀两刀就掉；空中砍中会被打得往上翻，正好接空中连段和钩锁突进。
## 受击、伤害、掉落都走 Enemy 的那一套，只是移动和出招自己写。

const HOVER_H := 105.0       # 在玩家头顶多高盘旋
const HOVER_SIDE := 80.0     # 偏到玩家哪一侧多远
const DIVE_SPEED := 470.0
const DIVE_TIME := 0.5
const FLAP_FREQ := 11.0

var _dive_dir := Vector2.ZERO
var _home_side := 1.0


func _ready() -> void:
	super._ready()
	_home_side = 1.0 if rng.randf() < 0.5 else -1.0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	state_time += delta
	_tick_bleed(delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	attack_cooldown -= delta
	_clock += delta
	match state:
		S.IDLE: _fly_idle(delta)
		S.WINDUP: _fly_windup(delta)
		S.ACTIVE: _fly_dive(delta)
		S.RECOVER:
			velocity = velocity.move_toward(Vector2(0, -120.0), 900.0 * delta)
			if state_time >= 0.45:
				attack_cooldown = rng.randf_range(1.0, 1.8)
				_enter(S.IDLE)
		S.FLINCH, S.STAGGER, S.GUARD, S.BROKEN:
			# 挨刀：被打得翻一下，有点往下坠，很快又扑腾起来
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			velocity.y = move_toward(velocity.y, 60.0, 900.0 * delta)
			if state_time >= (stagger_time if state == S.STAGGER else 0.35):
				attack_cooldown = maxf(attack_cooldown, 0.4)
				_enter(S.IDLE)
		S.DYING:
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
			velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
			if state_time >= 1.6:
				visible = false
				_enter(S.DEAD)
		S.DEAD:
			velocity = Vector2.ZERO
		_:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	# 不让飞出房间、钻进地里
	if state != S.DYING:
		var floor_y: float = main.FLOOR_Y
		if global_position.y > floor_y - 18.0 and velocity.y > 0.0 and state != S.ACTIVE:
			velocity.y = -80.0
	global_position.x = clampf(global_position.x, 16.0, float(main.arena_w) - 16.0)
	move_and_slide()
	queue_redraw()


func _fly_idle(delta: float) -> void:
	target = main.visible_player(global_position)
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		return
	if not aggro:
		if global_position.distance_to(target.global_position) < AGGRO_RANGE:
			wake()
		else:
			velocity = Vector2(0, sin(_clock * 2.0) * 10.0)
			return
	var tp := target.global_position
	var goal := tp + Vector2(_home_side * HOVER_SIDE, -HOVER_H) + Vector2(sin(_clock * 1.7) * 18.0, sin(_clock * 3.1) * 10.0)
	var d := goal - global_position
	var speed: float = data["speed"]
	velocity = velocity.move_toward(d.limit_length(1.0) * minf(speed, d.length() * 3.0), 700.0 * delta)
	facing = 1 if tp.x >= global_position.x else -1
	if rng.randf() < 0.25 * delta:
		_home_side = -_home_side   # 时不时换到另一边
	var dist := global_position.distance_to(tp)
	if attack_cooldown <= 0.0 and dist < 230.0 and main.can_attack(self):
		_start_move("dive")


func _fly_windup(delta: float) -> void:
	# 往后上方一缩，抖两下，然后锁定方向
	velocity = velocity.move_toward(Vector2(-facing * 50.0, -40.0), 600.0 * delta)
	if target != null and is_instance_valid(target):
		facing = 1 if target.global_position.x >= global_position.x else -1
	if state_time >= _hit_times()[0] * _speed():
		var aim := global_position + Vector2(facing * 60.0, 60.0)
		if target != null and is_instance_valid(target):
			aim = target.global_position + Vector2(0, -20.0)
		_dive_dir = (aim - global_position).normalized()
		if _dive_dir.y < 0.15:
			_dive_dir = Vector2(_dive_dir.x, 0.15).normalized()
		hit_targets.clear()
		Game.sfx("dodge", -4.0, 0.3)
		_enter(S.ACTIVE)


func _fly_dive(_delta: float) -> void:
	velocity = _dive_dir * DIVE_SPEED
	var m := _move()
	var r := Rect2(global_position + Vector2(-14, -22), Vector2(28, 24))
	for p: Player in main.get_players():
		if p in hit_targets or not p.is_alive():
			continue
		if r.intersects(p.body_rect()):
			hit_targets.append(p)
			var info := m
			if dmg_mult != 1.0:
				info = m.duplicate()
				info["dmg"] = float(m["dmg"]) * dmg_mult
			var result := p.receive_enemy_hit(info, self)
			_on_attack_result(result, p)
			if state != S.ACTIVE:
				return
	if state_time >= DIVE_TIME or (get_slide_collision_count() > 0 and state_time > 0.08):
		_enter(S.RECOVER)


## 弹反、挨刀都让它往后翻开
func _stagger(t: float) -> void:
	super._stagger(t)
	velocity = Vector2(-facing * 160.0, -120.0)


func _glint_pos() -> Vector2:
	return Vector2(facing * 12.0, -16.0)


func _draw() -> void:
	if state == S.DEAD:
		return
	# 地上的影子：离地越高越小越淡
	var floor_y: float = main.FLOOR_Y if main != null else 300.0
	var h := clampf(floor_y - global_position.y, 0.0, 200.0)
	draw_set_transform(Vector2(0, h), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 10.0 * (1.0 - h / 300.0), Color(0, 0, 0, 0.35 * (1.0 - h / 260.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Game.voxel:
		if state != S.DYING:
			_draw_overlay(-34.0, _danger())
		return
	var lk: Dictionary = data["look"]
	var tint := _tint()
	var body_c: Color = lk["feather"]
	var dark: Color = lk["feather_dark"]
	if tint.a > 0.0:
		body_c = body_c.lerp(Color(tint, 1.0), minf(tint.a, 1.0))
		dark = dark.lerp(Color(tint, 1.0), minf(tint.a, 1.0))
	var f := float(facing)
	var flap := sin(_clock * FLAP_FREQ * (2.0 if state == S.WINDUP else 1.0))
	var tilt := 0.0
	if state == S.ACTIVE:
		flap = -0.8
		tilt = 0.5
	var c := Vector2(0, -14)
	draw_set_transform(c, tilt * f, Vector2(f, 1.0))
	# 身子、头、喙、尾巴
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-2, -5), Vector2(8, -4), Vector2(10, 1), Vector2(0, 5), Vector2(-9, 3)]), body_c)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-17, -3), Vector2(-16, 4), Vector2(-9, 3)]), dark)
	draw_circle(Vector2(10, -3), 4.0, body_c)
	draw_colored_polygon(PackedVector2Array([Vector2(13, -4), Vector2(19, -1), Vector2(13, 0)]), Color(lk["beak"]))
	draw_rect(Rect2(10, -5, 2, 2), Color(1.0, 0.85, 0.3) if state != S.WINDUP else Color(1, 0.3, 0.2))
	# 翅膀：上下扇
	var tip := Vector2(-4, -6 - 14.0 * flap)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -3), Vector2(5, -3), tip + Vector2(2, 0), tip]), dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state != S.DYING:
		_draw_overlay(-34.0, _danger())
