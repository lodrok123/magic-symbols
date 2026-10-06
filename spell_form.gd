class_name SpellForm
extends Node2D

## LA FORMA DEL SELLO.
##
## Este nodo dibuja lo que el SELLO dice, y nada de lo que dice el elemento.
## Es la mitad "silueta" de un hechizo; el material (textura, partículas,
## luz, microanimación) es de otra capa y va encima.
##
##   - Barrera: UN campo continuo, no seis hechizos. Una base compartida,
##     una superficie que sube y un borde. Sale de los puntos de la receta,
##     así que un muro de tres o un corro de seis se dibujan con la misma
##     regla, sin escribir ninguno a mano.
##   - Flecha: cabeza y cola. Lo dominante es la DIRECCIÓN: un dardo con una
##     cola que se afina hacia atrás.
##
## Los hitboxes no son de aquí: siguen siendo los Area2D de siempre. Esto
## solo se dibuja.

## MODO SILUETA. Con esto encendido los hechizos se dibujan en blanco plano:
## sin sprite, sin partículas, sin luz. Es la prueba de que el sello se lee
## por su forma. Lo miran spell.gd y spell_factory.gd para apagar su parte.
static var silhouette: bool = false

enum Kind { CAMPO, FLECHA }

## --- Barrera ---
const ALTURA: float = 52.0    ## lo que sube la superficie, en píxeles
const ENLACE: float = 76.0    ## distancia máxima para unir dos puntos (una casilla son 64)
const ANILLO_ALTURA: float = 16.0  ## el borde de una barrera CERRADA: un contorno con cuerpo, no una cortina
const ANILLO_SEGMENTOS: int = 48
const SUBIDA: float = 0.15    ## segundos que tarda en levantarse
const HUNDE: float = 0.75     ## fracción de vida a partir de la cual se hunde

## --- Flecha ---
const COLA: float = 96.0
const COLA_ANCHO: float = 16.0
const CABEZA: float = 20.0

var kind: Kind = Kind.CAMPO
var color: Color = Color.WHITE

var _puntos: PackedVector2Array = PackedVector2Array()  # del campo, relativos a su centro
## Si los puntos forman un corro (lo que dibuja el jugador es un círculo), la
## barrera se dibuja como ese círculo: mismo contorno que el gesto, y que el
## hitbox (los puntos están sobre él).
## Lo que dibuja cada elemento por dentro del contorno (ver SpellMaterial), y
## los caminos por los que lo hace.
var _perfil: int = 0

## Los hechizos que son hitbox de este campo, y lo que el campo ha TOMADO de
## fuera (un viento que cruza fuego se tiñe de fuego): ver tomar().
var _spells: Array = []

## Un muro que avanza: hacia dónde y a qué velocidad se mueve el campo, y qué
## cosas ha golpeado ya (por id), para aplicar su elemento una sola vez a cada una.
var _vel: Vector2 = Vector2.ZERO

## Un campo que sigue a alguien (levitación): a quién y a qué distancia de él.
## Una onda (pulso): el campo crece desde su centro a esta razón por segundo.
var _crece: float = 0.0

var _sigue: Node2D = null
var _sigue_off: Vector2 = Vector2.ZERO
var golpeados: Dictionary = {}
var _carga: int = 0
var _carga_color: Color = Color.WHITE
var _carga_t0: float = 0.0
var _caminos: Array = []
var _anillo: bool = false
var _radio: float = 0.0
var _vida: float = 0.6
var _edad: float = 0.0

var _dir: Vector2 = Vector2.RIGHT    # de la flecha
var _recorrido: float = 0.0
var _ultima: Vector2 = Vector2.ZERO


