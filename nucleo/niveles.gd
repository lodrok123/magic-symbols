class_name Niveles
extends RefCounted

## TRANSICIÓN ENTRE NIVELES (mapas abiertos al estilo EoW, 23/10, docs/PLAN_BOSQUE_EOW.md §8). Antes cada escena era independiente; ahora una SALIDA con nombre carga otro nivel y la
## jugadora aparece en una ENTRADA con nombre (el `SensorLevelOpen` + `TagAreaStart` de EoW). Las dos son piezas de mapa (escenas/puzle.gd, objetos/salida_nivel_3d.gd):
##   ; pieza <id> entrada <x> <y> [mira=n|e|s|o]            el punto de llegada; el id ES su nombre. Sin `mira`, mira hacia donde hay más suelo libre (hacia dentro del nivel)
##   ; pieza <id> salida  <x> <y> a=<Nivel>:<entrada> [celdas=<lista>] [modo=pisar|usar] [marca=si|no]
##
## `<Nivel>` se resuelve con la tabla `ESCENAS` (nombre del mapa → escena de prueba): hoy el Bosque 01, la Cueva y el Bosque 01 v01. Un nivel que no está en la tabla, o cuya escena
## no existe todavía, AVISA en consola y no hace nada (la salida sigue ahí; sale un aviso en pantalla). Para dar de alta un nivel nuevo: una fila de `ESCENAS`.
##
## QUÉ VIAJA. Estado, Flags, Misiones y el repertorio de glifos son únicos y estáticos (`Estado.i()`, `Flags.i()`…): ninguna escena los rehace, así que oro, mochila, flags y glifos
## persisten solos. Lo único que se pasa a mano es la VIDA de la jugadora (Jugador3D nace con la vida máxima). El libro, la tinta y la cámara son del nivel y arrancan como en cualquier entrada.
## El diario sigue el mismo recorrido: `PlayLog.viaje_en_curso` hace que la escena nueva no cuente como partida nueva (evento `inicio_nivel`).
##
## CÓMO VA. 1) fundido a negro (`T_FUNDIDO`) sobre la raíz (sobrevive a la escena) · 2) se saca la escena vieja y se monta la nueva · 3) se espera a que haya jugadora, a que se levante el velo
## de «Preparando efectos» y a que Puzle3D haya montado sus piezas · 4) se la pone en la entrada, mirando hacia dentro, con la luz de su zona sin mezcla ni salto de cámara · 5) fundido de vuelta.

const ESCENAS: Dictionary = {
	"Bosque_01": "res://escenas/PruebaBosque01.tscn",
	"Cueva": "res://escenas/PruebaCueva.tscn",
	"CuevaResonante": "res://escenas/PruebaCuevaResonante.tscn",      # 27/10: la Cueva rediseñada como mazmorra EoW (docs/CUEVA_RESONANTE.md)
	"GrutaBatida": "res://escenas/PruebaGrutaBatida.tscn",            # 27/10: el nivel de la barrera (docs/GRUTA_BATIDA.md)
	"SalaEmpuje": "res://escenas/PruebaSalaEmpuje.tscn",            # 27/10: la sala de los bloques empujables (docs/EMPUJAR_BLOQUES.md)
	"Bosque_01_v01": "res://escenas/PruebaBosque01_v01.tscn",     # el mapa lo diseña otro agente (docs/PLAN_BOSQUE_01_V01.md): hasta que exista la escena, la salida avisa
}
const T_FUNDIDO: float = 0.35
const CAPA_FUNDIDO: int = 100
const NOMBRE_FUNDIDO: String = "FundidoNiveles"
const ESPERA_MAX_MS: int = 30000            ## ms de pared como tope esperando a la escena nueva (el velo de precalentado dura unos segundos)
const FOTOGRAMAS_ASENTAR: int = 2
const LARGO_MAX_MIRADA: int = 12            ## casillas que se miran en cada dirección para saber hacia dónde es «dentro»
const SEPARADOR: String = ":"
const TXT_SIN_NIVEL: String = "Este camino todavía no lleva a ningún sitio"

## Niveles dados de alta en tiempo de ejecución (`registrar`): para las pruebas y las capturas, que enseñan el viaje con una escena que hace de otra.
static var registro_extra: Dictionary = {}

## La entrada a la que va el viaje en curso (la escena nueva la lee al montarse).
static var entrada_pendiente: String = ""
static var vida_pendiente: float = -1.0
static var en_curso: bool = false
static var viajes: Array = []                ## {de, a, entrada}: lo que se ha viajado (las pruebas)
static var ultimo_aviso: String = ""


