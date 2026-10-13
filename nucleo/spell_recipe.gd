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
const ESCALA_ARO: float = 1.4   ## cuanto mayor que una casilla es el aro de la barrera quieta

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

## Segundos de recarga de la página (el mayor de sus sellos).
var cooldown: float = 0.0

## Si lo que sale bloquea proyectiles (ver Sigils.FORM, "blocks").
var blocks: bool = false

## Cuántas barreras hay apiladas (ver Sigils, "APILAR EL MISMO GLIFO"), y cuántas
## veces se ha aplicado cada glifo (para cobrar la recarga de los repetidos).
var barriers: int = 0
var _aplicados: Dictionary = {}

## --- LENGUAJE NUEVO (ver Sigils.FORM) ---
var bounces: int = 0        ## rebotes del proyectil (y si hay barrera, la hace reflejar)
var delay: float = 0.0      ## segundos que tarda en salir lo que se lanza
var pulse: bool = false     ## el área nace en ti y se expande
var pull: bool = false      ## lo que toca es tirado en vez de apartado
var mirror: bool = false    ## sale también hacia atrás

## Dónde se lanzó, en coordenadas de mundo. Lo que nace tarde (retardo, ondas
## sucesivas) nace AQUÍ y no donde estés después.
var _base: Vector2 = Vector2.ZERO

## Calidad del trazo, de 0 (justo aceptado) a 1 (limpio). La pone quien lanza.
var calidad: float = 1.0


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
	var repetido: bool = _aplicados.has(sigil_name)
	_aplicados[sigil_name] = int(_aplicados.get(sigil_name, 0)) + 1

	if Sigils.FORM.has(sigil_name):
		var form: Dictionary = Sigils.FORM[sigil_name]
		origin = maxf(origin, form.get("origin", 0.0))
		travels = travels or form.get("travels", false)
		spread = spread or form.get("spread", false)
		# El pulso también ocupa área, pero no es una BARRERA: no agranda el aro.
		if form.get("spread", false) and not form.get("pulse", false):
			barriers += 1
		bounces += int(form.get("bounces", 0))
		delay += float(form.get("delay", 0.0))
		pulse = pulse or form.get("pulse", false)
		pull = pull or form.get("pull", false)
		mirror = mirror or form.get("mirror", false)
		reach += int(form.get("reach", 0))
		lifetime += float(form.get("lifetime", 0.0))
		height += int(form.get("height", 0))
		cooldown = maxf(cooldown, float(form.get("cooldown", 0.0)))
		blocks = blocks or form.get("blocks", false)

	elif Sigils.OPERATOR.has(sigil_name):
		var op: Dictionary = Sigils.OPERATOR[sigil_name]
		copies *= int(op.get("copies", 1))
		power *= float(op.get("power", 1.0))
		cooldown = maxf(cooldown, float(op.get("cooldown", 0.0)))

	# Lo grande no sale gratis: cada glifo repetido alarga la recarga.
	if repetido:
		cooldown += Sigils.STACK_COOLDOWN


## --- La interpretación ---
func build(caster: Node2D, element: RuneData) -> void:
	# Dónde se lanzó: lo que nace tarde nace AHÍ.
	_base = caster.global_position

	# RETARDO: una marca en el suelo avisa de dónde va a salir, y se espera.
	if delay > 0.0:
		_marcar_retardo(caster, element.color)
		await caster.get_tree().create_timer(delay).timeout
		if not is_instance_valid(caster) or not caster.is_inside_tree():
			return

	var data := _powered(element)

	# Una onda con repetición son varias ondas, una tras otra. Todo lo demás,
	# una sola vez.
	var olas: int = mini(copies, 3) if _expande() else 1
	for o in range(olas):
		if o > 0:
			await caster.get_tree().create_timer(Sigils.WAVE_GAP).timeout
			if not is_instance_valid(caster) or not caster.is_inside_tree():
				return
		_construir(caster, data)


## La marca que se ve mientras algo espera a salir: un aro que se cierra sobre el
## sitio donde nacerá.
func _marcar_retardo(caster: Node2D, color: Color) -> void:
	var marca := Marca.new()
	marca.color = color
	marca.dura = delay
	caster.get_tree().current_scene.add_child(marca)
	marca.global_position = _base


class Marca extends Node2D:
	var color: Color = Color.WHITE
	var dura: float = 1.0
	var _t: float = 0.0

	func _init() -> void:
		scale = Vector2(1.0, 0.6)   # un círculo en el suelo, en isométrico

	func _process(delta: float) -> void:
		_t += delta
		if _t >= dura:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var f: float = clampf(_t / maxf(dura, 0.01), 0.0, 1.0)
		var r: float = lerpf(34.0, 12.0, f)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, 0.35 + 0.5 * f), 3.0, true)
		draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.5 * f), 2.0, true)
		draw_circle(Vector2.ZERO, 3.0 + 3.0 * f, Color(color.lightened(0.4), 0.85))


