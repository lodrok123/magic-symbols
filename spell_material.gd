class_name SpellMaterial
extends RefCounted

## EL MATERIAL DE CADA ELEMENTO.
##
## SpellForm decide la MACROFORMA (un círculo, un muro: por dónde va el borde
## de la barrera). Esto decide qué es ese borde POR DENTRO: cómo se mueve, de
## qué está hecho. Recibe caminos (líneas de puntos) y los rellena. No sabe si
## es un corro o un muro, y por eso un elemento nuevo es una función más.
##
## El punto de esta capa es la CONTINUIDAD: no hay "seis fuegos", hay UNA
## pared de fuego cuya altura y color varían a lo largo del camino.
##
##   Fuego   muro de lenguas ascendentes, en tres capas
##   Agua    pared de líquido con la superficie ondulando
##   Viento  corrientes que rodean, sin pared
##   Rayo    arcos que chisporrotean alrededor, a distintas alturas
##   Hielo   cristales: púas afiladas de distinta altura con una cara iluminada
##   Tierra  bloques de roca que se levantan del suelo, de altura desigual
##
## Todo el ruido sale de la POSICIÓN y del tiempo (no de un índice), así que
## el borde es continuo también al dar la vuelta.

enum Perfil { NINGUNO, FUEGO, AGUA, VIENTO, RAYO, HIELO, TIERRA }

## Distancia entre puntos de un camino. Menos son más lenguas finas; más, más
## coste. Con esto un círculo de 64 px de radio tiene unos 65 puntos.
const PASO: float = 6.0


static func perfil_de(runa: RuneData) -> int:
	if runa == null:
		return Perfil.NINGUNO
	if runa.tags.has("fuego"):
		return Perfil.FUEGO
	if runa.tags.has("agua"):
		return Perfil.AGUA
	if runa.tags.has("viento"):
		return Perfil.VIENTO
	if runa.tags.has("rayo"):
		return Perfil.RAYO
	if runa.tags.has("hielo"):
		return Perfil.HIELO
	if runa.tags.has("tierra"):
		return Perfil.TIERRA
	return Perfil.NINGUNO


