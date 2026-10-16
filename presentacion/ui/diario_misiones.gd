class_name DiarioMisiones
extends CanvasLayer

## EL DIARIO DE MISIONES (Fase 14.3, 16/10, Juego): la pantalla del «Adventure Log» (tecla J). Lista a la izquierda (icono de tipo,
## radio de «seguida», título), ficha a la derecha (título, texto, objetivos con casilla, recompensa y, abajo a la derecha, el origen).
## Solo LEE de `Misiones.i()` y solo escribe una cosa: qué misión se sigue (`seguir`).
##
## Manejo. Ratón: clic en una fila la abre; clic en su radio la sigue. Teclado: ↑/↓ cambian de misión, Enter/Espacio siguen la abierta,
## J o Esc cierran. Como la mochila, pausa el mundo mientras está abierto y lo reanuda al cerrar (y en `_exit_tree`).
## Arte: el arte del Pipeline (`res://presentacion/ui/laminas/diario_*.png`: panel, icono_principal, icono_secundaria) se usa si existe; si no
## todo se dibuja en código con la paleta de la mochila (placeholder). La lógica no depende del arte.
##
## Para las pruebas: `abrir()`, `cerrar()`, `mover(+1/-1)`, `alternar_seguida()`, `seleccionada`, `filas()` y `ficha()` son públicos.

const ANCHO: float = 780.0
const ALTO: float = 470.0
const ANCHO_LISTA: float = 270.0
const ALTO_FILA: float = 44.0
const ALPHA_VELO: float = 0.45

var abierto: bool = false
var seleccionada: String = ""
var _velo: ColorRect
var _panel: Control
var _lista: Control
var _ficha: Control
var _m: Misiones = null
var _pausado_por_mi: bool = false


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.visible = false
	add_child(_velo)
	_panel = Fondo.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.size = Vector2(ANCHO, ALTO)
	add_child(_panel)
	_lista = Lista.new()
	_lista.diario = self
	_lista.position = Vector2(26.0, 64.0)
	_lista.size = Vector2(ANCHO_LISTA, ALTO - 96.0)
	_panel.add_child(_lista)
	_ficha = Ficha.new()
	_ficha.diario = self
	_ficha.position = Vector2(ANCHO_LISTA + 54.0, 64.0)
	_ficha.size = Vector2(ANCHO - ANCHO_LISTA - 80.0, ALTO - 96.0)
	_panel.add_child(_ficha)
	get_viewport().size_changed.connect(_colocar)
	_enganchar()


func _exit_tree() -> void:
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false


func _process(_delta: float) -> void:
	if _m != Misiones.i():
		_enganchar()


func _enganchar() -> void:
	if _m != null:
		if _m.mision_cambio.is_connected(_on_cambio):
			_m.mision_cambio.disconnect(_on_cambio)
		if _m.seguida_cambio.is_connected(_on_cambio):
			_m.seguida_cambio.disconnect(_on_cambio)
	_m = Misiones.i()
	_m.mision_cambio.connect(_on_cambio)
	_m.seguida_cambio.connect(_on_cambio)
	_repintar()


func _on_cambio(_id: String) -> void:
	_repintar()


func _repintar() -> void:
	var ids: Array = _m.lista_para_diario()
	if not ids.has(seleccionada):
		seleccionada = String(ids[0]) if not ids.is_empty() else ""
	if _lista != null:
		_lista.queue_redraw()
		_ficha.queue_redraw()


func _colocar() -> void:
	if _panel == null:
		return
	var vista: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = ((vista - _panel.size) * 0.5).round()


## --- Datos para pintar (y para las pruebas) ---

## Las filas de la lista: [{id, titulo, tipo, estado, seguida}], en el orden del diario.
func filas() -> Array:
	var r: Array = []
	for id in _m.lista_para_diario():
		var d: Dictionary = _m.get_mision(id)
		r.append({"id": id, "titulo": d["titulo"], "tipo": d["tipo"], "estado": d["estado"], "seguida": id == _m.seguida_id()})
	return r


## La ficha de una misión: {titulo, tipo, estado, texto, objetivos [{texto, hecho}], origen, recompensa (texto), seguida}. {} si no existe.
func ficha(id: String) -> Dictionary:
	if not _m.existe(id):
		return {}
	var d: Dictionary = _m.get_mision(id)
	var rec: Dictionary = d["recompensa"]
	var partes: Array = []
	if int(rec.get("oro", 0)) > 0:
		partes.append("%d de oro" % int(rec["oro"]))
	for item in (rec.get("items", {}) as Dictionary):
		partes.append("%d × %s" % [int((rec["items"] as Dictionary)[item]), Objetos.nombre(String(item))])
	return {"titulo": d["titulo"], "tipo": d["tipo"], "estado": d["estado"], "texto": d["texto"], "objetivos": d["objetivos"],
		"origen": d["origen"], "recompensa": ", ".join(partes), "seguida": id == _m.seguida_id()}