## Lo que se crea de verdad (una vez, o una vez por onda).
func _construir(caster: Node2D, data: RuneData) -> void:
	var factor: float = Sigils.quality_factor(calidad)
	var muro: bool = _es_barrera_movil()
	var sigue: bool = _sigue()

	# Cuánto vive lo que se crea. Una barrera que avanza dura lo suyo; lo quieto,
	# lo base más lo que sume la levitación. La calidad del trazo lo encoge.
	var vida: float = (Sigils.BASE_LIFETIME + lifetime) * factor
	if muro:
		vida = Sigils.WALL_LIFETIME * factor
	elif sigue:
		# Lo que flota y te acompaña dura bastante más que lo que se queda quieto.
		vida = Sigils.FOLLOW_LIFETIME * factor
	elif _es_chorro():
		# Varias flechas: el chorro se queda más rato.
		vida = (Sigils.BASE_LIFETIME + lifetime + Sigils.jet_hold(reach)) * factor

	var manifestaciones: Array = []
	for direction_variant in _fan():
		for point in _points(direction_variant):
			manifestaciones.append([point, direction_variant])

	# El tope se aplica AQUÍ, no dentro de cada paso: así ninguna regla
	# necesita saber cuántas manifestaciones llevan las demás.
	if manifestaciones.size() > Sigils.MAX_MANIFESTATIONS:
		manifestaciones.resize(Sigils.MAX_MANIFESTATIONS)

	# Una onda se abre desde el CENTRO de lo suyo: cada punto sale hacia fuera.
	var centroides: Dictionary = {}
	if _expande():
		var sumas: Dictionary = {}
		var cuentas: Dictionary = {}
		for m in manifestaciones:
			sumas[m[1]] = sumas.get(m[1], Vector2.ZERO) + m[0]
			cuentas[m[1]] = int(cuentas.get(m[1], 0)) + 1
		for d in sumas:
			centroides[d] = sumas[d] / float(cuentas[d])

	# Lo que se queda es UNA superficie, aunque lo formen seis hechizos: el
	# campo se dibuja una vez para todos los puntos, y cada hechizo conserva
	# solo su hitbox. Sin esto una barrera se lee como "seis fuegos".
	var campo: SpellForm = null
	# Una barrera que avanza es lo mismo, pero el campo SE MUEVE con sus hitboxes:
	# uno por cada dirección del abanico.
	var campos: Dictionary = {}
	if muro:
		var grupos: Dictionary = {}
		for m in manifestaciones:
			if not grupos.has(m[1]):
				grupos[m[1]] = []
			grupos[m[1]].append(_base + m[0])
		for d in grupos:
			var f := SpellForm.field(caster, grupos[d], vida, data.color, data)
			if f != null:
				f.avanzar((d as Vector2).normalized() * Sigils.WALL_SPEED)
			campos[d] = f
	elif _es_quieto():
		var centros: Array = []
		for m in manifestaciones:
			centros.append(_base + m[0])
		campo = SpellForm.field(caster, centros, vida, data.color, data)
		if sigue and campo != null:
			campo.seguir(caster, campo.global_position - caster.global_position)
		if _expande() and campo != null:
			campo.expandir(Sigils.PULSE_SPEED / maxf(TILE * Sigils.size_factor(barriers), 1.0))

	for m in manifestaciones:
		var radial: Vector2 = Vector2.ZERO
		if _expande():
			radial = (m[0] - centroides[m[1]]).normalized()
		_manifest(caster, data, m[0], m[1], campos.get(m[1]) if muro else campo, vida, factor, radial)


## Varias flechas sin pilar: un chorro que se queda delante.
func _es_chorro() -> bool:
	return travels and origin <= 0.0 and reach > 1


## LA FLECHA NO CREA UNA FLECHA CUANDO HAY BARRERA: le da avance. Barrera + flecha
## (y nada que la ponga lejos o la alargue) es UNA barrera que se desplaza en la
## dirección de la flecha. Es lo mismo que una barrera quieta, con velocidad.
func _es_barrera_movil() -> bool:
	return travels and spread and not _es_quieto()


## El pulso: un área que nace en ti y se abre. Con algo que viaja (flecha) deja de
## ser una onda y es un muro que avanza, como cualquier área que viaja.
func _expande() -> bool:
	return pulse and spread and not travels


