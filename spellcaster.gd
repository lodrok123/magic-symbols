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

## --- RECARGA POR PÁGINA ---
##
## Lanzar una página la deja recargando: lo que tarda lo dicen sus sellos
## (Sigils, "cooldown"; con varios manda el mayor). Un hechizo potente no puede
## ser gratis: una flecha se repite enseguida, un muro no. El libro y la
## interfaz la enseñan en las pestañas de las páginas.
var cooldown_left: Array = [0.0, 0.0, 0.0]
var cooldown_total: Array = [0.0, 0.0, 0.0]

## --- AVISO DE LO QUE SALIÓ MAL ---
##
## Un rechazo que solo sale por consola no lo ve quien juega. Aquí se guarda el
## texto y el instante (en tiempo REAL, para que se vea con el libro abierto, que
## tiene el juego parado) hasta el que el libro debe enseñarlo.
var feedback_text: String = ""
var feedback_until: int = 0

## Lo último que se reconoció en el trazo, para poder decir "se parece a X".
var _parecido: String = ""
var _calidad_elemento: float = 1.0

## Un glifo se compara también girado según su sector (ver _reconocer_glifo).
const ROTAR_POR_SECTOR: bool = true


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
			"element_q": 1.0,
			"components": [],
			"undo": [],
		})


func _process(delta: float) -> void:
	# Con el libro abierto el árbol está parado y esto no corre: la recarga
	# cuenta tiempo de juego, no tiempo de preparación.
	for i in range(PAGES):
		if cooldown_left[i] > 0.0:
			cooldown_left[i] = maxf(0.0, cooldown_left[i] - delta)


## Cuánto le queda a la recarga de una página, de 1 (recién lanzada) a 0 (lista).
func page_cooldown_fraction(indice: int) -> float:
	if indice < 0 or indice >= PAGES or cooldown_total[indice] <= 0.0:
		return 0.0
	return clampf(cooldown_left[indice] / cooldown_total[indice], 0.0, 1.0)


func _feedback(texto: String, segundos: float = 1.4) -> void:
	feedback_text = texto
	feedback_until = Time.get_ticks_msec() + int(segundos * 1000.0)


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
		_feedback("Trazo demasiado corto")
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

	var result: Dictionary = _reconocer_glifo(strokes, sector)

	# Se imprime también el RIVAL. Un rechazo sin rival no se puede
	# arreglar: "barrera al 4%" parece mala suerte, y "barrera contra
	# rombo al 4%" dice exactamente qué hay que tocar.
	print("[$P sello] ", result["name"], " vs ", result["second_name"],
		"  margen ", "%.0f%%" % (100.0 * minf(result["margin"], 9.99)),
		"" if result["accepted"] else "  -> RECHAZADO",
		"  (girado)" if result.get("girado", false) else "")

	if result["accepted"] and Sigils.is_known(result["name"]):
		# Un sello reconocido pero no activo se rechaza AQUÍ, antes del
		# sonido de acierto: si no, sonaría "ok" y a continuación "no".
		if not Repertoire.sigil_active(result["name"]):
			_refuse_locked("sello", result["name"])
			return
		Sfx.play(self, "sello_ok")
		PlayLog.event("trazo", {"tipo": "glifo", "nombre": result["name"],
			"margen": snappedf(result["margin"], 0.01),
			"calidad": snappedf(result.get("quality", 1.0), 0.01),
			"girado": result.get("girado", false)})
		add_sigil(sector, result["name"], result.get("quality", 1.0))
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
		_feedback("No reconocido · se parece a: %s" % _nombre_visible(result["name"]))
		PlayLog.event("fallo", {"tipo": "glifo", "parece": result["name"],
			"rival": result["second_name"], "margen": snappedf(result["margin"], 0.01)})


