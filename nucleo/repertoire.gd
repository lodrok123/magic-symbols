class_name Repertoire
extends RefCounted

## LAS RUNAS ACTIVAS: lo que el jugador PUEDE usar ahora mismo.
##
## Hay dos listas, elementos y sellos, y una sola regla: lo que no está
## en ellas no se puede usar ni se ve. Ni se dibuja en la chuleta del
## libro, ni se acepta al reconocerlo, ni se lanza aunque una página lo
## lleve dentro.
##
## POR QUÉ ES UN ARCHIVO APARTE y no un `if` en cada sitio. Antes, retirar
## una runa (pilar, tiempo) era borrarle el glifo y esperar que nada más
## la mencionara: funcionaba por casualidad. Ahora es UN dato que decide
## tres cosas distintas —qué enseña el libro, qué acepta el Spellcaster y
## qué lanza una página— y ninguna de las tres sabe de las otras.
##
## Y ES LA BASE DE LA PROGRESIÓN. Desbloquear una runa es `unlock_element`
## o `unlock_sigil`, y bloquearla, lo contrario. Un nivel que enseña el
## agua en su segunda sala no necesita código nuevo: la llama al entrar.
##
## Los nombres son los de los gestos (los mismos de GestureLibrary y de
## Sigils): "fuego", "flecha"... Un nombre que no exista se avisa por
## consola en vez de ignorarse, porque una errata aquí no falla, deja
## una runa muerta sin decir por qué.

## El conjunto del micronivel (P0): 4 elementos x 2 sellos. Es también lo
## que hay activo si nadie toca nada, que es el alcance congelado del test.
const P0_ELEMENTS: PackedStringArray = ["fuego", "agua", "viento", "rayo"]
const P0_SIGILS: PackedStringArray = ["flecha", "barrera"]

static var _elements: PackedStringArray = PackedStringArray(["fuego", "agua", "viento", "rayo"])
static var _sigils: PackedStringArray = PackedStringArray(["flecha", "barrera"])


## CUÁNTOS SELLOS CABEN EN UNA PÁGINA (0 = sin límite).
##
## Es un tope de PRESUPUESTO, no de sectores: cuenta los sellos dibujados en
## total, estén en el mismo sector o en varios. Existe porque sin él la
## respuesta a cualquier problema es llenar el círculo de flechas, y eso no
## enseña nada del lenguaje. Con 2 hay que ELEGIR: dos flechas, flecha y
## barrera, o una sola y guardar el hueco.
##
## Empieza en 0 y lo fija cada nivel al arrancar (el blockout pone 2), para
## que el resto del juego siga como estaba.
static var max_sigils_per_page: int = 0


## CUÁNTAS PÁGINAS (libros) TIENES. 0 = todas las del Spellcaster. Lo fija cada nivel como `max_sigils_per_page`: el primero
## da una sola página, y las demás aparecen cuando la progresión las abre. Lo que no se tiene no se pinta en el libro ni se
## puede elegir o lanzar (Spellcaster.PAGES es el máximo posible, no lo que tienes).
static var max_pages: int = 0


## QUÉ LÁMINA DE LIBRO SE USA. "" = la de siempre (grimorio.png, doce casillas). «nivel1» = la del primer nivel, con el sello en el
## centro y tres huecos de glifo arriba (ver Spellbook.LIBROS). Lo fija la progresión; si la lámina no existe en disco, el libro
## cae a la de siempre sin romper nada.
static var libro: String = ""


## CAPACIDAD DEL LIBRO (27/10, Pablo): cuántos ELEMENTOS y cuántos GLIFOS distintos caben en la página derecha del libro que llevas.
## El primer libro de la historia admite 4 elementos y 6 glifos: se empieza con menos y se ganan jugando hasta llenarlo; más adelante
## llega un libro nuevo con más sitio. 0 = sin límite (los bancos de pruebas). Lo fija la progresión ANTES de `set_active`. Es un tope
## de lo que se CONOCE, no de lo que cabe en una página al lanzar (eso es `max_sigils_per_page`, los huecos del círculo).
static var max_elementos: int = 0
static var max_glifos: int = 0
static var _avisado_lleno: Dictionary = {}       ## "elementos" / "glifos" -> ya se avisó una vez de que el libro está lleno


static func pages_available(total: int) -> int:
	return total if max_pages <= 0 else clampi(max_pages, 1, total)


## HACIA DÓNDE SALE UN HECHIZO: ¿hacia el sector donde se dibujó, o hacia el
## ratón? Con true, todo hechizo que vaya en alguna dirección la toma del
## ratón en el momento de lanzarlo (desde el jugador hacia el cursor). El
## sector del libro deja de decir hacia dónde y pasa a ser solo un hueco
## donde poner el sello.
##
## Es contraintuitivo lo contrario: dibujas "flecha" en el sector de la
## izquierda y apuntas con el ratón a la derecha, y sale a la izquierda.
## Empieza en false y lo fija cada nivel, como el tope de sellos.
static var aim_with_mouse: bool = false


