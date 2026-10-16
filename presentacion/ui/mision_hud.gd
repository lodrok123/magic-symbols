class_name MisionHud
extends Label

## LA LÍNEA DE LA MISIÓN SEGUIDA en el HUD (Fase 14.3, 16/10, Juego): «Título · objetivo actual», discreta, debajo de las barras de vida y
## tinta. No decide nada: lee `Misiones.i().linea_hud()` y se redibuja cuando el diario avisa (`mision_cambio` / `seguida_cambio`).
## Si `Misiones.nuevo()` sustituye la instancia (un nivel nuevo), se vuelve a enganchar sola. Sin misión seguida no se ve.

const POS: Vector2 = Vector2(14.0, 122.0)     ## bajo la barra de tinta (Jugador3D.Y_BARRAS 80 + 24..38)

var _m: Misiones = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = POS
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color(0.98, 0.95, 0.85, 0.92))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("outline_size", 5)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enganchar()


func _process(_delta: float) -> void:
	if _m != Misiones.i():
		_enganchar()


func _enganchar() -> void:
	if _m != null:
		if _m.mision_cambio.is_connected(_on_cambio):
			_m.mision_cambio.disconnect(_on_cambio)
		if _m.seguida_cambio.is_connected(_on_seguida):
			_m.seguida_cambio.disconnect(_on_seguida)
	_m = Misiones.i()
	_m.mision_cambio.connect(_on_cambio)
	_m.seguida_cambio.connect(_on_seguida)
	_pintar()


func _on_cambio(_id: String) -> void:
	_pintar()


func _on_seguida(_id: String) -> void:
	_pintar()


func _pintar() -> void:
	var t: String = _m.linea_hud() if _m != null else ""
	text = ("◆ " + t) if t != "" else ""
	visible = t != ""