## --- Abrir, cerrar, moverse ---

func alternar() -> void:
	if abierto:
		cerrar()
	else:
		abrir()


func abrir() -> void:
	if abierto:
		return
	# Con otra pantalla que ya pausa (mochila, libro) no se abre encima.
	if is_inside_tree() and get_tree().paused:
		return
	abierto = true
	_repintar()
	_colocar()
	_velo.visible = true
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.color.a = ALPHA_VELO
	_panel.visible = true
	if is_inside_tree():
		get_tree().paused = true
		_pausado_por_mi = true
	Sfx.play(self, "libro_abre")


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	_panel.visible = false
	_velo.visible = false
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pausado_por_mi and is_inside_tree():
		get_tree().paused = false
	_pausado_por_mi = false
	Sfx.play(self, "libro_cierra")


## Pasa a la misión de abajo (+1) o de arriba (-1); no da la vuelta.
func mover(paso: int) -> void:
	var ids: Array = _m.lista_para_diario()
	if ids.is_empty():
		return
	var i: int = clampi(ids.find(seleccionada) + paso, 0, ids.size() - 1)
	seleccionada = String(ids[i])
	_lista.queue_redraw()
	_ficha.queue_redraw()


func seleccionar(id: String) -> void:
	if _m.existe(id) and _m.lista_para_diario().has(id):
		seleccionada = id
		_lista.queue_redraw()
		_ficha.queue_redraw()


## Sigue la misión abierta (o deja de seguirla si ya era la seguida). Solo las activas se pueden seguir.
func alternar_seguida() -> void:
	if seleccionada == "":
		return
	if _m.seguida_id() == seleccionada:
		_m.seguir("")
	else:
		_m.seguir(seleccionada)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_J:
		get_viewport().set_input_as_handled()
		alternar()
	elif abierto:
		match k.keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				cerrar()
			KEY_UP:
				get_viewport().set_input_as_handled()
				mover(-1)
			KEY_DOWN:
				get_viewport().set_input_as_handled()
				mover(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				get_viewport().set_input_as_handled()
				alternar_seguida()


## --- Dibujo ---

const PERGAMINO: Color = Color("efe7d3")
const TINTA: Color = Color("4e3a26")
const TINTA_SUAVE: Color = Color(0.31, 0.23, 0.15, 0.55)
const CUERO: Color = Color("7a4f2e")
const COSTURA: Color = Color("d2b07a")
const SELECCION: Color = Color("e3dcc9")
const DORADO: Color = Color("c9962b")


## El fondo del panel (arte `diario_panel` si existe; si no, cuero con pergamino como la mochila).
class Fondo extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var arte: Texture2D = BolsaUI.tex("diario_panel")
		if arte != null:
			draw_style_box(BolsaUI._nueve(arte, 48.0, 48.0), r)
		else:
			BolsaUI._caja(DiarioMisiones.CUERO, Color("5a3820"), 3, 22).draw(get_canvas_item(), r)
			BolsaUI._caja(DiarioMisiones.PERGAMINO, Color("8b8273"), 2, 12).draw(get_canvas_item(), r.grow(-18.0))
			BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 16.0), DiarioMisiones.COSTURA, 2.0, 7.0, 5.0)
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(0.0, 44.0), "Diario de misiones", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, DiarioMisiones.TINTA)
		draw_line(Vector2(DiarioMisiones.ANCHO_LISTA + 40.0, 62.0), Vector2(DiarioMisiones.ANCHO_LISTA + 40.0, size.y - 34.0), DiarioMisiones.TINTA_SUAVE, 1.5)
		draw_string(f, Vector2(24.0, size.y - 16.0), "[J / Esc] cerrar    [↑↓] elegir    [Enter] seguir", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DiarioMisiones.TINTA_SUAVE)