## Reconoce un glifo dibujado en un sector. Con ROTAR_POR_SECTOR se prueba también
## el trazo GIRADO como si el sector fuera el de la derecha, y se queda lo que
## mejor se reconozca: así una flecha dibujada "hacia fuera" en cualquier sector
## vale, y las plantillas grabadas en otro sector siguen valiendo.
func _reconocer_glifo(strokes: Array, sector: Vector2) -> Dictionary:
	var plantillas: Dictionary = gesture_library.templates_for(GestureLibrary.SIGILS)
	var activos: PackedStringArray = Repertoire.active_sigils()
	var directo: Dictionary = GestureRecognizer.recognize(strokes, plantillas, activos)

	if not ROTAR_POR_SECTOR or absf(sector.angle()) < 0.01:
		return directo

	var giro: float = -sector.angle()
	var girados: Array = []
	for trazo in strokes:
		var nuevo: Array = []
		for punto in trazo:
			nuevo.append((punto as Vector2).rotated(giro))
		girados.append(nuevo)

	var girado: Dictionary = GestureRecognizer.recognize(girados, plantillas, activos)
	girado["girado"] = true

	var mejor_girado: bool = false
	if girado["accepted"] and not directo["accepted"]:
		mejor_girado = true
	elif girado["accepted"] == directo["accepted"] and girado["margin"] > directo["margin"]:
		mejor_girado = true
	return girado if mejor_girado else directo


## Nombre de un gesto para enseñarlo; vacío si no hay ninguno.
func _nombre_visible(nombre: String) -> String:
	return nombre if nombre != "" else "?"


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
	_parecido = ""
	_calidad_elemento = 1.0
	var rune: Runes.Type = _recognize_shape(strokes)

	if rune == Runes.Type.NONE:
		Sfx.play(self, "sello_no")
		print("No he reconocido esa forma.")
		if _parecido != "":
			_feedback("No reconocido · se parece a: %s" % _parecido)
		return

	# SE RECONOCE CONTRA TODAS LAS PLANTILLAS Y SE FILTRA DESPUÉS, no al
	# revés. Filtrar antes dejaría al reconocedor comparando contra una o
	# dos plantillas (con una sola ni siquiera funciona: pide al menos dos)
	# y cualquier garabato acabaría siendo "el elemento que sí tienes".
	# Reconociendo entre todas, un gesto parecido a una runa aún bloqueada
	# FALLA en vez de convertirse en otra, que es lo que pide el diseño.
	var gesture_name: String = _gesture_name_of(rune)
	if not Repertoire.element_active(gesture_name):
		_refuse_locked("elemento", gesture_name)
		return

	# Un elemento nuevo sustituye al anterior: solo hay uno por hechizo,
	# y así rectificar es simplemente volver a dibujarlo.
	Sfx.play(self, "sello_ok")
	undo_history.append({"kind": "element", "previous": current_element,
		"previous_q": pages[page]["element_q"]})
	current_element = rune
	pages[page]["element_q"] = _calidad_elemento
	PlayLog.event("trazo", {"tipo": "elemento", "nombre": gesture_name,
		"calidad": snappedf(_calidad_elemento, 0.01)})
	print("Elemento: ", rune_database[rune].display_name)


## El nombre del gesto de un elemento (la clave de Repertoire) a partir
## de su tipo. Es GESTURE_TO_RUNE al revés; vacío si no está.
func _gesture_name_of(rune: Runes.Type) -> String:
	for gesture_name in GESTURE_TO_RUNE:
		if GESTURE_TO_RUNE[gesture_name] == rune:
			return gesture_name
	return ""


