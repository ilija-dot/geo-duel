class_name AvatarView
extends Control
## Draws an avatar from its part numbers, at any size. Nothing but simple shapes,
## so it looks sharp on every screen and needs no image files.

var avatar: Dictionary = AvatarParts.defaults():
	set(value):
		avatar = AvatarParts.normalize(value)
		queue_redraw()


static func make(av: Variant, px: int) -> AvatarView:
	var v := AvatarView.new()
	v.avatar = av if av is Dictionary else {}
	v.custom_minimum_size = Vector2(px, px)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _draw() -> void:
	var a := avatar
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	var bg: Color = AvatarParts.BG[a["bg"]]
	var skin: Color = AvatarParts.SKIN[a["skin"]]
	var hair_col: Color = AvatarParts.HAIR_COLOR[a["hair_color"]]
	var hair: String = AvatarParts.HAIR[a["hair"]]
	var ink := Color("2b2230")
	var head_r := r * 0.5
	var hc := c + Vector2(0, -r * 0.02)
	var w := maxf(1.5, r * 0.06)  # line width

	draw_circle(c, r, bg)
	# Shirt: the bottom slice of the background circle.
	draw_colored_polygon(_segment(c, r, r * 0.62, false), bg.darkened(0.35))
	# Neck
	draw_rect(Rect2(hc.x - head_r * 0.28, hc.y + head_r * 0.6, head_r * 0.56, head_r * 0.6), skin.darkened(0.08))

	if hair == "long":
		draw_rect(Rect2(hc.x - head_r * 1.12, hc.y - head_r * 0.2, head_r * 2.24, head_r * 1.5), hair_col)

	# Ears and head
	draw_circle(hc + Vector2(-head_r * 0.98, head_r * 0.1), head_r * 0.2, skin)
	draw_circle(hc + Vector2(head_r * 0.98, head_r * 0.1), head_r * 0.2, skin)
	draw_circle(hc, head_r, skin)

	# Hair on top
	var top := hc + Vector2(0, -head_r)
	match hair:
		"short", "long", "spiky":
			draw_colored_polygon(_segment(hc, head_r * 1.06, -head_r * 0.35, true), hair_col)
			if hair == "spiky":
				for i in 5:
					var x := hc.x + head_r * (-0.8 + i * 0.4)
					var base_y := hc.y - head_r * 0.8
					draw_colored_polygon(PackedVector2Array([Vector2(x - head_r * 0.22, base_y + head_r * 0.2), Vector2(x, base_y - head_r * 0.5), Vector2(x + head_r * 0.22, base_y + head_r * 0.2)]), hair_col)
		"bun":
			draw_colored_polygon(_segment(hc, head_r * 1.04, -head_r * 0.4, true), hair_col)
			draw_circle(top + Vector2(0, -head_r * 0.22), head_r * 0.36, hair_col)
		"curly":
			for i in 7:
				var ang := PI + PI * (i / 6.0)
				draw_circle(hc + Vector2(cos(ang), sin(ang)) * head_r * 0.92, head_r * 0.3, hair_col)
			draw_colored_polygon(_segment(hc, head_r * 0.98, -head_r * 0.45, true), hair_col)
		"mohawk":
			draw_colored_polygon(PackedVector2Array([top + Vector2(-head_r * 0.2, head_r * 0.25), top + Vector2(0, -head_r * 0.55), top + Vector2(head_r * 0.2, head_r * 0.25)]), hair_col)
			draw_rect(Rect2(top.x - head_r * 0.2, top.y - head_r * 0.2, head_r * 0.4, head_r * 0.6), hair_col)

	# Eyes
	var le := hc + Vector2(-head_r * 0.38, -head_r * 0.02)
	var re := hc + Vector2(head_r * 0.38, -head_r * 0.02)
	match AvatarParts.EYES[a["eyes"]]:
		"dots":
			draw_circle(le, head_r * 0.1, ink)
			draw_circle(re, head_r * 0.1, ink)
		"big":
			for e in [le, re]:
				draw_circle(e, head_r * 0.19, Color.WHITE)
				draw_circle(e + Vector2(0, head_r * 0.03), head_r * 0.1, ink)
		"happy":
			draw_arc(le + Vector2(0, head_r * 0.06), head_r * 0.13, PI, TAU, 12, ink, w)
			draw_arc(re + Vector2(0, head_r * 0.06), head_r * 0.13, PI, TAU, 12, ink, w)
		"sleepy":
			draw_line(le + Vector2(-head_r * 0.14, 0), le + Vector2(head_r * 0.14, 0), ink, w)
			draw_line(re + Vector2(-head_r * 0.14, 0), re + Vector2(head_r * 0.14, 0), ink, w)
		"wink":
			draw_circle(le, head_r * 0.1, ink)
			draw_arc(re + Vector2(0, head_r * 0.06), head_r * 0.13, PI, TAU, 12, ink, w)

	# Cheeks
	draw_circle(hc + Vector2(-head_r * 0.58, head_r * 0.3), head_r * 0.12, Color(1, 0.45, 0.45, 0.25))
	draw_circle(hc + Vector2(head_r * 0.58, head_r * 0.3), head_r * 0.12, Color(1, 0.45, 0.45, 0.25))

	# Mouth
	var m := hc + Vector2(0, head_r * 0.42)
	match AvatarParts.MOUTH[a["mouth"]]:
		"smile":
			draw_arc(m + Vector2(0, -head_r * 0.12), head_r * 0.24, 0.2, PI - 0.2, 14, ink, w)
		"open":
			draw_colored_polygon(_segment(m + Vector2(0, -head_r * 0.06), head_r * 0.24, 0.0, false), ink)
		"flat":
			draw_line(m + Vector2(-head_r * 0.18, 0), m + Vector2(head_r * 0.18, 0), ink, w)
		"o":
			draw_arc(m, head_r * 0.11, 0, TAU, 16, ink, w)
		"tongue":
			draw_colored_polygon(_segment(m + Vector2(0, -head_r * 0.06), head_r * 0.24, 0.0, false), ink)
			draw_circle(m + Vector2(0, head_r * 0.1), head_r * 0.1, Color("ff6f8a"))

	# Accessory
	match str(AvatarParts.accessory(a["acc"])["id"]):
		"glasses":
			for e in [le, re]:
				draw_arc(e, head_r * 0.22, 0, TAU, 20, ink, w)
			draw_line(le + Vector2(head_r * 0.22, 0), re - Vector2(head_r * 0.22, 0), ink, w)
		"sunglasses":
			for e in [le, re]:
				draw_circle(e, head_r * 0.24, Color("1a1a24"))
				draw_circle(e + Vector2(-head_r * 0.08, -head_r * 0.08), head_r * 0.06, Color(1, 1, 1, 0.5))
			draw_line(le + Vector2(head_r * 0.22, 0), re - Vector2(head_r * 0.22, 0), Color("1a1a24"), w)
		"flower":
			var f := hc + Vector2(head_r * 0.7, -head_r * 0.75)
			for i in 5:
				var ang := TAU * i / 5.0
				draw_circle(f + Vector2(cos(ang), sin(ang)) * head_r * 0.17, head_r * 0.13, Color("ff8fc2"))
			draw_circle(f, head_r * 0.1, Color("ffd34d"))
		"cap":
			var cap_col := Color("e53935")
			draw_colored_polygon(_segment(hc, head_r * 1.08, -head_r * 0.42, true), cap_col)
			draw_rect(Rect2(hc.x - head_r * 0.2, hc.y - head_r * 0.5, head_r * 1.4, head_r * 0.16), cap_col.darkened(0.25))
		"headphones":
			draw_arc(hc, head_r * 1.08, PI * 1.05, PI * 1.95, 20, Color("30333f"), maxf(2.0, head_r * 0.16))
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(hc.x + side * head_r * 1.0 - head_r * 0.17, hc.y - head_r * 0.15, head_r * 0.34, head_r * 0.55), Color("30333f"))
		"crown":
			var cy := hc.y - head_r * 0.85
			var gold := Color("f5c542")
			draw_colored_polygon(PackedVector2Array([
				Vector2(hc.x - head_r * 0.6, cy + head_r * 0.2), Vector2(hc.x - head_r * 0.6, cy - head_r * 0.35),
				Vector2(hc.x - head_r * 0.3, cy - head_r * 0.05), Vector2(hc.x, cy - head_r * 0.5),
				Vector2(hc.x + head_r * 0.3, cy - head_r * 0.05), Vector2(hc.x + head_r * 0.6, cy - head_r * 0.35),
				Vector2(hc.x + head_r * 0.6, cy + head_r * 0.2)]), gold)
			draw_circle(Vector2(hc.x, cy - head_r * 0.05), head_r * 0.08, Color("e53935"))


## The part of a circle above (or below) a horizontal line `offset` from its center.
func _segment(center: Vector2, radius: float, offset: float, above: bool) -> PackedVector2Array:
	var k := clampf(offset / radius, -0.999, 0.999)
	var t1 := asin(k)
	var t2 := PI - t1
	var from := t2 if above else t1
	var to := t1 + TAU if above else t2
	var pts := PackedVector2Array()
	for i in 25:
		var t := lerpf(from, to, i / 24.0)
		pts.append(center + Vector2(cos(t), sin(t)) * radius)
	return pts