class Lista extends Control:
	var diario: DiarioMisiones

	func _draw() -> void:
		if diario == null:
			return
		var f: Font = ThemeDB.fallback_font
		var y: float = 0.0
		var filas: Array = diario.filas()
		if filas.is_empty():
			draw_string(f, Vector2(4.0, 24.0), "Aún no tienes misiones.", HORIZONTAL_ALIGNMENT_LEFT, size.x, 15, DiarioMisiones.TINTA_SUAVE)
			return
		for fila in filas:
			var r := Rect2(0.0, y, size.x, DiarioMisiones.ALTO_FILA - 4.0)
			var elegida: bool = fila["id"] == diario.seleccionada
			if elegida:
				BolsaUI._caja(DiarioMisiones.SELECCION, Color("8b8273"), 2, 8).draw(get_canvas_item(), r)
			var gris: bool = fila["estado"] == "completa"
			var col: Color = DiarioMisiones.TINTA_SUAVE if gris else DiarioMisiones.TINTA
			_icono(Vector2(18.0, y + r.size.y * 0.5), String(fila["tipo"]), col)
			var titulo: String = String(fila["titulo"]) + ("  ✓" if gris else "")
			draw_string(f, Vector2(38.0, y + r.size.y * 0.5 + 5.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, size.x - 74.0, 15, col)
			# El radio de «seguida» a la derecha: lleno si se sigue, vacío si no (y apagado si no está activa).
			var c := Vector2(size.x - 18.0, y + r.size.y * 0.5)
			draw_arc(c, 7.0, 0.0, TAU, 20, col, 1.8, true)
			if bool(fila["seguida"]):
				draw_circle(c, 4.0, DiarioMisiones.DORADO)
			y += DiarioMisiones.ALTO_FILA

	## Principal: estrella; secundaria: rombo. (El arte del Pipeline sustituye a esto con `diario_icono_*`.)
	func _icono(p: Vector2, tipo: String, col: Color) -> void:
		var arte: Texture2D = BolsaUI.tex("diario_icono_" + tipo)
		if arte != null:
			draw_texture_rect(arte, Rect2(p - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false)
		elif tipo == "principal":
			var pts := PackedVector2Array()
			for k in range(10):
				var a: float = -PI * 0.5 + TAU * float(k) / 10.0
				pts.append(p + Vector2(cos(a), sin(a)) * (9.0 if k % 2 == 0 else 4.0))
			draw_colored_polygon(pts, col)
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 0), p + Vector2(0, 8), p + Vector2(-7, 0)]), col)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or diario == null:
			return
		var i: int = int(mb.position.y / DiarioMisiones.ALTO_FILA)
		var filas: Array = diario.filas()
		if i < 0 or i >= filas.size():
			return
		diario.seleccionar(String(filas[i]["id"]))
		if mb.position.x > size.x - 34.0:
			diario.alternar_seguida()


class Ficha extends Control:
	var diario: DiarioMisiones

	func _draw() -> void:
		if diario == null:
			return
		var d: Dictionary = diario.ficha(diario.seleccionada)
		var f: Font = ThemeDB.fallback_font
		if d.is_empty():
			return
		var y: float = 22.0
		draw_string(f, Vector2(0.0, y), String(d["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, size.x, 22, DiarioMisiones.TINTA)
		y += 22.0
		var etiqueta: String = "Misión principal" if d["tipo"] == "principal" else "Misión secundaria"
		if d["estado"] == "completa":
			etiqueta += " · completada"
		elif d["seguida"]:
			etiqueta += " · seguida"
		draw_string(f, Vector2(0.0, y), etiqueta, HORIZONTAL_ALIGNMENT_LEFT, size.x, 12, DiarioMisiones.TINTA_SUAVE)
		y += 22.0
		# El texto de 2–3 frases, partido en líneas del ancho de la ficha.
		var linea: PackedStringArray = _partir(f, String(d["texto"]), size.x, 14)
		for l in linea:
			draw_string(f, Vector2(0.0, y), l, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, DiarioMisiones.TINTA)
			y += 19.0
		y += 12.0
		for o in d["objetivos"]:
			var hecho: bool = bool(o["hecho"])
			var caja := Rect2(0.0, y - 13.0, 15.0, 15.0)
			draw_rect(caja, DiarioMisiones.TINTA_SUAVE if hecho else DiarioMisiones.TINTA, false, 1.8)
			if hecho:
				draw_line(caja.position + Vector2(3, 8), caja.position + Vector2(6.5, 12), DiarioMisiones.DORADO, 2.4, true)
				draw_line(caja.position + Vector2(6.5, 12), caja.position + Vector2(13, 2), DiarioMisiones.DORADO, 2.4, true)
			draw_string(f, Vector2(24.0, y), String(o["texto"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 14, DiarioMisiones.TINTA_SUAVE if hecho else DiarioMisiones.TINTA)
			y += 23.0
		if String(d["recompensa"]) != "":
			draw_string(f, Vector2(0.0, size.y - 30.0), "Recompensa: " + String(d["recompensa"]), HORIZONTAL_ALIGNMENT_LEFT, size.x, 13, DiarioMisiones.TINTA)
		if String(d["origen"]) != "":
			draw_string(f, Vector2(0.0, size.y - 8.0), String(d["origen"]), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 13, DiarioMisiones.TINTA_SUAVE)

	static func _partir(f: Font, texto: String, ancho: float, cuerpo: int) -> PackedStringArray:
		var lineas := PackedStringArray()
		var actual: String = ""
		for palabra in texto.split(" "):
			var prueba: String = palabra if actual == "" else actual + " " + palabra
			if f.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x > ancho and actual != "":
				lineas.append(actual)
				actual = palabra
			else:
				actual = prueba
		if actual != "":
			lineas.append(actual)
		return lineas
