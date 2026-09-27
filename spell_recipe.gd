class_name SpellRecipe
extends RefCounted

## LA RECETA DE UN COMPONENTE DEL HECHIZO.
##
## Los sellos dibujados en un sector escriben aquí su aportación, y
## luego `build()` lee la receta terminada y crea los hechizos. Ningún
## sello sabe de la existencia de los demás.
##
## Ahí está la diferencia entre un sistema que escala y uno que no: las
## combinaciones no están escritas en ninguna parte, EMERGEN de leer
## juntos unos pocos parámetros.

const TILE: float = 64.0

## Cuánto sube un nivel. Es el lateral del cubo isométrico, el mismo
## número que usa IsoGrid al apilar bloques: si un hechizo flota, que
## flote a la altura a la que flotaría un bloque puesto encima.
const LEVEL: float = 55.5

var direction: Vector2 = Vector2.RIGHT

var origin: float = 0.0     ## a qué distancia aparece (0 = encima de ti)
var travels: bool = false   ## ¿recorre el camino o se queda quieto?
var reach: int = 0          ## casillas que abarca a lo largo
var spread: bool = false    ## ¿ocupa área en vez de un punto?
var lifetime: float = 0.0   ## segundos de más en el mundo
var height: int = 0         ## niveles que sube
var copies: int = 1
var power: float = 1.0


func _init(sector: Vector2) -> void:
	direction = sector


## Cada sello vuelca lo suyo. Cómo se acumula cada parámetro NO es
## arbitrario: dice qué significa apilar ese sello.
##
##   travels, spread    se encienden (o)    — o viaja o no
##   origin             se queda el mayor   — manda el más lejano
##   reach, lifetime,   SE SUMAN            — más flechas, más lejos;
##   height                                   más levitaciones, más rato
##   copies, power      SE MULTIPLICAN      — dos repeticiones son cuatro
func apply(sigil_name: String) -> void:
	if Sigils.FORM.has(sigil_name):
		var form: Dictionary = Sigils.FORM[sigil_name]
		origin = maxf(origin, form.get("origin", 0.0))
		travels = travels or form.get("travels", false)
		spread = spread or form.get("spread", false)
		reach += int(form.get("reach", 0))
		lifetime += float(form.get("lifetime", 0.0))
		height += int(form.get("height", 0))

	elif Sigils.OPERATOR.has(sigil_name):
		var op: Dictionary = Sigils.OPERATOR[sigil_name]
		copies *= int(op.get("copies", 1))
		power *= float(op.get("power", 1.0))


## --- La interpretación ---
func build(caster: Node2D, element: RuneData) -> void:
	var data := _powered(element)

	var manifestaciones: Array = []
	for direction_variant in _fan():
		for point in _points(direction_variant):
			manifestaciones.append([point, direction_variant])

	# El tope se aplica AQUÍ, no dentro de cada paso: así ninguna regla
	# necesita saber cuántas manifestaciones llevan las demás.
	if manifestaciones.size() > Sigils.MAX_MANIFESTATIONS:
		manifestaciones.resize(Sigils.MAX_MANIFESTATIONS)

	for m in manifestaciones:
		_manifest(caster, data, m[0], m[1])


## Paso 1: en qué puntos se manifiesta, relativo al lanzador.
##
## AQUÍ ESTÁN LAS COMBINACIONES, y ninguna está escrita como tal.
func _points(dir: Vector2) -> Array:
	var puntos: Array = []

	if travels and origin > 0.0:
		# Nace lejos Y recorre el camino: solo puede significar que se
		# manifiesta A LO LARGO. Es el muro de fuego. Arranca en la
		# casilla SIGUIENTE, no en la tuya, o te emparedas solo.
		var steps := int(origin / TILE)
		for i in range(1, steps + 1):
			puntos.append(dir * TILE * float(i))

	elif travels and reach > 1:
		# Varias flechas sin pilar: el alcance se gasta en ocupar las
		# casillas de delante en vez de en salir disparado. Sale un
		# chorro, no una bala.
		for i in range(reach):
			puntos.append(dir * TILE * float(i))

	else:
		puntos.append(dir * origin)

	# Paso 2: el área. Lo bonito es que QUÉ área depende de si además
	# viaja, y eso no hay que decidirlo: se lee.
	if spread:
		puntos = _spread_points(puntos, dir)

	# Paso 3: la altura. Cada punto se repite hacia arriba. Con barrera
	# convierte el corro en columna; solo, deja el hechizo flotando a la
	# altura de un bloque.
	if height > 0:
		var apilados: Array = []
		for p in puntos:
			for h in range(height + 1):
				apilados.append(p - Vector2(0.0, LEVEL * float(h)))
		puntos = apilados

	return puntos


## Ocupar área significa algo distinto según se mueva o no.
func _spread_points(centros: Array, dir: Vector2) -> Array:
	var salida: Array = []

	if travels:
		# Algo que avanza y ocupa sitio es un MURO DE FRENTE: se pone de
		# través a la marcha y barre. Un corro alrededor de algo que
		# avanza no significaría nada.
		var perp := dir.orthogonal()
		for centro in centros:
			for k in range(-1, 2):
				salida.append(centro + perp * TILE * float(k))
	else:
		# Quieto: el corro rodea el punto. Solo, te rodea a ti; con
		# pilar, rodea el sitio que el pilar señaló.
		for centro in centros:
			for i in range(Sigils.RING_POINTS):
				var angle := TAU * float(i) / float(Sigils.RING_POINTS)
				salida.append(centro + Vector2(cos(angle), sin(angle)) * TILE)

	return salida


## Paso 4: las direcciones del abanico. Con una sola copia no hay
## abanico y la dirección es la del sector, tal cual.
func _fan() -> Array:
	if copies <= 1:
		return [direction]

	const SPREAD := deg_to_rad(22.0)
	var directions: Array = []
	for i in range(copies):
		var offset := (float(i) - float(copies - 1) * 0.5) * SPREAD
		directions.append(direction.rotated(offset))
	return directions


## Crear el hechizo en un punto.
##
## Un hechizo sale volando solo si la flecha es lo ÚNICO que dice dónde.
## En cuanto algo más ocupa el espacio —un pilar que lo pone lejos, o
## varias flechas que lo reparten por delante— deja de ser una bala y
## pasa a ser algo que está ahí puesto.
func _manifest(caster: Node2D, data: RuneData, offset: Vector2, dir: Vector2) -> void:
	var quieto: bool = not travels or origin > 0.0 or reach > 1
	var travel_direction: Vector2 = Vector2.ZERO if quieto else dir

	var spell := SpellFactory.cast(
		caster, caster.global_position + offset, travel_direction, data,
		Sigils.BASE_LIFETIME + lifetime)

	if spell:
		spell.power = power
		# Lo que permanece ATRAVIESA. Un tornado no se deshace contra el
		# primer arbusto: lo arrastra y sigue. Sale de un parámetro que
		# ya teníamos, sin inventar una regla nueva.
		spell.piercing = lifetime > 0.0


## El aumento NO puede tocar el RuneData original: los .tres están
## precargados y COMPARTIDOS, así que multiplicarle el daño al fuego lo
## dejaría potenciado para el resto de la partida. Se duplica primero.
func _powered(element: RuneData) -> RuneData:
	if is_equal_approx(power, 1.0):
		return element

	var copy: RuneData = element.duplicate()
	copy.damage *= power
	return copy