## --- Preguntas ---

static func element_active(gesture_name: String) -> bool:
	return _elements.has(gesture_name)


static func sigil_active(sigil_name: String) -> bool:
	return _sigils.has(sigil_name)


static func active_elements() -> PackedStringArray:
	return _elements.duplicate()


static func active_sigils() -> PackedStringArray:
	return _sigils.duplicate()


## --- Cambios ---

## Sustituye las dos listas de golpe. Es lo que llama un nivel al empezar.
static func set_active(elements: PackedStringArray, sigils: PackedStringArray) -> void:
	_elements = PackedStringArray()
	_sigils = PackedStringArray()
	for e in elements:
		unlock_element(e)
	for s in sigils:
		unlock_sigil(s)


## Devuelve true si ERA NUEVA, para que quien desbloquea pueda avisar al
## jugador solo la primera vez.
static func unlock_element(gesture_name: String) -> bool:
	if not GestureLibrary.ELEMENTS.has(gesture_name):
		push_warning("Repertoire: '%s' no es un elemento conocido." % gesture_name)
		return false
	if _elements.has(gesture_name):
		return false
	if max_elementos > 0 and _elements.size() >= max_elementos:
		_avisar_lleno("elementos", gesture_name, max_elementos)
		return false
	_elements.append(gesture_name)
	return true


static func unlock_sigil(sigil_name: String) -> bool:
	if not GestureLibrary.SIGILS.has(sigil_name):
		push_warning("Repertoire: '%s' no es un sello conocido." % sigil_name)
		return false
	if _sigils.has(sigil_name):
		return false
	if max_glifos > 0 and _sigils.size() >= max_glifos:
		_avisar_lleno("glifos", sigil_name, max_glifos)
		return false
	_sigils.append(sigil_name)
	return true


## ¿Cabe uno más? (para quien quiera avisar al jugador antes de dar algo).
static func cabe_elemento() -> bool:
	return max_elementos <= 0 or _elements.size() < max_elementos


static func cabe_glifo() -> bool:
	return max_glifos <= 0 or _sigils.size() < max_glifos


## Un nivel que da más de lo que cabe está mal diseñado para este libro: se dice UNA vez por consola (no se calla, como una errata).
static func _avisar_lleno(que: String, nombre: String, tope: int) -> void:
	if _avisado_lleno.has(que):
		return
	_avisado_lleno[que] = true
	push_warning("Repertoire: el libro está lleno (%d %s); '%s' no entra." % [tope, que, nombre])


## Fija la capacidad del libro (0 = sin límite) y olvida los avisos de libro lleno. Lo llama la progresión antes de `set_active`.
static func fijar_capacidad(elementos: int, glifos: int) -> void:
	max_elementos = maxi(elementos, 0)
	max_glifos = maxi(glifos, 0)
	_avisado_lleno.clear()


## GLIFOS POR ESCRIBIR EN EL LIBRO (24/10, Pablo): un glifo que se CONSIGUE jugando (cofre, tienda, NPC) se anota aquí, y la próxima vez que
## el libro está abierto se ESCRIBE en su casilla de la página derecha (Spellbook), que así recuerda lo que has ido consiguiendo. Lo que
## activa un nivel al empezar o una partida cargada (`set_active`, `unlock_sigil` a secas) no se anota: ya estaba ahí.
static var _por_escribir: PackedStringArray = PackedStringArray()


## Desbloquea y, si era nuevo, lo deja pendiente de escribirse en el libro. Devuelve true si ERA NUEVO (como `unlock_sigil`).
static func conseguir_sigil(sigil_name: String) -> bool:
	var nuevo: bool = unlock_sigil(sigil_name)
	if nuevo and not _por_escribir.has(sigil_name):
		_por_escribir.append(sigil_name)
	return nuevo


## Lo que el libro tiene por escribir, y lo vacía (lo llama Spellbook al abrirse). Lo que ya no está activo (un nivel nuevo lo quitó) se descarta.
static func tomar_por_escribir() -> PackedStringArray:
	var lista := PackedStringArray()
	for s in _por_escribir:
		if _sigils.has(s):
			lista.append(s)
	_por_escribir = PackedStringArray()
	return lista


static func lock_element(gesture_name: String) -> void:
	var i: int = _elements.find(gesture_name)
	if i >= 0:
		_elements.remove_at(i)


static func lock_sigil(sigil_name: String) -> void:
	var i: int = _sigils.find(sigil_name)
	if i >= 0:
		_sigils.remove_at(i)


## Todo lo que existe, incluidas las runas retiradas del test. Solo para
## probar: no es el juego del micronivel. Quita la capacidad del libro (si no, la paleta de pruebas se quedaría en 4 y 6).
static func activate_all() -> void:
	fijar_capacidad(0, 0)
	set_active(GestureLibrary.ELEMENTS, GestureLibrary.SIGILS)


static func reset_to_p0() -> void:
	set_active(P0_ELEMENTS, P0_SIGILS)
