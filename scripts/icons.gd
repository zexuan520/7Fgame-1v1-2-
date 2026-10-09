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
		"herb":
			# 伤药：一小包红色药丸 + 两片叶子
			c.draw_circle(p + Vector2(0, 1), 3, o)
			c.draw_circle(p + Vector2(0, 1), 2.5, Color("d8443a"))
			c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), Color("ffb0a0"))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2), p + Vector2(-4, -5), p + Vector2(-1, -5)]), Color("5aa04a"))
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2), p + Vector2(4, -5), p + Vector2(1, -5)]), Color("7ac06a"))
		"chest":
			c.draw_rect(Rect2(p + Vector2(-6, -3), Vector2(12, 8)), o)
			c.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 6)), col)
			c.draw_rect(Rect2(p + Vector2(-5, -2), Vector2(10, 2)), hi)
			c.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2, 2)), Color("e8c060"))
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
		# ---------- 装备 ----------
		"w_katana", "w_nodachi":
			# 刀：横放，刀柄在左
			var len := 9.0 if id == "w_katana" else 12.0
			c.draw_line(p + Vector2(-len + 2, 1), p + Vector2(len, -2), o, 3.0)
			c.draw_line(p + Vector2(-len + 5, 1), p + Vector2(len, -2), Color("d8e0ea"), 1.0)
			c.draw_rect(Rect2(p + Vector2(-len + 3, -1), Vector2(1, 4)), Color("c9a227"))
			c.draw_line(p + Vector2(-len - 1, 2), p + Vector2(-len + 3, 1), Color("3a2418"), 2.0)
		"w_dual":
			for k in [-2, 2]:
				c.draw_line(p + Vector2(-5, k + 1), p + Vector2(5, k - 1), o, 3.0)
				c.draw_line(p + Vector2(-2, k + 1), p + Vector2(5, k - 1), Color("d8e0ea"), 1.0)
				c.draw_rect(Rect2(p + Vector2(-5, k), Vector2(2, 2)), Color("3a2418"))
		"w_spear":
			c.draw_line(p + Vector2(-8, 2), p + Vector2(6, -1), o, 3.0)
			c.draw_line(p + Vector2(-8, 2), p + Vector2(5, -1), Color("8a5a36"), 1.0)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(4, -3), p + Vector2(10, -2), p + Vector2(5, 1)]), Color("d8e0ea"))
			c.draw_rect(Rect2(p + Vector2(3, -1), Vector2(2, 3)), Color("d0302a"))
		"w_fist":
			c.draw_circle(p, 5, o)
			c.draw_circle(p, 4, Color("6a707e"))
			for k in range(3):
				c.draw_rect(Rect2(p + Vector2(-3 + k * 2.5, -4), Vector2(2, 2)), Color("a8aebb"))
			c.draw_rect(Rect2(p + Vector2(-4, 1), Vector2(8, 1)), Color("4a4e58"))
		"hood":
			c.draw_circle(p + Vector2(0, 1), 5, o)
			c.draw_circle(p + Vector2(0, 1), 4, Color("4a4a6a"))
			c.draw_rect(Rect2(p + Vector2(-4, 2), Vector2(8, 3)), o)
			c.draw_rect(Rect2(p + Vector2(4, 0), Vector2(3, 2)), Color("4a4a6a"))
		"kasa":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(0, -5)]), o)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 1), p + Vector2(6, 1), p + Vector2(0, -4)]), Color("b8955a"))
			c.draw_line(p + Vector2(-3, -1), p + Vector2(3, -1), Color("7d6138"), 1.0)
		"kabuto":
			c.draw_circle(p + Vector2(0, 1), 5, o)
			c.draw_circle(p + Vector2(0, 1), 4, Color("5a5e6a"))
			c.draw_rect(Rect2(p + Vector2(-6, 2), Vector2(12, 2)), Color("4a4e58"))
			c.draw_line(p + Vector2(-1, -2), p + Vector2(-3, -7), Color("d8b040"), 1.0)
			c.draw_line(p + Vector2(1, -2), p + Vector2(3, -7), Color("d8b040"), 1.0)
		"vest", "leather", "plate":
			var body: Color = {"vest": Color("3a5a4a"), "leather": Color("6a4a30"), "plate": Color("5a5e6a")}[id]
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -6), p + Vector2(6, -6), p + Vector2(5, 6), p + Vector2(-5, 6)]), o)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -5), p + Vector2(5, -5), p + Vector2(4, 5), p + Vector2(-4, 5)]), body)
			c.draw_rect(Rect2(p + Vector2(-1, -5), Vector2(2, 3)), o)
			if id == "plate":
				for k in range(3):
					c.draw_rect(Rect2(p + Vector2(-4, -2 + k * 2.5), Vector2(8, 1)), body.darkened(0.35))
			else:
				c.draw_rect(Rect2(p + Vector2(-4, 2), Vector2(8, 1)), body.lightened(0.3))
		"charm":
			# 挂坠：一根绳子吊着一块玉
			c.draw_line(p + Vector2(-3, -6), p + Vector2(0, -2), Color("c8b07a"), 1.0)
			c.draw_line(p + Vector2(3, -6), p + Vector2(0, -2), Color("c8b07a"), 1.0)
			c.draw_circle(p + Vector2(0, 2), 4, o)
			c.draw_circle(p + Vector2(0, 2), 3, col)
			c.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(1, 1)), hi)
		"talent":
			# 一截骨头
			c.draw_line(p + Vector2(-4, 3), p + Vector2(4, -3), o, 4.0)
			c.draw_line(p + Vector2(-4, 3), p + Vector2(4, -3), Color("e0d8c0"), 2.0)
			for e: Vector2 in [Vector2(-5, 3), Vector2(-4, 5), Vector2(5, -3), Vector2(4, -5)]:
				c.draw_circle(p + e, 1.6, Color("e0d8c0"))
		"purse":
			for i in range(3):
				draw(c, "coin", p + Vector2(-4 + i * 4, 2 - (i % 2) * 3), col)
		_:
			c.draw_circle(p, 4, col)


static func gear_icon(item: Dictionary) -> String:
	match String(item["slot"]):
		"weapon": return "w_" + String(item["base"])
		"charm": return "charm"
	return String(item["base"])
