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

var direction: Vector2 = Vector2.RIGHT
var origin: float = 0.0    ## a qué distancia aparece (0 = encima de ti)
var travels: bool = false  ## ¿recorre el camino o se queda quieto?
var ring: bool = false     ## ¿rodea el punto con un corro?
var copies: int = 1
var power: float = 1.0


func _init(sector: Vector2) -> void:
	direction = sector


## Cada sello vuelca lo suyo. Los operadores MULTIPLICAN en vez de
## asignar, que es lo que permite apilarlos: dos sellos de repetición
## son cuatro copias, no dos.
func apply(sigil_name: String) -> void:
	if Sigils.FORM.has(sigil_name):
		var form: Dictionary = Sigils.FORM[sigil_name]
		origin = maxf(origin, form.get("origin", 0.0))
		travels = travels or form.get("travels", false)
		ring = ring or form.get("ring", false)

	elif Sigils.OPERATOR.has(sigil_name):
		var op: Dictionary = Sigils.OPERATOR[sigil_name]
		copies *= int(op.get("copies", 1))
		power *= float(op.get("power", 1.0))


## --- La interpretación ---
## Cuatro pasos, leídos en orden. Cada uno mira solo un parámetro, y de
## su encadenamiento salen todas las combinaciones.
func build(caster: Node2D, element: RuneData) -> void:
	var data := _powered(element)

	# Las copias abren en abanico alrededor de la dirección. Sirve igual
	# para algo que vuela (varias trayectorias) que para algo quieto
	# (varias posiciones), así que la repetición no necesita saber cuál
	# de las dos cosas está repitiendo.
	for direction_variant in _fan():
		for point in _points(direction_variant):
			_manifest(caster, data, point, direction_variant)


## Paso 1: en qué puntos se manifiesta, relativo al lanzador.
##
## AQUÍ ESTÁ EL MURO DE FUEGO. Un pilar pone origen lejos; una flecha
## pone que viaja. Algo que nace lejos Y recorre el camino solo puede
## significar una cosa: que se manifiesta A LO LARGO del camino. No hay
## ninguna regla "pilar + flecha = muro" escrita en ningún sitio.
func _points(dir: Vector2) -> Array:
	var points: Array = []

	if travels and origin > 0.0:
		# El muro arranca en la casilla SIGUIENTE, no en la tuya: si
		# empezara en el origen, un muro de tierra te emparedaría en tu
		# propia casilla.
		var steps := int(origin / TILE)
		for i in range(1, steps + 1):
			points.append(dir * TILE * float(i))
	else:
		points.append(dir * origin)

	# Paso 2: el anillo convierte cada punto en un corro a su alrededor.
	# Combinado con el pilar (origen lejos) sale una columna rodeada de
	# anillo — el segundo de tus ejemplos, tampoco escrito.
	if ring:
		var ringed: Array = []
		for centre in points:
			for i in range(Sigils.RING_POINTS):
				var angle := TAU * float(i) / float(Sigils.RING_POINTS)
				ringed.append(centre + Vector2(cos(angle), sin(angle)) * TILE)
		return ringed

	return points


## Paso 3: las direcciones del abanico. Con una sola copia no hay
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


## Paso 4: crear el hechizo en un punto. Si la receta dice que viaja,
## sale disparado; si no, se queda.
func _manifest(caster: Node2D, data: RuneData, offset: Vector2, dir: Vector2) -> void:
	var travel_direction := dir if (travels and origin <= 0.0) else Vector2.ZERO
	var spell := SpellFactory.cast(caster, caster.global_position + offset, travel_direction, data)
	if spell:
		spell.power = power


## El aumento NO puede tocar el RuneData original: los .tres están
## precargados y COMPARTIDOS, así que multiplicarle el daño al fuego lo
## dejaría potenciado para el resto de la partida. Se duplica primero.
func _powered(element: RuneData) -> RuneData:
	if is_equal_approx(power, 1.0):
		return element

	var copy: RuneData = element.duplicate()
	copy.damage *= power
	return copy
