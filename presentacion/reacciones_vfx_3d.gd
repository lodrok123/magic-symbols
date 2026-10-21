class_name ReaccionesVfx3D
extends RefCounted
## TABLA REACCIÓN → EFECTO + SONIDO (PL2 de PLAN_EOW, Pipeline, 21/10). Cuando la lógica del juego avisa de una reacción por su NOMBRE
## (`Mundo3D.reaccion(nombre, punto, nodo)`, tarea A4 del Juego), esta tabla decide qué se ve (`VfxReaccion3D`) y qué suena (`Sfx`).
##
## POR QUÉ UNA TABLA. Es la separación de EoW: la lógica emite una señal y una tabla aparte decide el efecto. El Juego no sabe qué partículas salen
## ni qué sonido suena; el Pipeline cambia un efecto o un sonido tocando UNA fila, sin tocar `Reactivo3D` ni `Combate3D`. Y al Pipeline le da un
## catálogo cerrado de cosas que producir (12 nombres, no «un efecto por cada sitio donde pasa algo»).
##
## PLANTILLA COMÚN + EXCEPCIONES. `TABLA` dice lo que pasa por defecto con cada reacción. `EXCEPCIONES[tipo][reaccion]` sobrescribe SOLO los campos que
## cambian para ese tipo de cosa (un goblin que arde deja llamas colgando; un seto que arde ya tiene su `PiezaFuego3D`, así que solo da un fogonazo).
## El `tipo` sale del propio nodo: la propiedad o meta `tipo` si la tiene (Reactivo3D lo tiene), «goblin» si es un enemigo (tiene `quemando`).
##
## NOMBRES. Son los del catálogo cerrado de A4 en `docs/PLAN_EOW.md`: prendido, apagado_agua, apagado_viento, consumido, mojado, secado, congelado,
## derretido, electrocutado, hundido, aturdido, empujado. Más UNO PROPUESTO que A4 no trae y el escudo necesita: `bloqueado` (algo choca contra algo que
## lo detiene). Un nombre que no esté en la tabla no hace nada (ni error): el Juego puede estrenar reacciones antes de que haya efecto.
##
## ENGANCHE (cuando el Juego cierre A4): `ReaccionesVfx3D.conectar(mundo, padre_fx)` se engancha a la señal `reaccion(nombre, punto, nodo)` de `Mundo3D`
## SI EXISTE (devuelve false si no: hoy no existe y no pasa nada). Sin esa señal, o para probar, se llama directamente `reproducir(...)`.
##
## Campos de cada fila: `vfx` (clave de EFECTOS; "" = sin dibujo), `sfx` (nombre de `Sfx.CATALOGO`; "" = mudo), `esc` (tamaño relativo del efecto),
## `bucle` (true: el sonido es un bucle que dura mientras arde; lo corta `apagar`), `tono` (>0 fija el tono del sonido).

## El catálogo cerrado, en el orden de A4 (+ `bloqueado`, propuesto).
const CATALOGO: Array = ["prendido", "apagado_agua", "apagado_viento", "consumido", "mojado", "secado", "congelado", "derretido",
	"electrocutado", "hundido", "aturdido", "empujado", "bloqueado"]

## Efectos que existen (clave → qué hace). Se usa para validar la tabla en la prueba: una fila no puede apuntar a un efecto que no esté aquí.
const EFECTOS: Array = ["llamarada", "llamas_cuerpo", "llamas_flecha", "apagar_vapor", "apagar_soplo", "ceniza", "mojar", "secar", "escarcha", "derretir",
	"descarga", "hundimiento", "estrellas", "empujon", "escudo_golpe", "escudo_roto", ""]

## PLANTILLA COMÚN (cualquier cosa).
const TABLA: Dictionary = {
	"prendido":       {"vfx": "llamarada",    "sfx": "prender",           "esc": 1.0},
	"apagado_agua":   {"vfx": "apagar_vapor", "sfx": "siseo_apagado",     "esc": 1.0},
	"apagado_viento": {"vfx": "apagar_soplo", "sfx": "empujado",          "esc": 1.0},
	"consumido":      {"vfx": "ceniza",       "sfx": "pira",              "esc": 1.0},
	"mojado":         {"vfx": "mojar",        "sfx": "chapoteo",          "esc": 1.0, "tono": 1.25},
	"secado":         {"vfx": "secar",        "sfx": "secado",            "esc": 1.0},
	"congelado":      {"vfx": "escarcha",     "sfx": "congelar",          "esc": 1.0},
	"derretido":      {"vfx": "derretir",     "sfx": "derretido",         "esc": 1.0},
	"electrocutado":  {"vfx": "descarga",     "sfx": "zumbido_electrico", "esc": 1.0},
	"hundido":        {"vfx": "hundimiento",  "sfx": "hundido_burbujas",  "esc": 1.0},
	"aturdido":       {"vfx": "estrellas",    "sfx": "aturdido",          "esc": 1.0},
	"empujado":       {"vfx": "empujon",      "sfx": "empujado",          "esc": 1.0},
	"bloqueado":      {"vfx": "escudo_golpe", "sfx": "escudo_golpe",      "esc": 1.0},
}

