extends Node3D

## GALERÍA DE LOS EFECTOS «BLOQUES» (25/11/2026, presentacion/vfx/bloques/bloques_vfx.gd). Va aparte para que lab_vfx_comparativa_3d.gd solo lleve unas teclas.
## Pablo pasó capturas de la demo de EffectBlocks y eligió lo que le interesa; aquí se ve todo en fila, por grupos, como en la demo (con rótulo debajo de cada uno).
## Los de un disparo (explosiones, limo) se repiten solos cada CICLO s.
## Teclas (dentro de LabVfxComparativa3D):
##   Ctrl+9          pone / quita la galería (esconde a la jugadora; al quitarla vuelve todo como estaba)
##   Mayús+Ctrl+9    vista: juego (ortogonal, 30°) → cerca (perspectiva)
##   Ctrl+0          grupo siguiente (Mayús+Ctrl+0: anterior): veneno y humo · explosiones · rayo · destellos y portal · decals
## Capturas: herramientas/captura_bloques_vfx.gd.

const BloquesVfx = preload("res://presentacion/vfx/bloques/bloques_vfx.gd")
const NOMBRE: String = "GaleriaBloques"
const CENTRO: Vector3 = Vector3(0.0, 0.0, -4.0)     ## entre los cubos del mapa del lab
const CICLO: float = 2.2                              ## s entre repeticiones de los de un disparo
const VISTAS: PackedStringArray = ["juego", "cerca"]
const ALTO_VENENO: float = 0.9                        ## m: la punta del bastón del chamán
## Cada grupo: [título, [[rótulo, id], ...]]. El id lo entiende `_crear`.
const GRUPOS: Array = [
	["VENENO Y HUMO", [["llama de veneno\n(bastón del chamán)", "veneno"], ["llama de veneno\nen vuelo (estela)", "veneno_vuelo"], ["humo tóxico\nverde veneno", "humo"], ["humo tóxico\nmorado (demo)", "humo_morado"]]],
	["EXPLOSIONES", [["fuego", "explosion_fuego"], ["agua", "explosion_agua"], ["tierra", "explosion_tierra"], ["eléctrica", "explosion_rayo"]]],
	["RAYO", [["ondas eléctricas", "ondas"], ["chispas eléctricas", "chispas"], ["bola de rayo", "bola"], ["explosión eléctrica", "explosion_rayo"]]],
	["DESTELLOS Y PORTAL", [["destellos (botín)", "destellos"], ["portal de fuego", "portal_fuego"], ["portal de agua", "portal_agua"]]],
	["DECALS", [["grieta tierra", "grieta_tierra"], ["grieta magma", "grieta_magma"], ["grieta rayo", "grieta_rayo"], ["grieta veneno", "grieta_veneno"], ["pisadas", "pisadas"], ["limo", "limo"]]],
]
const UN_DISPARO: PackedStringArray = ["explosion_fuego", "explosion_agua", "explosion_tierra", "explosion_rayo", "limo"]

var grupo: int = 0
var vista: int = 0
var auto: bool = true                                 ## false: no se repite solo (las capturas lanzan a mano)
var _lab: Node3D = null
var _cam: Camera3D = null
var _escenario: Node3D = null
var _efectos: Node3D = null
var _rotulo: Label = null
var _reloj: float = 0.0
var _items: Array = []                                ## [{id, pos, nodo}]
var _pj_visible: bool = true
var _panel_lab: bool = true


# ------------------------------------------------------------------ desde el lab ------------------------------------------------------------------

## Ctrl+9 / Ctrl+0 del lab. Devuelve la galería (o null si se ha quitado).
static func tecla(lab: Node3D, keycode: int, mayus: bool) -> Node:
	var g: Node = lab.get_node_or_null(NOMBRE)
	if keycode == KEY_9 and not mayus:
		if g != null:
			g.call("quitar")
			return null
		return poner(lab)
	if g == null:
		g = poner(lab)
	if keycode == KEY_9:
		g.call("poner_vista", (int(g.get("vista")) + 1) % VISTAS.size())
	elif keycode == KEY_0:
		g.call("poner_grupo", (int(g.get("grupo")) + (GRUPOS.size() - 1 if mayus else 1)) % GRUPOS.size())
	return g


