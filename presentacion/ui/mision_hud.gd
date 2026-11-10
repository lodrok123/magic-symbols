class_name MisionHud
extends Label

## LA LÍNEA DE LA MISIÓN SEGUIDA en el HUD (Fase 14.3, 16/10, Juego): «Título · objetivo actual», discreta, debajo de las barras de vida y
## tinta. No decide nada: lee `Misiones.i().linea_hud()` y se redibuja cuando el diario avisa (`mision_cambio` / `seguida_cambio`).
## Si `Misiones.nuevo()` sustituye la instancia (un nivel nuevo), se vuelve a enganchar sola. Sin misión seguida no se ve.

const POS: Vector2 = Vector2(14.0, 176.0)     ## bajo vida y frascos+tinta (HudEoW: Jugador3D.Y_BARRAS 80 + ~92 px de HUD; antes 122, bajo las dos barras finas)

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
		if _m.mision_activada.is_connected(_on_activada):
			_m.mision_activada.disconnect(_on_activada)
		if _m.objetivo_marcado.is_connected(_on_objetivo):
			_m.objetivo_marcado.disconnect(_on_objetivo)
		if _m.mision_completada.is_connected(_on_completada):
			_m.mision_completada.disconnect(_on_completada)
	_m = Misiones.i()
	_m.mision_cambio.connect(_on_cambio)
	_m.seguida_cambio.connect(_on_seguida)
	_m.mision_activada.connect(_on_activada)
	_m.objetivo_marcado.connect(_on_objetivo)
	_m.mision_completada.connect(_on_completada)
	_pintar()


## GAMEFEEL U3 (31/10): recibir, avanzar y completar una misión tienen sonidos propios (la interfaz suena
## SIEMPRE; con `Sensacion3D.ACTIVA = false` solo se apagan el deslizamiento y el destello). La línea entra deslizándose desde la izquierda y destella.
static var T_ENTRA_S: float = 0.2            ## s que tarda la línea en llegar a su sitio
static var DESPLAZA_PX: float = 36.0         ## px a la izquierda de donde parte
static var T_DESTELLO_S: float = 0.3         ## s del destello (brilla y vuelve a su color)
static var COLOR_DESTELLO: Color = Color(1.9, 1.75, 1.15, 1.0)
var _tw: Tween = null


func _on_activada(_id: String) -> void:
	Sfx.play_ui("logro_pista")
	_animar_entrada()


func _on_objetivo(id: String, _indice: int) -> void:
	Sfx.play_ui("objetivo_cumplido")
	if id == _m.seguida_id():
		_animar_entrada()


func _on_completada(_id: String) -> void:
	Sfx.play_ui("mision_completada")
	_animar_entrada()


func _animar_entrada() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	position = POS
	modulate = Color.WHITE
	if not Sensacion3D.ACTIVA or not is_inside_tree():
		return
	position = POS + Vector2(-DESPLAZA_PX, 0.0)
	modulate = Color(COLOR_DESTELLO.r, COLOR_DESTELLO.g, COLOR_DESTELLO.b, 0.0)
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw.tween_property(self, "position", POS, T_ENTRA_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "modulate", Color.WHITE, T_DESTELLO_S).set_ease(Tween.EASE_OUT)    # el destello: nace brillante y translúcido, acaba en su color


func _on_cambio(_id: String) -> void:
	_pintar()


func _on_seguida(_id: String) -> void:
	_pintar()


func _pintar() -> void:
	var t: String = _m.linea_hud() if _m != null else ""
	text = ("◆ " + t) if t != "" else ""
	visible = t != ""