static func camino_recto(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(1, ceili(a.distance_to(b) / PASO))
	for i in range(n + 1):
		pts.append(a.lerp(b, float(i) / float(n)))
	return pts


## Cerrado: el último punto repite el primero.
static func camino_circulo(radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(24, ceili(TAU * radio / PASO))
	for i in range(n + 1):
		pts.append(Vector2.from_angle(TAU * float(i) / float(n)) * radio)
	return pts


## `env` es 0..1: lo levantada que está la barrera (sube al nacer, se hunde al
## morir).
static func dibujar(ci: CanvasItem, perfil: int, caminos: Array, t: float, env: float, col: Color) -> void:
	if env <= 0.02:
		return
	for k in range(caminos.size()):
		var c: PackedVector2Array = caminos[k]
		if c.size() < 2:
			continue
		match perfil:
			Perfil.FUEGO:
				_fuego(ci, c, t, env, col)
			Perfil.AGUA:
				_agua(ci, c, t, env, col)
			Perfil.VIENTO:
				_viento(ci, c, k, t, env, col)
			Perfil.RAYO:
				_rayo(ci, c, k, t, env, col)
			Perfil.HIELO:
				_hielo(ci, c, t, env, col)
			Perfil.TIERRA:
				_tierra(ci, c, t, env, col)
		_motas(ci, perfil, c, k, t, env, col)


## --- Partículas ---
## Motas que se mueven por encima del dibujo: lo que hace que la barrera parezca una imagen VIVA y
## no una forma que cambia de alto. Son PROCEDURALES (salen del tiempo y de un hash del índice, no
## de nodos), así que no hay nada que crear ni que borrar y se ven igual en cámara lenta. Se
## reparten por el camino y cada elemento las mueve a su manera.
const MOTAS_MAX: int = 36
const MOTAS_CADA: float = 9.0   ## un punto cada tantos px de camino


static func _h(i: int, k: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)


static func _motas(ci: CanvasItem, perfil: int, c: PackedVector2Array, k: int, t: float, env: float, col: Color) -> void:
	var largo: float = _largo(c)
	var n: int = clampi(roundi(largo / MOTAS_CADA), 6, MOTAS_MAX)
	for i in range(n):
		var s: int = i + k * 101
		var u: float = _h(s, 1) * largo
		var p: Vector2 = _en(c, u, largo)
		match perfil:
			Perfil.FUEGO:
				# ascuas: suben, se menean y se apagan
				var f: float = fposmod(t * (0.55 + _h(s, 2) * 0.6) + _h(s, 3), 1.0)
				var q: Vector2 = p + Vector2(sin(f * 7.0 + _h(s, 4) * 6.28) * 5.0, -f * (30.0 + _h(s, 5) * 34.0))
				var a: float = (1.0 - f) * env
				var cc: Color = Color(1.0, 0.85, 0.35).lerp(col, f)
				ci.draw_circle(q, 1.0 + (1.0 - f) * 1.8, Color(cc.r, cc.g, cc.b, a))
			Perfil.AGUA:
				# burbujas y gotas: suben despacio y revientan arriba
				var f: float = fposmod(t * (0.25 + _h(s, 2) * 0.3) + _h(s, 3), 1.0)
				var q: Vector2 = p + Vector2(sin(f * 5.0 + _h(s, 4) * 6.28) * 3.0, -f * (22.0 + _h(s, 5) * 26.0))
				var r: float = 1.4 + _h(s, 6) * 2.0
				var a: float = sin(f * PI) * env
				ci.draw_arc(q, r, 0.0, TAU, 10, Color(0.85, 0.97, 1.0, a * 0.9), 1.0, true)
				ci.draw_circle(q + Vector2(-r * 0.3, -r * 0.3), 0.7, Color(1.0, 1.0, 1.0, a))
			Perfil.VIENTO:
				# hojas y polvo que giran siguiendo el camino
				var u2: float = fposmod(u + t * (26.0 + _h(s, 2) * 30.0), maxf(largo, 1.0))
				var base: Vector2 = _en(c, u2, largo)
				var alto: float = 6.0 + _h(s, 3) * 34.0 + sin(t * 2.0 + _h(s, 4) * 6.28) * 4.0
				var q: Vector2 = base + Vector2(0.0, -alto)
				var a: float = (0.35 + 0.45 * sin(t * 3.0 + float(s))) * env
				var d: Vector2 = Vector2.from_angle(t * 2.0 + _h(s, 5) * 6.28) * (2.0 + _h(s, 6) * 2.0)
				ci.draw_line(q - d, q + d, Color(0.9, 1.0, 0.85, clampf(a, 0.0, 1.0)), 1.6, true)
			Perfil.RAYO:
				# chispas: aparecen un instante y saltan de sitio
				var paso: int = int(floor(t * 14.0 + _h(s, 2) * 5.0))
				if _h(s + paso * 7, 7) < 0.55:
					continue
				var q: Vector2 = p + Vector2((_h(s + paso, 8) - 0.5) * 22.0, -4.0 - _h(s + paso, 9) * 42.0)
				var a: float = env * (0.6 + 0.4 * _h(s + paso, 10))
				ci.draw_rect(Rect2(q - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(1.0, 1.0, 0.7, a))
			Perfil.HIELO:
				# destellos: cristales que brillan y se apagan donde están
				var f: float = fposmod(t * (0.4 + _h(s, 2) * 0.5) + _h(s, 3), 1.0)
				var q: Vector2 = p + Vector2(0.0, -_h(s, 5) * 40.0)
				var a: float = sin(f * PI) * env
				var r: float = 2.0 + _h(s, 6) * 2.5
				ci.draw_line(q - Vector2(r, 0.0), q + Vector2(r, 0.0), Color(0.9, 1.0, 1.0, a), 1.2, true)
				ci.draw_line(q - Vector2(0.0, r), q + Vector2(0.0, r), Color(0.9, 1.0, 1.0, a), 1.2, true)
			Perfil.TIERRA:
				# guijarros que saltan y caen
				var f: float = fposmod(t * (0.5 + _h(s, 2) * 0.4) + _h(s, 3), 1.0)
				var q: Vector2 = p + Vector2((_h(s, 4) - 0.5) * 14.0 * f, -sin(f * PI) * (10.0 + _h(s, 5) * 26.0))
				var a: float = env * (1.0 - f * 0.4)
				ci.draw_circle(q, 1.2 + _h(s, 6) * 1.6, Color(col.r * 0.8, col.g * 0.7, col.b * 0.6, a))


## --- Estela de la flecha ---
## Motas que quedan atrás de lo que vuela. Cada una nace a una DISTANCIA recorrida (una cada GAP px) y
## se queda en su sitio del camino: a cuántos px detrás de la cabeza está es lo que dice cuánto lleva
## de vida. Así la estela depende de lo recorrido y no del tiempo: en cámara lenta no se estira.
const ESTELA_GAP: float = 6.0
const ESTELA_LARGO: float = 90.0


static func estela(ci: CanvasItem, perfil: int, d: Vector2, recorrido: float, t: float, col: Color) -> void:
	var perp: Vector2 = d.orthogonal()
	var k_fin: int = int(floor(recorrido / ESTELA_GAP))
	for k in range(k_fin, maxi(k_fin - int(ESTELA_LARGO / ESTELA_GAP), 0), -1):
		var atras: float = recorrido - float(k) * ESTELA_GAP     # px detras de la cabeza
		var f: float = clampf(atras / ESTELA_LARGO, 0.0, 1.0)
		var a: float = 1.0 - f
		var lat: float = (_h(k, 1) - 0.5) * 12.0
		var base: Vector2 = -d * (atras + 6.0) + perp * lat
		match perfil:
			Perfil.FUEGO:
				var q: Vector2 = base + Vector2(0.0, -f * 22.0)
				var cc: Color = Color(1.0, 0.85, 0.35).lerp(col, f)
				ci.draw_circle(q, 0.8 + 2.0 * a, Color(cc.r, cc.g, cc.b, a))
			Perfil.AGUA:
				var q: Vector2 = base + Vector2(0.0, f * f * 26.0)
				ci.draw_circle(q, 0.8 + 1.4 * a, Color(0.8, 0.95, 1.0, a * 0.9))
			Perfil.VIENTO:
				var q: Vector2 = base * 1.0 + perp * sin(t * 6.0 + float(k)) * 3.0
				ci.draw_line(q, q - d * (4.0 + 6.0 * a), Color(0.92, 1.0, 0.88, a * 0.8), 1.3, true)
			Perfil.RAYO:
				if _h(k + int(floor(t * 20.0)), 7) < 0.5:
					continue
				var q: Vector2 = base + perp * (_h(k + int(floor(t * 20.0)), 8) - 0.5) * 14.0
				ci.draw_rect(Rect2(q - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), Color(1.0, 1.0, 0.7, a))
			Perfil.HIELO:
				if int(k) % 2 == 1:
					continue
				var r: float = 1.5 + 2.0 * a
				ci.draw_line(base - Vector2(r, 0.0), base + Vector2(r, 0.0), Color(0.9, 1.0, 1.0, a), 1.1, true)
				ci.draw_line(base - Vector2(0.0, r), base + Vector2(0.0, r), Color(0.9, 1.0, 1.0, a), 1.1, true)
			Perfil.TIERRA:
				var q: Vector2 = base + Vector2(0.0, f * f * 24.0)
				ci.draw_circle(q, 0.9 + 1.4 * a, Color(col.r * 0.8, col.g * 0.7, col.b * 0.6, a))
			_:
				ci.draw_circle(base, 0.8 + 1.4 * a, Color(col.r, col.g, col.b, a * 0.8))


## --- Utilidades ---

static func _cerrado(c: PackedVector2Array) -> bool:
	return c[0].is_equal_approx(c[c.size() - 1])


static func _largo(c: PackedVector2Array) -> float:
	var l: float = 0.0
	for i in range(c.size() - 1):
		l += c[i].distance_to(c[i + 1])
	return l


## Punto a distancia `u` a lo largo del camino. Los puntos van a paso uniforme
## dentro de cada camino, así que no hace falta acumular longitudes.
static func _en(c: PackedVector2Array, u: float, largo: float) -> Vector2:
	var f: float = clampf(u / maxf(largo, 0.001), 0.0, 1.0) * float(c.size() - 1)
	var i: int = mini(int(f), c.size() - 2)
	return c[i].lerp(c[i + 1], f - float(i))


## Solo dibuja polígonos con área: uno aplastado (dos puntos en vertical y el
## borde a altura cero) haría que Godot escribiera un error por fotograma.
static func _area(pts: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


## Si las cuatro esquinas giran hacia el mismo lado el cuadrilátero es convexo y
## simple: se dibuja sin más. Solo los raros (cruzados, aplastados) pasan por
## la comprobación cara de triangular. Con un incendio son miles al segundo.
static func _convexo(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var s1: float = (b - a).cross(c - b)
	var s2: float = (c - b).cross(d - c)
	var s3: float = (d - c).cross(a - d)
	var s4: float = (a - d).cross(b - a)
	return (s1 > 0.5 and s2 > 0.5 and s3 > 0.5 and s4 > 0.5) \
		or (s1 < -0.5 and s2 < -0.5 and s3 < -0.5 and s4 < -0.5)


static func _quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([a, b, c, d])
	if not _convexo(a, b, c, d):
		if _area(pts) < 0.8 or Geometry2D.triangulate_polygon(pts).is_empty():
			return
	ci.draw_colored_polygon(pts, col)


static func _quad_g(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var pts := PackedVector2Array([a, b, c, d])
	if _area(pts) < 0.8 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_polygon(pts, PackedColorArray([ca, cb, cc, cd]))


## --- FUEGO ---
## Un muro: tres capas de lenguas (roja fuera, naranja, amarilla dentro) cuyo
## borde superior sube y baja con el ruido de la posición.

static func _llama(p: Vector2, t: float, capa: float) -> float:
	var a: float = 0.5 + 0.5 * sin(p.x * 0.21 + p.y * 0.13 + t * 9.0 + capa * 3.0)
	var b: float = 0.5 + 0.5 * sin(p.x * 0.47 - p.y * 0.31 - t * 13.0 + capa * 5.0)
	return 0.28 + 0.72 * pow(a * 0.6 + b * 0.4, 1.5)


static func _fuego(ci: CanvasItem, c: PackedVector2Array, t: float, env: float, col: Color) -> void:
	var alto: float = 46.0 * env
	var capas: Array = [
		[1.00, col.darkened(0.30), 0.80],
		[0.72, col, 0.90],
		[0.42, col.lightened(0.60), 0.95],
	]

	# La base brilla: es donde el fuego es más denso.
	ci.draw_polyline(c, Color(col.lightened(0.3), 0.7 * env), 5.0, true)

	for capa in capas:
		var esc: float = capa[0]
		var relleno: Color = capa[1]
		relleno.a = float(capa[2]) * clampf(env * 1.4, 0.0, 1.0)

		var techo := PackedVector2Array()
		for p in c:
			var h: float = alto * esc * _llama(p, t, esc)
			# Las puntas se mecen a un lado, como una llama de verdad.
			var mece: float = sin(p.x * 0.2 + t * 6.0 + esc * 2.0) * 3.0 * env
			techo.append(p + Vector2(mece, -h))

		for i in range(c.size() - 1):
			_quad(ci, c[i], c[i + 1], techo[i + 1], techo[i], relleno)


## --- AGUA ---
## Una pared de líquido: más oscura y opaca abajo, más clara arriba, con la
## superficie ondulando y reflejos que se desplazan.

static func _agua(ci: CanvasItem, c: PackedVector2Array, t: float, env: float, col: Color) -> void:
	var alto: float = 30.0 * env
	var abajo := Color(col.darkened(0.25), 0.78)
	var arriba := Color(col.lightened(0.35), 0.40)

	var techo := PackedVector2Array()
	for p in c:
		var h: float = alto * (0.85 + 0.12 * sin(p.x * 0.10 + t * 3.2) + 0.08 * sin(p.y * 0.14 - t * 4.1))
		techo.append(p + Vector2(0.0, -h))

	for i in range(c.size() - 1):
		_quad_g(ci, c[i], c[i + 1], techo[i + 1], techo[i], abajo, abajo, arriba, arriba)

	# Reflejos: destellos cortos que recorren la pared.
	for i in range(0, c.size() - 1, 3):
		var p: Vector2 = c[i]
		if sin(p.x * 0.31 - p.y * 0.17 + t * 5.0) > 0.86:
			var a: Vector2 = p.lerp(techo[i], 0.45)
			ci.draw_line(a, a + Vector2(9.0, 0.0), Color(1, 1, 1, 0.55 * env), 2.0, true)

	ci.draw_polyline(techo, Color(col.lightened(0.7), 0.95 * env), 2.0, true)
	ci.draw_polyline(c, Color(col.lightened(0.15), 0.9 * env), 3.0, true)


## --- VIENTO ---
## Sin pared: corrientes que ruedan alrededor a distintas alturas. Lo que se
## ve es el movimiento; el borde queda solo insinuado en el suelo.

static func _viento(ci: CanvasItem, c: PackedVector2Array, k: int, t: float, env: float, col: Color) -> void:
	var largo: float = _largo(c)
	var cerrado: bool = _cerrado(c)
	var cuantas: int = clampi(roundi(largo / 70.0), 1, 8)
	var ls: float = clampf(largo * 0.28, 40.0, 120.0)

	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.28 * env), 2.0, true)

	for s in range(cuantas):
		var vel: float = 150.0 + 40.0 * float(s % 3)
		var base: float = float(s) / float(cuantas) * largo + float(k) * 37.0
		var lift: float = 8.0 + 10.0 * float((s * 3) % 4)
		var u0: float
		if cerrado:
			u0 = fposmod(base + t * vel, largo)
		else:
			u0 = fposmod(base + t * vel, largo + ls) - ls

		var prev: Vector2 = Vector2.ZERO
		var tiene: bool = false
		const TRAMOS: int = 12
		for m in range(TRAMOS + 1):
			var f: float = float(m) / float(TRAMOS)
			var u: float = u0 + ls * f
			if cerrado:
				u = fposmod(u, largo)
			elif u < 0.0 or u > largo:
				tiene = false
				continue
			var p: Vector2 = _en(c, u, largo)
			p.y -= lift + 5.0 * sin(u * 0.05 + t * 4.0 + float(s))
			if tiene:
				var a: float = sin(PI * f) * 0.85 * env
				ci.draw_line(prev, p, Color(col.lightened(0.5), a), 1.0 + 2.0 * sin(PI * f), true)
			prev = p
			tiene = true


## --- RAYO ---
## Arcos que chisporrotean: cada instante se redibujan en otro sitio, con
## sacudidas, y de vez en cuando cae uno vertical. Tres alturas.

static func _rayo(ci: CanvasItem, c: PackedVector2Array, k: int, t: float, env: float, col: Color) -> void:
	var largo: float = _largo(c)
	var cerrado: bool = _cerrado(c)
	var tick: int = int(t * 16.0)
	var alturas: Array = [6.0, 22.0, 38.0]

	# El contorno queda siempre, tenue: es lo que cierra el círculo.
	ci.draw_polyline(c, Color(col.r, col.g, col.b, 0.35 * env), 2.0, true)

	for j in range(alturas.size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = tick * 7919 + j * 104729 + k * 31

		var frac: float = 0.40 if cerrado else 0.85
		var u0: float = rng.randf() * largo
		var n: int = maxi(3, int(largo * frac / 9.0))
		var pts := PackedVector2Array()
		for m in range(n + 1):
			var u: float = u0 + largo * frac * float(m) / float(n)
			if cerrado:
				u = fposmod(u, largo)
			elif u > largo:
				break
			var p: Vector2 = _en(c, u, largo)
			p += Vector2(rng.randf_range(-4.0, 4.0), -float(alturas[j]) + rng.randf_range(-6.0, 6.0))
			pts.append(p)
		if pts.size() >= 2:
			_arco(ci, pts, col, env)

	# Un rayo que cae de arriba abajo, en un punto cualquiera.
	var rf := RandomNumberGenerator.new()
	rf.seed = tick * 6151 + k * 17
	var p0: Vector2 = _en(c, rf.randf() * largo, largo)
	var vert := PackedVector2Array()
	for m in range(5):
		vert.append(p0 + Vector2(rf.randf_range(-5.0, 5.0) if m > 0 else 0.0, -44.0 * float(m) / 4.0))
	_arco(ci, vert, col, env)


## --- HIELO ---
## Cristales: púas de altura desigual a lo largo del camino, cada una con una
## cara iluminada que centellea. Sin movimiento de masa: el hielo está quieto, lo
## único que se mueve es el brillo.

## Ruido estable (0..1) que sale de la POSICIÓN, no de un índice: así la púa de
## un punto es siempre la misma y el borde no parpadea.
static func _ruido(p: Vector2) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233) * 43758.5453, 1.0)


static func _hielo(ci: CanvasItem, c: PackedVector2Array, t: float, env: float, col: Color) -> void:
	var alto: float = 44.0 * env
	ci.draw_polyline(c, Color(col.lightened(0.55), 0.6 * env), 4.0, true)

	for i in range(0, c.size() - 1, 3):
		var p: Vector2 = c[i]
		var d: Vector2 = (c[i + 1] - c[i]).normalized()
		var n: float = _ruido(p)
		var h: float = alto * (0.35 + 0.65 * n)
		if h < 3.0:
			continue
		var punta: Vector2 = p + Vector2((n - 0.5) * 10.0, -h)
		var a: Vector2 = p - d * 6.0
		var b: Vector2 = p + d * 6.0

		_tri(ci, a, b, punta, Color(col.darkened(0.05), 0.80 * env))
		# La cara que da a la luz, con un centelleo lento.
		var brillo: float = 0.55 + 0.45 * sin(t * 2.4 + p.x * 0.17)
		_tri(ci, p, b, punta, Color(col.lightened(0.6), 0.55 * env * brillo))
		ci.draw_line(a, punta, Color(1.0, 1.0, 1.0, 0.6 * env), 1.0, true)


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([a, b, c])
	if _area(pts) < 0.8:
		return
	ci.draw_colored_polygon(pts, col)


## --- TIERRA ---
## Bloques de roca que SE LEVANTAN: alturas desiguales, una cara superior más
## clara, y un temblor mientras suben. Es lo único que se sacude; ya levantada,
## la roca no se mueve.

static func _tierra(ci: CanvasItem, c: PackedVector2Array, t: float, env: float, col: Color) -> void:
	var alto: float = 34.0 * env
	var tiembla: float = (1.0 - clampf(env * 1.3, 0.0, 1.0)) * 2.5

	ci.draw_polyline(c, Color(col.darkened(0.45), 0.8 * env), 5.0, true)

	for i in range(0, c.size() - 2, 2):
		var p: Vector2 = c[i]
		var q: Vector2 = c[mini(i + 2, c.size() - 1)]
		var n: float = _ruido(p)
		var h: float = alto * (0.45 + 0.55 * n)
		if h < 2.0:
			continue
		var sacudida: Vector2 = Vector2(sin(t * 55.0 + p.x) * tiembla, 0.0)
		var a: Vector2 = p + sacudida
		var b: Vector2 = q + sacudida
		var tono: Color = col.darkened(0.12 + 0.2 * n)
		_quad(ci, a, b, b - Vector2(0.0, h), a - Vector2(0.0, h), Color(tono, 0.95 * env))
		# La cara de arriba, más clara.
		ci.draw_line(a - Vector2(0.0, h), b - Vector2(0.0, h), Color(col.lightened(0.35), env), 3.0, true)
		# Una grieta, solo en las piedras altas.
		if n > 0.6:
			ci.draw_line(a.lerp(b, 0.4) - Vector2(0.0, h * 0.8), a.lerp(b, 0.55) - Vector2(0.0, h * 0.3),
					Color(col.darkened(0.6), 0.7 * env), 1.0, true)


static func _arco(ci: CanvasItem, pts: PackedVector2Array, col: Color, env: float) -> void:
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, 0.25 * env), 6.0, true)
	ci.draw_polyline(pts, Color(col, 0.9 * env), 3.0, true)
	ci.draw_polyline(pts, Color(1.0, 1.0, 0.88, 0.95 * env), 1.5, true)