## Espejo: sale también hacia atrás. Solo tiene sentido en lo que tiene dirección
## propia (viaja o nace lejos); en lo que te rodea, atrás y delante son lo mismo.
func _espeja() -> bool:
	return mirror and (travels or origin > 0.0)


## LEVITACIÓN SOLA: el elemento flota y te sigue un rato. Si algo más dice dónde
## (flecha, pilar, barrera), manda eso y la levitación solo lo eleva.
func _sigue() -> bool:
	return height > 0 and not travels and not spread and origin <= 0.0 and reach <= 1


## ¿Sale disparado como proyectil?
func _es_volador() -> bool:
	return travels and not _es_quieto() and not _es_barrera_movil()


## Un hechizo sale volando solo si la flecha es lo ÚNICO que dice dónde.
func _es_quieto() -> bool:
	return not travels or origin > 0.0 or reach > 1


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
		for i in range(Sigils.jet_cells(reach)):
			puntos.append(dir * TILE * float(i))

	else:
		# Un muro que avanza arranca en la casilla de DELANTE, no en la tuya: si
		# no, prende (o moja, o electriza) el suelo que tienes bajo los pies.
		var salida: float = origin
		if travels and spread:
			salida = maxf(origin, TILE)
		if _sigue() and copies > 1:
			# Varias copias que te siguen: satélites repartidos a tu alrededor.
			for i in range(copies):
				puntos.append(dir.rotated(TAU * float(i) / float(copies)) * TILE * 0.9)
		else:
			puntos.append(dir * salida)

	# Paso 2: el área. Lo bonito es que QUÉ área depende de si además
	# viaja, y eso no hay que decidirlo: se lee.
	if spread:
		puntos = _spread_points(puntos, dir)

	# Paso 3: la altura. Cada punto se repite hacia arriba. Con barrera
	# convierte el corro en columna; solo, deja el hechizo flotando a la
	# altura de un bloque.
	if height > 0:
		var apilados: Array = []
		if spread and not _expande():
			# Barrera + levitación: una COLUMNA de aros, del suelo hacia arriba.
			for p in puntos:
				for h in range(height + 1):
					apilados.append(p - Vector2(0.0, LEVEL * float(h)))
		else:
			# Levitación sin barrera: no se repite, SE ELEVA. Solo es una cosa,
			# flotando. Un proyectil sube solo medio nivel por nivel: lo justo para
			# que se lea que vuela por encima, sin salirse de lo que puede golpear.
			var sube: float = LEVEL * float(height) * (0.5 if _es_volador() else 1.0)
			for p in puntos:
				apilados.append(p - Vector2(0.0, sube))
		puntos = apilados

	return puntos


## Ocupar área significa algo distinto según se mueva o no.
const CURVA_MURO: float = 1.5     ## radio del arco del muro, en "medias anchuras"


func _spread_points(centros: Array, dir: Vector2) -> Array:
	var salida: Array = []

	if travels:
		# Algo que avanza y ocupa sitio es un MURO DE FRENTE: se pone de
		# través a la marcha y barre. Un corro alrededor de algo que
		# avanza no significaría nada.
		# Con repetición, el muro lleva una FILA más por delante (hasta tres).
		var perp := dir.orthogonal()
		var mitad: int = Sigils.wall_half(barriers)
		for fila in range(mini(copies, 3)):
			for centro in centros:
				for k in range(-mitad, mitad + 1):
					# CURVATURA: el muro no es una recta, es un ARCO que va por delante en el
					# centro y se repliega en los extremos (como un escudo). Los puntos
					# siguen una circunferencia de radio CURVA_MURO x mitad casillas, espaciados
					# una casilla a lo largo del arco: así siguen enlazados entre sí.
					var radio: float = TILE * CURVA_MURO * float(maxi(mitad, 1))
					var ang: float = float(k) * TILE / radio
					var lateral: float = sin(ang) * radio
					var retroceso: float = (1.0 - cos(ang)) * radio
					salida.append(centro + dir * (TILE * 1.2 * float(fila) - retroceso) + perp * lateral)
	else:
		# Quieto: el corro rodea el punto. Solo, te rodea a ti; con
		# pilar, rodea el sitio que el pilar señaló.
		# Con varias barreras el aro crece, y con él el número de puntos, para que
		# sigan a la misma distancia unos de otros (si no, quedarían huecos).
		# Con repetición salen aros CONCÉNTRICOS (hasta tres), cada uno mayor.
		# (Una onda no lleva aros concéntricos: la repetición la repite en el tiempo.)
		var anillos: int = 1 if _expande() else mini(copies, 3)
		for anillo in range(anillos):
			var tam: float = minf(Sigils.size_factor(barriers) * (1.0 + 0.6 * float(anillo)), Sigils.MAX_SIZE_FACTOR)
			# El aro es mayor que una casilla: con el personaje de 115 px uno de 64 px de radio quedaba a ras de su
			# silueta. Mas puntos para que sigan a la misma distancia unos de otros.
			var radio_aro: float = tam * ESCALA_ARO
			var cuantos: int = clampi(roundi(float(Sigils.RING_POINTS) * radio_aro), Sigils.RING_POINTS, 20)
			for centro in centros:
				for i in range(cuantos):
					var angle := TAU * float(i) / float(cuantos)
					salida.append(centro + Vector2(cos(angle), sin(angle)) * TILE * radio_aro)

	return salida


