## EstadosSuelo3D · qué le pasa a cada casilla del suelo (hielo, electricidad, fuego, mojado). Datos puros, sin nodos (M2, 13/10).
##
## Por qué: hoy «¿está helada esta casilla?» lo guarda la maqueta del Pipeline (`_helada`) y el Juego se lo pregunta con
## `mundo.get("_helada")` (8 sitios). Un dato, un dueño (ARQUITECTURA_MODULAR §5.1): el dueño es esta clase, y quien dibuje
## (la maqueta, el agua) pregunta aquí o escucha `Mundo3D.casilla_cambio`; no guarda su propia copia.
##
## Qué NO hace (todavía): las textura de estado (`_img_estado`, con su caducidad de quemado/mojado) sigue siendo de la maqueta;
## es dibujo. Esta clase guarda el HECHO (la casilla está helada), no su aspecto.
class_name EstadosSuelo3D
extends RefCounted

## Los estados que existen. Una casilla puede tener varios a la vez (mojada y electrificada, por ejemplo).
const HELADA: String = "helada"
const ELECTRIFICADA: String = "electrificada"
const QUEMADA: String = "quemada"
const MOJADA: String = "mojada"
const TODOS: PackedStringArray = ["helada", "electrificada", "quemada", "mojada"]

## Cómo se llama cada estado en `Mundo3D.casilla_cambio(c, que)`, que habla de lo que pasó, no de cómo queda la casilla.
const QUE: Dictionary = {"helada": "hielo", "electrificada": "rayo", "quemada": "fuego", "mojada": "mojado"}

## Se emite SOLO cuando el estado cambia de verdad (poner lo que ya hay no avisa a nadie).
signal cambio(c: Vector2i, estado: String, si: bool)

var _celdas: Dictionary = {}          ## estado -> Dictionary(Vector2i -> true)


func tiene(c: Vector2i, estado: String) -> bool:
	return (_celdas.get(estado, {}) as Dictionary).has(c)


## Pone o quita un estado. Devuelve true si algo cambió.
func poner(c: Vector2i, estado: String, si: bool) -> bool:
	if not TODOS.has(estado):
		push_warning("EstadosSuelo3D: estado desconocido «%s»" % estado)
		return false
	var d: Dictionary = _celdas.get(estado, {})
	if si == d.has(c):
		return false
	if si:
		d[c] = true
	else:
		d.erase(c)
	_celdas[estado] = d
	cambio.emit(c, estado, si)
	return true


## Las casillas con ese estado (copia: se puede recorrer mientras cambian).
func celdas(estado: String) -> Array:
	return (_celdas.get(estado, {}) as Dictionary).keys()


func cuantas(estado: String) -> int:
	return (_celdas.get(estado, {}) as Dictionary).size()


## Empieza de cero (cambio de nivel). No emite `cambio`: quien recarga el nivel se redibuja entero.
func limpiar() -> void:
	_celdas.clear()
