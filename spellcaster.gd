extends Node2D

# El enum de tipos de runa ahora vive en runes.gd (clase Runes),
# para que otros scripts (RuneData, Enemy, Spell, futuros objetos
# del mundo) puedan usarlo sin depender de este nodo.

## El trazo que se está reconociendo ahora mismo. Lo rellena el grimorio
## a través de add_stroke(); este nodo ya no captura ratón.
var stroke_points: Array[Vector2] = []

# Conteo de esquinas: el reconocedor ANTIGUO, y solo de emergencia.
#
# Ya no pretende acertar: con siete elementos y formas nuevas, contar
# esquinas no distingue un rayo de una tierra. Su único trabajo es que
# el juego arranque y se deje jugar con la biblioteca vacía, el rato
# que tardes en grabar las plantillas. En cuanto haya una sola muestra
# de cualquier elemento, deja de usarse.
#   0-1 esquinas -> AGUA
#   2-3 esquinas -> FUEGO
#   4 o más      -> VIENTO
const CORNER_ANGLE_THRESHOLD: float = 40.0
const CIRCLE_MAX_CORNERS: int = 1
const TRIANGLE_MAX_CORNERS: int = 3

# La "base de datos" de elementos: qué RuneData corresponde a cada
# forma reconocida. Añadir un elemento nuevo el día de mañana es
# crear su .tres y añadir una línea aquí, nada más.
const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")
const WATER_RUNE: RuneData = preload("res://water_rune.tres")
const WIND_RUNE: RuneData = preload("res://wind_rune.tres")
const EARTH_RUNE: RuneData = preload("res://earth_rune.tres")
const LIGHTNING_RUNE: RuneData = preload("res://lightning_rune.tres")
const ICE_RUNE: RuneData = preload("res://ice_rune.tres")
const TIME_RUNE: RuneData = preload("res://time_rune.tres")

var rune_database: Dictionary = {
	Runes.Type.SHAPE_TRIANGLE: FIRE_RUNE,
	Runes.Type.SHAPE_CIRCLE: WATER_RUNE,
	Runes.Type.SHAPE_LINES: WIND_RUNE,
	Runes.Type.SHAPE_ARC: EARTH_RUNE,
	Runes.Type.ELEMENT_LIGHTNING: LIGHTNING_RUNE,
	Runes.Type.ELEMENT_ICE: ICE_RUNE,
	Runes.Type.ELEMENT_TIME: TIME_RUNE,
}

## Cuánto tiene que irse un trazo hacia fuera o hacia dentro para contar
## como flecha o pilar en vez de barrera. Con 0.45, un trazo tiene que
## desviarse más de unos 63° de la tangente para dejar de ser barrera.
const ALIGNMENT_THRESHOLD: float = 0.45

## --- El hechizo que se está componiendo ---
## Ya no es una secuencia de dos runas, sino dos cosas independientes:
## QUÉ elemento (un solo trazo cerrado) y HACIA DÓNDE (un trazo recto
## por cada dirección, tantos como quieras). Dibujar cuatro trazos en
## cuatro sectores del círculo lanza cuatro proyectiles a la vez.
## --- LAS PÁGINAS DEL GRIMORIO ---
##
## Un mago con un solo hechizo listo no tiene decisiones: tiene el
## hechizo. Con tres preparados, entrar en una sala es elegir con qué
## entras, y eso convierte el libro en PREPARACIÓN y la partida en
## EJECUCIÓN — dos ritmos distintos, que es justo lo que le faltaba a un
## juego donde abrir el libro detiene el tiempo.
##
## Las páginas NO se gastan al usarse. Podrían, y sería más "táctico",
## pero aquí solo añadiría ir y venir: el libro para el tiempo, así que
## rehacer un hechizo gastado no cuesta riesgo, cuesta tedio. Un hechizo
## preparado es una herramienta en el cinturón, no una poción. (Si algún
## día se quiere lo contrario, es vaciar la página en cast_page.)
const PAGES: int = 3

## En cuál se está dibujando ahora mismo.
var page: int = 0

## Tres fichas iguales. Cada una es un hechizo entero: su elemento, sus
## componentes y su propio historial de deshacer.
##
## El historial VA POR PÁGINA y no es un detalle: con uno compartido,
## deshacer después de cambiar de página borraría un trazo de la página
## de al lado, y el jugador vería desaparecer algo que no estaba mirando.
var pages: Array = []


