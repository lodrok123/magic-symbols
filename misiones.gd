class_name Misiones
extends Node

## LOS ENCARGOS de los guardabosques. Cada guardabosques ofrece uno; al aceptarlo (cerrando
## su diálogo) pasa a "activa", al cumplirse pasa a "lista" y al volver a hablar con él se
## cobra la recompensa (100 de oro) y queda "hecha".
##
## Tipos:
##   matar   N goblins que mueran cerca de un punto
##   quemar  N objetos que empiecen a arder
##   apagar  apagar una fogata concreta (se vuelve a encender al aceptar el encargo)
##
## Esta clase no sabe nada del nivel: el nivel la crea, le define los encargos y le pasa el
## aviso (`avisar`) con el que contarle cosas al jugador.

const RECOMPENSA: int = 100

var avisar: Callable = Callable()
var lista: Array = []         ## [{npc, nombre, tipo, meta, progreso, estado, ...}]


func definir(npc: Node, nombre: String, tipo: String, meta: int, oferta: Array,
		extra: Dictionary = {}) -> void:
	var m: Dictionary = {"npc": npc, "nombre": nombre, "tipo": tipo, "meta": meta,
		"progreso": 0, "estado": "libre", "oferta": oferta}
	m.merge(extra, true)
	lista.append(m)
	if tipo == "apagar" and is_instance_valid(m.get("fogata")):
		(m["fogata"] as Node).connect("extinguished", _on_apagada.bind(m))


## Engancha las señales del mundo. Se llama una vez construido el nivel.
func iniciar() -> void:
	Estado.i().enemigo_muerto.connect(_on_muerte)
	for o in get_tree().get_nodes_in_group("flammable"):
		if o.has_signal("ardiendo"):
			o.connect("ardiendo", _on_arde.bind(o))


func de_npc(npc: Node) -> Dictionary:
	for m in lista:
		if m["npc"] == npc:
			return m
	return {}


func lineas_para(npc: Node) -> Array:
	var m: Dictionary = de_npc(npc)
	if m.is_empty():
		return ["..."]
	match String(m["estado"]):
		"libre":
			return m["oferta"]
		"activa":
			return ["Todavía no has terminado: %s (%d/%d)." % [_descripcion(m), int(m["progreso"]), int(m["meta"])]]
		"lista":
			return ["¡Lo has conseguido! Toma tu recompensa: %d de oro." % RECOMPENSA]
		_:
			return ["Gracias otra vez. El bosque está más tranquilo."]


## El diálogo con este guardabosques acaba de cerrarse.
func al_cerrar(npc: Node) -> void:
	var m: Dictionary = de_npc(npc)
	if m.is_empty():
		return
	match String(m["estado"]):
		"libre":
			m["estado"] = "activa"
			if m["tipo"] == "apagar" and is_instance_valid(m.get("fogata")):
				var f: Node = m["fogata"]
				if not bool(f.get("is_lit")):
					f.call("_light", false)
			_avisar("Encargo aceptado: %s" % _descripcion(m))
		"lista":
			m["estado"] = "hecha"
			Estado.i().dar_oro(RECOMPENSA)
			Sonidos.play(self, "comprar", -6.0)
			_avisar("Encargo cumplido: +%d de oro" % RECOMPENSA)
	_cambiado()


func _descripcion(m: Dictionary) -> String:
	return String(m["nombre"])


func texto_hud() -> String:
	var l: Array = []
	for m in lista:
		match String(m["estado"]):
			"activa":
				l.append("• %s  %d/%d" % [m["nombre"], int(m["progreso"]), int(m["meta"])])
			"lista":
				l.append("• %s: ¡vuelve con el guardabosques!" % m["nombre"])
	return "\n".join(l)


func _avance(m: Dictionary, n: int = 1) -> void:
	if String(m["estado"]) != "activa":
		return
	m["progreso"] = mini(int(m["progreso"]) + n, int(m["meta"]))
	if int(m["progreso"]) >= int(m["meta"]):
		m["estado"] = "lista"
		_avisar("Encargo cumplido. Vuelve con el guardabosques.")
	_cambiado()


func _on_muerte(pos: Vector2, quien: String) -> void:
	if quien.contains("dummy"):
		return
	for m in lista:
		if m["tipo"] == "matar" and pos.distance_to(m["centro"]) <= float(m["radio"]):
			_avance(m)


func _on_arde(obj: Node) -> void:
	for m in lista:
		if m["tipo"] != "quemar" or String(m["estado"]) != "activa":
			continue
		var r: float = float(m.get("radio", 0.0))
		if r <= 0.0 or (obj as Node2D).global_position.distance_to(m["centro"]) <= r:
			_avance(m)
			return


func _on_apagada(m: Dictionary) -> void:
	_avance(m)


func _avisar(t: String) -> void:
	if avisar.is_valid():
		avisar.call(t)


func _cambiado() -> void:
	Estado.i().cambiado.emit()
