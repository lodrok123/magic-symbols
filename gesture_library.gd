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
	"tiempo",   # X
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
	"pilar",       # ⊥
	"barrera",     # círculo cerrado
	"levitacion",  # flecha hacia arriba
	"repeticion",  # dos triángulos: multiplica lo que haya en su sector
	"amplificar",  # multiplica el daño y sube la intensidad del efecto
]

## El orden en que las teclas 1..9 los seleccionan al grabar. Primero
## los elementos, luego los sellos: es el mismo orden en que aparecen
## arriba, para que el número de la tecla no se aprenda dos veces.
const RECORDABLE: PackedStringArray = [
	"fuego", "agua", "tierra", "rayo", "hielo", "tiempo", "viento",
	"flecha", "pilar", "barrera", "levitacion", "repeticion", "amplificar",
]

## nombre -> Array de nubes ya normalizadas (PackedVector2Array). Se
## guardan normalizadas porque una plantilla no es más que un gesto que
## ya pasó por GestureRecognizer.normalize().
@export var templates: Dictionary = {}

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
const PATH: String = "res://gesture_library.tres"

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


func add_sample(gesture_name: String, normalized_points: PackedVector2Array) -> void:
	if not templates.has(gesture_name):
		templates[gesture_name] = []
	templates[gesture_name].append(normalized_points)


func sample_count(gesture_name: String) -> int:
	if not templates.has(gesture_name):
		return 0
	return templates[gesture_name].size()


func clear_gesture(gesture_name: String) -> void:
	templates.erase(gesture_name)


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


## Si está vacía, quien reconozca debe recurrir al método antiguo. Es lo
## que permite grabar plantillas sin que el juego deje de funcionar
## mientras tanto.
func is_empty() -> bool:
	return templates.is_empty()
