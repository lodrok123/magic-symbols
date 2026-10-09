class_name BolsaUI
extends CanvasLayer

## LA MOCHILA: una cuadrícula de 4 columnas. Empieza con 8 huecos (2 filas) y el
## alquimista la amplía hasta 20 (5 filas); los huecos que aún no tienes salen como bloqueados.
## Se abre con I (o la X, o Esc), y al abrirla suena el ruido de la bolsa. Clic en una poción la bebe.
## Fuera de la mochila hay una correa fija abajo con los 8 primeros huecos (con su número) y, a la derecha,
## una ficha de pergamino con el oro, las pociones (Q) y los huecos.
##
## ASPECTO (9/10, encargo del Pipeline): cuero marrón con costura, interior de pergamino como el grimorio.
## Todo se dibuja en código con la paleta de abajo; si existe el arte de `res://poc_25d/ui/` (mochila_panel,
## mochila_solapa, mochila_hueco, mochila_hueco_vacio, mochila_hueco_encima, mochila_hueco_bloqueado, mochila_cerrar,
## mochila_ficha_numero, mochila_correa) se usa en su lugar, pieza a pieza: esperar el arte no bloquea nada.
## La lógica (Estado, Objetos, huecos, beber) no cambia.
##
## APERTURA como el grimorio: tween de 0,35 s que ignora el time_scale, sube desde abajo y escala de 0,9 a 1
## con TRANS_BACK, con un velo negro al 35 % detrás; al cerrar, lo inverso en 0,25 s. El mundo se sigue pausando
## mientras está abierta (como antes) y se reanuda al cerrar y en _exit_tree.

const COLUMNAS: int = 4
const TAM: float = 66.0
const HUECOS_BARRA: int = 8
const TAM_BARRA: float = 46.0
const SEP: float = 6.0

const RUTA_ARTE: String = "res://poc_25d/ui/"
const CUERO: Color = Color("7a4f2e")
const CUERO_SOMBRA: Color = Color("5a3820")
const COSTURA: Color = Color("d2b07a")
const PERGAMINO: Color = Color("efe7d3")
const PERGAMINO_SOMBRA: Color = Color("e3dcc9")
const PERGAMINO_CLARO: Color = Color("f3ebd7")
const LINEA: Color = Color("8b8273")
const TINTA: Color = Color("4e3a26")
## La solapa lleva la tinta oscura del encargo (#4e3a26), pero sobre el cuero #7a4f2e eso da un contraste de 1,5 (no se
## lee); se hace la solapa de un cuero más claro (contraste 5,6) para que el título se vea.
const SOLAPA: Color = Color("d6b883")
const HEBILLA: Color = Color("e0c26a")
const VELO_ALFA: float = 0.35
const T_ABRIR: float = 0.35
const T_CERRAR: float = 0.25
const SUBIDA: float = 90.0

var abierta: bool = false
## Heredado: la textura azul del panel antiguo. Ya no se usa (el panel es de cuero); se deja para no romper a quien la asigne.
var panel_textura: Texture2D = null
var _velo: ColorRect
var _marco: Control
var _panel: PanelContainer
var _solapa: Control
var _cerrar: Control
var _rejilla: GridContainer
var _info: Label
var _barra: HBoxContainer
var _pie: HBoxContainer
var _oro: Label
var _pociones: Label
var _huecos_txt: Label
var _tween: Tween = null

static var _cache_tex: Dictionary = {}


## El arte de `poc_25d/ui/<nombre>.png` si existe, o null (entonces se dibuja en código).
static func tex(nombre: String) -> Texture2D:
	if _cache_tex.has(nombre):
		return _cache_tex[nombre]
	var ruta: String = RUTA_ARTE + nombre + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(ruta):
		t = load(ruta) as Texture2D
	_cache_tex[nombre] = t
	return t