## EXCEPCIONES por tipo de cosa: solo los campos que cambian.
const EXCEPCIONES: Dictionary = {
	# El enemigo que arde se queda ardiendo (llamas colgando de él, con su sonido en bucle) hasta que algo lo apaga.
	"goblin": {
		"prendido": {"vfx": "llamas_cuerpo", "sfx": "arde_bucle", "bucle": true},
		"consumido": {"vfx": "ceniza", "sfx": ""},                 # al morir ya suena `muerte`/`goblin_muere` desde su propio código
		"hundido": {"esc": 1.0},
		"empujado": {"esc": 0.8},
	},
	# La flecha ardiendo: llama pequeña en la punta; al gastarse no deja ceniza.
	"flecha": {
		"prendido": {"vfx": "llamas_flecha", "sfx": "prender", "esc": 0.5},
		"apagado_agua": {"esc": 0.4},
		"consumido": {"vfx": "", "sfx": ""},
	},
	# El escudo del goblin (A5): arde con llamas pequeñas, se rompe al consumirse y suena a madera cuando algo lo golpea.
	"escudo": {
		"prendido": {"vfx": "llamas_cuerpo", "sfx": "arde_bucle", "bucle": true, "esc": 0.5},
		"consumido": {"vfx": "escudo_roto", "sfx": "escudo_roto"},
		"bloqueado": {"vfx": "escudo_golpe", "sfx": "escudo_golpe"},
	},
	# Las piezas de escenario que arden ya tienen su fuego propio (`PiezaFuego3D`/`ConsumoFuego3D`): aquí solo el fogonazo del instante y el sonido.
	"seto":    {"consumido": {"vfx": "", "sfx": ""}},               # el consumo lo dibuja ConsumoFuego3D (lo llama Reactivo3D._consumir)
	"tronco":  {"consumido": {"vfx": "", "sfx": ""}},
	"telarana": {"consumido": {"vfx": "", "sfx": ""}},
}

## Sonidos en bucle que están sonando por nodo (instancia → reproductor), para cortarlos al apagar.
static var _bucles: Dictionary = {}
static var _fx: Node3D = null


## La fila que toca para (`reaccion`, `tipo`): la plantilla con las excepciones del tipo encima. {} si la reacción no existe en la tabla.
static func resolver(reaccion: String, tipo: String = "") -> Dictionary:
	if not TABLA.has(reaccion):
		return {}
	var fila: Dictionary = (TABLA[reaccion] as Dictionary).duplicate()
	if EXCEPCIONES.has(tipo) and (EXCEPCIONES[tipo] as Dictionary).has(reaccion):
		fila.merge(EXCEPCIONES[tipo][reaccion], true)
	return fila


## El tipo de lo que reacciona: su propiedad o meta `tipo`; «goblin» si es un enemigo (tiene `quemando`); «» si no se sabe.
static func tipo_de(nodo: Object) -> String:
	if nodo == null:
		return ""
	if nodo.has_meta("tipo"):
		return String(nodo.get_meta("tipo"))
	var t: Variant = nodo.get("tipo")
	if t != null and String(t) != "":
		return String(t)
	if nodo.get("quemando") != null:
		return "goblin"
	return ""


## Se engancha a `Mundo3D.reaccion(nombre, punto, nodo)` SI la señal existe. Devuelve true si se enganchó. `padre_fx` = dónde cuelgan las partículas sueltas.
static func conectar(mundo: Object, padre_fx: Node3D) -> bool:
	if mundo == null or not mundo.has_signal("reaccion"):
		return false
	_fx = padre_fx
	var f := Callable(ReaccionesVfx3D, "_al_reaccionar")
	if not mundo.is_connected("reaccion", f):
		mundo.connect("reaccion", f)
	return true


