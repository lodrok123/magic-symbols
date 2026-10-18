class_name GestureRectify
extends RefCounted

## RECTIFICADOR DEL TRAZO (Fase 14.4 · 16/10, Juego; pedido de Pablo: «el trazo es muy lento… una ayuda que se sienta que dibujas tú
## pero permitiendo un trazo menos libre para evitar errores»).
##
## Qué hace: convierte un trazo a mano alzada en una POLILÍNEA DE TRAMOS RECTOS cuyas direcciones son solo las OCHO del compás
## (0°, 45°, 90°…). No hay rejilla ni nodos: el trazo sale de donde el jugador lo empieza, mide lo que él dibuja y solo se le
## quitan el temblor y los ángulos a medias. Es lo que pidió Pablo frente a la rejilla visible del vídeo de referencia: «que solo
## tome en cuenta las direcciones».
##
## Por qué ocho direcciones y no cuatro: los sellos giran por sectores de 45° (Spellbook.SECTORS = 8) y runas como el rombo o la
## zeta del rayo viven en las diagonales. Con cuatro, un rombo sería un cuadrado.
##
## Cómo (tres pasos, todos sobre puntos ya en píxeles del libro; `escala` = radio del círculo, _u(RADIUS), para que las tolerancias
## no dependan del tamaño de la ventana):
##   1. Douglas-Peucker con tolerancia TOL_SIMPLIFICAR × escala: deja solo los vértices donde el trazo cambia de verdad de rumbo.
##   2. Cada tramo se CUANTIZA a la dirección del compás más cercana y conserva su longitud proyectada sobre ella; los tramos
##      seguidos con la misma dirección se funden, y los más cortos que TRAMO_MIN × escala (el gancho al arrancar, el rabo al
##      soltar, el redondeo de una esquina) se quitan y los vecinos se vuelven a fundir si ahora coinciden.
##   3. Se reconstruye desde el primer punto encadenando los tramos. Si el final cae a menos de CIERRE × escala del principio con
##      tres o más tramos, se cierra exacto (un rombo dibujado casi cerrado queda cerrado).
## Es determinista y sin estado: la misma función vale para el trazo en curso (se pinta rectificado en vivo) y para el cerrado
## (el que se reconoce y se graba). Un trazo más corto que TRAMO_MIN queda como un punto: el reconocedor ya lo descarta.
##
## Lo que NO hace: no reconoce nada ni decide direcciones por la runa esperada (eso sigue siendo del $P y de GestureAssist). Y no
## toca el trazo CRUDO: Spellbook lo guarda aparte para el PlayLog y para la punta de la pluma.

const DIRECCIONES: int = 8
const TOL_SIMPLIFICAR: float = 0.06        ## × escala: desviación máxima que se considera temblor (15 px en el libro de diseño)
const TRAMO_MIN: float = 0.10              ## × escala: un tramo más corto es ruido y se funde con los vecinos
const CIERRE: float = 0.12                 ## × escala: distancia final-inicio por debajo de la cual la figura se cierra exacta


## Trazo a mano alzada → polilínea de tramos rectos en las ocho direcciones. Devuelve al menos 2 puntos si el trazo medía algo;
## si no, el trazo tal cual (un punto suelto no se rectifica).
## `escala` fija la tolerancia al TEMBLOR (TOL_SIMPLIFICAR). `escala_forma` (17/10, diario 137) fija el tamaño de las FORMAS: el tramo mínimo
## (TRAMO_MIN) y el cierre (CIERRE). Por defecto es la misma que `escala` (comportamiento de siempre). Se separan para los glifos: el temblor
## de la mano mide lo mismo en un círculo pequeño que en uno grande, pero las formas son 4 veces menores (medido en diario 138).
static func rectificar(trazo: PackedVector2Array, escala: float, escala_forma: float = -1.0) -> PackedVector2Array:
	if trazo.size() < 2 or escala <= 0.0:
		return trazo
	var ef: float = escala if escala_forma <= 0.0 else escala_forma
	var vertices: PackedVector2Array = simplificar(trazo, TOL_SIMPLIFICAR * escala)
	var tramos: Array = _tramos(vertices)                       # [[dir, largo], …]
	tramos = _fundir(tramos)
	tramos = _sin_cortos(tramos, TRAMO_MIN * ef)
	if tramos.is_empty():
		return PackedVector2Array([trazo[0], trazo[0]])
	var salida := PackedVector2Array([trazo[0]])
	var p: Vector2 = trazo[0]
	for t in tramos:
		p += direccion(int(t[0])) * float(t[1])
		salida.append(p)
	if tramos.size() >= 3 and salida[salida.size() - 1].distance_to(salida[0]) < CIERRE * ef:
		salida[salida.size() - 1] = salida[0]
	return salida


