extends Node2D
## EL IMPACTO DE UN HECHIZO, pintado por elemento y sin nodos de partículas.
##
## Lo crea spell.gd al golpear (junto al chispazo y el fogonazo de siempre, que se quedan).
## Vive VIDA segundos dibujando motas que salen del punto de choque y se borra solo. Todo sale del
## tiempo y de un hash del índice, igual que las motas de SpellMaterial: se ve igual en cámara lenta.

const VIDA: float = 0.55

var perfil: int = 0
var color: Color = Color.WHITE
var direccion: Vector2 = Vector2.RIGHT
var _t: float = 0.0


func iniciar(runa: RuneData, dir: Vector2) -> void:
	perfil = SpellMaterial.perfil_de(runa)
	color = runa.color
	direccion = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT


func _process(delta: float) -> void:
	_t += delta
	if _t >= VIDA:
		queue_free()
		return
	queue_redraw()


func _h(i: int, k: int) -> float:
	return SpellMaterial._h(i, k)


func _draw() -> void:
	var f: float = clampf(_t / VIDA, 0.0, 1.0)
	var e: float = 1.0 - (1.0 - f) * (1.0 - f)    # sale rápido y frena
	var a: float = 1.0 - f
	match perfil:
		SpellMaterial.Perfil.FUEGO:
			draw_circle(Vector2.ZERO, 14.0 * a, Color(1.0, 0.9, 0.5, a * 0.8))
			for i in range(14):
				var ang: float = TAU * float(i) / 14.0 + _h(i, 1) * 0.5
				var r: float = (14.0 + _h(i, 2) * 30.0) * e
				var p: Vector2 = Vector2(cos(ang), sin(ang) * 0.75) * r + Vector2(0.0, -26.0 * f * f)
				var cc: Color = Color(1.0, 0.85, 0.35).lerp(color, f)
				draw_circle(p, 1.2 + 2.4 * a, Color(cc.r, cc.g, cc.b, a))
		SpellMaterial.Perfil.AGUA:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, 8.0 + 36.0 * e, 0.0, TAU, 28, Color(0.8, 0.95, 1.0, a * 0.9), 1.6, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var ts: float = f * VIDA
			for i in range(12):
				var ang: float = -PI * (0.1 + 0.8 * _h(i, 1))
				var v: float = 60.0 + _h(i, 2) * 70.0
				var p: Vector2 = Vector2(cos(ang) * v * ts, sin(ang) * v * ts + 0.5 * 240.0 * ts * ts)
				draw_circle(p, 1.2 + _h(i, 3) * 1.4, Color(0.75, 0.93, 1.0, a))
		SpellMaterial.Perfil.VIENTO:
			for k in range(3):
				var pts := PackedVector2Array()
				for s in range(14):
					var u: float = float(s) / 13.0
					var ang: float = TAU * float(k) / 3.0 + u * 2.4 + f * 3.0
					pts.append(Vector2(cos(ang), sin(ang) * 0.7) * (4.0 + 34.0 * e * u))
				draw_polyline(pts, Color(0.92, 1.0, 0.88, a * 0.8), 1.6, true)
			for i in range(8):
				var ang: float = TAU * float(i) / 8.0 + f * 2.0
				draw_circle(Vector2(cos(ang), sin(ang) * 0.7) * (20.0 + 20.0 * e), 1.4, Color(1.0, 1.0, 0.9, a))
		SpellMaterial.Perfil.RAYO:
			var paso: int = int(floor(_t * 30.0))
			draw_circle(Vector2.ZERO, 10.0 * a, Color(1.0, 1.0, 0.8, a))
			for i in range(8):
				var ang: float = TAU * float(i) / 8.0 + _h(i + paso, 1) * 0.6
				var largo: float = (16.0 + _h(i, 2) * 26.0) * (0.4 + 0.6 * e)
				var pts := PackedVector2Array([Vector2.ZERO])
				for s in range(1, 5):
					var u: float = float(s) / 4.0
					pts.append(Vector2.from_angle(ang) * largo * u + Vector2.from_angle(ang + PI * 0.5) * (_h(i * 5 + s + paso, 3) - 0.5) * 9.0)
				draw_polyline(pts, Color(1.0, 0.95, 0.55, a), 1.6, true)
		SpellMaterial.Perfil.HIELO:
			for i in range(9):
				var ang: float = TAU * float(i) / 9.0 + _h(i, 1) * 0.5
				var r: float = (10.0 + _h(i, 2) * 28.0) * e
				var c0: Vector2 = Vector2(cos(ang), sin(ang) * 0.8) * r
				var d: Vector2 = Vector2.from_angle(ang)
				var o: Vector2 = d.orthogonal()
				var tam: float = 4.0 + _h(i, 3) * 3.0
				draw_colored_polygon(PackedVector2Array([c0 + d * tam, c0 + o * tam * 0.35, c0 - d * tam * 0.6, c0 - o * tam * 0.35]),
						Color(0.85, 0.97, 1.0, a))
			draw_line(Vector2(-12.0, 0.0) * a, Vector2(12.0, 0.0) * a, Color(1.0, 1.0, 1.0, a), 1.4, true)
			draw_line(Vector2(0.0, -12.0) * a, Vector2(0.0, 12.0) * a, Color(1.0, 1.0, 1.0, a), 1.4, true)
		SpellMaterial.Perfil.TIERRA:
			var ts2: float = f * VIDA
			draw_circle(Vector2(0.0, -2.0), 8.0 + 22.0 * e, Color(0.55, 0.45, 0.35, a * 0.25))
			for i in range(9):
				var ang: float = -PI * (0.05 + 0.9 * _h(i, 1))
				var v: float = 55.0 + _h(i, 2) * 60.0
				var p: Vector2 = Vector2(cos(ang) * v * ts2, sin(ang) * v * ts2 + 0.5 * 260.0 * ts2 * ts2)
				draw_circle(p, 1.6 + _h(i, 3) * 2.0, Color(color.r * 0.8, color.g * 0.7, color.b * 0.6, a))
		_:
			for i in range(10):
				var ang: float = TAU * float(i) / 10.0 + _h(i, 1) * 0.5
				draw_circle(Vector2(cos(ang), sin(ang) * 0.8) * (10.0 + 26.0 * _h(i, 2)) * e, 1.0 + 2.0 * a, Color(color.r, color.g, color.b, a))