## Se dice en voz alta, con sonido de rechazo. Que una runa bloqueada no
## haga NADA sin avisar es el peor caso: el jugador creería que ha dibujado
## mal y seguiría intentándolo. Así sabe que es la runa, no su pulso.
func _refuse_locked(kind: String, gesture_name: String) -> void:
	Sfx.play(self, "sello_no")
	print("Aún no conoces ese ", kind, ": '", gesture_name, "'.")
	_feedback("Aún no conoces '%s'" % gesture_name)
	PlayLog.event("fallo", {"tipo": "bloqueado", "parece": gesture_name})


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
func add_sigil(sector: Vector2, sigil_name: String, calidad: float = 1.0) -> void:
	# LAS RUNAS INACTIVAS NO PASAN. Va aquí y no solo en el reconocedor
	# porque por esta función entran los dos caminos (el $P y la raya
	# recta), y una regla que se pueda esquivar por uno de los dos no es
	# una regla. Es la misma razón por la que vive aquí el filtro de eje.
	if not Repertoire.sigil_active(sigil_name):
		_refuse_locked("sello", sigil_name)
		return

	# Con el ratón apuntando, el sector ya no dice hacia dónde sale el hechizo,
	# así que "una flecha vuela plana" no tiene con qué comprobarse: la
	# restricción de eje solo existe cuando manda el sector.
	if not Repertoire.aim_with_mouse and not Sigils.allowed_on(sigil_name, sector):
		print("'", sigil_name, "' no vale hacia ahí: una flecha vuela plana.",
			" Prueba con levitación, barrera o pilar.")
		_feedback("'%s' no vale hacia ahí" % sigil_name)
		return

	# EL PRESUPUESTO DE SELLOS. Se comprueba después del eje a propósito: si
	# el sello no valía hacia ahí, ese es el motivo que hay que decir.
	var limite: int = Repertoire.max_sigils_per_page
	if limite > 0 and sigils_used() >= limite:
		Sfx.play(self, "sello_no")
		print("Ya has usado los ", limite, " sellos de esta página.",
			" Deshaz uno (clic derecho) si quieres cambiarlo.")
		_feedback("Página llena: %d sellos" % limite)
		return

	var component := _component_at(sector)
	component["sigils"].append(sigil_name)
	component["quality"].append(clampf(calidad, 0.0, 1.0))

	undo_history.append({"kind": "sigil", "direction": sector})
	print("Sello '", sigil_name, "' hacia ", sector,
		"  ->  ", component["sigils"])


## --- PONER RUNAS DIRECTAMENTE (pruebas) ---
##
## Lo que hace el reconocedor al aceptar un trazo, sin el trazo. Lo usa la paleta de
## pruebas (rune_palette.gd). Pasa por los mismos filtros: runa activa, límite de
## sellos por página, deshacer.
func place_element(gesture_name: String) -> void:
	if not GESTURE_TO_RUNE.has(gesture_name):
		return
	if not Repertoire.element_active(gesture_name):
		_refuse_locked("elemento", gesture_name)
		return
	Sfx.play(self, "sello_ok")
	undo_history.append({"kind": "element", "previous": current_element,
		"previous_q": pages[page]["element_q"]})
	current_element = GESTURE_TO_RUNE[gesture_name]
	pages[page]["element_q"] = 1.0
	print("Elemento (paleta): ", gesture_name)


## Todos los glifos puestos así van al mismo sector (la derecha): con el ratón
## apuntando el sector solo es un hueco, y sin él una flecha plana vale ahí.
func place_sigil(sigil_name: String) -> void:
	add_sigil(Vector2.RIGHT, sigil_name, 1.0)


## Cuántos sellos lleva la PÁGINA ACTIVA en total, sumando todos los
## sectores. Lo usa el libro para enseñar el contador.
func sigils_used() -> int:
	var total: int = 0
	for component in current_components:
		total += component["sigils"].size()
	return total


## Busca el componente de ese sector, o lo crea si es el primero que
## cae ahí. Los sellos del mismo sector modifican el mismo componente;
## los de sectores distintos son componentes independientes.
func _component_at(sector: Vector2) -> Dictionary:
	for component in current_components:
		if component["direction"].is_equal_approx(sector):
			return component

	var created := {"direction": sector, "sigils": [], "quality": []}
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
			pages[page]["element_q"] = last.get("previous_q", 1.0)
			print("Deshecho el elemento.")
		"sigil":
			# Se quita el último sello de SU sector, no el último
			# componente: si tenías dos sellos apilados ahí, deshacer
			# debe quitar uno, no el montón entero.
			var component := _component_at(last["direction"])
			component["sigils"].pop_back()
			if not component["quality"].is_empty():
				component["quality"].pop_back()
			if component["sigils"].is_empty():
				current_components.erase(component)
			print("Deshecho un sello.")


## Vacía LA PÁGINA ACTIVA, no las tres. Borrar las otras dos por
## equivocación sería el peor error posible de esta pantalla: se pierde
## trabajo que el jugador no estaba ni mirando.
func clear_sequence() -> void:
	current_element = Runes.Type.NONE
	pages[page]["element_q"] = 1.0
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
	# Al cerrar el libro manda lo fijado al abrirlo; con 1/2/3 fuera del
	# libro (cast_page directo) manda el ratón en vivo.
	if Repertoire.aim_with_mouse and _aim_at_open != Vector2.ZERO:
		_aim_override = _aim_at_open
	cast_page(page)
	_aim_override = Vector2.ZERO