static func poner(lab: Node3D) -> Node:
	var g: Node3D = (load("res://laboratorios/lab_bloques_vfx.gd") as GDScript).new()
	g.name = NOMBRE
	g.set("_lab", lab)
	lab.add_child(g)
	return g


static func texto(lab: Node3D) -> String:
	return "\nCtrl+9 GALERÍA de efectos «bloques» (veneno del chamán, humo tóxico, explosiones, rayo, destellos, portal, decals) · Mayús+Ctrl+9 vista · Ctrl+0 grupo" + \
		(" · PUESTA" if lab.get_node_or_null(NOMBRE) != null else "")


# ------------------------------------------------------------------ montaje ------------------------------------------------------------------

func _ready() -> void:
	var pj: Node3D = _lab.get("_pj") if _lab != null else null
	if pj != null:
		_pj_visible = pj.visible
		pj.visible = false
	if _lab != null:
		_panel_lab = bool(_lab.get("_panel_visible"))
		_lab.set("_panel_visible", false)
		for h in _lab.get_children():                    # los cubos del mapa tapan la fila: fuera mientras esté la galería
			if h is MeshInstance3D and String(h.name).begins_with("Cubo"):
				(h as MeshInstance3D).visible = false
	_escenario = Node3D.new()
	_escenario.name = "Escenario"
	add_child(_escenario)
	_efectos = Node3D.new()
	_efectos.name = "Efectos"
	add_child(_efectos)
	_cam = Camera3D.new()
	_cam.name = "CamaraGaleria"
	add_child(_cam)
	_cam.make_current()
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.position = Vector2(16, 16)
	_rotulo.add_theme_font_size_override("font_size", 17)
	_rotulo.add_theme_color_override("font_color", Color(1, 1, 1))
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_rotulo.add_theme_constant_override("outline_size", 5)
	capa.add_child(_rotulo)
	poner_grupo(grupo)


func quitar() -> void:
	var pj: Node3D = _lab.get("_pj") if _lab != null else null
	if pj != null:
		pj.visible = _pj_visible
	if _lab != null:
		_lab.set("_panel_visible", _panel_lab)
		for h in _lab.get_children():
			if h is MeshInstance3D and String(h.name).begins_with("Cubo"):
				(h as MeshInstance3D).visible = true
	var cam_lab: Camera3D = _lab.get("_cam") if _lab != null else null
	if cam_lab != null:
		cam_lab.make_current()
	queue_free()


func _separacion() -> float:
	var n: int = (GRUPOS[grupo][1] as Array).size()
	return 2.4 if n <= 4 else 1.75


func poner_grupo(i: int) -> void:
	grupo = clampi(i, 0, GRUPOS.size() - 1)
	for h in _escenario.get_children():
		h.queue_free()
	for h in _efectos.get_children():
		h.queue_free()
	_items.clear()
	var lista: Array = GRUPOS[grupo][1]
	var sep: float = _separacion()
	for k in lista.size():
		var pos: Vector3 = CENTRO + Vector3((float(k) - float(lista.size() - 1) * 0.5) * sep, 0.0, 0.0)
		var l3: Label3D = Label3D.new()
		l3.text = String(lista[k][0])
		l3.font_size = 40
		l3.pixel_size = 0.0035
		l3.outline_size = 10
		l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l3.no_depth_test = true
		l3.position = pos + Vector3(0, 0.05, 1.25)            # a ras de suelo, delante
		_escenario.add_child(l3)
		_items.append({"id": String(lista[k][1]), "pos": pos, "nodo": null})
	for it in _items:
		_lanzar(it)
	poner_vista(vista)
	_reloj = 0.0


## Crea (o vuelve a crear) el efecto de un hueco de la galería.
func _lanzar(it: Dictionary) -> void:
	var viejo: Node = it["nodo"]
	if viejo != null and is_instance_valid(viejo):
		viejo.queue_free()
	var e: Node3D = _crear(String(it["id"]))
	_efectos.add_child(e)
	var alto: float = 0.0
	match String(it["id"]):
		"veneno", "veneno_vuelo":
			alto = ALTO_VENENO
		"ondas", "chispas", "bola", "destellos":
			alto = 0.8
		"explosion_fuego", "explosion_agua", "explosion_rayo":
			alto = 0.35
		"explosion_tierra":
			alto = 0.05
	e.global_position = (it["pos"] as Vector3) + Vector3(0, alto, 0)
	it["nodo"] = e