## El nombre de nivel de lo que se escribe en `escena=`: un nivel de la tabla tal cual, o el nombre de una escena de la tabla (`PruebaCueva` → `Cueva`). Si no casa con nada, tal cual.
static func nivel_de(escena_o_nivel: String) -> String:
	if ESCENAS.has(escena_o_nivel) or registro_extra.has(escena_o_nivel):
		return escena_o_nivel
	for tabla in [registro_extra, ESCENAS]:
		for k in (tabla as Dictionary):
			if String((tabla as Dictionary)[k]).get_file().get_basename() == escena_o_nivel:
				return String(k)
	return escena_o_nivel


## La escena de un nivel (la tabla `ESCENAS`, o lo registrado en `registro_extra`); "" si no tiene fila.
static func escena_de(nivel: String) -> String:
	return String(registro_extra.get(nivel, ESCENAS.get(nivel, "")))


## Da de alta (o cambia) la escena de un nivel solo durante esta ejecución. `""` la quita.
static func registrar(nivel: String, escena: String) -> void:
	if escena == "":
		registro_extra.erase(nivel)
	else:
		registro_extra[nivel] = escena


## ¿Hay una escena para este nivel? (tiene fila y el archivo existe).
static func existe(nivel: String) -> bool:
	var ruta: String = escena_de(nivel)
	return ruta != "" and ResourceLoader.exists(ruta)


## `<Nivel>:<entrada>` → [nivel, entrada]. Vacío si no tiene esa forma.
static func partir(destino: String) -> PackedStringArray:
	var p: PackedStringArray = destino.split(SEPARADOR)
	if p.size() != 2 or p[0] == "" or p[1] == "":
		return PackedStringArray()
	return p


## El alfa del fundido ahora mismo (-1 = no hay fundido). Para las pruebas y las capturas.
static func alfa_fundido(arbol: SceneTree) -> float:
	var capa: Node = arbol.root.get_node_or_null(NOMBRE_FUNDIDO)
	if capa == null:
		return -1.0
	var r: ColorRect = capa.get_node_or_null("negro") as ColorRect
	return r.color.a if r != null else -1.0


## Empieza el viaje a `destino` («Nivel:entrada») desde la escena `mundo` (la raíz del nivel). Devuelve false, sin hacer nada, si ya hay un viaje en curso, si
## `destino` está mal escrito o si ese nivel no existe todavía (avisa por consola). El viaje sigue solo (fundido, cargar, colocar, fundido).
static func ir_a(mundo: Node, destino: String) -> bool:
	if en_curso or mundo == null or not mundo.is_inside_tree():
		return false
	var p: PackedStringArray = partir(destino)
	if p.is_empty():
		_avisar("destino «%s» mal escrito: se escribe <Nivel>:<entrada>" % destino)
		return false
	if not existe(p[0]):
		_avisar("el nivel «%s» todavía no existe (hay: %s; escena %s)" % [p[0], ", ".join(ESCENAS.keys()), escena_de(p[0]) if escena_de(p[0]) != "" else "sin fila en Niveles.ESCENAS"])
		return false
	en_curso = true
	_viaje(mundo, p[0], p[1])
	return true


static func _avisar(texto: String) -> void:
	ultimo_aviso = texto
	push_warning("Niveles: " + texto)


## El viaje entero (corre solo: no se espera).
static func _viaje(mundo: Node, nivel: String, entrada: String) -> void:
	var arbol: SceneTree = mundo.get_tree()
	var origen: String = String(mundo.get("nivel")) if mundo.get("nivel") != null else ""
	PlayLog.event("transicion", {"de": origen, "a": nivel, "entrada": entrada})
	viajes.append({"de": origen, "a": nivel, "entrada": entrada})
	Engine.time_scale = 1.0
	var jug: Node = _jugador(arbol)
	if jug != null:
		vida_pendiente = float(jug.get("vida"))
		jug.call("bloquear", true)
	var negro: ColorRect = _velo(arbol)
	await _fundir(negro, 1.0)
	entrada_pendiente = entrada
	PlayLog.viaje_en_curso = true
	var padre: Node = mundo.get_parent()
	padre.remove_child(mundo)
	mundo.queue_free()
	await arbol.process_frame
	await arbol.process_frame
	var nueva: Node = (load(escena_de(nivel)) as PackedScene).instantiate()
	padre.add_child(nueva)
	if padre == arbol.root:
		arbol.current_scene = nueva
	await _llegar(arbol, nueva, negro)
	en_curso = false


