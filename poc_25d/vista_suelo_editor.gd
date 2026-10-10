@tool
extends "res://poc_25d/prueba_test2.gd"
## VISTA DEL SUELO DEL JUEGO EN EL EDITOR (13/10, Pipeline).
##
## Va dentro del nivel (p. ej. Nivel_Bosque.tscn, nodo `VistaSuelo`) y SOLO hace algo en el editor: lee el nivel abierto
## (GridMap + marcadores, también lo que aún no está guardado) y construye el suelo con el MISMO código que el juego
## (PruebaTest2._leer_nivel_de, _construir_suelo y _sembrar_hierba): hierba, camino, tierra, piedra, agua, cauce, orillas
## y las matas de hierba.
## Por qué hereda de prueba_test2.gd en vez de copiar el código: así el suelo del editor no se puede separar del del juego.
##
## Los bloques del GridMap (para pintar casillas) se ocultan en el editor mientras se ve el suelo; `ver_bloques` los
## vuelve a mostrar. No se guarda: al guardar la escena quedan visibles como siempre.
## Se rehace sola al cambiar una casilla del GridMap o un marcador; `actualizar` la rehace a mano.
## En el juego no hace nada: PruebaBosque lee el nivel sin meterlo en el árbol y este nodo no tiene metadato `id`.

## Ver los bloques del GridMap (para pintar casillas) en vez del suelo del juego.
@export var ver_bloques: bool = false:
	set(v):
		ver_bloques = v
		if is_inside_tree():
			_aplicar_bloques()

## Sembrar también la hierba del juego (matas y flores). En el juego sale alrededor del jugador al andar; aquí, toda.
@export var ver_hierba: bool = true:
	set(v):
		ver_hierba = v
		if is_inside_tree() and Engine.is_editor_hint():
			_reconstruir()

## Pulsar para rehacer el suelo a mano (se rehace solo al cambiar casillas o marcadores).
@export var actualizar: bool = false:
	set(v):
		actualizar = false
		if is_inside_tree() and Engine.is_editor_hint():
			_reconstruir()

const COMPROBAR_CADA: float = 0.5        ## s entre comprobaciones de cambios en el nivel

var _firma: int = 0
var _pendiente: int = 0     ## huella vista en la comprobación anterior: se rehace cuando deja de cambiar (no a cada clic)
var _espera: float = 0.0


func _ready() -> void:
	# No llama a PruebaTest2._ready: aquí no hay juego (cámara, jugador, reglas…), solo el suelo.
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_reconstruir()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_espera += delta
	if _espera < COMPROBAR_CADA:
		return
	_espera = 0.0
	var f: int = _firma_nivel()
	if f == _firma:
		return
	if f == _pendiente:
		_reconstruir()          # lleva COMPROBAR_CADA s sin cambiar: ya se puede rehacer
	_pendiente = f


func _unhandled_input(_ev: InputEvent) -> void:
	pass        # el del juego (cámara, hechizos) no corre en el editor


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	# Lo que se cambia solo para verlo en el editor se deja como estaba al guardar, y se vuelve a poner después.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var g: GridMap = _gridmap()
		if g != null:
			g.visible = true
		position = Vector3.ZERO
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_aplicar_bloques()
		position = -_desplaza
	elif what == NOTIFICATION_EXIT_TREE:
		var g2: GridMap = _gridmap()
		if g2 != null:
			g2.visible = true


func _raiz_nivel() -> Node:
	return owner if owner != null else get_parent()


func _gridmap() -> GridMap:
	var raiz: Node = _raiz_nivel()
	if raiz == null:
		return null
	for g in raiz.find_children("*", "GridMap", true, false):
		return g as GridMap
	return null


func _aplicar_bloques() -> void:
	var g: GridMap = _gridmap()
	if g != null:
		g.visible = ver_bloques


## Huella del nivel: casillas del GridMap y marcadores (letra, sitio, giro, escala, lleno). Si cambia, se rehace el suelo.
func _firma_nivel() -> int:
	var raiz: Node = _raiz_nivel()
	if raiz == null:
		return 0
	var partes: Array = []
	var g: GridMap = _gridmap()
	if g != null:
		for u in g.get_used_cells():
			partes.append(u)
			partes.append(g.get_cell_item(u))
	for m in raiz.find_children("*", "Marcador3D", true, false):
		partes.append(String(m.get("letra")))
		partes.append((m as Node3D).transform)
		partes.append(bool(m.get("lleno")))
	return hash(partes)


## Borra el suelo anterior y lo vuelve a construir con el código del juego.
func _reconstruir() -> void:
	for h in get_children():
		remove_child(h)
		h.queue_free()
	_agua_cauce.clear()
	_guijarros = null
	_avisos.clear()
	var raiz: Node = _raiz_nivel()
	if raiz == null:
		return
	nivel = String(raiz.name).trim_prefix("Nivel_")      # solo para _tipo_suelo (el Test 2 conserva su aldea)
	_modo_nivel = true
	_leer_nivel_de(raiz)
	_nivel_raiz = null          # la escena abierta NO se libera (en el juego sí, porque es una copia)
	if not _modo_nivel or _mapa.is_empty():
		push_warning("VistaSuelo: no se pudo leer el nivel: %s" % str(_avisos))
		return
	_lado = _mapa.size()
	_construir_suelo()
	if ver_hierba:
		hierba_completa = true      # sin jugador: toda la hierba de una vez (en el juego se completa al andar)
		_sembrar_hierba()
	# El juego mueve el nivel para que empiece en (0, 0) (`_desplaza`); aquí se deshace para que case con el GridMap.
	position = -_desplaza
	_firma = _firma_nivel()
	_aplicar_bloques()