## --- El hechizo que se está componiendo ---
##
## Estas tres siguen existiendo con el mismo nombre y el mismo
## significado que siempre, pero ya no guardan nada: son una VENTANA a la
## página activa. Todo el código que las usaba —el grimorio al pintar, la
## receta al construir, deshacer— funciona igual sin enterarse de que
## ahora hay tres. Esa es la razón de hacerlo con propiedades y no
## renombrando medio archivo.
var current_element: Runes.Type:
	get:
		return pages[page]["element"]
	set(value):
		pages[page]["element"] = value

## Cada entrada es {"direction": Vector2, "sigils": Array}.
## Un hechizo son N componentes, no una pareja fija de runas.
var current_components: Array:
	get:
		return pages[page]["components"]

## Qué hizo cada trazo, en orden, para poder deshacerlo.
##
## Guardar "qué cambió" y no solo "qué había" es lo que permite que
## deshacer funcione bien al rectificar el elemento: si dibujas fuego,
## luego agua y luego deshaces, vuelve a ser fuego — no se queda sin
## elemento. Cada entrada apunta el valor ANTERIOR.
var undo_history: Array:
	get:
		return pages[page]["undo"]

const MIN_STROKE_LENGTH: float = 40.0


## Este nodo ya no escucha el ratón. Desde que existe el grimorio, quien
## captura el trazo es la interfaz del libro (spellbook.gd) y este script
## se queda con lo que de verdad le toca: reconocer qué runa era y
## resolver el hechizo. El libro lo encuentra por este grupo.
func _ready() -> void:
	add_to_group("spellcaster")

	# Las páginas se crean aquí y no en la declaración porque las tres
	# propiedades de arriba leen pages[page]: si alguien preguntara antes
	# de esto, se encontraría una lista vacía.
	for i in range(PAGES):
		pages.append({
			"element": Runes.Type.NONE,
			"components": [],
			"undo": [],
		})


## --- Interfaz pública, la que usa el grimorio ---

## Recibe un trazo ya capturado y el SECTOR del círculo donde se dibujó,
## ya convertido en vector unitario por el grimorio (que es quien conoce
## la geometría del libro; aquí solo nos llega "hacia allá", o ZERO si
## se dibujó sobre el núcleo).
##
## LO QUE DECIDE EL SIGNIFICADO ES DÓNDE SE DIBUJA, NO QUÉ FORMA TIENE:
##   - en el NÚCLEO  -> es el elemento
##   - en un SECTOR  -> es un componente, en la dirección de ese sector
##
## Antes lo decidía la forma (cerrada = elemento, recta = patrón), y eso
## dejaba fuera cualquier gesto abierto: un semicírculo no se cierra, así
## que jamás habría podido ser un elemento. Mirar la posición en vez de
## la forma libera por completo el vocabulario de gestos, y de paso
## elimina una heurística frágil.
## Recibe un GESTO COMPLETO: una lista de trazos, porque un sello puede
## necesitar varios (un palo y una base, dos arcos, tres líneas).
func add_gesture(strokes: Array, sector: Vector2) -> void:
	if strokes.is_empty():
		return

	stroke_points.clear()
	for p in strokes[0]:
		stroke_points.append(p)

	# Un gesto de varios trazos nunca es "demasiado corto": el trazo
	# suelto y minúsculo sí, pero tres líneas cortas son un gesto válido.
	if strokes.size() == 1 and _get_total_length() < MIN_STROKE_LENGTH:
		print("Trazo demasiado corto, ignorado")
		return

	if sector == Vector2.ZERO:
		_add_element(strokes)
	else:
		# TODO GESTO DE SECTOR PASA POR EL $P, tenga un trazo o siete.
		#
		# Antes solo pasaban los de varios trazos, y esa condición era el
		# bug: el rombo, la levitación y la barrera se dibujan DE UN SOLO
		# TRAZO, así que jamás llegaban al reconocedor. Caían directos al
		# atajo del producto escalar, que solo sabe devolver tres cosas, y
		# de ahí que en la partida todo saliera flecha o pilar. No es que
		# los reconociera mal: es que ni los miraba.
		#
		# Medido sobre las plantillas ya grabadas, los seis sellos se
		# distinguen entre sí SIN UNA SOLA CONFUSIÓN (margen mediano del
		# 50% al 324%, muy por encima del corte del 30%). La puntería
		# estaba; lo que faltaba era dejarla trabajar.
		_add_sigil_gesture(strokes, sector)


