extends Node
## LAB DE LAS FICHAS DE GLIFO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4 H5/H6/H8). Enseña `LaminaGlifo` en modo consulta con todas las runas de `FichasGlifo.ids()`.
##   ← / → (o A / D)  runa anterior / siguiente      N  alterna «nueva» (rótulo NUEVA RUNA / RUNA)      Esc  salir
## Se abre con:  godot --path . res://laboratorios/LabFichasGlifo.tscn

var nueva: bool = false
var indice: int = 0
var lamina: LaminaGlifo = null
var _ids: Array = []
var _cuenta: Label = null


func _ready() -> void:
	_ids = FichasGlifo.ids()
	var fondo := CanvasLayer.new()
	fondo.layer = -1
	add_child(fondo)
	var rect := ColorRect.new()
	rect.color = Color(0.30, 0.33, 0.37)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(rect)
	var capa := CanvasLayer.new()
	capa.layer = 90
	add_child(capa)
	_cuenta = Label.new()
	_cuenta.position = Vector2(16.0, 12.0)
	_cuenta.add_theme_font_size_override("font_size", 20)
	capa.add_child(_cuenta)
	var ayuda := Label.new()
	ayuda.text = "← →  /  A D: otra runa      N: nueva / consulta      Esc: salir"
	ayuda.add_theme_font_size_override("font_size", 16)
	ayuda.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ayuda.offset_left = -300.0
	ayuda.offset_right = 300.0
	ayuda.offset_top = -44.0
	ayuda.offset_bottom = -12.0
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capa.add_child(ayuda)
	mostrar(0)


func mostrar(i: int) -> void:
	indice = posmod(i, _ids.size())
	if is_instance_valid(lamina):
		lamina.free()
	lamina = LaminaGlifo.mostrar(self, String(_ids[indice]), nueva, false)
	_cuenta.text = "%d / %d   ·   %s" % [indice + 1, _ids.size(), String(_ids[indice])]


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_RIGHT, KEY_D:
			mostrar(indice + 1)
		KEY_LEFT, KEY_A:
			mostrar(indice - 1)
		KEY_N:
			nueva = not nueva
			mostrar(indice)
		KEY_ESCAPE:
			get_tree().quit()
