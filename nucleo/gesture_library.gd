class_name GestureLibrary
extends Resource

## La biblioteca de gestos: qué formas conoce el juego y cómo son.
##
## Igual que un elemento es un RuneData y no código, un gesto es un dato
## y no una heurística. Añadir una forma nueva es DIBUJARLA desde el
## modo de grabación del grimorio, no escribir una función que la
## detecte. Ese es todo el sentido de haber traído el $1.
##
## Cada gesto guarda VARIAS muestras a propósito: el mismo trazo sale
## distinto rápido que despacio, grande que pequeño. Con una sola
## muestra el reconocedor es frágil; con cuatro, sólido.

## Los gestos están separados en dos familias, y esa separación es lo
## que evita que se estorben: un elemento se dibuja en el NÚCLEO y un
## sello en un SECTOR, así que al reconocer solo se compara contra la
## familia que corresponde. Sin esto, añadir sellos degradaría el
## reconocimiento de los elementos, porque cada gesto nuevo es un
## competidor más para todos los demás.
## Los nombres son los del ELEMENTO, no los de la forma. Antes se
## llamaban "circulo" o "triangulo", y eso ataba el vocabulario al
## dibujo: cambiar el gesto del fuego obligaba a renombrarlo en cuatro
## archivos. Ahora la forma es solo el dato grabado, y el nombre dice lo
## único que no cambia — qué elemento es.
const ELEMENTS: PackedStringArray = [
	"fuego",    # P
	"agua",     # onda ~
	"tierra",   # triángulo abierto por abajo
	"rayo",     # zigzag
	"hielo",    # copo / asterisco
	"viento",   # 2-3 líneas horizontales
]

## Los sellos modifican un componente: dicen DÓNDE y CUÁNTO, nunca QUÉ.
##
## Estos cuatro midieron 100% de acierto entre ellos. Por eso la familia
## se respeta a rajatabla: un gesto que se parezca a otro debe caer al
## otro lado de la división elemento/función, porque los dos lados nunca
## se comparan entre sí.
##
## "levitacion" vuelve, ahora que SÍ hace algo: aporta permanencia y
## altura, que es lo que saca al juego de "disparar en todas
## direcciones". Medido contra los demás sellos da 99,6% de acierto y
## cero confusiones con pilar — que era la duda, porque los dos son un
## palo vertical. No se parecen porque el $P no normaliza el giro: uno
## lleva la barra abajo y el otro la punta arriba.
const SIGILS: PackedStringArray = [
	"flecha",      # flecha apuntando a la derecha
	"barrera",     # círculo cerrado
	"levitacion",  # flecha hacia arriba
	"repeticion",  # dos triángulos: multiplica lo que haya en su sector
	"amplificar",  # multiplica el daño y sube la intensidad del efecto
	"rebote",      # NUEVO: una V que toca el suelo y sube
	"retardo",     # NUEVO: reloj de arena
	"pulso",       # NUEVO: aros que se abren
	"atraccion",   # NUEVO: puntas que convergen
	"espejo",      # NUEVO: eje con dos puntas hacia fuera
	"permanencia", # ᛉ algiz (19/10, Pablo): lo que sale se queda más tiempo. Hasta que Pablo grabe sus muestras con G no se reconoce
	"linea",       # raya (ᛁ isa): con un elemento es un RAYO («haz», 21/10, Pablo); el muro es solo de `barrera`
	"altura",      # ⊥: estira la forma hacia arriba (fase 8)
]

## El orden en que las teclas 1..9 los seleccionan al grabar. Primero
## los elementos, luego los sellos: es el mismo orden en que aparecen
## arriba, para que el número de la tecla no se aprenda dos veces.
const RECORDABLE: PackedStringArray = [
	"fuego", "agua", "tierra", "rayo", "hielo", "viento",          # 20/10: «tiempo» ya no se graba ni se reconoce (es cinemática, ver BIBLIA)
	"flecha", "barrera", "levitacion", "repeticion", "amplificar",
	"rebote", "retardo", "pulso", "atraccion", "espejo",
	# 16/10 (biblia de runas de Pablo): también se graban los que aún no lanzan nada, para tenerlos listos (assets, enemigos, señuelos).
	"linea", "veneno", "naturaleza", "sombra", "luz", "thurisaz", "ansuz", "raido", "permanencia", "berkana",
]