## Un sello se compara SOLO contra sellos, nunca contra los elementos.
func _add_sigil_gesture(strokes: Array, sector: Vector2) -> void:
	if not gesture_library.has_any(GestureLibrary.SIGILS):
		print("Aún no hay sellos grabados.")
		_add_component(sector)
		return

	var result: Dictionary = GestureRecognizer.recognize(
		strokes, gesture_library.templates_for(GestureLibrary.SIGILS))

	# Se imprime también el RIVAL. Un rechazo sin rival no se puede
	# arreglar: "barrera al 4%" parece mala suerte, y "barrera contra
	# rombo al 4%" dice exactamente qué hay que tocar.
	print("[$P sello] ", result["name"], " vs ", result["second_name"],
		"  margen ", "%.0f%%" % (100.0 * minf(result["margin"], 9.99)),
		"" if result["accepted"] else "  -> RECHAZADO")

	if result["accepted"] and Sigils.is_known(result["name"]):
		Sfx.play(self, "sello_ok")
		add_sigil(sector, result["name"])
		return

	# EL ATAJO YA NO ES LA RED DE SEGURIDAD DE TODO.
	#
	# Que un sello rechazado se convirtiera calladamente en una flecha era
	# cómodo y era mentira: el juego respondía con total seguridad —"Sello
	# 'flecha'"— a un gesto que no había entendido, así que nunca te
	# enterabas de que había que repetirlo. Y encima premiaba el fallo con
	# el sello más potente, que es exactamente al revés de lo que enseña
	# un buen reconocedor.
	#
	# El atajo sigue existiendo, porque una raya recta ES el azúcar
	# deliberado del trazo simple. Pero solo para eso: para una raya.
	# Cualquier otra cosa rechazada se dice en voz alta.
	if _is_straight(strokes):
		_add_component(sector)
	else:
		Sfx.play(self, "sello_no")
		print("No he reconocido ese sello. Vuelve a dibujarlo.")


## ¿Es el gesto una simple raya?
##
## Se mide comparando el RECORRIDO con la distancia de punta a punta: una
## línea recta vale 1.0 y cualquier símbolo se dispara enseguida. Medido
## sobre las plantillas ya grabadas, el sello más recto que existe da 1.18
## y las medianas van de 1.74 a 15.87, así que el corte en 1.25 separa sin
## rozar a nadie. Un trazo hecho a pulso ronda 1.02-1.10.
const STRAIGHT_RATIO: float = 1.25


func _is_straight(strokes: Array) -> bool:
	if strokes.size() != 1:
		return false

	var recorrido: float = _get_total_length()
	var punta_a_punta: float = stroke_points[0].distance_to(stroke_points[-1])
	if punta_a_punta < 1.0:
		return false

	return recorrido / punta_a_punta <= STRAIGHT_RATIO


func _add_element(strokes: Array) -> void:
	var rune: Runes.Type = _recognize_shape(strokes)

	if rune == Runes.Type.NONE:
		Sfx.play(self, "sello_no")
		print("No he reconocido esa forma.")
		return

	# Un elemento nuevo sustituye al anterior: solo hay uno por hechizo,
	# y así rectificar es simplemente volver a dibujarlo.
	Sfx.play(self, "sello_ok")
	undo_history.append({"kind": "element", "previous": current_element})
	current_element = rune
	print("Elemento: ", rune_database[rune].display_name)


## Un trazo recto en un sector es el atajo del sello equivalente: el
## trazo es azúcar, el sello es el lenguaje. Por eso lo primero que se
## hace es traducirlo a un nombre de sello y a partir de ahí los dos
## caminos son el mismo.
func _add_component(sector: Vector2) -> void:
	var pattern: Runes.Pattern = _pattern_of_stroke(sector)
	add_sigil(sector, Sigils.PATTERN_AS_SIGIL[pattern])