## Un campo para todos los puntos de una manifestación quieta. `centros` son
## posiciones de MUNDO. Devuelve null si no se puede colocar.
static func field(caster: Node2D, centros: Array, duracion: float, col: Color, runa: RuneData = null) -> SpellForm:
	if centros.is_empty() or caster == null or not caster.is_inside_tree():
		return null

	var f := SpellForm.new()
	f.kind = Kind.CAMPO
	f.color = col
	f._vida = duracion

	var c := Vector2.ZERO
	for p in centros:
		var v: Vector2 = p
		c += v
	c /= float(centros.size())
	for p in centros:
		var v: Vector2 = p
		f._puntos.append(v - c)

	f._detectar_anillo()
	f._perfil = SpellMaterial.perfil_de(runa)
	f._armar_caminos()

	caster.get_tree().current_scene.add_child(f)
	# Un pelo por DETRÁS de quien lanza (1 px hacia arriba): en isométrico se
	# ordena por Y, y si el campo empatara con el jugador, la pared de delante
	# lo taparía justo a él. Prefiero verte entero dentro de tu barrera.
	f.global_position = c + Vector2(0.0, -1.0)
	return f


## Una flecha cuelga del hechizo que vuela y lo acompaña.
static func arrow(spell: Node2D, direccion: Vector2, col: Color) -> SpellForm:
	var f := SpellForm.new()
	f.kind = Kind.FLECHA
	f.color = col
	f._dir = direccion.normalized() if direccion != Vector2.ZERO else Vector2.RIGHT
	spell.add_child(f)
	f._ultima = spell.global_position
	return f


## Es un corro si hay al menos 3 puntos a la misma distancia del centro y
## repartidos por toda la vuelta (sin huecos grandes). Una columna de anillos
## apilados o un muro en línea no cumplen y siguen con el dibujo de superficie.
func _detectar_anillo() -> void:
	var n: int = _puntos.size()
	if n < 3:
		return
	var media: float = 0.0
	for p in _puntos:
		media += p.length()
	media /= float(n)
	if media < 8.0:
		return
	var angulos: Array = []
	for p in _puntos:
		if absf(p.length() - media) > 4.0:
			return
		angulos.append(p.angle())
	angulos.sort()
	var hueco: float = TAU - (angulos[n - 1] - angulos[0])
	for i in range(1, n):
		hueco = maxf(hueco, angulos[i] - angulos[i - 1])
	if hueco > PI * 0.75:
		return
	_anillo = true
	_radio = media


## Los caminos por los que corre el material: el círculo si es un corro; si
## no, cada unión entre dos puntos cercanos.
func _armar_caminos() -> void:
	_caminos.clear()
	if _anillo:
		_caminos.append(SpellMaterial.camino_circulo(_radio))
		return
	for i in range(_puntos.size()):
		for j in range(i + 1, _puntos.size()):
			if _caminos.size() >= 24:
				return
			if _puntos[i].distance_to(_puntos[j]) <= ENLACE:
				_caminos.append(SpellMaterial.camino_recto(_puntos[i], _puntos[j]))


func registrar(spell: Node) -> void:
	_spells.append(spell)


## El campo se mueve con sus hitboxes: es un muro que avanza.
func expandir(razon: float) -> void:
	_crece = razon


func seguir(a_quien: Node2D, desfase: Vector2) -> void:
	_sigue = a_quien
	_sigue_off = desfase


func avanzar(velocidad: Vector2) -> void:
	_vel = velocidad


## Se apaga del todo: el dibujo y todos sus hitboxes.
func apagar() -> void:
	for s in _spells:
		if is_instance_valid(s):
			s.queue_free()
	queue_free()


## El campo toma el elemento de lo que ha tocado. Todos sus hitboxes pasan a
## llevarlo (la barrera entera quema, no solo el trozo que tocó el fuego) y el
## dibujo suma, sobre su propio material, el del elemento a media intensidad:
## corrientes de viento que arden, o que chispean, o que gotean.
func tomar(runa: RuneData, origen: Node) -> void:
	if _carga != 0 or runa == null:
		return
	_carga = maxi(SpellMaterial.perfil_de(runa), 0)
	_carga_color = runa.color
	_carga_t0 = _edad
	for s in _spells:
		if s != origen and is_instance_valid(s):
			s.carried = true
			s.set_rune_data(runa)