## La dirección con la que se lanza un componente: la de su sector, o la del
## ratón si el nivel lo pide (ver Repertoire.aim_with_mouse). Se pregunta al
## lanzar y no al dibujar, porque el ratón se mueve entre una cosa y otra.
func _cast_direction(sector: Vector2) -> Vector2:
	if not Repertoire.aim_with_mouse:
		return sector

	# Si se está lanzando al CERRAR EL LIBRO, manda la dirección que se
	# fijó al abrirlo (ver remember_aim), no el ratón de ahora.
	if _aim_override != Vector2.ZERO:
		return _aim_override

	return _live_aim()


## Hacia dónde apunta el ratón ahora mismo, desde el jugador.
func _live_aim() -> Vector2:
	var hacia: Vector2 = get_global_mouse_position() - global_position
	if hacia.length() >= 8.0:
		return hacia.normalized()

	# Con el cursor encima del jugador no hay dirección que sacar: se usa la
	# última hacia la que anduvo, y si no la conoce, la derecha.
	var ultima: Variant = get_parent().get("last_direction")
	if ultima is Vector2 and ultima != Vector2.ZERO:
		return ultima
	return Vector2.RIGHT


## LA DIRECCIÓN SE FIJA AL ABRIR EL LIBRO.
##
## Al cerrar con T el cursor sigue encima del libro, así que leerlo entonces
## daría una dirección cualquiera. Como con el libro abierto el tiempo está
## parado, hacia donde apuntabas al abrirlo sigue siendo el sitio correcto al
## cerrarlo: apuntas, abres, dibujas, cierras y sale. Lo llama el libro.
var _aim_at_open: Vector2 = Vector2.ZERO
var _aim_override: Vector2 = Vector2.ZERO

func remember_aim() -> void:
	_aim_at_open = _live_aim()


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

	# RED DE SEGURIDAD: lo que se lanza también se filtra. Una página puede
	# haberse rellenado cuando la runa estaba activa y luego perderse (un
	# nivel que retira runas); lo que no está activo no sale, la hayas
	# dibujado cuando la hayas dibujado.
	if not Repertoire.element_active(_gesture_name_of(ficha["element"])):
		print("La página ", indice + 1, " lleva un elemento que ya no está activo.")
		return

	if componentes.is_empty():
		print("A la página ", indice + 1,
			" le falta hacia dónde: dibuja un trazo en algún sector.")
		_feedback("A la página %d le falta hacia dónde" % (indice + 1))
		return

	# RECARGA: una página recién lanzada no vuelve a salir hasta que se enfríe.
	if cooldown_left[indice] > 0.0:
		print("La página ", indice + 1, " se está recargando (", "%.1f" % cooldown_left[indice], " s).")
		Sfx.play(self, "sello_no")
		PlayLog.event("cast_bloqueado", {"pagina": indice + 1,
			"queda": snappedf(cooldown_left[indice], 0.1)})
		return

	# Cada componente arma su receta con los sellos que le cayeron
	# encima, y la receta terminada decide qué sale. Aquí no hay ni una
	# sola combinación escrita: todas emergen de leer juntos los pocos
	# parámetros que los sellos dejaron puestos.
	var lanzados: int = 0
	var recarga: float = 0.0
	var calidad_pagina: float = 1.0
	var glifos_log: Array = []

	# CON EL RATÓN APUNTANDO, LOS GLIFOS DE UNA PÁGINA SE COMBINAN ENTEROS. El
	# sector solo es un hueco donde dibujar: ya no dice hacia dónde sale, así que
	# no tiene por qué separar los glifos. Flecha en un sector y barrera en otro
	# son UN hechizo (una barrera que avanza), no una flecha y una barrera sueltas.
	var a_lanzar: Array = componentes
	if Repertoire.aim_with_mouse and componentes.size() > 1:
		var fusion: Dictionary = {"direction": componentes[0]["direction"],
			"sigils": [], "quality": []}
		for c in componentes:
			fusion["sigils"].append_array(c["sigils"])
			fusion["quality"].append_array(c.get("quality", []))
		a_lanzar = [fusion]

	for component in a_lanzar:
		var bloqueado: bool = false
		for sigil_name in component["sigils"]:
			if not Repertoire.sigil_active(sigil_name):
				bloqueado = true
		if bloqueado:
			print("Un componente lleva un sello que ya no está activo: no se lanza.")
			continue

		# La calidad del hechizo es la del PEOR trazo que lo compone (el elemento
		# cuenta): un trazo flojo en cualquier parte lo deja flojo.
		var calidad: float = ficha.get("element_q", 1.0)
		for q in component.get("quality", []):
			calidad = minf(calidad, q)

		var recipe := SpellRecipe.new(_cast_direction(component["direction"]))
		for sigil_name in component["sigils"]:
			recipe.apply(sigil_name)
		recipe.calidad = calidad
		recipe.build(self, element_data)

		lanzados += 1
		recarga = maxf(recarga, recipe.cooldown)
		calidad_pagina = minf(calidad_pagina, calidad)
		glifos_log.append(component["sigils"].duplicate())

	if lanzados == 0:
		return

	cooldown_total[indice] = recarga
	cooldown_left[indice] = recarga

	_set_tipo_cast(glifos_log)
	_play_cast_animation()

	print("¡Hechizo lanzado! (página ", indice + 1, ") ",
		element_data.display_name, " x", componentes.size(), " componentes")

	PlayLog.event("cast", {"pagina": indice + 1,
		"elemento": _gesture_name_of(ficha["element"]),
		"glifos": glifos_log,
		"calidad": snappedf(calidad_pagina, 0.01),
		"recarga": recarga})