## --- BIBLIA DE RUNAS (16/10, lámina de Pablo: 24 runas del futhark antiguo) ---
## Qué runa es cada nombre y para qué sirve. Es DATO, no reconocimiento: el reconocedor sigue usando las muestras grabadas; esta tabla
## dice cómo se llama cada forma, qué futhark es (para assets, carteles, el libro) y si hoy desemboca en algo.
##   uso: "cinematico" (20/10: la runa del tiempo; solo eventos de nivel o de guion, el jugador no la traza ni se reconoce; no está en ELEMENTS) · "elemento" (núcleo) · "sello" (sector) · "enemigos" (la usan ellos, el jugador no la traza) · "asset" (decora: aún sin
##        hechizo) · "libre" (sin asignar: puede usarse más adelante).
## No todas las de `uso` sello/elemento están ya en el juego con esa forma: Pablo regraba las plantillas con G. Las de uso "asset" y
## "libre" no están en ELEMENTS ni SIGILS, así que aunque se graben no compiten en el reconocimiento.
const BIBLIA: Dictionary = {
	"repeticion": {"futhark": "ᚠ", "nombre_runa": "fehu", "uso": "sello"},
	"rebote":     {"futhark": "ᚢ", "nombre_runa": "uruz", "uso": "sello"},
	"thurisaz":   {"futhark": "ᚦ", "nombre_runa": "thurisaz", "uso": "libre"},
	"ansuz":      {"futhark": "ᚨ", "nombre_runa": "ansuz", "uso": "libre"},
	"raido":      {"futhark": "ᚱ", "nombre_runa": "raido", "uso": "libre"},
	"fuego":      {"futhark": "ᚲ", "nombre_runa": "kenaz", "uso": "elemento"},
	"pulso":      {"futhark": "ᚷ", "nombre_runa": "gebo", "uso": "sello"},
	"veneno":     {"futhark": "ᚹ", "nombre_runa": "wunjo", "uso": "enemigos"},
	"hielo":      {"futhark": "ᚺ", "nombre_runa": "hagalaz", "uso": "elemento"},
	"linea":      {"futhark": "ᛁ", "nombre_runa": "isa", "uso": "sello"},
	"naturaleza": {"futhark": "ᛃ", "nombre_runa": "jera", "uso": "asset"},
	"flecha":     {"futhark": "ᛇ", "nombre_runa": "eihwaz", "uso": "sello"},
	"sombra":     {"futhark": "ᛈ", "nombre_runa": "perthro", "uso": "asset"},
	"permanencia": {"futhark": "ᛉ", "nombre_runa": "algiz", "uso": "sello"},       # antes «algiz», libre (ESPEC_HECHIZO §3, decidido el 19/10)
	"rayo":       {"futhark": "ᛊ", "nombre_runa": "sowilo", "uso": "elemento"},
	"levitacion": {"futhark": "ᛏ", "nombre_runa": "tiwaz", "uso": "sello"},
	"berkana":    {"futhark": "ᛒ", "nombre_runa": "berkana", "uso": "libre"},
	"tierra":     {"futhark": "ᛗ", "nombre_runa": "mannaz", "uso": "elemento"},
	"viento":     {"futhark": "ᚢ", "nombre_runa": "uruz (variante de lados rectos, lámina aparte)", "uso": "elemento"},
	"agua":       {"futhark": "ᛚ", "nombre_runa": "laguz", "uso": "elemento"},
	"barrera":    {"futhark": "ᛜ", "nombre_runa": "ingwaz", "uso": "sello"},
	"tiempo":     {"futhark": "ᛟ", "nombre_runa": "othala", "uso": "cinematico"},
	"luz":        {"futhark": "ᛞ", "nombre_runa": "dagaz", "uso": "asset"},
}


## --- GIRO DE LOS GLIFOS EN LOS SECTORES (16/10, Pablo: «los glifos detectados siempre rótalos hacia el centro») ---
## Un glifo trazado o pintado en un sector va girado de modo que su "arriba" APUNTA AL CENTRO del círculo: en el sector este queda
## tumbado mirando al oeste, en el norte boca abajo, y así. Es una sola convención para las tres cosas que giran: lo que el jugador
## dibuja (el reconocedor lo desgira con −giro antes de comparar con la plantilla derecha), la guía fantasma (la plantilla girada
## con +giro) y el sello pintado en el hueco. Devuelve el ángulo (rad) que hay que aplicar a un glifo derecho para colocarlo así.
## Para el núcleo (sector cero) es 0: los elementos van derechos.
static func giro_glifo(sector: Vector2) -> float:
	if sector.length_squared() < 0.0001:
		return 0.0
	# "Arriba" en pantalla es (0, −1), ángulo −π/2. Para que apunte hacia −sector hay que girar (ángulo de −sector) − (−π/2).
	return (-sector).angle() + PI * 0.5

