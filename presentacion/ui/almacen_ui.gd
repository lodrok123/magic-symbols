class_name AlmacenUI
extends CanvasLayer
## EL COFRE MÁGICO (14/11, playtest de Pablo): almacén compartido por todos los cofres mágicos del mundo (Estado.almacen, 50 huecos).
## Dos columnas con el aspecto de la tienda: a la izquierda la MOCHILA, a la derecha el COFRE. Enter (o clic) pasa la pila entera al otro lado;
## Espacio pasa una sola unidad. ← → (A D) cambian de columna, ↑ ↓ (W S, rueda) eligen, Esc o E cierran. Pausa el mundo mientras está abierto.
##   AlmacenUI.abrir_en(get_tree())     # lo llaman los cofres mágicos de los niveles

const ANCHO: float = 840.0
const ALTO: float = 520.0
const COL_ANCHO: float = 360.0
const COL_Y: float = 118.0
const FILA_ALTO: float = 44.0
const FILA_SEP: float = 6.0
const FILAS_VISIBLES: int = 6
const TITULOS: Array = ["Mochila", "Cofre mágico"]

var abierta: bool = false
var columna: int = 0                 ## 0 mochila · 1 cofre
var elegido: Array = [0, 0]
var _scroll: Array = [0, 0]
var mensaje: String = ""
var _velo: ColorRect
var _panel: Lamina
var _pausado_por_mi: bool = false


static func abrir_en(arbol: SceneTree) -> AlmacenUI:
	var ui: AlmacenUI = arbol.root.get_node_or_null("AlmacenUI") as AlmacenUI
	if ui == null:
		ui = AlmacenUI.new()
		ui.name = "AlmacenUI"
		arbol.root.add_child(ui)
	ui.abrir()
	return ui


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0.45)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.visible = false
	add_child(_velo)
	_panel = Lamina.new()
	_panel.ui = self
	_panel.size = Vector2(ANCHO, ALTO)
	_panel.visible = false
	add_child(_panel)


func _exit_tree() -> void:
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false


func abrir() -> void:
	if not is_node_ready():
		await ready
	columna = 0
	elegido = [0, 0]
	_scroll = [0, 0]
	mensaje = ""
	abierta = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = ((vp - _panel.size) * 0.5).round()
	_velo.visible = true
	_panel.visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_pausado_por_mi = true
	Sfx.play_ui("libro_abre")
	_panel.queue_redraw()


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	_velo.visible = false
	_panel.visible = false
	if _pausado_por_mi:
		get_tree().paused = false
	_pausado_por_mi = false
	Sfx.play_ui("libro_cierra")


## [[id, cantidad], …] de una columna, ordenado por nombre.
func lista(col: int) -> Array:
	var d: Dictionary = Estado.i().items if col == 0 else Estado.i().almacen
	var r: Array = []
	for id in d:
		# Lo de la categoría «clave» (llaves, ropa, glifos, mejoras) y las piezas de mejora no se guardan: no ocupan sitio o son de la historia.
		if int(d[id]) > 0 and (col == 1 or (Objetos.categoria(String(id)) != "clave" and not Objetos.es_pieza(String(id)))):
			r.append([String(id), int(d[id])])
	r.sort_custom(func(a: Array, b: Array) -> bool: return Objetos.nombre(a[0]) < Objetos.nombre(b[0]))
	return r


func elegir(col: int, i: int) -> void:
	var n: int = lista(col).size()
	columna = col
	elegido[col] = clampi(i, 0, maxi(n - 1, 0))
	if elegido[col] < _scroll[col]:
		_scroll[col] = elegido[col]
	elif elegido[col] >= _scroll[col] + FILAS_VISIBLES:
		_scroll[col] = elegido[col] - FILAS_VISIBLES + 1
	_panel.queue_redraw()


## Pasa la pila elegida (o una unidad) al otro lado. Devuelve cuántas pasaron.
func mover(todo: bool = true) -> int:
	var l: Array = lista(columna)
	if l.is_empty():
		return 0
	var fila: Array = l[clampi(elegido[columna], 0, l.size() - 1)]
	var id: String = fila[0]
	var n: int = int(fila[1]) if todo else 1
	var e: Estado = Estado.i()
	var k: int = e.guardar_en_almacen(id, n) if columna == 0 else e.sacar_de_almacen(id, n)
	if k <= 0:
		mensaje = "El cofre mágico está lleno" if columna == 0 else "No cabe en la mochila"
		Sfx.play_ui("no_puedes_ui")
	else:
		mensaje = "%s %s%s" % ["Guardas" if columna == 0 else "Sacas", Objetos.nombre(id), "" if k == 1 else " ×%d" % k]
		Sfx.play_ui("ui_tick")
	elegir(columna, elegido[columna])
	return k


