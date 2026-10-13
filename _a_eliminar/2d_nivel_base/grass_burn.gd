class_name GrassBurn
extends Node2D

## LO QUE SE VE CUANDO ARDE UNA HIERBA.
##
## Referencia: una bola de fuego cae, y desde el punto de impacto el fuego se
## extiende por el suelo como una BANDA continua y densa en el frente, con una
## columna más alta en el origen; detrás del frente se va quedando en brasas y
## suelo quemado. Lo que NO es: llamas sueltas repartidas por el bloque.
##
## Por eso aquí las llamas no son sprites, sino una banda continua (el mismo
## material de fuego de las barreras, SpellMaterial) dibujada a lo largo del
## borde de lo quemado, en varias capas que retroceden y bajan de altura:
##
##   frente      alto y brillante, en el borde
##   estela      más bajo y rojizo, justo detrás
##   brasas      llamas mínimas y chispas dentro de lo ya quemado
##   suelo       el terreno quemado (oscuro) ∩ el rombo del bloque
##
## El suelo es un plano en perspectiva: un círculo sobre él se ve como una
## elipse aplastada (la misma razón 2:1 del rombo). Todo el crecimiento se
## dibuja así, y `radio` está en unidades DE SUELO.
##
## No decide nada del juego: GrassBlock le dice dónde prendió y cuánto ha
## crecido, y la mecánica (daño, contagio) sigue siendo suya.

const CARBON: Color = Color(0.09, 0.05, 0.03)
const FUEGO: Color = Color(1.0, 0.50, 0.08)

## Capas de llama: [cuánto retrocede del borde (px de suelo), intensidad].
const CAPAS: Array = [[0.0, 0.85], [28.0, 1.6], [60.0, 1.38]]
const PASO: float = 6.0          ## separación entre lenguas de una banda
const ALTO: float = 10.0         ## altura de una lengua del frente, en píxeles

## Colores de una lengua, de fuera adentro: rojo oscuro, rojo, naranja, amarillo.
const C_BRASA: Color = Color(0.70, 0.10, 0.02)
const C_FUERA: Color = Color(0.92, 0.25, 0.04)
const C_MEDIO: Color = Color(1.0, 0.55, 0.10)
const C_DENTRO: Color = Color(1.0, 0.90, 0.40)

var origen: Vector2 = Vector2.ZERO   ## punto donde prendió, en local
var radio: float = 0.0               ## hasta dónde ha llegado lo quemado (suelo)
var t: float = 0.0                   ## segundos desde que prendió
var env: float = 1.0                 ## 1 = a pleno; baja a 0 al apagarse
var igniting: bool = false           ## recién prendida: más baja
var aviva: float = 0.0               ## 0..1 avivado por el viento: llamas más altas
var soplo: Vector2 = Vector2.ZERO    ## hacia dónde sopla (las llamas se inclinan)

var _fase: float = 0.0


func _ready() -> void:
	_fase = randf() * TAU


static func _k() -> float:
	return IsoGrid.STEP.y / IsoGrid.STEP.x


## ¿Está `p` (local) dentro del rombo del bloque?
static func _dentro(p: Vector2, margen: float = 0.0) -> bool:
	return absf(p.x) / (IsoGrid.STEP.x + margen) + absf(p.y) / (IsoGrid.STEP.y + margen * 0.5) <= 1.0


## Distancia sobre el suelo desde el origen (el eje Y del suelo va sin aplastar).
func _dist_suelo(p: Vector2) -> float:
	var d: Vector2 = p - origen
	return Vector2(d.x, d.y / _k()).length()


## Un punto de la elipse de radio `r` en el ángulo `a`, con el borde irregular.
func _punto(r: float, a: float) -> Vector2:
	var rr: float = r * (1.0 + 0.10 * sin(3.0 * a + _fase) + 0.06 * sin(7.0 * a + _fase * 1.7))
	return origen + Vector2(cos(a) * rr, sin(a) * rr * _k())


## Los tramos de la elipse de radio `r` que caen dentro del bloque.
func _arcos(r: float) -> Array:
	var caminos: Array = []
	var n: int = maxi(16, int(TAU * r / PASO))
	var actual := PackedVector2Array()
	for i in range(n + 1):
		var p: Vector2 = _punto(r, TAU * float(i) / float(n))
		if _dentro(p, 1.5):
			actual.append(p)
		else:
			if actual.size() >= 2:
				caminos.append(actual)
			actual = PackedVector2Array()
	if actual.size() >= 2:
		caminos.append(actual)
	return caminos


func _process(_delta: float) -> void:
	if radio >= 1.0 and env > 0.02:
		queue_redraw()