## ¿Este campo dibuja el material del elemento él solo? Si es así, los
## hechizos sueltos que lo forman NO enseñan su sprite: sería volver a ver
## seis fuegos. En silueta no hay material, y ellos ya están ocultos.
func cubre() -> bool:
	return _perfil != SpellMaterial.Perfil.NINGUNO and not _caminos.is_empty() and not silhouette


func _ready() -> void:
	# La cola va detrás del dibujo del hechizo (cuando lo hay), sin tocar
	# z_index: un z negativo la mandaría por debajo del suelo entero.
	if kind == Kind.FLECHA:
		show_behind_parent = true


func _process(delta: float) -> void:
	_edad += delta

	if kind == Kind.CAMPO:
		if _edad >= _vida:
			queue_free()
			return
		if _vel != Vector2.ZERO:
			global_position += _vel * delta
		if is_instance_valid(_sigue):
			global_position = Sigils.flotar(global_position, _sigue.global_position + _sigue_off, delta)
		if _crece > 0.0:
			scale = Vector2.ONE * (1.0 + _crece * _edad)
	else:
		# La cola crece con lo RECORRIDO y no con el tiempo: así una flecha
		# recién nacida no arrastra una cola que no ha dibujado todavía, y en
		# cámara lenta sigue teniendo la misma longitud.
		var actual: Vector2 = global_position
		_recorrido += actual.distance_to(_ultima)
		_ultima = actual

	queue_redraw()


func _draw() -> void:
	if kind == Kind.CAMPO:
		_dibujar_campo()
	else:
		_dibujar_flecha()


## --- Colores ---
## En silueta todo es blanco. Fuera de ella, la forma va teñida con el color
## del elemento y translúcida, para no tapar lo que se dibuje encima.

func _relleno(alfa: float) -> Color:
	if silhouette:
		return Color(1.0, 1.0, 1.0, 0.9)
	return Color(color.r, color.g, color.b, alfa)


func _suelo() -> Color:
	if silhouette:
		return Color(1.0, 1.0, 1.0, 0.4)
	return Color(color.r, color.g, color.b, 0.16)


func _borde() -> Color:
	if silhouette:
		return Color.WHITE
	return Color(color.r, color.g, color.b, 0.9)


## Solo dibuja si el polígono es válido. Un cuadrilátero aplastado (dos
## puntos alineados en vertical, o la superficie a altura cero) haría que
## Godot escribiera un error por fotograma.
func _poligono(pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, col)


## --- Barrera ---

func _dibujar_campo() -> void:
	if cubre():
		_dibujar_material()
		return
	if _anillo:
		_dibujar_anillo()
		return
	var t: float = clampf(_edad / maxf(_vida, 0.01), 0.0, 1.0)
	var sube: float = 1.0 - pow(1.0 - clampf(_edad / SUBIDA, 0.0, 1.0), 3.0)
	var hunde: float = 1.0 - smoothstep(HUNDE, 1.0, t)
	var arriba := Vector2(0.0, -ALTURA * sube * hunde)

	var relleno: Color = _relleno(0.30)
	var borde: Color = _borde()

	var n: int = _puntos.size()
	var enlaces: int = 0

	# Cada pareja de puntos cercanos se une con un trozo de superficie. Así
	# el corro de seis y el muro de tres salen de la MISMA regla.
	for i in range(n):
		for j in range(i + 1, n):
			var a: Vector2 = _puntos[i]
			var b: Vector2 = _puntos[j]
			if a.distance_to(b) > ENLACE:
				continue
			enlaces += 1
			_poligono(PackedVector2Array([a, b, b + arriba, a + arriba]), relleno)
			draw_line(a, b, borde, 3.0, true)
			draw_line(a + arriba, b + arriba, borde, 3.0, true)

	# Si los trozos se cierran en anillo, el suelo de dentro es de la barrera:
	# una base COMPARTIDA es lo que la hace una cosa y no seis.
	if n >= 3 and enlaces >= n:
		var orden: Array = Array(_puntos)
		orden.sort_custom(func(p, q): return p.angle() < q.angle())
		_poligono(PackedVector2Array(orden), _suelo())

	# Los postes verticales dan el "║": el borde de la superficie.
	for p in _puntos:
		draw_line(p, p + arriba, borde, 3.0, true)


