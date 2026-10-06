extends RefCounted
## Dibujo procedural de cubos isometricos (128x64 px de cara superior) con distintos acabados.
## Lo usa demo_arte.gd para probar los personajes sobre muchos entornos.

const TW := 64.0
const TH := 32.0
const OUT := Color(0.16, 0.10, 0.07, 0.9)

const TYPES := [
	{"n": "Hierba", "top": Color(0.50, 0.80, 0.24), "side_l": Color(0.58, 0.38, 0.20), "side_r": Color(0.46, 0.30, 0.16), "k": "grass", "d1": Color(0.33, 0.62, 0.15), "d2": Color(0.74, 0.92, 0.42)},
	{"n": "Tierra", "top": Color(0.72, 0.46, 0.27), "k": "dirt", "d1": Color(0.50, 0.30, 0.17), "d2": Color(0.85, 0.60, 0.40)},
	{"n": "Piedra", "top": Color(0.62, 0.64, 0.68), "k": "stone", "d1": Color(0.42, 0.44, 0.50), "d2": Color(0.78, 0.80, 0.84)},
	{"n": "Arena", "top": Color(0.90, 0.80, 0.52), "k": "sand", "d1": Color(0.75, 0.63, 0.36), "d2": Color(0.97, 0.92, 0.72)},
	{"n": "Nieve", "top": Color(0.93, 0.96, 1.00), "k": "snow", "d1": Color(0.72, 0.80, 0.92), "d2": Color(1, 1, 1)},
	{"n": "Agua", "top": Color(0.25, 0.58, 0.85), "k": "water", "d1": Color(0.15, 0.40, 0.70), "d2": Color(0.70, 0.90, 1.00)},
	{"n": "Madera", "top": Color(0.68, 0.46, 0.25), "k": "wood", "d1": Color(0.45, 0.28, 0.14), "d2": Color(0.82, 0.60, 0.38)},
	{"n": "Ceniza", "top": Color(0.27, 0.25, 0.27), "k": "ash", "d1": Color(0.15, 0.14, 0.16), "d2": Color(1.0, 0.50, 0.15)},
	{"n": "Marmol", "top": Color(0.90, 0.90, 0.92), "k": "marble", "d1": Color(0.60, 0.62, 0.70), "d2": Color(0.78, 0.80, 0.86)},
	{"n": "Cueva", "top": Color(0.24, 0.30, 0.42), "k": "rock", "d1": Color(0.14, 0.18, 0.28), "d2": Color(0.40, 0.50, 0.66)},
	{"n": "Magia", "top": Color(0.50, 0.30, 0.75), "k": "magic", "d1": Color(0.30, 0.16, 0.50), "d2": Color(0.90, 0.70, 1.00)},
	{"n": "Otono", "top": Color(0.78, 0.52, 0.20), "k": "leaves", "d1": Color(0.60, 0.28, 0.10), "d2": Color(0.95, 0.78, 0.30)},
]


static func tile_pos(ix: int, iy: int) -> Vector2:
	return Vector2((ix - iy) * TW, (ix + iy) * TH)


static func _pt(rng: RandomNumberGenerator, c: Vector2) -> Vector2:
	for i in 30:
		var x := rng.randf_range(-1.0, 1.0)
		var y := rng.randf_range(-1.0, 1.0)
		if absf(x) + absf(y) < 0.80:
			return c + Vector2(x * TW, y * TH)
	return c


## c = centro de la cara superior; h = alto de las caras laterales (0 = plano)
static func draw_cube(ci: CanvasItem, c: Vector2, t: Dictionary, h: float, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var tc: Color = t["top"]
	var lc: Color = t["side_l"] if t.has("side_l") else tc.darkened(0.28)
	var rc: Color = t["side_r"] if t.has("side_r") else tc.darkened(0.42)
	var top := PackedVector2Array([c + Vector2(0, -TH), c + Vector2(TW, 0), c + Vector2(0, TH), c + Vector2(-TW, 0)])
	if h > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-TW, 0), c + Vector2(0, TH), c + Vector2(0, TH + h), c + Vector2(-TW, h)]), lc)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, TH), c + Vector2(TW, 0), c + Vector2(TW, h), c + Vector2(0, TH + h)]), rc)
		ci.draw_polyline(PackedVector2Array([c + Vector2(-TW, 0), c + Vector2(-TW, h), c + Vector2(0, TH + h), c + Vector2(TW, h), c + Vector2(TW, 0)]), OUT, 1.5)
		ci.draw_line(c + Vector2(0, TH), c + Vector2(0, TH + h), OUT, 1.5)
	ci.draw_colored_polygon(top, tc)
	_detail(ci, c, t, rng, top)
	ci.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), OUT, 1.5)