static func _caja(fondo: Color, borde: Color, ancho: int, radio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	s.anti_aliasing = true
	return s


## Contorno de un rectángulo redondeado como lista de puntos (para trazarlo discontinuo: costura, hueco vacío).
static func camino(r: Rect2, radio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad: float = maxf(minf(radio, minf(r.size.x, r.size.y) * 0.5), 0.5)
	var centros: Array = [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var arranque: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in range(4):
		for s in range(7):
			var a: float = float(arranque[k]) + (PI * 0.5) * float(s) / 6.0
			pts.append((centros[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	return pts


## Traza `pts` a trozos: `on` px de línea y `off` de hueco.
static func discontinuo(c: CanvasItem, pts: PackedVector2Array, col: Color, ancho: float, on: float, off: float) -> void:
	var resto: float = on
	var dibuja: bool = true
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var largo: float = a.distance_to(b)
		var pos: float = 0.0
		while pos < largo:
			var paso: float = minf(resto, largo - pos)
			if dibuja:
				c.draw_line(a.lerp(b, pos / largo), a.lerp(b, (pos + paso) / largo), col, ancho, true)
			pos += paso
			resto -= paso
			if resto <= 0.001:
				dibuja = not dibuja
				resto = on if dibuja else off


static func _nueve(t: Texture2D, margen_x: float, margen_y: float) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = margen_x
	s.texture_margin_right = margen_x
	s.texture_margin_top = margen_y
	s.texture_margin_bottom = margen_y
	return s


class Hueco extends Control:
	var id: String = ""
	var cantidad: int = 0
	var bloqueado: bool = false
	var pulsado: Callable
	var _encima: bool = false
	var tam: float = BolsaUI.TAM

	func _ready() -> void:
		custom_minimum_size = Vector2(tam, tam)
		mouse_entered.connect(func(): _encima = true; queue_redraw())
		mouse_exited.connect(func(): _encima = false; queue_redraw())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var estado: String = "bloqueado" if bloqueado else ("encima" if _encima else ("lleno" if id != "" else "vacio"))
		var arte: Texture2D = BolsaUI.tex("mochila_hueco" if estado == "lleno" else "mochila_hueco_" + estado)
		if arte != null:
			draw_texture_rect(arte, r, false)
		else:
			var rad: float = clampf(size.x * 0.14, 5.0, 10.0)
			match estado:
				"bloqueado":
					# Borde al 25 % y sin relleno.
					draw_polyline(BolsaUI.camino(r.grow(-1.5), rad), Color(BolsaUI.LINEA, 0.25), 2.0, true)
				"lleno":
					BolsaUI._caja(BolsaUI.PERGAMINO_SOMBRA, BolsaUI.LINEA, 2, int(rad)).draw(get_canvas_item(), r)
				"encima":
					BolsaUI._caja(BolsaUI.PERGAMINO_CLARO, BolsaUI.LINEA, 3, int(rad)).draw(get_canvas_item(), r)
				_:
					BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-1.5), rad), BolsaUI.LINEA, 2.0, 6.0, 4.0)
		if bloqueado or id == "":
			return
		# Arte propio del objeto (poc_25d/ui/objeto_<id>.png) si existe; si no, el dibujo en código de Objetos.
		var icono: Texture2D = BolsaUI.tex("objeto_" + id)
		if icono != null:
			var lado: float = size.x * 0.62
			draw_texture_rect(icono, Rect2(size * 0.5 + Vector2(-lado * 0.5, -lado * 0.5 - 3.0), Vector2(lado, lado)), false)
		else:
			Objetos.dibujar(self, id, size * 0.5 + Vector2(0, -3), size.x * 0.26)
		if cantidad > 1:
			var f: Font = ThemeDB.fallback_font
			var cuerpo: int = maxi(13, int(size.x * 0.3))
			var pos := Vector2(0.0, size.y - 6.0)
			# Tinta oscura con halo de pergamino: se lee sobre el icono sea del color que sea.
			draw_string_outline(f, pos, str(cantidad), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, cuerpo, 5, BolsaUI.PERGAMINO)
			draw_string(f, pos, str(cantidad), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, cuerpo, BolsaUI.TINTA)

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT and id != "" and pulsado.is_valid():
			pulsado.call(id)


## El marco de cuero con el interior de pergamino y la costura. Se dibuja entero aquí (el estilo del contenedor va vacío:
## el `_draw` de un script se ejecuta ANTES que el estilo del PanelContainer y lo taparía).
class Cuero extends PanelContainer:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var arte: Texture2D = BolsaUI.tex("mochila_panel")
		if arte != null:
			draw_style_box(BolsaUI._nueve(arte, 48.0, 48.0), r)
			return
		BolsaUI._caja(BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 22).draw(get_canvas_item(), r)
		BolsaUI._caja(BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 12).draw(get_canvas_item(), r.grow(-20.0))
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-8.0), 16.0), BolsaUI.COSTURA, 2.0, 7.0, 5.0)


## La correa de abajo: cuero con costura que lleva los 8 huecos.
class Correa extends PanelContainer:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var arte: Texture2D = BolsaUI.tex("mochila_correa")
		if arte != null:
			draw_style_box(BolsaUI._nueve(arte, 24.0, 12.0), r)
			return
		BolsaUI._caja(BolsaUI.CUERO, BolsaUI.CUERO_SOMBRA, 3, 14).draw(get_canvas_item(), r)
		BolsaUI.discontinuo(self, BolsaUI.camino(r.grow(-5.0), 10.0), BolsaUI.COSTURA, 1.5, 6.0, 4.0)