func _dibujar_material() -> void:
	var t: float = clampf(_edad / maxf(_vida, 0.01), 0.0, 1.0)
	var sube: float = 1.0 - pow(1.0 - clampf(_edad / SUBIDA, 0.0, 1.0), 3.0)
	var hunde: float = 1.0 - smoothstep(HUNDE, 1.0, t)
	var env: float = sube * hunde

	# El suelo de dentro de un corro es de la barrera.
	if _anillo:
		var c: PackedVector2Array = _caminos[0]
		_poligono(c.slice(0, c.size() - 1), Color(color.r, color.g, color.b, 0.16 * env))

	var k: float = clampf((_edad - _carga_t0) / 0.3, 0.0, 1.0) if _carga_t0 > 0.0 or _carga != 0 else 0.0
	var base: Color = color.lerp(_carga_color, k * 0.6) if _carga != 0 else color
	SpellMaterial.dibujar(self, _perfil, _caminos, _edad, env, base)
	if _carga != 0:
		SpellMaterial.dibujar(self, _carga, _caminos, _edad, env * 0.55 * k, _carga_color)


## Un círculo en el suelo con un borde bajo: el contorno que dibujó el jugador.
func _dibujar_anillo() -> void:
	var t: float = clampf(_edad / maxf(_vida, 0.01), 0.0, 1.0)
	var sube: float = 1.0 - pow(1.0 - clampf(_edad / SUBIDA, 0.0, 1.0), 3.0)
	var hunde: float = 1.0 - smoothstep(HUNDE, 1.0, t)
	var arriba := Vector2(0.0, -ANILLO_ALTURA * sube * hunde)

	var base := PackedVector2Array()
	for i in range(ANILLO_SEGMENTOS):
		base.append(Vector2.from_angle(TAU * float(i) / float(ANILLO_SEGMENTOS)) * _radio)

	# El interior es de la barrera: base compartida.
	_poligono(base, _suelo())

	# El borde: una banda baja entre el suelo y su canto superior.
	var relleno: Color = _relleno(0.30)
	for i in range(ANILLO_SEGMENTOS):
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % ANILLO_SEGMENTOS]
		_poligono(PackedVector2Array([a, b, b + arriba, a + arriba]), relleno)

	var borde: Color = _borde()
	var cerrada := PackedVector2Array(base)
	cerrada.append(base[0])
	draw_polyline(cerrada, borde, 4.0, true)
	var alta := PackedVector2Array()
	for p in cerrada:
		alta.append(p + arriba)
	draw_polyline(alta, borde, 2.0, true)


## --- Flecha ---

func _dibujar_flecha() -> void:
	var d: Vector2 = _dir
	var perp: Vector2 = d.orthogonal()
	var largo: float = minf(_recorrido, COLA)

	# La cola: un triángulo que se afina hacia atrás.
	if largo > 2.0:
		var base: Vector2 = -d * 6.0
		_poligono(PackedVector2Array([
			base + perp * COLA_ANCHO * 0.5,
			base - perp * COLA_ANCHO * 0.5,
			base - d * largo,
		]), _relleno(0.35))

	# Motas de la estela (fuera de silueta): el detalle que la hace "imagen que se mueve".
	if not silhouette:
		SpellMaterial.estela(self, _perfil, d, _recorrido, _edad, color)

	# La cabeza solo se dibuja en silueta: fuera de ella la pone el sprite
	# del elemento, y dos cabezas encima se estorban.
	if silhouette:
		_poligono(PackedVector2Array([
			d * CABEZA,
			-d * 8.0 + perp * 9.0,
			-d * 3.0,
			-d * 8.0 - perp * 9.0,
		]), Color.WHITE)