## "He lanzado un hechizo" es un SUCESO: no se puede deducir mirando la
## posición de nadie, así que hay que avisar. Es el único de los cinco
## clips que necesita esto — andar y respirar se observan, y el golpe y
## la muerte llegan por la señal de vida.
##
## Se busca el animador en vez de guardarlo: así el Spellcaster funciona
## igual en un actor que no tenga animación, sin comprobaciones ni
## configuración. Si no hay, no pasa nada.
## Qué gesto hace el héroe según lo que lanza (lo lee player.gd en la meta "tipo_cast"):
##   lateral ...... algo que viaja a casillas lejanas (flecha, muro que avanza)
##   envolvente ... barrera, pulso, levitación, atracción: rodean a quien lanza
##   estatico ..... solo el elemento, o pilar / retardo: no viaja ni envuelve
func _set_tipo_cast(glifos_log: Array) -> void:
	var todos: Array = []
	for lista in glifos_log:
		todos.append_array(lista)
	var tipo: String = "estatico"
	if todos.has("flecha"):
		tipo = "lateral"
	elif todos.has("barrera") or todos.has("pulso") or todos.has("levitacion") or todos.has("atraccion"):
		tipo = "envolvente"
	var padre: Node = get_parent()
	if padre != null:
		padre.set_meta("tipo_cast", tipo)


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
		strokes, gesture_library.templates_for(GestureLibrary.ELEMENTS),
		Repertoire.active_elements())

	_parecido = result.get("name", "")
	_calidad_elemento = result.get("quality", 1.0)

	# Quedarse sin plantillas NO es fallar la puntería, y decir "no te he
	# entendido" cuando el problema es que la biblioteca está a medias
	# manda a buscar por el sitio equivocado.
	if result.get("needs_more_samples", false):
		_parecido = ""
		_warn_missing_templates()
		return Runes.Type.NONE

	print("[$P] ", result["name"], " vs ", result["second_name"],
		"  parecido ", "%.2f" % result["score"],
		"  margen ", "%.0f%%" % (100.0 * minf(result["margin"], 9.99)),
		"" if result["accepted"] else "  -> RECHAZADO")

	if not result["accepted"]:
		PlayLog.event("fallo", {"tipo": "elemento", "parece": result["name"],
			"rival": result["second_name"], "margen": snappedf(result["margin"], 0.01)})
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
