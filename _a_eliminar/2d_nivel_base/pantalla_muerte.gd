class_name PantallaMuerte
extends CanvasLayer

## LA PANTALLA DE "HAS MUERTO". El jugador (player.gd) la busca por el grupo
## "pantalla_muerte"; si existe, al morir hace su animación de muerte, la pantalla se
## funde y espera. Pulsando ENTER o el botón, el jugador revive en el último punto de
## guardado (o en el inicio si no pisó ninguno).

var _fondo: ColorRect
var _caja: VBoxContainer
var _jugador: Node = null
var _lista: bool = false


func _ready() -> void:
	add_to_group("pantalla_muerte")
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_fondo = ColorRect.new()
	_fondo.color = Color(0.25, 0.0, 0.02, 0.0)
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_caja = VBoxContainer.new()
	_caja.alignment = BoxContainer.ALIGNMENT_CENTER
	_caja.add_theme_constant_override("separation", 22)
	_fondo.add_child(_caja)
	_caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var t := Label.new()
	t.text = "HAS MUERTO"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	t.add_theme_constant_override("outline_size", 10)
	_caja.add_child(t)

	var b := Button.new()
	b.text = "Volver al último punto de guardado   [Enter]"
	b.custom_minimum_size = Vector2(420, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_continuar)
	_caja.add_child(b)
	_caja.modulate.a = 0.0


func mostrar(jugador: Node, espera: float = 1.1) -> void:
	_jugador = jugador
	_lista = false
	visible = true
	_fondo.color.a = 0.0
	_caja.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(espera)           # deja acabar la animación de caída
	tw.tween_property(_fondo, "color:a", 0.62, 0.8)
	tw.parallel().tween_property(_caja, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func(): _lista = true)


func _input(event: InputEvent) -> void:
	if not visible or not _lista:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_R):
		get_viewport().set_input_as_handled()
		_continuar()


func _continuar() -> void:
	if not _lista:
		return
	_lista = false
	visible = false
	if is_instance_valid(_jugador):
		_jugador.call("revivir")