func _input(event: InputEvent) -> void:
	if not abierta:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k: Key = (event as InputEventKey).keycode
		var eco: bool = (event as InputEventKey).echo
		match k:
			KEY_UP, KEY_W:
				elegir(columna, elegido[columna] - 1)
			KEY_DOWN, KEY_S:
				elegir(columna, elegido[columna] + 1)
			KEY_LEFT, KEY_A:
				elegir(0, elegido[0])
			KEY_RIGHT, KEY_D:
				elegir(1, elegido[1])
			KEY_ENTER, KEY_KP_ENTER:
				if not eco:
					mover(true)
			KEY_SPACE:
				if not eco:
					mover(false)
			KEY_ESCAPE, KEY_E, KEY_I:
				if not eco:
					cerrar()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: InputEventMouseButton = event as InputEventMouseButton
		var p: Vector2 = _panel.get_global_transform_with_canvas().affine_inverse() * b.position
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			elegir(columna, elegido[columna] - 1)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			elegir(columna, elegido[columna] + 1)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			for col in range(2):
				for v in range(FILAS_VISIBLES):
					if rect_fila(col, v).has_point(p) and _scroll[col] + v < lista(col).size():
						var era: bool = columna == col and elegido[col] == _scroll[col] + v
						elegir(col, _scroll[col] + v)
						if era:
							mover(true)
						return
		get_viewport().set_input_as_handled()


static func rect_fila(col: int, v: int) -> Rect2:
	var x: float = 44.0 if col == 0 else ANCHO - 44.0 - COL_ANCHO
	return Rect2(x, COL_Y + float(v) * (FILA_ALTO + FILA_SEP), COL_ANCHO, FILA_ALTO)


class Lamina extends Control:
	var ui: AlmacenUI

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _caja(r: Rect2, fondo: Color, borde: Color, ancho: int, radio: int) -> void:
		BolsaUI._caja(fondo, borde, ancho, radio).draw(get_canvas_item(), r)

	func _draw() -> void:
		if ui == null:
			return
		var f: Font = TemaInterfaz.fuente()
		var r := Rect2(Vector2.ZERO, size)
		_caja(r, BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 24)
		_caja(r.grow(-20.0), BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 14)
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 18.0), BolsaUI.COSTURA, 2.0, 7.0, 5.0)
		draw_string(f, Vector2(44.0, 72.0), "Cofre mágico", HORIZONTAL_ALIGNMENT_LEFT, 400.0, 30, MenuPestanas.TINTA)
		draw_string(f, Vector2(0.0, 72.0), "Lo que guardes aquí estará en todos los cofres mágicos   ", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 44.0, 14, MenuPestanas.TINTA_SUAVE)
		var e: Estado = Estado.i()
		var cuentas: Array = ["%d / %d huecos" % [e.huecos_usados(), e.capacidad], "%d / %d huecos" % [e.almacen_huecos_usados(), Estado.ALMACEN_HUECOS]]
		for col in range(2):
			var x0: float = AlmacenUI.rect_fila(col, 0).position.x
			draw_string(f, Vector2(x0, AlmacenUI.COL_Y - 14.0), AlmacenUI.TITULOS[col], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MenuPestanas.DORADO.darkened(0.25) if ui.columna == col else MenuPestanas.TINTA)
			draw_string(f, Vector2(x0, AlmacenUI.COL_Y - 14.0), cuentas[col], HORIZONTAL_ALIGNMENT_RIGHT, AlmacenUI.COL_ANCHO, 14, MenuPestanas.TINTA_SUAVE)
			var l: Array = ui.lista(col)
			if l.is_empty():
				draw_string(f, Vector2(x0, AlmacenUI.COL_Y + 30.0), "Vacío", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MenuPestanas.TINTA_SUAVE)
			for v in range(AlmacenUI.FILAS_VISIBLES):
				var i: int = ui._scroll[col] + v
				if i >= l.size():
					break
				var fr: Rect2 = AlmacenUI.rect_fila(col, v)
				var sel: bool = ui.columna == col and ui.elegido[col] == i
				_caja(fr, TiendaUI.AMBAR if sel else TiendaUI.FILA, TiendaUI.AMBAR_BORDE if sel else BolsaUI.LINEA, 2 if sel else 1, 9)
				var id: String = l[i][0]
				var t: Texture2D = BolsaUI.tex("objeto_" + id)
				var c := fr.position + Vector2(28.0, fr.size.y * 0.5)
				if t != null:
					draw_texture_rect(t, Rect2(c - Vector2(17, 17), Vector2(34, 34)), false)
				else:
					Objetos.dibujar(self, id, c, 13.0)
				draw_string(f, fr.position + Vector2(56.0, 28.0), Objetos.nombre(id), HORIZONTAL_ALIGNMENT_LEFT, fr.size.x - 120.0, 17, MenuPestanas.TINTA)
				draw_string(f, fr.position + Vector2(0.0, 28.0), "×%d  " % int(l[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, fr.size.x - 10.0, 17, MenuPestanas.TINTA)
			if ui._scroll[col] + AlmacenUI.FILAS_VISIBLES < l.size():
				draw_string(f, Vector2(x0 + AlmacenUI.COL_ANCHO * 0.5 - 6.0, AlmacenUI.rect_fila(col, AlmacenUI.FILAS_VISIBLES - 1).end.y + 14.0), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MenuPestanas.TINTA_SUAVE)
		# Flecha entre columnas: hacia dónde va lo elegido.
		var cx: float = size.x * 0.5
		draw_string(f, Vector2(cx - 30.0, AlmacenUI.COL_Y + 140.0), "→" if ui.columna == 0 else "←", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 34, MenuPestanas.DORADO)
		var ayuda := "[Enter] pasar la pila   [Espacio] pasar una   [← →] columna   [Esc] cerrar"
		draw_string(f, Vector2(0.0, size.y - 34.0), ui.mensaje if ui.mensaje != "" else ayuda, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, MenuPestanas.TINTA)
