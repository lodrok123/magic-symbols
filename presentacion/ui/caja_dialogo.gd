class_name CajaDialogo
extends CanvasLayer
## LA CAJA DE DIÁLOGO DE PERGAMINO (sacada el 14/11 de escenas/bosque_01_v01_3d.gd, commit 256b1756, para usarla en cualquier nivel).
## Papel claro con borde, el NOMBRE de quien habla en serif negrita, el texto debajo y la tecla para seguir a la derecha.
## Uso: `caja.text = "Marimanta · El grimorio de Leonardo…"` (lo de antes de « · » es el nombre; sin él, es narración) o `caja.decir(nombre, texto)`.
## `text = ""` la esconde. Se esconde sola a los `dura_s` s (0 = no).

var _panel: PanelContainer
var _nombre: Label
var _texto: Label
var _tecla: Label
var _t := 0.0
var dura_s := 0.0
var tecla := ""

var text: String = "":
	set(v):
		text = v
		if not is_node_ready():
			return
		var trozos := v.split(" · ", true, 1)
		if trozos.size() == 2 and trozos[0].length() <= 24:
			decir(trozos[0], trozos[1])
		else:
			decir("", v)


func _ready() -> void:
	layer = 11
	var raiz := Control.new()
	add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	raiz.add_child(_panel)
	_panel.add_to_group("dialogo_pergamino")
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -76.0
	_panel.offset_top = -76.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var papel := TemaInterfaz.caja_panel(TemaInterfaz.PERGAMINO_DIALOGO, Color("947047"), 1)
	papel.content_margin_left = 20.0
	papel.content_margin_right = 20.0
	papel.content_margin_top = 12.0
	papel.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", papel)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 5)
	_panel.add_child(columna)
	_nombre = _linea(columna, 19, Color("6b4827"))
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	serif.font_weight = 700
	_nombre.add_theme_font_override("font", serif)
	_texto = _linea(columna, 21, Color("32271e"))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tecla = _linea(columna, 15, TemaInterfaz.TINTA_PERGAMINO)
	_tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	raiz.resized.connect(_ajustar_ancho.bind(raiz))
	_ajustar_ancho(raiz)
	_panel.hide()
	if text != "":
		text = text


func decir(nombre: String, texto: String) -> void:
	_t = 0.0
	if texto.strip_edges() == "":
		_panel.hide()
		return
	_nombre.text = nombre
	_nombre.visible = nombre != ""
	_texto.text = texto
	_tecla.text = tecla
	_tecla.visible = tecla != ""
	_panel.show()
	_ajustar_alto.call_deferred()


func _process(delta: float) -> void:
	if dura_s > 0.0 and _panel.visible:
		_t += delta
		if _t >= dura_s:
			_panel.hide()


func _ajustar_ancho(raiz: Control) -> void:
	var mitad: float = minf(raiz.size.x * 0.42, 360.0)
	_panel.offset_left = -mitad
	_panel.offset_right = mitad
	_texto.custom_minimum_size.x = maxf(mitad * 2.0 - 40.0, 0.0)
	_ajustar_alto.call_deferred()


func _ajustar_alto() -> void:
	_panel.offset_top = _panel.offset_bottom - _panel.get_combined_minimum_size().y


func _linea(columna: VBoxContainer, cuerpo: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_override("font", TemaInterfaz.fuente())
	etiqueta.add_theme_font_size_override("font_size", cuerpo)
	etiqueta.add_theme_color_override("font_color", color)
	columna.add_child(etiqueta)
	return etiqueta
