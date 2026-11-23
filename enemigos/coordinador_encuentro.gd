class_name CoordinadorEncuentro
extends RefCounted

## G2 de docs/PLAN_COMBATE_2026-11-22.md (22/11, lista de mejoras aprobada por Pablo): COORDINAR LOS ENCUENTROS. Dueño: Juego.
##
## Reparte FICHAS DE ATAQUE: como mucho MAX_ATACANTES enemigos pueden estar preparando o dando un ataque peligroso a la vez (cargando, `_carga` > 0, o con el golpe en
## camino, `_golpe_pendiente`). Quien no tiene ficha NO se queda quieto: se RECOLOCA (`Combate3D._recolocar`): rodea a la jugadora buscando otro ángulo, se pone entre
## ella y el chamán para protegerlo o, si es arquero, se mueve de lado buscando otra línea. La ficha se suelta en cuanto deja de cargar o de atacar (`Combate3D._physics_process`),
## así que van rotando: el que acaba de atacar descansa y entra otro.
## Entran los goblins de cuerpo a cuerpo y los arqueros que se mueven. No entran: el elemental (jefe), los canouros (tienen sus propios turnos, CanouroV2), los arqueros
## de puesto (son torretas), ni el gólem, el limo o el chamán (otra IA).
## Es global por nivel (todos los que pelean contra ella a la vez forman el encuentro); el vigía sigue diciendo cuándo empieza y acaba.

static var ACTIVO: bool = true
static var MAX_ATACANTES: int = 2
const T_CADUCA: float = 8.0                 ## s: una ficha que nadie soltó (un enemigo que se quedó colgado) caduca sola

static var _fichas: Dictionary = {}         ## instance_id -> {"nodo": WeakRef, "desde": ms}
static var pico: int = 0                    ## lo más que ha habido a la vez (pruebas)
static var negadas: int = 0                 ## veces que se negó una ficha (pruebas)


## ¿Puede `c` empezar (o seguir) su ataque? Si ya tiene ficha, sí; si queda hueco, se la da; si no, no.
static func puede(c: Object) -> bool:
	if not ACTIVO or c == null:
		return true
	_limpiar()
	var id: int = c.get_instance_id()
	if _fichas.has(id):
		return true
	if _fichas.size() >= MAX_ATACANTES:
		negadas += 1
		return false
	_fichas[id] = {"nodo": weakref(c), "desde": Time.get_ticks_msec()}
	pico = maxi(pico, _fichas.size())
	return true


static func tiene(c: Object) -> bool:
	return c != null and _fichas.has(c.get_instance_id())


static func soltar(c: Object) -> void:
	if c != null:
		_fichas.erase(c.get_instance_id())


static func atacantes() -> int:
	_limpiar()
	return _fichas.size()


static func reiniciar() -> void:
	_fichas.clear()
	pico = 0
	negadas = 0


static func _limpiar() -> void:
	var ahora: int = Time.get_ticks_msec()
	for id in _fichas.keys():
		var f: Dictionary = _fichas[id]
		var n: Variant = (f["nodo"] as WeakRef).get_ref()
		if n == null or not is_instance_valid(n) or bool((n as Object).get("muerto")) or float(ahora - int(f["desde"])) / 1000.0 > T_CADUCA:
			_fichas.erase(id)