## Paso 4: las direcciones del abanico. Con una sola copia no hay
## abanico y la dirección es la del sector, tal cual.
func _fan() -> Array:
	# Con barrera, las copias no abren abanico: se vuelven más aros / más filas.
	# El espejo añade la dirección contraria; la repetición abre abanico en cada una.
	var bases: Array = [direction]
	if _espeja():
		bases.append(-direction)

	if copies <= 1 or spread or _sigue():
		return bases

	const SPREAD := deg_to_rad(22.0)
	var directions: Array = []
	for base in bases:
		for i in range(copies):
			var offset := (float(i) - float(copies - 1) * 0.5) * SPREAD
			directions.append((base as Vector2).rotated(offset))
	return directions


## Crear el hechizo en un punto.
##
## Un hechizo sale volando solo si la flecha es lo ÚNICO que dice dónde.
## En cuanto algo más ocupa el espacio —un pilar que lo pone lejos, o
## varias flechas que lo reparten por delante— deja de ser una bala y
## pasa a ser algo que está ahí puesto.
func _manifest(caster: Node2D, data: RuneData, offset: Vector2, dir: Vector2,
		campo: SpellForm = null, vida: float = 0.0, factor: float = 1.0,
		radial: Vector2 = Vector2.ZERO) -> void:
	# La barrera que avanza es una barrera: no vuela como una flecha, se desplaza.
	var movil: bool = _es_barrera_movil()
	var quieto: bool = _es_quieto() or movil
	var travel_direction: Vector2 = Vector2.ZERO if quieto else dir

	var spell := SpellFactory.cast(
		caster, _base + offset, travel_direction, data,
		vida if vida > 0.0 else Sigils.BASE_LIFETIME + lifetime)

	if spell:
		spell.lanzador = caster
		spell.power = power
		# Lo que permanece ATRAVIESA. Un tornado no se deshace contra el
		# primer arbusto: lo arrastra y sigue. Sale de un parámetro que
		# ya teníamos, sin inventar una regla nueva.
		spell.piercing = lifetime > 0.0
		# La levitación lo pone a una altura: pasa por encima de barreras bajas.
		spell.altura = height
		if _sigue():
			spell.sigue = caster
			spell.sigue_offset = offset

		if movil:
			# Lo único que aporta la flecha: velocidad, hacia donde apunta.
			spell.velocidad = dir.normalized() * Sigils.WALL_SPEED
		elif not quieto and factor < 0.999:
			# Un trazo flojo no llega tan lejos. Con trazo limpio la flecha
			# vuela como siempre.
			spell.vida_maxima = 3.0 * factor

		# Lenguaje nuevo.
		spell.atrae = pull
		if radial != Vector2.ZERO:
			spell.velocidad = radial * Sigils.PULSE_SPEED   # la onda se abre
		if bounces > 0:
			spell.refleja = blocks
			if not quieto:
				spell.rebotes = bounces
				# Con rebotes la flecha vive más: tiene que dar tiempo a volver.
				spell.vida_maxima = (2.5 + float(bounces)) * factor

		# Toda barrera bloquea proyectiles.
		if blocks:
			spell.hacer_barrera()

		# Si el campo ya dibuja el elemento, este hechizo solo es un hitbox.
		if campo != null:
			campo.registrar(spell)
			spell.campo = campo
			if campo.cubre():
				spell.cubierto = true


## El aumento NO puede tocar el RuneData original: los .tres están
## precargados y COMPARTIDOS, así que multiplicarle el daño al fuego lo
## dejaría potenciado para el resto de la partida. Se duplica primero.
func _powered(element: RuneData) -> RuneData:
	if is_equal_approx(power, 1.0):
		return element

	var copy: RuneData = element.duplicate()
	copy.damage *= power
	return copy