## nombre -> Array de nubes ya normalizadas (PackedVector2Array). Se
## guardan normalizadas porque una plantilla no es más que un gesto que
## ya pasó por GestureRecognizer.normalize().
@export var templates: Dictionary = {}

## nombre -> con CUÁNTOS TRAZOS se dibuja el gesto (el máximo de sus muestras). Lo apunta el grimorio al grabar (16/10, trazo
## recto): con él sabe si un gesto puede darse por cerrado al soltar el ratón sin esperar la pausa (ningún gesto activo de la
## familia necesita más trazos de los ya dibujados). Un gesto sin dato aquí (grabado antes) desactiva el cierre inmediato en su
## familia: mejor esperar que cerrar de más.
@export var trazos: Dictionary = {}

## --- Acceso compartido ---
## Antes esto se hacía con `preload`, y tenía un problema serio: un
## preload cuyo archivo no existe es un ERROR DE COMPILACIÓN. Borrar el
## .tres para empezar de cero dejaba el juego sin arrancar siquiera.
##
## Ahora se carga en tiempo de ejecución y, si el archivo no está, se
## empieza con una biblioteca vacía que se creará sola al grabar la
## primera muestra. Borrar el archivo pasa a ser una forma legítima de
## resetear, no una manera de romperlo todo.
##
## Es una única instancia compartida a propósito: el grimorio graba y el
## Spellcaster reconoce sobre la MISMA, así que una muestra recién
## grabada se puede usar al instante sin reiniciar.
const PATH: String = "res://nucleo/gesture_library.tres"

static var _shared: GestureLibrary = null


static func get_shared() -> GestureLibrary:
	if _shared == null:
		if ResourceLoader.exists(PATH):
			_shared = load(PATH)
		if _shared == null:
			_shared = GestureLibrary.new()
	return _shared


func save() -> void:
	var error := ResourceSaver.save(self, PATH)
	if error != OK:
		# Solo se puede escribir en res:// desde el editor. En un juego
		# exportado fallaría, y está bien: grabar gestos es una
		# herramienta de desarrollo, no una función del juego.
		print("No se pudo guardar la biblioteca de gestos (código ", error, ")")


## Solo las plantillas de una familia. Es lo que permite comparar un
## trazo del núcleo únicamente contra elementos.
func templates_for(names: PackedStringArray) -> Dictionary:
	var subset: Dictionary = {}
	for name in names:
		if templates.has(name):
			subset[name] = templates[name]
	return subset


func has_any(names: PackedStringArray) -> bool:
	for name in names:
		if templates.has(name) and not templates[name].is_empty():
			return true
	return false


func add_sample(gesture_name: String, normalized_points: PackedVector2Array, n_trazos: int = 0) -> void:
	if not templates.has(gesture_name):
		templates[gesture_name] = []
	templates[gesture_name].append(normalized_points)
	if n_trazos > 0:
		trazos[gesture_name] = maxi(int(trazos.get(gesture_name, 0)), n_trazos)


## El mayor número de trazos que necesita alguno de estos gestos, o -1 si a alguno le falta el dato (no se puede afirmar nada).
func trazos_max(names: PackedStringArray) -> int:
	var m: int = 0
	for name in names:
		if not templates.has(name):
			continue
		if not trazos.has(name):
			return -1
		m = maxi(m, int(trazos[name]))
	return m


func sample_count(gesture_name: String) -> int:
	if not templates.has(gesture_name):
		return 0
	return templates[gesture_name].size()


func clear_gesture(gesture_name: String) -> void:
	templates.erase(gesture_name)
	trazos.erase(gesture_name)


## Quita solo la última muestra. Es lo que más falta hace: casi nunca
## quieres empezar de cero, quieres deshacer el trazo que acaba de
## salirte torcido.
func remove_last_sample(gesture_name: String) -> void:
	if not templates.has(gesture_name):
		return

	templates[gesture_name].pop_back()
	if templates[gesture_name].is_empty():
		templates.erase(gesture_name)


func clear_all() -> void:
	templates.clear()
	trazos.clear()


## Si está vacía, quien reconozca debe recurrir al método antiguo. Es lo
## que permite grabar plantillas sin que el juego deje de funcionar
## mientras tanto.
func is_empty() -> bool:
	return templates.is_empty()