static func _al_reaccionar(nombre: String, punto: Vector3, nodo: Node = null) -> void:
	reproducir(nombre, punto, nodo, _fx)


## Hace la reacción: dibuja el efecto y suena el sonido de la fila. Devuelve lo que ha resuelto ({vfx, sfx, tipo, ...}; {} si no hay fila), para pruebas
## y para quien quiera saber qué ha pasado. `padre_fx` es un Node3D del árbol donde colgar lo suelto; si falta, se usa el padre del nodo o el propio nodo.
static func reproducir(nombre: String, punto: Vector3, nodo: Node = null, padre_fx: Node3D = null) -> Dictionary:
	var tipo: String = tipo_de(nodo)
	var fila: Dictionary = resolver(nombre, tipo)
	if fila.is_empty():
		return {}
	fila["tipo"] = tipo
	var cuerpo: Node3D = nodo as Node3D
	var padre: Node3D = padre_fx
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		padre = (cuerpo.get_parent() as Node3D) if cuerpo != null and cuerpo.get_parent() is Node3D else cuerpo
	if padre == null or not padre.is_inside_tree():
		return fila                                                 # sin árbol no hay dónde dibujar ni sonar: se devuelve la fila y ya
	var esc: float = float(fila.get("esc", 1.0))
	if cuerpo != null and (nombre.begins_with("apagado") or nombre == "consumido"):
		_cortar_bucle(cuerpo)                                       # lo que ardía deja de crepitar
	var vfx: String = String(fila.get("vfx", ""))
	match vfx:
		"llamarada": VfxReaccion3D.llamarada(padre, punto, esc)
		"llamas_cuerpo": VfxReaccion3D.llamas_cuerpo(cuerpo, esc)
		"llamas_flecha": VfxReaccion3D.llamas_flecha(cuerpo)
		"apagar_vapor": VfxReaccion3D.apagar_vapor(padre, punto, cuerpo, esc)
		"apagar_soplo": VfxReaccion3D.apagar_soplo(padre, punto, cuerpo, esc)
		"ceniza": VfxReaccion3D.ceniza(padre, punto, esc)
		"mojar": VfxReaccion3D.mojar(padre, punto, esc)
		"secar": VfxReaccion3D.secar(padre, punto, esc)
		"escarcha": VfxReaccion3D.escarcha(padre, punto, esc)
		"derretir": VfxReaccion3D.derretir(padre, punto, esc)
		"descarga": VfxReaccion3D.descarga(padre, punto, esc)
		"hundimiento": VfxReaccion3D.hundimiento(padre, punto, esc)
		"estrellas": VfxReaccion3D.estrellas(padre, punto, esc)
		"empujon": VfxReaccion3D.empujon(padre, punto, Vector3.ZERO, esc)
		"escudo_golpe": VfxReaccion3D.escudo_golpe(padre, punto, Vector3.UP, esc)
		"escudo_roto": VfxReaccion3D.escudo_roto(padre, punto, false, esc)
	var sfx: String = String(fila.get("sfx", ""))
	if sfx != "":
		var origen: Node = cuerpo if cuerpo != null and cuerpo.is_inside_tree() else padre
		if bool(fila.get("bucle", false)) and cuerpo != null:
			if not _bucles.has(cuerpo.get_instance_id()):
				var p: Node = Sfx.bucle(origen, sfx, float(fila.get("tono", 1.0)))
				if p != null:
					_bucles[cuerpo.get_instance_id()] = p
					cuerpo.tree_exiting.connect(func() -> void: _cortar_bucle(cuerpo))   # si el nodo se libera ardiendo, el crepitar se va con él
		else:
			Sfx.play(origen, sfx, float(fila.get("tono", 0.0)))
	return fila


## Corta el sonido en bucle de `nodo` (si lo tenía).
static func _cortar_bucle(nodo: Object) -> void:
	if nodo == null:
		return
	var id: int = nodo.get_instance_id()
	if _bucles.has(id):
		Sfx.parar(_bucles[id] as Node, 0.25)
		_bucles.erase(id)


## ¿Tiene `nodo` un sonido en bucle sonando ahora mismo? (pruebas)
static func suena_bucle(nodo: Object) -> bool:
	return nodo != null and _bucles.has(nodo.get_instance_id()) and is_instance_valid(_bucles[nodo.get_instance_id()])