static func _detail(ci: CanvasItem, c: Vector2, t: Dictionary, rng: RandomNumberGenerator, top: PackedVector2Array) -> void:
	var d1: Color = t["d1"]
	var d2: Color = t["d2"]
	match String(t["k"]):
		"grass":
			for i in 16:
				var p := _pt(rng, c)
				var col := d1 if i % 3 != 0 else d2
				ci.draw_line(p, p + Vector2(-2, -5), col, 1.5)
				ci.draw_line(p, p + Vector2(2, -6), col, 1.5)
		"dirt":
			for i in 12:
				ci.draw_circle(_pt(rng, c), rng.randf_range(1.2, 3.0), d1 if i % 2 == 0 else d2)
		"stone":
			for i in 3:
				var p := _pt(rng, c)
				var q := p + Vector2(rng.randf_range(-12, 12), rng.randf_range(-5, 5))
				var r := q + Vector2(rng.randf_range(-10, 10), rng.randf_range(-4, 4))
				ci.draw_polyline(PackedVector2Array([p, q, r]), d1, 1.5)
			for i in 8:
				ci.draw_circle(_pt(rng, c), 1.2, d2)
		"sand":
			for i in 34:
				ci.draw_circle(_pt(rng, c), 0.9, d1 if i % 2 == 0 else d2)
		"snow":
			for i in 8:
				ci.draw_circle(_pt(rng, c), rng.randf_range(2.0, 4.0), d1)
			for i in 12:
				ci.draw_circle(_pt(rng, c), 1.2, d2)
		"water":
			for i in 5:
				var p := _pt(rng, c)
				var w := PackedVector2Array([p, p + Vector2(5, -2), p + Vector2(10, 0), p + Vector2(15, -2)])
				ci.draw_polyline(w, d2, 1.5)
			for i in 3:
				var p := _pt(rng, c)
				ci.draw_line(p, p + Vector2(8, 0), d1, 2.0)
		"wood":
			for f in [0.25, 0.5, 0.75]:
				ci.draw_line(top[0].lerp(top[3], f), top[1].lerp(top[2], f), d1, 1.5)
			for i in 3:
				ci.draw_circle(_pt(rng, c), 1.6, d1)
		"ash":
			for i in 5:
				var p := _pt(rng, c)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(rng.randf_range(-9, 9), rng.randf_range(-4, 4))]), d1, 2.0)
			for i in 7:
				ci.draw_circle(_pt(rng, c), 1.5, d2)
		"marble":
			for i in 2:
				var p := _pt(rng, c)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(10, -4), p + Vector2(18, 1), p + Vector2(28, -3)]), d1, 1.0)
			for i in 6:
				ci.draw_circle(_pt(rng, c), 1.4, d2)
		"rock":
			for i in 18:
				ci.draw_circle(_pt(rng, c), rng.randf_range(1.0, 2.4), d1 if i % 2 == 0 else d2)
		"magic":
			for i in 9:
				var p := _pt(rng, c)
				ci.draw_circle(p, 3.2, Color(d2.r, d2.g, d2.b, 0.25))
				ci.draw_circle(p, 1.5, d2)
			var q := c + Vector2(0, 0)
			ci.draw_polyline(PackedVector2Array([q + Vector2(0, -8), q + Vector2(14, 0), q + Vector2(0, 8), q + Vector2(-14, 0), q + Vector2(0, -8)]), d1, 1.5)
		"leaves":
			for i in 16:
				ci.draw_circle(_pt(rng, c), rng.randf_range(1.6, 2.8), d1 if i % 2 == 0 else d2)


## Suelo plano sin contorno entre baldosas contiguas: solo se dibuja el borde exterior.
## keys: Dictionary con clave ix*100+iy -> true (usa ix,iy >= 0 en rango 0..99 con offset)
static func draw_ground(ci: CanvasItem, cells: Array, h: float) -> void:
	var keys := {}
	for c in cells:
		keys[Vector2i(int(c["ix"]), int(c["iy"]))] = true
	for c in cells:
		var ix := int(c["ix"])
		var iy := int(c["iy"])
		var p := tile_pos(ix, iy)
		var t: Dictionary = TYPES[c["t"]]
		var tc: Color = t["top"]
		var lc: Color = t["side_l"] if t.has("side_l") else tc.darkened(0.28)
		var rc: Color = t["side_r"] if t.has("side_r") else tc.darkened(0.42)
		if not keys.has(Vector2i(ix, iy + 1)):
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-TW, 0), p + Vector2(0, TH), p + Vector2(0, TH + h), p + Vector2(-TW, h)]), lc)
		if not keys.has(Vector2i(ix + 1, iy)):
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, TH), p + Vector2(TW, 0), p + Vector2(TW, h), p + Vector2(0, TH + h)]), rc)
		var e := 0.8
		var top := PackedVector2Array([p + Vector2(0, -TH - e), p + Vector2(TW + e * 2.0, 0), p + Vector2(0, TH + e), p + Vector2(-TW - e * 2.0, 0)])
		ci.draw_colored_polygon(top, tc)
		var rng := RandomNumberGenerator.new()
		rng.seed = ix * 131 + iy * 17
		_detail(ci, p, t, rng, PackedVector2Array([p + Vector2(0, -TH), p + Vector2(TW, 0), p + Vector2(0, TH), p + Vector2(-TW, 0)]))
	for c in cells:
		var ix := int(c["ix"])
		var iy := int(c["iy"])
		var p := tile_pos(ix, iy)
		var T := p + Vector2(0, -TH)
		var R := p + Vector2(TW, 0)
		var B := p + Vector2(0, TH)
		var L := p + Vector2(-TW, 0)
		if not keys.has(Vector2i(ix, iy - 1)):
			ci.draw_line(T, R, OUT, 1.5)
		if not keys.has(Vector2i(ix - 1, iy)):
			ci.draw_line(L, T, OUT, 1.5)
		if not keys.has(Vector2i(ix + 1, iy)):
			ci.draw_polyline(PackedVector2Array([R, B, B + Vector2(0, h), R + Vector2(0, h)]), OUT, 1.5)
		if not keys.has(Vector2i(ix, iy + 1)):
			ci.draw_polyline(PackedVector2Array([B, L, L + Vector2(0, h), B + Vector2(0, h)]), OUT, 1.5)