## La escena nueva ya está en el árbol: espera a que esté lista, pone a la jugadora en su entrada y levanta el fundido.
static func _llegar(arbol: SceneTree, nueva: Node, negro: ColorRect) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ESPERA_MAX_MS and not _lista(arbol, nueva):
		await arbol.process_frame
	var e: Node = _entrada(arbol, entrada_pendiente)
	if e != null and _jugador(arbol) != null:
		colocar(nueva, e)
	else:
		_avisar("el nivel nuevo no tiene la entrada «%s»: la jugadora se queda donde nace" % entrada_pendiente)
	entrada_pendiente = ""
	var jug: Node = _jugador(arbol)
	if jug != null and vida_pendiente > 0.0:
		jug.set("vida", minf(vida_pendiente, Estado.i().vida_max))
		jug.emit_signal("vida_cambiada", float(jug.get("vida")), Estado.i().vida_max)
	vida_pendiente = -1.0
	var zonas: Node = nueva.get_node_or_null("Zonas3D")
	if zonas != null and zonas.has_method("forzar"):
		zonas.call("forzar")
	for _i in range(FOTOGRAMAS_ASENTAR):
		await arbol.process_frame
	await _fundir(negro, 0.0)
	negro.get_parent().queue_free()


## ¿Está montado lo que hace falta para colocar a la jugadora? Jugadora y lanzador, velo de precalentado levantado y todos los Puzle3D de la escena con sus piezas.
static func _lista(arbol: SceneTree, nueva: Node) -> bool:
	if not is_instance_valid(nueva) or _jugador(arbol) == null or nueva.get("_velo") != null:
		return false
	for pz in nueva.find_children("*", "Puzle3D", true, false):
		if not bool((pz as Object).get("listo")):
			return false
	return true


static func _jugador(arbol: SceneTree) -> Node:
	var lanz: Node = arbol.get_first_node_in_group("spellcaster")
	return lanz.get("jugador") as Node if lanz != null and lanz.get("jugador") != null else null


## La entrada con ese nombre (EntradaNivel3D, grupo `entrada_nivel`) o null.
static func _entrada(arbol: SceneTree, nombre: String) -> Node:
	for n in arbol.get_nodes_in_group("entrada_nivel"):
		if is_instance_valid(n) and String(n.get("nombre")) == nombre:
			return n
	return null


## Pone a la jugadora en la casilla de la entrada, mirando hacia dentro. También es su punto de reaparición.
static func colocar(mundo: Node, e: Node) -> void:
	var arbol: SceneTree = mundo.get_tree()
	var c: Vector2i = e.get("celda")
	var jug: Node = _jugador(arbol)
	if jug == null:
		return
	if mundo.has_method("ir_a"):
		mundo.call("ir_a", c)                 # cámara y hierba al sitio
	var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	var pj: Node3D = jug.get("pj") as Node3D
	if pj != null:
		pj.position = p
	(jug as Node3D).position = p
	jug.set("puntos_inicio", p)
	var dir: Vector3 = e.call("direccion_mirada")
	jug.call("mirar_hacia", dir)
	if pj != null and pj.has_method("mirar"):
		pj.call("mirar", dir, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  Fundido
# ---------------------------------------------------------------------------------------------------------------------

## El rectángulo negro, en una capa de la raíz (sobrevive al cambio de escena). Si ya había uno, ese.
static func _velo(arbol: SceneTree) -> ColorRect:
	var capa: Node = arbol.root.get_node_or_null(NOMBRE_FUNDIDO)
	if capa != null:
		return capa.get_node("negro") as ColorRect
	var cl := CanvasLayer.new()
	cl.name = NOMBRE_FUNDIDO
	cl.layer = CAPA_FUNDIDO
	var r := ColorRect.new()
	r.name = "negro"
	r.color = Color(0.0, 0.0, 0.0, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	arbol.root.add_child(cl)
	return r


## Lleva el alfa del negro a `alfa` en `T_FUNDIDO` s. Espera a que acabe.
static func _fundir(negro: ColorRect, alfa: float) -> void:
	var tw: Tween = negro.create_tween()
	tw.tween_property(negro, "color:a", alfa, T_FUNDIDO)
	await tw.finished