## Ficha de pergamino con borde de tinta: el oro y las pociones.
class Ficha extends PanelContainer:
	func _draw() -> void:
		BolsaUI._caja(BolsaUI.PERGAMINO, BolsaUI.LINEA, 2, 10).draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


## La solapa con hebilla que hace de cartela del título. Cuelga del borde de arriba, centrada; no tapa huecos.
class Solapa extends Control:
	var texto: String = "Mochila"

	func _init() -> void:
		custom_minimum_size = Vector2(230.0, 48.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var arte: Texture2D = BolsaUI.tex("mochila_solapa")
		if arte != null:
			draw_texture_rect(arte, Rect2(Vector2.ZERO, size), false)
		else:
			var forma := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - 14.0), Vector2(w * 0.5, h), Vector2(0, h - 14.0)])
			draw_colored_polygon(forma, BolsaUI.SOLAPA)
			var borde := PackedVector2Array(forma)
			borde.append(forma[0])
			draw_polyline(borde, BolsaUI.CUERO_SOMBRA, 3.0, true)
			var costura := PackedVector2Array([Vector2(7, 6), Vector2(w - 7.0, 6), Vector2(w - 7.0, h - 19.0), Vector2(w * 0.5, h - 9.0), Vector2(7, h - 19.0), Vector2(7, 6)])
			BolsaUI.discontinuo(self, costura, BolsaUI.CUERO, 1.5, 5.0, 4.0)
			# Hebilla pequeña en la punta.
			var hb := Rect2(Vector2(w * 0.5 - 7.0, h - 17.0), Vector2(14.0, 12.0))
			draw_rect(hb, BolsaUI.HEBILLA)
			draw_rect(hb, BolsaUI.CUERO_SOMBRA, false, 1.5)
			draw_rect(Rect2(hb.position + Vector2(5.0, 3.0), Vector2(4.0, 6.0)), BolsaUI.CUERO_SOMBRA)
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(0.0, h * 0.5 + 6.0), texto, HORIZONTAL_ALIGNMENT_CENTER, w, 22, BolsaUI.TINTA)


## El botón redondo de cuero con una X.
class Cerrar extends Control:
	signal pulsado
	var _encima: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(32.0, 32.0)
		size = Vector2(32.0, 32.0)
		tooltip_text = "Cerrar [I / Esc]"
		mouse_entered.connect(func(): _encima = true; queue_redraw())
		mouse_exited.connect(func(): _encima = false; queue_redraw())

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var arte: Texture2D = BolsaUI.tex("mochila_cerrar")
		if arte != null:
			draw_texture_rect(arte, Rect2(Vector2.ZERO, size), false, Color(1.15, 1.15, 1.15) if _encima else Color.WHITE)
			return
		var relleno: Color = BolsaUI.CUERO.lightened(0.18) if _encima else BolsaUI.CUERO
		draw_circle(c, 16.0, BolsaUI.CUERO_SOMBRA)
		draw_circle(c, 14.0, relleno)
		draw_arc(c, 11.0, 0.0, TAU, 24, BolsaUI.COSTURA, 1.2, true)
		draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), BolsaUI.PERGAMINO, 2.5, true)
		draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), BolsaUI.PERGAMINO, 2.5, true)

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			pulsado.emit()


## La ficha con el número (1–8) encima de cada hueco de la barra.
class FichaNumero extends Control:
	var numero: int = 1

	func _init() -> void:
		custom_minimum_size = Vector2(24.0, 18.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var arte: Texture2D = BolsaUI.tex("mochila_ficha_numero")
		if arte != null:
			draw_texture_rect(arte, r, false)
		else:
			BolsaUI._caja(BolsaUI.CUERO_SOMBRA, BolsaUI.COSTURA, 1, 6).draw(get_canvas_item(), r)
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(0.0, size.y - 4.0), str(numero), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, BolsaUI.PERGAMINO)


static func _etiqueta(tam_fuente: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam_fuente)
	l.add_theme_color_override("font_color", TINTA)
	return l


