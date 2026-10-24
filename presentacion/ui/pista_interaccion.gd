class_name PistaInteraccion
extends PanelContainer

## LA PISTA DE INTERACCIÓN «[E] Hablar» (24/10; estilo Echoes of Wisdom: una tecla redondeada y la acción, sobre un panel oscuro translúcido).
## Un control suelto, listo para colgarlo de una capa de interfaz: `mostrar("E", "Hablar")` lo enseña con un fundido, `ocultar()` lo apaga.
## Se coloca abajo en el centro, sobre la guía del lanzador. No decide nada: quien sepa que hay algo a mano (un NPC, un cofre, una planta) la llama.
## No cambia lógica ni tamaños de hit: ignora el ratón.

const T_FUNDIDO_S: float = 0.18
const Y_DESDE_ABAJO_PX: float = 150.0      ## separación entre el borde de abajo de la pantalla y la pista
const LADO_TECLA_PX: float = 30.0
const ESQUINA_TECLA_PX: int = 8
const COLOR_TECLA: Color = Color(0.96, 0.92, 0.82)       ## la tecla es clara, con la letra oscura (se lee de un vistazo)
const COLOR_LETRA: Color = Color(0.16, 0.11, 0.06)
const COLOR_BORDE_TECLA: Color = Color(0.55, 0.40, 0.20)
const SEPARACION_PX: int = 10

var _tecla: Label = null
var _accion: Label = null
var _tween: Tween = null


func _init() -> void:
	theme = TemaInterfaz.tema()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", SEPARACION_PX)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	_tecla = Label.new()
	_tecla.custom_minimum_size = Vector2(LADO_TECLA_PX, LADO_TECLA_PX)
	_tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tecla.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := StyleBoxFlat.new()
	caja.bg_color = COLOR_TECLA
	caja.border_color = COLOR_BORDE_TECLA
	caja.set_border_width_all(2)
	caja.border_width_bottom = 4                      # el canto de la tecla
	caja.set_corner_radius_all(ESQUINA_TECLA_PX)
	caja.anti_aliasing = true
	_tecla.add_theme_stylebox_override("normal", caja)
	_tecla.add_theme_color_override("font_color", COLOR_LETRA)
	_tecla.add_theme_constant_override("outline_size", 0)
	fila.add_child(_tecla)
	_accion = Label.new()
	_accion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_accion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(_accion)


## Enseña «[tecla] acción», centrada abajo. Si ya estaba, solo cambia el texto.
func mostrar(tecla: String, accion: String) -> void:
	_tecla.text = tecla
	_accion.text = accion
	visible = true
	reset_size()
	_colocar()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, T_FUNDIDO_S)


func ocultar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, T_FUNDIDO_S)
	_tween.tween_callback(func(): visible = false)


## Abajo en el centro de la ventana (anclas al borde de abajo, crece hacia los lados).
func _colocar() -> void:
	var medida: Vector2 = get_combined_minimum_size()        # antes de tocar las anclas: cambiarlas deforma el tamaño actual
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	offset_left = -medida.x * 0.5
	offset_right = medida.x * 0.5
	offset_bottom = -Y_DESDE_ABAJO_PX
	offset_top = offset_bottom - medida.y


## El texto de la acción y el de la tecla (para las pruebas).
func texto_accion() -> String:
	return _accion.text


func texto_tecla() -> String:
	return _tecla.text


## Contraste del texto de la acción contra el panel y de la letra contra la tecla (el peor de los dos, con el panel sobre blanco o negro).
static func contraste_minimo() -> float:
	var panel: float = TemaInterfaz.contraste_peor(TemaInterfaz.TEXTO, TemaInterfaz.FONDO_PANEL)
	return minf(panel, TemaInterfaz.contraste(COLOR_LETRA, COLOR_TECLA))
