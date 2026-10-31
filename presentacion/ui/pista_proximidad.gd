class_name PistaProximidad
extends Node

## EL DETECTOR DE LA PISTA «[E] Hablar» (gamefeel U6, 31/10). Un único camino para los cuatro sitios que escuchan la E (el guardabosques del Bosque, el de la escena de jugabilidad,
## los cofres y el alquimista del Bosque 01 y las plantas que se recogen): cada uno se apunta al grupo `GRUPO` y responde a `accion_pista() -> String`:
## la acción que ofrece AHORA a la jugadora («Hablar», «Abrir», «Recoger») o "" si no hay nada a mano. Cada uno usa su propio alcance de la E, así que la pista sale justo cuando la E responde.
## Este nodo (uno por partida, colgado de la raíz con su capa) mira el grupo cada fotograma: si alguien ofrece algo enseña la pista (`PistaInteraccion`), y si nadie ofrece (te alejas, ya
## interactuaste o hay una pausa) la esconde. Es INFORMACIÓN, no sensación: sale también con `Sensacion3D.ACTIVA = false`.
##     PistaProximidad.asegurar(get_tree())      # desde el _ready de quien tenga algo a mano (idempotente)
##     add_to_group(PistaProximidad.GRUPO)       # y ofrecer `func accion_pista() -> String`

const GRUPO: StringName = &"pista_e"
const TECLA: String = "E"
const CAPA: int = 8

static var _gestor: PistaProximidad = null

var _pista: PistaInteraccion = null
var _accion: String = ""                          ## lo que se está enseñando ahora ("" = nada)


## Monta el gestor si aún no existe (varios llamadores, uno solo). Vale llamarlo desde un `_ready`: se cuelga de la raíz sin esperar.
static func asegurar(arbol: SceneTree) -> void:
	if arbol == null or arbol.root == null:
		return
	if _gestor != null and is_instance_valid(_gestor):
		return
	_gestor = PistaProximidad.new()
	_gestor.name = "PistaProximidad"
	_gestor.process_mode = Node.PROCESS_MODE_ALWAYS
	arbol.root.add_child.call_deferred(_gestor)


## Quita el gestor (las pruebas montan escenas sueltas y no quieren que el de la anterior sobreviva).
static func reiniciar() -> void:
	if _gestor != null and is_instance_valid(_gestor):
		_gestor.free()
	_gestor = null


## Lo que enseña la pista ahora mismo ("" = escondida). Para las pruebas.
static func accion_actual() -> String:
	return _gestor._accion if _gestor != null and is_instance_valid(_gestor) else ""


## El nodo de la pista (para las pruebas). null si aún no se montó.
static func pista() -> PistaInteraccion:
	return _gestor._pista if _gestor != null and is_instance_valid(_gestor) else null


## Distancia en el suelo (ignora la altura), como la miden todas las E del proyecto.
static func dist_plana(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _ready() -> void:
	var capa := CanvasLayer.new()
	capa.layer = CAPA
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	_pista = PistaInteraccion.new()
	capa.add_child(_pista)


func _process(_delta: float) -> void:
	var quiere: String = ""
	if not get_tree().paused:
		for n in get_tree().get_nodes_in_group(GRUPO):
			if is_instance_valid(n) and n.has_method("accion_pista"):
				quiere = String(n.call("accion_pista"))
				if quiere != "":
					break
	if quiere == _accion:
		return
	_accion = quiere
	if _accion != "":
		_pista.mostrar(TECLA, _accion)
	else:
		_pista.ocultar()
