class_name BolsaUI
extends CanvasLayer

## LA MOCHILA: una cuadrícula de 4 columnas. Empieza con 8 huecos (2 filas) y el
## alquimista la amplía hasta 20 (5 filas); los huecos que aún no tienes salen oscuros.
## Se abre con I, y al abrirla suena el ruido de la bolsa. Clic en una poción la bebe.
## Fuera de la mochila hay un pequeño aviso fijo con el oro, las pociones (Q) y los huecos.

const COLUMNAS: int = 4
const TAM: float = 66.0

var abierta: bool = false
var panel_textura: Texture2D = null
var _panel: PanelContainer
var _rejilla: GridContainer
var _info: Label
var _hud: Label
var _titulo: Label
var _barra: HBoxContainer
const HUECOS_BARRA: int = 8
const TAM_BARRA: float = 46.0


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
		var fondo: Color = Color(0.05, 0.05, 0.08, 0.9) if bloqueado else Color(0.16, 0.2, 0.34, 0.95)
		if _encima and not bloqueado:
			fondo = fondo.lightened(0.15)
		draw_rect(r, fondo)
		draw_rect(r, Color(0.55, 0.65, 0.9, 0.5 if not bloqueado else 0.15), false, 2.0)
		if bloqueado:
			var f: Font = ThemeDB.fallback_font
			draw_string(f, Vector2(0, size.y * 0.58), "🔒" if false else "—", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.2))
			return
		if id != "":
			Objetos.dibujar(self, id, size * 0.5 + Vector2(0, -3), size.x * 0.26)
			if cantidad > 1:
				var f2: Font = ThemeDB.fallback_font
				draw_string(f2, Vector2(0, size.y - 5.0), str(cantidad), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, int(size.x * 0.23), Color(1, 1, 1))

	func _gui_input(event: InputEvent) -> void:
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT and id != "" and pulsado.is_valid():
			pulsado.call(id)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hud.offset_left = -330.0
	_hud.offset_right = -16.0
	_hud.offset_top = 14.0
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hud)

	# La barra de la mochila, siempre a la vista abajo: los 8 primeros huecos.
	_barra = HBoxContainer.new()
	_barra.add_theme_constant_override("separation", 4)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_barra)
	_barra.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_barra.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_barra.offset_right = -16.0
	_barra.offset_bottom = -16.0

	_panel = PanelContainer.new()
	_panel.visible = false
	if panel_textura != null:
		var estilo := StyleBoxTexture.new()
		estilo.texture = panel_textura
		for lado in ["left", "right", "top", "bottom"]:
			estilo.set("texture_margin_" + lado, 18.0)
			estilo.set("content_margin_" + lado, 24.0)
		estilo.modulate_color = Color(0.10, 0.13, 0.26, 0.97)
		_panel.add_theme_stylebox_override("panel", estilo)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 20)
	_titulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	caja.add_child(_titulo)

	_rejilla = GridContainer.new()
	_rejilla.columns = COLUMNAS
	_rejilla.add_theme_constant_override("h_separation", 6)
	_rejilla.add_theme_constant_override("v_separation", 6)
	caja.add_child(_rejilla)

	_info = Label.new()
	_info.custom_minimum_size = Vector2(COLUMNAS * (TAM + 6.0), 40.0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))
	caja.add_child(_info)

	var pista := Label.new()
	pista.text = "[I / Esc] cerrar     clic en una poción: beber"
	pista.add_theme_font_size_override("font_size", 13)
	pista.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.7))
	caja.add_child(pista)

	Estado.i().cambiado.connect(_refrescar)
	_refrescar()


func alternar() -> void:
	abierta = not abierta
	_panel.visible = abierta
	Sonidos.play(self, "bolsa", -4.0, 1.0 if abierta else 0.85)
	get_tree().paused = abierta
	_refrescar()


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
	_hud.text = "[Q] Poción x%d     [I] Mochila %d/%d" % [
		e.cuenta("pocion"), e.huecos_usados(), e.capacidad]
	_refrescar_barra(e)
	if not abierta:
		return
	_titulo.text = "Mochila  (%d/%d)" % [e.huecos_usados(), e.capacidad]
	for h in _rejilla.get_children():
		h.queue_free()
	# Una entrada por pila (si hay más de 9, ocupa varios huecos)
	var pilas: Array = []
	for id in e.items:
		var n: int = int(e.items[id])
		while n > 0:
			pilas.append([id, mini(n, Estado.PILA_MAX)])
			n -= Estado.PILA_MAX
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
	_info.text = "Pasa el ratón sobre un objeto para ver qué es."


func _usar(id: String) -> void:
	if id == "pocion":
		var j: Node = get_tree().get_first_node_in_group("player")
		if j != null:
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
		var h := Hueco.new()
		h.tam = TAM_BARRA
		h.bloqueado = i >= e.capacidad
		if i < pilas.size() and not h.bloqueado:
			h.id = String(pilas[i][0])
			h.cantidad = int(pilas[i][1])
			h.tooltip_text = Objetos.nombre(h.id)
			h.pulsado = _usar
		_barra.add_child(h)