## Añade un sello a un sector. Si ese sector ya tenía algo dibujado, el
## sello se SUMA a lo que hubiera: así es como se combinan.
##
## EL FILTRO DE EJE SE APLICA AQUÍ y no en cada sitio que añade sellos,
## porque aquí pasan los dos caminos —el $P y el atajo de la raya— y una
## regla que se pueda esquivar por uno de los dos no es una regla.
func add_sigil(sector: Vector2, sigil_name: String) -> void:
	if not Sigils.allowed_on(sigil_name, sector):
		print("'", sigil_name, "' no vale hacia ahí: una flecha vuela plana.",
			" Prueba con levitación, barrera o pilar.")
		return

	var component := _component_at(sector)
	component["sigils"].append(sigil_name)

	undo_history.append({"kind": "sigil", "direction": sector})
	print("Sello '", sigil_name, "' hacia ", sector,
		"  ->  ", component["sigils"])


## Busca el componente de ese sector, o lo crea si es el primero que
## cae ahí. Los sellos del mismo sector modifican el mismo componente;
## los de sectores distintos son componentes independientes.
func _component_at(sector: Vector2) -> Dictionary:
	for component in current_components:
		if component["direction"].is_equal_approx(sector):
			return component

	var created := {"direction": sector, "sigils": []}
	current_components.append(created)
	return created


## Qué patrón pide un trazo recto, según hacia dónde va EN RELACIÓN a su
## sector. No hacen falta símbolos nuevos ni tocar el reconocedor: la
## información ya estaba en el trazo, solo había que leerla.
##
##   hacia fuera (alejándose del centro) -> FLECHA
##   hacia dentro (volviendo al centro)  -> PILAR
##   de lado (cruzando el sector)        -> BARRERA
##
## El producto escalar mide justo eso: vale 1 si el trazo va exactamente
## hacia fuera, -1 si va exactamente hacia dentro, y 0 si es perpendicular.
func _pattern_of_stroke(sector: Vector2) -> Runes.Pattern:
	var stroke_direction: Vector2 = (stroke_points[-1] - stroke_points[0]).normalized()
	var alignment: float = stroke_direction.dot(sector)

	if alignment > ALIGNMENT_THRESHOLD:
		return Runes.Pattern.ARROW
	elif alignment < -ALIGNMENT_THRESHOLD:
		return Runes.Pattern.PILLAR

	return Runes.Pattern.BARRIER


## El elemento elegido, o null si aún no hay ninguno. Devuelve el
## RuneData completo, no el tipo: así el libro puede pintar su color y su
## nombre sin conocer la lista de elementos que existen.
func current_element_data() -> RuneData:
	if current_element == Runes.Type.NONE:
		return null
	return rune_database.get(current_element)


## Los componentes dibujados hasta ahora. El grimorio los usa para pintar
## el glifo que toca en cada sector ocupado.
func components() -> Array:
	return current_components


## Deshace el último trazo que tuvo efecto. Los trazos que no llegaron a
## contar (demasiado cortos, o hechos sobre el núcleo sin sector) no
## entran en el historial, así que deshacer nunca "gasta" un turno en
## algo que el jugador no vio pasar.
func undo_last() -> void:
	if undo_history.is_empty():
		print("No hay nada que deshacer.")
		return

	var last: Dictionary = undo_history.pop_back()

	match last["kind"]:
		"element":
			current_element = last["previous"]
			print("Deshecho el elemento.")
		"sigil":
			# Se quita el último sello de SU sector, no el último
			# componente: si tenías dos sellos apilados ahí, deshacer
			# debe quitar uno, no el montón entero.
			var component := _component_at(last["direction"])
			component["sigils"].pop_back()
			if component["sigils"].is_empty():
				current_components.erase(component)
			print("Deshecho un sello.")


## Vacía LA PÁGINA ACTIVA, no las tres. Borrar las otras dos por
## equivocación sería el peor error posible de esta pantalla: se pierde
## trabajo que el jugador no estaba ni mirando.
func clear_sequence() -> void:
	current_element = Runes.Type.NONE
	current_components.clear()
	undo_history.clear()
	stroke_points.clear()


## --- Pasar página ---

func select_page(indice: int) -> void:
	if indice < 0 or indice >= PAGES or indice == page:
		return
	page = indice
	stroke_points.clear()