func _draw() -> void:
	if radio < 1.0 or env <= 0.02:
		return

	var rombo := PackedVector2Array([
		Vector2(0.0, -IsoGrid.STEP.y), Vector2(IsoGrid.STEP.x, 0.0),
		Vector2(0.0, IsoGrid.STEP.y), Vector2(-IsoGrid.STEP.x, 0.0)])

	# 1) El suelo quemado: la elipse recortada al rombo.
	var elipse := PackedVector2Array()
	for i in range(36):
		elipse.append(_punto(radio, TAU * float(i) / 36.0))
	for poly in Geometry2D.intersect_polygons(elipse, rombo):
		if Geometry2D.triangulate_polygon(poly).is_empty():
			continue
		draw_colored_polygon(poly, Color(CARBON, 0.5 * env))

	# 2) El resplandor detrás del frente: una banda ancha y tenue.
	var crece: float = clampf(radio / 30.0, 0.0, 1.0)
	for c in _arcos(maxf(radio - 16.0, 2.0)):
		draw_polyline(c, Color(1.0, 0.42, 0.10, 0.20 * env * crece), 30.0, true)

	# 3) Las llamas: capas continuas de lenguas a lo largo del borde, cada una
	# más atrás y más baja. Se dibujan de atrás (arriba en pantalla) hacia
	# delante para que las de delante tapen a las de detrás.
	var alta: float = 0.7 if igniting else 1.0
	var lenguas: Array = []
	for capa in CAPAS:
		var r: float = radio - float(capa[0])
		if r < 4.0:
			continue
		var e: float = env * float(capa[1]) * crece * alta
		for c in _arcos(r):
			for p in c:
				lenguas.append([p, e, float(capa[0])])

	# 4) La columna del origen: donde cayó, el fuego es más alto. Baja con el
	# tiempo hasta un rescoldo.
	var col: float = lerpf(1.0, 0.35, smoothstep(0.8, 4.0, t)) * (1.0 + 0.6 * aviva)
	for k in range(-2, 3):
		lenguas.append([origen + Vector2(float(k) * 5.0, float(absi(k))), env * col * alta * 1.15, 99.0])

	lenguas.sort_custom(func(a, b): return a[0].y < b[0].y)
	for l in lenguas:
		_lengua(l[0], l[1], l[2])

	# 5) Brasas: puntos que laten dentro de lo ya quemado, por detrás de la
	# estela. Fijas (nacen de la fase del bloque), no aleatorias por fotograma.
	for k in range(10):
		var ang: float = _fase + float(k) * 2.399
		var dist: float = radio * (0.15 + 0.7 * fmod(float(k) * 0.618, 1.0))
		var p: Vector2 = origen + Vector2(cos(ang) * dist, sin(ang) * dist * _k())
		if not _dentro(p, -6.0) or dist > radio - 32.0:
			continue
		var late: float = 0.5 + 0.5 * sin(t * 4.0 + float(k) * 1.7)
		draw_circle(p, 2.6, Color(1.0, 0.35, 0.05, (0.12 + 0.30 * late) * env))
		draw_circle(p, 1.2, Color(1.0, 0.8, 0.3, (0.3 + 0.5 * late) * env))

	# 6) Chispas sueltas dentro de lo quemado.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 7.0) * 977 + 13
	for _i in range(8):
		var p := Vector2(rng.randf_range(-IsoGrid.STEP.x, IsoGrid.STEP.x), rng.randf_range(-IsoGrid.STEP.y, IsoGrid.STEP.y))
		if _dentro(p, -6.0) and _dist_suelo(p) < radio * 0.9:
			draw_circle(p + Vector2(0.0, -rng.randf_range(0.0, 10.0)), 1.4, Color(1.0, 0.75, 0.25, 0.85 * env))


## Una lengua de fuego: tres triángulos anidados (rojo, naranja, amarillo) que
## suben desde `base`. Alto y balanceo salen de la posición y del tiempo, así
## que lenguas vecinas se parecen y la banda se lee continua, no a saltos.
func _lengua(base: Vector2, e: float, sesgo: float) -> void:
	if e <= 0.02:
		return
	var v: float = SpellMaterial._llama(base, t, sesgo * 0.05)
	var alto: float = ALTO * e * v * (1.0 + 3 * aviva)
	if alto < 3.0:
		return
	# Un pequeño desplazamiento fijo por posición: sin él las lenguas caen en
	# hilera y se nota la rejilla de puntos.
	base += Vector2(sin(base.x * 1.7 + base.y * 0.9) * 3.0, sin(base.y * 2.3 + base.x * 0.6) * 1.5)
	var ancho: float = PASO * 1.2
	var mece: float = sin(base.x * 0.21 + t * 7.0 + sesgo) * (3.0 + 2.0 * aviva) * e + soplo.x * aviva * alto * 0.35
	var capas: Array = [[1.0, C_BRASA, 0.80], [0.82, C_FUERA, 0.85], [0.56, C_MEDIO, 0.92], [0.28, C_DENTRO, 0.95]]
	for c in capas:
		var k: float = c[0]
		var cc: Color = c[1]
		cc.a = float(c[2]) * clampf(e * 1.6, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-ancho * 0.5 * k, 0.0),
			base + Vector2(ancho * 0.5 * k, 0.0),
			base + Vector2(mece * k, -alto * k)]), cc)