func _crear(id: String) -> Node3D:
	match id:
		"veneno":
			return BloquesVfx.crear_veneno_chaman(false)
		"veneno_vuelo":
			return BloquesVfx.crear_veneno_chaman(true)
		"humo":
			return BloquesVfx.crear_humo_toxico(false)
		"humo_morado":
			return BloquesVfx.crear_humo_toxico(true)
		"explosion_fuego":
			return BloquesVfx.crear_explosion("fuego")
		"explosion_agua":
			return BloquesVfx.crear_explosion("agua")
		"explosion_tierra":
			return BloquesVfx.crear_explosion("tierra")
		"explosion_rayo":
			return BloquesVfx.crear_explosion("rayo")
		"ondas":
			return BloquesVfx.crear_ondas_electricas(1.8)
		"chispas":
			return BloquesVfx.crear_chispas_electricas()
		"bola":
			return BloquesVfx.crear_bola_rayo()
		"destellos":
			return BloquesVfx.crear_destellos("fuego")
		"portal_fuego":
			return BloquesVfx.crear_portal("fuego")
		"portal_agua":
			return BloquesVfx.crear_portal("agua")
		"grieta_tierra":
			return BloquesVfx.crear_grieta("tierra", 1.4)
		"grieta_magma":
			return BloquesVfx.crear_grieta("magma", 1.4)
		"grieta_rayo":
			return BloquesVfx.crear_grieta("rayo", 1.4)
		"grieta_veneno":
			return BloquesVfx.crear_grieta("veneno", 1.4)
		"pisadas":
			return BloquesVfx.crear_pisadas(8)
		"limo":
			return BloquesVfx.crear_salpicadura_limo("veneno")
	return Node3D.new()


## Relanza los de un disparo (las capturas lo llaman a mano).
func relanzar() -> void:
	for it in _items:
		if UN_DISPARO.has(String(it["id"])):
			_lanzar(it)
	_reloj = 0.0


func poner_vista(v: int) -> void:
	vista = clampi(v, 0, VISTAS.size() - 1)
	var n: int = (GRUPOS[grupo][1] as Array).size()
	var ancho: float = float(n) * _separacion()
	var foco: Vector3 = CENTRO + Vector3(0, 0.6, 0.3)
	match VISTAS[vista]:
		"juego":                                     # como el juego: ortogonal, 30° sobre el suelo (PruebaTest2)
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = maxf(ancho / 1.7, 3.2)
			_cam.global_position = foco + Vector3(0, sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0))) * 20.0
			_cam.look_at(foco, Vector3.UP)
		_:
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.fov = 50.0
			_cam.global_position = foco + Vector3(0, 1.4, ancho * 0.5 + 0.6)
			_cam.look_at(foco, Vector3.UP)
	_rotular()


## Mueve los de «en vuelo» (ida y vuelta), para ver la estela.
func _process(delta: float) -> void:
	for it in _items:
		if String(it["id"]) == "veneno_vuelo" and it["nodo"] != null and is_instance_valid(it["nodo"]):
			var t: float = Time.get_ticks_msec() / 1000.0
			(it["nodo"] as Node3D).global_position = (it["pos"] as Vector3) + Vector3(sin(t * 2.2) * 0.8, ALTO_VENENO + 0.1 * sin(t * 4.4), 0)
	if not auto:
		return
	_reloj += delta
	if _reloj >= CICLO:
		relanzar()


func rotulos(si: bool) -> void:
	if _rotulo != null:
		_rotulo.visible = si
	for h in _escenario.get_children():
		if h is Label3D:
			(h as Label3D).visible = si


func _rotular() -> void:
	if _rotulo == null:
		return
	_rotulo.text = ("GALERÍA DE EFECTOS «BLOQUES» · grupo %d/%d: %s\nCtrl+0 grupo siguiente (Mayús: anterior) · Mayús+Ctrl+9 vista: %s · Ctrl+9 salir · los de un disparo se repiten cada %.1f s\n" +
		"Mandos (constantes arriba de presentacion/vfx/bloques/bloques_vfx.gd): tamaños, cantidades, velocidades y colores de cada efecto") % [
		grupo + 1, GRUPOS.size(), String(GRUPOS[grupo][0]), VISTAS[vista], CICLO]