## ¿Tiene esta página algo dibujado? Lo usa el libro para pintar las
## pestañas, y quien pregunta no debería tener que saber que una página
## es un diccionario.
func page_ready(indice: int) -> bool:
	if indice < 0 or indice >= PAGES:
		return false
	var p: Dictionary = pages[indice]
	return p["element"] != Runes.Type.NONE and not p["components"].is_empty()


## El elemento de una página cualquiera, para pintar su pestaña del color
## que le toca.
func page_element_data(indice: int) -> RuneData:
	if indice < 0 or indice >= PAGES:
		return null
	var tipo: Runes.Type = pages[indice]["element"]
	if tipo == Runes.Type.NONE:
		return null
	return rune_database.get(tipo)


## Al cerrar el libro se lanza la página en la que estabas.
##
## SE MANTIENE EL GESTO DE SIEMPRE —dibujas, cierras, sale— porque era
## bueno y porque cambiarlo obligaría a reaprender lo único que el
## jugador ya tenía interiorizado. Las páginas no lo sustituyen: lo
## amplían. Lo que antes era "el hechizo" ahora es "la página en la que
## estabas", y las otras dos siguen ahí para las teclas 1-3.
func cast_current() -> void:
	cast_page(page)


## Lanza una página cualquiera, esté el libro abierto o cerrado.
##
## LA PÁGINA NO SE BORRA AL LANZARLA, y ese es el cambio de verdad: un
## hechizo preparado deja de ser de un solo uso y pasa a ser algo que
## llevas encima. Entrar en una sala con fuego en la 1, hielo en la 2 y
## viento en la 3 es una decisión que se toma ANTES, con el tiempo
## parado, y se ejecuta después sin volver a pararlo.
func cast_page(indice: int) -> void:
	if indice < 0 or indice >= PAGES:
		return

	var ficha: Dictionary = pages[indice]
	var element_data: RuneData = rune_database.get(ficha["element"])
	var componentes: Array = ficha["components"]

	if element_data == null:
		print("La página ", indice + 1, " no tiene ningún elemento dibujado.")
		return

	if componentes.is_empty():
		print("A la página ", indice + 1,
			" le falta hacia dónde: dibuja un trazo en algún sector.")
		return

	# Cada componente arma su receta con los sellos que le cayeron
	# encima, y la receta terminada decide qué sale. Aquí no hay ni una
	# sola combinación escrita: todas emergen de leer juntos los pocos
	# parámetros que los sellos dejaron puestos.
	for component in componentes:
		var recipe := SpellRecipe.new(component["direction"])
		for sigil_name in component["sigils"]:
			recipe.apply(sigil_name)
		recipe.build(self, element_data)

	_play_cast_animation()

	print("¡Hechizo lanzado! (página ", indice + 1, ") ",
		element_data.display_name, " x", componentes.size(), " componentes")


## "He lanzado un hechizo" es un SUCESO: no se puede deducir mirando la
## posición de nadie, así que hay que avisar. Es el único de los cinco
## clips que necesita esto — andar y respirar se observan, y el golpe y
## la muerte llegan por la señal de vida.
##
## Se busca el animador en vez de guardarlo: así el Spellcaster funciona
## igual en un actor que no tenga animación, sin comprobaciones ni
## configuración. Si no hay, no pasa nada.
func _play_cast_animation() -> void:
	var animador := ActorAnimator.find_in(get_parent())
	if animador:
		animador.play("cast")


## --- Reconocimiento (interno) ---

func _count_corners() -> int:
	var corners: int = 0

	if stroke_points.size() < 3:
		return 0

	for i in range(1, stroke_points.size() - 1):
		var prev_segment: Vector2 = stroke_points[i] - stroke_points[i - 1]
		var next_segment: Vector2 = stroke_points[i + 1] - stroke_points[i]

		if prev_segment.length() < 1.0 or next_segment.length() < 1.0:
			continue

		var angle_diff: float = rad_to_deg(prev_segment.angle_to(next_segment))
		if abs(angle_diff) > CORNER_ANGLE_THRESHOLD:
			corners += 1

	return corners





## --- Reconocimiento por plantillas ($P) ---

## Se pide a GestureLibrary en vez de precargarla: ver get_shared().
var gesture_library: GestureLibrary = GestureLibrary.get_shared()

