class_name GrimorioUI
extends CanvasLayer

## EL GRIMORIO PASTEL (prueba de concepto): la doble página que se abre con T, con su animación.
## Las láminas salen de `generar_paginas.py` (o de una pintada a mano/IA con las mismas medidas,
## `paginas.json`). Mientras está abierto el tiempo va a cámara muy lenta, como en el juego.
##
## Con el libro abierto:  1 = libro de aprendiz (1 sello, 3 glifos) · 2 = libro avanzado (2 sellos, 6 glifos)
##                        Q / E o flechas = estilo de página (botánico, astral, acuarela)
##                        Espacio = rellenar/vaciar los huecos de glifo (para ver cómo queda la página llena)
## No reconoce dibujos: eso es spellbook.gd en el juego. Aquí solo se juzga el aspecto y la animación.

signal abierto_cambiado(abierto: bool)

const CARPETA: String = "res://poc_25d/grimorio/"
const ESTILOS: Array = ["botanico", "astral", "acuarela"]
const DISTRIBUCIONES: Array = ["s1g3", "s2g6"]
const NOMBRES: Dictionary = {"botanico": "botánico", "astral": "astral", "acuarela": "acuarela",
	"s1g3": "aprendiz: 1 sello · 3 glifos", "s2g6": "avanzado: 2 sellos · 6 glifos"}
const COLOR_ELEMENTO: Array = [Color(0.96, 0.55, 0.36), Color(0.43, 0.67, 0.93), Color(0.77, 0.59, 0.38),
	Color(0.59, 0.84, 0.69), Color(0.94, 0.81, 0.35), Color(0.63, 0.84, 0.94)]
const DURACION: float = 0.35
const TIEMPO_ABIERTO: float = 0.05    ## escala de tiempo del mundo con el libro abierto

@export var estilo: int = 0
@export var distribucion: int = 0

var abierto: bool = false
var _velo: ColorRect = null
var _libro: Control = null
var _lamina: TextureRect = null
var _encima: Control = null
var _rotulo: Label = null
var _medidas: Dictionary = {}
var _llenos: bool = false
var _tw: Tween = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_velo = ColorRect.new()
	_velo.color = Color(0.10, 0.08, 0.12, 0.0)
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_velo)
	_libro = Control.new()
	_libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_libro)
	_lamina = TextureRect.new()
	_lamina.stretch_mode = TextureRect.STRETCH_SCALE
	_lamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_libro.add_child(_lamina)
	_encima = Control.new()
	_encima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encima.draw.connect(_dibujar_encima)
	_libro.add_child(_encima)
	_rotulo = Label.new()
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_rotulo.add_theme_constant_override("outline_size", 6)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_rotulo)
	_leer_medidas()
	_cargar_lamina()
	_libro.visible = false
	_rotulo.visible = false
	get_viewport().size_changed.connect(_encajar)


func _leer_medidas() -> void:
	var ruta: String = CARPETA + "paginas.json"
	if not FileAccess.file_exists(ruta):
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if datos is Dictionary:
		_medidas = (datos as Dictionary).get("distribuciones", {})


func _cargar_lamina() -> void:
	var ruta: String = CARPETA + "pagina_%s_%s.png" % [ESTILOS[estilo], DISTRIBUCIONES[distribucion]]
	_lamina.texture = load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null
	_encajar()
	_encima.queue_redraw()
	_rotulo.text = "GRIMORIO · %s · %s\n1/2 libro · Q/E estilo · Espacio llenar huecos · T cerrar" % [
		NOMBRES[ESTILOS[estilo]], NOMBRES[DISTRIBUCIONES[distribucion]]]


## La lámina ocupa el 92 % del ancho o del alto de la pantalla, lo que quepa.
func _encajar() -> void:
	if _lamina.texture == null:
		return
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var tam: Vector2 = _lamina.texture.get_size()
	var f: float = minf(pantalla.x * 0.92 / tam.x, pantalla.y * 0.86 / tam.y)
	_libro.size = tam
	_lamina.size = tam
	_encima.size = tam
	_libro.pivot_offset = tam * 0.5
	_libro.scale = Vector2.ONE * f if not abierto or _tw == null or not _tw.is_running() else _libro.scale
	_libro.position = (pantalla - tam) * 0.5 + Vector2(0.0, pantalla.y * 0.03)
	_rotulo.size = Vector2(pantalla.x, 60.0)
	_rotulo.position = Vector2(0.0, pantalla.y - 64.0)


func _escala_final() -> float:
	if _lamina.texture == null:
		return 1.0
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	var tam: Vector2 = _lamina.texture.get_size()
	return minf(pantalla.x * 0.92 / tam.x, pantalla.y * 0.86 / tam.y)


