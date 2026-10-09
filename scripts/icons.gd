class_name Icons
extends RefCounted
## 小像素图标（约 12×12）：地图节点、门匾、货物、供台、界面上的铜钱和魂玉都用这里画。


static func draw(c: CanvasItem, id: String, at: Vector2, col: Color) -> void:
	var p := at.round()
	var o := Color(0.03, 0.02, 0.04, col.a)
	var hi := col.lightened(0.4)
	var dk := col.darkened(0.35)
	match id:
		"fight":
			# 两把交叉的刀
			c.draw_line(p + Vector2(-5, -5), p + Vector2(4, 4), hi, 2.0)
			c.draw_line(p + Vector2(5, -5), p + Vector2(-4, 4), col, 2.0)
			c.draw_rect(Rect2(p + Vector2(2, 2), Vector2(3, 3)), dk)
			c.draw_rect(Rect2(p + Vector2(-5, 2), Vector2(3, 3)), dk)
		"elite":
			# 鬼面：两只角 + 红脸
			c.draw_circle(p + Vector2(0, 1), 5, col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(-6, -7), p + Vector2(-2, -4)]), hi)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(5, -2), p + Vector2(6, -7), p + Vector2(2, -4)]), hi)
			c.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(2, 2)), o)
			c.draw_rect(Rect2(p + Vector2(1, -1), Vector2(2, 2)), o)
			c.draw_rect(Rect2(p + Vector2(-2, 3), Vector2(4, 1)), o)
		"shop":
			# 钱袋
			c.draw_circle(p + Vector2(0, 2), 5, col)
			c.draw_rect(Rect2(p + Vector2(-2, -5), Vector2(4, 3)), dk)
			c.draw_rect(Rect2(p + Vector2(-3, -3), Vector2(6, 1)), hi)
			c.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 2)), dk)
		"rest":
			# 香炉 + 一缕烟
			c.draw_rect(Rect2(p + Vector2(-5, 1), Vector2(10, 4)), col)
			c.draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 1)), hi)
			c.draw_rect(Rect2(p + Vector2(-4, 5), Vector2(1, 1)), dk)
			c.draw_rect(Rect2(p + Vector2(3, 5), Vector2(1, 1)), dk)
			c.draw_line(p + Vector2(0, -1), p + Vector2(-1, -4), hi, 1.0)
			c.draw_line(p + Vector2(-1, -4), p + Vector2(1, -7), hi, 1.0)
		"boss":
			# 一把竖着的刀，刀身发光
			c.draw_line(p + Vector2(0, -7), p + Vector2(0, 3), hi, 2.0)
			c.draw_rect(Rect2(p + Vector2(-3, 3), Vector2(7, 1)), col)
			c.draw_rect(Rect2(p + Vector2(0, 4), Vector2(1, 3)), dk)
		"start", "temple":
			# 小庙
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -1), p + Vector2(6, -1), p + Vector2(3, -5), p + Vector2(-3, -5)]), col)
			c.draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 6)), dk)
			c.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 4)), o)
		"coin":
			c.draw_circle(p, 3.5, Color("b8742e"))
			c.draw_circle(p, 2.5, Color("d89a48"))
			c.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2)), Color("4a2a14"))
		"jade":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)]), Color("5ed6a8"))
			c.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(1, 2)), Color("d8fff0"))
		# ---------- 货物 ----------
		"refill", "gourd":
			var body := col if id == "refill" else col.darkened(0.3)
			c.draw_circle(p + Vector2(0, 2), 4, o)
			c.draw_circle(p + Vector2(0, -3), 3, o)
			c.draw_circle(p + Vector2(0, 2), 3, body)
			c.draw_circle(p + Vector2(0, -3), 2, body)
			c.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(4, 1)), Color("c9a24a"))
			c.draw_rect(Rect2(p + Vector2(-1, -6), Vector2(2, 1)), Color("6b4a2a"))
			if id == "gourd":
				c.draw_rect(Rect2(p + Vector2(4, -5), Vector2(1, 3)), hi)
				c.draw_rect(Rect2(p + Vector2(3, -4), Vector2(3, 1)), hi)
		"heal":
			# 纸包的药
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 3), p + Vector2(5, 3), p + Vector2(3, -3), p + Vector2(-3, -3)]), Color("e8dcc0"))
			c.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 3)), col)
			c.draw_rect(Rect2(p + Vector2(-4, 0), Vector2(8, 1)), col)
		"whetstone":
			c.draw_rect(Rect2(p + Vector2(-6, -2), Vector2(12, 5)), o)
			c.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 4)), Color("8a8a96"))
			c.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 1)), Color("c0c0cc"))
			c.draw_line(p + Vector2(-4, -5), p + Vector2(4, -3), hi, 1.0)
		"amulet", "vigor":
			c.draw_circle(p + Vector2(0, 1), 4, o)
			c.draw_circle(p + Vector2(0, 1), 3, col)
			c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 2)), hi)
			c.draw_line(p + Vector2(-3, -2), p + Vector2(0, -6), dk, 1.0)
			c.draw_line(p + Vector2(3, -2), p + Vector2(0, -6), dk, 1.0)
		"guard_charm":
			# 黄符
			c.draw_rect(Rect2(p + Vector2(-3, -6), Vector2(6, 12)), o)
			c.draw_rect(Rect2(p + Vector2(-2, -5), Vector2(4, 10)), Color("e0c050"))
			c.draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 1)), Color("a02020"))
			c.draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 5)), Color("a02020"))
		"purse":
			for i in range(3):
				draw(c, "coin", p + Vector2(-4 + i * 4, 2 - (i % 2) * 3), col)
		_:
			c.draw_circle(p, 4, col)