## Qué runa es cada gesto grabado. El nombre del gesto es un texto
## porque la biblioteca no sabe nada del juego: solo guarda formas. Esta
## tabla es el único sitio donde "el gesto llamado fuego" se convierte
## en "el elemento fuego".
##
## Sigue haciendo falta aunque ahora los nombres coincidan: la
## biblioteca guarda textos y el juego usa el enum, y el enum no se
## puede reordenar (los .tres guardan el número). Es la junta entre las
## dos piezas, y por eso es mejor que sea explícita.
const GESTURE_TO_RUNE: Dictionary = {
	"fuego": Runes.Type.SHAPE_TRIANGLE,
	"agua": Runes.Type.SHAPE_CIRCLE,
	"viento": Runes.Type.SHAPE_LINES,
	"tierra": Runes.Type.SHAPE_ARC,
	"rayo": Runes.Type.ELEMENT_LIGHTNING,
	"hielo": Runes.Type.ELEMENT_ICE,
	"tiempo": Runes.Type.ELEMENT_TIME,
}


## Un gesto del núcleo se compara SOLO contra los elementos, nunca
## contra los sellos. Cada gesto añadido es un competidor más para todos
## los demás, así que sin esta separación el reconocimiento de los
## elementos se degradaría según fueras inventando sellos.
func _recognize_with_templates(strokes: Array) -> Runes.Type:
	var result: Dictionary = GestureRecognizer.recognize(
		strokes, gesture_library.templates_for(GestureLibrary.ELEMENTS))

	# Quedarse sin plantillas NO es fallar la puntería, y decir "no te he
	# entendido" cuando el problema es que la biblioteca está a medias
	# manda a buscar por el sitio equivocado.
	if result.get("needs_more_samples", false):
		_warn_missing_templates()
		return Runes.Type.NONE

	print("[$P] ", result["name"], " vs ", result["second_name"],
		"  parecido ", "%.2f" % result["score"],
		"  margen ", "%.0f%%" % (100.0 * minf(result["margin"], 9.99)),
		"" if result["accepted"] else "  -> RECHAZADO")

	if not result["accepted"]:
		return Runes.Type.NONE

	return GESTURE_TO_RUNE.get(result["name"], Runes.Type.NONE)


## Dice QUÉ falta, no solo que algo falla. Un mensaje que enumera los
## elementos sin grabar ahorra el rato de buscar el fallo donde no está.
func _warn_missing_templates() -> void:
	var faltan: PackedStringArray = []
	for nombre in GestureLibrary.ELEMENTS:
		if gesture_library.sample_count(nombre) == 0:
			faltan.append(nombre)

	print("No se puede reconocer: hacen falta al menos DOS elementos")
	print("  grabados para poder distinguirlos. Sin grabar: ",
		", ".join(faltan))
	print("  Abre el libro con T, pulsa G y dibuja cada uno.")


## Qué forma es el gesto dibujado en el núcleo.
##
## Si ya hay plantillas de elementos, manda el $P. Si no, se recurre al
## conteo de esquinas, que es lo que permite grabarlas sin que el juego
## se quede mientras tanto sin reconocer nada.
func _recognize_shape(strokes: Array) -> Runes.Type:
	if gesture_library.has_any(GestureLibrary.ELEMENTS):
		return _recognize_with_templates(strokes)

	return _recognize_by_corners()


## --- Reconocimiento antiguo, por conteo de esquinas ---
## Solo se usa mientras la biblioteca de gestos esté vacía. No sabe
## reconocer el semicírculo (tierra): un trazo abierto no tiene esquinas
## que contar. En cuanto grabes plantillas, deja de usarse.
func _recognize_by_corners() -> Runes.Type:
	var corners: int = _count_corners()
	print("[esquinas] detectadas: ", corners)

	if corners <= CIRCLE_MAX_CORNERS:
		return Runes.Type.SHAPE_CIRCLE
	elif corners <= TRIANGLE_MAX_CORNERS:
		return Runes.Type.SHAPE_TRIANGLE

	return Runes.Type.SHAPE_LINES


func _get_total_length() -> float:
	var total: float = 0.0
	for i in range(stroke_points.size() - 1):
		total += stroke_points[i].distance_to(stroke_points[i + 1])
	return total
