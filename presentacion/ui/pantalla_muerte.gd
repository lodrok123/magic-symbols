class_name PantallaMuerte
extends CanvasLayer

## LA PANTALLA DE «HAS MUERTO» (Fase 14.3 · 3.3, 16/10, Juego): sobria, como la de Echoes of Wisdom. Al morir el jugador:
##   1. la UI se esconde (todas las demás capas de interfaz) y el MUNDO se desenfoca y se apaga un poco (shader sobre la pantalla);
##   2. aparece «Has muerto» en rojo apagado (#8a2a2a) con un fundido de T_FUNDIDO (0,6 s);
##   3. se mantiene T_MANTIENE (1,5 s);
##   4. fundido a negro (T_NEGRO), el jugador reaparece en el último punto de guardado (`Jugador3D.reaparecer`), la UI vuelve y se aclara (T_SALIDA).
## Sin botones. Con `esperar_tecla` en true, tras T_TECLA (2 s) sale «Pulsa cualquier tecla» y el paso 4 espera a esa tecla (por defecto
## false: reaparece solo). Todos los tiempos son constantes aquí para que Pablo los afine.
## Fuente: la que haya por defecto (el libro no usa una fuente propia todavía; cuando el Pipeline la entregue, `FUENTE`).
## Cómo se engancha: `Jugador3D.montar` crea una y la llama desde `_morir` (`mostrar`). Si no hay pantalla, el jugador reaparece solo a los
## `TIEMPO_REAPARECER` como siempre (laboratorios y pruebas sin ella).
## Lo que NO hace: no cambia la vida ni la posición por su cuenta; solo pide `reaparecer()` al jugador en el momento en que todo está en negro.

const COLOR_TEXTO: Color = Color("8a2a2a")
const T_FUNDIDO: float = 0.6
const T_MANTIENE: float = 1.5
const T_TECLA: float = 2.0
const T_NEGRO: float = 0.45
const T_SALIDA: float = 0.5
const DESENFOQUE: float = 3.5            ## nivel de mipmap con que se lee la pantalla (0 = nítida; 3–4 = muy borrosa)
const OSCURO: float = 1.0
const FUENTE: String = ""                ## ruta de una fuente propia (vacío = la del tema)

const CODIGO: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float desenfoque = 0.0;
uniform float oscuro = 0.0;
void fragment() {
	vec3 c = textureLod(pantalla, SCREEN_UV, desenfoque).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), oscuro * 0.55);
	c *= 1.0 - oscuro * 0.5;
	COLOR = vec4(c, 1.0);
}
"""

var activa: bool = false
var fase: String = ""                    ## "" | "fundido" | "mantiene" | "negro" | "salida"
var esperar_tecla: bool = false
var _jugador: Node = null
var _desenfoque: ColorRect = null
var _mat: ShaderMaterial = null
var _texto: Label = null
var _pista: Label = null
var _negro: ColorRect = null
var _escondidas: Array = []              ## [[CanvasLayer, visible_antes]]
var _t: float = 0.0
var _tw: Tween = null


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CODIGO
	_mat.shader = sh
	_desenfoque = ColorRect.new()
	_desenfoque.material = _mat
	_desenfoque.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenfoque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenfoque.modulate.a = 0.0
	add_child(_desenfoque)
	_texto = Label.new()
	_texto.text = "Has muerto"
	_texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 84)
	_texto.add_theme_color_override("font_color", COLOR_TEXTO)
	_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_texto.add_theme_constant_override("outline_size", 8)
	if FUENTE != "" and ResourceLoader.exists(FUENTE):
		_texto.add_theme_font_override("font", load(FUENTE))
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.modulate.a = 0.0
	add_child(_texto)
	_pista = Label.new()
	_pista.text = "Pulsa cualquier tecla"
	_pista.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pista.offset_left = -200.0
	_pista.offset_right = 200.0
	_pista.offset_top = -110.0
	_pista.offset_bottom = -70.0
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pista.add_theme_font_size_override("font_size", 18)
	_pista.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 0.8))
	_pista.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_pista.add_theme_constant_override("outline_size", 5)
	_pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.modulate.a = 0.0
	add_child(_pista)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.modulate.a = 0.0
	add_child(_negro)


func _exit_tree() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_restaurar_ui()


## La secuencia completa. `jugador` es quien reaparecerá (`reaparecer()`).
func mostrar(jugador: Node) -> void:
	if activa:
		return
	activa = true
	_jugador = jugador
	_t = 0.0
	fase = "fundido"
	visible = true
	_esconder_ui()
	_texto.modulate.a = 0.0
	_pista.modulate.a = 0.0
	_negro.modulate.a = 0.0
	_desenfoque.modulate.a = 1.0
	_mat.set_shader_parameter("desenfoque", 0.0)
	_mat.set_shader_parameter("oscuro", 0.0)
	PlayLog.event("pantalla_muerte", {"fase": "inicio"})
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("desenfoque", v), 0.0, DESENFOQUE, T_FUNDIDO)
	_tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("oscuro", v), 0.0, OSCURO, T_FUNDIDO)
	_tw.tween_property(_texto, "modulate:a", 1.0, T_FUNDIDO)
	_tw.chain().tween_callback(func() -> void: fase = "mantiene")
	_tw.tween_interval(T_MANTIENE)
	_tw.chain().tween_callback(_tras_mantener)


func _process(delta: float) -> void:
	if not activa:
		return
	_t += delta
	if fase == "mantiene" and esperar_tecla and _t >= T_TECLA and _pista.modulate.a < 1.0:
		_pista.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if not activa or not esperar_tecla or fase != "mantiene" or _t < T_TECLA:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_reaparecer()


func _tras_mantener() -> void:
	if esperar_tecla:
		return                            # espera a la tecla (`_input`) desde T_TECLA
	_reaparecer()


func _reaparecer() -> void:
	if fase == "negro" or fase == "salida":
		return
	fase = "negro"
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_pista.modulate.a = 0.0
	_tw = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(_negro, "modulate:a", 1.0, T_NEGRO)
	_tw.tween_callback(_en_negro)
	_tw.tween_property(_negro, "modulate:a", 0.0, T_SALIDA)
	_tw.tween_callback(_acabar)


## Todo en negro: se quita el desenfoque y el texto, el jugador reaparece en el guardado y vuelve la interfaz.
func _en_negro() -> void:
	fase = "salida"
	_desenfoque.modulate.a = 0.0
	_texto.modulate.a = 0.0
	if is_instance_valid(_jugador) and _jugador.has_method("reaparecer"):
		_jugador.call("reaparecer")
	_restaurar_ui()
	PlayLog.event("pantalla_muerte", {"fase": "reaparece"})


func _acabar() -> void:
	activa = false
	fase = ""
	visible = false


## Esconde las demás capas de interfaz (y se acuerda de las que estaban visibles, para devolverlas tal cual).
func _esconder_ui() -> void:
	_escondidas.clear()
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var capa: CanvasLayer = n as CanvasLayer
		if capa == self or not capa.visible:
			continue
		_escondidas.append(capa)
		capa.visible = false


func _restaurar_ui() -> void:
	for capa in _escondidas:
		if is_instance_valid(capa):
			(capa as CanvasLayer).visible = true
	_escondidas.clear()