## Abre o cierra con la animación: el libro sube desde abajo girado y pequeño, el velo oscurece y el
## mundo se frena; al cerrar, lo contrario y deprisa.
func alternar() -> void:
	abierto = not abierto
	if _tw != null and _tw.is_running():
		_tw.kill()
	_tw = create_tween()
	_tw.set_ignore_time_scale(true)
	_tw.set_parallel(true)
	var f: float = _escala_final()
	var pantalla: Vector2 = get_viewport().get_visible_rect().size
	if abierto:
		_encajar()
		_libro.visible = true
		_rotulo.visible = true
		_libro.scale = Vector2(f * 0.55, f * 0.55)
		_libro.rotation = deg_to_rad(-8.0)
		_libro.modulate = Color(1, 1, 1, 0)
		var destino_y: float = _libro.position.y
		_libro.position.y += pantalla.y * 0.35
		_tw.tween_property(_libro, "position:y", destino_y, DURACION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_libro, "scale", Vector2(f, f), DURACION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_libro, "rotation", 0.0, DURACION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_property(_libro, "modulate:a", 1.0, DURACION * 0.6)
		_tw.tween_property(_velo, "color:a", 0.45, DURACION)
		_tw.tween_property(_rotulo, "modulate:a", 1.0, DURACION)
		Engine.time_scale = TIEMPO_ABIERTO
	else:
		_tw.tween_property(_libro, "position:y", _libro.position.y + pantalla.y * 0.3, DURACION * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tw.tween_property(_libro, "scale", Vector2(f * 0.6, f * 0.6), DURACION * 0.7)
		_tw.tween_property(_libro, "rotation", deg_to_rad(6.0), DURACION * 0.7)
		_tw.tween_property(_libro, "modulate:a", 0.0, DURACION * 0.7)
		_tw.tween_property(_velo, "color:a", 0.0, DURACION * 0.7)
		_tw.tween_property(_rotulo, "modulate:a", 0.0, DURACION * 0.5)
		_tw.chain().tween_callback(_al_cerrar)
		Engine.time_scale = 1.0
	abierto_cambiado.emit(abierto)


func _al_cerrar() -> void:
	_libro.visible = false
	_rotulo.visible = false
	_encajar()


## Cambio de lámina con un "pasar de página": la lámina se aplasta en horizontal y vuelve.
func _pasar(cambio: Callable) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	var f: float = _escala_final()
	tw.tween_property(_libro, "scale:x", f * 0.02, 0.09).set_ease(Tween.EASE_IN)
	tw.tween_callback(cambio)
	tw.tween_property(_libro, "scale:x", f, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func set_estilo(i: int) -> void:
	estilo = posmod(i, ESTILOS.size())
	_cargar_lamina()


func set_distribucion(i: int) -> void:
	distribucion = posmod(i, DISTRIBUCIONES.size())
	_cargar_lamina()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode == KEY_T:
		alternar()
		get_viewport().set_input_as_handled()
		return
	if not abierto:
		return
	match k.keycode:
		KEY_1:
			_pasar(set_distribucion.bind(0))
		KEY_2:
			_pasar(set_distribucion.bind(1))
		KEY_Q, KEY_LEFT:
			_pasar(set_estilo.bind(estilo - 1))
		KEY_E, KEY_RIGHT:
			_pasar(set_estilo.bind(estilo + 1))
		KEY_SPACE:
			_llenos = not _llenos
			_encima.queue_redraw()
	# Con el libro abierto, el resto del juego no recibe teclas.
	get_viewport().set_input_as_handled()


## Lo que va encima de la lámina: los sellos elegidos en el núcleo y los glifos en sus huecos (de muestra).
func _dibujar_encima() -> void:
	var g: Dictionary = _medidas.get(DISTRIBUCIONES[distribucion], {})
	if g.is_empty() or not _llenos:
		return
	var c := Vector2(g["circulo_centro"][0], g["circulo_centro"][1])
	var rn: float = float(g["nucleo_radio"])
	var sellos: int = int(g["sellos"])
	if sellos == 1:
		_encima.draw_circle(c, rn * 0.55, Color(COLOR_ELEMENTO[0], 0.55))
	else:
		_encima.draw_circle(c + Vector2(0, -rn * 0.5), rn * 0.32, Color(COLOR_ELEMENTO[0], 0.6))
		_encima.draw_circle(c + Vector2(0, rn * 0.5), rn * 0.32, Color(COLOR_ELEMENTO[3], 0.6))
	var tinta := Color(0.15, 0.25, 0.60, 0.85)
	var huecos: Array = g["huecos"]
	var r: float = float(g["hueco_radio"])
	for i in range(huecos.size()):
		var h := Vector2(huecos[i][0], huecos[i][1])
		# Un glifo de muestra distinto en cada hueco: flecha, barrera, espiral...
		match i % 3:
			0:
				_encima.draw_line(h + Vector2(-r * 0.5, 0), h + Vector2(r * 0.5, 0), tinta, 4.0)
				_encima.draw_line(h + Vector2(r * 0.5, 0), h + Vector2(r * 0.15, -r * 0.3), tinta, 4.0)
				_encima.draw_line(h + Vector2(r * 0.5, 0), h + Vector2(r * 0.15, r * 0.3), tinta, 4.0)
			1:
				_encima.draw_arc(h, r * 0.5, PI, TAU, 16, tinta, 4.0)
				_encima.draw_line(h + Vector2(-r * 0.5, 0), h + Vector2(r * 0.5, 0), tinta, 4.0)
			_:
				_encima.draw_arc(h, r * 0.45, 0.0, PI * 1.6, 20, tinta, 4.0)
				_encima.draw_arc(h, r * 0.2, PI, TAU * 1.2, 12, tinta, 4.0)
	# Y los mismos glifos repetidos en sus sectores del círculo, para ver el conjunto.
	var rc: float = float(g["circulo_radio"])
	for i in range(huecos.size()):
		var a: float = float(i) / 8.0 * TAU - PI * 0.5
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * (rn + rc) * 0.5
		_encima.draw_line(p - Vector2(cos(a), sin(a)) * 30.0, p + Vector2(cos(a), sin(a)) * 30.0, tinta, 5.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