## Varios trazos de golpe (un gesto).
static func rectificar_gesto(trazos: Array, escala: float, escala_forma: float = -1.0) -> Array:
	var r: Array = []
	for t in trazos:
		r.append(rectificar(t, escala, escala_forma))
	return r


## Vector unitario de la dirección `i` del compás (0 = este, 1 = sureste en coordenadas de pantalla, y así cada 45°).
static func direccion(i: int) -> Vector2:
	var a: float = float(posmod(i, DIRECCIONES)) * TAU / float(DIRECCIONES)
	return Vector2(cos(a), sin(a))


## Índice del compás más cercano a un vector.
static func indice(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (TAU / float(DIRECCIONES)))), DIRECCIONES)


## Douglas-Peucker iterativo (sin recursión: un trazo largo no debe tirar la pila).
static func simplificar(pts: PackedVector2Array, tol: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n <= 2:
		return pts
	var guardar: PackedByteArray = PackedByteArray()
	guardar.resize(n)
	guardar.fill(0)
	guardar[0] = 1
	guardar[n - 1] = 1
	var pila: Array = [[0, n - 1]]
	while not pila.is_empty():
		var par: Array = pila.pop_back()
		var a: int = par[0]
		var b: int = par[1]
		if b - a < 2:
			continue
		var peor: float = -1.0
		var k: int = -1
		for i in range(a + 1, b):
			var d: float = _distancia_a_segmento(pts[i], pts[a], pts[b])
			if d > peor:
				peor = d
				k = i
		if peor > tol and k > 0:
			guardar[k] = 1
			pila.append([a, k])
			pila.append([k, b])
	var salida := PackedVector2Array()
	for i in range(n):
		if guardar[i] == 1:
			salida.append(pts[i])
	return salida


static func _distancia_a_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	if a.distance_squared_to(b) < 1.0e-6:
		return p.distance_to(a)
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Vértices → tramos [dirección del compás, largo proyectado]. Un tramo cuya proyección sale ≤ 0 se descarta (solo pasa con
## vértices casi pegados).
static func _tramos(vertices: PackedVector2Array) -> Array:
	var tramos: Array = []
	for i in range(vertices.size() - 1):
		var v: Vector2 = vertices[i + 1] - vertices[i]
		if v.length_squared() < 1.0e-6:
			continue
		var d: int = indice(v)
		var largo: float = v.dot(direccion(d))
		if largo > 0.0:
			tramos.append([d, largo])
	return tramos


## Funde tramos seguidos con la misma dirección (sus largos se suman).
static func _fundir(tramos: Array) -> Array:
	var salida: Array = []
	for t in tramos:
		if not salida.is_empty() and int(salida[salida.size() - 1][0]) == int(t[0]):
			salida[salida.size() - 1][1] += float(t[1])
		else:
			salida.append([int(t[0]), float(t[1])])
	return salida


## Quita los tramos más cortos que `minimo`, del más corto al más largo, volviendo a fundir tras cada quite. Si solo queda uno, se
## queda aunque sea corto: un trazo de un solo tramo corto es cosa del reconocedor, no de aquí.
static func _sin_cortos(tramos: Array, minimo: float) -> Array:
	var t: Array = tramos.duplicate(true)
	while t.size() > 1:
		var k: int = -1
		var menor: float = minimo
		for i in range(t.size()):
			if float(t[i][1]) < menor:
				menor = float(t[i][1])
				k = i
		if k < 0:
			break
		t.remove_at(k)
		t = _fundir(t)
	return t


## Cuántos tramos tiene un trazo ya rectificado (para pruebas y PlayLog).
static func tramos_de(trazo: PackedVector2Array) -> int:
	return maxi(trazo.size() - 1, 0)
