class_name AtajosPlaytest
extends Node

## ATAJOS DE LOS NIVELES DE PLAYTEST (24/11/2026, Pablo tras jugar PtVagonetas: «he revisado los puzles 1 y 3; el resto no los he encontrado»).
## Va en las escenas Prueba<Pt…> que crea `herramientas/generar_playtest_puzles.gd`. Lee del mapa del nivel las zonas de puzle (`; zona … nombre=pt_<id>
## rotulo=<n>._<título>`) y:
##   · enseña arriba a la izquierda la lista de salas («Alt+1 · 1. Vagoneta a la placa…»), con ✔ en la sala donde está la jugadora;
##   · con Alt + número (o el número del teclado numérico) lleva a la jugadora a la ENTRADA de esa sala: la casilla libre de la sala más cercana a su
##     borde de abajo (el lado de la cámara), para que el puzle quede delante.
## Solo para playtest: un nivel oficial no lo lleva.

const RUTA_MAPA: String = "res://mundo/datos_nivel/mapas/%s.txt"

var salas: Array = []          ## [{n, titulo, nombre, rect: Rect2i}] en orden
var _hud: Label = null
var _t: float = 0.0


func _ready() -> void:
	_leer.call_deferred()


func _leer() -> void:
	var mundo: Node = get_parent()
	var nivel: String = String(mundo.get("nivel")) if mundo != null and mundo.get("nivel") != null else ""
	var ruta: String = RUTA_MAPA % nivel
	if nivel == "" or not FileAccess.file_exists(ruta):
		return
	var re: RegEx = RegEx.create_from_string("^; zona (\\d+),(\\d+)\\.\\.(\\d+),(\\d+) .*nombre=(pt_\\w+) rotulo=(\\d+)\\._(\\S+)")
	for linea in FileAccess.get_file_as_string(ruta).split("\n"):
		var m: RegExMatch = re.search(String(linea).strip_edges())
		if m == null:
			continue
		var a := Vector2i(m.get_string(1).to_int(), m.get_string(2).to_int())
		var b := Vector2i(m.get_string(3).to_int(), m.get_string(4).to_int())
		salas.append({"n": m.get_string(6).to_int(), "titulo": m.get_string(7).replace("_", " "), "nombre": m.get_string(5), "rect": Rect2i(a, b - a + Vector2i.ONE)})
	salas.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["n"]) < int(y["n"]))
	if salas.is_empty():
		return
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	# A la derecha, a media altura y con fondo oscuro: arriba a la izquierda está el texto de depuración del nivel y se pisaban.
	_panel = PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.04, 0.04, 0.72)
	fondo.set_corner_radius_all(6)
	fondo.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", fondo)
	capa.add_child(_panel)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	_panel.add_child(_hud)
	_pintar()


var _panel: PanelContainer = null


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0 and _hud != null:
		_t = 0.3
		_pintar()
	# Alt + número, leído del teclado en cada fotograma: el evento se lo queda antes la acción de la página del libro (`pagina_N`, que también salta con Alt).
	var n_alt: int = -1
	if Input.is_key_pressed(KEY_ALT):
		for k in range(1, 10):
			if Input.is_key_pressed(KEY_0 + k):
				n_alt = k
	if n_alt > 0 and n_alt != _alt_antes:
		ir_a(n_alt)
	_alt_antes = n_alt


var _alt_antes: int = -1


func _pintar() -> void:
	var j: Node3D = _jugador()
	var aqui: Vector2i = Terreno3D.celda_de(j.global_position) if j != null else Vector2i(-99, -99)
	var t: String = "PLAYTEST · Alt + número = ir a la sala\n"
	for s in salas:
		t += "%s Alt+%d · %d. %s\n" % ["▶" if (s["rect"] as Rect2i).has_point(aqui) else "  ", int(s["n"]), int(s["n"]), String(s["titulo"])]
	_hud.text = t.strip_edges(false, true)
	if _panel != null:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_panel.reset_size()
		_panel.position = Vector2(vp.x - _panel.size.x - 16.0, vp.y * 0.36)


## En `_input` (antes que nadie): los números sueltos son las páginas del libro y se las quedaba el lanzador. Con Alt (o en el teclado numérico) es el atajo,
## y se marca como gestionado para que no cambie también de página.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: InputEventKey = ev
	var n: int = -1
	if k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
		n = k.keycode - KEY_KP_0
	if n > 0 and ir_a(n):
		get_viewport().set_input_as_handled()


## Lleva a la jugadora a la entrada de la sala `n`. false si no existe o no hay sitio.
func ir_a(n: int) -> bool:
	for s in salas:
		if int(s["n"]) != n:
			continue
		var c: Vector2i = entrada(s["rect"])
		var j: Node3D = _jugador()
		if c.x < 0 or j == null:
			return false
		var p: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		var pj: Node3D = j.get("pj") as Node3D
		if pj != null:
			pj.position = p
		j.position = p
		return true
	return false


## La casilla libre de la sala más cercana al centro de su borde de abajo.
static func entrada(r: Rect2i) -> Vector2i:
	var meta := Vector2(r.position.x + r.size.x * 0.5, r.end.y - 1)
	var mejor := Vector2i(-1, -1)
	var md: float = INF
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if Terreno3D.bloqueada(c) or not Terreno3D.pisable(c, 0, true, 1, false):
				continue
			var d: float = Vector2(c).distance_squared_to(meta)
			if d < md:
				md = d
				mejor = c
	return mejor


func _jugador() -> Node3D:
	var lz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	return lz.get("jugador") as Node3D if lz != null and lz.get("jugador") != null else null