static func _margenes(s: StyleBox, izq: float, arr: float, der: float, aba: float) -> void:
	s.content_margin_left = izq
	s.content_margin_top = arr
	s.content_margin_right = der
	s.content_margin_bottom = aba


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Velo negro al 35 % detrás de la mochila (solo mientras está abierta: si no, no estorba al ratón).
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.visible = false
	add_child(_velo)

	# La barra de la mochila, siempre a la vista abajo: correa con los 8 primeros huecos y, a la derecha, la ficha del oro.
	_pie = HBoxContainer.new()
	_pie.add_theme_constant_override("separation", 12)
	_pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pie)
	_pie.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pie.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pie.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pie.offset_right = -16.0
	_pie.offset_bottom = -16.0

	var correa := Correa.new()
	var sb_vacio := StyleBoxEmpty.new()
	_margenes(sb_vacio, 14.0, 10.0, 14.0, 12.0)
	correa.add_theme_stylebox_override("panel", sb_vacio)
	correa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pie.add_child(correa)
	_barra = HBoxContainer.new()
	_barra.add_theme_constant_override("separation", 5)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	correa.add_child(_barra)

	var ficha := Ficha.new()
	var sb_ficha := StyleBoxEmpty.new()
	_margenes(sb_ficha, 14.0, 10.0, 14.0, 10.0)
	ficha.add_theme_stylebox_override("panel", sb_ficha)
	ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ficha.size_flags_vertical = Control.SIZE_SHRINK_END
	_pie.add_child(ficha)
	var lineas := VBoxContainer.new()
	lineas.add_theme_constant_override("separation", 2)
	lineas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ficha.add_child(lineas)
	_oro = _etiqueta(16)
	_pociones = _etiqueta(15)
	_huecos_txt = _etiqueta(15)
	for l in [_oro, _pociones, _huecos_txt]:
		lineas.add_child(l)

	# La mochila abierta: _marco (se anima) -> _panel (cuero) + botón de cerrar.
	_marco = Control.new()
	_marco.visible = false
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marco)

	_panel = Cuero.new()
	var sb_panel := StyleBoxEmpty.new()
	_margenes(sb_panel, 36.0, 22.0, 36.0, 34.0)
	_panel.add_theme_stylebox_override("panel", sb_panel)
	_marco.add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	# La solapa cuelga del borde de arriba, centrada, y es el título.
	_solapa = Solapa.new()
	_solapa.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(_solapa)

	var filas: int = int(ceil(float(Estado.CAPACIDAD_MAX) / float(COLUMNAS)))
	_rejilla = GridContainer.new()
	_rejilla.columns = COLUMNAS
	_rejilla.add_theme_constant_override("h_separation", int(SEP))
	_rejilla.add_theme_constant_override("v_separation", int(SEP))
	# Alto fijo (los 20 huecos, aunque aún no estén creados): así el marco mide lo mismo al abrir y no salta.
	_rejilla.custom_minimum_size = Vector2(COLUMNAS * TAM + (COLUMNAS - 1) * SEP, filas * TAM + (filas - 1) * SEP)
	caja.add_child(_rejilla)

	_info = _etiqueta(14)
	_info.custom_minimum_size = Vector2(COLUMNAS * (TAM + SEP), 40.0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(_info)

	var pista := _etiqueta(13)
	pista.add_theme_color_override("font_color", Color(TINTA, 0.8))
	pista.text = "[I / Esc] cerrar     clic en una poción: beber"
	caja.add_child(pista)

	_cerrar = Cerrar.new()
	_cerrar.pulsado.connect(func(): if abierta: alternar())
	_marco.add_child(_cerrar)

	get_viewport().size_changed.connect(_colocar)
	Estado.i().cambiado.connect(_refrescar)
	_refrescar()


func _exit_tree() -> void:
	# Cambiar de escena con la mochila abierta no puede dejar el mundo pausado.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if abierta and is_inside_tree():
		get_tree().paused = false


## Mide el marco, lo centra y devuelve la posición de reposo.
func _colocar() -> Vector2:
	if _panel == null:
		return Vector2.ZERO
	_panel.size = _panel.get_combined_minimum_size()
	_marco.size = _panel.size
	_marco.pivot_offset = _marco.size * 0.5
	_cerrar.position = Vector2(_marco.size.x - 40.0, 3.0)
	var vista: Vector2 = get_viewport().get_visible_rect().size
	var reposo: Vector2 = ((vista - _marco.size) * 0.5).round()
	# Que la mochila no tape la correa de abajo (~110 px con su margen) si la ventana es baja.
	reposo.y = maxf(8.0, minf(reposo.y, vista.y - 110.0 - _marco.size.y))
	if abierta and (_tween == null or not _tween.is_running()):
		_marco.position = reposo
	return reposo


func alternar() -> void:
	abierta = not abierta
	Sonidos.play(self, "bolsa", -4.0, 1.0 if abierta else 0.85)
	get_tree().paused = abierta
	_refrescar()
	_animar(abierta)


## Abre/cierra como el grimorio: sube desde abajo y escala de 0,9 a 1 con TRANS_BACK, con el velo; al cerrar, lo inverso
## más rápido. El tween ignora el time_scale y corre aunque el árbol esté pausado.
func _animar(abre: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var reposo: Vector2 = _colocar()
	var fuera: Vector2 = reposo + Vector2(0.0, SUBIDA)
	_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if abre:
		_marco.visible = true
		_velo.visible = true
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_marco.mouse_filter = Control.MOUSE_FILTER_PASS
		_marco.position = fuera
		_marco.scale = Vector2(0.9, 0.9)
		_marco.modulate.a = 0.0
		_velo.color.a = 0.0
		_tween.tween_property(_marco, "position", reposo, T_ABRIR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_marco, "scale", Vector2.ONE, T_ABRIR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_marco, "modulate:a", 1.0, T_ABRIR * 0.6)
		_tween.tween_property(_velo, "color:a", VELO_ALFA, T_ABRIR)
	else:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tween.tween_property(_marco, "position", fuera, T_CERRAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_property(_marco, "scale", Vector2(0.9, 0.9), T_CERRAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_tween.tween_property(_marco, "modulate:a", 0.0, T_CERRAR)
		_tween.tween_property(_velo, "color:a", 0.0, T_CERRAR)
		_tween.chain().tween_callback(_ocultar)


func _ocultar() -> void:
	if abierta:
		return
	_marco.visible = false
	_velo.visible = false


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_I:
		get_viewport().set_input_as_handled()
		alternar()
	elif k.keycode == KEY_ESCAPE and abierta:
		get_viewport().set_input_as_handled()
		alternar()


func _refrescar() -> void:
	var e: Estado = Estado.i()
	_oro.text = "Oro  %d" % e.oro
	_pociones.text = "[Q] Poción x%d" % e.cuenta("pocion")
	_huecos_txt.text = "[I] Mochila %d/%d" % [e.huecos_usados(), e.capacidad]
	_refrescar_barra(e)
	if not abierta:
		return
	for h in _rejilla.get_children():
		h.queue_free()
	# Una entrada por pila (si hay más de 9, ocupa varios huecos)
	var pilas: Array = _pilas(e)
	for i in range(Estado.CAPACIDAD_MAX):
		var h := Hueco.new()
		h.bloqueado = i >= e.capacidad
		if i < pilas.size() and not h.bloqueado:
			h.id = String(pilas[i][0])
			h.cantidad = int(pilas[i][1])
			h.tooltip_text = "%s\n%s" % [Objetos.nombre(h.id), String(Objetos.DATOS.get(h.id, {}).get("desc", ""))]
			h.pulsado = _usar
		elif h.bloqueado:
			h.tooltip_text = "Hueco bloqueado: el alquimista puede ampliar la mochila"
		_rejilla.add_child(h)
	_info.text = "%d/%d huecos. Pasa el ratón sobre un objeto para ver qué es." % [e.huecos_usados(), e.capacidad]


func _usar(id: String) -> void:
	if id == "pocion":
		var j: Node = get_tree().get_first_node_in_group("player")
		if j != null and j.has_method("usar_pocion"):
			# En 3D el jugador solo bebe con el árbol en marcha: se cierra la mochila antes (y se reanuda el mundo).
			if abierta and j.get("jugador") != null:
				alternar()
			j.call("usar_pocion")


func _pilas(e: Estado) -> Array:
	var pilas: Array = []
	for id in e.items:
		var n: int = int(e.items[id])
		while n > 0:
			pilas.append([id, mini(n, Estado.PILA_MAX)])
			n -= Estado.PILA_MAX
	return pilas


func _refrescar_barra(e: Estado) -> void:
	if _barra == null:
		return
	for h in _barra.get_children():
		h.queue_free()
	var pilas: Array = _pilas(e)
	for i in range(HUECOS_BARRA):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := FichaNumero.new()
		num.numero = i + 1
		num.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(num)
		var h := Hueco.new()
		h.tam = TAM_BARRA
		h.bloqueado = i >= e.capacidad
		if i < pilas.size() and not h.bloqueado:
			h.id = String(pilas[i][0])
			h.cantidad = int(pilas[i][1])
			h.tooltip_text = Objetos.nombre(h.id)
			h.pulsado = _usar
		col.add_child(h)
		_barra.add_child(col)
